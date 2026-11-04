//
//  ColorExtensions.swift
//  DockTile
//
//  Hex color support for SwiftUI Color
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

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

    /// Blend this colour toward black by `fraction` (0 = unchanged, 1 = black).
    /// Used for the glyph's dimensional shading (top → bottom fill) in the icon depth
    /// treatment, mirrored by `NSColor.darkened(by:)` in the baked renderer.
    func darkened(by fraction: CGFloat) -> Color {
        Color(NSColor(self).darkened(by: fraction))
    }
}

extension NSColor {
    /// Blend this colour toward black by `fraction` (0 = unchanged, 1 = black).
    /// Counterpart to `Color.darkened(by:)` for `IconGenerator`'s CoreGraphics pipeline.
    func darkened(by fraction: CGFloat) -> NSColor {
        blended(withFraction: fraction, of: .black) ?? self
    }
}
