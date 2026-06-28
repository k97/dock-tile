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

    @Test("Bundle ID resolving means installed")
    func bundleResolvesIsInstalled() {
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: true,
                onDiskPathExists: false
            ) == .installed
        )
    }

    @Test("An app present on disk is installed even when Launch Services doesn't resolve the bundle")
    func onDiskPathIsInstalled() {
        // The "app moved / LS not yet re-registered after update" case.
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                onDiskPathExists: true
            ) == .installed
        )
    }

    // MARK: - Missing

    @Test("No live bundle and nothing on disk is missing")
    func noSignalsIsMissing() {
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                onDiskPathExists: false
            ) == .missing
        )
    }

    // MARK: - Regression: pre-v8 legacy entries must still be flagged

    @Test("A legacy entry (no path, has cached icon) that no longer resolves is missing, not exempt")
    func legacyUninstalledAppIsMissing() {
        // Regression guard for the production miss: an app uninstalled BEFORE the lastKnownPath
        // field existed carries a cached icon and no path. It must be flagged missing — a cached
        // icon is DockTile's own snapshot, not proof the app is installed. The classifier no
        // longer takes hasCachedIcon, so "doesn't resolve + not on disk" is unambiguously missing.
        #expect(
            AppInstallChecker.classifyInstallStatus(
                bundleResolves: false,
                onDiskPathExists: false
            ) == .missing
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
