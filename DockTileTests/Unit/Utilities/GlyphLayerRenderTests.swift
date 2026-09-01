//
//  GlyphLayerRenderTests.swift
//  DockTileTests
//
//  Render-level guard for the LEAN glyph layer the declarative (.icon → Assets.car) pipeline
//  feeds to macOS. Draws through the REAL production path (IconGenerator.generateGlyphLayerPNG
//  → drawSFSymbol / drawEmoji → IconDepthMetrics) and pixel-scans the PNG bytes.
//
//  WHY LEAN: a compiled icon gets the system's own Liquid Glass pass, and its background comes
//  from the .icon document's JSON fill — so a layer PNG must carry the glyph and nothing else.
//  KEEP (glyph-intrinsic): shading gradient + contact shadow. DROP (system supplies them):
//  squircle, gradient background, glass stroke, surface sheen, glyph specular sheen. Baking our
//  emulated effects under the system's real ones is the failure this design avoids — so the
//  transparent-corners test below is the "no baked squircle" guard.
//
//  Appearance is a LAYER SWAP, never a recolour at render time: .light → white glyph,
//  .dark → the tint lifted for visibility, .tinted → mono (the system tints what we supply).
//  Emoji are colour glyphs that cannot be recoloured, so ONE layer serves every appearance.
//
//  Swift 6 - Strict Concurrency
//

import Testing
import AppKit
@testable import Dock_Tile

@MainActor
@Suite("Lean glyph layer rendering")
struct GlyphLayerRenderTests {

    private static let canvas = 1024

    private func bitmap(_ data: Data) throws -> NSBitmapImageRep {
        try #require(NSBitmapImageRep(data: data))
    }

    @Test("Layer canvas is exactly 1024x1024 with transparent corners (no baked squircle)")
    func canvasIsTransparentOutsideGlyph() throws {
        let data = try IconGenerator.generateGlyphLayerPNG(
            appearance: .light, tintColor: .green, iconType: .sfSymbol,
            iconValue: "hammer.fill", iconScale: 14, iconWeight: .medium)
        let rep = try bitmap(data)
        #expect(rep.pixelsWide == Self.canvas)
        #expect(rep.pixelsHigh == Self.canvas)
        for (x, y) in [(2, 2), (1021, 2), (2, 1021), (1021, 1021)] {
            let alpha = try #require(rep.colorAt(x: x, y: y)?.alphaComponent)
            #expect(alpha == 0)
        }
    }

    @Test("Light layer glyph is white-family; dark layer carries the LIFTED tint")
    func appearanceDrivesGlyphColour() throws {
        // #5F00FF is the colour `liftedForDarkGlyph` exists for: maximum HSB brightness, perceived
        // luminance (0.23) far under the 0.55 floor, so it vanishes on the dark background unless
        // lifted. A saturated tint like .green would satisfy a "saturation > 0.3" check straight
        // from the raw tint, proving nothing about the lift.
        let violet = TintColor.custom("#5F00FF")
        func layer(_ appearance: IconAppearance) throws -> Data {
            try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance, tintColor: violet, iconType: .sfSymbol,
                iconValue: "square.fill", iconScale: 14, iconWeight: .medium)
        }
        func centreColour(_ data: Data) throws -> NSColor {
            let rep = try bitmap(data)
            return try #require(rep.colorAt(x: 512, y: 512)?.usingColorSpace(.sRGB))
        }

        let lightData = try layer(.light)
        let light = try centreColour(lightData)
        #expect(light.brightnessComponent > 0.85)
        #expect(light.saturationComponent < 0.15)

