//
//  IconDepthMetrics.swift
//  DockTile
//
//  Pure, value-in / value-out rules for the "Liquid Glass" depth treatment baked into
//  tile icons and mirrored in the live SwiftUI preview.
//
//  WHY THIS EXISTS (regression-guard convention):
//  Tile icons are rendered TWICE — baked to `.icns` by `IconGenerator` (CoreGraphics) and
//  live by `DockTileIconPreview` (SwiftUI) — and the two are kept in sync by hand. Every
//  visual constant that both need (glyph size ratio, glass stroke, surface sheen, glyph
//  contact shadow, glyph shading) lives here as a plain-value function so the two renderers
//  read the SAME numbers and cannot drift. It has no AppKit/SwiftUI dependency, so the
//  regression-prone decisions are unit-testable in isolation (mirrors `PopoverMetrics`,
//  `IconStyle.from`). See IconDepthMetricsTests.
//
//  Apple's Tahoe / Liquid Glass icons get specular highlights + depth from the system's
//  layered `.icon` pipeline. DockTile's tiles are generated at runtime (per tint × per
//  style), so they can't use that pipeline — instead we EMULATE the treatment by baking a
//  restrained sheen + contact shadow + glyph shading ourselves.
//
//  Swift 6 - Strict Concurrency
//

import CoreGraphics
import Foundation

enum IconDepthMetrics {

    // MARK: - Glyph size ratio (safe-area cap)

    /// Maximum safe ratio — matches the outer guide circle (~60% of icon bounds). SF Symbols
    /// are capped here so they never crowd the tile. The brand logo uses its own (higher)
    /// curve in `SFSymbolCatalog.brandRatio`, and emoji their own ceiling below.
    static let maxSafeRatio: CGFloat = 0.60

    /// Emoji ceiling — a "sticker" isn't bound by the SF-Symbol guide circle, so emoji may grow
    /// past 0.60, but not past the SHAPE.
    ///
    /// **The bound is the squircle's largest centred SQUARE, not its side (critical).** Emoji are
    /// ink-normalised (`emojiInkFit`), so the ratio bounds the artwork's bounding BOX — and a box
    /// only fits a squircle if it fits that inscribed square (~0.868 of the shape's side). With
    /// the icon-grid margin the shape is `1 - 2 × contentInsetRatio` = 0.805 of the canvas, so the
    /// real limit is ≈0.699 of the canvas; measured against the rendered shape it is **0.6875**
    /// (`IconPreviewGeometryTests.emojiCeilingFitsTheInscribedSquare`, which re-derives it from
    /// pixels rather than trusting this comment). This sits under that with margin.
    ///
    /// Comparing the ratio against the shape's side instead — treating the squircle as a square —
    /// is what let the old 0.78 ceiling ship: at scale 22 a full-cell emoji (🟥, 🧊) put tens of
    /// thousands of opaque pixels outside the tile at the 1024 bake.
    static let emojiMaxSafeRatio: CGFloat = 0.67

    /// Emoji ratio at the lowest Icon Scale (the 0.30 symbol base plus the +0.05 weight offset
    /// emoji have always carried). The low end is unchanged by the ceiling correction.
    static let emojiBaseRatio: CGFloat = 0.35

    /// Top Icon Scale step for emoji — the customiser's stepper bound, and the step the emoji
    /// curve is scaled to land on the ceiling. Symbols and the brand logo stop at 19.
    static let emojiScaleMax = 22

    /// Per-step growth for emoji, derived so the TOP step lands exactly on the ceiling. Emoji get
    /// their own slope rather than the symbols' 0.035: clamping the shared slope at a lower
    /// ceiling would flatten the top steps into each other, and every stepper step must stay
    /// visually distinct — so the whole curve is rescaled, shrinking most where it was unsafe.
    static var emojiRatioStep: CGFloat {
        (emojiMaxSafeRatio - emojiBaseRatio) / CGFloat(emojiScaleMax - 10)
    }

