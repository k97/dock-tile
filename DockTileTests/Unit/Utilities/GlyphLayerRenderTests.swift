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

    @Test("Light layer glyph is white-family; dark layer carries the lifted tint")
    func appearanceDrivesGlyphColour() throws {
        func layer(_ appearance: IconAppearance) throws -> Data {
            try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance, tintColor: .green, iconType: .sfSymbol,
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

        let dark = try centreColour(try layer(.dark))
        #expect(dark.saturationComponent > 0.3)   // tinted glyph, not white

        // Mono for the system tint pass — and byte-identical to the light layer, which is what
        // lets the .icon document reuse the light layer for tinted (no third PNG).
        let tintedData = try layer(.tinted)
        let tinted = try centreColour(tintedData)
        #expect(tinted.saturationComponent < 0.15)
        #expect(tintedData == lightData)
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

    @Test("Brand glyph routes like a symbol: tintable, appearance-swapped, seam-sized")
    func brandGlyphRoutesLikeASymbol() throws {
        let brand = SFSymbolCatalog.brandSymbolName
        func rep(_ appearance: IconAppearance) throws -> NSBitmapImageRep {
            try bitmap(try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance, tintColor: .green, iconType: .sfSymbol,
                iconValue: brand, iconScale: 14, iconWeight: .medium))
        }
        // Unlike emoji, the brand raster IS recoloured per appearance — so its layers differ.
        let light = try rep(.light)
        let dark = try rep(.dark)
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