        // The shading gradient darkens the glyph toward its bottom, so the BRIGHTEST pixel down
        // the glyph's centre column is the undarkened foreground the lift produced — comparable
        // to the seam's own value, unlike the mid-gradient centre pixel.
        let darkRep = try bitmap(try layer(.dark))
        let glyphLuminances: [CGFloat] = (0..<Self.canvas)
            .compactMap { darkRep.colorAt(x: 512, y: $0)?.usingColorSpace(.sRGB) }
            .filter { $0.alphaComponent > 0.99 }
            .map(Self.perceivedLuminance)
        let rendered = try #require(glyphLuminances.max())
        let expected = Self.perceivedLuminance(
            violet.nsColors(for: .dark, iconType: .sfSymbol).foreground)
        let unlifted = Self.perceivedLuminance(try #require(NSColor(hex: "#5F00FF")))
        #expect(expected >= TintColor.darkGlyphLuminanceFloor - 0.001)  // the seam lifted at all
        // …and the pixels carry it. The shading gradient costs the composited glyph ~15% of its
        // luminance, so the rendered maximum sits just under the seam's value — and, crucially,
        // far above the ~0.23 an unlifted #5F00FF would leave (which is the regression).
        #expect(abs(rendered - expected) < 0.12)
        #expect(rendered > unlifted + 0.2)

        // Mono for the system tint pass — and byte-identical to the light layer, which is what
        // lets the .icon document reuse the light layer for tinted (no third PNG).
        let tintedData = try layer(.tinted)
        let tinted = try centreColour(tintedData)
        #expect(tinted.saturationComponent < 0.15)
        #expect(tintedData == lightData)
    }

    /// The same 0.299/0.587/0.114 weighting `liftedForDarkGlyph` lifts on — HSB brightness cannot
    /// see the `#5F00FF` case at all (it is already 1.0 there).
    private static func perceivedLuminance(_ color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
    }

    @Test("Glyph honours the seam ratio on the new canvas")
    func glyphSizeFollowsSeamRatio() throws {
        let rep = try bitmap(try IconGenerator.generateGlyphLayerPNG(
            appearance: .light, tintColor: .green, iconType: .sfSymbol,
            iconValue: "square.fill", iconScale: 14, iconWeight: .medium))
        // Scan the horizontal extent of non-transparent pixels on the centre row.
        var minX = Self.canvas, maxX = 0
        for x in 0..<Self.canvas where (rep.colorAt(x: x, y: 512)?.alphaComponent ?? 0) > 0.1 {
            minX = min(minX, x); maxX = max(maxX, x)
        }
        let measured = Double(maxX - minX + 1) / Double(Self.canvas)
        let expected = Double(IconDepthMetrics.glyphSizeRatio(
            iconScale: 14, iconType: .sfSymbol, iconValue: "square.fill"))
        #expect(abs(measured - expected) < 0.05)   // square.fill ≈ its bounding box
    }

    @Test("Emoji layer renders identically for every appearance (single-layer model)")
    func emojiIgnoresAppearance() throws {
        let a = try IconGenerator.generateGlyphLayerPNG(appearance: .light, tintColor: .green,
            iconType: .emoji, iconValue: "🔨", iconScale: 14, iconWeight: .medium)
        let b = try IconGenerator.generateGlyphLayerPNG(appearance: .dark, tintColor: .green,
            iconType: .emoji, iconValue: "🔨", iconScale: 14, iconWeight: .medium)
        let c = try IconGenerator.generateGlyphLayerPNG(appearance: .tinted, tintColor: .green,
            iconType: .emoji, iconValue: "🔨", iconScale: 14, iconWeight: .medium)
        #expect(a == b)
        #expect(a == c)
    }

    @Test("Fallback icns bakes the icon-grid margin (transparent mid-edge, opaque centre)")
    func fallbackIcnsIsMargined() throws {
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("docktile-fallback-\(UUID().uuidString).icns")
        defer { try? FileManager.default.removeItem(at: out) }

        try IconGenerator.generateFallbackIcns(
            tintColor: .green, iconType: .sfSymbol, iconValue: "square.fill",
            iconScale: 14, iconWeight: .medium, outputURL: out)

        let image = try #require(NSImage(contentsOf: out))
        let rep = try #require(
            image.representations.compactMap { $0 as? NSBitmapImageRep }
                .max(by: { $0.pixelsWide < $1.pixelsWide }))
        let width = rep.pixelsWide
        #expect(width == 1024)   // 512@2x, the largest rendition

