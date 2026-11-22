import Foundation
import Testing
@testable import Dock_Tile

/// Turning the Menu Bar setting off asks first only while a tile is in the menu bar and not the Dock;
/// the alert names up to three tiles, then "N more".
@Suite("Menu bar off alert")
struct MenuBarOffAlertTests {
    private func tile(_ name: String, dock: Bool, menuBar: Bool) -> DockTileConfiguration {
        DockTileConfiguration(name: name, isVisibleInDock: dock, showInMenuBar: menuBar)
    }

    // MARK: - Menu-only filter

    @Test func listsOnlyMenuOnlyTiles() {
        let configs = [
            tile("Both", dock: true, menuBar: true),
            tile("MenuOnly", dock: false, menuBar: true),
            tile("DockOnly", dock: true, menuBar: false),
            tile("Neither", dock: false, menuBar: false),
        ]
        #expect(GeneralSettingsView.menuOnlyTileNames(configs) == ["MenuOnly"])
    }

    @Test func keepsSidebarOrder() {
        let configs = [
            tile("Zed", dock: false, menuBar: true),
            tile("Alpha", dock: true, menuBar: true),
            tile("Mid", dock: false, menuBar: true),
        ]
        #expect(GeneralSettingsView.menuOnlyTileNames(configs) == ["Zed", "Mid"])
    }

    // MARK: - Message

    @Test func noAlertWithoutMenuOnlyTiles() {
        #expect(GeneralSettingsView.menuBarOffMessage(names: []) == nil)
    }

    @Test func oneNameUsesTheSingularMessage() throws {
        let message = try #require(GeneralSettingsView.menuBarOffMessage(names: ["Media"]))
        #expect(message == AppStrings.Alert.menuBarOffMessageOne("Media"))
        #expect(message.hasPrefix("Media "))  // independent pin: the name leads, nothing joined around it
    }

    @Test func twoAndThreeNamesAreListed() throws {
        for names in [["Media", "Work"], ["Media", "Work", "Chat"]] {
            let message = try #require(GeneralSettingsView.menuBarOffMessage(names: names))
            #expect(message == AppStrings.Alert.menuBarOffMessageMany(ListFormatter.localizedString(byJoining: names)))
            for name in names { #expect(message.contains(name)) }
            #expect(!message.contains(AppStrings.Alert.menuBarOffMore(1)))
        }
    }

    @Test func messageNamesThreeThenCounts() throws {
        let names = ["Media", "Work", "Chat", "Fourth", "Fifth"]
        let message = try #require(GeneralSettingsView.menuBarOffMessage(names: names))
        let list = ListFormatter.localizedString(byJoining: ["Media", "Work", "Chat", AppStrings.Alert.menuBarOffMore(2)])
        #expect(message == AppStrings.Alert.menuBarOffMessageMany(list))
        // Independent of how the seam builds it: three names and the count in, the rest out.
        for name in ["Media", "Work", "Chat"] { #expect(message.contains(name)) }
        #expect(message.contains("2"))
        #expect(!message.contains("Fourth"))
        #expect(!message.contains("Fifth"))
    }

    @Test func fourNamesCountOneMore() throws {
        let message = try #require(GeneralSettingsView.menuBarOffMessage(names: ["A1", "B1", "C1", "D1"]))
        #expect(message.contains(AppStrings.Alert.menuBarOffMore(1)))
        #expect(!message.contains("D1"))
    }
}
