//
//  ColorExtensions.swift
//  DockTile
//
//  Hex color support for SwiftUI Color
//  Swift 6 - Strict Concurrency
//

import SwiftUI

extension Color {
    /// Initialize Color from hex string
    /// Supports formats: "#RRGGBB", "#RGB", "#RRGGBBAA", "#RGBA"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Convert Color to hex string
    func toHex() -> String? {
        guard let components = self.cgColor?.components, components.count >= 3 else {
            return nil
        }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Create a lighter shade of the color by increasing brightness
    /// - Parameter amount: How much to lighten (0.0-1.0), e.g., 0.15 = 15% lighter
    /// - Returns: A lighter version of the color with full opacity
    func lighterShade(by amount: CGFloat) -> Color {
        // Convert to NSColor, apply transformation, convert back
        let nsColor = NSColor(self)

        // Try to get HSB components
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if let hsbColor = nsColor.usingColorSpace(.deviceRGB) {
            hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            // Increase brightness, decrease saturation slightly for a "lighter" feel
            let newBrightness = min(1.0, brightness + amount)
            let newSaturation = max(0.0, saturation - (amount * 0.3))

            let lighterNSColor = NSColor(
                hue: hue,
                saturation: newSaturation,
                brightness: newBrightness,
                alpha: 1.0
            )

            return Color(lighterNSColor)
        }

        // Fallback: return original color
        return self
    }
}