    /// The type's own ceiling: SF Symbols 0.60, emoji 0.67 (brand is handled upstream).
    static func maxSafeRatio(for iconType: IconType) -> CGFloat {
        iconType == .emoji ? emojiMaxSafeRatio : maxSafeRatio
    }

    /// Per-type warning threshold — 95% of the type's own ceiling, so the warning means
    /// "near YOUR limit" for emoji too instead of firing across their whole upper range.
    static func warningThreshold(for iconType: IconType) -> CGFloat {
        maxSafeRatio(for: iconType) * 0.95
    }

    /// Fraction of the tile the glyph should fill for a given Icon Scale (10–19 symbols,
    /// 10–22 emoji — the stepper's own ranges).
    /// Single source of truth for BOTH renderers — the preview previously duplicated this
    /// inline and dropped the `maxSafeRatio` cap, drawing symbols larger than the baked icon.
    static func glyphSizeRatio(iconScale: Int, iconType: IconType, iconValue: String) -> CGFloat {
        // Brand logo scales on its own curve with its own (higher) ceiling.
        if iconType == .sfSymbol && iconValue == SFSymbolCatalog.brandSymbolName {
            return SFSymbolCatalog.brandRatio(forScale: iconScale)
        }
        return cappedSymbolRatio(iconScale: iconScale, iconType: iconType)
    }

    /// The uncapped-then-capped ratio for SF Symbols / emojis (excludes the brand logo).
    private static func cappedSymbolRatio(iconScale: Int, iconType: IconType) -> CGFloat {
        if iconType == .emoji {
            // Emoji run on their own slope (see `emojiRatioStep`), from `emojiBaseRatio` at
            // scale 10 to the ceiling at `emojiScaleMax`. The `min` only guards a stored scale
            // above the stepper's range.
            let ratio = emojiBaseRatio + (CGFloat(iconScale - 10) * emojiRatioStep)
            return min(ratio, emojiMaxSafeRatio)
        }
        // Symbols: 0.035 per step above scale 10 (they step to 19), capped at the guide circle.
        return min(0.30 + (CGFloat(iconScale - 10) * 0.035), maxSafeRatio)
    }

    /// True when the (non-brand) glyph is at or past the type's safe-area warning threshold.
    static func isAtSafeAreaLimit(iconScale: Int, iconType: IconType) -> Bool {
        cappedSymbolRatio(iconScale: iconScale, iconType: iconType) >= warningThreshold(for: iconType)
    }

    // MARK: - Emoji ink fit (per-emoji artwork normalisation)

    /// How to draw an emoji so its MEASURED artwork ("ink"), not its font em box, fills the
    /// tile at the requested ratio. Apple Color Emoji reports identical glyph bounds for
    /// every emoji (the bitmap cell), while the actual art fills anywhere from ~65% (🧊) to
    /// ~100% (🟥) of that cell and can sit off-centre (🍕) — so sizing by font em made some
    /// emoji render visibly larger than others at the same Icon Size and let full-cell art
    /// crowd the safe area. Measurement lives in `IconGenerator.emojiInkMetrics(for:)`
    /// (pixel scan, cached); this seam is the pure arithmetic both renderers share.
    struct EmojiInkFit: Equatable {
        /// Font size that makes the artwork's larger dimension equal `tileSize × targetRatio`.
        var fontSize: CGFloat
        /// The artwork centre's offset from the typographic box centre, in points at
        /// `fontSize`, in the y-up measurement space. Renderers subtract this from the
        /// typographic-centred position (SwiftUI flips the y sign) to optically centre the art.
        var inkCenterOffset: CGPoint
    }

    /// Artwork is assumed to fill at least this fraction of the em box — a measured ink below
    /// it is clamped so a pathologically sparse glyph can't blow the font size up unboundedly.
    static let emojiMinInkFraction: CGFloat = 0.55

