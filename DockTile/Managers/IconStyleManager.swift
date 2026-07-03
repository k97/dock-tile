//
//  IconStyleManager.swift
//  DockTile
//
//  Manages macOS Tahoe icon style observation (Default/Dark/Clear/Tinted)
//  This is SEPARATE from Appearance (Light/Dark) - Tahoe has two independent settings
//
//  ARCHITECTURE:
//  - Single source of truth for icon style across the app
//  - Views use @StateObject/@ObservedObject to react to changes
//  - Only ONE polling timer exists (here), not scattered across views
//  - Posts .iconStyleDidChange notification for non-SwiftUI components (e.g., HelperAppDelegate)
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

/// Represents the macOS Tahoe icon style (System Settings → Appearance → Icon and widget style)
/// This is INDEPENDENT of the system appearance (Light/Dark mode)
enum IconStyle: String, CaseIterable, Sendable {
    case defaultStyle   // Default colorful icons (key not set)
    case dark           // Dark background with tint-colored symbols (RegularDark)
    case clear          // "Etched glass" look (value TBD)
    case tinted         // Wallpaper-tinted background (value TBD)

    /// The UserDefaults key for icon style
    static let userDefaultsKey = "AppleIconAppearanceTheme"

    /// Returns the current icon style from system preferences
    static var current: IconStyle {
        // Read from global UserDefaults using CFPreferences for reliability
        let value = CFPreferencesCopyAppValue(
            userDefaultsKey as CFString,
            kCFPreferencesAnyApplication
        ) as? String

        return from(preferencesValue: value)
    }

    /// Convert from UserDefaults value to IconStyle
    /// Known macOS Tahoe values (as of 2026-02):
    /// - nil or not set = Default (colorful)
    /// - "RegularAutomatic" = Automatic — follows system appearance (Dark → dark icons)
    /// - "RegularDark" = Dark (explicit)
    /// - "RegularLight" = Light/Default (explicit)
    /// - "ClearAutomatic" = Clear
    /// - "TintedAutomatic" = Tinted
    static func from(preferencesValue: String?) -> IconStyle {
        from(preferencesValue: preferencesValue, isDarkMode: systemAppearanceIsDark)
    }

    /// Pure mapping seam: resolves the `AppleIconAppearanceTheme` string to an `IconStyle` with
    /// the system appearance INJECTED, so the Automatic-follows-appearance behaviour (the Tahoe
    /// default, and the most regression-prone case) is unit-testable without CFPreferences.
    /// The argument-less `systemAppearanceIsDark` is read only at the call site above.
    static func from(preferencesValue: String?, isDarkMode: Bool) -> IconStyle {
        guard let value = preferencesValue else {
            return .defaultStyle // Key not set = Default
        }

        switch value {
        // Automatic: the "Regular" (non-clear/tinted) style that follows the system
        // appearance — dark icons in Dark mode, colourful default in Light mode.
        // This is the Tahoe default, so it MUST be handled or dark mode never applies.
        case "RegularAutomatic", "Automatic":
            return isDarkMode ? .dark : .defaultStyle
        // Dark style (explicit)
        case "RegularDark", "Dark":
            return .dark
        // Light/Default style (explicit)
        case "RegularLight", "Light":
            return .defaultStyle
        // Clear style (semi-transparent gray)
        case "ClearAutomatic", "Clear", "RegularClear":
            return .clear
        // Tinted style (wallpaper-derived colors)
        case "TintedAutomatic", "Tinted", "RegularTinted":
            return .tinted
        default:
            // Log unknown values for debugging - helps discover new values
            print("[IconStyleManager] Unknown AppleIconAppearanceTheme value: \(value)")
            return .defaultStyle
        }
    }

    /// Whether the system is currently in Dark appearance.
    /// Read via CFPreferences (mirrors how the icon-style value is read) so it works in
    /// the main app and helper processes without depending on a live `NSApplication`.
    static var systemAppearanceIsDark: Bool {
        let style = CFPreferencesCopyAppValue(
            "AppleInterfaceStyle" as CFString,
            kCFPreferencesAnyApplication
        ) as? String
        return style == "Dark"
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .defaultStyle: return "Default"
        case .dark: return "Dark"
        case .clear: return "Clear"
        case .tinted: return "Tinted"
        }
    }
}