        // Sampled at the MID-EDGE, not a corner: the corners of a full-bleed squircle are
        // transparent too, so a corner probe cannot tell "margined" from "edge-to-edge". The
        // vertical mid-edge is solid background on an unmargined icon and empty on this one.
        let midEdge = try #require(rep.colorAt(x: 1, y: width / 2)?.alphaComponent)
        #expect(midEdge == 0)

        // …and the tile itself is really drawn.
        let centre = try #require(rep.colorAt(x: width / 2, y: width / 2)?.alphaComponent)
        #expect(centre == 1)
    }

    /// The compiled icon draws the shape itself and composites this layer over it, so a glyph
    /// that outgrows the icon-grid shape spills past the tile in the Dock (or gets clipped by
    /// the system) — neither is what the customiser shows. The preview carries the same guard
    /// (`IconPreviewGeometryTests.glyphStaysInsideTheShapeAtMaxScale`); this one pins the pixels
    /// macOS actually receives, at the real 1024 canvas.
    @Test("Max-scale glyph layers stay inside the icon-grid shape", arguments: [
        (IconType.emoji, "🟥"), (IconType.emoji, "🧊"), (IconType.emoji, "🍕"),
        (IconType.sfSymbol, "square.fill"), (IconType.sfSymbol, SFSymbolCatalog.brandSymbolName)
    ])
    func maxScaleLayerStaysInsideTheShape(_ type: IconType, _ value: String) throws {
        let scale = type == .emoji ? IconDepthMetrics.emojiScaleMax : 19
        let rep = try bitmap(try IconGenerator.generateGlyphLayerPNG(
            appearance: .light, tintColor: .green, iconType: type,
            iconValue: value, iconScale: scale, iconWeight: .medium))
        let mask = try #require(IconPreviewGeometryTests.shapeMask(side: CGFloat(Self.canvas)))
        let escaped = IconPreviewGeometryTests.escapedPixels(rep, mask: mask)
        #expect(escaped == 0, "\(value) at scale \(scale): \(escaped) layer pixels outside the shape")
    }

    @Test("Brand glyph routes like a symbol: tintable, appearance-swapped, seam-sized")
    func brandGlyphRoutesLikeASymbol() throws {
        let brand = SFSymbolCatalog.brandSymbolName
        func layer(_ appearance: IconAppearance) throws -> Data {
            try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance, tintColor: .green, iconType: .sfSymbol,
                iconValue: brand, iconScale: 14, iconWeight: .medium)
        }
        // Unlike emoji, the brand raster IS recoloured per appearance — so its layers differ.
        let lightData = try layer(.light)
        let darkData = try layer(.dark)
        #expect(lightData != darkData)
        let light = try bitmap(lightData)
        let dark = try bitmap(darkData)
        #expect(light.pixelsWide == Self.canvas)

        // The logo's own (higher) ratio curve, not the SF-Symbol cap.
        let expected = Double(IconDepthMetrics.glyphSizeRatio(
            iconScale: 14, iconType: .sfSymbol, iconValue: brand))
        #expect(expected == Double(SFSymbolCatalog.brandRatio(forScale: 14)))

        var minX = Self.canvas, maxX = 0
        for x in 0..<Self.canvas where (light.colorAt(x: x, y: 512)?.alphaComponent ?? 0) > 0.1 {
            minX = min(minX, x); maxX = max(maxX, x)
        }
        let measured = Double(maxX - minX + 1) / Double(Self.canvas)
        #expect(abs(measured - expected) < 0.05)

        // Corners transparent in both appearances (no baked plate behind the logo).
        for r in [light, dark] {
            let alpha = try #require(r.colorAt(x: 2, y: 1021)?.alphaComponent)
            #expect(alpha == 0)
        }
    }
}
