//
//  PopoverAppearance.swift
//  DockTile
//
//  Global appearance settings for the Dock tile popover (Grid / List), tuned from
//  Settings → General → Popover Appearance. App-wide defaults that every tile's popover
//  inherits — the per-tile Grid/List choice still lives on the Tile Detail screen.
//
//  Persisted in the SHARED suite (com.docktile.shared) so HELPER bundles — which actually
//  render the popover — read the same values as the main app, exactly like analytics consent.
//
//  Swift 6 - Strict Concurrency
//

import Foundation
import CoreGraphics

// MARK: - Tiers

/// Three-tier size, used by both "Popover Size" (overall width / grid columns) and
/// "Tile Size" (icon/cell size within the popover). Independent controls, same scale.
enum PopoverSizeTier: String, CaseIterable, Codable, Hashable {
    case small
    case medium
    case large
}

/// Open/close + content motion. `default`/`fast` map to durations; `none` is instant.
/// Always forced to `none` (and the picker disabled) when system Reduce Motion is on.
enum PopoverAnimationTier: String, CaseIterable, Codable, Hashable {
    case none
    case `default`
    case fast
}

/// Gap + padding between items inside the popover. Hit targets stay ≥44pt at every tier.
enum PopoverSpacingTier: String, CaseIterable, Codable, Hashable {
    case compact
    case comfortable
    case spacious
}

// MARK: - Settings value

/// The six global popover-appearance values. Defaults keep the popover roomy (density opt-in).
struct PopoverSettings: Equatable {
    var popoverSize: PopoverSizeTier
    var tileSize: PopoverSizeTier
    var animation: PopoverAnimationTier
    var spacing: PopoverSpacingTier
    var showLabels: Bool
    var highlightOnHover: Bool

    /// Spec defaults — identical to today's roomy feel; Reduce Motion overrides `animation` at render.
    static let `default` = PopoverSettings(
        popoverSize: .medium,
        tileSize: .medium,
        animation: .default,
        spacing: .comfortable,
        showLabels: true,
        highlightOnHover: true
    )

    /// The shared-suite keys for one layout's config. Grid and List are stored independently; List
    /// has no `showLabels` key (a list popover always labels its rows).
    private struct Keys {
        let size, tileSize, animation, spacing, highlightOnHover: String
        let showLabels: String?
    }

    private static func keys(for layout: LayoutMode) -> Keys {
        switch layout {
        case .grid:
            return Keys(size: UserDefaultsKeys.popoverGridSize,
                        tileSize: UserDefaultsKeys.popoverGridTileSize,
                        animation: UserDefaultsKeys.popoverGridAnimation,
                        spacing: UserDefaultsKeys.popoverGridSpacing,
                        highlightOnHover: UserDefaultsKeys.popoverGridHighlightOnHover,
                        showLabels: UserDefaultsKeys.popoverGridShowLabels)
        case .list:
            return Keys(size: UserDefaultsKeys.popoverListSize,
                        tileSize: UserDefaultsKeys.popoverListTileSize,
                        animation: UserDefaultsKeys.popoverListAnimation,
                        spacing: UserDefaultsKeys.popoverListSpacing,
                        highlightOnHover: UserDefaultsKeys.popoverListHighlightOnHover,
                        showLabels: nil)
        }
    }

