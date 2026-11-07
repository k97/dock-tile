import Testing
@testable import Dock_Tile

/// Dock Lock acts only for the display the user last picked, while it is connected beside another
/// (issue #13: the login spawner and the engine both depend on it). Failing values: Dock Lock
/// starting or moving the Dock with no anchor, a missing anchor display, or a single screen.
@Suite("Dock Lock readiness")
struct DockLockReadinessTests {

    private let anchor = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"

    @Test("The picked display connected beside another: actionable")
    func anchorWithAnother() {
        #expect(DockLockManager.anchorIsActionable(anchorUUID: anchor, connectedUUIDs: [other, anchor]) == true)
    }

    @Test("Default (no display picked): nothing to hold")
    func noAnchor() {
        #expect(DockLockManager.anchorIsActionable(anchorUUID: nil, connectedUUIDs: [anchor, other]) == false)
    }

    @Test("The picked display is not connected: nothing to hold")
    func anchorAbsent() {
        #expect(DockLockManager.anchorIsActionable(anchorUUID: anchor, connectedUUIDs: [other, "33333333-3333-3333-3333-333333333333"]) == false)
    }

    @Test("Only the picked display is connected: nothing to hold")
    func singleDisplay() {
        #expect(DockLockManager.anchorIsActionable(anchorUUID: anchor, connectedUUIDs: [anchor]) == false)
        #expect(DockLockManager.anchorIsActionable(anchorUUID: anchor, connectedUUIDs: []) == false)
    }
}
