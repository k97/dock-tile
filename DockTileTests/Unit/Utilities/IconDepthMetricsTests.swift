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

    @Test("Emoji gets a +0.05 weight offset, capped at the emoji ceiling")
    func emojiRatioOffsetAndCap() {
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 14, iconType: .emoji, iconValue: "🚀"), 0.49)
        // scale 23 → 0.755 + 0.05 = 0.805 uncapped → capped at the emoji ceiling (0.78)
        #expect(IconDepthMetrics.glyphSizeRatio(iconScale: 23, iconType: .emoji, iconValue: "🚀") == IconDepthMetrics.emojiMaxSafeRatio)
    }

    @Test("Emoji stepper range 17–22 stays distinct under the emoji ceiling (no dead steps)")
    func emojiTopStepsDistinct() {
        // The 0.60 SF cap used to flatten everything past 17 to 0.60; the 0.78 emoji ceiling
        // keeps every stepper step meaningful up to the top step at 22.
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 17, iconType: .emoji, iconValue: "🚀"), 0.595)
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 18, iconType: .emoji, iconValue: "🚀"), 0.63)
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 19, iconType: .emoji, iconValue: "🚀"), 0.665)
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 20, iconType: .emoji, iconValue: "🚀"), 0.70)
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 21, iconType: .emoji, iconValue: "🚀"), 0.735)
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 22, iconType: .emoji, iconValue: "🚀"), 0.77)
        // Symbols are untouched by the emoji ceiling: scale 19 still clamps to 0.60.
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
        #expect(IconDepthMetrics.emojiMaxSafeRatio == 0.78)
    }

    @Test("Emoji safe-area warning keys off the emoji ceiling — only the top step fires")
    func emojiSafeAreaLimitUsesOwnThreshold() {
        // Emoji threshold = 0.78 × 0.95 = 0.741: scale 22 (0.77) warns, 21 (0.735) and
        // below don't. (Under the old shared 0.57 threshold the warning fired from 17 up —
        // constant noise across the opened-up emoji range.)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 19, iconType: .emoji) == false)
        #expect(IconDepthMetrics.isAtSafeAreaLimit(iconScale: 21, iconType: .emoji) == false)
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