    /// Read one layout's config from the shared suite. Used by helper popovers (which can't use
    /// `@AppStorage` ergonomically across processes) — a grid tile loads `.grid`, a list tile `.list`.
    /// Delegates parsing to the pure `resolve(...)` seam so the fallback logic is unit-tested without
    /// touching real UserDefaults. List has no stored `showLabels` → resolves to `true` (always labels).
    static func load(
        layout: LayoutMode,
        from defaults: UserDefaults? = UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName)
    ) -> PopoverSettings {
        guard let d = defaults else { return .default }
        let k = keys(for: layout)
        return resolve(
            sizeRaw: d.string(forKey: k.size),
            tileRaw: d.string(forKey: k.tileSize),
            animationRaw: d.string(forKey: k.animation),
            spacingRaw: d.string(forKey: k.spacing),
            // `object(forKey:)` distinguishes "absent" (→ default ON) from an explicit false.
            showLabels: k.showLabels.flatMap { d.object(forKey: $0) as? Bool },
            highlightOnHover: d.object(forKey: k.highlightOnHover) as? Bool
        )
    }

    /// Write one layout's config to the shared suite — the explicit counterpart to `load(layout:)`.
    /// The Settings pane stages edits per layout and calls this for both on **Save**, so helper
    /// popovers pick up a coherent set on their next open (not mid-edit). List skips `showLabels`.
    func persist(
        layout: LayoutMode,
        to defaults: UserDefaults? = UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName)
    ) {
        guard let d = defaults else { return }
        let k = Self.keys(for: layout)
        d.set(popoverSize.rawValue, forKey: k.size)
        d.set(tileSize.rawValue, forKey: k.tileSize)
        d.set(animation.rawValue, forKey: k.animation)
        d.set(spacing.rawValue, forKey: k.spacing)
        d.set(highlightOnHover, forKey: k.highlightOnHover)
        if let showLabelsKey = k.showLabels { d.set(showLabels, forKey: showLabelsKey) }
    }

    /// Pure mapping from raw stored values → settings, with the spec defaults as the fallback for
    /// any absent or unrecognised value. The tested seam (`PopoverMetricsTests`).
    nonisolated static func resolve(
        sizeRaw: String?,
        tileRaw: String?,
        animationRaw: String?,
        spacingRaw: String?,
        showLabels: Bool?,
        highlightOnHover: Bool?
    ) -> PopoverSettings {
        PopoverSettings(
            popoverSize: PopoverSizeTier(rawValue: sizeRaw ?? "") ?? .medium,
            tileSize: PopoverSizeTier(rawValue: tileRaw ?? "") ?? .medium,
            animation: PopoverAnimationTier(rawValue: animationRaw ?? "") ?? .default,
            spacing: PopoverSpacingTier(rawValue: spacingRaw ?? "") ?? .comfortable,
            showLabels: showLabels ?? true,
            highlightOnHover: highlightOnHover ?? true
        )
    }
}

// MARK: - Metrics seam (pure, unit-tested)

/// Concrete pixel sizing for the popover grid layout, derived purely from the tier settings.
struct PopoverGridMetrics: Equatable {
    let columns: Int
    let iconSize: CGFloat
    let cornerRadius: CGFloat
    let glyphSize: CGFloat
    let gap: CGFloat
    let cellWidth: CGFloat
}

/// Concrete pixel sizing for the popover list layout.
struct PopoverListMetrics: Equatable {
    let width: CGFloat
    let iconSize: CGFloat
    let cornerRadius: CGFloat
    let rowVerticalPadding: CGFloat
    let rowSpacing: CGFloat
    let fontSize: CGFloat
}

/// Pure mapping from tier settings → concrete dimensions. The single source of truth shared by
/// the live preview in `PopoverAppearanceView` and the real popovers in `NativePopoverViews`, so
/// the studio preview can never drift from what the Dock actually renders. Guarded by
/// `PopoverMetricsTests` (regression-guard convention).
enum PopoverMetrics {

    // MARK: Grid

    /// Grid column count. Small = 4, Medium = 5, Large = 6 (the design's discrete column map —
    /// item size is driven by a small set of column counts, not free pixels).
    nonisolated static func gridColumns(_ size: PopoverSizeTier) -> Int {
        switch size {
        case .small: return 4
        case .medium: return 5
        case .large: return 6
        }
    }

    /// Icon/cell size within the popover. Never below 44pt so the hit target stays ≥44pt.
    nonisolated static func tileIconSize(_ size: PopoverSizeTier) -> CGFloat {
        switch size {
        case .small: return 44
        case .medium: return 56
        case .large: return 72
        }
    }

    nonisolated static func gridGap(_ spacing: PopoverSpacingTier) -> CGFloat {
        switch spacing {
        case .compact: return 8
        case .comfortable: return 14
        case .spacious: return 20
        }
    }

    nonisolated static func grid(
        popoverSize: PopoverSizeTier,
        tileSize: PopoverSizeTier,
        spacing: PopoverSpacingTier,
        showLabels: Bool
    ) -> PopoverGridMetrics {
        let icon = tileIconSize(tileSize)
        // Label adds ~26pt of text gutter to the cell; icon-only cells get a tight 6pt margin.
        let cellWidth = icon + (showLabels ? 26 : 6)
        return PopoverGridMetrics(
            columns: gridColumns(popoverSize),
            iconSize: icon,
            cornerRadius: (icon * 0.225).rounded(),
            glyphSize: (icon * 0.42).rounded(),
            gap: gridGap(spacing),
            cellWidth: cellWidth
        )
    }

    // MARK: List

