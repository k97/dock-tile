//
//  DockSnapshotRevertTests.swift
//  DockTileTests
//
//  Guards Revert to Dock Version: `DockTileConfiguration.revertingContent(to:)` takes every content
//  field from the copy sealed into the helper at build time and keeps the current Dock bookkeeping;
//  `HelperBundleManager.writeDockSnapshot` / `readDockSnapshot` round-trip that copy through the bundle.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("Revert to Dock Version")
struct DockSnapshotRevertTests {

    /// Owned by Dock operations, never by Revert.
    private static let bookkeepingKeys: Set<String> = [
        "id", "bundleIdentifier", "isVisibleInDock", "lastDockIndex", "helperAppVersion"
    ]

    private static let tileID = UUID()

    /// What the helper was built from: every content field away from a new tile's default.
    private static let snapshot = DockTileConfiguration(
        id: tileID,
        name: "Media",
        tintColor: .custom("#5F00FF"),
        symbolEmoji: "🎬",
        iconType: .emoji,
        iconValue: "🎬",
        iconScale: 18,
        iconWeight: .bold,
        background: .mono,
        iconFace: .glyph,
        appsBackground: .custom,
        appsBackgroundColor: "#224466",
        savedSymbol: SavedGlyph(value: "bolt", scale: 16),
        savedEmoji: SavedGlyph(value: "🍿", scale: 20),
        layoutMode: .list,
        appItems: [AppItem(bundleIdentifier: "com.apple.TV", name: "TV", lastKnownPath: "/System/Applications/TV.app")],
        isVisibleInDock: true,
        showInAppSwitcher: true,
        lastDockIndex: 3,
        helperAppVersion: "2.6.3"
    )

    /// The draft: same tile, every content field at its default, every bookkeeping field different.
    private static let draft = DockTileConfiguration(
        id: tileID,
        isVisibleInDock: false,
        bundleIdentifier: "com.docktile.test.draft",
        lastDockIndex: 7,
        helperAppVersion: "2.6.4"
    )

    private func json(_ config: DockTileConfiguration) throws -> [String: Any] {
        let data = try JSONEncoder().encode(config)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?): return (a as AnyObject).isEqual(b)
        default: return false
        }
    }

    @Test("Revert takes every content field from the copy and keeps the draft's bookkeeping")
    func revertTakesEveryContentFieldFromTheCopy() throws {
        let snapshot = try json(Self.snapshot)
        let draft = try json(Self.draft)
        let reverted = try json(Self.draft.revertingContent(to: Self.snapshot))
        for key in Set(snapshot.keys).union(draft.keys).union(reverted.keys) {
            if Self.bookkeepingKeys.contains(key) {
                #expect(same(reverted[key], draft[key]), "'\(key)' is bookkeeping — Revert must keep the draft's")
            } else {
                // The fixture is only a guard if the two sides differ on every content key.
                #expect(!same(snapshot[key], draft[key]), "'\(key)' is equal in the fixture — make the snapshot set it")
                #expect(same(reverted[key], snapshot[key]), "'\(key)' was not reverted to the Dock copy")
            }
        }
    }

    @Test("Another tile's copy is ignored")
    func revertIgnoresAnotherTilesCopy() {
        var other = Self.snapshot.duplicate(named: "Other")
        other.lastDockIndex = 1
        #expect(Self.draft.revertingContent(to: other) == Self.draft)
    }

    @Test("Reverting a tile that matches its copy changes nothing")
    func revertOfAnUnchangedTileIsANoOp() {
        let unchanged = Self.draft.revertingContent(to: Self.snapshot)
        #expect(unchanged.revertingContent(to: Self.snapshot) == unchanged)
    }

    @Test("A healed path stays live; an item only in the copy keeps its own")
    func revertKeepsTheLivePathPerItem() throws {
        let kept = UUID(), removed = UUID()
        var copy = Self.snapshot
        copy.appItems = [
            AppItem(id: kept, bundleIdentifier: "com.apple.TV", name: "TV", lastKnownPath: "/Applications/Old/TV.app"),
            AppItem(id: removed, bundleIdentifier: "com.apple.Music", name: "Music", lastKnownPath: "/System/Applications/Music.app"),
        ]
        var live = Self.draft
        // The missing-app scan healed TV's path; the draft also renamed it and dropped Music.
        live.appItems = [AppItem(id: kept, bundleIdentifier: "com.apple.TV", name: "Renamed", lastKnownPath: "/Applications/TV.app")]

        let items = live.revertingContent(to: copy).appItems
        try #require(items.count == 2)
        #expect(items[0].lastKnownPath == "/Applications/TV.app")  // bookkeeping: live
        #expect(items[0].name == "TV")                             // content: the copy
        #expect(items[1].lastKnownPath == "/System/Applications/Music.app")
    }

    @Test("The copy round-trips through the helper bundle")
    func snapshotRoundTripsThroughTheBundleFile() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("DockSnapshotRevertTests-\(UUID().uuidString)")
        let bundle = base.appendingPathComponent("Tile.app")
        try FileManager.default.createDirectory(at: bundle.appendingPathComponent("Contents/Resources"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        #expect(HelperBundleManager.readDockSnapshot(inBundle: bundle) == nil)  // built before this change
        try HelperBundleManager.writeDockSnapshot(Self.snapshot, inBundle: bundle)
        #expect(HelperBundleManager.readDockSnapshot(inBundle: bundle) == Self.snapshot)
    }
}
