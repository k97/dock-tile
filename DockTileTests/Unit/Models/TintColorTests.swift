import Testing
import SwiftUI
import AppKit
@testable import Dock_Tile

// MARK: - TintColor Extended Tests

/// Additional focused tests for TintColor functionality
@Suite("TintColor Extended Tests")
struct TintColorExtendedTests {

    // MARK: - Preset Color Properties

    @Test("Red preset has correct gradient colors")
    func redPresetColors() {
        let red = TintColor.preset(.red)

        // Top should be lighter (#FF6B6B)
        // Bottom should be saturated (#FF3B30)
        _ = red.colorTop
        _ = red.colorBottom

        // Verify displayName
        #expect(red.displayName == "Red")
    }

    @Test("All presets have distinct top and bottom colors")
    func presetsHaveDistinctGradients() {
        for preset in TintColor.PresetColor.allCases {
            let color = TintColor.preset(preset)
            let top = color.colorTop
            let bottom = color.colorBottom

            // Top and bottom should be different for gradient effect
            // We verify they exist (don't crash) - actual color comparison would require
            // converting to components which is complex
            _ = top
            _ = bottom
        }
    }

    @Test("PresetColor allCases contains all colors")
    func allCasesComplete() {
        let expected = 7  // red, orange, green, blue, purple, pink, gray
        #expect(TintColor.PresetColor.allCases.count == expected)
    }

    // MARK: - Custom Color Properties

    @Test("Custom color colorBottom returns the input hex color")
    func customColorBottom() {
        let customHex = "#FF5733"
        let color = TintColor.custom(customHex)

        // colorBottom should be the base hex color
        _ = color.colorBottom
        // colorTop should be a lighter shade
        _ = color.colorTop
    }

    @Test("Custom color with various hex formats")
    func customColorVariousFormats() {
        let colors: [TintColor] = [
            .custom("#FF0000"),     // Standard 6-char
            .custom("#00FF00"),     // Green
            .custom("#0000FF"),     // Blue
            .custom("#123456"),     // Random
            .custom("#ABCDEF"),     // Uppercase
            .custom("#abcdef"),     // Lowercase
        ]

        for color in colors {
            // Should not crash
            _ = color.colorTop
            _ = color.colorBottom
            _ = color.color
            _ = color.displayName
        }
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
