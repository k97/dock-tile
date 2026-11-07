import Foundation
import Testing
@testable import Dock_Tile

/// When a resident Dock Tile installs a waiting update, and when its relaunch starts quietly (#13).
/// Failing values: an install (a quit and relaunch) while the user is at the window, mid-build, or
/// after a short pause; a stale flag making a later normal launch silent.
@Suite("Idle install")
struct IdleInstallTests {

    @Test("Ten idle minutes with the window off screen and the Dock quiet: install")
    func installsWhenIdle() {
        #expect(IdleInstall.shouldInstall(windowVisible: false, secondsSinceInput: 600, dockBusy: false) == true)
    }

    @Test("Under ten minutes: wait")
    func waitsUnderThreshold() {
        #expect(IdleInstall.shouldInstall(windowVisible: false, secondsSinceInput: 599, dockBusy: false) == false)
    }

    @Test("Window on screen: wait, however long idle")
    func waitsWhileWindowVisible() {
        #expect(IdleInstall.shouldInstall(windowVisible: true, secondsSinceInput: 3600, dockBusy: false) == false)
    }

    @Test("A Dock operation in flight: wait")
    func waitsWhileDockBusy() {
        #expect(IdleInstall.shouldInstall(windowVisible: false, secondsSinceInput: 3600, dockBusy: true) == false)
    }

    @Test("The relaunch flag counts only while under 120 s old")
    func relaunchFlagAge() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(IdleInstall.isQuietRelaunch(flaggedAt: now.addingTimeInterval(-119), now: now) == true)
        #expect(IdleInstall.isQuietRelaunch(flaggedAt: now.addingTimeInterval(-121), now: now) == false)
        // A clock set back must not make the flag live for ever.
        #expect(IdleInstall.isQuietRelaunch(flaggedAt: now.addingTimeInterval(60), now: now) == false)
    }
}
