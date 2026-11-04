import Testing
import SwiftUI
import AppKit
@testable import Dock_Tile

// MARK: - Color Extension Tests

@Suite("Color Extension Tests")
struct ColorExtensionTests {

    // MARK: - Hex Initialization

    @Test("6-character hex creates correct color")
    func sixCharHex() {
        let color = Color(hex: "#FF5733")
        let nsColor = NSColor(color)

        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        #expect(red == 255)
        #expect(green == 87)
        #expect(blue == 51)
    }

    @Test("6-character hex without hash prefix")
    func sixCharHexNoHash() {
        let color = Color(hex: "00FF00")
        let nsColor = NSColor(color)

        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        let green = Int(round(rgbColor.greenComponent * 255))
        #expect(green == 255)
    }

    @Test("3-character hex expands correctly")
    func threeCharHex() {
        // #F00 should expand to #FF0000 (pure red)
        let color = Color(hex: "#F00")
        let nsColor = NSColor(color)

        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        #expect(red == 255)
        #expect(green == 0)
        #expect(blue == 0)
    }

    @Test("8-character hex includes alpha")
    func eightCharHex() {
        // Format: AARRGGBB
        let color = Color(hex: "#80FF0000")  // 50% alpha, pure red
        let nsColor = NSColor(color)

        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        let alpha = Int(round(rgbColor.alphaComponent * 255))
        let red = Int(round(rgbColor.redComponent * 255))

        #expect(alpha == 128)  // ~50%
        #expect(red == 255)
    }

    @Test("Invalid hex returns black")
    func invalidHex() {
        let color = Color(hex: "invalid")
        let nsColor = NSColor(color)

        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        #expect(red == 0)
        #expect(green == 0)
        #expect(blue == 0)
    }

    @Test("Empty hex returns black")
    func emptyHex() {
        let color = Color(hex: "")
        let nsColor = NSColor(color)

        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        let red = Int(round(rgbColor.redComponent * 255))
        #expect(red == 0)
    }

    @Test("Hex is case insensitive")
    func caseInsensitiveHex() {
        let colorLower = Color(hex: "#ff5733")
        let colorUpper = Color(hex: "#FF5733")

        let nsLower = NSColor(colorLower)
        let nsUpper = NSColor(colorUpper)

        guard let rgbLower = nsLower.usingColorSpace(.deviceRGB),
              let rgbUpper = nsUpper.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        #expect(abs(rgbLower.redComponent - rgbUpper.redComponent) < 0.01)
        #expect(abs(rgbLower.greenComponent - rgbUpper.greenComponent) < 0.01)
        #expect(abs(rgbLower.blueComponent - rgbUpper.blueComponent) < 0.01)
    }

    // MARK: - Hex Output

    /// A custom tile colour was saved through deviceRGB and truncated, while every reader treats the
    /// stored hex as sRGB, so the Dock baked a slightly different colour than the one picked. The
    /// expected hexes are literals; the old path gives #1A679D for the P3 colour, so it fails here.
    @Test("A picked colour is stored as its sRGB hex, rounded")
    func srgbHexString() {
        #expect(Color(.sRGB, red: 95 / 255.0, green: 0, blue: 1).srgbHexString() == "#5F00FF")
        #expect(Color(.displayP3, red: 0.2, green: 0.4, blue: 0.6).srgbHexString() == "#1B689D")
        // An out-of-gamut colour comes back as a valid, clamped hex.
        #expect(Color(.displayP3, red: 1, green: 0, blue: 0).srgbHexString() == "#FF0000")
    }

    // MARK: - Common Colors

    @Test("Common web colors parse correctly")
    func commonWebColors() {
        let testCases: [(String, Int, Int, Int)] = [
            ("#000000", 0, 0, 0),          // Black
            ("#FFFFFF", 255, 255, 255),    // White
            ("#FF0000", 255, 0, 0),        // Red
            ("#00FF00", 0, 255, 0),        // Green
            ("#0000FF", 0, 0, 255),        // Blue
            ("#FFFF00", 255, 255, 0),      // Yellow
            ("#FF00FF", 255, 0, 255),      // Magenta
            ("#00FFFF", 0, 255, 255),      // Cyan
        ]

        for (hex, expectedR, expectedG, expectedB) in testCases {
            let color = Color(hex: hex)
            let nsColor = NSColor(color)

            guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
                Issue.record("Could not convert \(hex) to RGB color space")
                continue
            }

            let red = Int(round(rgbColor.redComponent * 255))
            let green = Int(round(rgbColor.greenComponent * 255))
            let blue = Int(round(rgbColor.blueComponent * 255))

            #expect(red == expectedR, "Red component of \(hex)")
            #expect(green == expectedG, "Green component of \(hex)")
            #expect(blue == expectedB, "Blue component of \(hex)")
        }
    }
}