    /// `inkPerPoint` / `typographicSizePerPoint` are the measured metrics normalised to a
    /// 1pt font (see `IconGenerator.EmojiInkMetrics`).
    static func emojiInkFit(
        tileSize: CGFloat,
        targetRatio: CGFloat,
        inkPerPoint: CGRect,
        typographicSizePerPoint: CGSize
    ) -> EmojiInkFit {
        let maxInk = max(inkPerPoint.width, inkPerPoint.height, emojiMinInkFraction)
        let fontSize = tileSize * targetRatio / maxInk
        let offset = CGPoint(
            x: (inkPerPoint.midX - typographicSizePerPoint.width / 2) * fontSize,
            y: (inkPerPoint.midY - typographicSizePerPoint.height / 2) * fontSize
        )
        return EmojiInkFit(fontSize: fontSize, inkCenterOffset: offset)
    }

    // MARK: - Icon-grid content inset

    /// Apple's icon-grid proportion: the icon shape occupies 206 of a 256-unit canvas, leaving a
    /// transparent margin all round. This describes how the Dock composes a compiled icon among
    /// its NEIGHBOURS — an artifact fact, not a UI-slot fact. Its real consumers are the
    /// compiled `.icon`'s own geometry (the system applies it), `IconGenerator.generateFallbackIcns`
    /// and the legacy macOS 15 bake `IconGenerator.generateIcon` (both bake it explicitly; the
    /// legacy bake shipped full-bleed through 2.0.2, drawing ~24 % larger than every neighbouring
    /// Dock icon — `LegacyIcnsMarginTests`). UI slots — the live preview,
    /// sidebar rows, the tile editor canvas — deliberately do NOT apply it (decision 2026-09-02,
    /// Task 6 of docs/superpowers/plans/2026-09-02-appearance-environment.md): a UI slot has no
    /// neighbours to compose among, so the margin there just read as the icon shrinking. Shared
    /// here rather than owned by a renderer so the two real consumers can't drift apart.
    static let contentInsetRatio: CGFloat = 25.0 / 256.0   // (256 - 206) / 2 / 256

    // MARK: - Inner glass stroke

    /// White opacity of the inner glass stroke, subtler in Dark style.
    static func strokeOpacity(style: IconStyle) -> CGFloat {
        style == .dark ? 0.2 : 0.5
    }

    /// Inner glass stroke line width, scaled so it stays visible at every size
    /// (~0.5pt at 160pt, thicker for the large baked variants). Both renderers use this,
    /// removing the old fixed-`0.5` drift in the preview.
    static func strokeLineWidth(nominalSize: CGFloat) -> CGFloat {
        max(0.5, nominalSize * 0.003125)
    }

    // MARK: - Depth gate

    /// Depth detail (sheen, glyph shading, contact shadow) is suppressed below this size so
    /// the tiny 16px Dock renditions stay crisp instead of turning muddy. All the medium/
    /// large baked variants and every in-app preview clear this bar.
    static let minDetailSize: CGFloat = 22

    static func showsDepth(nominalSize: CGFloat) -> Bool { nominalSize >= minDetailSize }

    // MARK: - Surface sheen (top glass gloss on the tile)

    /// White alpha of the top specular sheen laid over the tile surface; 0 when suppressed.
    /// Restrained per style — the grayscale Clear/Tinted styles get less so the emulated
    /// gloss doesn't fight the system's own tinting.
    static func surfaceSheenAlpha(style: IconStyle, nominalSize: CGFloat) -> CGFloat {
        guard showsDepth(nominalSize: nominalSize) else { return 0 }
        switch style {
        case .defaultStyle: return 0.15
        case .dark:         return 0.10
        case .clear:        return 0.08
        case .tinted:       return 0.10
        }
    }

    /// Fraction of the tile height over which the sheen fades from full to clear.
    static let surfaceSheenHeightFraction: CGFloat = 0.5

    // MARK: - Glyph contact shadow (lift)

