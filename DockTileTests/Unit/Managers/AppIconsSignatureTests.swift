//
//  AppIconsSignatureTests.swift
//  DockTileTests
//
//  Guards "Update lights up when an App Grid's app changed on disk". An app's own icon isn't part of
//  the tile, so an app update or a Finder-pasted icon (2026-11-10: a Chrome web app's pasted icon)
//  left the Dock on the old icon while Update read "nothing pending". The build stamps when each
//  drawn app was last modified; Tile Detail compares it with the apps on disk.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("App icons signature (Update after an app changes)")
struct AppIconsSignatureTests {
    private func apps(_ count: Int) -> [AppItem] {
        (0..<count).map { AppItem(bundleIdentifier: "com.example.\($0)", name: "App \($0)", lastKnownPath: "/Apps/\($0).app") }
    }

    private func grid(_ items: [AppItem]) -> DockTileConfiguration {
        DockTileConfiguration(name: "Grid", iconFace: .apps, appItems: items)
    }

    @Test("Moves when a drawn app's modification time changes, and only then")
    func movesWithModificationTime() {
        let config = grid(apps(3))
        let before = HelperBundleManager.appIconsSignature(for: config) { _ in 1_000 }
        let same = HelperBundleManager.appIconsSignature(for: config) { _ in 1_000 }
        let changed = HelperBundleManager.appIconsSignature(for: config) { $0.lastKnownPath == "/Apps/1.app" ? 2_000 : 1_000 }
        #expect(before == same)
        #expect(before != changed)
        #expect(before == config.appItems.map { "\($0.id.uuidString)=1000" }.joined(separator: ","))
    }

    @Test("A missing app (no modification time) moves it too: its cell changes")
    func missingAppCounts() {
        let config = grid(apps(2))
        let installed = HelperBundleManager.appIconsSignature(for: config) { _ in 1_000 }
        let gone = HelperBundleManager.appIconsSignature(for: config) { $0.lastKnownPath == "/Apps/0.app" ? 0 : 1_000 }
        #expect(installed != gone)
    }

    @Test("Only the apps the face can draw: the first nine items, folders left out")
    func scope() {
        var items = apps(10)
        items[2] = AppItem(bundleIdentifier: "folder.1", name: "Folder", isFolder: true, folderPath: "/Folder")
        let config = grid(items)
        let base = HelperBundleManager.appIconsSignature(for: config) { _ in 1_000 }
        #expect(HelperBundleManager.appIconsSignature(for: config) { $0.lastKnownPath == "/Apps/9.app" ? 9 : 1_000 } == base)
        #expect(HelperBundleManager.appIconsSignature(for: config) { $0.isFolder ? 9 : 1_000 } == base)
        #expect(base.split(separator: ",").count == 8)
    }

    @Test("A glyph face draws no app icons: always empty")
    func glyphFace() {
        var config = grid(apps(3))
        config.iconFace = .glyph
        #expect(HelperBundleManager.appIconsSignature(for: config) { _ in 1_000 } == "")
    }

    @Test("A changed app lights Update even when the tile itself is unchanged")
    func lightsUpdate() {
        #expect(DockTileDetailView.actionIsProminent(action: .install, isCurrentlyInDock: true,
                                                     builtDockSignature: "s", dockSignature: "s",
                                                     appIconsChanged: true) == true)
        #expect(DockTileDetailView.actionIsProminent(action: .remove, isCurrentlyInDock: true,
                                                     builtDockSignature: "s", dockSignature: "s",
                                                     appIconsChanged: true) == false)
    }

    @Test("The stamp lands in a staged helper's Info.plist under DTAppIconsSignature")
    func stampedIntoInfoPlist() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("Stamp-\(UUID().uuidString).app")
        defer { try? FileManager.default.removeItem(at: bundle) }
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        #expect((["CFBundleIdentifier": "com.example.helper"] as NSDictionary)
            .write(to: contents.appendingPathComponent("Info.plist"), atomically: true))

        try HelperBundleManager.stampAppIconsSignature("a=1,b=2", inBundle: bundle)

        let plist = try #require(NSDictionary(contentsOf: contents.appendingPathComponent("Info.plist")))
        #expect(plist[HelperBundleManager.appIconsSignatureKey] as? String == "a=1,b=2")
        #expect(plist["CFBundleIdentifier"] as? String == "com.example.helper")
        #expect(HelperBundleManager.appIconsSignatureKey == "DTAppIconsSignature")
    }
}