/// Manages icon style observation and provides style-aware rendering utilities
///
/// USAGE IN SWIFTUI VIEWS:
/// ```swift
/// struct MyView: View {
///     @ObservedObject private var iconStyleManager = IconStyleManager.shared
///
///     var body: some View {
///         // Use iconStyleManager.currentStyle
///         // View automatically updates when style changes
///     }
/// }
/// ```
@MainActor
final class IconStyleManager: ObservableObject {

    static let shared = IconStyleManager()

    /// Current icon style - views observing this will automatically update
    @Published private(set) var currentStyle: IconStyle = .defaultStyle

    /// Distributed notification observers (for system notifications)
    private var distributedObservers: [any NSObjectProtocol] = []

    /// Single polling timer for the entire app (2-second interval is sufficient)
    private var pollTimer: Timer?

    private init() {
        // Initial state
        currentStyle = IconStyle.current
        print("[IconStyleManager] Initialized with style: \(currentStyle.rawValue)")

        setupObservers()
    }

    private func setupObservers() {
        // Observe distributed notifications that might indicate icon style changes
        // macOS Tahoe may use various notification names
        let notificationNames = [
            "AppleIconAppearanceThemeChangedNotification",
            "AppleInterfaceThemeChangedNotification",
            "com.apple.desktop.darkModeChanged"
        ]

        for name in notificationNames {
            let observer = DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                let notificationName = name
                Task { @MainActor in
                    print("[IconStyleManager] Received notification: \(notificationName)")
                    self?.checkAndUpdateStyle()
                }
            }
            distributedObservers.append(observer)
        }

        // Single polling timer as fallback (2 seconds is responsive enough)
        // This is the ONLY polling timer in the app for icon style
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndUpdateStyle()
            }
        }

        print("[IconStyleManager] Observers set up (1 poll timer, \(distributedObservers.count) notification observers)")
    }

    /// Check for style change and update if needed
    /// Called by both notifications and polling timer
    private func checkAndUpdateStyle() {
        let newStyle = IconStyle.current
        guard newStyle != currentStyle else { return }

        print("[IconStyleManager] Style changed: \(currentStyle.rawValue) → \(newStyle.rawValue)")
        currentStyle = newStyle

        // Post notification for non-SwiftUI components (HelperAppDelegate, etc.)
        NotificationCenter.default.post(name: .iconStyleDidChange, object: newStyle)
    }

    /// Clean up observers (called on app termination)
    func cleanup() {
        pollTimer?.invalidate()
        pollTimer = nil
        for observer in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        distributedObservers.removeAll()
        print("[IconStyleManager] Cleaned up observers")
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when icon style changes (for non-SwiftUI components)
    /// SwiftUI views should use @ObservedObject instead
    static let iconStyleDidChange = Notification.Name("IconStyleDidChange")
}

// MARK: - Icon Style Color Generation

extension TintColor {

    /// Dark-style glyph colours: SF-Symbol tiles render the tile's own tint as the *glyph*
    /// (lifted to this perceived-luminance floor) on a neutral near-black background — the
    /// HIG-native Tahoe Dark model. The floor is deliberately restrained (0.55, not a hotter
    /// 0.6+) so lifted glyphs read calm rather than punchy on the dark tile.
    static let darkGlyphLuminanceFloor: CGFloat = 0.55

    /// Neutral near-black background gradient for Dark-style SF-Symbol tiles (the pre-tint
    /// `#2C2C2E → #1C1C1E` values), so the tinted glyph reads against a monochrome surface.
    static let darkNeutralTopHex = "#2C2C2E"
    static let darkNeutralBottomHex = "#1C1C1E"

