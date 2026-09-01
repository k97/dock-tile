//
//  HelperSelfHealTests.swift
//  DockTileTests
//
//  Guards the version-independent self-heal:
//    1. `classifyHelperHealth` — the pure decision (only PINNED tiles are repair targets, so a
//       draft the user never Added can never be force-pinned).
//    2. `helperIconsComplete(resourcesContents:declarative:)` — the pure structural-integrity
//       seam, plus `helperIconsComplete(at:)`, its instance wrapper over a real temp bundle
//       (catches the killed-mid-generation bundle: missing / zero-length generated icon files).
//       Declarative-complete means `Assets.car` + `AppIcon.icns` both present and non-empty;
//       legacy-complete is unchanged (`AppIcon.icns` + the four style variants). Critically, a
//       LEGACY-shaped bundle evaluated as `declarative: true` must be INCOMPLETE — that's exactly
//       what makes every existing helper regenerate into the new shape on its first Tahoe launch
//       of the new version.
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

/// Pure seam tests — plain `[String: Int]` byte sizes in, no filesystem. Deterministic regardless
/// of which OS runs the suite (unlike the instance method below, which reads
/// `IconPipeline.isDeclarative` from the real running OS).
@Suite("Helper icon completeness — pure seam")
struct HelperIconsCompleteSeamTests {

    private let legacyVariants = ["AppIcon.icns": 4, "AppIcon-default.icns": 4,
                                   "AppIcon-dark.icns": 4, "AppIcon-clear.icns": 4,
                                   "AppIcon-tinted.icns": 4]

    // MARK: Legacy contract (declarative: false) — unchanged

    @Test("Legacy: a complete four-variant set is complete")
    func legacyCompleteSetIsComplete() {
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: legacyVariants, declarative: false) == true)
    }

    @Test("Legacy: missing the active AppIcon.icns → incomplete")
    func legacyMissingActiveIcon() {
        var contents = legacyVariants
        contents.removeValue(forKey: "AppIcon.icns")
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: contents, declarative: false) == false)
    }

    @Test("Legacy: missing a single style variant → incomplete")
    func legacyMissingVariant() {
        var contents = legacyVariants
        contents.removeValue(forKey: "AppIcon-dark.icns")
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: contents, declarative: false) == false)
    }

    @Test("Legacy: a zero-length variant counts as incomplete (half-written)")
    func legacyZeroLengthIsIncomplete() {
        var contents = legacyVariants
        contents["AppIcon-tinted.icns"] = 0
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: contents, declarative: false) == false)
    }

    // MARK: Declarative contract — Assets.car + AppIcon.icns

    @Test("Declarative: car + icns both present and non-empty → complete")
    func declarativeCompleteSetIsComplete() {
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: ["Assets.car": 100, "AppIcon.icns": 4], declarative: true) == true)
    }

    @Test("Declarative: missing Assets.car → incomplete")
    func declarativeMissingCar() {
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: ["AppIcon.icns": 4], declarative: true) == false)
    }

    @Test("Declarative: zero-byte Assets.car → incomplete")
    func declarativeZeroByteCar() {
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: ["Assets.car": 0, "AppIcon.icns": 4], declarative: true) == false)
    }

    @Test("Declarative: missing AppIcon.icns → incomplete")
    func declarativeMissingIcns() {
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: ["Assets.car": 100], declarative: true) == false)
    }

    /// THE migration trigger: a bundle built by the OLD (legacy) pipeline — four style variants,
    /// no Assets.car — must classify as INCOMPLETE once evaluated under the declarative rule.
    /// That is not an edge case: it is exactly the mechanism that makes every existing helper
    /// regenerate into the new declarative shape on its first launch of the new app version on
    /// macOS 26. If this test flips to `true`, no old helper would ever self-heal into a car.
    @Test("A LEGACY-shaped bundle evaluated as declarative is INCOMPLETE (the migration trigger)")
    func legacyShapedBundleIsIncompleteUnderDeclarative() {
        #expect(HelperBundleManager.helperIconsComplete(
            resourcesContents: legacyVariants, declarative: true) == false)
    }
}

/// Instance-method integration tests over a real temp bundle. `helperIconsComplete(at:)` reads
/// `IconPipeline.isDeclarative` from the real running OS, so these exercise the actual activation
/// point as it behaves on THIS machine (macOS 26 → declarative). This is the direct evidence that
/// the live defect (every declarative helper misclassifying as corrupt) is fixed: a real
/// declarative-shaped bundle built on disk now reports complete.
@Suite("Helper icon integrity probe (real bundle, current platform)")
@MainActor
struct HelperIconsCompleteTests {

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

    @Test("A real declarative-shaped bundle (Assets.car + AppIcon.icns) reports complete — the live defect is fixed")
    func declarativeShapedBundleIsComplete() throws {
        let bundle = try makeBundle(present: ["Assets.car", "AppIcon.icns"])
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == true)
    }

    @Test("A real LEGACY-shaped bundle (four variants, no Assets.car) reports incomplete on this (declarative) platform")
    func legacyShapedBundleIsIncomplete() throws {
        let bundle = try makeBundle(present: ["AppIcon.icns", "AppIcon-default.icns", "AppIcon-dark.icns",
                                               "AppIcon-clear.icns", "AppIcon-tinted.icns"])
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == false)
    }

    @Test("Missing Assets.car on this platform → incomplete")
    func missingCar() throws {
        let bundle = try makeBundle(present: ["AppIcon.icns"])
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == false)
    }

    @Test("Zero-length Assets.car on this platform → incomplete")
    func zeroLengthCar() throws {
        let bundle = try makeBundle(present: ["AppIcon.icns"], zeroLength: ["Assets.car"])
        defer { try? FileManager.default.removeItem(at: bundle) }
        #expect(HelperBundleManager.shared.helperIconsComplete(at: bundle) == false)
    }
}
