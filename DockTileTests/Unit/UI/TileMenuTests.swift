import Testing
@testable import Dock_Tile

/// The tile menu shared by the menu bar icon and the Dock menus (issue #13). Failing value: a
/// missing app listed as launchable, apps out of tile order, or a hidden tile in the menus.
@Suite("Tile menu entries")
struct TileMenuTests {

    private let mail = AppItem(bundleIdentifier: "com.apple.mail", name: "Mail")
    private let gone = AppItem(bundleIdentifier: "com.example.gone", name: "Gone")

    private func tile(_ name: String, _ apps: [AppItem]) -> DockTileConfiguration {
        var config = DockTileConfiguration(name: name)
        config.appItems = apps
        return config
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

    @Test("A tile with Show Tile off is not in the menus; order is kept")
    func hiddenTilesAreLeftOut() {
        var hidden = tile("Hidden", [mail])
        hidden.isVisibleInDock = false
        let listed = TileMenu.menuTiles([tile("Work", []), hidden, tile("Dev", [])])
        #expect(listed.map(\.name) == ["Work", "Dev"])
    }
}
