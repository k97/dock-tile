import Testing
import Foundation
import Security
@testable import Dock_Tile

// MARK: - Icon Inventory Format Tests
//
// Guards `DiagnosticsLog.formatIconInventory` — the pure renderer for the Copy Diagnostics section
// built for the Dock icon-size-flap investigation. The section exists so a user's pasted report can
// answer "which shape (legacy variants vs declarative Assets.car) was this pinned tile in, and when
// did its icon files last change" without any live access to their Mac. Every case here pins the
// EXACT rendered text — a silently-reworded or reordered line would be as bad as no section at all
// when someone is trying to read a report a user attached to a bug.

@Suite("DiagnosticsLog.formatIconInventory")
struct IconInventoryFormatTests {

    // Fixed instants so the rendered mtime strings are exact and reproducible.
    private static let earlier = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15T08:00:00Z
    private static let later = Date(timeIntervalSince1970: 1_800_000_060)   // 2027-01-15T08:01:00Z

    @Test("Empty list renders the no-pinned-helpers line, not an empty section")
    func emptyList() {
        let result = DiagnosticsLog.formatIconInventory([])
        #expect(result == "Icon inventory (pinned helpers only):\n  (no pinned helpers)")
    }

    @Test("Legacy row shows seal, the matched variant, and sorted mtimes")
    func legacyRow() {
        let item = HelperIconInventory(
            tileName: "'Dev Tile' (BFDE6AB4)",
            sealValid: true,
            liveIconMatchesVariant: "AppIcon-default.icns",
            carPresent: false,
            carRenditionSummary: nil,
            iconFileMTimes: [
                "AppIcon.icns": Self.earlier,
                "AppIcon-default.icns": Self.later
            ],
            inspectionError: nil
        )
        let result = DiagnosticsLog.formatIconInventory([item])
        let expected = """
        Icon inventory (pinned helpers only):
          'Dev Tile' (BFDE6AB4)
            seal: valid
            shape: legacy — live AppIcon.icns matches AppIcon-default.icns
            mtimes: AppIcon-default.icns=2027-01-15T08:01:00Z, AppIcon.icns=2027-01-15T08:00:00Z
        """
        #expect(result == expected)
    }

    @Test("Legacy row with no matching variant says so explicitly, never silently omits it")
    func legacyRowNoMatch() {
        let item = HelperIconInventory(
            tileName: "'Odd Tile' (AAAAAAAA)",
            sealValid: false,
            liveIconMatchesVariant: "none",
            carPresent: false,
            carRenditionSummary: nil,
            iconFileMTimes: [:],
            inspectionError: nil
        )
        let result = DiagnosticsLog.formatIconInventory([item])
        let expected = """
        Icon inventory (pinned helpers only):
          'Odd Tile' (AAAAAAAA)
            seal: BROKEN
            shape: legacy — live AppIcon.icns matches no known variant
            mtimes: (no icon files found)
        """
        #expect(result == expected)
    }

    @Test("Declarative row shows the car rendition summary, not variant fields")
    func declarativeRow() {
        let item = HelperIconInventory(
            tileName: "'Media' (99E4FB5E)",
            sealValid: true,
            liveIconMatchesVariant: nil,
            carPresent: true,
            carRenditionSummary: "12 renditions, IconImageStack: yes",
            iconFileMTimes: [
                "Assets.car": Self.earlier,
                "AppIcon.icns": Self.later
            ],
            inspectionError: nil
        )
        let result = DiagnosticsLog.formatIconInventory([item])
        let expected = """
        Icon inventory (pinned helpers only):
          'Media' (99E4FB5E)
            seal: valid
            shape: declarative — Assets.car present (12 renditions, IconImageStack: yes)
            mtimes: AppIcon.icns=2027-01-15T08:01:00Z, Assets.car=2027-01-15T08:00:00Z
        """
        #expect(result == expected)
    }

    @Test("Assets.car present but assetutil couldn't summarise it still says so, not silently blank")
    func declarativeRowUnparseableCar() {
        let item = HelperIconInventory(
            tileName: "'Corrupt' (CCCCCCCC)",
            sealValid: true,
            liveIconMatchesVariant: nil,
            carPresent: true,
            carRenditionSummary: nil,
            iconFileMTimes: [:],
            inspectionError: nil
        )
        let result = DiagnosticsLog.formatIconInventory([item])
        let expected = """
        Icon inventory (pinned helpers only):
          'Corrupt' (CCCCCCCC)
            seal: valid
            shape: declarative — Assets.car present (present, assetutil summary unavailable)
            mtimes: (no icon files found)
        """
        #expect(result == expected)
    }

