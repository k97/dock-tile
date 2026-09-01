//
//  IconDepthMetricsTests.swift
//  DockTileTests
//
//  Regression guards for the pure icon-depth seam shared by the baked .icns renderer
//  (IconGenerator) and the live preview (DockTileIconPreview). Asserts exact magnitudes so a
//  broken visual rule fails loudly instead of silently drifting the two renderers apart.
//

import Testing
import CoreGraphics
@testable import Dock_Tile

struct IconDepthMetricsTests {

    /// Ratio magnitudes are derived (0.30 + n·0.035), so compare within a tight tolerance —
    /// compile-time constant folding of the literal form rounds differently from the runtime
    /// computation. Still an exact-magnitude assertion, just float-safe.
    private func expectClose(_ a: CGFloat, _ b: CGFloat, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(a - b) < 1e-9, "expected \(b), got \(a)", sourceLocation: sourceLocation)
    }

    // MARK: - Glyph size ratio (single source; the drift this seam was created to kill)

    @Test("SF Symbol ratio scales with iconScale and is capped at the safe area")
    func symbolRatioScalesAndCaps() {
        // base = 0.30 + (scale-10)*0.035
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 10, iconType: .sfSymbol, iconValue: "star.fill"), 0.30)
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 14, iconType: .sfSymbol, iconValue: "star.fill"), 0.44)
        // scale 20 → 0.65 uncapped, capped to 0.60
        #expect(IconDepthMetrics.glyphSizeRatio(iconScale: 20, iconType: .sfSymbol, iconValue: "star.fill") == IconDepthMetrics.maxSafeRatio)
    }

    @Test("Emoji start at the same base and reach the ceiling exactly at the top step")
    func emojiRatioBaseAndCeiling() {
        // Base (scale 10) is the symbols' 0.30 + the emoji weight offset — unchanged.
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 10, iconType: .emoji, iconValue: "🚀"), 0.35)
        // The top step lands ON the ceiling by construction, not by clamping.
        expectClose(
            IconDepthMetrics.glyphSizeRatio(iconScale: IconDepthMetrics.emojiScaleMax, iconType: .emoji, iconValue: "🚀"),
            IconDepthMetrics.emojiMaxSafeRatio)
        // A stored scale past the stepper's range still can't exceed the ceiling.
        #expect(IconDepthMetrics.glyphSizeRatio(iconScale: 23, iconType: .emoji, iconValue: "🚀") == IconDepthMetrics.emojiMaxSafeRatio)
    }

    @Test("Emoji stepper range 17–22 stays distinct under the emoji ceiling (no dead steps)")
    func emojiTopStepsDistinct() {
        // UPDATED (deliberately) when the emoji ceiling was corrected from 0.78 to 0.67: the old
        // ceiling was measured against the shape's SIDE, but the shape is a squircle, so an
        // emoji's bounding box must fit its inscribed square (~0.6875 of the canvas). The curve
        // was rescaled rather than clamped precisely so these steps stay distinct — they are
        // 0.02667 apart now instead of 0.035, and none of them repeats.
        let step = IconDepthMetrics.emojiRatioStep
        expectClose(step, (0.67 - 0.35) / 12)
        for scale in 17...IconDepthMetrics.emojiScaleMax {
            expectClose(
                IconDepthMetrics.glyphSizeRatio(iconScale: scale, iconType: .emoji, iconValue: "🚀"),
                0.35 + CGFloat(scale - 10) * step)
        }
        // Distinctness is the property that matters: consecutive steps differ by a full step.
        for scale in 10..<IconDepthMetrics.emojiScaleMax {
            let lower = IconDepthMetrics.glyphSizeRatio(iconScale: scale, iconType: .emoji, iconValue: "🚀")
            let upper = IconDepthMetrics.glyphSizeRatio(iconScale: scale + 1, iconType: .emoji, iconValue: "🚀")
            expectClose(upper - lower, step)
        }
        // Symbols are untouched by the emoji curve: scale 19 still clamps to 0.60.
        #expect(IconDepthMetrics.glyphSizeRatio(iconScale: 19, iconType: .sfSymbol, iconValue: "star.fill") == IconDepthMetrics.maxSafeRatio)
    }

    @Test("Brand logo uses its own curve/ceiling, not the SF-Symbol cap")
    func brandRatioUsesOwnCurve() {
        let brand = SFSymbolCatalog.brandSymbolName
        #expect(IconDepthMetrics.glyphSizeRatio(iconScale: 14, iconType: .sfSymbol, iconValue: brand) == SFSymbolCatalog.brandRatio(forScale: 14))
        // At high scale the brand exceeds the 0.60 SF cap (it has its own 0.78 ceiling).
        let brandHigh = IconDepthMetrics.glyphSizeRatio(iconScale: 20, iconType: .sfSymbol, iconValue: brand)
        #expect(brandHigh > IconDepthMetrics.maxSafeRatio)
        #expect(brandHigh == SFSymbolCatalog.brandRatio(forScale: 20))
    }

    @Test("Safe-area limit flags high scales, not low ones")
    func safeAreaLimit() {
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 10, iconType: .sfSymbol) == false)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 20, iconType: .sfSymbol) == true)
        // maxSafeRatio / warningThreshold are the documented magnitudes.
        #expect(IconDepthMetrics.maxSafeRatio == 0.60)
        #expect(IconDepthMetrics.warningThreshold == 0.57)
        // 0.78 until the squircle-inscribed-square correction; the geometry is re-derived from
        // rendered pixels in IconPreviewGeometryTests.emojiCeilingFitsTheInscribedSquare.
        #expect(IconDepthMetrics.emojiMaxSafeRatio == 0.67)
    }

    @Test("Emoji safe-area warning keys off the emoji ceiling — only the top steps fire")
    func emojiSafeAreaLimitUsesOwnThreshold() {
        // Emoji threshold = 0.67 × 0.95 = 0.6365: scale 22 (0.67) and 21 (0.6433) warn, 20
        // (0.6167) and below don't. UPDATED with the ceiling correction — 21 now warns where it
        // used to sit clear of the old (too generous) 0.741 threshold, which is the honest
        // reading of "within 5% of your limit" against the true geometric limit.
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 19, iconType: .emoji) == false)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 20, iconType: .emoji) == false)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 21, iconType: .emoji) == true)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 22, iconType: .emoji) == true)
        // Symbols keep the original 0.57 threshold: 18 (0.58) warns, 17 (0.545) doesn't.
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 17, iconType: .sfSymbol) == false)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 18, iconType: .sfSymbol) == true)
    }

    // MARK: - Emoji ink fit (artwork normalisation)

    @Test("Full-em ink draws at exactly the target size with no offset")
    func inkFitFullCell() {
        let fit = IconDepthMetrics.emojiInkFit(
            tileSize: 256, targetRatio: 0.77,
            inkPerPoint: CGRect(x: 0, y: 0, width: 1, height: 1),
            typographicSizePerPoint: CGSize(width: 1, height: 1)
        )
        expectClose(fit.fontSize, 256 * 0.77)
        expectClose(fit.inkCenterOffset.x, 0)
        expectClose(fit.inkCenterOffset.y, 0)
    }

    @Test("Sparse ink scales the font up so the artwork hits the target")
    func inkFitSparse() {
        // Ink fills 0.7 of the em, centred → font grows by 1/0.7, no recentring needed.
        let fit = IconDepthMetrics.emojiInkFit(
            tileSize: 256, targetRatio: 0.77,
            inkPerPoint: CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7),
            typographicSizePerPoint: CGSize(width: 1, height: 1)
        )
        expectClose(fit.fontSize, 256 * 0.77 / 0.7)
        expectClose(fit.inkCenterOffset.x, 0)
        expectClose(fit.inkCenterOffset.y, 0)
    }

    @Test("Off-centre ink produces the recentring offset")
    func inkFitOffCentre() {
        // Ink hugs the left/bottom of the em (like 🍕's left-heavy artwork).
        let fit = IconDepthMetrics.emojiInkFit(
            tileSize: 256, targetRatio: 0.5,
            inkPerPoint: CGRect(x: 0, y: 0, width: 0.8, height: 0.8),
            typographicSizePerPoint: CGSize(width: 1, height: 1)
        )
        expectClose(fit.fontSize, 256 * 0.5 / 0.8)
        // Ink centre (0.4, 0.4) vs typo centre (0.5, 0.5) → −0.1 × fontSize on each axis.
        expectClose(fit.inkCenterOffset.x, -0.1 * fit.fontSize)
        expectClose(fit.inkCenterOffset.y, -0.1 * fit.fontSize)
    }

    @Test("Pathologically sparse ink is clamped so the font can't blow up unboundedly")
    func inkFitClampsTinyInk() {
        let fit = IconDepthMetrics.emojiInkFit(
            tileSize: 256, targetRatio: 0.77,
            inkPerPoint: CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.1),
            typographicSizePerPoint: CGSize(width: 1, height: 1)
        )
        // maxInk clamps to emojiMinInkFraction (0.55), not the measured 0.1.
        expectClose(fit.fontSize, 256 * 0.77 / IconDepthMetrics.emojiMinInkFraction)
    }

    // MARK: - Inner glass stroke

    @Test("Stroke opacity is subtler in Dark style")
    func strokeOpacity() {
        #expect(IconDepthMetrics.strokeOpacity(style: .dark) == 0.2)
        #expect(IconDepthMetrics.strokeOpacity(style: .defaultStyle) == 0.5)
        #expect(IconDepthMetrics.strokeOpacity(style: .clear) == 0.5)
        #expect(IconDepthMetrics.strokeOpacity(style: .tinted) == 0.5)
    }

    @Test("Stroke line width scales with size but never below 0.5pt")
    func strokeLineWidth() {
        #expect(IconDepthMetrics.strokeLineWidth(nominalSize: 24) == 0.5)   // 0.075 → floored to 0.5
        #expect(IconDepthMetrics.strokeLineWidth(nominalSize: 160) == 0.5)  // exactly 0.5
        #expect(IconDepthMetrics.strokeLineWidth(nominalSize: 512) == 512 * 0.003125)
    }

    // MARK: - Depth gate

    @Test("Depth detail is suppressed below the tiny-icon threshold")
    func depthGate() {
        #expect(IconDepthMetrics.showsDepth(nominalSize: 16) == false)
        #expect(IconDepthMetrics.showsDepth(nominalSize: 21) == false)
        #expect(IconDepthMetrics.showsDepth(nominalSize: 22) == true)
        #expect(IconDepthMetrics.showsDepth(nominalSize: 128) == true)
    }

    // MARK: - Surface sheen

    @Test("Surface sheen alpha is per-style and suppressed at tiny sizes")
    func surfaceSheen() {
        #expect(IconDepthMetrics.surfaceSheenAlpha(style: .defaultStyle, nominalSize: 80) == 0.15)
        #expect(IconDepthMetrics.surfaceSheenAlpha(style: .dark, nominalSize: 80) == 0.10)
        #expect(IconDepthMetrics.surfaceSheenAlpha(style: .clear, nominalSize: 80) == 0.08)
        #expect(IconDepthMetrics.surfaceSheenAlpha(style: .tinted, nominalSize: 80) == 0.10)
        // Suppressed below the gate.
        #expect(IconDepthMetrics.surfaceSheenAlpha(style: .defaultStyle, nominalSize: 16) == 0)
    }

    // MARK: - Glyph contact shadow

    @Test("Glyph shadow is nil below the gate")
    func glyphShadowGate() {
        #expect(IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 16) == nil)
    }

    @Test("Glyph shadow alpha is per-style; Dark is strongest to lift a white glyph")
    func glyphShadowAlpha() throws {
        let def = try #require(IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 80))
        let dark = try #require(IconDepthMetrics.glyphShadow(style: .dark, iconType: .sfSymbol, nominalSize: 80))
        let clear = try #require(IconDepthMetrics.glyphShadow(style: .clear, iconType: .sfSymbol, nominalSize: 80))
        let tinted = try #require(IconDepthMetrics.glyphShadow(style: .tinted, iconType: .sfSymbol, nominalSize: 80))
        #expect(def.blackAlpha == 0.18)
        #expect(dark.blackAlpha == 0.35)
        #expect(clear.blackAlpha == 0.12)
        #expect(tinted.blackAlpha == 0.15)
    }

    @Test("Emoji shadow is lighter than a symbol's but present in every style")
    func emojiShadowLighterButPresent() throws {
        let symbol = try #require(IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 80))
        let emoji = try #require(IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .emoji, nominalSize: 80))
        #expect(emoji.blackAlpha == symbol.blackAlpha * 0.7)
        // Present even in the light Default style (previously emoji only cast a shadow in Dark).
        #expect(IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .emoji, nominalSize: 80) != nil)
    }

    @Test("Glyph shadow blur/offset scale with size; Dark blurs more")
    func glyphShadowGeometry() throws {
        let def = try #require(IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 80))
        let dark = try #require(IconDepthMetrics.glyphShadow(style: .dark, iconType: .sfSymbol, nominalSize: 80))
        #expect(def.blur == 80 * 0.02)
        #expect(dark.blur == 80 * 0.025)
        #expect(def.offset == max(0.5, 80 * 0.012))
    }

    // MARK: - Glyph shading

    @Test("Glyph bottom-darken is per-style for symbols, nil for emoji")
    func glyphBottomDarken() {
        #expect(IconDepthMetrics.glyphBottomDarken(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 80) == 0.12)
        #expect(IconDepthMetrics.glyphBottomDarken(style: .dark, iconType: .sfSymbol, nominalSize: 80) == 0.10)
        #expect(IconDepthMetrics.glyphBottomDarken(style: .clear, iconType: .sfSymbol, nominalSize: 80) == 0.08)
        #expect(IconDepthMetrics.glyphBottomDarken(style: .tinted, iconType: .sfSymbol, nominalSize: 80) == 0.10)
        // Emoji are multicolour — never recoloured.
        #expect(IconDepthMetrics.glyphBottomDarken(style: .defaultStyle, iconType: .emoji, nominalSize: 80) == nil)
        // Suppressed below the gate.
        #expect(IconDepthMetrics.glyphBottomDarken(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 16) == nil)
    }

    // MARK: - Glyph specular sheen

    @Test("Glyph sheen is per-style for symbols; grayscale styles dialled back")
    func glyphSheenPerStyle() throws {
        let def = try #require(IconDepthMetrics.glyphSheen(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 80))
        let dark = try #require(IconDepthMetrics.glyphSheen(style: .dark, iconType: .sfSymbol, nominalSize: 80))
        let clear = try #require(IconDepthMetrics.glyphSheen(style: .clear, iconType: .sfSymbol, nominalSize: 80))
        let tinted = try #require(IconDepthMetrics.glyphSheen(style: .tinted, iconType: .sfSymbol, nominalSize: 80))
        #expect(def.alpha == 0.55)
        #expect(dark.alpha == 0.55)
        #expect(clear.alpha == 0.30)
        #expect(tinted.alpha == 0.37)
        // Grayscale styles are gentler so the gloss doesn't fight the system tint.
        #expect(clear.alpha < def.alpha)
        #expect(tinted.alpha < def.alpha)
        // Height fraction is shared across styles.
        #expect(def.heightFraction == 0.53)
        #expect(dark.heightFraction == 0.53)
    }

    @Test("Emoji get a gentle glossy-sticker sheen, much lighter than a symbol's")
    func emojiSheenGentle() throws {
        let emoji = try #require(IconDepthMetrics.glyphSheen(style: .defaultStyle, iconType: .emoji, nominalSize: 80))
        let symbol = try #require(IconDepthMetrics.glyphSheen(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 80))
        #expect(emoji.alpha == 0.18)
        #expect(emoji.alpha < symbol.alpha)
        // Emoji sheen is style-independent (emoji keep full colour in every style).
        #expect(IconDepthMetrics.glyphSheen(style: .dark, iconType: .emoji, nominalSize: 80)?.alpha == 0.18)
        #expect(IconDepthMetrics.glyphSheen(style: .clear, iconType: .emoji, nominalSize: 80)?.alpha == 0.18)
        #expect(emoji.heightFraction == 0.53)
    }

    // MARK: - Icon-grid content inset (declarative geometry)

    @Test("Content inset is Apple's icon-grid margin: 206 of a 256 canvas")
    func contentInsetMatchesIconGrid() {
        // (256 - 206) / 2 / 256 — the transparent margin on each side.
        expectClose(IconDepthMetrics.contentInsetRatio, 25.0 / 256.0)
        // The squircle therefore spans 206/256 of the canvas.
        expectClose(1 - 2 * IconDepthMetrics.contentInsetRatio, 206.0 / 256.0)
        // Concretely at the 1024 bake: a 100px margin, an 824px shape.
        expectClose(1024 * IconDepthMetrics.contentInsetRatio, 100)
    }

    @Test("Glyph sheen is suppressed below the size gate (symbol and emoji)")
    func glyphSheenSizeGate() {
        #expect(IconDepthMetrics.glyphSheen(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 16) == nil)
        #expect(IconDepthMetrics.glyphSheen(style: .dark, iconType: .sfSymbol, nominalSize: 21) == nil)
        #expect(IconDepthMetrics.glyphSheen(style: .dark, iconType: .sfSymbol, nominalSize: 22) != nil)
        // Emoji follow the same gate.
        #expect(IconDepthMetrics.glyphSheen(style: .defaultStyle, iconType: .emoji, nominalSize: 16) == nil)
        #expect(IconDepthMetrics.glyphSheen(style: .defaultStyle, iconType: .emoji, nominalSize: 22) != nil)
    }
}