    /// List icon size is driven by Tile Size (the list is always one column).
    nonisolated static func listIconSize(_ tileSize: PopoverSizeTier) -> CGFloat {
        switch tileSize {
        case .small: return 18
        case .medium: return 24
        case .large: return 32
        }
    }

    /// List popover width is driven by Popover Size.
    nonisolated static func listWidth(_ size: PopoverSizeTier) -> CGFloat {
        switch size {
        case .small: return 200
        case .medium: return 240
        case .large: return 280
        }
    }

    nonisolated static func list(
        popoverSize: PopoverSizeTier,
        tileSize: PopoverSizeTier,
        spacing: PopoverSpacingTier
    ) -> PopoverListMetrics {
        let icon = listIconSize(tileSize)
        let rowPad: CGFloat = {
            switch spacing {
            case .compact: return 3
            case .comfortable: return 6
            case .spacious: return 10
            }
        }()
        let rowSpacing: CGFloat = {
            switch spacing {
            case .compact: return 8
            case .comfortable: return 10
            case .spacious: return 13
            }
        }()
        return PopoverListMetrics(
            width: listWidth(popoverSize),
            iconSize: icon,
            cornerRadius: (icon * 0.25).rounded(),
            rowVerticalPadding: rowPad,
            rowSpacing: rowSpacing,
            fontSize: tileSize == .large ? 14 : 13
        )
    }

    // MARK: Animation

    /// Open/close + content motion duration in seconds. Reduce Motion forces 0 regardless of tier.
    nonisolated static func animationDuration(_ tier: PopoverAnimationTier, reduceMotion: Bool) -> Double {
        if reduceMotion { return 0 }
        switch tier {
        case .none: return 0
        case .default: return 0.25
        case .fast: return 0.15
        }
    }
}

// MARK: - Panel geometry

/// The popover panels' chrome geometry and size formulas — the single place either the real panel
/// or the editor/preview canvas can be resized from.
///
/// **Why this is one seam (critical)**: `StackPopoverView` pins its own width AND height from these
/// formulas, so a grid panel and the canvas around it can only disagree if two copies drift.
/// `ListPopoverView` pins only its **width** and takes an intrinsic height, which makes the canvas's
/// estimate load-bearing — an underestimate CLIPS the real panel, because the canvas frames it and
/// clips to that frame. Both formulas did live in two places and did drift: the empty-list case
/// reached the canvas billing one 36pt row while the panel rendered its ~110pt empty state, cutting
/// off the tile-name header and the last line of the hint. Guarded by `PopoverPreviewCanvasTests`.
enum PopoverPanelLayout {

    // MARK: Grid chrome (`StackPopoverView`)

    static let gridHeaderHeight: CGFloat = 36
    /// Applied on all four sides of the grid content.
    static let gridPadding: CGFloat = 16
    /// Height of the grid's own "no apps" state.
    static let gridEmptyHeight: CGFloat = 180
    /// Floor for the EMPTY grid panel's width. Column count is capped at the app count, so a tile
    /// with no apps would otherwise be a single 82pt column — a sliver the empty state's two lines
    /// wrap to shreds inside.
    static let gridEmptyMinWidth: CGFloat = 260
    /// Floor for a populated grid panel. The header reserves a 28pt gutter on each side (the gear
    /// and its balancing spacer), so a one-app tile's single column left the title ~26pt and it
    /// wrapped onto a second line. Two columns (210pt) already clear this, so only the one-app case
    /// is widened.
    static let gridMinWidth: CGFloat = 180
    /// The real popover scrolls past this; the editor does not (Tile Detail scrolls instead).
    static let gridScrollCap: CGFloat = 600
    /// Label line under a grid cell when Show Labels is on: a 4pt gap + one 14pt line.
    static let gridLabelHeight: CGFloat = 18
    /// 2pt cell padding, top and bottom.
    static let gridCellPadding: CGFloat = 4
    /// The editor-only "Not installed" caption under a missing app's icon: the cell VStack's 4pt
    /// spacing + one 10pt line. Billed for EVERY row when any app in the tile is missing — which
    /// row holds it isn't known here, and over-reserving leaves slack while under-reserving clips.
    static let gridMissingCaptionHeight: CGFloat = 17

    // MARK: List chrome (`ListPopoverView`)

