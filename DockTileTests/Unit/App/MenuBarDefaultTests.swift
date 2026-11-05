import Testing
@testable import Dock_Tile

/// The menu bar icon's first value and the stay-running rule (issue #13). Failing values: an
/// existing user handed a new menu bar icon on update, or the app quitting on close while the icon
/// (or Dock Lock) is on.
@Suite("Menu bar default and lifetime")
struct MenuBarDefaultTests {

    @Test("A new install starts with the icon on; an existing user keeps it off")
    func initialValue() {
        #expect(MenuBarController.initialEnabled(hasLaunchedBefore: false) == true)
        #expect(MenuBarController.initialEnabled(hasLaunchedBefore: true) == false)
    }

    @Test("Stays running while Dock Lock or the menu bar icon is on; quits on close otherwise")
    func staysResident() {
        #expect(AppDelegate.staysResident(dockLock: false, menuBar: false) == false)
        #expect(AppDelegate.staysResident(dockLock: true, menuBar: false) == true)
        #expect(AppDelegate.staysResident(dockLock: false, menuBar: true) == true)
        #expect(AppDelegate.staysResident(dockLock: true, menuBar: true) == true)
    }
}
