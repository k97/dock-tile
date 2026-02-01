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
    /// - "RegularDark" = Dark
    /// - "ClearAutomatic" = Clear
    /// - "TintedAutomatic" = Tinted
    static func from(preferencesValue: String?) -> IconStyle {
        guard let value = preferencesValue else {
            return .defaultStyle // Key not set = Default
        }

        switch value {
        // Dark style
        case "RegularDark", "Dark":
            return .dark
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

    /// Returns colors appropriate for the given icon style
    /// - Parameter style: The icon style to generate colors for
    /// - Returns: A tuple of (background top, background bottom, foreground) colors
    ///
    /// NOTE: Clear and Tinted use GRAYSCALE colors (no user tint color).
    /// This follows Apple HIG - macOS applies system tinting on top of grayscale icons.
    func colors(for style: IconStyle) -> (backgroundTop: Color, backgroundBottom: Color, foreground: Color) {
        switch style {
        case .defaultStyle:
            // Default: colorful gradient background, white foreground
            return (colorTop, colorBottom, .white)

        case .dark:
            // Dark: dark gray background, tint-colored foreground
            let darkTop = Color(hex: "#2C2C2E")  // System dark gray
            let darkBottom = Color(hex: "#1C1C1E")  // Deeper dark
            return (darkTop, darkBottom, color)

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
    /// NOTE: Clear and Tinted use GRAYSCALE colors (no user tint color).
    /// This follows Apple HIG - macOS applies system tinting on top of grayscale icons.
    func nsColors(for style: IconStyle) -> (backgroundTop: NSColor, backgroundBottom: NSColor, foreground: NSColor) {
        switch style {
        case .defaultStyle:
            // Default: colorful gradient, white symbol
            return (nsColorTop, nsColorBottom, .white)

        case .dark:
            // Dark: dark gray background, tint-colored symbol
            let darkTop = NSColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1.0)  // #2C2C2E
            let darkBottom = NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0)  // #1C1C1E
            return (darkTop, darkBottom, nsColor)

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
