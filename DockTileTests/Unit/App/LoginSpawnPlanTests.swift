import Testing
@testable import Dock_Tile

/// Whether the login spawner starts the main app quietly (issue #13). Failing values: a menu bar
/// icon or Dock Lock missing after login, a main app started with nothing to do, a second main app
/// beside one already running, or the spawner counting itself (it shares the main app's bundle id)
/// and never launching.
@Suite("Login spawn: main app")
struct LoginSpawnPlanTests {

    @Test("Menu bar icon on and no main app running: launches it")
    func launchesForMenuBar() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: true, dockLockReady: false, mainAppPids: [], ownPid: 100) == true)
    }

    @Test("Dock Lock with its display to hold, icon off: launches it")
    func launchesForDockLock() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: false, dockLockReady: true, mainAppPids: [], ownPid: 100) == true)
    }

    @Test("Neither: never launches the main app")
    func nothingToDo() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: false, dockLockReady: false, mainAppPids: [], ownPid: 100) == false)
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: false, dockLockReady: false, mainAppPids: [100], ownPid: 100) == false)
    }

    @Test("The spawner's own pid is not a running main app")
    func ignoresOwnPid() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: true, dockLockReady: false, mainAppPids: [100], ownPid: 100) == true)
    }

    @Test("Another main app running: no second one")
    func noSecondInstance() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: true, dockLockReady: true, mainAppPids: [100, 200], ownPid: 100) == false)
    }
}
