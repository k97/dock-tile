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

    // MARK: - Per-layout persistence (Grid & List stored independently)

    /// Isolated ephemeral suite per call (unique name, torn down in `defer`) — never touches
    /// `UserDefaults.standard`, so it's parallel-safe.
    private func withTempDefaults(_ body: (UserDefaults) -> Void) {
        let name = "com.docktile.tests.popover.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        body(d)
    }

    @Test("Grid and List configs persist to independent keys and never bleed into each other")
    func gridAndListPersistIndependently() {
        withTempDefaults { d in
            var grid = PopoverSettings.default
            grid.popoverSize = .large
            grid.tileSize = .large
            var list = PopoverSettings.default
            list.popoverSize = .small
            list.spacing = .compact

            grid.persist(layout: .grid, to: d)
            list.persist(layout: .list, to: d)

            let loadedGrid = PopoverSettings.load(layout: .grid, from: d)
            let loadedList = PopoverSettings.load(layout: .list, from: d)
            #expect(loadedGrid.popoverSize == .large)
            #expect(loadedGrid.tileSize == .large)
            #expect(loadedList.popoverSize == .small)
            #expect(loadedList.spacing == .compact)
            // The other layout's fields are untouched by each write.
            #expect(loadedGrid.spacing == .comfortable)
            #expect(loadedList.tileSize == .medium)
        }
    }

    @Test("List config never writes a Show Labels key; List load always resolves showLabels true")
    func listSkipsShowLabels() {
        withTempDefaults { d in
            var list = PopoverSettings.default
            list.showLabels = false   // even if a caller flips it, List must not persist it
            list.persist(layout: .list, to: d)

            #expect(d.object(forKey: UserDefaultsKeys.popoverListSize) != nil)
            #expect(d.object(forKey: "popover.list.showLabels") == nil)
            // A list popover always labels its rows, regardless of any stored value.
            #expect(PopoverSettings.load(layout: .list, from: d).showLabels == true)
        }
    }

    @Test("Absent per-layout values resolve to the spec defaults")
    func loadDefaultsWhenAbsent() {
        withTempDefaults { d in
            #expect(PopoverSettings.load(layout: .grid, from: d) == PopoverSettings.default)
            #expect(PopoverSettings.load(layout: .list, from: d) == PopoverSettings.default)
        }
    }
}
