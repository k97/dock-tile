//
//  HelperSelfHealTests.swift
//  DockTileTests
//
//  Guards the version-independent self-heal:
//    1. `classifyHelperHealth` — the pure decision (only PINNED tiles are repair targets, so a
//       draft the user never Added can never be force-pinned).
//    2. `helperIconsComplete` — the structural-integrity probe over a real temp bundle (catches the
//       killed-mid-generation bundle: missing / zero-length generated `.icns`).
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite("Helper self-heal triage")
struct HelperSelfHealClassifyTests {

    private func classify(pinned: Bool, exists: Bool, icons: Bool, baked: Bool) -> HelperMigrationManager.HelperHealth {
        HelperMigrationManager.classifyHelperHealth(
            isPinnedInDock: pinned, bundleExists: exists,
            iconsComplete: icons, bakedVersionMatchesCurrent: baked)
    }

    @Test("Unpinned tile is never a repair target, whatever its on-disk state (drafts are safe)")
    func unpinnedNeverHeals() {
        #expect(classify(pinned: false, exists: false, icons: false, baked: false) == .healthy)
        #expect(classify(pinned: false, exists: true, icons: true, baked: true) == .healthy)
    }

    @Test("Pinned + healthy bundle (present, complete, current) → healthy")
    func pinnedHealthy() {
        #expect(classify(pinned: true, exists: true, icons: true, baked: true) == .healthy)
    }

    @Test("Pinned + missing bundle → heal")
    func pinnedMissing() {
        #expect(classify(pinned: true, exists: false, icons: false, baked: false) == .heal)
    }

    @Test("Pinned + present but structurally corrupt (icons incomplete) → heal")
    func pinnedCorruptIcons() {
        #expect(classify(pinned: true, exists: true, icons: false, baked: true) == .heal)
    }

    @Test("Pinned + present + complete icons but built by an older app version → heal")
    func pinnedStaleBakedVersion() {
        #expect(classify(pinned: true, exists: true, icons: true, baked: false) == .heal)
    }
}

@Suite("Helper icon integrity probe")
@MainActor
struct HelperIconsCompleteTests {

    /// All five generated icon files a healthy helper carries.
    private let iconNames = ["AppIcon.icns", "AppIcon-default.icns", "AppIcon-dark.icns",
                             "AppIcon-clear.icns", "AppIcon-tinted.icns"]

    /// Build a temp `.app` with a Resources dir; `present` names get a non-empty file.
    private func makeBundle(present: [String], zeroLength: [String] = []) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("selfheal-\(UUID().uuidString)")
        let resources = root.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        for name in present {
            try Data([0x69, 0x63, 0x6e, 0x73]).write(to: resources.appendingPathComponent(name))
        }
        for name in zeroLength {
            try Data().write(to: resources.appendingPathComponent(name))
        }
        return root
    }

    @Test("A complete icon set reports healthy")
    func completeSetIsComplete() throws {
        let bundle = try makeBundle(present: iconNames)
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == true)
    }

    @Test("Missing the active AppIcon.icns → incomplete (the killed-mid-generation Ship case)")
    func missingActiveIcon() throws {
        let bundle = try makeBundle(present: iconNames.filter { $0 != "AppIcon.icns" })
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == false)
    }

    @Test("Missing a single style variant → incomplete")
    func missingVariant() throws {
        let bundle = try makeBundle(present: iconNames.filter { $0 != "AppIcon-dark.icns" })
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == false)
    }

    @Test("A zero-length icon file counts as incomplete (half-written)")
    func zeroLengthIsIncomplete() throws {
        let bundle = try makeBundle(
            present: iconNames.filter { $0 != "AppIcon-tinted.icns" },
            zeroLength: ["AppIcon-tinted.icns"])
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == false)
    }
}
