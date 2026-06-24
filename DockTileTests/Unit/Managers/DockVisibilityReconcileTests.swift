//
//  DockVisibilityReconcileTests.swift
//  DockTileTests
//
//  Guards the Dock visibility reconciliation rules — the source of several past "hidden in
//  config but still pinned" / "new tile never pins" regressions. Exercises the pure
//  `ConfigurationManager.resolveDockVisibility(...)` seam directly so each rule (and the
//  never-pinned guard) fails loudly if changed.
//

import Testing
@testable import Dock_Tile

@Suite("Dock visibility reconciliation rules")
struct DockVisibilityReconcileTests {

    private func resolve(
        visible: Bool,
        inDock: Bool,
        helperExists: Bool,
        reconcile: Bool
    ) -> ConfigurationManager.DockVisibilityResolution {
        ConfigurationManager.resolveDockVisibility(
            isVisibleInConfig: visible,
            isActuallyInDock: inDock,
            helperExists: helperExists,
            reconcileDockedHiddenTiles: reconcile
        )
    }

    // MARK: - Direction 1: visible in config, absent from Dock

    @Test("Visible + absent + WAS pinned → mark hidden")
    func direction1MarksHidden() {
        #expect(resolve(visible: true, inDock: false, helperExists: true, reconcile: false) == .markHidden)
        // Reconcile flag is irrelevant to direction 1.
        #expect(resolve(visible: true, inDock: false, helperExists: true, reconcile: true) == .markHidden)
    }

    /// THE never-pinned guard. A brand-new tile defaults to visible but has no helper bundle
    /// until the user clicks Add to Dock. It must NOT be flipped hidden, or the action button
    /// degrades "Add to Dock" → "Done" and the tile never pins. If someone deletes the
    /// `helperExists` guard, this test goes red.
    @Test("Visible + absent + NEVER pinned → skip (never-pinned guard)")
    func direction1NeverPinnedGuard() {
        #expect(resolve(visible: true, inDock: false, helperExists: false, reconcile: false) == .skipNeverPinned)
        #expect(resolve(visible: true, inDock: false, helperExists: false, reconcile: true) == .skipNeverPinned)
    }

    // MARK: - Direction 2: hidden in config, still pinned

    @Test("Hidden + still pinned + reconcile ON → remove from Dock")
    func direction2RemovesWhenReconciling() {
        #expect(resolve(visible: false, inDock: true, helperExists: false, reconcile: true) == .removeFromDock)
    }

    /// The destructive removal restarts the Dock, so the LIVE watcher path (reconcile = false)
    /// must never trigger it — otherwise a removal could fight the user / spin a restart loop.
    @Test("Hidden + still pinned + reconcile OFF → keep (no destructive removal on watcher path)")
    func direction2KeepsWhenNotReconciling() {
        #expect(resolve(visible: false, inDock: true, helperExists: false, reconcile: false) == .keepStuckPinned)
    }

    // MARK: - Already in sync

    @Test("In-sync states are a no-op", arguments: [
        (true, true),    // visible and pinned
        (false, false)   // hidden and absent
    ])
    func inSyncIsNoop(_ visible: Bool, _ inDock: Bool) {
        // helperExists / reconcile must not matter when already consistent.
        #expect(resolve(visible: visible, inDock: inDock, helperExists: true, reconcile: true) == .inSync)
        #expect(resolve(visible: visible, inDock: inDock, helperExists: false, reconcile: false) == .inSync)
    }
}
