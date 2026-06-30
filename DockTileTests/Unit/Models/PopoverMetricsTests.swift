import Testing
import Foundation
@testable import Dock_Tile

/// Regression guard for the popover sizing seam (`PopoverMetrics`) and the shared-suite loader
/// (`PopoverSettings.load`). These pure mappings drive BOTH the live preview in the settings pane
/// and the real Dock popover, so a broken mapping would silently desync the two — exactly the kind
/// of invariant the project pins behind a tested seam.
@Suite("Popover Metrics")
struct PopoverMetricsTests {

    // MARK: - Grid columns

    @Test("Grid columns: Small 4 / Medium 5 / Large 6")
    func gridColumns() {
        #expect(PopoverMetrics.gridColumns(.small) == 4)
        #expect(PopoverMetrics.gridColumns(.medium) == 5)
        #expect(PopoverMetrics.gridColumns(.large) == 6)
    }

    // MARK: - Tile icon size (hit-target floor)

    @Test("Tile icon size grows with the tier and never drops below the 44pt hit target")
    func tileIconSize() {
        #expect(PopoverMetrics.tileIconSize(.small) == 44)
        #expect(PopoverMetrics.tileIconSize(.medium) == 56)
        #expect(PopoverMetrics.tileIconSize(.large) == 72)
        // The smallest tier must still clear the 44pt minimum hit area.
        #expect(PopoverMetrics.tileIconSize(.small) >= 44)
    }

    // MARK: - Spacing

    @Test("Grid gap: Compact 8 / Comfortable 14 / Spacious 20")
    func gridGap() {
        #expect(PopoverMetrics.gridGap(.compact) == 8)
        #expect(PopoverMetrics.gridGap(.comfortable) == 14)
        #expect(PopoverMetrics.gridGap(.spacious) == 20)
    }

    // MARK: - Grid composite

    @Test("Grid cell width adds a label gutter only when labels are shown")
    func gridCellWidthLabelGutter() {
        let withLabels = PopoverMetrics.grid(popoverSize: .medium, tileSize: .medium, spacing: .comfortable, showLabels: true)
        let noLabels = PopoverMetrics.grid(popoverSize: .medium, tileSize: .medium, spacing: .comfortable, showLabels: false)
        // 56pt icon: 56 + 26 (label) vs 56 + 6 (icon-only).
        #expect(withLabels.cellWidth == 82)
        #expect(noLabels.cellWidth == 62)
        // The icon itself is unchanged by the label toggle.
        #expect(withLabels.iconSize == noLabels.iconSize)
    }

    @Test("Grid corner radius and glyph size derive from the icon size")
    func gridDerivedSizes() {
        let m = PopoverMetrics.grid(popoverSize: .large, tileSize: .large, spacing: .spacious, showLabels: true)
        #expect(m.iconSize == 72)
        #expect(m.cornerRadius == 16)   // round(72 * 0.225)
        #expect(m.glyphSize == 30)      // round(72 * 0.42)
        #expect(m.columns == 6)
        #expect(m.gap == 20)
    }

    // MARK: - List

    @Test("List width tracks Popover Size; icon + font track Tile Size")
    func listMetrics() {
        let small = PopoverMetrics.list(popoverSize: .small, tileSize: .small, spacing: .compact)
        let large = PopoverMetrics.list(popoverSize: .large, tileSize: .large, spacing: .spacious)
        #expect(small.width == 200)
        #expect(large.width == 280)
        #expect(small.iconSize == 18)
        #expect(large.iconSize == 32)
        // Only the large tile size bumps the font; the rest stay at 13pt.
        #expect(small.fontSize == 13)
        #expect(large.fontSize == 14)
        #expect(PopoverMetrics.list(popoverSize: .medium, tileSize: .medium, spacing: .comfortable).fontSize == 13)
    }

    // MARK: - Animation + Reduce Motion override

    @Test("Animation durations map per tier")
    func animationDurations() {
        #expect(PopoverMetrics.animationDuration(.none, reduceMotion: false) == 0)
        #expect(PopoverMetrics.animationDuration(.default, reduceMotion: false) == 0.25)
        #expect(PopoverMetrics.animationDuration(.fast, reduceMotion: false) == 0.15)
    }

    @Test("Reduce Motion forces every tier to zero duration")
    func reduceMotionOverridesAnimation() {
        for tier in PopoverAnimationTier.allCases {
            #expect(PopoverMetrics.animationDuration(tier, reduceMotion: true) == 0)
        }
    }

    // MARK: - PopoverSettings.resolve (shared-suite defaults)

    @Test("resolve() returns spec defaults when every value is absent")
    func resolveDefaults() {
        let s = PopoverSettings.resolve(
            sizeRaw: nil, tileRaw: nil, animationRaw: nil,
            spacingRaw: nil, showLabels: nil, highlightOnHover: nil
        )
        #expect(s == PopoverSettings.default)
        #expect(s.popoverSize == .medium)
        #expect(s.tileSize == .medium)
        #expect(s.animation == .default)
        #expect(s.spacing == .comfortable)
        #expect(s.showLabels == true)
        #expect(s.highlightOnHover == true)
    }

    @Test("resolve() reads stored values and treats an explicit false toggle as off")
    func resolveStored() {
        let s = PopoverSettings.resolve(
            sizeRaw: PopoverSizeTier.large.rawValue,
            tileRaw: PopoverSizeTier.small.rawValue,
            animationRaw: PopoverAnimationTier.fast.rawValue,
            spacingRaw: PopoverSpacingTier.compact.rawValue,
            showLabels: false,
            highlightOnHover: false
        )
        #expect(s.popoverSize == .large)
        #expect(s.tileSize == .small)
        #expect(s.animation == .fast)
        #expect(s.spacing == .compact)
        #expect(s.showLabels == false)
        #expect(s.highlightOnHover == false)
    }

    @Test("resolve() falls back to the default for an unrecognised stored tier")
    func resolveGarbageFallsBack() {
        let s = PopoverSettings.resolve(
            sizeRaw: "enormous", tileRaw: nil, animationRaw: "warp",
            spacingRaw: nil, showLabels: nil, highlightOnHover: nil
        )
        #expect(s.popoverSize == .medium)
        #expect(s.animation == .default)
    }
}