    struct GlyphShadow: Equatable {
        /// Alpha of the black shadow.
        var blackAlpha: CGFloat
        /// Downward offset magnitude in points (each renderer applies the sign for "down"
        /// in its own coordinate space).
        var offset: CGFloat
        /// Blur radius in points.
        var blur: CGFloat
    }

    /// Soft contact shadow beneath the glyph so it reads as raised off the glass.
    /// `nil` when the icon is too small to carry it. Emoji get a lighter shadow (they already
    /// carry their own colour and detail) but — unlike before — in EVERY style, not just Dark.
    static func glyphShadow(style: IconStyle, iconType: IconType, nominalSize: CGFloat) -> GlyphShadow? {
        guard showsDepth(nominalSize: nominalSize) else { return nil }

        let symbolAlpha: CGFloat
        switch style {
        case .defaultStyle: symbolAlpha = 0.18
        case .dark:         symbolAlpha = 0.35   // stronger: lift a white glyph off the dark tile
        case .clear:        symbolAlpha = 0.12
        case .tinted:       symbolAlpha = 0.15
        }

        let alpha = iconType == .emoji ? symbolAlpha * 0.7 : symbolAlpha
        let blur = nominalSize * (style == .dark ? 0.025 : 0.02)
        let offset = max(0.5, nominalSize * 0.012)
        return GlyphShadow(blackAlpha: alpha, offset: offset, blur: blur)
    }

    // MARK: - Glyph specular sheen (Liquid-Glass gloss on the symbol)

    struct GlyphSheen: Equatable {
        /// White alpha at the top of the glyph, fading to clear.
        var alpha: CGFloat
        /// Fraction of the glyph's height over which the sheen fades from full (top) to clear.
        var heightFraction: CGFloat
    }

    /// A specular highlight clipped to the TOP of the glyph shape — the Liquid-Glass "lit glass"
    /// cue, stacked *above* the shading fill + contact shadow. A white→transparent vertical
    /// gradient masked by the glyph, concentrated in the top `heightFraction`. `nil` only when the
    /// icon is too small to carry depth.
    ///
    /// Because the sheen is **additive white light, not a recolour**, it also works on emoji — a
    /// glossy-sticker highlight consistent with the "Sticker on Glass" metaphor — but much gentler
    /// (`emojiAlpha`) so it doesn't wash out the emoji's own colour and detail.
    ///
    /// The top-heavy falloff is deliberate: a uniform glow reads as plastic; the top-to-bottom
    /// asymmetry is what the eye reads as glass. Grayscale Clear/Tinted are dialled back so the
    /// gloss doesn't fight the system's own tinting (same rationale as `surfaceSheenAlpha`).
    static func glyphSheen(style: IconStyle, iconType: IconType, nominalSize: CGFloat) -> GlyphSheen? {
        guard showsDepth(nominalSize: nominalSize) else { return nil }
        let alpha: CGFloat
        if iconType == .emoji {
            alpha = emojiAlpha
        } else {
            switch style {
            case .defaultStyle: alpha = 0.55
            case .dark:         alpha = 0.55
            case .clear:        alpha = 0.30
            case .tinted:       alpha = 0.37
            }
        }
        return GlyphSheen(alpha: alpha, heightFraction: glyphSheenHeightFraction)
    }

    /// Emoji specular sheen alpha — a restrained glossy-sticker highlight (emoji keep their own
    /// colour, so the gloss must stay light or it flattens them).
    static let emojiAlpha: CGFloat = 0.18

    /// Height fraction shared by every style's glyph sheen (tuned in the live study).
    static let glyphSheenHeightFraction: CGFloat = 0.53

    // MARK: - Glyph shading (dimensional fill; symbols / brand only)

    /// How much the BOTTOM of the glyph is darkened toward black to fake a top-lit,
    /// slightly-extruded surface (the glyph is filled top→bottom with foreground →
    /// foreground-darkened-by-this). Returns `nil` for emoji (multicolour, never recoloured)
    /// and when depth is suppressed.
    static func glyphBottomDarken(style: IconStyle, iconType: IconType, nominalSize: CGFloat) -> CGFloat? {
        guard iconType != .emoji, showsDepth(nominalSize: nominalSize) else { return nil }
        switch style {
        case .defaultStyle: return 0.12
        case .dark:         return 0.10
        case .clear:        return 0.08
        case .tinted:       return 0.10
        }
    }
}

