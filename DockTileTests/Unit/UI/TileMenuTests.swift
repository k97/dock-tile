import Testing
@testable import Dock_Tile

/// The tile menu shared by the menu bar icon and the Dock menus (issue #13). Failing value: a
/// missing app listed as launchable, or tiles out of sidebar order.
@Suite("Tile menu entries")
struct TileMenuTests {

    private let mail = AppItem(bundleIdentifier: "com.apple.mail", name: "Mail")
    private let gone = AppItem(bundleIdentifier: "com.example.gone", name: "Gone")

    private func tile(_ name: String, _ apps: [AppItem]) -> DockTileConfiguration {
        var config = DockTileConfiguration(name: name)
        config.appItems = apps
        return config
    }

    @Test("Tiles keep the order they are given; apps keep tile order")
    func orderIsKept() {
        let entries = TileMenu.entries(for: [tile("Work", [mail, gone]), tile("Dev", [])],
                                       isInstalled: { _ in true })
        #expect(entries.map(\.config.name) == ["Work", "Dev"])
        #expect(entries[0].rows.map(\.item.name) == ["Mail", "Gone"])
    }

    @Test("A missing app stays listed but disabled")
    func missingAppIsDisabled() throws {
        let entries = TileMenu.entries(for: [tile("Work", [mail, gone])],
                                       isInstalled: { $0.bundleIdentifier != "com.example.gone" })
        let rows = try #require(entries.first).rows
        #expect(rows.map(\.enabled) == [true, false])
    }

    @Test("An empty tile has no rows")
    func emptyTileHasNoRows() throws {
        let entries = TileMenu.entries(for: [tile("Empty", [])], isInstalled: { _ in true })
        #expect(try #require(entries.first).rows.isEmpty)
    }

    @Test("No tiles, no entries")
    func noTiles() {
        #expect(TileMenu.entries(for: [], isInstalled: { _ in true }).isEmpty)
    }

    @Test("A tile with Show Tile off is not in the menus; order is kept")
    func hiddenTilesAreLeftOut() {
        var hidden = tile("Hidden", [mail])
        hidden.isVisibleInDock = false
        let listed = TileMenu.menuTiles([tile("Work", []), hidden, tile("Dev", [])])
        #expect(listed.map(\.name) == ["Work", "Dev"])
    }
}
