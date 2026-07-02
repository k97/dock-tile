import Testing
import Foundation
@testable import Dock_Tile

// MARK: - Diagnostics Log Tests
//
// Guards the regression-prone decisions in the dev-verbose / prod-quiet diagnostics layer without
// depending on the build-time `AppEnvironment.isRelease` constant or touching the shared log file:
//   1. `shouldRecord` — the verbose gate. A wrong result either floods a user's prod report with
//      the dev click/workflow firehose, or silently drops dev traces the developer relies on.
//   2. `measure` — must return the body's value and re-throw its errors unchanged, so wrapping a
//      workflow for timing never alters its behaviour.
//   3. `elapsedMs` — non-negative whole-millisecond arithmetic over a `Duration`.

@Suite("DiagnosticsLog.shouldRecord verbose gate")
struct DiagnosticsShouldRecordTests {

    @Test("Non-verbose events are always recorded, in dev and release")
    func nonVerboseAlwaysRecorded() {
        #expect(DiagnosticsLog.shouldRecord(verbose: false, isRelease: false))
        #expect(DiagnosticsLog.shouldRecord(verbose: false, isRelease: true))
    }

    @Test("Verbose events are kept in dev builds")
    func verboseKeptInDev() {
        #expect(DiagnosticsLog.shouldRecord(verbose: true, isRelease: false))
    }

    @Test("Verbose events are dropped in release builds")
    func verboseDroppedInRelease() {
        #expect(!DiagnosticsLog.shouldRecord(verbose: true, isRelease: true))
    }
}

@Suite("DiagnosticsLog.measure passthrough")
struct DiagnosticsMeasureTests {

    private struct MeasureError: Error, Equatable {}

    @Test("Async measure returns the body's value unchanged")
    func asyncReturnsValue() async {
        let result = await DiagnosticsLog.shared.measure("unit-test async") { () async -> Int in
            try? await Task.sleep(nanoseconds: 1)
            return 42
        }
        #expect(result == 42)
    }

    @Test("Async measure re-throws the body's error unchanged")
    func asyncRethrows() async {
        await #expect(throws: MeasureError.self) {
            _ = try await DiagnosticsLog.shared.measure("unit-test async throw") { () async throws -> Int in
                throw MeasureError()
            }
        }
    }

    @Test("Sync measure returns the body's value unchanged")
    func syncReturnsValue() {
        let result = DiagnosticsLog.shared.measure("unit-test sync") { 7 }
        #expect(result == 7)
    }

    @Test("Sync measure re-throws the body's error unchanged")
    func syncRethrows() {
        #expect(throws: MeasureError.self) {
            _ = try DiagnosticsLog.shared.measure("unit-test sync throw") { () throws -> Int in
                throw MeasureError()
            }
        }
    }
}

@Suite("DiagnosticsLog.elapsedMs")
struct DiagnosticsElapsedTests {

    @Test("Elapsed milliseconds are never negative")
    func nonNegative() {
        let clock = ContinuousClock()
        let start = clock.now
        #expect(DiagnosticsLog.elapsedMs(from: start, clock: clock) >= 0)
    }
}
