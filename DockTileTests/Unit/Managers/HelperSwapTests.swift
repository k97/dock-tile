import Foundation
import Testing
@testable import Dock_Tile

/// The 2.6.3 staged rebuild: a tile's new bundle is built in a hidden staging folder and swapped in
/// with one atomic rename, so the tile's folder never holds a half-built bundle (or a copy of the
/// main app carrying its bundle id — what the 2026-10-29 Force Quit hit). Failing values: a swap
/// that leaves `final` missing or old on success, one that destroys the old bundle when the new one
/// is absent, an old-folder rule that deletes the NEW bundle when two spellings of one path differ,
/// and a lock two builds of one tile can both take.
@Suite("Staged helper rebuild: staging, swap, lock", .serialized)
struct HelperSwapTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HelperSwapTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let real = try #require(realpath(dir.path, nil))
        defer { free(real) }
        return URL(fileURLWithPath: String(cString: real), isDirectory: true)
    }

    private func makeBundle(_ url: URL, marker: String) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try marker.write(to: url.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
    }

    private func marker(_ url: URL) -> String? {
        try? String(contentsOf: url.appendingPathComponent("marker"), encoding: .utf8)
    }

    @Test("Staging is a hidden folder beside the tiles, one bundle per tile id")
    func stagingIsHiddenAndBesideTheTiles() {
        let url = HelperBundleManager.stagingBundleURL(helperDirectory: URL(fileURLWithPath: "/x"),
                                                       bundleId: "com.docktile.dev.A")
        #expect(url.path == "/x/.staging/com.docktile.dev.A.app")
        #expect(url.deletingLastPathComponent().lastPathComponent.hasPrefix("."))
        #expect(HelperBundleManager.stagingDirectory(helperDirectory: URL(fileURLWithPath: "/x")).path == "/x/.staging")
    }

    @Test("Swapping over an existing bundle puts the new one in place and removes the old")
    func swapIntoPlaceExchangesAnExistingBundle() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let final = dir.appendingPathComponent("Tile.app"), staged = dir.appendingPathComponent(".staging/A.app")
        try makeBundle(final, marker: "old")
        try makeBundle(staged, marker: "new")

        try HelperBundleManager.swapIntoPlace(staged: staged, final: final)

        #expect(marker(final) == "new")
        #expect(!FileManager.default.fileExists(atPath: staged.path))
    }

    @Test("Swapping into an empty path is a plain move")
    func swapIntoPlaceIntoEmptyPath() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let final = dir.appendingPathComponent("Tile.app"), staged = dir.appendingPathComponent(".staging/A.app")
        try makeBundle(staged, marker: "new")

        try HelperBundleManager.swapIntoPlace(staged: staged, final: final)

        #expect(marker(final) == "new")
        #expect(!FileManager.default.fileExists(atPath: staged.path))
    }

    @Test("A missing staged bundle throws and leaves the old tile untouched")
    func swapKeepsTheOldBundleWhenStagingIsMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let final = dir.appendingPathComponent("Tile.app"), staged = dir.appendingPathComponent(".staging/A.app")
        try makeBundle(final, marker: "old")

        #expect(throws: HelperBundleError.bundleCopyFailed) {
            try HelperBundleManager.swapIntoPlace(staged: staged, final: final)
        }
        #expect(marker(final) == "old")
    }

    @Test("Two spellings of the same folder are the same folder: nothing is removed")
    func oldFolderIsKeptWhenItIsTheSamePath() {
        let slashed = URL(fileURLWithPath: "/x/A.app/"), bare = URL(fileURLWithPath: "/x/A.app")
        #expect(HelperBundleManager.oldFolderToRemove(existing: slashed, final: bare) == nil)
        #expect(HelperBundleManager.oldFolderToRemove(existing: bare, final: slashed) == nil)
        #expect(HelperBundleManager.oldFolderToRemove(existing: URL(string: "file:///x/A.app/"), final: bare) == nil)
        #expect(HelperBundleManager.oldFolderToRemove(existing: nil, final: bare) == nil)
    }

    /// Final review, 2026-10-31: on case-insensitive APFS (the default) a tile renamed "utils" →
    /// "Utils" gets `final = …/Utils.app` (it "exists") while `findExistingHelper` returns the disk
    /// spelling `…/utils.app`. Compared as strings they differ, and removing the "old" folder after
    /// the swap deleted the NEW bundle. Same file on disk → nothing to remove.
    @Test("A case-only rename is the same folder on disk: nothing is removed")
    func oldFolderIsKeptOnACaseOnlyRename() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try makeBundle(dir.appendingPathComponent("utils.app"), marker: "tile")

        #expect(HelperBundleManager.oldFolderToRemove(existing: dir.appendingPathComponent("utils.app"),
                                                      final: dir.appendingPathComponent("Utils.app")) == nil)
    }

    @Test("After a rename the old folder is the one removed")
    func oldFolderIsRemovedAfterARename() {
        let old = URL(fileURLWithPath: "/x/Old.app")
        #expect(HelperBundleManager.oldFolderToRemove(existing: old, final: URL(fileURLWithPath: "/x/New.app")) == old)
    }

    @Test("A second build lock for the same tile is refused until the first is released")
    func secondLockForTheSameTileIsRefused() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = try #require(TileBuildLock.acquire(bundleId: "A", stagingDirectory: dir))
        #expect(TileBuildLock.acquire(bundleId: "A", stagingDirectory: dir) == nil)
        let other = TileBuildLock.acquire(bundleId: "B", stagingDirectory: dir)
        #expect(other != nil)

        first.release()
        #expect(TileBuildLock.acquire(bundleId: "A", stagingDirectory: dir) != nil)
        other?.release()
    }

    @Test("Stale staging bundles are removed unless their tile's build still holds the lock")
    func staleStagingIsRemovedOnlyWhenUnlocked() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try makeBundle(dir.appendingPathComponent("A.app"), marker: "a")
        try makeBundle(dir.appendingPathComponent("B.app"), marker: "b")
        let held = try #require(TileBuildLock.acquire(bundleId: "B", stagingDirectory: dir))
        defer { held.release() }

        let removed = HelperBundleManager.removeStaleStaging(stagingDirectory: dir)

        #expect(removed == ["A.app"])
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("A.app").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("B.app").path))
    }
}
