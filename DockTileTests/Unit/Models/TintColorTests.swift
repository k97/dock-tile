import Testing
import SwiftUI
import AppKit
@testable import Dock_Tile

// MARK: - Color measurement helpers

/// RGBA components of a SwiftUI Color via deviceRGB. Returns nil if conversion fails.
private func rgba(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    guard let c = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
    return (c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
}

// MARK: - TintColor Extended Tests

/// Additional focused tests for TintColor functionality
@Suite("TintColor Extended Tests")
struct TintColorExtendedTests {

    // MARK: - Preset Color Properties

    @Test("PresetColor allCases contains all colors")
    func allCasesComplete() {
        let expected = 7  // red, orange, green, blue, purple, pink, gray
        #expect(TintColor.PresetColor.allCases.count == expected)
    }

    // MARK: - Custom Color Properties

    @Test("Color(hex:) round-trips a custom colour's hex across formats", arguments: [
        ("#FF0000", 1.0, 0.0, 0.0),
        ("#00FF00", 0.0, 1.0, 0.0),
        ("#0000FF", 0.0, 0.0, 1.0),
        ("#ABCDEF", 0.6706, 0.8039, 0.9373),       // 0xAB,0xCD,0xEF / 255
        ("#abcdef", 0.6706, 0.8039, 0.9373)        // case-insensitive
    ] as [(String, Double, Double, Double)])
    func customColorVariousFormats(_ hex: String, _ r: Double, _ g: Double, _ b: Double) throws {
        let comps = try #require(rgba(Color(hex: hex)))
        #expect(abs(comps.r - CGFloat(r)) < 0.01, "\(hex) red")
        #expect(abs(comps.g - CGFloat(g)) < 0.01, "\(hex) green")
        #expect(abs(comps.b - CGFloat(b)) < 0.01, "\(hex) blue")
        #expect(comps.a == 1.0, "\(hex) should be fully opaque")
    }

    // MARK: - Equality

    @Test("Same preset colors are equal")
    func presetEquality() {
        #expect(TintColor.blue == TintColor.preset(.blue))
        #expect(TintColor.red == TintColor.preset(.red))
    }

    @Test("Different preset colors are not equal")
    func presetInequality() {
        #expect(TintColor.blue != TintColor.red)
        #expect(TintColor.green != TintColor.purple)
    }

    @Test("Same custom colors are equal")
    func customEquality() {
        #expect(TintColor.custom("#FF5733") == TintColor.custom("#FF5733"))
    }

    @Test("Different custom colors are not equal")
    func customInequality() {
        #expect(TintColor.custom("#FF5733") != TintColor.custom("#00FF00"))
    }

    @Test("Custom and preset colors are not equal")
    func customVsPreset() {
        // Even if the hex might be similar, they're different types
        #expect(TintColor.custom("#007AFF") != TintColor.blue)
    }

    // MARK: - Hashable

    @Test("Preset colors have consistent hash values")
    func presetHashConsistency() {
        let blue1 = TintColor.blue
        let blue2 = TintColor.preset(.blue)

        #expect(blue1.hashValue == blue2.hashValue)
    }

    @Test("Different colors have different hashes (usually)")
    func differentColorsHaveDifferentHashes() {
        let colors = TintColor.allPresets
        var hashes = Set<Int>()

        for color in colors {
            hashes.insert(color.hashValue)
        }

        // Most colors should have unique hashes
        // (hash collisions are possible but unlikely for 8 items)
        #expect(hashes.count >= 6)
    }

    @Test("Colors can be used as dictionary keys")
    func dictionaryKeys() {
        var dict: [TintColor: String] = [:]

        dict[.blue] = "Blue"
        dict[.red] = "Red"
        dict[.custom("#FF5733")] = "Custom"

        #expect(dict[.blue] == "Blue")
        #expect(dict[.red] == "Red")
        #expect(dict[.custom("#FF5733")] == "Custom")
    }

    @Test("Colors can be used in Sets")
    func setOperations() {
        var colorSet = Set<TintColor>()

        colorSet.insert(.blue)
        colorSet.insert(.red)
        colorSet.insert(.blue)  // Duplicate

        #expect(colorSet.count == 2)
        #expect(colorSet.contains(.blue))
        #expect(colorSet.contains(.red))
        #expect(!colorSet.contains(.green))
    }

    // MARK: - Encoding Edge Cases

    @Test("Encoding preserves case sensitivity of hex values")
    func encodingPreservesHexCase() throws {
        let color = TintColor.custom("#AbCdEf")

        let encoder = JSONEncoder()
        let data = try encoder.encode(color)
        let json = String(data: data, encoding: .utf8)!

        // The hex should be preserved as-is
        #expect(json.contains("AbCdEf"))
    }

    @Test("Multiple encode/decode cycles preserve value")
    func multipleRoundTrips() throws {
        let original = TintColor.custom("#123ABC")

        var current = original
        for _ in 0..<5 {
            let encoder = JSONEncoder()
            let data = try encoder.encode(current)

            let decoder = JSONDecoder()
            current = try decoder.decode(TintColor.self, from: data)
        }

        #expect(current == original)
    }

    // MARK: - Display Names

    @Test("All preset display names are capitalized")
    func displayNamesCapitalized() {
        for preset in TintColor.PresetColor.allCases {
            let name = preset.displayName
            #expect(name.first?.isUppercase == true)
        }
    }

    @Test("Custom display name format")
    func customDisplayNameFormat() {
        let color = TintColor.custom("#AABBCC")
        let displayName = color.displayName

        #expect(displayName.hasPrefix("Custom"))
        #expect(displayName.contains("#AABBCC"))
    }

    // MARK: - Icon Names

    @Test("All preset colors have icon names")
    func presetIconNames() {
        for preset in TintColor.PresetColor.allCases {
            let iconName = preset.iconName
            #expect(!iconName.isEmpty)
        }
    }
}

// MARK: - PresetColor Extension

extension TintColor.PresetColor {
    /// SF Symbol icon name for the color (for UI pickers)
    var iconName: String {
        switch self {
        case .red: return "circle.fill"
        case .orange: return "circle.fill"
        case .green: return "circle.fill"
        case .blue: return "circle.fill"
        case .purple: return "circle.fill"
        case .pink: return "circle.fill"
        case .gray: return "circle.fill"
        }
    }
}

// MARK: - Dark-style glyph treatment (colored glyph on neutral near-black)

@Suite("Dark-style tinted-glyph rendering")
struct DarkGlyphTreatmentTests {

    @Test("Dark + SF Symbol: neutral near-black background AND a 3:1 tinted glyph (#5F00FF regression)")
    func darkSymbolUsesNeutralBackgroundAndVisibleGlyph() throws {
        let result = TintColor.custom("#5F00FF").nsColors(for: .dark, iconType: .sfSymbol, background: .colour)
        let top = try #require(result.backgroundTop.usingColorSpace(.sRGB))
        let expected = try #require(SRGB(hex: TintColor.darkNeutralTopHex))
        #expect(abs(top.redComponent - expected.r) < 0.002)
        let fg = try #require(result.foreground.usingColorSpace(.sRGB))
        let glyph = SRGB(r: fg.redComponent, g: fg.greenComponent, b: fg.blueComponent)
        #expect(ToneMap.contrastRatio(glyph.darkened(by: 0.10), expected) >= ToneMap.floor)
        #expect(fg.blueComponent > fg.greenComponent)   // still violet
    }

    @Test("SwiftUI colors(for:) mirrors nsColors(for:) for every background x style x icon type")
    func swiftUIMirrorsNSColors() throws {
        let tints: [TintColor] = [.custom("#5F00FF"), .preset(.blue), .preset(.orange)]
        for background in TileBackground.allCases {
            for style in IconStyle.allCases {
                for iconType in [IconType.sfSymbol, .emoji] {
                    for tint in tints {
                        let ns = tint.nsColors(for: style, iconType: iconType, background: background)
                        let sw = tint.colors(for: style, iconType: iconType, background: background)
                        let label = "\(background) / \(style) / \(iconType) / \(tint)"
                        try expectSameColour(ns.foreground, sw.foreground, "foreground \(label)")
                        try expectSameColour(ns.backgroundTop, sw.backgroundTop, "backgroundTop \(label)")
                        try expectSameColour(ns.backgroundBottom, sw.backgroundBottom, "backgroundBottom \(label)")
                    }
                }
            }
        }
    }

    private func expectSameColour(
        _ ns: NSColor, _ swiftUI: Color, _ label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let a = try #require(ns.usingColorSpace(.sRGB), "\(label): NSColor not convertible", sourceLocation: sourceLocation)
        let b = try #require(NSColor(swiftUI).usingColorSpace(.sRGB), "\(label): Color not convertible", sourceLocation: sourceLocation)
        #expect(abs(a.redComponent - b.redComponent) < 0.002, "\(label) red", sourceLocation: sourceLocation)
        #expect(abs(a.greenComponent - b.greenComponent) < 0.002, "\(label) green", sourceLocation: sourceLocation)
        #expect(abs(a.blueComponent - b.blueComponent) < 0.002, "\(label) blue", sourceLocation: sourceLocation)
    }

    @Test("Non-Dark styles ignore iconType through the adapter too (Default fill is shared)")
    func nonDarkStylesIgnoreIconType() throws {
        for background in TileBackground.allCases {
            let symbol = TintColor.preset(.purple).nsColors(for: .defaultStyle, iconType: .sfSymbol, background: background)
            let emoji = TintColor.preset(.purple).nsColors(for: .defaultStyle, iconType: .emoji, background: background)
            let s = try #require(symbol.backgroundTop.usingColorSpace(.sRGB))
            let e = try #require(emoji.backgroundTop.usingColorSpace(.sRGB))
            #expect(abs(s.redComponent - e.redComponent) < 0.001)
            #expect(abs(s.greenComponent - e.greenComponent) < 0.001)
            #expect(abs(s.blueComponent - e.blueComponent) < 0.001)
        }
    }

    @Test("Adapters are the palette: nsColors equals TilePalette.resolve exactly")
    func adapterIsThePalette() throws {
        let tint = TintColor.preset(.green)
        let roles = TilePalette.resolve(tint: tint, background: .mono, style: .defaultStyle, iconType: .sfSymbol)
        let fg = try #require(tint.nsColors(for: .defaultStyle, iconType: .sfSymbol, background: .mono).foreground.usingColorSpace(.sRGB))
        #expect(abs(fg.redComponent - roles.glyph.r) < 1e-6)
        #expect(abs(fg.greenComponent - roles.glyph.g) < 1e-6)
        #expect(abs(fg.blueComponent - roles.glyph.b) < 1e-6)
    }
}

@Suite("Settings badge style mapping mirrors the tile mapping")
struct BadgeColorMappingTests {

    /// The seam exists so the sidebar badges restyle in lock-step with the tile icons beside
    /// them. Grayscale styles carry no tint at all, so badgeColors must return EXACTLY the same
    /// constants `colors(for:)` gives every tile — compared component-wise through NSColor.
    @Test("Clear and Tinted are the tile mapping's exact grayscale constants",
          arguments: [IconStyle.clear, IconStyle.tinted])
    func grayscaleStylesMatchTileMapping(_ style: IconStyle) throws {
        let badge = TintColor.badgeColors(for: style, tint: .purple)
        let tile = TintColor.blue.colors(for: style, iconType: .sfSymbol, background: .colour)
        for (a, b) in [(badge.top, tile.backgroundTop),
                       (badge.bottom, tile.backgroundBottom),
                       (badge.foreground, tile.foreground)] {
            let na = try #require(NSColor(a).usingColorSpace(.deviceRGB))
            let nb = try #require(NSColor(b).usingColorSpace(.deviceRGB))
            #expect(abs(na.redComponent - nb.redComponent) < 0.001)
            #expect(abs(na.greenComponent - nb.greenComponent) < 0.001)
            #expect(abs(na.blueComponent - nb.blueComponent) < 0.001)
        }
    }

    @Test("Dark style: neutral near-black background, glyph from the palette's 3:1 rule")
    func darkStyleUsesPalette() throws {
        let badge = TintColor.badgeColors(for: .dark, tint: Color(hex: "#1A0533"))
        let top = try #require(NSColor(badge.top).usingColorSpace(.sRGB))
        #expect(abs(top.redComponent - TilePalette.darkTop.r) < 0.002)
        let fg = try #require(NSColor(badge.foreground).usingColorSpace(.sRGB))
        let glyph = SRGB(r: fg.redComponent, g: fg.greenComponent, b: fg.blueComponent)
        #expect(ToneMap.contrastRatio(glyph.darkened(by: 0.10), TilePalette.darkTop) >= ToneMap.floor)
    }

    @Test("Default style: the Colour-tile fill rule with a white glyph")
    func defaultStyleUsesColourFill() throws {
        let badge = TintColor.badgeColors(for: .defaultStyle, tint: Color(hex: "#FF9500"))
        let expected = TilePalette.resolve(base: SRGB(hex: "#FF9500")!, light: SRGB(hex: "#FF9500")!,
                                           background: .colour, style: .defaultStyle, iconType: .sfSymbol)
        let top = try #require(NSColor(badge.top).usingColorSpace(.sRGB))
        #expect(abs(top.redComponent - expected.top.r) < 0.002 && abs(top.greenComponent - expected.top.g) < 0.002)
        let fg = try #require(NSColor(badge.foreground).usingColorSpace(.sRGB))
        #expect(fg.redComponent > 0.99 && fg.greenComponent > 0.99 && fg.blueComponent > 0.99)
    }
}
