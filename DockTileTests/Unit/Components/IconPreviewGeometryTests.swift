//
//  IconPreviewGeometryTests.swift
//  DockTileTests
//
//  The customiser's live preview must draw the SAME picture the Dock draws. Declarative tiles
//  render at Apple's icon-grid geometry — the shape occupies 206 of a 256-unit canvas, leaving a
//  transparent margin all round — so the preview carries that margin too, sourced from the shared
//  `IconDepthMetrics.contentInsetRatio` seam (never an inlined copy: an inlined geometry constant
//  is exactly the preview-vs-baked drift this seam exists to prevent).
//
//  Renders the REAL `DockTileIconPreview` through `ImageRenderer` and scans the resulting pixels,
//  so a preview that silently goes back to full-bleed fails here.
//
//  Swift 6 - Strict Concurrency
//

import Testing
import SwiftUI
import AppKit
@testable import Dock_Tile

@MainActor
@Suite("Icon preview geometry")
struct IconPreviewGeometryTests {

    private static let side: CGFloat = 256

    /// Render the preview at 1 pixel per point so pixel indices are point coordinates.
    private func render(
        iconType: IconType = .sfSymbol,
        iconValue: String = "star.fill",
        iconScale: Int = 14
    ) throws -> NSBitmapImageRep {
        let view = DockTileIconPreview(
            tintColor: .blue,
            iconType: iconType,
            iconValue: iconValue,
            iconScale: iconScale,
            iconWeight: .medium,
            size: Self.side
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let cgImage = try #require(renderer.cgImage)
        #expect(cgImage.width == Int(Self.side))
        #expect(cgImage.height == Int(Self.side))
        return NSBitmapImageRep(cgImage: cgImage)
    }

    private func alpha(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) throws -> CGFloat {
        try #require(rep.colorAt(x: x, y: y)?.alphaComponent)
    }

    /// First x on the given row whose alpha clears the anti-aliasing floor.
    private func firstOpaqueColumn(_ rep: NSBitmapImageRep, row: Int) throws -> Int {
        var found: Int?
        for x in 0..<rep.pixelsWide where found == nil {
            if try alpha(rep, x, row) > 0.5 { found = x }
        }
        return try #require(found, "row \(row) is fully transparent")
    }

    /// First y in the given column whose alpha clears the anti-aliasing floor.
    private func firstOpaqueRow(_ rep: NSBitmapImageRep, column: Int) throws -> Int {
        var found: Int?
        for y in 0..<rep.pixelsHigh where found == nil {
            if try alpha(rep, column, y) > 0.5 { found = y }
        }
        return try #require(found, "column \(column) is fully transparent")
    }

    // MARK: - The tile shape (as pixels, so containment is measured, not assumed)

    /// The squircle the preview actually draws: the canvas inset by the icon-grid margin, with
    /// the corner radius taken off the SHAPE — filled white into a bitmap so any render can be
    /// compared against it pixel by pixel.
    static func shapeMask(side: CGFloat) -> NSBitmapImageRep? {
        let px = Int(side)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        rep.size = CGSize(width: side, height: side)
        let inset = side * IconDepthMetrics.contentInsetRatio
        let shape = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: inset, dy: inset)
        let path = RoundedRectangle(cornerRadius: shape.width * 0.225, style: .continuous)
            .path(in: shape).cgPath
        ctx.cgContext.clear(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.cgContext.addPath(path)
        ctx.cgContext.setFillColor(NSColor.white.cgColor)
        ctx.cgContext.fillPath()
        return rep
    }

    /// Pixels painted where the tile shape isn't — i.e. artwork escaping the tile.
    ///
    /// `artworkAlpha` (0.25) is above the glyph's soft contact shadow (peak 0.18 for symbols,
    /// 0.126 for emoji) so a legitimate shadow feathering past the edge is not counted; a pixel
    /// counts as inside if the shape covers it at all, so the shape's own AA never counts either.
    static func escapedPixels(_ render: NSBitmapImageRep, mask: NSBitmapImageRep) -> Int {
        var escaped = 0
        for y in 0..<render.pixelsHigh {
            for x in 0..<render.pixelsWide {
                guard let pixel = render.colorAt(x: x, y: y), pixel.alphaComponent >= 0.25 else { continue }
                let covered = mask.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if covered <= 0.02 { escaped += 1 }
            }
        }
        return escaped
    }

    @Test("Preview leaves the icon-grid margin transparent on every edge")
    func marginIsTransparent() throws {
        let rep = try render()
        let inset = Int(Self.side * IconDepthMetrics.contentInsetRatio)  // 25 at 256
        let mid = Int(Self.side) / 2
        let last = Int(Self.side) - 1

        // Well inside the margin, on each edge midpoint: nothing may be painted.
        let leftMargin = try alpha(rep, 2, mid)
        let rightMargin = try alpha(rep, last - 2, mid)
        let topMargin = try alpha(rep, mid, 2)
        let bottomMargin = try alpha(rep, mid, last - 2)
        #expect(leftMargin == 0)
        #expect(rightMargin == 0)
        #expect(topMargin == 0)
        #expect(bottomMargin == 0)

        // Just inside the shape: fully painted.
        let insideLeft = try alpha(rep, inset + 3, mid)
        let insideTop = try alpha(rep, mid, inset + 3)
        #expect(insideLeft > 0.99)
        #expect(insideTop > 0.99)
    }

    @Test("Preview shape starts exactly at the seam's inset (206/256 content area)")
    func shapeStartsAtSeamInset() throws {
        let rep = try render()
        let expected = Self.side * IconDepthMetrics.contentInsetRatio  // 25 at 256
        let mid = Int(Self.side) / 2

        // Left edge and top edge of the squircle sit one inset in from the canvas (±1px for
        // anti-aliasing of the shape's edge).
        let left = CGFloat(try firstOpaqueColumn(rep, row: mid))
        let top = CGFloat(try firstOpaqueRow(rep, column: mid))
        #expect(abs(left - expected) <= 1, "left edge at \(left), expected \(expected)")
        #expect(abs(top - expected) <= 1, "top edge at \(top), expected \(expected)")
    }

    // MARK: - Glyph containment at MAXIMUM Icon Scale

    /// The guard that should have existed before the margin landed: the earlier tests scanned the
    /// SHAPE's edges but never the glyph, so a glyph sized against the canvas could overflow the
    /// (smaller) shape unnoticed. The stepper's top step is the only step that can fail, so that
    /// is what is pinned — for every icon type.
    ///
    /// Symbols and the brand logo stop at 19, emoji at 22 (`CustomiseTileView.maxIconScale`).
    /// The emoji cases are the measured worst cases: 🟥 fills its whole cell (square, corner to
    /// corner), 🧊 is the sparsest, 🍕 the most off-centre.
    @Test("Nothing escapes the tile at maximum Icon Scale", arguments: [
        (IconType.sfSymbol, "square.fill", 19),
        (IconType.sfSymbol, "star.fill", 19),
        (IconType.sfSymbol, SFSymbolCatalog.brandSymbolName, 19),
        (IconType.emoji, "🟥", IconDepthMetrics.emojiScaleMax),
        (IconType.emoji, "🧊", IconDepthMetrics.emojiScaleMax),
        (IconType.emoji, "🍕", IconDepthMetrics.emojiScaleMax)
    ])
    func glyphStaysInsideTheShapeAtMaxScale(_ type: IconType, _ value: String, _ scale: Int) throws {
        let rep = try render(iconType: type, iconValue: value, iconScale: scale)
        let mask = try #require(Self.shapeMask(side: Self.side))
        let escaped = Self.escapedPixels(rep, mask: mask)
        #expect(escaped == 0, "\(value) at scale \(scale): \(escaped) painted pixels outside the tile")
    }

    /// Why the emoji ceiling is what it is, measured rather than asserted: the shape is a
    /// squircle, so the artwork's bounding box must fit its largest CENTRED SQUARE, not its side.
    /// (Comparing the ratio against the shape's side — treating the squircle as a square — is the
    /// arithmetic that let max-scale emoji overflow.)
    @Test("The emoji ceiling fits inside the shape's largest centred square")
    func emojiCeilingFitsTheInscribedSquare() throws {
        let mask = try #require(Self.shapeMask(side: Self.side))
        let centre = Int(Self.side) / 2

        // The squircle is convex, so a centred square is inside exactly when its corners are.
        var halfSide = 0
        var inside = true
        while inside && halfSide < centre {
            let next = halfSide + 1
            for (dx, dy) in [(-next, -next), (next, -next), (-next, next), (next, next)] {
                let covered = mask.colorAt(x: centre + dx, y: centre + dy)?.alphaComponent ?? 0
                if covered <= 0.5 { inside = false }
            }
            if inside { halfSide = next }
        }
        let inscribedRatio = CGFloat(halfSide * 2) / Self.side

        #expect(IconDepthMetrics.emojiMaxSafeRatio <= inscribedRatio,
                "emoji ceiling \(IconDepthMetrics.emojiMaxSafeRatio) exceeds the measured inscribed square \(inscribedRatio)")
        // SF Symbols are bounded by the same square rule and clear it with room to spare.
        #expect(IconDepthMetrics.maxSafeRatio <= inscribedRatio)
        // The brand logo is deliberately NOT asserted here: it is a circular ring, and the
        // largest centred CIRCLE in a squircle is wider than the largest centred square, so the
        // square rule would reject a ratio (0.725 at its top step) that demonstrably fits. Its
        // containment is proven by pixels in `glyphStaysInsideTheShapeAtMaxScale` instead.
    }

