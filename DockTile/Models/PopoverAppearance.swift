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

    /// Read the current values from the shared suite. Used by helper popovers (which can't use
    /// `@AppStorage` ergonomically across processes). Delegates parsing to the pure `resolve(...)`
    /// seam below so the fallback logic is unit-tested without touching real UserDefaults.
    static func load(
        from defaults: UserDefaults? = UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName)
    ) -> PopoverSettings {
        guard let d = defaults else { return .default }
        return resolve(
            sizeRaw: d.string(forKey: UserDefaultsKeys.popoverSize),
            tileRaw: d.string(forKey: UserDefaultsKeys.popoverTileSize),
            animationRaw: d.string(forKey: UserDefaultsKeys.popoverAnimation),
            spacingRaw: d.string(forKey: UserDefaultsKeys.popoverSpacing),
            // `object(forKey:)` distinguishes "absent" (→ default ON) from an explicit false.
            showLabels: d.object(forKey: UserDefaultsKeys.popoverShowLabels) as? Bool,
            highlightOnHover: d.object(forKey: UserDefaultsKeys.popoverHighlightOnHover) as? Bool
        )
    }

    /// Write these values to the shared suite — the explicit counterpart to `load()`. The Settings
    /// pane stages edits in a draft and calls this only when the user presses **Save**, so helper
    /// popovers pick up a coherent set on their next open (not mid-edit).
    func persist(
        to defaults: UserDefaults? = UserDefaults(suiteName: UserDefaultsKeys.sharedSuiteName)
    ) {
        guard let d = defaults else { return }
        d.set(popoverSize.rawValue, forKey: UserDefaultsKeys.popoverSize)
        d.set(tileSize.rawValue, forKey: UserDefaultsKeys.popoverTileSize)
        d.set(animation.rawValue, forKey: UserDefaultsKeys.popoverAnimation)
        d.set(spacing.rawValue, forKey: UserDefaultsKeys.popoverSpacing)
        d.set(showLabels, forKey: UserDefaultsKeys.popoverShowLabels)
        d.set(highlightOnHover, forKey: UserDefaultsKeys.popoverHighlightOnHover)
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
