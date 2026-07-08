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

enum IconDepthMetrics {

    // MARK: - Glyph size ratio (safe-area cap)

    /// Maximum safe ratio — matches the outer guide circle (~60% of icon bounds). SF Symbols
    /// are capped here so they never crowd the tile. The brand logo uses its own (higher)
    /// curve in `SFSymbolCatalog.brandRatio`, and emoji their own ceiling below.
    static let maxSafeRatio: CGFloat = 0.60

    /// Emoji ceiling — a "sticker" isn't bound by the SF-Symbol guide circle, so emoji may
    /// grow past 0.60. Sits just above scale 22's uncapped 0.77 so every emoji stepper step
    /// 17–22 stays distinct (0.595 … 0.77) instead of clamping flat — the same own-ceiling
    /// pattern as the brand glyph's 0.78. Because emoji are ink-normalised (`emojiInkFit`),
    /// the ratio bounds the measured ARTWORK, keeping every emoji inside the squircle's
    /// ~0.86 centred-square limit with margin.
    static let emojiMaxSafeRatio: CGFloat = 0.78

    /// The type's own ceiling: SF Symbols 0.60, emoji 0.67 (brand is handled upstream).
    static func maxSafeRatio(for iconType: IconType) -> CGFloat {
        iconType == .emoji ? emojiMaxSafeRatio : maxSafeRatio
    }

    /// Threshold for the customiser's "near the edge" warning (95% of the safe area).
    static let warningThreshold: CGFloat = 0.57

    /// Per-type warning threshold — 95% of the type's own ceiling, so the warning means
    /// "near YOUR limit" for emoji too instead of firing across their whole upper range.
    static func warningThreshold(for iconType: IconType) -> CGFloat {
        maxSafeRatio(for: iconType) * 0.95
    }

    /// Fraction of the tile the glyph should fill for a given Icon Scale (10–19 symbols,
    /// 10–26 emoji).
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
        // Base ratio: 0.035 per step above scale 10 (symbols step to 19, emoji to 26).
        let base = 0.30 + (CGFloat(iconScale - 10) * 0.035)
        // Emoji gets +5% offset for visual weight.
        let ratio = iconType == .emoji ? base + 0.05 : base
        return min(ratio, maxSafeRatio(for: iconType))
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
