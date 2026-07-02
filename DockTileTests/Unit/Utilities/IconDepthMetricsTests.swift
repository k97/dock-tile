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

    @Test("Emoji gets a +0.05 weight offset, still capped at the safe area")
    func emojiRatioOffsetAndCap() {
        expectClose(IconDepthMetrics.glyphSizeRatio(iconScale: 14, iconType: .emoji, iconValue: "🚀"), 0.49)
        // scale 20 → 0.65 + 0.05 = 0.70 uncapped → capped 0.60
        #expect(IconDepthMetrics.glyphSizeRatio(iconScale: 20, iconType: .emoji, iconValue: "🚀") == IconDepthMetrics.maxSafeRatio)
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
}
