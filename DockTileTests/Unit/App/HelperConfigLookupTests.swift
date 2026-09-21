import Foundation
import Testing
@testable import Dock_Tile

/// The helper decides Ghost vs App mode before ConfigurationManager exists, by reading the config
/// file itself. It used to hardcode the RELEASE filename, so a dev helper read the wrong file and
/// was always Ghost. Failing value: `true` expected, `false` returned, for a tile present in the
/// file that was passed in.
@Suite("Helper config lookup")
struct HelperConfigLookupTests {

    private func writeConfig(showInAppSwitcher: Bool, bundleId: String) throws -> URL {
        var config = DockTileConfiguration(name: "Probe")
        config.bundleIdentifier = bundleId
        config.showInAppSwitcher = showInAppSwitcher
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("helper-lookup-\(UUID().uuidString).json")
        try encoder.encode([config]).write(to: url)
        return url
    }

    @Test("Reads the flag for the matching bundle id from the file it is given")
    func readsFlagFromGivenFile() throws {
        let url = try writeConfig(showInAppSwitcher: true, bundleId: "com.docktile.dev.PROBE")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: url, bundleId: "com.docktile.dev.PROBE") == true)
    }

    @Test("An unknown bundle id or a missing file defaults to Ghost mode")
    func defaultsToGhost() throws {
        let url = try writeConfig(showInAppSwitcher: true, bundleId: "com.docktile.dev.PROBE")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: url, bundleId: "com.docktile.dev.OTHER") == false)
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).json")
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: missing, bundleId: "com.docktile.dev.PROBE") == false)
    }

    /// The seam above is always handed a URL, so no test of it can fail for the regression the task
    /// actually exists to prevent: a literal `com.docktile.configs.json` at the CALL SITE
    /// (`HelperAppDelegate.applicationWillFinishLaunching`), which made every dev helper read the
    /// release config and come up Ghost. This guards the value that call site passes.
    ///
    /// Failing value: `preferencesURL` resolving to the release filename in a Debug build — exactly
    /// the shipped bug — or to anything outside `~/Library/Preferences`.
    @Test("The config path comes from the environment, so a dev build never reads the release file")
    func preferencesURLCarriesTheEnvironmentFilename() {
        let url = AppEnvironment.preferencesURL
        let expected = AppEnvironment.isRelease ? "com.docktile.configs.json" : "com.docktile.dev.configs.json"
        #expect(url.lastPathComponent == expected)
        #expect(url.path.hasSuffix("Library/Preferences/\(expected)"))
        // Tests run under the dev app, so the dev/release split must be live here, not theoretical.
        #expect(AppEnvironment.isRelease == false)
    }

    @Test("An unreadable or wrongly-shaped config file defaults to Ghost mode")
    func undecodableFileDefaultsToGhost() throws {
        let dir = FileManager.default.temporaryDirectory

        // Not JSON at all.
        let garbage = dir.appendingPathComponent("helper-lookup-garbage-\(UUID().uuidString).json")
        try Data("{ this is not valid JSON".utf8).write(to: garbage)
        defer { try? FileManager.default.removeItem(at: garbage) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: garbage, bundleId: "com.docktile.dev.PROBE") == false)

        // Valid JSON, wrong shape — the likelier real regression, since a schema change can
        // produce this while the file still parses.
        let wrongShape = dir.appendingPathComponent("helper-lookup-shape-\(UUID().uuidString).json")
        try Data("{\"configurations\": []}".utf8).write(to: wrongShape)
        defer { try? FileManager.default.removeItem(at: wrongShape) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: wrongShape, bundleId: "com.docktile.dev.PROBE") == false)
    }
}
