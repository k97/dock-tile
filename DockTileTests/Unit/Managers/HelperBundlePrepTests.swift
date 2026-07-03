//
//  HelperBundlePrepTests.swift
//  DockTileTests
//
//  Guards the two helper-bundle filesystem invariants that previously had no unit coverage:
//    1. The helper Info.plist transform — CFBundleIconFile, Ghost/App mode, Sparkle + URL-scheme
//       stripping (pure `HelperBundleManager.helperInfoPlist`).
//    2. Removal of the main app's baked icons — Assets.car MUST go or macOS shows the main app
//       icon (real temp-dir test of `HelperBundleManager.stripMainAppIcons`).
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite("Helper Info.plist transform")
struct HelperInfoPlistTests {

    /// A representative copy of the main app's Info.plist before helper-ification.
    private func mainAppPlist() -> [String: Any] {
        [
            "CFBundleIdentifier": "com.docktile.app",
            "CFBundleName": "Dock Tile",
            "CFBundleDisplayName": "Dock Tile",
            "CFBundleIconFile": "MainAppIcon",
            "CFBundleVersion": "42",                 // unrelated key must survive untouched
            "SUFeedURL": "https://example.com/appcast.xml",
            "SUPublicEDKey": "abc123",
            "SUEnableAutomaticChecks": true,
            "SUScheduledCheckInterval": 86400,
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["docktile"]]]
        ]
    }

    @Test("CFBundleIconFile is forced to AppIcon (so the generated .icns wins)")
    func iconFileForcedToAppIcon() {
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false)
        #expect(out["CFBundleIconFile"] as? String == "AppIcon")
    }

    @Test("Bundle identity is rewritten to the helper's")
    func bundleIdentityRewritten() {
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false)
        #expect(out["CFBundleIdentifier"] as? String == "com.docktile.helper.x")
        #expect(out["CFBundleName"] as? String == "My Tile")
        #expect(out["CFBundleDisplayName"] as? String == "My Tile")
    }

    @Test("Sparkle keys and the URL scheme are stripped; unrelated keys are preserved")
    func stripsSparkleAndURLScheme() {
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false)

        #expect(out["SUFeedURL"] == nil)
        #expect(out["SUPublicEDKey"] == nil)
        #expect(out["SUEnableAutomaticChecks"] == nil)
        #expect(out["SUScheduledCheckInterval"] == nil)
        #expect(out["CFBundleURLTypes"] == nil)
        // A key we never touch must come through unchanged.
        #expect(out["CFBundleVersion"] as? String == "42")
    }

    @Test("Ghost mode sets LSUIElement; App mode removes it")
    func ghostVsAppMode() {
        let ghost = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "id", appName: "T", showInAppSwitcher: false)
        #expect(ghost["LSUIElement"] as? Bool == true)

        let app = HelperBundleManager.helperInfoPlist(
            from: ["LSUIElement": true], bundleId: "id", appName: "T", showInAppSwitcher: true)
        #expect(app["LSUIElement"] == nil)
    }
}

@Suite("Helper icon stripping (filesystem)", .serialized)
struct HelperIconStripTests {

    /// Build a throwaway `*.app/Contents/Resources` skeleton in the temp dir with optional
    /// Assets.car / AppIcon.icns, and return the bundle root. Caller deletes it.
    private func makeBundle(assetsCar: Bool, icns: Bool) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("docktile-test-\(UUID().uuidString)")
            .appendingPathComponent("Tile.app")
        let resources = root.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        if assetsCar {
            try Data("car".utf8).write(to: resources.appendingPathComponent("Assets.car"))
        }
        if icns {
            try Data("icns".utf8).write(to: resources.appendingPathComponent("AppIcon.icns"))
        }
        return root
    }

    private func exists(_ url: URL, _ rel: String) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(rel).path)
    }

    @Test("Removes Assets.car and AppIcon.icns when present")
    func removesBothWhenPresent() throws {
        let bundle = try makeBundle(assetsCar: true, icns: true)
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }

        let result = HelperBundleManager.stripMainAppIcons(inBundle: bundle)

        #expect(result.assetsCar == true)
        #expect(result.icns == true)
        #expect(exists(bundle, "Contents/Resources/Assets.car") == false)
        #expect(exists(bundle, "Contents/Resources/AppIcon.icns") == false)
    }

    @Test("No-op (no throw) when the icon assets are absent")
    func noopWhenAbsent() throws {
        let bundle = try makeBundle(assetsCar: false, icns: false)
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }

        let result = HelperBundleManager.stripMainAppIcons(inBundle: bundle)

        #expect(result.assetsCar == false)
        #expect(result.icns == false)
        // Resources dir still intact — we only target the two icon files.
        #expect(exists(bundle, "Contents/Resources") == true)
    }
}

// MARK: - Helper folder disambiguation (same-name tiles must not collide)

@Suite("Helper folder name")
struct HelperFolderNameTests {

    @Test("Clean name when the path is free / already this tile's")
    func cleanNameWhenUncontested() {
        #expect(HelperBundleManager.helperFolderName(
            baseName: "Ship", cleanNameTakenByOther: false, shortId: "00358962") == "Ship.app")
    }

    @Test("Disambiguates with the short id when another tile owns the clean name")
    func disambiguatesOnCollision() {
        // Two legitimately same-named tiles: the second must not clobber the first's Ship.app.
        #expect(HelperBundleManager.helperFolderName(
            baseName: "Ship", cleanNameTakenByOther: true, shortId: "52300A6C") == "Ship-52300A6C.app")
    }

    @Test("Different tiles sharing a name resolve to different folders")
    func sameNameDistinctFolders() {
        let first = HelperBundleManager.helperFolderName(
            baseName: "Ship", cleanNameTakenByOther: false, shortId: "00358962")
        let second = HelperBundleManager.helperFolderName(
            baseName: "Ship", cleanNameTakenByOther: true, shortId: "52300A6C")
        #expect(first != second)
    }
}

// MARK: - Test-host guard

@Suite("Test environment detection")
struct TestEnvironmentTests {

    @Test("isRunningTests is true inside the test host (gates launch-time mutators)")
    func detectsTestHost() {
        // If this ever reads false, the app's launch side effects (helper migration, Dock
        // reconcile/watch, login-item registration) would run against the user's live dev data.
        #expect(AppEnvironment.isRunningTests == true)
    }
}
