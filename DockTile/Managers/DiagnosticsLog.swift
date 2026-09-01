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
import Security

/// One pinned helper's icon-shape facts for Copy Diagnostics — plain values gathered once per
/// report by `HelperBundleManager.collectIconInventory`. Built for the Dock icon-size-flap
/// investigation: the legacy path's constant `.icns` rewriting + Launch Services re-registration is
/// the suspected trigger, and the declarative pipeline (macOS 26, no runtime swaps) is the fix under
/// test — so a report must make it unambiguous which shape a given pinned tile was actually in.
struct HelperIconInventory {
    /// `config.diagnosticName` — never a bare tile name (two tiles can legitimately share one).
    let tileName: String
    let sealValid: Bool
    /// LEGACY path only: the filename of the style variant the live `AppIcon.icns` byte-matches,
    /// or the literal `"none"` when it matches none of them. `nil` on the declarative path, or when
    /// inspection failed before this could be determined.
    let liveIconMatchesVariant: String?
    /// DECLARATIVE path: whether `Assets.car` exists in the bundle's Resources.
    let carPresent: Bool
    /// DECLARATIVE path only: a short `assetutil --info` summary (rendition count + whether an
    /// `IconImageStack` rendition is present). `nil` when there's no car, or inspection failed.
    let carRenditionSummary: String?
    /// Modification times of every icon-related file found in the bundle — the trace of exactly
    /// the rewriting churn implicated in the Dock icon-size flap.
    let iconFileMTimes: [String: Date]
    /// Non-nil ⇒ inspecting this helper failed partway (missing bundle, unreadable signature,
    /// unparseable `assetutil` output, …). The other fields are then best-effort/unset and must not
    /// be trusted — a partially-inspected helper still gets its own row instead of vanishing from
    /// the report, so one broken tile can never hide the rest.
    let inspectionError: String?
}

/// One helper bundle's code-signature state, from a single `SecStaticCodeCheckValidity` pass.
///
/// Copy Diagnostics reports seals twice — once per bundle in the "Helper bundle signatures"
/// section, once per pinned tile in the icon inventory — and that validation costs ~70 ms on a
/// 16 MB bundle (≈2 s at 16 tiles, synchronously on the main actor). So it is computed ONCE, by
/// `HelperBundleManager.helperSealStates()`, and threaded into both sections.
enum HelperSealState: Equatable {
    case valid
    /// `SecStaticCodeCheckValidity` failed — the seal is genuinely broken.
    case broken(OSStatus)
    /// `SecStaticCodeCreateWithPath` failed — the bundle's signature could not even be read.
    case unreadable(OSStatus)

