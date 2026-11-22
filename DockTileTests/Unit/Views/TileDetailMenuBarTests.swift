import Foundation
import Testing
@testable import Dock_Tile

/// Tile Detail's action button reads short (Add / Update / Remove / Done) while its tooltip and
/// accessibility label keep the place, so Remove is never read as Delete. The Show in Menu Bar
/// switch is applied by the autosave, so it never dirties the hidden tile's Done.
@Suite("Tile Detail — menu bar switch and button titles")
struct TileDetailMenuBarTests {

    @Test func buttonTitlesAreShort() {
        #expect(DockTileDetailView.actionTitle(.install, isCurrentlyInDock: false) == AppStrings.Button.dockAdd)
        #expect(DockTileDetailView.actionTitle(.install, isCurrentlyInDock: true) == AppStrings.Button.update)
        #expect(DockTileDetailView.actionTitle(.remove, isCurrentlyInDock: true) == AppStrings.Button.dockRemove)
        #expect(DockTileDetailView.actionTitle(.saveOnly, isCurrentlyInDock: false) == AppStrings.Button.done)
    }

    @Test func helpKeepsThePlace() {
        #expect(DockTileDetailView.actionHelp(.install, isCurrentlyInDock: false) == AppStrings.Button.addToDock)
        #expect(DockTileDetailView.actionHelp(.install, isCurrentlyInDock: true) == nil)
        #expect(DockTileDetailView.actionHelp(.remove, isCurrentlyInDock: true) == AppStrings.Button.removeFromDock)
        #expect(DockTileDetailView.actionHelp(.saveOnly, isCurrentlyInDock: false) == nil)
    }

    /// Failing value: `contentSignature` combining `showInMenuBar` gives the two tiles different hashes.
    @Test func menuBarSwitchLeavesDoneClean() {
        let off = DockTileConfiguration(name: "Media", showInMenuBar: false)
        var on = off
        on.showInMenuBar = true
        #expect(DockTileDetailView.contentSignature(of: off) == DockTileDetailView.contentSignature(of: on))
    }

    /// The hero is exactly as tall as the card: 3 rows → 122 pt, 4 rows (Show in Menu Bar) → 163 pt.
    /// Literal pins, so a regression back to a fixed 122 pt fails the 4-row case.
    @Test func heroMatchesTheCardHeight() {
        #expect(DockTileDetailView.heroIconSize(rows: 3) == 122)
        #expect(DockTileDetailView.heroIconSize(rows: 4) == 163)
    }
}
