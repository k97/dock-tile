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
import SwiftUI
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

// MARK: - Inner glass stroke geometry (LEGACY bake only)

/// The glass stroke must be an INNER stroke — the same thing SwiftUI's `strokeBorder` draws in
/// the live preview. A centre stroke on the squircle path with no clip paints half its width
/// OUTSIDE the shape: at the 1024px bake that is a ~1.6px half-opacity white halo tracing the
/// tile's corners, and only half the line lands inside, so the visible width is half the
/// preview's. The halo is visible at the CORNERS (along the straight edges the outer half falls
/// off the canvas), so that is where this scans.
///
/// Scope: `generateIcon` / `generateIcns` only. The declarative pipeline's layer PNGs and its
/// fallback `.icns` are specified stroke-free (the system supplies the glass), so nothing here
/// touches them.
@MainActor
@Suite("Icon glass stroke geometry")
struct IconStrokeGeometryTests {

    /// 1024 is the size where the defect is measurable: `strokeLineWidth` = 3.2pt, so an
    /// unclipped centre stroke reaches 1.6px beyond the shape.
    private static let px = 1024

    private func rasterisedTile() throws -> NSBitmapImageRep {
        let image = IconGenerator.generateIcon(
            tintColor: .blue, iconType: .sfSymbol, iconValue: "star.fill",
            iconScale: 14, size: CGSize(width: Self.px, height: Self.px),
            iconStyle: .defaultStyle)
        return try #require(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
    }

    /// The exact squircle the generator fills (same construction as `createSquirclePath`).
    private func squircle() -> CGPath {
        let side = CGFloat(Self.px)
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        return RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
            .path(in: rect).cgPath
    }

    @Test("No paint escapes the squircle: the glass stroke is inner, not centred")
    func strokeStaysInsideTheShape() throws {
        let rep = try rasterisedTile()
        let path = squircle()
        let side = CGFloat(Self.px)
        let centre = CGPoint(x: side / 2, y: side / 2)
        // Corner boxes: the only region where "outside the squircle" is still on the canvas.
        let box = Int(side * 0.225) + 12
        var offenders: [(Int, Int, CGFloat)] = []

        for (originX, originY) in [(0, 0), (Self.px - box, 0), (0, Self.px - box), (Self.px - box, Self.px - box)] {
            for y in originY..<(originY + box) {
                for x in originX..<(originX + box) {
                    guard let colour = rep.colorAt(x: x, y: y), colour.alphaComponent >= 0.25 else { continue }
                    let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                    guard !path.contains(point) else { continue }
                    // Anti-aliasing of the fill itself can tint a pixel whose centre sits a
                    // fraction outside the edge; a full pixel-width beyond it cannot be AA.
                    let dx = centre.x - point.x, dy = centre.y - point.y
                    let length = max(1e-6, (dx * dx + dy * dy).squareRoot())
                    let inward = CGPoint(x: point.x + dx / length, y: point.y + dy / length)
                    if !path.contains(inward) {
                        offenders.append((x, y, colour.alphaComponent))
                    }
                }
            }
        }

        #expect(offenders.isEmpty, "\(offenders.count) painted pixels outside the squircle, e.g. \(offenders.prefix(4))")
    }

    @Test("The inner stroke spans the full line width inside the edge, not half of it")
    func innerStrokeSpansFullLineWidth() throws {
        let rep = try rasterisedTile()
        let mid = Self.px / 2
        // strokeLineWidth(1024) = 3.2pt. An inner stroke covers rows 0…3.2 below the top edge;
        // an unclipped CENTRE stroke covers only 0…1.6, leaving row 2 at plain background.
        #expect(IconDepthMetrics.strokeLineWidth(nominalSize: 1024) == 3.2)

        // Measure the WHITENESS of a row — the lowest channel. A white overlay lifts every
        // channel; HSB brightness would not show it at all, because the blue tile's own top
        // colour already saturates the blue channel at ~1.0.
        func whiteness(_ y: Int) throws -> CGFloat {
            let colour = try #require(rep.colorAt(x: mid, y: y)?.usingColorSpace(.sRGB))
            return min(colour.redComponent, min(colour.greenComponent, colour.blueComponent))
        }
        let body = try whiteness(40)          // well below the stroke: plain gradient
        let rimTop = try whiteness(0) - body  // inside the stroke either way
        let rimRow2 = try whiteness(2) - body // inside the stroke ONLY when it is inner

        // A 0.5-alpha white line lifts the low channels by ~0.4; a row the stroke never
        // reaches lifts by ~0.
        #expect(rimTop > 0.1, "no white rim at the top edge (\(rimTop)) — the glass stroke may have been lost")
        #expect(rimRow2 > 0.1, "row 2 unlit (\(rimRow2)) — stroke reaches only half the line width inside")
    }
}
