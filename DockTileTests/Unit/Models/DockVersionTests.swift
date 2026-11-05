//
//  DockVersionTests.swift
//  DockTileTests
//
//  Guards `DockTileConfiguration.dockVersion(live:snapshot:)` — what background rebuilds and helpers
//  show: the helper's sealed copy for content, the live config for bookkeeping, the live config alone
//  when no copy exists, and nothing for a deleted tile.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("Dock shows the Dock version")
struct DockVersionTests {

    private static let tileID = UUID()

    /// What the helper was built from.
    private static let copy = DockTileConfiguration(
        id: tileID,
        name: "Dev",
        iconValue: "hammer",
        layoutMode: .list,
        appItems: [AppItem(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")],
        isVisibleInDock: true,
        lastDockIndex: 2,
        helperAppVersion: "2.6.3"
    )

    /// The live config: a draft of every content field, and bookkeeping moved on since the build.
    private static let live = DockTileConfiguration(
        id: tileID,
        name: "Draft",
        iconValue: "star",
        layoutMode: .grid,
        appItems: [],
        isVisibleInDock: false,
        bundleIdentifier: "com.docktile.test.live",
        lastDockIndex: 9,
        helperAppVersion: "2.6.5"
    )

    @Test("A deleted tile is never rebuilt or shown")
    func deletedTileIsNil() {
        #expect(DockTileConfiguration.dockVersion(live: nil, snapshot: Self.copy) == nil)
    }

    @Test("No copy yet → the live config, unchanged")
    func noCopyFallsBackToLive() {
        #expect(DockTileConfiguration.dockVersion(live: Self.live, snapshot: nil) == Self.live)
    }

    @Test("With a copy → content from the copy, bookkeeping from the live config")
    func copyWinsForContent() throws {
        let shown = try #require(DockTileConfiguration.dockVersion(live: Self.live, snapshot: Self.copy))
        #expect(shown.name == "Dev")
        #expect(shown.iconValue == "hammer")
        #expect(shown.layoutMode == .list)
        #expect(shown.appItems.map(\.bundleIdentifier) == ["com.apple.dt.Xcode"])
        #expect(shown.bundleIdentifier == "com.docktile.test.live")
        #expect(shown.isVisibleInDock == false)
        #expect(shown.lastDockIndex == 9)
        #expect(shown.helperAppVersion == "2.6.5")
    }

    @Test("Another tile's copy → the live config")
    func otherTilesCopyIsIgnored() {
        let other = Self.copy.duplicate(named: "Other")
        #expect(DockTileConfiguration.dockVersion(live: Self.live, snapshot: other) == Self.live)
    }
}
