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
}
