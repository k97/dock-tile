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

/// Sum of the RGB channels — a simple, monotonic proxy for "lightness". The TintColor gradient
/// invariant is that the TOP stop is always lighter (higher sum) than the BOTTOM stop.
private func lightness(_ color: Color) -> CGFloat? {
    guard let c = rgba(color) else { return nil }
    return c.r + c.g + c.b
}

// MARK: - TintColor Extended Tests

/// Additional focused tests for TintColor functionality
@Suite("TintColor Extended Tests")
struct TintColorExtendedTests {

    // MARK: - Preset Color Properties

    @Test("Red preset gradient: red channel dominates and the two stops differ")
    func redPresetColors() throws {
        let red = TintColor.preset(.red)
        let top = try #require(rgba(red.colorTop))
        let bottom = try #require(rgba(red.colorBottom))

        // Red dominates both stops.
        #expect(top.r > top.g && top.r > top.b)
        #expect(bottom.r > bottom.g && bottom.r > bottom.b)
        // The gradient is not flat.
        #expect(top != bottom)
        #expect(red.displayName == "Red")
    }

    /// Gradient invariant for EVERY preset: the top stop is strictly lighter than the bottom,
    /// and the two stops are distinct. A regression that flattens or inverts a gradient (e.g. a
    /// copy-paste error in the colour table) fails here instead of shipping a flat icon.
    @Test("Every preset's top stop is lighter than its bottom stop")
    func presetsHaveDistinctGradients() throws {
        for preset in TintColor.PresetColor.allCases {
            let color = TintColor.preset(preset)
            let topLight = try #require(lightness(color.colorTop), "\(preset) colorTop")
            let bottomLight = try #require(lightness(color.colorBottom), "\(preset) colorBottom")

            #expect(topLight > bottomLight, "\(preset): top should be lighter than bottom")
            #expect(rgba(color.colorTop)! != rgba(color.colorBottom)!, "\(preset): stops must differ")
        }
    }

    @Test("PresetColor allCases contains all colors")
    func allCasesComplete() {
        let expected = 7  // red, orange, green, blue, purple, pink, gray
        #expect(TintColor.PresetColor.allCases.count == expected)
    }

    // MARK: - Custom Color Properties

    @Test("Custom colorBottom equals the input hex; colorTop is a lighter shade")
    func customColorBottom() throws {
        // #FF5733 → r=1.0, g=0x57/255≈0.341, b=0x33/255=0.2
        let color = TintColor.custom("#FF5733")
        let bottom = try #require(rgba(color.colorBottom))

        #expect(abs(bottom.r - 1.0) < 0.01)
        #expect(abs(bottom.g - 0.341) < 0.01)
        #expect(abs(bottom.b - 0.2) < 0.01)

        // Top is a genuinely lighter shade of the same base.
        let topLight = try #require(lightness(color.colorTop))
        let bottomLight = try #require(lightness(color.colorBottom))
        #expect(topLight > bottomLight)
    }

    @Test("Custom colorBottom round-trips the input hex across formats", arguments: [
        ("#FF0000", 1.0, 0.0, 0.0),
        ("#00FF00", 0.0, 1.0, 0.0),
        ("#0000FF", 0.0, 0.0, 1.0),
        ("#ABCDEF", 0.6706, 0.8039, 0.9373),       // 0xAB,0xCD,0xEF / 255
        ("#abcdef", 0.6706, 0.8039, 0.9373)        // case-insensitive
    ] as [(String, Double, Double, Double)])
    func customColorVariousFormats(_ hex: String, _ r: Double, _ g: Double, _ b: Double) throws {
        let comps = try #require(rgba(TintColor.custom(hex).colorBottom))
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
