import Foundation
import Testing
@testable import Dock_Tile

/// `isVisibleInDock` and `lastDockIndex` are written ONLY by
/// `DockTileDetailView.performDockAction()`, after the Dock add/remove actually completed
/// (architecture.md, "Visibility ownership"). An editor that saves its whole snapshot re-asserts
/// whatever was stored when the editor opened, so a change that landed meanwhile — the live
/// `DockPlistWatcher` running `syncDockVisibility()` because the user dragged the tile out of the
/// Dock — is overwritten, leaving the config claiming "visible" with nothing pinned. That desync has
/// shipped once and does not self-heal until the next launch reconcile.
///
/// Both editors now route their saves through `preservingStoredVisibility`. Failing value: a seam
/// that returns `edited` untouched — the pre-fix Customise behaviour — fails
/// `storedVisibilityWinsOverTheEditorSnapshot` on both fields.
@Suite("Visibility ownership")
struct VisibilityOwnershipTests {

    private func config(name: String, visible: Bool, dockIndex: Int?) -> DockTileConfiguration {
        var config = DockTileConfiguration(name: name)
        config.isVisibleInDock = visible
        config.lastDockIndex = dockIndex
        return config
    }

    @Test("The stored visibility and Dock index win over the editor's stale snapshot")
    func storedVisibilityWinsOverTheEditorSnapshot() {
        // The editor opened while the tile was visible at index 3, then the watcher marked it hidden.
        var edited = config(name: "Work", visible: true, dockIndex: 3)
        edited.tintColor = .preset(.purple)
        let stored = config(name: "Work", visible: false, dockIndex: nil)

        let result = ConfigurationManager.preservingStoredVisibility(edited, stored: stored)

        #expect(result.isVisibleInDock == false)
        #expect(result.lastDockIndex == nil)
    }

    @Test("Every non-visibility edit still reaches the save")
    func contentEditsSurvive() {
        var edited = config(name: "Renamed", visible: true, dockIndex: 7)
        edited.tintColor = .preset(.purple)
        edited.iconValue = "hammer.fill"
        edited.iconScale = 17
        let stored = config(name: "Original", visible: false, dockIndex: 2)

        let result = ConfigurationManager.preservingStoredVisibility(edited, stored: stored)

        #expect(result.name == "Renamed")
        #expect(result.tintColor == .preset(.purple))
        #expect(result.iconValue == "hammer.fill")
        #expect(result.iconScale == 17)
        // …and the visibility pair still came from the stored copy, not the snapshot.
        #expect(result.isVisibleInDock == false)
        #expect(result.lastDockIndex == 2)
    }

    /// A stored index of `nil` must not be treated as "no opinion" and back-filled from the editor:
    /// `nil` is the meaningful value `performDockAction` writes after a successful install, because
    /// the position is then live in the Dock rather than saved.
    @Test("A stored nil Dock index overwrites a non-nil snapshot, rather than being skipped")
    func storedNilIndexStillWins() {
        let edited = config(name: "Media", visible: true, dockIndex: 5)
        let stored = config(name: "Media", visible: true, dockIndex: nil)

        #expect(ConfigurationManager.preservingStoredVisibility(edited, stored: stored).lastDockIndex == nil)
    }

    /// An unknown id has nothing to preserve. `updateConfiguration` no-ops on one anyway, so the
    /// snapshot passes through unchanged rather than being silently blanked.
    @Test("With no stored copy the snapshot passes through untouched")
    func unknownIdPassesThrough() {
        let edited = config(name: "Fresh", visible: true, dockIndex: 4)

        let result = ConfigurationManager.preservingStoredVisibility(edited, stored: nil)

        #expect(result.isVisibleInDock == true)
        #expect(result.lastDockIndex == 4)
    }
}