    @Test("Emoji tiles get the same margined geometry as symbol tiles")
    func emojiTileIsMarginedToo() throws {
        let rep = try render(iconType: .emoji, iconValue: "🚀")
        let expected = Self.side * IconDepthMetrics.contentInsetRatio
        let mid = Int(Self.side) / 2
        let leftMargin = try alpha(rep, 2, mid)
        #expect(leftMargin == 0)
        let left = CGFloat(try firstOpaqueColumn(rep, row: mid))
        #expect(abs(left - expected) <= 1, "left edge at \(left), expected \(expected)")
    }

    // MARK: - Appearance via the environment (2026-09-02 regression guard)

    /// Renders the REAL preview with a given `colorScheme` injected through the environment and
    /// the raw style token pinned to Automatic via the test-only `rawStyleOverride` seam — this is
    /// the only way to force the discriminating case: under an EXPLICIT style (e.g. ClearDark) the
    /// two renders would legitimately match and prove nothing.
    private func renderPreview(scheme: ColorScheme) throws -> NSBitmapImageRep {
        var view = DockTileIconPreview(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            iconWeight: .medium,
            size: Self.side
        )
        view.rawStyleOverride = .value("RegularAutomatic")
        let hosted = view.environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 1
        let cgImage = try #require(renderer.cgImage)
        return NSBitmapImageRep(cgImage: cgImage)
    }

    @Test("Preview renders DIFFERENT output for light vs dark colorScheme under an Automatic raw style")
    func previewFollowsEnvironmentScheme() throws {
        // Under the frozen `currentStyle` implementation both renders were identical (the
        // environment was never consulted) — this is the regression Task 3 fixes.
        let light = try renderPreview(scheme: .light)
        let dark = try renderPreview(scheme: .dark)
        let lightData = try #require(light.representation(using: .png, properties: [:]))
        let darkData = try #require(dark.representation(using: .png, properties: [:]))
        #expect(lightData != darkData)
    }
}