    /// The tile-name header: one 13pt line inside `listHeaderVerticalPadding` top and bottom.
    static let listHeaderHeight: CGFloat = 32
    static let listHeaderVerticalPadding: CGFloat = 8
    /// The panel's own padding above the first row and below the last.
    static let listOuterVerticalPadding: CGFloat = 8
    /// `emptyStateView`'s own vertical padding, top and bottom.
    static let listEmptyStatePadding: CGFloat = 16
    /// The EDIT-mode empty state: a 13pt title line, 4pt spacing, and an 11pt subtitle that wraps to
    /// two lines at the default tier's text width. 16 + 4 + 28.
    ///
    /// The two-line figure is measured against the shipped English copy ("Use Add to choose what
    /// opens from this tile.") — the three shipped locales are all English, so it holds today. A
    /// longer translation would wrap to three lines and be clipped: if a non-English locale is ever
    /// added, either raise this or cap the subtitle at two lines.
    static let listEmptyStateTextHeight: CGFloat = 48
    /// The SHIPPED empty state: the same 13pt title line, with no subtitle under it.
    static let listEmptyStateShippedTextHeight: CGFloat = 16
    /// The helper popover's trailing utility block (never shown in the editor): a 1pt `Divider`
    /// inside 4pt top/bottom padding, then two `ListMenuRow`s of ~24pt each (a 13pt line inside
    /// 4pt top/bottom padding). 1 + 8 + 48.
    static let listUtilityRowsHeight: CGFloat = 57
    static let listRowMinHeight: CGFloat = 28

    /// Columns actually drawn: the Popover Size tier capped at the app count, so a tile with fewer
    /// apps than columns stays tight instead of padding out empty trailing columns.
    nonisolated static func columnCount(metricsColumns: Int, appCount: Int) -> Int {
        max(1, min(metricsColumns, max(1, appCount)))
    }

    /// A grid panel's intrinsic size, uncapped. `StackPopoverView` applies `gridScrollCap` to the
    /// height outside the editor; the editor and the canvas use the full value.
    nonisolated static func gridPanelSize(
        metrics: PopoverGridMetrics,
        appCount: Int,
        showLabels: Bool,
        includesMissingCaption: Bool = false
    ) -> CGSize {
        let cols = columnCount(metricsColumns: metrics.columns, appCount: appCount)
        let width = metrics.cellWidth * CGFloat(cols)
            + metrics.gap * CGFloat(cols - 1)
            + gridPadding * 2
        guard appCount > 0 else {
            return CGSize(width: max(width, gridEmptyMinWidth), height: gridEmptyHeight)
        }
        let rows = Int(ceil(Double(appCount) / Double(cols)))
        let itemHeight = metrics.iconSize
            + (showLabels ? gridLabelHeight : 0)
            + (includesMissingCaption ? gridMissingCaptionHeight : 0)
            + gridCellPadding
        let height = gridHeaderHeight
            + CGFloat(rows) * itemHeight
            + CGFloat(rows - 1) * metrics.gap
            + gridPadding * 2
        return CGSize(width: max(width, gridMinWidth), height: height)
    }

    /// A list panel's intrinsic size. The width is what `ListPopoverView` pins; the height is the
    /// estimate the canvas must not undershoot.
    ///
    /// `hasHeader` mirrors `ListPopoverView`'s `if !tileName.isEmpty` — a tile whose name has been
    /// cleared draws no title row, and billing for one leaves a visible gap under the panel.
    ///
    /// **`isEditing` is the panel's whole mode**, not one detail of it: the editor drops the trailing
    /// utility rows and shows a taller two-line empty state, while the shipped popover does the
    /// reverse. Passing it as one flag keeps those two facts from disagreeing — they were previously
    /// a `includesUtilityRows` parameter plus an *unstated* assumption that the empty branch was
    /// always the editor's.
    nonisolated static func listPanelSize(
        metrics: PopoverListMetrics,
        appCount: Int,
        isEditing: Bool,
        hasHeader: Bool
    ) -> CGSize {
        let header = hasHeader ? listHeaderHeight : 0
        guard appCount > 0 else {
            let height = header
                + listEmptyStatePadding * 2
                + (isEditing ? listEmptyStateTextHeight : listEmptyStateShippedTextHeight)
                + listOuterVerticalPadding * 2
            return CGSize(width: metrics.width, height: height)
        }
        let rowHeight = max(
            listRowMinHeight,
            max(metrics.iconSize, metrics.fontSize + 3) + metrics.rowVerticalPadding * 2
        )
        let height = header
            + CGFloat(appCount) * rowHeight
            + (isEditing ? 0 : listUtilityRowsHeight)
            + listOuterVerticalPadding * 2
        return CGSize(width: metrics.width, height: height)
    }
}