    /// Returns colors appropriate for the given icon style
    /// - Parameters:
    ///   - style: The icon style to generate colors for
    ///   - iconType: SF Symbol vs emoji — in Dark style the two diverge (a symbol becomes a
    ///     tinted glyph on neutral near-black; an emoji keeps the darkened-own-tint background
    ///     since it can't be recoloured).
    /// - Returns: A tuple of (background top, background bottom, foreground) colors
    ///
    /// NOTE: Clear and Tinted use GRAYSCALE colors (no user tint color).
    /// This follows Apple HIG - macOS applies system tinting on top of grayscale icons.
    func colors(for style: IconStyle, iconType: IconType = .sfSymbol) -> (backgroundTop: Color, backgroundBottom: Color, foreground: Color) {
        switch style {
        case .defaultStyle:
            // Default: colorful gradient background, white foreground
            return (colorTop, colorBottom, .white)

        case .dark:
            switch iconType {
            case .sfSymbol:
                // Dark + SF Symbol (HIG-native): flip the roles — the tile's picked colour
                // becomes the GLYPH, lifted on perceived luminance so even deep violet stays
                // visible, on a neutral near-black background.
                let bgTop = Color(hex: TintColor.darkNeutralTopHex)
                let bgBottom = Color(hex: TintColor.darkNeutralBottomHex)
                let glyph = colorBottom.liftedForDarkGlyph(minLuminance: TintColor.darkGlyphLuminanceFloor)
                return (bgTop, bgBottom, glyph)
            case .emoji:
                // Dark + emoji: keep the darkened-own-tint background (an emoji can't be
                // recoloured, so it keeps its full colour + contact shadow; foreground unused).
                let darkTop = colorTop.darkenedForDarkMode(maxBrightness: 0.22)
                let darkBottom = colorBottom.darkenedForDarkMode(maxBrightness: 0.13)
                return (darkTop, darkBottom, .white)
            }

        case .clear:
            // Clear: light gray background, dark gray symbol
            // NO user color - macOS applies system tinting
            let clearTop = Color(hex: "#F0F0F2")
            let clearBottom = Color(hex: "#E0E0E4")
            let clearForeground = Color(hex: "#6E6E73")  // Dark gray symbol
            return (clearTop, clearBottom, clearForeground)

        case .tinted:
            // Tinted: medium gray gradient, white/light symbol
            // NO user color - macOS applies wallpaper-derived tinting
            let tintedTop = Color(hex: "#8E8E93")
            let tintedBottom = Color(hex: "#636366")
            return (tintedTop, tintedBottom, .white)
        }
    }

    /// Returns NSColors appropriate for the given icon style (for IconGenerator)
    ///
    /// Kept in lock-step with `colors(for:iconType:)` — the SwiftUI preview must match the
    /// baked `.icns`, including the Dark-style split between SF Symbol and emoji.
    ///
    /// NOTE: Clear and Tinted use GRAYSCALE colors (no user tint color).
    /// This follows Apple HIG - macOS applies system tinting on top of grayscale icons.
    func nsColors(for style: IconStyle, iconType: IconType = .sfSymbol) -> (backgroundTop: NSColor, backgroundBottom: NSColor, foreground: NSColor) {
        switch style {
        case .defaultStyle:
            // Default: colorful gradient, white symbol
            return (nsColorTop, nsColorBottom, .white)

        case .dark:
            switch iconType {
            case .sfSymbol:
                // Dark + SF Symbol (HIG-native): tile's picked colour becomes the GLYPH, lifted
                // on perceived luminance (so deep violet stays visible), on neutral near-black.
                let bgTop = NSColor(hex: TintColor.darkNeutralTopHex) ?? NSColor(white: 0.17, alpha: 1)
                let bgBottom = NSColor(hex: TintColor.darkNeutralBottomHex) ?? NSColor(white: 0.11, alpha: 1)
                let glyph = nsColorBottom.liftedForDarkGlyph(minLuminance: TintColor.darkGlyphLuminanceFloor)
                return (bgTop, bgBottom, glyph)
            case .emoji:
                // Dark + emoji: darkened-own-tint background (emoji keeps its own colour; the
                // white foreground is unused by the emoji draw path).
                let darkTop = nsColorTop.darkenedForDarkMode(maxBrightness: 0.22)
                let darkBottom = nsColorBottom.darkenedForDarkMode(maxBrightness: 0.13)
                return (darkTop, darkBottom, .white)
            }

        case .clear:
            // Clear: light gray background, dark gray symbol
            // NO user color - macOS applies system tinting
            let clearTop = NSColor(red: 0.941, green: 0.941, blue: 0.949, alpha: 1.0)  // #F0F0F2
            let clearBottom = NSColor(red: 0.878, green: 0.878, blue: 0.894, alpha: 1.0)  // #E0E0E4
            let clearForeground = NSColor(red: 0.431, green: 0.431, blue: 0.451, alpha: 1.0)  // #6E6E73
            return (clearTop, clearBottom, clearForeground)

        case .tinted:
            // Tinted: medium gray gradient, white symbol
            // NO user color - macOS applies wallpaper-derived tinting
            let tintedTop = NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)  // #8E8E93
            let tintedBottom = NSColor(red: 0.388, green: 0.388, blue: 0.400, alpha: 1.0)  // #636366
            return (tintedTop, tintedBottom, .white)
        }
    }
}
