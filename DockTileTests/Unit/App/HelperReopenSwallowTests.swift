import Testing
import CoreFoundation
@testable import Dock_Tile

/// Issue #12 "First Click doesn't trigger": the post-cold-launch reopen swallow used to be an
/// unbounded boolean — when macOS never delivered the trailing reopen ('rapp') after a cold
/// Dock click, the flag stayed armed indefinitely and silently ate the NEXT genuine Dock
/// click, whenever it came. The swallow must only cover the reopen macOS delivers as part of
/// the launch sequence itself (milliseconds after the auto-show), never a later user click.
struct HelperReopenSwallowTests {

    @Test("Reopen right after the launch auto-show is swallowed")
    func swallowsImmediateTrailingReopen() {
        let shownAt: CFAbsoluteTime = 1000.0
        #expect(HelperAppDelegate.shouldSwallowReopen(now: shownAt + 0.05, autoShownAt: shownAt))
    }

    @Test("Reopen just inside the swallow window is swallowed")
    func swallowsReopenJustInsideWindow() {
        let shownAt: CFAbsoluteTime = 1000.0
        #expect(HelperAppDelegate.shouldSwallowReopen(now: shownAt + 0.99, autoShownAt: shownAt))
    }

    @Test("Reopen at the window boundary acts — the click must not be eaten")
    func actsAtWindowBoundary() {
        let shownAt: CFAbsoluteTime = 1000.0
        #expect(!HelperAppDelegate.shouldSwallowReopen(now: shownAt + 1.0, autoShownAt: shownAt))
    }

    @Test("A Dock click seconds after a cold launch acts — the reproduced #12 case")
    func actsOnGenuineLaterClick() {
        let shownAt: CFAbsoluteTime = 1000.0
        // Reproduced live: click 5s after launch was silently swallowed by the boolean flag.
        #expect(!HelperAppDelegate.shouldSwallowReopen(now: shownAt + 5.0, autoShownAt: shownAt))
    }
}
