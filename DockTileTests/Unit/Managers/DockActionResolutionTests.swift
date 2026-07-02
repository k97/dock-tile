//
//  DockActionResolutionTests.swift
//  DockTileTests
//
//  Guards the Dock action rules behind the Tile Detail toolbar button — the source of the
//  "Dock restarts on every Done / on never-pinned tiles" regressions. Three pure seams:
//
//  1. `DockTileDetailView.resolveDockAction` — which operation the button performs. The
//     critical case is `saveOnly` (hidden AND not pinned): it must never reach
//     HelperBundleManager, so the Dock is never restarted for a no-op save.
//  2. `DockTileDetailView.dockActionIsEnabled` — Dock-touching actions stay enabled (the
//     pending Dock op IS the change; Update deliberately re-renders on demand), while the
//     saveOnly "Done" disables until there are new edits.
//  3. `DockTileDetailView.contentSignature` — the dirty fingerprint. Must track every
//     user-editable field but ignore the bookkeeping performDockAction writes back
//     (`lastDockIndex`, `helperAppVersion`) and `isVisibleInDock`, or a completed action
//     would immediately re-dirty (or never clean) the button.
//  4. `HelperBundleManager.shouldPerformDockRemoval` — the removal path's no-op guard: no
//     Dock plist entry AND no running helper ⇒ nothing to do, Dock must NOT be restarted.
//

import Testing
@testable import Dock_Tile

@Suite("Dock action resolution rules")
struct DockActionResolutionTests {

    // MARK: - resolveDockAction (full matrix)

    @Test("Visible + not pinned → install (Add to Dock)")
    func visibleNotPinnedInstalls() {
        #expect(DockTileDetailView.resolveDockAction(isVisibleInDock: true, isCurrentlyInDock: false) == .install)
    }

    @Test("Visible + pinned → install (Update re-renders the helper)")
    func visiblePinnedInstalls() {
        #expect(DockTileDetailView.resolveDockAction(isVisibleInDock: true, isCurrentlyInDock: true) == .install)
    }

    @Test("Hidden + still pinned → remove")
    func hiddenPinnedRemoves() {
        #expect(DockTileDetailView.resolveDockAction(isVisibleInDock: false, isCurrentlyInDock: true) == .remove)
    }

    /// THE regression case: hidden and not pinned means there is NO Dock work. If this stops
    /// resolving to `saveOnly`, every "Done" on a hidden tile restarts the Dock again.
    @Test("Hidden + not pinned → saveOnly (never touches the Dock)")
    func hiddenNotPinnedSavesOnly() {
        #expect(DockTileDetailView.resolveDockAction(isVisibleInDock: false, isCurrentlyInDock: false) == .saveOnly)
    }

    // MARK: - dockActionIsEnabled

    @Test("Install and remove are enabled regardless of dirty state")
    func dockTouchingActionsAlwaysEnabled() {
        #expect(DockTileDetailView.dockActionIsEnabled(action: .install, isDirty: false, isProcessing: false))
        #expect(DockTileDetailView.dockActionIsEnabled(action: .install, isDirty: true, isProcessing: false))
        #expect(DockTileDetailView.dockActionIsEnabled(action: .remove, isDirty: false, isProcessing: false))
        #expect(DockTileDetailView.dockActionIsEnabled(action: .remove, isDirty: true, isProcessing: false))
    }

    @Test("saveOnly Done requires new edits")
    func saveOnlyRequiresDirty() {
        #expect(!DockTileDetailView.dockActionIsEnabled(action: .saveOnly, isDirty: false, isProcessing: false))
        #expect(DockTileDetailView.dockActionIsEnabled(action: .saveOnly, isDirty: true, isProcessing: false))
    }

    @Test("Everything is disabled while processing")
    func processingDisablesAll() {
        #expect(!DockTileDetailView.dockActionIsEnabled(action: .install, isDirty: true, isProcessing: true))
        #expect(!DockTileDetailView.dockActionIsEnabled(action: .remove, isDirty: true, isProcessing: true))
        #expect(!DockTileDetailView.dockActionIsEnabled(action: .saveOnly, isDirty: true, isProcessing: true))
    }

