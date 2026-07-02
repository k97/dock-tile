//
//  DiagnosticsLog.swift
//  DockTile
//
//  Cross-process diagnostics. Captures recent app events (lifecycle, Sparkle
//  updates, Dock operations, helper-tile activity, errors) so the user can run
//  File > Copy Diagnostics and paste one timeline covering the main app AND every
//  helper tile.
//
//  HOW cross-process works: the main app and all its helpers are copies that share
//  one Application Support folder (AppEnvironment.supportURL), and the app is not
//  sandboxed — so every process appends to ONE shared file with atomic O_APPEND
//  writes. The main app's report() reads that file. Each line is tagged with the
//  process label (main / helper:<tile>) + pid. Also mirrored to the unified log
//  (subsystem "com.docktile.diagnostics") for Console.app.
//
//  Verbosity: `log(_:_:verbose:)` — verbose events are kept in Debug/dev builds and
//  dropped in Release, so prod reports stay lean. Dev and prod write to separate
//  files (separate support folders), so dev's firehose never reaches a user's prod log.
//
//  Click tracing: `ui(_:)` is a semantic shorthand for user-interaction events (button
//  taps, sidebar selection, menu commands, Dock clicks). It is ALWAYS verbose, so the
//  click firehose lands in dev reports and is dropped in Release automatically — the
//  "rich in dev, quiet in prod" contract with no per-call bookkeeping.
//
//  Workflow timing: `measure(_:_:)` brackets a unit of work with a start/end line (elapsed
//  ms) AND an OSSignposter interval, so a multi-step workflow (install a helper, run the
//  migration batch, build+show a popover) is both readable in the copied report and
//  profilable in Instruments' "workflow" signposts. Timing lines are verbose (dev only);
//  a thrown error is logged non-verbose (failures matter in prod too).
//
//  Thread-safe — safe to call from any thread.
//

import AppKit
import Darwin
import Foundation
import OSLog

final class DiagnosticsLog: @unchecked Sendable {
    static let shared = DiagnosticsLog()

    private struct Entry {
        let date: Date
        let category: String
        let message: String
    }

    private let lock = NSLock()
    /// In-process fallback buffer, used only if the shared file can't be read.
    private var entries: [Entry] = []
    /// Process label used in each line: "main" or "helper:<tile name>".
    private var label: String = AppEnvironment.appRole

    /// Keep roughly the last hour, with a hard count cap as an in-memory backstop.
    private let retention: TimeInterval = 3600
    private let hardCap = 2000

    /// One shared file per environment (dev vs release have separate support folders).
    private let fileURL = AppEnvironment.supportURL.appendingPathComponent("diagnostics.log")

    private let logger = Logger(subsystem: "com.docktile.diagnostics", category: "app")

    /// Signpost interval emitter for `measure(_:)`. Shows workflow spans in Instruments'
    /// "workflow" signpost track (subsystem "com.docktile.diagnostics") so a dev can profile
    /// how long install / migration / popover-show actually take.
    private let signposter = OSSignposter(subsystem: "com.docktile.diagnostics", category: "workflow")

