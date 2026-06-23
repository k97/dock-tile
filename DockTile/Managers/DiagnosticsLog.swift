//
//  DiagnosticsLog.swift
//  DockTile
//
//  Lightweight in-process diagnostics ring buffer. Captures recent app events
//  (lifecycle, Sparkle updates, Dock operations, errors) so the user can run
//  File > Copy Diagnostics and paste a report when something goes wrong.
//
//  Thread-safe — safe to call `log(_:_:)` from any thread. Mirrors to the unified
//  log (subsystem "com.docktile.diagnostics") so events also show in Console.app.
//

import AppKit
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
    private var entries: [Entry] = []

    /// Keep roughly the last hour, with a hard count cap as a memory backstop.
    private let retention: TimeInterval = 3600
    private let hardCap = 2000

    private let logger = Logger(subsystem: "com.docktile.diagnostics", category: "app")

    private let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    /// Record a diagnostic event. `category` is a short tag, e.g. "update", "dock", "lifecycle".
    func log(_ category: String, _ message: String) {
        let entry = Entry(date: Date(), category: category, message: message)
        lock.lock()
        entries.append(entry)
        pruneLocked(now: entry.date)
        lock.unlock()
        logger.notice("[\(category, privacy: .public)] \(message, privacy: .public)")
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

    /// A human-readable report: environment header + the last hour of events.
    func report() -> String {
        lock.lock()
        let snapshot = entries
        lock.unlock()

        let os = ProcessInfo.processInfo.operatingSystemVersion
        var lines: [String] = [
            "Dock Tile Diagnostics",
            "Generated:  \(stamp.string(from: Date()))",
            "Version:    \(AppEnvironment.appVersion) (\(AppEnvironment.current))",
            "Role:       \(AppEnvironment.appRole)",
            "Bundle:     \(Bundle.main.bundleIdentifier ?? "unknown")",
            "macOS:      \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "Events:     \(snapshot.count) in the last hour",
            String(repeating: "—", count: 48)
        ]
        if snapshot.isEmpty {
            lines.append("(no diagnostic events recorded in the last hour)")
        } else {
            for e in snapshot {
                lines.append("\(stamp.string(from: e.date))  [\(e.category)]  \(e.message)")
            }
        }
        return lines.joined(separator: "\n")
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
