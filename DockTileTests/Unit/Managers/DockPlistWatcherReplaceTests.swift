import Foundation
import Testing
@testable import Dock_Tile

/// cfprefsd rewrites the Dock plist by ATOMIC REPLACE. A watcher holding one descriptor sees the
/// first replacement and then watches a dead inode. Failing value: 1 callback for 2 replacements.
@MainActor
@Suite("DockPlistWatcher across atomic replaces", .serialized)
struct DockPlistWatcherReplaceTests {

    @Test("Two atomic replacements produce two change callbacks")
    func survivesAtomicReplace() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("watcher-\(UUID().uuidString).plist")
        try Data("one".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        // 0.2 s, not 0.05: one atomic replace can emit .write/.attrib/.delete, and a debounce
        // shorter than the gap between them would report a third callback and fail for no real reason.
        let watcher = DockPlistWatcher(path: url.path, debounceInterval: 0.2)
        var callbacks = 0
        watcher.onDockChanged = { callbacks += 1 }
        watcher.startWatching()
        defer { watcher.stopWatching() }

        try Data("two".utf8).write(to: url, options: .atomic)
        try await Task.sleep(nanoseconds: 400_000_000)
        try Data("three".utf8).write(to: url, options: .atomic)
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(callbacks == 2)
    }
}