// MARK: - Apps face grid

/// Geometry, material and item selection for the Apps tile face: a tile showing its own apps as
/// a folder-style mini grid, like an iOS 26 folder / App Library cluster.
///
/// WHY ONE SEAM: four renderers (the baked fallback `.icns`, the declarative glyph layers, the
/// live preview and the legacy bake) draw this face, so every number they share lives here and
/// they cannot drift. Block 0.80 and gap 0.035 (was 0.70 / 0.047, from the iOS 26 screenshot):
/// widened 2026-10-19 because the 3×3 minis read small and crowded to the centre in the Dock.
/// One to four items draw in a 2x2 grid (one item sits in the top-left cell, like an iOS folder —
/// owner, 2026-10-22; it was one centred 0.60 icon until then), five or more in a 3x3. `TilePalette`
/// is deliberately not involved: the face's plate is the system grays or the tile's own App Grid
/// background (`fillColors`), never the Symbol/Emoji tint. Only Foundation/CoreGraphics, so it is unit-testable.
enum AppsFaceGrid {
    /// Side of the mini-icon block, as a fraction of the shape.
    static let blockRatio: CGFloat = 0.80
    /// Gap between adjacent minis, as a fraction of the shape.
    static let gapRatio: CGFloat = 0.035
    static let maxItems = 9
    /// Fraction of an app icon's canvas that its visible shape occupies (the icon-grid margin).
    static let appIconContentRatio: CGFloat = 1 - 2 * IconDepthMetrics.contentInsetRatio
    /// Two grids only: 2x2 for up to four items (one item included), 3x3 from five.
    static func columns(count: Int) -> Int {
        count <= 4 ? 2 : 3
    }

    static func cellRatio(columns: Int) -> CGFloat {
        (blockRatio - CGFloat(columns - 1) * gapRatio) / CGFloat(columns)
    }

    /// Cell rects in the unit space of the SHAPE: origin top-left, y-down.
    static func cells(count: Int) -> [CGRect] {
        let n = min(max(count, 0), maxItems)
        guard n > 0 else { return [] }
        let cols = columns(count: n)
        let cell = cellRatio(columns: cols)
        let origin = (1 - blockRatio) / 2
        return (0..<n).map { i in
            CGRect(x: origin + CGFloat(i % cols) * (cell + gapRatio),
                   y: origin + CGFloat(i / cols) * (cell + gapRatio),
                   width: cell, height: cell)
        }
    }

    /// Where to draw an item's icon so its VISIBLE shape fills the cell: an app icon carries the
    /// icon-grid margin, so its canvas is the cell scaled up about its centre; a folder is the cell.
    static func drawBox(for cell: CGRect, isFolder: Bool) -> CGRect {
        guard !isFolder else { return cell }
        let side = cell.width / appIconContentRatio
        let h = cell.height / appIconContentRatio
        return CGRect(x: cell.midX - side / 2, y: cell.midY - h / 2, width: side, height: h)
    }

