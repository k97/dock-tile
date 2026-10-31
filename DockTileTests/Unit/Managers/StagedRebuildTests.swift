import Foundation
import Testing
@testable import Dock_Tile

private enum StepError: Error { case boom }

/// Records every step `runStagedRebuild` takes, in order.
@MainActor
private final class StepRecorder {
    var log: [String] = []
    var lockAvailable = true
    var failing: String?

    func steps() -> StagedRebuildSteps {
        func step(_ name: String) throws {
            log.append(name)
            if failing == name { throw StepError.boom }
        }
        return StagedRebuildSteps(
            acquireLock: { self.log.append("acquireLock"); return self.lockAvailable },
            post: { self.log.append("post:\($0.rawValue)") },
            copy: { try step("copy") },
            buildIcons: { try step("buildIcons") },
            sign: { try step("sign") },
            quitOld: { self.log.append("quitOld") },
            swap: { try step("swap") },
            removeOldFolder: { self.log.append("removeOldFolder") },
            removeStaged: { self.log.append("removeStaged") },
            register: { self.log.append("register") },
            launchNew: { self.log.append("launchNew") },
            launchExisting: { self.log.append("launchExisting") }
        )
    }
}

/// The order of a staged rebuild IS the fix (2.6.3): the old helper keeps running (and shows the
/// bar) until the new bundle is complete and signed, the swap happens only after it is quit, anything
/// the Dock relaunched in that gap is quit again before the new one launches, and a failure leaves
/// the old tile exactly as it was. Failing values: the 2.6.1 order (quit before building), a launch
/// before the second quit, and a build failure that quits or swaps anyway.
@Suite("Staged rebuild order")
@MainActor
struct StagedRebuildTests {

    @Test("Build, then quit, swap, register, quit again, launch")
    func happyPathOrder() async throws {
        let recorder = StepRecorder()
        try await HelperBundleManager.runStagedRebuild(recorder.steps())
        #expect(recorder.log == [
            "acquireLock", "post:begin", "copy", "post:copied", "buildIcons", "post:iconsBuilt",
            "sign", "post:signed", "post:ready", "quitOld", "swap", "removeOldFolder", "register",
            "quitOld", "launchNew",
        ])
    }

    @Test("Another process's build of the tile refuses this one before anything is touched")
    func lockHeldRefusesWithoutTouchingAnything() async {
        let recorder = StepRecorder()
        recorder.lockAvailable = false
        await #expect(throws: HelperBundleError.bundleBuildInProgress) {
            try await HelperBundleManager.runStagedRebuild(recorder.steps())
        }
        #expect(recorder.log == ["acquireLock"])
    }

    @Test("A build step failure cancels the bar, removes staging and never touches the old tile",
          arguments: ["copy", "buildIcons", "sign"])
    func buildFailureCancelsAndKeepsTheOldTile(failing: String) async {
        let recorder = StepRecorder()
        recorder.failing = failing
        await #expect(throws: StepError.self) {
            try await HelperBundleManager.runStagedRebuild(recorder.steps())
        }
        #expect(Array(recorder.log.suffix(3)) == [failing, "post:cancelled", "removeStaged"])
        #expect(!recorder.log.contains("quitOld"))
        #expect(!recorder.log.contains("swap"))
        #expect(!recorder.log.contains("launchNew"))
    }

    /// The bar is cancelled too (final review, 2026-10-31): a helper `quitOld` could not stop would
    /// otherwise keep a full bar and ignore clicks until the 30 s expiry.
    @Test("A failed swap clears the bar and relaunches the old tile instead of leaving it dead")
    func swapFailureRelaunchesTheOldTile() async {
        let recorder = StepRecorder()
        recorder.failing = "swap"
        await #expect(throws: StepError.self) {
            try await HelperBundleManager.runStagedRebuild(recorder.steps())
        }
        #expect(Array(recorder.log.suffix(5)) == ["quitOld", "swap", "post:cancelled", "removeStaged", "launchExisting"])
        #expect(!recorder.log.contains("removeOldFolder"))
        #expect(!recorder.log.contains("register"))
        #expect(!recorder.log.contains("launchNew"))
    }
}
