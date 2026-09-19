import Testing
@testable import Dock_Tile

/// Guards the rule behind every debounced config save: a debounce that was CANCELLED must not
/// save. The regression this kills: `try? await Task.sleep` swallowed the cancellation, so each
/// superseded edit saved the whole config immediately (one full save per colour-drag tick).
/// Failing value: a cancelled wait returning `true`.
@Suite("Save debounce")
struct SaveDebounceTests {

    @Test("An uninterrupted wait reports that the full interval elapsed")
    func uninterruptedWaitCompletes() async {
        let completed = await SaveDebounce.waitedFullInterval(nanoseconds: 1_000_000)
        #expect(completed == true)
    }

    @Test("A wait cancelled part-way reports false so the caller skips its save")
    func cancelledWaitReportsFalse() async {
        let task = Task { await SaveDebounce.waitedFullInterval(nanoseconds: 5_000_000_000) }
        task.cancel()
        let completed = await task.value
        #expect(completed == false)
    }
}
