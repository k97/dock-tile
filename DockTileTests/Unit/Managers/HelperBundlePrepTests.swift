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
            "SUAutomaticallyUpdate": true,
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["docktile"]]]
        ]
    }

    @Test("CFBundleIconFile is forced to AppIcon (so the generated .icns wins)")
    func iconFileForcedToAppIcon() {
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false, declarative: false, iconSignature: "sig", dockSignature: "dock")
        #expect(out["CFBundleIconFile"] as? String == "AppIcon")
    }

    @Test("Declarative helpers set CFBundleIconName ALONGSIDE CFBundleIconFile")
    func declarativeSetsIconNameAlongsideIconFile() {
        // The compiled per-tile Assets.car is resolved by CFBundleIconName; the fallback .icns
        // still needs CFBundleIconFile for Launch Services contexts that read the loose icon.
        // BOTH, never either — dropping the icns key would strand the fallback.
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false, declarative: true, iconSignature: "sig", dockSignature: "dock")
        #expect(out["CFBundleIconName"] as? String == "AppIcon")
        #expect(out["CFBundleIconFile"] as? String == "AppIcon")
    }

    @Test("The legacy path does not ADD CFBundleIconName (it has no catalog to name)")
    func legacyDoesNotAddIconName() {
        // Scoped deliberately to "not added": whatever the main app's plist happened to carry is
        // passed through untouched, because the legacy transform is frozen — it ships to macOS 15
        // users on a path this machine cannot exercise, so it gets no edits it does not need.
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false, declarative: false, iconSignature: "sig", dockSignature: "dock")
        #expect(out["CFBundleIconName"] == nil)
        #expect(out["CFBundleIconFile"] as? String == "AppIcon")
    }

    @Test("Bundle identity is rewritten to the helper's")
    func bundleIdentityRewritten() {
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false, declarative: false, iconSignature: "sig", dockSignature: "dock")
        #expect(out["CFBundleIdentifier"] as? String == "com.docktile.helper.x")
        #expect(out["CFBundleName"] as? String == "My Tile")
        #expect(out["CFBundleDisplayName"] as? String == "My Tile")
    }

    @Test("Sparkle keys and the URL scheme are stripped; unrelated keys are preserved")
    func stripsSparkleAndURLScheme() {
        let out = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "com.docktile.helper.x", appName: "My Tile",
            showInAppSwitcher: false, declarative: false, iconSignature: "sig", dockSignature: "dock")

        #expect(out["SUFeedURL"] == nil)
        #expect(out["SUPublicEDKey"] == nil)
        #expect(out["SUEnableAutomaticChecks"] == nil)
        #expect(out["SUScheduledCheckInterval"] == nil)
        #expect(out["SUAutomaticallyUpdate"] == nil)
        #expect(out["CFBundleURLTypes"] == nil)
        // A key we never touch must come through unchanged.
        #expect(out["CFBundleVersion"] as? String == "42")
    }

    @Test("Ghost mode sets LSUIElement; App mode removes it")
    func ghostVsAppMode() {
        let ghost = HelperBundleManager.helperInfoPlist(
            from: mainAppPlist(), bundleId: "id", appName: "T", showInAppSwitcher: false,
            declarative: false, iconSignature: "sig", dockSignature: "dock")
        #expect(ghost["LSUIElement"] as? Bool == true)

        let app = HelperBundleManager.helperInfoPlist(
            from: ["LSUIElement": true], bundleId: "id", appName: "T", showInAppSwitcher: true,
            declarative: false, iconSignature: "sig", dockSignature: "dock")
        #expect(app["LSUIElement"] == nil)
    }
}

@Suite("Helper resource strip list")
struct HelperStripListTests {

    @Test("Every helper strips the catalog, the template icns, and the bundled compiler")
    func stripsIconAssetsAndCompiler() {
        // A helper must never be able to compile an .icon document — it has no reason to and
        // `IconCompiler.bundledCompilerURL` documents it as impossible. The binary being absent
        // from the copy is what makes that true.
        #expect(HelperBundleManager.resourcesToStripFromHelper()
            == ["Assets.car", "AppIcon.icns", "docktile-actool"])
    }
}

@Suite("Helper icon stripping (filesystem)", .serialized)
struct HelperIconStripTests {

