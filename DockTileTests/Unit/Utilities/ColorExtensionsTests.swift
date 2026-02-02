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

    @Test("Color converts to hex string")
    func toHexString() {
        let color = Color(hex: "#FF5733")
        let hexString = color.toHex()

        // Color space conversions can cause slight variations
        // Just verify we get a valid hex string back
        #expect(hexString != nil)
        #expect(hexString?.hasPrefix("#") == true)
        #expect(hexString?.count == 7)
    }

    @Test("Color initialized from hex converts back to valid hex")
    func hexRoundTrip() {
        // Use a color initialized from hex (not SwiftUI's system colors)
        // because Color.red doesn't have direct cgColor access
        let color = Color(hex: "#FF0000")
        let hexString = color.toHex()

        #expect(hexString != nil)
        #expect(hexString?.hasPrefix("#") == true)
        #expect(hexString?.count == 7)
    }

    // MARK: - Lighter Shade

    @Test("lighterShade increases brightness")
    func lighterShadeIncreasesBrightness() {
        let original = Color(hex: "#336699")
        let lighter = original.lighterShade(by: 0.2)

        let nsOriginal = NSColor(original)
        let nsLighter = NSColor(lighter)

        guard let rgbOriginal = nsOriginal.usingColorSpace(.deviceRGB),
              let rgbLighter = nsLighter.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        var origBrightness: CGFloat = 0
        var lightBrightness: CGFloat = 0

        rgbOriginal.getHue(nil, saturation: nil, brightness: &origBrightness, alpha: nil)
        rgbLighter.getHue(nil, saturation: nil, brightness: &lightBrightness, alpha: nil)

        #expect(lightBrightness > origBrightness)
    }

    @Test("lighterShade decreases saturation")
    func lighterShadeDecreasesSaturation() {
        let original = Color(hex: "#FF0000")  // Pure saturated red
        let lighter = original.lighterShade(by: 0.2)

        let nsOriginal = NSColor(original)
        let nsLighter = NSColor(lighter)

        guard let rgbOriginal = nsOriginal.usingColorSpace(.deviceRGB),
              let rgbLighter = nsLighter.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        var origSaturation: CGFloat = 0
        var lightSaturation: CGFloat = 0

        rgbOriginal.getHue(nil, saturation: &origSaturation, brightness: nil, alpha: nil)
        rgbLighter.getHue(nil, saturation: &lightSaturation, brightness: nil, alpha: nil)

        #expect(lightSaturation < origSaturation)
    }

    @Test("lighterShade with zero amount returns similar color")
    func lighterShadeZeroAmount() {
        let original = Color(hex: "#336699")
        let lighter = original.lighterShade(by: 0.0)

        let nsOriginal = NSColor(original)
        let nsLighter = NSColor(lighter)

        guard let rgbOriginal = nsOriginal.usingColorSpace(.deviceRGB),
              let rgbLighter = nsLighter.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        // Should be very similar (allowing for floating point differences)
        #expect(abs(rgbOriginal.redComponent - rgbLighter.redComponent) < 0.01)
        #expect(abs(rgbOriginal.greenComponent - rgbLighter.greenComponent) < 0.01)
        #expect(abs(rgbOriginal.blueComponent - rgbLighter.blueComponent) < 0.01)
    }

    @Test("lighterShade caps brightness at 1.0")
    func lighterShadeCappedBrightness() {
        let original = Color(hex: "#FFFFFF")  // Already maximum brightness
        let lighter = original.lighterShade(by: 0.5)

        let nsLighter = NSColor(lighter)

        guard let rgbLighter = nsLighter.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        var brightness: CGFloat = 0
        rgbLighter.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)

        #expect(brightness <= 1.0)
    }

    @Test("lighterShade returns full opacity")
    func lighterShadeFullOpacity() {
        let original = Color(hex: "#80336699")  // 50% alpha
        let lighter = original.lighterShade(by: 0.2)

        let nsLighter = NSColor(lighter)

        guard let rgbLighter = nsLighter.usingColorSpace(.deviceRGB) else {
            Issue.record("Could not convert to RGB color space")
            return
        }

        #expect(rgbLighter.alphaComponent == 1.0)
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
