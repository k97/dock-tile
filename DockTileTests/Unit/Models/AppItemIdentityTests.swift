//
//  AppItemIdentityTests.swift
//  DockTileTests
//
//  Guards the path-based identity rules that let browser PWAs sharing a bundle id
//  (e.g. the same site installed under different profiles — multi-account inboxes)
//  be added and launched as distinct tiles.
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite struct AppItemIdentityTests {

    private func app(bundleId: String, path: String?) -> AppItem {
        AppItem(bundleIdentifier: bundleId, name: "X", lastKnownPath: path)
    }

    // MARK: - matchesApp (dedup key)

    @Test func distinctPathsWithSharedBundleIdAreNotDuplicates() {
        // Two Outlook PWAs from different profiles: one bundle id, two on-disk bundles.
        let existing = app(bundleId: "com.microsoft.edgemac.app.HASH", path: "/Apps/Outlook Home.app")
        #expect(existing.matchesApp(path: "/Apps/Outlook Work.app",
                                    bundleId: "com.microsoft.edgemac.app.HASH") == false)
    }

    @Test func identicalPathIsDuplicate() {
        let existing = app(bundleId: "com.acme.app", path: "/Apps/Foo.app")
        #expect(existing.matchesApp(path: "/Apps/Foo.app", bundleId: "com.acme.app") == true)
    }

    @Test func legacyItemWithoutPathFallsBackToBundleId() {
        // Pre-v8 config: no stored path, so bundle id is the only signal available.
        let existing = app(bundleId: "com.acme.app", path: nil)
        #expect(existing.matchesApp(path: "/Apps/Foo.app", bundleId: "com.acme.app") == true)
        #expect(existing.matchesApp(path: "/Apps/Foo.app", bundleId: "com.other.app") == false)
    }

    @Test func folderNeverMatchesAnApp() {
        let folder = AppItem(bundleIdentifier: "folder.1", name: "F", isFolder: true, folderPath: "/Apps")
        #expect(folder.matchesApp(path: "/Apps", bundleId: nil) == false)
    }

    // MARK: - resolvedAppURL (launch/resolution target)

    @Test func prefersExistingPathOverBundleResolution() {
        // The bundle id resolves to the "Home" install, but this item is the "Work" one —
        // launch must open Work, not whichever Launch Services picked.
        let url = AppItem.resolvedAppURL(
            lastKnownPath: "/Apps/Outlook Work.app",
            pathExists: true,
            bundleResolvedURL: URL(fileURLWithPath: "/Apps/Outlook Home.app")
        )
        #expect(url == URL(fileURLWithPath: "/Apps/Outlook Work.app"))
    }

    @Test func fallsBackToBundleWhenPathIsStale() {
        // App moved/updated: stored path gone, self-heal via Launch Services.
        let fallback = URL(fileURLWithPath: "/Apps/Foo.app")
        let url = AppItem.resolvedAppURL(lastKnownPath: "/Apps/Stale.app",
                                         pathExists: false,
                                         bundleResolvedURL: fallback)
        #expect(url == fallback)
    }

    @Test func fallsBackToBundleWhenNoStoredPath() {
        let fallback = URL(fileURLWithPath: "/Apps/Foo.app")
        let url = AppItem.resolvedAppURL(lastKnownPath: nil, pathExists: false, bundleResolvedURL: fallback)
        #expect(url == fallback)
    }

    @Test func returnsNilWhenNothingResolves() {
        let url = AppItem.resolvedAppURL(lastKnownPath: nil, pathExists: false, bundleResolvedURL: nil)
        #expect(url == nil)
    }
}
