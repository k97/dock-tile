//
//  This file no longer defines AppearanceManager/AppearanceMode (deleted 2026-09-01 — dead code
//  embodying the superseded dark-mode design of a grey background + raw-tint glyph, replaced by
//  the current darkened-own-tint treatment, and an overload trap: `TintColor.colors(for:)` /
//  `.nsColors(for:)` existed for both `AppearanceMode` and `IconStyle`, both with a `.dark`
//  case, so a type-inference accident could silently resurrect the old rendering). What remains
//  below — the `NSColor`/`Color` extensions (`darkenedForDarkMode`, `liftedForDarkGlyph`, the hex
//  initialisers, `lighterShade(by:)`) — is live code the current icon rendering depends on.
//
import SwiftUI
import AppKit

extension TintColor {

    // MARK: - NSColor Accessors

    /// The top gradient color as NSColor
    var nsColorTop: NSColor {
        switch self {
        case .preset(_):
            return NSColor(colorTop)
        case .custom(let hex):
            if let color = NSColor(hex: hex) {
                // Create a lighter shade by increasing brightness (not using opacity)
                // Using opacity causes the gradient to not fill the entire background
                return color.lighterShade(by: 0.15)
            }
            return NSColor.systemGray
        }
    }

    /// The bottom gradient color as NSColor
    var nsColorBottom: NSColor {
        switch self {
        case .preset(_):
            return NSColor(colorBottom)
        case .custom(let hex):
            return NSColor(hex: hex) ?? NSColor.systemGray
        }
    }

    /// The primary tint color as NSColor
    var nsColor: NSColor {
        return nsColorBottom
    }
}

// MARK: - NSColor Extensions

extension NSColor {
    /// Create a lighter shade of the color by increasing brightness
    /// - Parameter amount: How much to lighten (0.0-1.0), e.g., 0.15 = 15% lighter
    /// - Returns: A lighter version of the color with full opacity
    func lighterShade(by amount: CGFloat) -> NSColor {
        // Convert to HSB color space
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        // Try to get HSB components
        if let hsbColor = self.usingColorSpace(.deviceRGB) {
            hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            // Increase brightness, decrease saturation slightly for a "lighter" feel
            let newBrightness = min(1.0, brightness + amount)
            let newSaturation = max(0.0, saturation - (amount * 0.3))  // Slightly less saturated

            return NSColor(
                hue: hue,
                saturation: newSaturation,
                brightness: newBrightness,
                alpha: 1.0  // Always full opacity
            )
        }

        // Fallback: return original color if conversion fails
        return self
    }

    /// Returns a darkened version of the colour suitable for a dark-mode icon background.
    /// Keeps hue and saturation (so the tile's colour identity is preserved) but *caps*
    /// brightness, so light tints (e.g. amber) darken while already-dark tints stay dark.
    /// HIG: the Dark icon variant keeps the original hue on a darkened background.
    /// - Parameter maxBrightness: The brightness ceiling (0.0-1.0), e.g. 0.22.
    func darkenedForDarkMode(maxBrightness: CGFloat) -> NSColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if let hsbColor = self.usingColorSpace(.deviceRGB) {
            hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return NSColor(
                hue: hue,
                saturation: saturation,
                brightness: min(brightness, maxBrightness),
                alpha: 1.0  // Always full opacity
            )
        }

        // Fallback: return original color if conversion fails
        return self
    }

    /// Returns a version of the colour lifted to a minimum *perceived luminance*, suitable for a
    /// Dark-style **glyph** sitting on a neutral near-black background. Blends the colour toward
    /// white only as far as needed to clear the floor, preserving hue while shedding saturation.
    ///
    /// WHY perceived luminance, not HSB brightness: a colour like Media's `#5F00FF` has *maximum*
    /// HSB brightness (its bright channel is blue) yet reads dark because blue is weighted only
    /// 0.114 in perceived luminance — so "raise brightness" is a no-op on exactly the colours that
    /// vanish on near-black. Lifting on `0.299R+0.587G+0.114B` fixes that. (HIG: the Dark variant's
    /// foreground "may need to be made lighter for better contrast.")
    /// - Parameter minLuminance: The perceived-luminance floor (0.0-1.0), e.g. 0.6.
    func liftedForDarkGlyph(minLuminance: CGFloat) -> NSColor {
        guard let rgb = self.usingColorSpace(.deviceRGB) else { return self }
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        guard luminance < minLuminance else {
            // Already light enough; return at full opacity (drop any inherited alpha).
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
        // Blend toward white by t. Because luminance is linear in RGB, this lands L' on the floor.
        let t = (minLuminance - luminance) / (1.0 - luminance)
        return NSColor(
            red: r + t * (1.0 - r),
            green: g + t * (1.0 - g),
            blue: b + t * (1.0 - b),
            alpha: 1.0
        )
    }

    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        switch hexSanitized.count {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - SwiftUI Color Initializer from NSColor

extension Color {
    init(_ nsColor: NSColor) {
        self.init(nsColor: nsColor)
    }
}
