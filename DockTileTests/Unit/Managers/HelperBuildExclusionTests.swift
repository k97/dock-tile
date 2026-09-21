import Foundation
import Testing
@testable import Dock_Tile

/// The bundle-BUILD critical section (`generateHelperBundle` → `installTileIcons` →
/// `codesignHelper`) used to contain no `await`, so the main actor serialised it implicitly. Moving
/// the icon compile and the codesign off the main actor inserted ~1.4 s of suspension into it, so a
/// user pressing **Update** can now be parked inside it alongside a migration / Popover-Appearance
/// batch's `regenerateHelperBundle` for the SAME bundle path — `installHelper` deletes and re-copies
/// the directory the suspended regenerate then writes into and signs.
///
/// Failing value: `true` for a bundle id that is already in flight. That is precisely the old
/// behaviour, because `regenerateHelperBundle` never registered in the set at all.
@Suite("Helper bundle build exclusion")
struct HelperBuildExclusionTests {

    private let tile = "com.docktile.dev.11111111-2222-3333-4444-555555555555"
    private let other = "com.docktile.dev.99999999-8888-7777-6666-555555555555"

    @Test("A build may begin when nothing is in flight for that bundle id")
    func allowsFirstBuild() {
        #expect(HelperBundleManager.canBeginBundleBuild(bundleId: tile, inFlight: []) == true)
        #expect(HelperBundleManager.canBeginBundleBuild(bundleId: tile, inFlight: [other]) == true)
    }

    @Test("A second build for the SAME bundle id is refused, whoever else is building")
    func refusesConcurrentBuildOfSameBundle() {
        #expect(HelperBundleManager.canBeginBundleBuild(bundleId: tile, inFlight: [tile]) == false)
        #expect(HelperBundleManager.canBeginBundleBuild(bundleId: tile, inFlight: [tile, other]) == false)
    }

    @Test("Concurrent builds of DIFFERENT tiles are still allowed — a batch must not serialise itself")
    func allowsConcurrentBuildsOfDifferentBundles() {
        #expect(HelperBundleManager.canBeginBundleBuild(bundleId: other, inFlight: [tile]) == true)
    }

    /// A refused regenerate must be reported as a THROWN error, because `runRegenerationBatch`
    /// stamps `helperAppVersion` only on success — a silent "success" would mark the tile migrated
    /// while its bundle was never rebuilt, and `classifyForMigration` would then skip it forever.
    @Test("The refusal error is its own case, distinct from every other helper-bundle failure")
    func refusalIsItsOwnError() {
        #expect(HelperBundleError.bundleBuildInProgress.errorDescription == AppStrings.Error.bundleBuildInProgress)
        let others = [HelperBundleError.bundleCopyFailed, .codesignFailed, .appTranslocated,
                      .mainAppNotFound, .infoPlistReadFailed, .infoPlistWriteFailed]
        for other in others {
            #expect(other.errorDescription != AppStrings.Error.bundleBuildInProgress)
        }
    }
}
