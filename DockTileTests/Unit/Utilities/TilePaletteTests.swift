//  TilePaletteTests.swift — the colour each renderer draws, per background × style × icon type.
import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Dock_Tile

@Suite("TilePalette roles")
struct TilePaletteTests {
    private let presets = TintColor.allPresets
    private let customs: [TintColor] = [.custom("#FFFFFF"), .custom("#000000"), .custom("#5F00FF"), .custom("#FFCC00")]

    private func q(_ c: SRGB) -> SRGB {
        SRGB(r: (c.r * 255).rounded() / 255, g: (c.g * 255).rounded() / 255, b: (c.b * 255).rounded() / 255)
    }

    @Test("Mono Light: white→#EFEFF1 tile, symbol clears 3.0 against the darker stop")
    func monoLight() throws {
        for tint in presets + customs {
            for type in [IconType.sfSymbol, .emoji] {
                let r = TilePalette.resolve(tint: tint, background: .mono, style: .defaultStyle, iconType: type)
                #expect(r.top == SRGB(hex: "#FFFFFF"))
                #expect(r.bottom == SRGB(hex: "#EFEFF1"))
                #expect(ToneMap.contrastRatio(q(r.glyph), r.bottom) >= ToneMap.floor, "\(tint)")
            }
        }
    }

    @Test("Dark symbol (Colour or Mono): neutral near-black, SHADED symbol bottom clears 3.0")
    func darkSymbol() throws {
        let shade = try #require(IconDepthMetrics.glyphBottomDarken(style: .dark, iconType: .sfSymbol, nominalSize: 1024))
        for bg in TileBackground.allCases {
            for tint in presets + customs {
                let r = TilePalette.resolve(tint: tint, background: bg, style: .dark, iconType: .sfSymbol)
                #expect(r.top == SRGB(hex: TintColor.darkNeutralTopHex))
                #expect(r.bottom == SRGB(hex: TintColor.darkNeutralBottomHex))
                let shaded = q(r.glyph).darkened(by: Double(shade))
                #expect(ToneMap.contrastRatio(shaded, r.top) >= ToneMap.floor, "\(bg) \(tint)")
            }
        }
    }

    @Test("Mono Dark emoji: neutral near-black (not the darkened tint)")
    func monoDarkEmoji() {
        let r = TilePalette.resolve(tint: .blue, background: .mono, style: .dark, iconType: .emoji)
        #expect(r.top == SRGB(hex: TintColor.darkNeutralTopHex))
        #expect(r.bottom == SRGB(hex: TintColor.darkNeutralBottomHex))
    }

    @Test("Colour Dark emoji keeps the darkened-own-tint background (exact blue values)")
    func colourDarkEmoji() throws {
        let r = TilePalette.resolve(tint: .blue, background: .colour, style: .dark, iconType: .emoji)
        // top = light stop #4DABF7 scaled so its max channel is 0.22; bottom = base #007AFF scaled to 0.13
        let tol = 1e-9
        #expect(abs(r.top.r - 0.22 * 77.0 / 247.0) < tol)
        #expect(abs(r.top.g - 0.22 * 171.0 / 247.0) < tol)
        #expect(abs(r.top.b - 0.22) < tol)
        #expect(abs(r.bottom.r - 0) < tol)
        #expect(abs(r.bottom.g - 0.13 * 122.0 / 255.0) < tol)
        #expect(abs(r.bottom.b - 0.13) < tol)
    }

    @Test("Colour Default: white symbol clears 3.0 against the fill's lighter top; bottom is darker")
    func colourFill() throws {
        let shade = try #require(IconDepthMetrics.glyphBottomDarken(style: .defaultStyle, iconType: .sfSymbol, nominalSize: 1024))
        for tint in presets + customs {
            let r = TilePalette.resolve(tint: tint, background: .colour, style: .defaultStyle, iconType: .sfSymbol)
            #expect(r.glyph == .white)
            #expect(ToneMap.contrastRatio(.white, q(r.top)) >= ToneMap.floor, "\(tint)")
            // The symbol's SHADED bottom sits over the fill's darker bottom stop.
            #expect(ToneMap.contrastRatio(q(SRGB.white.darkened(by: Double(shade))), q(r.bottom)) >= ToneMap.floor, "\(tint) shaded")
            // Never lighter at the bottom; strictly darker for every colour that is not already black
            // (a black custom fill has nowhere darker to go — L clamps at 0).
            #expect(ToneMap.relativeLuminance(r.bottom) <= ToneMap.relativeLuminance(r.top), "\(tint) bottom lighter")
            if tint != .custom("#000000") {
                #expect(ToneMap.relativeLuminance(r.bottom) < ToneMap.relativeLuminance(r.top), "\(tint) gradient is flat")
            }
        }
    }

