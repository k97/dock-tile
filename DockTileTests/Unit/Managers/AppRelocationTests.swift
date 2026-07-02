import Testing
import Foundation
@testable import Dock_Tile

// MARK: - App Relocation Tests
//
// Guards the pure decision seam behind the "move to /Applications" feature without touching
// Security.framework (SecTranslocate), FileManager, or NSAlert. The regression this protects:
// a user running `~/Downloads/Dock Tile.app` under macOS App Translocation hits a read-only
// shadow mount, so copying the app as a helper template fails with an opaque Cocoa 260. The seam
// decides (a) whether that location blocks helper generation and (b) whether to nudge the user.

@Suite("AppRelocation.classify")
struct AppRelocationClassifyTests {

    private let appDirs = ["/Applications", "/Users/test/Applications"]

    @Test("A translocated bundle is .translocated regardless of its reported path")
    func translocatedWins() {
        let location = AppRelocation.classify(
            bundlePath: "/Applications/Dock Tile.app",
            isTranslocated: true,
            applicationsDirectories: appDirs
        )
        #expect(location == .translocated)
    }

    @Test("A bundle inside the system Applications folder is .applications")
    func systemApplications() {
        let location = AppRelocation.classify(
            bundlePath: "/Applications/Dock Tile.app",
            isTranslocated: false,
            applicationsDirectories: appDirs
        )
        #expect(location == .applications)
    }

    @Test("A bundle inside the user's ~/Applications folder is .applications")
    func userApplications() {
        let location = AppRelocation.classify(
            bundlePath: "/Users/test/Applications/Dock Tile.app",
            isTranslocated: false,
            applicationsDirectories: appDirs
        )
        #expect(location == .applications)
    }

    @Test("A bundle in Downloads is .elsewhere")
    func downloads() {
        let location = AppRelocation.classify(
            bundlePath: "/Users/test/Downloads/Dock Tile.app",
            isTranslocated: false,
            applicationsDirectories: appDirs
        )
        #expect(location == .elsewhere)
    }

    @Test("A trailing slash on the Applications directory still matches")
    func trailingSlashNormalized() {
        let location = AppRelocation.classify(
            bundlePath: "/Applications/Dock Tile.app",
            isTranslocated: false,
            applicationsDirectories: ["/Applications/"]
        )
        #expect(location == .applications)
    }

    @Test("A directory that is only a name prefix of Applications does not falsely match")
    func noPrefixFalsePositive() {
        // "/ApplicationsOld/..." must NOT be treated as inside "/Applications".
        let location = AppRelocation.classify(
            bundlePath: "/ApplicationsOld/Dock Tile.app",
            isTranslocated: false,
            applicationsDirectories: ["/Applications"]
        )
        #expect(location == .elsewhere)
    }
}

@Suite("AppRelocation decisions")
struct AppRelocationDecisionTests {

    @Test("Only a translocated location blocks helper-bundle generation")
    func blocksBundleGeneration() {
        #expect(AppRelocation.blocksBundleGeneration(.translocated) == true)
        #expect(AppRelocation.blocksBundleGeneration(.elsewhere) == false)
        #expect(AppRelocation.blocksBundleGeneration(.applications) == false)
    }

    @Test("Anything but a real Applications install should prompt relocation")
    func requiresRelocation() {
        #expect(AppRelocation.requiresRelocation(.translocated) == true)
        #expect(AppRelocation.requiresRelocation(.elsewhere) == true)
        #expect(AppRelocation.requiresRelocation(.applications) == false)
    }

    @Test("Each location exposes a stable analytics token")
    func analyticsValues() {
        #expect(AppRelocation.Location.applications.analyticsValue == "applications")
        #expect(AppRelocation.Location.translocated.analyticsValue == "translocated")
        #expect(AppRelocation.Location.elsewhere.analyticsValue == "elsewhere")
    }
}
