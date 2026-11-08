import Testing
@testable import Dock_Tile

/// Dock Lock remembers one anchor per display setup = the exact set of connected displays (#37).
/// The engine and the login spawner both resolve through `resolveAnchor`. Failing values: an anchor
/// leaking into a setup that never picked one, Default not sticking, a single screen being held, or
/// the writer building a different key from the reader.
@Suite("Dock Lock per-setup anchors")
struct DockLockSetupTests {

    private let laptop = "11111111-1111-1111-1111-111111111111"
    private let home = "22222222-2222-2222-2222-222222222222"
    private let work = "33333333-3333-3333-3333-333333333333"

    private var homeSetup: [String] { [laptop, home] }
    private var workSetup: [String] { [laptop, work] }

    @Test("The setup key ignores display order")
    func keyIsOrderIndependent() {
        #expect(DockLockManager.setupKey([home, laptop]) == DockLockManager.setupKey([laptop, home]))
        #expect(DockLockManager.setupKey([laptop, home]) != DockLockManager.setupKey([laptop, work]))
    }

    @Test("A known setup holds its own anchor; each setup keeps its own")
    func knownSetups() {
        let remembered = [DockLockManager.setupKey(homeSetup): home, DockLockManager.setupKey(workSetup): laptop]
        #expect(DockLockManager.resolveAnchor(connected: homeSetup, remembered: remembered, legacy: nil) == home)
        #expect(DockLockManager.resolveAnchor(connected: [work, laptop], remembered: remembered, legacy: nil) == laptop)
    }

    @Test("An unknown setup is left alone, even with another setup's anchor connected")
    func unknownSetupIsLeftAlone() {
        let remembered = [DockLockManager.setupKey(homeSetup): home]
        // Projector plugged in beside home: home's anchor is connected, but this set was never picked on.
        #expect(DockLockManager.resolveAnchor(connected: [laptop, home, work], remembered: remembered, legacy: nil) == nil)
    }

    @Test("Default picked on a setup holds nothing there")
    func defaultEntry() {
        let remembered = [DockLockManager.setupKey(homeSetup): ""]
        #expect(DockLockManager.resolveAnchor(connected: homeSetup, remembered: remembered, legacy: nil) == nil)
    }

    @Test("One display or none: nothing to hold")
    func singleDisplay() {
        let remembered = [DockLockManager.setupKey([laptop]): laptop]
        #expect(DockLockManager.resolveAnchor(connected: [laptop], remembered: remembered, legacy: laptop) == nil)
        #expect(DockLockManager.resolveAnchor(connected: [], remembered: [:], legacy: laptop) == nil)
    }

    @Test("The pre-#37 anchor covers every setup it is in that has no entry of its own")
    func legacyFallback() {
        #expect(DockLockManager.resolveAnchor(connected: homeSetup, remembered: [:], legacy: laptop) == laptop)
        #expect(DockLockManager.resolveAnchor(connected: workSetup, remembered: [:], legacy: laptop) == laptop)
        // Not connected: an unknown setup.
        #expect(DockLockManager.resolveAnchor(connected: [home, work], remembered: [:], legacy: laptop) == nil)
    }

    @Test("A setup's own entry beats the pre-#37 anchor, Default included")
    func entryBeatsLegacy() {
        let picked = [DockLockManager.setupKey(homeSetup): home]
        #expect(DockLockManager.resolveAnchor(connected: homeSetup, remembered: picked, legacy: laptop) == home)
        let defaulted = [DockLockManager.setupKey(homeSetup): ""]
        #expect(DockLockManager.resolveAnchor(connected: homeSetup, remembered: defaulted, legacy: laptop) == nil)
    }

    @Test("Picking changes only the current setup; Default is stored, not deleted")
    func picking() {
        let start = [DockLockManager.setupKey(workSetup): work]
        let picked = DockLockManager.remembered(start, picking: home, connected: [home, laptop])
        #expect(picked == [DockLockManager.setupKey(workSetup): work, DockLockManager.setupKey(homeSetup): home])
        // What the writer stored, the reader finds — with the displays listed in another order.
        #expect(DockLockManager.resolveAnchor(connected: homeSetup, remembered: picked, legacy: nil) == home)

        let defaulted = DockLockManager.remembered(picked, picking: nil, connected: homeSetup)
        #expect(defaulted == [DockLockManager.setupKey(workSetup): work, DockLockManager.setupKey(homeSetup): ""])
    }
}