    /// Maps a unit rect onto `shape`. `yUp` flips vertically for AppKit's non-flipped bitmaps.
    static func rect(_ unit: CGRect, in shape: CGRect, yUp: Bool) -> CGRect {
        let w = unit.width * shape.width
        let h = unit.height * shape.height
        let x = shape.minX + unit.minX * shape.width
        let y = yUp
            ? shape.maxY - (unit.minY + unit.height) * shape.height
            : shape.minY + unit.minY * shape.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Contact shadow under each mini; `nil` below the detail gate.
    static func miniShadow(nominalSize: CGFloat) -> IconDepthMetrics.GlyphShadow? {
        guard IconDepthMetrics.showsDepth(nominalSize: nominalSize) else { return nil }
        return IconDepthMetrics.GlyphShadow(blackAlpha: 0.35,
                                            offset: nominalSize * 6 / 1024,
                                            blur: nominalSize * 12 / 1024)
    }

    // MARK: Material (system grays or the tile's App Grid background, top then bottom)

    static let lightGrays: (top: CGFloat, bottom: CGFloat) = (1.0, 0.925)
    static let darkGrays: (top: CGFloat, bottom: CGFloat) = (0.192, 0.078)

    static func fillGrays(style: IconStyle) -> (top: CGFloat, bottom: CGFloat) {
        style == .dark ? darkGrays : lightGrays
    }

    static func fillColors(background: AppsGridBackground, customHex: String, style: IconStyle)
        -> (top: SRGB, bottom: SRGB) {
        let grays: (top: CGFloat, bottom: CGFloat)
        switch background {
        case .custom:
            let color = SRGB(hex: customHex) ?? SRGB(hex: ConfigurationDefaults.appsBackgroundColor)!
            return (color, color)
        case .charcoal: grays = darkGrays
        case .light: grays = lightGrays
        case .automatic: grays = fillGrays(style: style)
        }
        return (SRGB(r: Double(grays.top), g: Double(grays.top), b: Double(grays.top)),
                SRGB(r: Double(grays.bottom), g: Double(grays.bottom), b: Double(grays.bottom)))
    }

    /// Dark when white reads better on the plate's top than black (equal contrast at relative
    /// luminance ~0.179).
    static func usesDarkPlate(background: AppsGridBackground, customHex: String, style: IconStyle) -> Bool {
        let top = fillColors(background: background, customHex: customHex, style: style).top
        return ToneMap.contrastRatio(top, SRGB(r: 1, g: 1, b: 1)) > ToneMap.contrastRatio(top, SRGB(r: 0, g: 0, b: 0))
    }

    /// The empty-slot tone baked into one compiled appearance layer. The tinted slot holds the
    /// Clear Dark renders and the system remaps its fill, so it is always dark glass — the tone
    /// it had before backgrounds existed. Follow System keeps that slot-by-slot bake exactly;
    /// a fixed plate looks the same in every slot, so its own colour decides.
    static func layerOnDarkGlass(slot: AppIconRenderStyle, background: AppsGridBackground, customHex: String) -> Bool {
        if slot == .clearDark { return true }
        if background == .automatic { return slot == .dark }
        return usesDarkPlate(background: background, customHex: customHex, style: .defaultStyle)
    }

    /// An App Grid with no (installed) apps shows the empty 2x2: four quiet slots in the 2x2 cells,
    /// the app-icon shape (continuous corners, 22.5% of the cell), a faint darker well on light glass
    /// and a faint lighter one on dark glass — no stroke, no shadow, no text (owner, 2026-10-22: an
    /// App Grid never shows the tile's symbol). They disappear once an app is added.
    static let emptySlotCount = 4
    static let slotCornerRatio: CGFloat = 0.225
    static func emptySlotFill(onDarkGlass: Bool) -> (white: CGFloat, alpha: CGFloat) {
        onDarkGlass ? (1, 0.10) : (0, 0.07)
    }

    /// Clear and Tinted are grayscale styles, so the minis lose their colour too.
    static func desaturatesMinis(style: IconStyle) -> Bool {
        style == .clear || style == .tinted
    }

    // MARK: Selection

    /// Installed items in tile order, at most `maxItems`; `skipped` counts missing items in the
    /// whole list so the next installed one takes a skipped item's cell.
    static func select(items: [AppItem], isInstalled: (AppItem) -> Bool) -> (selected: [AppItem], skipped: Int) {
        var selected: [AppItem] = []
        var skipped = 0
        for item in items {
            if isInstalled(item) {
                if selected.count < maxItems { selected.append(item) }
            } else {
                skipped += 1
            }
        }
        return (selected, skipped)
    }
}
