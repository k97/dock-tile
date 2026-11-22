//
//  DockTileDuplicateTests.swift
//  DockTileTests
//
//  Guards `DockTileConfiguration.duplicate(named:)` (issue #21): a duplicate must look exactly like
//  its original — only its identity, name and Dock bookkeeping are new. Compared through the
//  encoded JSON so a field added to the model later is checked without editing this file, as long
//  as the sample below sets it (the coverage test fails until it does).
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("Duplicate tile keeps its look")
struct DockTileDuplicateTests {

    /// Keys a duplicate must NOT share with its original: identity, name and Dock bookkeeping.
    private static let resetKeys: Set<String> = [
        "id", "name", "bundleIdentifier", "isVisibleInDock", "showInMenuBar", "lastDockIndex", "helperAppVersion"
    ]

    /// Every content field set to something other than a new tile's default.
    private static let original = DockTileConfiguration(
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
        showInMenuBar: true,
        showInAppSwitcher: true,
        lastDockIndex: 3,
        helperAppVersion: "2.2.0"
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

    @Test("The sample tile sets every content field away from a new tile's default")
    func sampleCoversEveryContentField() throws {
        let sample = try json(Self.original)
        let fresh = try json(DockTileConfiguration())
        for key in Set(sample.keys).union(fresh.keys).subtracting(Self.resetKeys) {
            #expect(!same(sample[key], fresh[key]),
                    "'\(key)' equals a new tile's default in the sample — set it to a non-default value so the duplicate test checks it")
        }
    }

    @Test("A duplicate keeps every content field of its original")
    func duplicateKeepsContent() throws {
        let original = try json(Self.original)
        let copy = try json(Self.original.duplicate(named: "Media 1"))
        for key in Set(original.keys).union(copy.keys).subtracting(Self.resetKeys) {
            #expect(same(original[key], copy[key]), "'\(key)' was not copied to the duplicate")
        }
    }

    @Test("A duplicate gets its own identity and starts unpinned")
    func duplicateResetsIdentity() {
        let copy = Self.original.duplicate(named: "Media 1")
        #expect(copy.id != Self.original.id)
        #expect(copy.name == "Media 1")
        #expect(copy.bundleIdentifier == "\(AppEnvironment.helperBundlePrefix).\(copy.id.uuidString)")
        #expect(copy.isVisibleInDock == false)
        #expect(copy.lastDockIndex == nil)
        #expect(copy.helperAppVersion == nil)
    }
}
