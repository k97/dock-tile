import Foundation
import Testing
@testable import Dock_Tile

/// cfprefsd rewrites the Dock plist by ATOMIC REPLACE. A watcher holding one descriptor sees the
/// first replacement and then watches a dead inode. Failing value: the callback count never rises
/// after the second replacement.
@MainActor
@Suite("DockPlistWatcher across atomic replaces", .serialized)
struct DockPlistWatcherReplaceTests {

    @Test("A change after an atomic replace is still reported")
    func survivesAtomicReplace() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("watcher-\(UUID().uuidString).plist")
        try Data("one".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let watcher = DockPlistWatcher(path: url.path, debounceInterval: 0.2)
        var callbacks = 0
        watcher.onDockChanged = { callbacks += 1 }
        watcher.startWatching()
        defer { watcher.stopWatching() }

        // Poll rather than sleep a fixed span: a loaded machine can delay a filesystem event well
        // past any margin worth hard-coding, and polling also returns as soon as the event lands.
        func waitForCallbackCount(above baseline: Int, timeout: TimeInterval = 5) async -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if callbacks > baseline { return true }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            return callbacks > baseline
        }

        try Data("two".utf8).write(to: url, options: .atomic)
        #expect(await waitForCallbackCount(above: 0), "no change reported for the first atomic replace")

        // Count AFTER the first replace has settled, so the second assertion cannot be satisfied by
        // leftover events from the first — that loophole would let this pass against the old code.
        let afterFirstReplace = callbacks

        try Data("three".utf8).write(to: url, options: .atomic)
        #expect(await waitForCallbackCount(above: afterFirstReplace),
                "watcher went deaf after the first atomic replace — the descriptor was left on the unlinked inode")
    }
}