    private let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        // The support folder normally already exists (helpers live in it), but make sure
        // so the very first write on a fresh install doesn't drop on the floor.
        try? FileManager.default.createDirectory(at: AppEnvironment.supportURL,
                                                 withIntermediateDirectories: true)
    }

    /// Identify this process in the shared log. Helpers call this with their tile name
    /// once the config is loaded; the main app keeps the default ("main").
    func setLabel(_ label: String) {
        lock.lock(); self.label = label; lock.unlock()
    }

    /// Pure gate for whether an event is recorded: verbose (dev-detail) events are dropped in
    /// Release; everything else is always kept. Extracted as a `nonisolated static` seam (mirrors
    /// `resolveDockVisibility` / `AnalyticsService.shouldCollect`) so the dev-verbose/prod-quiet
    /// rule is unit-tested without depending on the build-time `AppEnvironment.isRelease` constant.
    nonisolated static func shouldRecord(verbose: Bool, isRelease: Bool) -> Bool {
        !(verbose && isRelease)
    }

    /// Record a diagnostic event. `category` is a short tag, e.g. "update", "dock", "helper".
    /// Pass `verbose: true` for high-frequency/low-signal events — those are dropped in Release.
    func log(_ category: String, _ message: String, verbose: Bool = false) {
        guard Self.shouldRecord(verbose: verbose, isRelease: AppEnvironment.isRelease) else { return }

        let now = Date()
        lock.lock()
        let label = self.label
        entries.append(Entry(date: now, category: category, message: message))
        pruneLocked(now: now)
        lock.unlock()

        appendToFile("\(stamp.string(from: now)) [\(label) \(ProcessInfo.processInfo.processIdentifier)] [\(category)] \(message)\n")
        logger.notice("[\(label, privacy: .public)] [\(category, privacy: .public)] \(message, privacy: .public)")
    }

    /// Record a user-interaction (click/tap/selection/menu) event. Semantic shorthand for
    /// `log("ui", …, verbose: true)`: the click firehose is ALWAYS verbose, so it enriches dev
    /// reports and is dropped in Release automatically. Use for the gesture that *triggers* work
    /// ("+ pressed", "Add to Dock clicked", "Dock icon clicked → show popover"), complementing the
    /// non-verbose state-change logs that record the *outcome*.
    func ui(_ message: String) {
        log("ui", message, verbose: true)
    }

    // MARK: - Workflow timing

    /// Bracket an async unit of work with start/end timing lines and an OSSignposter interval.
    /// Logs `▶ <name>` then `✔ <name> (Nms)` (both verbose — dev only); a thrown error logs
    /// `✗ <name> FAILED (Nms)` non-verbose (kept in prod) and re-throws. Returns the body's value.
    ///
    /// Inherits the caller's actor isolation (`#isolation`) so a `@MainActor` workflow closure that
    /// captures actor-isolated state stays on that actor rather than being "sent" across actors —
    /// avoids the Swift 6 non-Sendable-closure diagnostic without forcing `@Sendable` on the body.
    func measure<T>(_ name: String, category: String = "workflow", isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> T) async rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        let id = signposter.makeSignpostID()
        let interval = signposter.beginInterval("workflow", id: id, "\(name)")
        log(category, "▶ \(name)", verbose: true)
        do {
            let result = try await body()
            signposter.endInterval("workflow", interval)
            log(category, "✔ \(name) (\(Self.elapsedMs(from: start, clock: clock))ms)", verbose: true)
            return result
        } catch {
            signposter.endInterval("workflow", interval)
            log(category, "✗ \(name) FAILED (\(Self.elapsedMs(from: start, clock: clock))ms): \(error.localizedDescription)")
            throw error
        }
    }

    /// Synchronous counterpart to `measure(_:_:)` for non-async workflows.
    func measure<T>(_ name: String, category: String = "workflow", _ body: () throws -> T) rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        let id = signposter.makeSignpostID()
        let interval = signposter.beginInterval("workflow", id: id, "\(name)")
        log(category, "▶ \(name)", verbose: true)
        do {
            let result = try body()
            signposter.endInterval("workflow", interval)
            log(category, "✔ \(name) (\(Self.elapsedMs(from: start, clock: clock))ms)", verbose: true)
            return result
        } catch {
            signposter.endInterval("workflow", interval)
            log(category, "✗ \(name) FAILED (\(Self.elapsedMs(from: start, clock: clock))ms): \(error.localizedDescription)")
            throw error
        }
    }

    /// Whole milliseconds elapsed since `start`. Pure so `measure`'s formatting is trivially checked.
    nonisolated static func elapsedMs(from start: ContinuousClock.Instant, clock: ContinuousClock) -> Int {
        let (seconds, attoseconds) = start.duration(to: clock.now).components
        return Int(seconds * 1000 + attoseconds / 1_000_000_000_000_000)
    }

    private func pruneLocked(now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        if let firstFresh = entries.firstIndex(where: { $0.date >= cutoff }), firstFresh > 0 {
            entries.removeFirst(firstFresh)
        }
        if entries.count > hardCap {
            entries.removeFirst(entries.count - hardCap)
        }
    }

    /// Atomic cross-process append (O_APPEND guarantees each write lands at end-of-file).
    private func appendToFile(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        let fd = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { return }
        defer { close(fd) }
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress { _ = write(fd, base, raw.count) }
        }
    }

    /// Main-app-only: trim the shared file to the retention window on launch so it
    /// doesn't grow unbounded. Helpers never trim (avoids multi-writer rewrite races).
    func prepareOnLaunch() {
        guard !AppEnvironment.isHelper else { return }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let cutoff = Date().addingTimeInterval(-retention)
        let kept = content.split(separator: "\n", omittingEmptySubsequences: true).filter { line in
            guard let sp = line.firstIndex(of: " ") else { return true }
            guard let d = stamp.date(from: String(line[line.startIndex..<sp])) else { return true }
            return d >= cutoff
        }
        let rebuilt = kept.isEmpty ? "" : kept.joined(separator: "\n") + "\n"
        try? rebuilt.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// The last hour of lines from the shared file (all processes), chronological.
    /// Falls back to this process's in-memory buffer if the file can't be read.
    private func recentLines() -> [String] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            lock.lock(); let snapshot = entries; lock.unlock()
            return snapshot.map { "\(stamp.string(from: $0.date))  [\($0.category)]  \($0.message)" }
        }
        let cutoff = Date().addingTimeInterval(-retention)
        return content.split(separator: "\n", omittingEmptySubsequences: true).compactMap { sub in
            let line = String(sub)
            guard let sp = line.firstIndex(of: " ") else { return line }
            if let d = stamp.date(from: String(line[line.startIndex..<sp])), d < cutoff { return nil }
            return line
        }
    }

    /// A human-readable report: environment header + the last hour of events across all processes.
    func report() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let events = recentLines()
        var out: [String] = [
            "Dock Tile Diagnostics",
            "Generated:  \(stamp.string(from: Date()))",
            "Version:    \(AppEnvironment.appVersion) (\(AppEnvironment.current))",
            "Role:       \(AppEnvironment.appRole)",
            "Bundle:     \(Bundle.main.bundleIdentifier ?? "unknown")",
            "macOS:      \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "Verbose:    \(AppEnvironment.isRelease ? "off (release — click/workflow traces omitted)" : "on (dev — click + workflow traces included)")",
            "Events:     \(events.count) in the last hour (main app + all helper tiles)",
            String(repeating: "—", count: 56)
        ]
        out.append(events.isEmpty ? "(no diagnostic events recorded in the last hour)" : events.joined(separator: "\n"))
        return out.joined(separator: "\n")
    }

    /// Build the report and place it on the general pasteboard (NSPasteboard → main thread).
    @MainActor
    func copyToPasteboard() {
        let text = report()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        log("diagnostics", "Copied diagnostics report to clipboard (\(text.count) chars)")
    }
}
