//
//  IconGeneratorContentTests.swift
//  DockTileTests
//
//  Guards icon *content*, not just size/validity. The prior tests asserted `image.isValid`,
//  which a fully blank (or all-black) image passes. These read the generated bitmap's pixels:
//  the squircle must actually cover the canvas, a bright glyph must be present (not blank), and
//  the chosen tint must dominate the background — so a regression dropping the fill/tint fails.
//

import Testing
import AppKit
@testable import Dock_Tile

@Suite("IconGenerator content")
@MainActor
struct IconGeneratorContentTests {

    private let px = 64

    private func icon(_ tint: TintColor, value: String = "star.fill", type: IconType = .sfSymbol) -> NSImage {
        // Pin the Default style: these tests assert a tint-dominant background + a bright (white)
        // glyph. Without pinning, `IconStyle.current` follows the host appearance, so on a Dark-mode
        // machine they'd render the Dark variant (neutral near-black bg, tinted glyph) and the
        // tint-dominance assertions would spuriously fail. Dark-style rendering is covered
        // separately by DarkGlyphTreatmentTests.
        IconGenerator.generateIcon(
            tintColor: tint, iconType: type, iconValue: value,
            iconScale: 14, size: CGSize(width: px, height: px),
            iconStyle: .defaultStyle)
    }

    /// The bitmap the generator already rendered into (avoids a lossy headless re-render).
    private func raster(_ image: NSImage) -> NSBitmapImageRep? {
        image.representations.compactMap { $0 as? NSBitmapImageRep }.first
    }

    /// Pixel metrics over the OPAQUE region: average channels, squircle coverage, and the single
    /// brightest channel value seen anywhere (the white glyph → ~1.0; a blank/black icon → ~0).
    private func metrics(_ image: NSImage) -> (r: Double, g: Double, b: Double, coverage: Double, peak: Double)? {
        guard let rep = raster(image) else { return nil }
        var rs = 0.0, gs = 0.0, bs = 0.0, count = 0, peak = 0.0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent >= 0.5 else { continue }
                let r = Double(c.redComponent), g = Double(c.greenComponent), b = Double(c.blueComponent)
                rs += r; gs += g; bs += b; count += 1
                peak = max(peak, max(r, max(g, b)))
            }
        }
        guard count > 0 else { return nil }
        let n = Double(count)
        return (rs / n, gs / n, bs / n, n / Double(rep.pixelsWide * rep.pixelsHigh), peak)
    }

    @Test("Generated icon is not blank: the squircle covers the canvas and a bright glyph is present")
    func iconIsNotBlank() throws {
        let m = try #require(metrics(icon(.red)))
        // The rounded-square fill should cover a large fraction of the canvas (not empty).
        #expect(m.coverage > 0.5, "coverage \(m.coverage) too low — fill may be missing")
        // A near-white glyph is drawn over the fill, so the brightest pixel is near 1.0.
        // An all-black / blank icon would peak near 0 and fail here.
        #expect(m.peak > 0.8, "peak brightness \(m.peak) too low — icon may be blank/black")
    }

    @Test("The chosen preset tint dominates the background", arguments: [
        (TintColor.red, "r"),
        (TintColor.blue, "b"),
        (TintColor.green, "g")
    ])
    func tintDominates(_ tint: TintColor, _ dominant: String) throws {
        let m = try #require(metrics(icon(tint)))
        // The white glyph lifts all channels equally, so the dominant channel comes from the
        // background tint. Assert the expected channel leads the other two.
        switch dominant {
        case "r": #expect(m.r > m.g && m.r > m.b, "red tile not red-dominant: \(m)")
        case "g": #expect(m.g > m.r && m.g > m.b, "green tile not green-dominant: \(m)")
        case "b": #expect(m.b > m.r && m.b > m.g, "blue tile not blue-dominant: \(m)")
        default: Issue.record("unexpected channel \(dominant)")
        }
    }

    @Test("Different tints produce visibly different icons")
    func differentTintsDiffer() throws {
        let red = try #require(metrics(icon(.red)))
        let blue = try #require(metrics(icon(.blue)))
        // Red has materially more red than blue does; blue has materially more blue than red.
        #expect(red.r - blue.r > 0.1, "red/blue red channels too close")
        #expect(blue.b - red.b > 0.1, "red/blue blue channels too close")
    }

    @Test("Custom hex tint is reflected in the rendered background")
    func customHexTintApplied() throws {
        // Dodger blue (#1E90FF) — the blue channel should clearly lead the others.
        let m = try #require(metrics(icon(.custom("#1E90FF"))))
        #expect(m.b > m.r && m.b > m.g, "custom blue not blue-dominant: \(m)")
    }
}