    @Test("Default style is icon-type independent for every background (symbol and emoji share the fill)")
    func defaultIgnoresIconType() {
        for bg in TileBackground.allCases {
            for tint in presets + customs {
                let s = TilePalette.resolve(tint: tint, background: bg, style: .defaultStyle, iconType: .sfSymbol)
                let e = TilePalette.resolve(tint: tint, background: bg, style: .defaultStyle, iconType: .emoji)
                #expect(s.top == e.top && s.bottom == e.bottom, "\(bg) \(tint)")
            }
        }
    }

    @Test("Clear and Tinted ignore background and tint", arguments: [IconStyle.clear, .tinted])
    func greyscaleStylesUnchanged(_ style: IconStyle) {
        let a = TilePalette.resolve(tint: .orange, background: .colour, style: style, iconType: .sfSymbol)
        let b = TilePalette.resolve(tint: .purple, background: .mono, style: style, iconType: .emoji)
        #expect(a == b)
        if style == .tinted {
            #expect(a.glyph == .white)
            #expect(a.top == SRGB(hex: "#8E8E93") && a.bottom == SRGB(hex: "#636366"))
        } else {
            #expect(a.top == SRGB(hex: "#F0F0F2") && a.bottom == SRGB(hex: "#E0E0E4") && a.glyph == SRGB(hex: "#6E6E73"))
        }
    }

    @Test("A malformed custom hex renders the grey preset's tones, never black")
    func malformedCustomFallsBackToGrey() {
        for bad in ["oops", "#12", ""] {
            #expect(TintColor.custom(bad).baseRGB == TintColor.gray.baseRGB, "\(bad)")
        }
    }

    @Test("fillWasDeepened: orange moves, blue (already 4:1 on white) does not")
    func deepenedFlag() {
        #expect(TilePalette.fillWasDeepened(tint: .orange))
        #expect(!TilePalette.fillWasDeepened(tint: .blue))
    }

    @Test("Preset stops are pinned to independent literals, and the SwiftUI colours match them")
    func presetStopsPinned() throws {
        func c(_ r: Double, _ g: Double, _ b: Double) -> SRGB { SRGB(r: r / 255, g: g / 255, b: b / 255) }
        // (preset, light stop, base stop) as r/g/b components, not parsed from hex
        let table: [(TintColor.PresetColor, SRGB, SRGB)] = [
            (.red, c(0xFF, 0x6B, 0x6B), c(0xFF, 0x3B, 0x30)),
            (.orange, c(0xFF, 0xA9, 0x4D), c(0xFF, 0x95, 0x00)),
            (.green, c(0x6B, 0xCF, 0x7F), c(0x34, 0xC7, 0x59)),
            (.blue, c(0x4D, 0xAB, 0xF7), c(0x00, 0x7A, 0xFF)),
            (.purple, c(0xB1, 0x97, 0xFC), c(0xAF, 0x52, 0xDE)),
            (.pink, c(0xFF, 0x6B, 0x9D), c(0xFF, 0x2D, 0x55)),
            (.gray, c(0xAD, 0xB5, 0xBD), c(0x8E, 0x8E, 0x93)),
        ]
        #expect(table.count == TintColor.PresetColor.allCases.count)
        func rgb(_ color: Color) throws -> (Double, Double, Double) {
            let ns = try #require(NSColor(color).usingColorSpace(.sRGB))
            return (Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent))
        }
        for (p, light, base) in table {
            #expect(TintColor.preset(p).lightRGB == light, "\(p) light")
            #expect(TintColor.preset(p).baseRGB == base, "\(p) base")
            let bottom = try rgb(p.colorBottom)
            #expect(abs(bottom.0 - base.r) < 0.002 && abs(bottom.1 - base.g) < 0.002 && abs(bottom.2 - base.b) < 0.002, "\(p) colorBottom")
        }
    }
}
