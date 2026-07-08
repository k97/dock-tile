//
//  EmojiInkFitRenderTests.swift
//  DockTileTests
//
//  Containment guard for emoji ink normalisation: draws emoji through the REAL production
//  path (IconGenerator.drawEmoji → emojiInkMetrics → IconDepthMetrics.emojiInkFit) onto a
//  transparent tile and pixel-scans the result.
//
//  THE REGRESSION THIS KILLS: emoji used to be sized by font em, but Apple Color Emoji
//  artwork fills anywhere from ~65% (🧊) to ~100% (🟥) of the em cell — so at the same Icon
//  Size some emoji rendered visibly larger and crowded the safe area while others looked
//  small, and off-centre artwork (🍕) sat askew. Normalisation makes the measured ARTWORK
//  hit the seam ratio, optically centred — so containment holds at every scale by
//  construction. These tests pin that at the top emoji step (22 → ratio 0.77).
//
//  Swift 6 - Strict Concurrency
//

import Testing
import AppKit
@testable import Dock_Tile

@MainActor
struct EmojiInkFitRenderTests {

    private static let tile: CGFloat = 256
    /// Top emoji step (scale 22) — the tightest fit, so the strongest containment check.
    private static let targetRatio: CGFloat = 0.77

    /// Draw the emoji exactly as generateIcon does (target side = ratio × tile) onto a
    /// transparent bitmap, no shadow/sheen, and return the tight alpha bounds in y-down
    /// tile coordinates.
    private func renderedInk(_ emoji: String) throws -> CGRect {
        let px = Int(Self.tile)
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        rep.size = CGSize(width: Self.tile, height: Self.tile)
        let gctx = try #require(NSGraphicsContext(bitmapImageRep: rep))

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        IconGenerator.drawEmoji(
            emoji: emoji,
            rect: CGRect(x: 0, y: 0, width: Self.tile, height: Self.tile),
            fontSize: Self.tile * Self.targetRatio,
            shadow: nil,
            sheen: nil
        )
        NSGraphicsContext.restoreGraphicsState()

        let data = try #require(rep.bitmapData)
        let rowBytes = rep.bytesPerRow
        var minX = px, minY = px, maxX = -1, maxY = -1
        for y in 0..<px {
            for x in 0..<px {
                if data[y * rowBytes + x * 4 + 3] > 8 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        try #require(maxX >= 0, "\(emoji) rendered no ink")
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Spread of artwork-to-em fill fractions: 🟥 ~1.0, 😀 ~1.0, ⚽ ~0.96, 🍕 off-centre,
    /// 🧊 ~0.65 sparse, 🇦🇺 wide-short flag.
    private static let sample = ["🟥", "😀", "⚽", "🍕", "🧊", "🇦🇺", "🚢"]

    @Test("Every emoji's rendered artwork hits the seam ratio, regardless of em fill")
    func artworkHitsTarget() throws {
        for emoji in Self.sample {
            let ink = try renderedInk(emoji)
            let maxDim = max(ink.width, ink.height) / Self.tile
            // ±0.03 absorbs strike-to-strike artwork drift between the measurement's
            // reference size and the render size (color emoji ship as discrete bitmaps).
            #expect(abs(maxDim - Self.targetRatio) < 0.03,
                    "\(emoji) artwork fills \(maxDim) of the tile; target \(Self.targetRatio)")
        }
    }

    @Test("Every emoji's artwork is optically centred and inside the safe area")
    func artworkCentredAndContained() throws {
        // At ratio 0.77 the artwork's edges must clear the tile edge by (1−0.77)/2 ≈ 29px;
        // 24px asserted (tolerance as above). Inside the squircle's ~0.86 centred-square
        // bound with margin — nothing can poke outside the tile shape.
        let margin: CGFloat = 24
        for emoji in Self.sample {
            let ink = try renderedInk(emoji)
            #expect(ink.minX >= margin && ink.minY >= margin
                    && ink.maxX <= Self.tile - margin && ink.maxY <= Self.tile - margin,
                    "\(emoji) ink \(ink) escapes the safe area")
            #expect(abs(ink.midX - Self.tile / 2) <= 4, "\(emoji) off-centre horizontally: \(ink)")
            #expect(abs(ink.midY - Self.tile / 2) <= 4, "\(emoji) off-centre vertically: \(ink)")
        }
    }
}