    @Test("A helper whose inspection failed renders its error, not silently vanishes")
    func failedInspectionRow() {
        let item = HelperIconInventory(
            tileName: "'Ghost' (00000000)",
            sealValid: false,
            liveIconMatchesVariant: nil,
            carPresent: false,
            carRenditionSummary: nil,
            iconFileMTimes: [:],
            inspectionError: "no helper bundle found on disk"
        )
        let result = DiagnosticsLog.formatIconInventory([item])
        let expected = """
        Icon inventory (pinned helpers only):
          'Ghost' (00000000)
            INSPECTION FAILED: no helper bundle found on disk
        """
        #expect(result == expected)
    }

    @Test("Neither Assets.car nor a variant match is called out as an unknown shape, not misreported as legacy or declarative")
    func unknownShapeRow() {
        let item = HelperIconInventory(
            tileName: "'Weird' (11111111)",
            sealValid: true,
            liveIconMatchesVariant: nil,
            carPresent: false,
            carRenditionSummary: nil,
            iconFileMTimes: [:],
            inspectionError: nil
        )
        let result = DiagnosticsLog.formatIconInventory([item])
        let expected = """
        Icon inventory (pinned helpers only):
          'Weird' (11111111)
            seal: valid
            shape: unknown — no Assets.car and no variant match found
            mtimes: (no icon files found)
        """
        #expect(result == expected)
    }

    @Test("Multiple pinned helpers render one block each, in the order given — both shapes visible in one report")
    func multipleItemsBothShapes() {
        let legacy = HelperIconInventory(
            tileName: "'Dev Tile' (BFDE6AB4)",
            sealValid: true,
            liveIconMatchesVariant: "AppIcon-dark.icns",
            carPresent: false,
            carRenditionSummary: nil,
            iconFileMTimes: [:],
            inspectionError: nil
        )
        let declarative = HelperIconInventory(
            tileName: "'Media' (99E4FB5E)",
            sealValid: true,
            liveIconMatchesVariant: nil,
            carPresent: true,
            carRenditionSummary: "3 renditions, IconImageStack: yes",
            iconFileMTimes: [:],
            inspectionError: nil
        )
        let result = DiagnosticsLog.formatIconInventory([legacy, declarative])
        let expected = """
        Icon inventory (pinned helpers only):
          'Dev Tile' (BFDE6AB4)
            seal: valid
            shape: legacy — live AppIcon.icns matches AppIcon-dark.icns
            mtimes: (no icon files found)
          'Media' (99E4FB5E)
            seal: valid
            shape: declarative — Assets.car present (3 renditions, IconImageStack: yes)
            mtimes: (no icon files found)
        """
        #expect(result == expected)
    }
}

// MARK: - Helper Seal Report Format Tests
//
// Guards `DiagnosticsLog.formatSealStates` — the other half of the seal dedupe. The seal is now
// validated ONCE per bundle (`HelperBundleManager.helperSealStates`) and rendered from the stored
// state, so this pins the rendered text the report has always carried, including the icon-swap
// note that makes a broken seal readable without looking anything up.

@Suite("DiagnosticsLog.formatSealStates")
struct HelperSealFormatTests {

    @Test("Bundles render sorted by name, one line each, with the valid/broken/unreadable wording")
    func rendersEveryState() {
        let lines = DiagnosticsLog.formatSealStates([
            "Zed.app": .valid,
            "Media.app": .broken(errSecCSBadResource),
            "Alpha.app": .unreadable(-67062)
        ])
        #expect(lines == [
            "  Alpha.app: unreadable (OSStatus -67062)",
            "  Media.app: SEAL BROKEN, OSStatus -67054 (sealed resource modified — icon swap)",
            "  Zed.app: seal valid"
        ])
    }

    @Test("A broken seal that is NOT the icon-swap status omits the icon-swap note")
    func otherBreakageHasNoIconSwapNote() {
        #expect(DiagnosticsLog.formatSealStates(["Tile.app": .broken(-67030)])
            == ["  Tile.app: SEAL BROKEN, OSStatus -67030"])
    }

    @Test("No bundles renders no lines — report() then omits the section entirely")
    func emptyRendersNothing() {
        #expect(DiagnosticsLog.formatSealStates([:]).isEmpty)
    }
}
