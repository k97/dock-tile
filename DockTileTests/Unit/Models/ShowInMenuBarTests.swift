//
//  ShowInMenuBarTests.swift
//  DockTileTests
//
//  Guards `DockTileConfiguration.showInMenuBar` (schema v13): an old config with no key lists in the
//  menu bar exactly when it is in the Dock (what the 2.7.x menu showed), the field round-trips, and it
//  is never part of what the helper shows — no Update prompt, no dirty edit, kept by Revert, and off
//  on a duplicate.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("Show in Menu Bar field")
struct ShowInMenuBarTests {

    /// `config` encoded, with the `showInMenuBar` key removed — what a 2.7.x config file holds.
    private func decodedWithoutKey(_ config: DockTileConfiguration) throws -> DockTileConfiguration {
        let data = try JSONEncoder().encode(config)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        try #require(object.removeValue(forKey: "showInMenuBar") != nil)
        let stripped = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(DockTileConfiguration.self, from: stripped)
    }

    /// Failing value: a fallback to `ConfigurationDefaults.showInMenuBar` (false) fails the first
    /// expectation; a literal `true` fails the second.
    @Test("A config without the key takes the tile's own Dock visibility")
    func decodesMissingKeyFromDockVisibility() throws {
        let inDock = try decodedWithoutKey(DockTileConfiguration(isVisibleInDock: true, showInMenuBar: false))
        #expect(inDock.showInMenuBar == true)

        let hidden = try decodedWithoutKey(DockTileConfiguration(isVisibleInDock: false, showInMenuBar: true))
        #expect(hidden.showInMenuBar == false)
    }

    @Test("A stored value survives encode and decode, independent of the Dock")
    func roundTrips() throws {
        let config = DockTileConfiguration(isVisibleInDock: false, showInMenuBar: true)
        let decoded = try JSONDecoder().decode(DockTileConfiguration.self, from: JSONEncoder().encode(config))
        #expect(decoded.showInMenuBar == true)
        #expect(decoded.isVisibleInDock == false)
    }

    @Test("Flipping it moves neither the Dock signature nor the editor's content signature")
    func notPartOfWhatTheHelperShows() {
        let off = DockTileConfiguration(name: "Media", showInMenuBar: false)
        var on = off
        on.showInMenuBar = true
        #expect(on.dockSignature == off.dockSignature)
        #expect(DockTileDetailView.contentSignature(of: on) == DockTileDetailView.contentSignature(of: off))
    }

    @Test("Revert keeps the live value, not the Dock copy's")
    func revertKeepsLiveValue() {
        let id = UUID()
        let live = DockTileConfiguration(id: id, name: "Draft", showInMenuBar: true)
        let snapshot = DockTileConfiguration(id: id, name: "Built", showInMenuBar: false)
        #expect(live.revertingContent(to: snapshot).showInMenuBar == true)
    }

    @Test("A duplicate starts out of the menu bar, as it starts out of the Dock")
    func duplicateStartsOff() {
        let source = DockTileConfiguration(name: "Media", showInMenuBar: true)
        #expect(source.duplicate(named: "Media 1").showInMenuBar == false)
    }
}