    var isValid: Bool { self == .valid }
}

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

    /// Where helper spin watchdogs drop `/usr/bin/sample` captures (one per process lifetime).
    static let spinsDirectory = AppEnvironment.supportURL.appendingPathComponent("spins")

    /// Pure: the `Sort by top of stack` block of a `sample` report — the frames the process spent
    /// the most time in — without the long `Binary Images` tail. Empty when the marker is absent.
    nonisolated static func spinExcerpt(from sampleText: String) -> String {
        let lines = sampleText.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("Sort by top of stack") }) else { return "" }
        let end = lines[start...].firstIndex(where: { $0.hasPrefix("Binary Images") }) ?? lines.endIndex
        return lines[start..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Newest-first spin capture files (empty when none). Names start with an ISO stamp, so a
    /// reverse lexicographic sort is a reverse chronological sort.
    private func spinCaptureFiles() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: Self.spinsDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

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

        // Keep only the 5 newest spin captures. Main app only — helpers never prune shared files.
        for stale in spinCaptureFiles().dropFirst(5) {
            try? FileManager.default.removeItem(at: stale)
        }
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
    /// `configurations` (the app's known tiles) is used only to name/scope the icon inventory
    /// section below — pass `ConfigurationManager.configurations`; helpers pass none.
    @MainActor
    func report(configurations: [DockTileConfiguration]) -> String {
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

        // Spin captures are the one piece of evidence a runaway helper leaves behind; list them and
        // inline the hottest frames of the newest so the pasted report alone can name the loop.
        let spins = spinCaptureFiles()
        if !spins.isEmpty {
            out.append("")
            out.append("Spin captures (\(spins.count), newest first — full files in \(Self.spinsDirectory.path)):")
            for file in spins.prefix(5) { out.append("  \(file.lastPathComponent)") }
            if let newest = spins.first, let text = try? String(contentsOf: newest, encoding: .utf8) {
                out.append("")
                out.append("Hottest frames in \(newest.lastPathComponent):")
                out.append(Self.spinExcerpt(from: text))
            }
        }

        // ONE seal validation pass for the whole report: this section renders it in full, and the
        // icon inventory below reads its per-tile answer out of the same map instead of
        // re-running SecStaticCodeCheckValidity on every pinned bundle (~70 ms each).
        let sealStates = HelperBundleManager.shared.helperSealStates()
        if !sealStates.isEmpty {
            out.append("")
            out.append("Helper bundle signatures:")
            out.append(contentsOf: Self.formatSealStates(sealStates))
        }

        // Always rendered (even when empty) — see `formatIconInventory`'s doc comment for why.
        out.append("")
        out.append(Self.formatIconInventory(HelperBundleManager.shared.collectIconInventory(
            configurations: configurations, sealStates: sealStates)))

        return out.joined(separator: "\n")
    }

    /// ISO8601 (whole seconds — mtime resolution finer than that isn't useful here) formatter for
    /// `formatIconInventory`'s mtime lines. A dedicated static instance so the pure formatter below
    /// doesn't need an instance of `DiagnosticsLog` to render a date.
    nonisolated(unsafe) private static let mtimeStamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Pure renderer for the Copy Diagnostics icon-inventory section (regression-guard convention —
    /// mirrors `spinExcerpt`). Always renders a header, even for an empty list, so the section's
    /// absence in a pasted report is never mistaken for "the feature never ran".
    nonisolated static func formatIconInventory(_ items: [HelperIconInventory]) -> String {
        var lines = ["Icon inventory (pinned helpers only):"]
        guard !items.isEmpty else {
            lines.append("  (no pinned helpers)")
            return lines.joined(separator: "\n")
        }
        for item in items {
            lines.append("  \(item.tileName)")
            if let error = item.inspectionError {
                lines.append("    INSPECTION FAILED: \(error)")
                continue
            }
            lines.append("    seal: \(item.sealValid ? "valid" : "BROKEN")")
            if item.carPresent {
                let summary = item.carRenditionSummary ?? "present, assetutil summary unavailable"
                lines.append("    shape: declarative — Assets.car present (\(summary))")
            } else if let match = item.liveIconMatchesVariant {
                let described = (match == "none") ? "no known variant" : match
                lines.append("    shape: legacy — live AppIcon.icns matches \(described)")
            } else {
                lines.append("    shape: unknown — no Assets.car and no variant match found")
            }
            if item.iconFileMTimes.isEmpty {
                lines.append("    mtimes: (no icon files found)")
            } else {
                let joined = item.iconFileMTimes.keys.sorted()
                    .map { "\($0)=\(mtimeStamp.string(from: item.iconFileMTimes[$0]!))" }
                    .joined(separator: ", ")
                lines.append("    mtimes: \(joined)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Pure renderer for the per-bundle code-signature section, one line each (mirrors
    /// `formatIconInventory`). The states come from `HelperBundleManager.helperSealStates()` — the
    /// single validation pass this report runs.
    ///
    /// WHY this is worth a line in every report: switching a tile's icon rewrites `AppIcon.icns`
    /// inside an already-signed bundle, which breaks the signature seal — verified, a tile that has
    /// switched styles fails with "a sealed resource is missing or invalid / file modified:
    /// …/AppIcon.icns" while one that never switched verifies clean. So this doubles as a free,
    /// on-disk indicator of WHICH tiles have been flipping appearance, with no telemetry at all.
    nonisolated static func formatSealStates(_ states: [String: HelperSealState]) -> [String] {
        states.keys.sorted().map { name in
            switch states[name]! {
            case .valid:
                return "  \(name): seal valid"
            case .unreadable(let status):
                return "  \(name): unreadable (OSStatus \(status))"
            case .broken(let status):
                // errSecCSBadResource (-67054) is the icon-swap signature: a sealed resource changed.
                let note = (status == errSecCSBadResource) ? " (sealed resource modified — icon swap)" : ""
                return "  \(name): SEAL BROKEN, OSStatus \(status)\(note)"
            }
        }
    }

    /// Build the report and place it on the general pasteboard (NSPasteboard → main thread).
    @MainActor
    func copyToPasteboard(configurations: [DockTileConfiguration]) {
        let text = report(configurations: configurations)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        log("diagnostics", "Copied diagnostics report to clipboard (\(text.count) chars)")
    }
}

// MARK: - Spin watchdog (helpers)

/// Pure decision seam for the helper CPU watchdog (regression-guard convention — mirrors
/// `DiagnosticsLog.shouldRecord`). Plain values in, decision out; no clocks, no files.
enum SpinWatchdogPolicy {
    /// Fraction of one core the process must sustain for a window to count as "hot".
    static let hotUtilization: Double = 0.5
    /// Consecutive hot windows before a capture fires (3 × 30 s = 90 s — a popover-open burst
    /// lasts well under a second; the July 2026 incident ran at 83 % for 16 h).
    static let hotWindowsRequired = 3
    /// Window length in seconds.
    static let interval: TimeInterval = 30

    /// CPU-seconds consumed per wall-second — 1.0 = one core fully busy.
    nonisolated static func utilization(cpuDeltaNs: UInt64, wallDeltaNs: UInt64) -> Double {
        guard wallDeltaNs > 0 else { return 0 }
        return Double(cpuDeltaNs) / Double(wallDeltaNs)
    }

    /// Advance the hot-window streak and decide whether to capture now. A capture fires once per
    /// process lifetime (`hasCaptured`) — one `sample` file is the evidence; more is noise.
    nonisolated static func step(utilization: Double, consecutiveHot: Int, hasCaptured: Bool)
        -> (consecutiveHot: Int, capture: Bool) {
        let hot = utilization >= hotUtilization
        let streak = hot ? consecutiveHot + 1 : 0
        return (streak, hot && !hasCaptured && streak >= hotWindowsRequired)
    }
}

/// Recorded as a Crashlytics non-fatal when the watchdog fires, so prevalence across users is
/// visible even when nobody sends a diagnostics report.
enum SpinWatchdogError: Error {
    case sustainedCPU
}

/// Helper-only CPU watchdog. Ticks on its OWN background queue (a `DispatchSourceTimer`, not a
/// run-loop `Timer`), so it keeps ticking while the main thread is hung or spinning. When the
/// process sustains `SpinWatchdogPolicy.hotUtilization` of a core for `hotWindowsRequired`
/// windows it runs `/usr/bin/sample` on itself into `DiagnosticsLog.spinsDirectory` and logs it —
/// the stack the July 2026 "AI Tile at 82.9 % CPU for 16 h" report never had.
///
/// `sample` on an own-user, ad-hoc-signed helper needs no root and no TCC grant (verified from a
/// launchd-spawned context on 2026-08-29).
final class SpinWatchdog: @unchecked Sendable {
    static let shared = SpinWatchdog()

    private let queue = DispatchQueue(label: "com.docktile.spin-watchdog", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastCPU: UInt64 = 0
    private var lastWall: UInt64 = 0
    private var consecutiveHot = 0
    private var hasCaptured = false
    /// Set by a block dispatched to the main queue each tick; still false next tick ⇒ main hung.
    private var mainThreadPong = true
    private var sampler: Process?

    private init() {}

    /// Begin watching. Idempotent. All state is confined to `queue`.
    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            lastCPU = Self.processCPUNs()
            lastWall = DispatchTime.now().uptimeNanoseconds
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now() + SpinWatchdogPolicy.interval,
                            repeating: SpinWatchdogPolicy.interval)
            source.setEventHandler { [weak self] in self?.tick() }
            timer = source
            source.resume()
        }
    }

    /// Total CPU time (all threads) this process has consumed — what Activity Monitor's % CPU is
    /// derived from.
    private static func processCPUNs() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_PROCESS_CPUTIME_ID)
    }

    private func tick() {
        let cpu = Self.processCPUNs()
        let wall = DispatchTime.now().uptimeNanoseconds
        let utilization = SpinWatchdogPolicy.utilization(cpuDeltaNs: cpu &- lastCPU,
                                                         wallDeltaNs: wall &- lastWall)
        lastCPU = cpu
        lastWall = wall

        // Round-trip a block through the main queue: if the previous one never came back, the main
        // thread is wedged — which distinguishes "spinning in a background worker" from "spinning
        // in AppKit/SwiftUI on main", the single most useful bit for reading the capture.
        let mainResponsive = mainThreadPong
        mainThreadPong = false
        DispatchQueue.main.async { [weak self] in
            self?.queue.async { self?.mainThreadPong = true }
        }

        let decision = SpinWatchdogPolicy.step(utilization: utilization,
                                               consecutiveHot: consecutiveHot,
                                               hasCaptured: hasCaptured)
        consecutiveHot = decision.consecutiveHot
        guard decision.capture else { return }
        hasCaptured = true

        let hotSeconds = Int(Double(consecutiveHot) * SpinWatchdogPolicy.interval)
        let percent = Int((utilization * 100).rounded())
        DiagnosticsLog.shared.log("watchdog",
            "Sustained CPU \(percent)% of a core for \(hotSeconds)s " +
            "(main thread \(mainResponsive ? "responsive" : "NOT responding")) — capturing sample")
        Task { @MainActor in
            AnalyticsService.shared.record(SpinWatchdogError.sustainedCPU,
                                           context: "spin_watchdog",
                                           keys: ["cpu_percent": String(percent),
                                                  "main_thread_responsive": String(mainResponsive)])
        }
        captureSample()
    }

    private func captureSample() {
        let dir = DiagnosticsLog.spinsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let file = dir.appendingPathComponent("\(stamp)-\(Bundle.main.bundleIdentifier ?? "helper").txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
        process.arguments = [String(ProcessInfo.processInfo.processIdentifier), "3", "-file", file.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] finished in
            DiagnosticsLog.shared.log("watchdog", finished.terminationStatus == 0
                ? "Spin sample written: \(file.lastPathComponent) (File → Copy Diagnostics includes it)"
                : "sample exited \(finished.terminationStatus) — no spin capture")
            self?.queue.async { self?.sampler = nil }
        }
        sampler = process
        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.log("watchdog", "Could not launch sample: \(error.localizedDescription)")
            sampler = nil
        }
    }
}