    // MARK: - contentSignature

    private func makeConfig() -> DockTileConfiguration {
        DockTileConfiguration(
            name: "Work",
            tintColor: .preset(.blue),
            iconType: .sfSymbol,
            iconValue: "folder",
            appItems: [
                AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari"),
                AppItem(bundleIdentifier: "com.apple.mail", name: "Mail")
            ]
        )
    }

    @Test("Identical content → identical signature")
    func signatureIsStable() {
        let config = makeConfig()
        #expect(DockTileDetailView.contentSignature(of: config) == DockTileDetailView.contentSignature(of: config))
    }

    @Test("Every user-editable field changes the signature")
    func userEditsChangeSignature() {
        let base = makeConfig()
        let baseSignature = DockTileDetailView.contentSignature(of: base)

        var renamed = base
        renamed.name = "Play"
        #expect(DockTileDetailView.contentSignature(of: renamed) != baseSignature)

        var retinted = base
        retinted.tintColor = .preset(.red)
        #expect(DockTileDetailView.contentSignature(of: retinted) != baseSignature)

        var reiconed = base
        reiconed.iconValue = "star"
        #expect(DockTileDetailView.contentSignature(of: reiconed) != baseSignature)

        var rescaled = base
        rescaled.iconScale += 1
        #expect(DockTileDetailView.contentSignature(of: rescaled) != baseSignature)

        var relaidOut = base
        relaidOut.layoutMode = .list
        #expect(DockTileDetailView.contentSignature(of: relaidOut) != baseSignature)

        var switched = base
        switched.showInAppSwitcher.toggle()
        #expect(DockTileDetailView.contentSignature(of: switched) != baseSignature)

        var appsChanged = base
        appsChanged.appItems.append(AppItem(bundleIdentifier: "com.apple.Notes", name: "Notes"))
        #expect(DockTileDetailView.contentSignature(of: appsChanged) != baseSignature)

        var appsRemoved = base
        appsRemoved.appItems.removeLast()
        #expect(DockTileDetailView.contentSignature(of: appsRemoved) != baseSignature)
    }

    /// Bookkeeping written back by performDockAction after a successful action must NOT count
    /// as new edits — otherwise the button re-dirties itself the moment an action completes.
    @Test("Bookkeeping fields do not change the signature")
    func bookkeepingIsIgnored() {
        let base = makeConfig()
        let baseSignature = DockTileDetailView.contentSignature(of: base)

        var repositioned = base
        repositioned.lastDockIndex = 4
        #expect(DockTileDetailView.contentSignature(of: repositioned) == baseSignature)

        var stamped = base
        stamped.helperAppVersion = "9.9.9"
        #expect(DockTileDetailView.contentSignature(of: stamped) == baseSignature)

        var hidden = base
        hidden.isVisibleInDock = false
        #expect(DockTileDetailView.contentSignature(of: hidden) == baseSignature)
    }

    // MARK: - shouldPerformDockRemoval (HelperBundleManager no-op guard)

    /// If this guard is deleted, a removal with nothing to remove falls through to
    /// `restartDock()` and the Dock bounces on every no-op action again.
    @Test("Not pinned + no helper running → removal is a no-op (Dock must not restart)")
    func removalNoOpWhenNothingToDo() {
        #expect(!HelperBundleManager.shouldPerformDockRemoval(isInDock: false, isHelperRunning: false))
    }

    @Test("Pinned or running helper → removal proceeds")
    func removalProceedsWhenWorkExists() {
        #expect(HelperBundleManager.shouldPerformDockRemoval(isInDock: true, isHelperRunning: false))
        #expect(HelperBundleManager.shouldPerformDockRemoval(isInDock: false, isHelperRunning: true))
        #expect(HelperBundleManager.shouldPerformDockRemoval(isInDock: true, isHelperRunning: true))
    }
}