    /// Build a throwaway `*.app/Contents/Resources` skeleton in the temp dir with optional
    /// Assets.car / AppIcon.icns / docktile-actool, and return the bundle root. Caller deletes it.
    private func makeBundle(assetsCar: Bool, icns: Bool, compiler: Bool = false) throws -> URL {
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
        if compiler {
            try Data("mach-o".utf8).write(to: resources.appendingPathComponent("docktile-actool"))
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

    @Test("Removes the compiler whichever icon pipeline generated the helper")
    func alwaysRemovesCompiler() throws {
        // THE regression guard for a strip gated on the pipeline: a pre-Tahoe host still bundles
        // docktile-actool, and a helper generated there must not carry a dead executable it can
        // never run. `stripMainAppIcons` takes no pipeline flag precisely so this cannot regress —
        // reintroducing one would have to change this call, not just slip past it.
        let bundle = try makeBundle(assetsCar: true, icns: true, compiler: true)
        defer { try? FileManager.default.removeItem(at: bundle.deletingLastPathComponent()) }

        HelperBundleManager.stripMainAppIcons(inBundle: bundle)

        #expect(exists(bundle, "Contents/Resources/docktile-actool") == false)
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
        // Resources dir still intact — we only target the icon files.
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

    /// A name of only emoji or punctuation sanitized to "" and gave `<support>/.app`, a hidden folder
    /// that `findExistingHelper` never found (Update, Delete and self-heal all missed the bundle).
    /// Failing value: without the fallback the base is "" and the folder ".app".
    @Test("A name with nothing to keep falls back to the short id")
    func emptyBaseFallsBackToShortId() {
        #expect(HelperBundleManager.helperBaseName(name: "🚀", shortId: "B4EF96A2") == "B4EF96A2")
        #expect(HelperBundleManager.helperBaseName(name: " !!! ", shortId: "B4EF96A2") == "B4EF96A2")
        #expect(HelperBundleManager.helperFolderName(
            baseName: HelperBundleManager.helperBaseName(name: "🚀", shortId: "B4EF96A2"),
            cleanNameTakenByOther: false, shortId: "B4EF96A2") == "B4EF96A2.app")
    }

    @Test("A name with something to keep is sanitized as before")
    func nonEmptyBaseIsSanitized() {
        #expect(HelperBundleManager.helperBaseName(name: "Work & Play", shortId: "B4EF96A2") == "Work  Play")
        #expect(HelperBundleManager.helperBaseName(name: "🚀 Ship", shortId: "B4EF96A2") == "Ship")
    }

    /// The legacy `.app` folder must be adopted so the tile's next rebuild removes it. `pathExtension`
    /// of a bare `.app` is "" — the reason the old `== "app"` filter never saw it.
    @Test("The scan accepts *.app and the legacy bare .app, nothing else")
    func helperFolderNames() throws {
        #expect(HelperBundleManager.isHelperFolderName("Dev.app"))
        #expect(HelperBundleManager.isHelperFolderName("Ship-52300A6C.app"))
        #expect(HelperBundleManager.isHelperFolderName(".app"))
        #expect(!HelperBundleManager.isHelperFolderName(".staging"))
        #expect(!HelperBundleManager.isHelperFolderName("diagnostics.log"))
        #expect(!HelperBundleManager.isHelperFolderName("Dev"))
        #expect(URL(fileURLWithPath: "/a/.app").pathExtension == "")
    }

    /// On the real file system: a directory listing includes the hidden `.app` folder, and the scan
    /// rule picks it out.
    @Test("A real directory listing yields the hidden legacy folder")
    func legacyFolderIsListed() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HelperFolderNameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".app"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Dev.app"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let listed = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter(HelperBundleManager.isHelperFolderName)
            .sorted()

        #expect(listed == [".app", "Dev.app"])

        // Adopted as the tile's existing folder, the legacy `.app` is what the rebuild removes once
        // the bundle has moved to `<shortId>.app`.
        let legacy = dir.appendingPathComponent(".app")
        let moved = dir.appendingPathComponent("B4EF96A2.app")
        #expect(HelperBundleManager.oldFolderToRemove(existing: legacy, final: moved) == legacy)
    }
}

// MARK: - Dock entry label (the tooltip must be the tile name, never the folder stem)

@Suite("Dock file-label")
struct DockFileLabelTests {

    /// Bundle names now carry the tile's real name, so a name of only spaces reached the Dock as a
    /// blank tooltip. Failing value: an `isEmpty`-only check returns "   ".
    @Test("A whitespace-only bundle name falls back to the folder stem")
    func whitespaceNameFallsBack() {
        let plist: [String: Any] = ["CFBundleDisplayName": "   ", "CFBundleName": "   "]
        #expect(HelperBundleManager.dockFileLabel(infoPlist: plist, folderStem: "B4EF96A2") == "B4EF96A2")
    }

    @Test("Display name wins over a disambiguated folder stem")
    func displayNameBeatsFolderStem() {
        // The shipped bug: the second same-named tile lives in Utils-B4EF96A2.app and the Dock
        // tooltip showed the stem. The Dock renders file-label verbatim, so it must be the name.
        let plist: [String: Any] = ["CFBundleDisplayName": "Utils", "CFBundleName": "Utils"]
        #expect(HelperBundleManager.dockFileLabel(infoPlist: plist, folderStem: "Utils-B4EF96A2") == "Utils")
    }

    @Test("Falls back to CFBundleName, then to the folder stem")
    func fallbackOrder() {
        #expect(HelperBundleManager.dockFileLabel(
            infoPlist: ["CFBundleName": "AI Tile"], folderStem: "AI Tile-EA03FD62") == "AI Tile")
        #expect(HelperBundleManager.dockFileLabel(infoPlist: [:], folderStem: "Media") == "Media")
    }

    @Test("Blank names are treated as absent")
    func blankNamesSkipped() {
        let plist: [String: Any] = ["CFBundleDisplayName": "", "CFBundleName": "Dev"]
        #expect(HelperBundleManager.dockFileLabel(infoPlist: plist, folderStem: "Dev-42EF7FC1") == "Dev")
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
