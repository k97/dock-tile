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
    private func render(iconType: IconType = .sfSymbol, iconValue: String = "star.fill") throws -> NSBitmapImageRep {
        let view = DockTileIconPreview(
            tintColor: .blue,
            iconType: iconType,
            iconValue: iconValue,
            iconScale: 14,
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
        for x in 0..<rep.pixelsWide {
            if try alpha(rep, x, row) > 0.5 { return x }
        }
        Issue.record("row \(row) is fully transparent")
        return -1
    }

    /// First y in the given column whose alpha clears the anti-aliasing floor.
    private func firstOpaqueRow(_ rep: NSBitmapImageRep, column: Int) throws -> Int {
        for y in 0..<rep.pixelsHigh {
            if try alpha(rep, column, y) > 0.5 { return y }
        }
        Issue.record("column \(column) is fully transparent")
        return -1
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
}
