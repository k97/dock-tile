//
//  IconSwapAtomicityTests.swift
//  DockTileTests
//
//  Guards `HelperBundleManager.replaceIconAtomically(source:destination:)` — the seam behind
//  `switchIcon`'s icon replacement.
//
//  Why it matters: the old two-step (remove destination, then copy source) was interruptible.
//  A thrown copy — or a helper killed between the two calls — left the bundle with NO
//  `AppIcon.icns` at all plus a broken seal, unrepaired until the once-per-session self-heal,
//  and only if the tile was pinned. The invariant: the destination either keeps its old bytes
//  or holds the new ones — never neither.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("replaceIconAtomically")
struct IconSwapAtomicityTests {

    /// Fresh scratch directory per test; no shared state, parallel-safe.
    private func makeScratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-swap-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Replaces an existing destination with the source bytes")
    func replacesExistingDestination() throws {
        let dir = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("AppIcon-dark.icns")
        let destination = dir.appendingPathComponent("AppIcon.icns")
        try Data("new-dark-variant".utf8).write(to: source)
        try Data("old-live-icon".utf8).write(to: destination)

        try HelperBundleManager.replaceIconAtomically(source: source, destination: destination)

        #expect(try Data(contentsOf: destination) == Data("new-dark-variant".utf8))
        // The source variant file must survive the swap — it is the style library, not a scratch.
        #expect(try Data(contentsOf: source) == Data("new-dark-variant".utf8))
    }

    @Test("Creates the destination when none exists")
    func createsMissingDestination() throws {
        let dir = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("AppIcon-default.icns")
        let destination = dir.appendingPathComponent("AppIcon.icns")
        try Data("default-variant".utf8).write(to: source)

        try HelperBundleManager.replaceIconAtomically(source: source, destination: destination)

        #expect(try Data(contentsOf: destination) == Data("default-variant".utf8))
    }

    @Test("A missing source throws AND leaves the existing destination intact")
    func failedSwapPreservesDestination() throws {
        let dir = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("AppIcon-clear.icns") // never written
        let destination = dir.appendingPathComponent("AppIcon.icns")
        try Data("old-live-icon".utf8).write(to: destination)

        #expect(throws: (any Error).self) {
            try HelperBundleManager.replaceIconAtomically(source: source, destination: destination)
        }
        // THE regression this seam exists for: the old remove-then-copy deleted the live icon
        // first, so this exact failure left the helper with no icon at all.
        #expect(try Data(contentsOf: destination) == Data("old-live-icon".utf8))
    }

    @Test("Leaves no staging file behind in the destination directory")
    func leavesNoStagingResidueBesideDestination() throws {
        let dir = try makeScratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("AppIcon-tinted.icns")
        let destination = dir.appendingPathComponent("AppIcon.icns")
        try Data("tinted-variant".utf8).write(to: source)
        try Data("old-live-icon".utf8).write(to: destination)

        try HelperBundleManager.replaceIconAtomically(source: source, destination: destination)

        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(contents == ["AppIcon-tinted.icns", "AppIcon.icns"])
    }
}
