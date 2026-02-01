import SwiftUI
import AppKit
import Combine

/// Represents the system appearance mode for icon rendering
enum AppearanceMode: String, CaseIterable, Sendable {
    case light       // Default light appearance
    case dark        // Dark mode appearance
    // Future: clear, tinted (requires discovering UserDefaults keys)

    /// Returns the current system appearance mode (must be called on MainActor)
    @MainActor
    static var current: AppearanceMode {
        let appearance = NSApp.effectiveAppearance
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return .dark
        }
        return .light
    }

    /// Convert from SwiftUI ColorScheme
    static func from(colorScheme: ColorScheme) -> AppearanceMode {
        colorScheme == .dark ? .dark : .light
    }
}

/// Manages system appearance observation and provides appearance-aware rendering utilities
@MainActor
final class AppearanceManager: ObservableObject {

    static let shared = AppearanceManager()

    /// Current system appearance mode
    @Published private(set) var currentMode: AppearanceMode = .light

    /// Whether the system is in dark mode
    var isDarkMode: Bool { currentMode == .dark }

    private var appearanceObserver: NSKeyValueObservation?
    private var distributedNotificationObserver: (any NSObjectProtocol)?

    private init() {
        // Initial state
        currentMode = AppearanceMode.current
        print("[AppearanceManager] Initialized with mode: \(currentMode.rawValue)")

        // Observe NSApp.effectiveAppearance via KVO
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateAppearanceMode()
            }
        }

        // Also observe the distributed notification for appearance changes
        // This catches cases where KVO might miss changes
        distributedNotificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAppearanceMode()
            }
        }
    }

    /// Clean up observers when the manager is deallocated
    func cleanup() {
        appearanceObserver?.invalidate()
        appearanceObserver = nil
        if let observer = distributedNotificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            distributedNotificationObserver = nil
        }
    }

    private func updateAppearanceMode() {
        let newMode = AppearanceMode.current
        print("[AppearanceManager] Checking appearance - current: \(currentMode.rawValue), new: \(newMode.rawValue)")
        if newMode != currentMode {
            print("[AppearanceManager] Mode changed to: \(newMode.rawValue)")
            currentMode = newMode
            // Post notification for components that don't use @ObservedObject
            NotificationCenter.default.post(name: .appearanceModeDidChange, object: newMode)
        }
    }

    /// Update mode from SwiftUI's colorScheme (for views that have access to Environment)
    func updateFromColorScheme(_ colorScheme: ColorScheme) {
        let newMode = AppearanceMode.from(colorScheme: colorScheme)
        if newMode != currentMode {
            print("[AppearanceManager] Mode updated from colorScheme: \(newMode.rawValue)")
            currentMode = newMode
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let appearanceModeDidChange = Notification.Name("AppearanceModeDidChange")
}

// MARK: - Appearance-Aware Color Generation

extension TintColor {

    /// Returns colors appropriate for the given appearance mode
    /// - Parameter mode: The appearance mode to generate colors for
    /// - Returns: A tuple of (background top, background bottom, foreground) colors
    func colors(for mode: AppearanceMode) -> (backgroundTop: Color, backgroundBottom: Color, foreground: Color) {
        switch mode {
        case .light:
            // Default behavior: gradient background, white foreground
            return (colorTop, colorBottom, .white)

        case .dark:
            // Dark mode: dark background, tint-colored foreground
            let darkTop = Color(hex: "#2C2C2E")  // System dark gray
            let darkBottom = Color(hex: "#1C1C1E")  // Deeper dark
            return (darkTop, darkBottom, color)
        }
    }

    /// Returns NSColors appropriate for the given appearance mode (for IconGenerator)
    /// - Parameter mode: The appearance mode to generate colors for
    /// - Returns: A tuple of (background top, background bottom, foreground) NSColors
    func nsColors(for mode: AppearanceMode) -> (backgroundTop: NSColor, backgroundBottom: NSColor, foreground: NSColor) {
        switch mode {
        case .light:
            return (nsColorTop, nsColorBottom, .white)

        case .dark:
            let darkTop = NSColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1.0)  // #2C2C2E
            let darkBottom = NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0)  // #1C1C1E
            return (darkTop, darkBottom, nsColor)
        }
    }

    // MARK: - NSColor Accessors

    /// The top gradient color as NSColor
    var nsColorTop: NSColor {
        switch self {
        case .preset(_):
            return NSColor(colorTop)
        case .custom(let hex):
            if let color = NSColor(hex: hex) {
                return color.withAlphaComponent(0.8)
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

// MARK: - NSColor Hex Initializer

extension NSColor {
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
