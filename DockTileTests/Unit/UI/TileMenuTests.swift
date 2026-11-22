import Foundation
import Testing
@testable import Dock_Tile

/// The tile menu shared by the menu bar icon and the Dock menus (issue #13). Failing value: a
/// missing app listed as launchable, apps out of tile order, or a tile listed in the wrong place
/// (the Dock menu follows Show in Dock, the menu bar menu Show in Menu Bar).
@Suite("Tile menu entries")
struct TileMenuTests {

    private let mail = AppItem(bundleIdentifier: "com.apple.mail", name: "Mail")
    private let gone = AppItem(bundleIdentifier: "com.example.gone", name: "Gone")

    private func tile(_ name: String, _ apps: [AppItem]) -> DockTileConfiguration {
        var config = DockTileConfiguration(name: name)
        config.appItems = apps
        return config
    }

    private func tile(_ name: String, dock: Bool, menuBar: Bool) -> DockTileConfiguration {
        DockTileConfiguration(name: name, isVisibleInDock: dock, showInMenuBar: menuBar)
    }

    @Test("Apps keep tile order; a missing app stays listed but disabled")
    func missingAppIsDisabled() {
        let rows = TileMenu.rows(for: tile("Work", [mail, gone]),
                                 isInstalled: { $0.bundleIdentifier != "com.example.gone" })
        #expect(rows.map(\.item.name) == ["Mail", "Gone"])
        #expect(rows.map(\.enabled) == [true, false])
    }

    @Test("An empty tile has no rows")
    func emptyTileHasNoRows() {
        #expect(TileMenu.rows(for: tile("Empty", []), isInstalled: { _ in true }).isEmpty)
    }

    @Test("A tile with Show in Dock off is not in the Dock menu; order is kept")
    func hiddenTilesAreLeftOut() {
        var hidden = tile("Hidden", [mail])
        hidden.isVisibleInDock = false
        let listed = TileMenu.menuTiles([tile("Work", []), hidden, tile("Dev", [])], in: .dock)
        #expect(listed.map(\.name) == ["Work", "Dev"])
    }

    /// Failing value: a `.menuBar` filter on `isVisibleInDock` lists C and drops B.
    @Test("The menu bar menu follows Show in Menu Bar, the Dock menu Show in Dock; order is kept")
    func menuBarIgnoresDockVisibility() {
        let tiles = [tile("A", dock: true, menuBar: true),
                     tile("B", dock: false, menuBar: true),
                     tile("C", dock: true, menuBar: false)]
        #expect(TileMenu.menuTiles(tiles, in: .menuBar).map(\.name) == ["A", "B"])
        #expect(TileMenu.menuTiles(tiles, in: .dock).map(\.name) == ["A", "C"])
    }

    @Test("With Show in Menu Bar off on every tile, the menu bar menu lists none")
    func noMenuBarTilesLeavesNoRows() {
        let tiles = [tile("A", dock: true, menuBar: false), tile("B", dock: false, menuBar: false)]
        #expect(TileMenu.menuTiles(tiles, in: .menuBar).isEmpty)
    }

    /// A 2.7.x config has no `showInMenuBar` key; its menu bar menu listed the Dock's tiles.
    /// Failing value: a missing key decoding to a constant (all or none) instead of Dock visibility.
    @Test("After upgrade the menu bar lists exactly the tiles it listed before")
    func menuBarListsWhatTheDockDidBeforeUpgrade() throws {
        let stored = [tile("Work", dock: true, menuBar: false),
                      tile("Hidden", dock: false, menuBar: true),
                      tile("Dev", dock: true, menuBar: false)]
        let data = try JSONEncoder().encode(stored)
        var objects = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        for index in objects.indices {
            try #require(objects[index].removeValue(forKey: "showInMenuBar") != nil)
        }
        let decoded = try JSONDecoder().decode([DockTileConfiguration].self,
                                               from: JSONSerialization.data(withJSONObject: objects))

        let menuBar = TileMenu.menuTiles(decoded, in: .menuBar).map(\.name)
        #expect(menuBar == ["Work", "Dev"])
        #expect(menuBar == TileMenu.menuTiles(decoded, in: .dock).map(\.name))
    }
}
