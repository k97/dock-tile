import Testing
@testable import Dock_Tile

/// `main.swift` picks the helper or the main-app delegate from `AppEnvironment.isHelper` alone — the
/// one copy of the rule since `main.swift` and `AppDelegate` each carried their own (`AppDelegate`'s
/// compared the bundle id with itself, so it was always false). Failing value: a bare
/// `hasPrefix("com.docktile.")` rule calls the dev main app (`com.docktile.dev.app`) a helper.
@Suite("Helper detection")
struct HelperDetectionTests {

    @Test("The main app is never a helper", arguments: [
        "com.docktile.app",      // release
        "com.docktile.dev.app",  // dev
        "com.docktile",          // legacy / fallback
    ])
    func mainAppIsNotAHelper(_ bundleId: String) {
        #expect(AppEnvironment.isHelper(bundleId: bundleId) == false)
    }

    @Test("A per-tile bundle is a helper", arguments: [
        "com.docktile.6F9619FF-8B86-D011-B42D-00C04FC964FF",      // release
        "com.docktile.dev.6F9619FF-8B86-D011-B42D-00C04FC964FF",  // dev
    ])
    func tileBundleIsAHelper(_ bundleId: String) {
        #expect(AppEnvironment.isHelper(bundleId: bundleId) == true)
    }

    @Test("Another app's bundle is not a helper")
    func unrelatedBundleIsNotAHelper() {
        #expect(AppEnvironment.isHelper(bundleId: "com.example.app") == false)
    }
}
