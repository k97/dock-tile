import Testing
import Foundation
@testable import Dock_Tile

// MARK: - AppInstallChecker Tests

/// Exercises the pure `classifyInstallStatus(...)` decision seam — the regression-prone rule that
/// decides whether a tile's app is installed, missing, or unknown. Kept I/O-free so the rule is
/// testable without touching Launch Services / FileManager (mirrors `classifyForMigration`).
@Suite("AppInstallChecker classification")
struct AppInstallCheckerTests {

    // MARK: - Installed (either positive signal wins)

    @Test("Bundle ID resolving means installed, regardless of other signals")
    func bundleResolvesIsInstalled() {
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: true,
                hasLastKnownPath: false,
                onDiskPathExists: false,
                hasCachedIcon: false
            ) == .installed
        )
    }

    @Test("An app present on disk is installed even when Launch Services doesn't resolve the bundle")
    func onDiskPathIsInstalled() {
        // The "app moved / LS not yet re-registered after update" case.
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                hasLastKnownPath: true,
                onDiskPathExists: true,
                hasCachedIcon: false
            ) == .installed
        )
    }

    // MARK: - Missing (confident)

    @Test("A recorded path that is now gone, with no live bundle, is confidently missing")
    func recordedPathGoneIsMissing() {
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                hasLastKnownPath: true,
                onDiskPathExists: false,
                hasCachedIcon: true   // cached icon must NOT rescue a confirmed-missing app
            ) == .missing
        )
    }

    @Test("No bundle, no path on record, and no cached icon leaves nothing to point at — missing")
    func noSignalsAtAllIsMissing() {
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                hasLastKnownPath: false,
                onDiskPathExists: false,
                hasCachedIcon: false
            ) == .missing
        )
    }

    // MARK: - Unknown (legacy safety)

    @Test("Pre-v8 entry (no path) with a cached icon stays unknown, never flagged")
    func legacyCachedIconIsUnknown() {
        // Avoids false positives on legacy data / a transiently-unregistered LS entry.
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                hasLastKnownPath: false,
                onDiskPathExists: false,
                hasCachedIcon: true
            ) == .unknown
        )
    }

    // MARK: - Search paths centralisation

    @Test("Common search paths cover the four standard app install locations for a name")
    func commonSearchPathsCoverStandardLocations() {
        let paths = AppInstallChecker.commonSearchPaths(forName: "Safari")
        #expect(paths.contains("/Applications/Safari.app"))
        #expect(paths.contains("/System/Applications/Safari.app"))
        #expect(paths.contains("/Applications/Utilities/Safari.app"))
        #expect(paths.count == 4)
    }
}

// MARK: - AppItem lastKnownPath schema evolution

@Suite("AppItem lastKnownPath (v8) backward compatibility")
struct AppItemLastKnownPathTests {

    @Test("A pre-v8 config without lastKnownPath decodes with a nil path")
    func decodesLegacyConfigWithoutPath() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "bundleIdentifier": "com.apple.Safari",
          "name": "Safari",
          "isFolder": false
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(AppItem.self, from: json)
        #expect(item.lastKnownPath == nil)
        #expect(item.bundleIdentifier == "com.apple.Safari")
    }

    @Test("lastKnownPath survives an encode/decode round trip")
    func roundTripsLastKnownPath() throws {
        let original = AppItem(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            lastKnownPath: "/Applications/Safari.app"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppItem.self, from: data)
        #expect(decoded.lastKnownPath == "/Applications/Safari.app")
    }
}
