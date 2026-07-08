//
//  EmojiSheenMaskTests.swift
//  DockTileTests
//
//  Regression guard for the emoji glyph-sheen mask (IconGenerator.emojiSheenImage).
//
//  THE REGRESSION THIS KILLS: the gloss used to be painted first and "masked" by drawing the
//  emoji over it with `.destinationIn`. CoreText colour-glyph drawing does not honour that
//  blend mode — it produced the INVERSE mask, so every baked emoji tile carried a translucent
//  white rectangle (the glyph's full typographic box, minus the emoji) that read as a
//  plate/bevel behind the sticker. SF Symbol tiles were unaffected (different mask path),
//  which is exactly how it shipped unnoticed: the SwiftUI live preview masks correctly, only
//  the baked `.icns` was wrong. These tests pin the mask's actual pixels.
//
//  Swift 6 - Strict Concurrency
//

import Testing
import AppKit
@testable import Dock_Tile

@MainActor
struct EmojiSheenMaskTests {

    /// Renders the sheen at full strength over the whole glyph height so every assertion
    /// reads undiluted mask output (the production alpha/heightFraction only scale it).
    private func sheenBitmap(for emoji: String) throws -> NSBitmapImageRep {
        let font = NSFont.systemFont(ofSize: 120)
        let size = NSAttributedString(string: emoji, attributes: [.font: font]).size()
        let image = try #require(IconGenerator.emojiSheenImage(
            emoji: emoji,
            font: font,
            size: size,
            alpha: 1.0,
            heightFraction: 1.0
        ))
        return try #require(image.representations.first as? NSBitmapImageRep)
    }

    @Test("gloss never escapes the emoji silhouette — typographic-box corners stay fully transparent")
    func cornersCarryNoGloss() throws {
        // Both emoji leave all four corners of their typographic box empty. Under the broken
        // destinationIn arrangement the TOP corners came back at ~full alpha (the plate).
        for emoji in ["🚢", "⚽"] {
            let rep = try sheenBitmap(for: emoji)
            let corners = [
                (1, 1), (rep.pixelsWide - 2, 1),
                (1, rep.pixelsHigh - 2), (rep.pixelsWide - 2, rep.pixelsHigh - 2)
            ]
            for (x, y) in corners {
                let alpha = try #require(rep.colorAt(x: x, y: y)).alphaComponent
                #expect(alpha == 0.0, "\(emoji) gloss leaked outside the silhouette at (\(x), \(y))")
            }
        }
    }

    @Test("gloss actually lands on the emoji body")
    func glossCoversSilhouette() throws {
        // Centre of a solid round emoji is inside the silhouette; with alpha 1.0 fading over
        // the full height, the mid-height gloss must still be clearly present. The inverse
        // mask (or an all-transparent mask) fails this.
        let rep = try sheenBitmap(for: "⚽")
        let centre = try #require(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2))
        #expect(centre.alphaComponent > 0.2)
    }
}
