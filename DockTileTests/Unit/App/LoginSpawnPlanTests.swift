import Testing
@testable import Dock_Tile

/// Whether the login spawner starts the main app quietly for the menu bar icon (issue #13).
/// Failing values: a menu bar icon missing after login, a second main app beside one already
/// running, or the spawner counting itself (it shares the main app's bundle id) and never launching.
@Suite("Login spawn: main app")
struct LoginSpawnPlanTests {

    @Test("Icon on and no main app running: launches it")
    func launchesWhenOn() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: true, mainAppPids: [], ownPid: 100) == true)
    }

    @Test("The spawner's own pid is not a running main app")
    func ignoresOwnPid() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: true, mainAppPids: [100], ownPid: 100) == true)
    }

    @Test("Another main app running: no second one")
    func noSecondInstance() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: true, mainAppPids: [100, 200], ownPid: 100) == false)
    }

    @Test("Icon off: never launches the main app")
    func offNeverLaunches() {
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: false, mainAppPids: [], ownPid: 100) == false)
        #expect(LoginTileSpawner.launchesMainApp(menuBarEnabled: false, mainAppPids: [100], ownPid: 100) == false)
    }
}
