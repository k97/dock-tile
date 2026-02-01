//
//  DockTileIconPreview.swift
//  DockTile
//
//  Icon preview component with gradient background and symbol/emoji
//  Supports SF Symbols and Emojis with multiple sizes
//  Matches IconGenerator output exactly (no system effects like shadows)
//  Supports icon style-aware rendering (Default/Dark/Clear/Tinted)
//
//  Uses @ObservedObject with IconStyleManager for efficient updates
//  (single source of truth, no per-view polling)
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct DockTileIconPreview: View {
    let tintColor: TintColor
    let iconType: IconType
    let iconValue: String
    let iconScale: Int  // 10-20 range, default 14
    let size: CGFloat

    // Observe IconStyleManager for icon style changes (single source of truth)
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Current icon style from manager
    private var iconStyle: IconStyle {
        iconStyleManager.currentStyle
    }

    /// Whether we're in dark icon style
    private var isDarkStyle: Bool {
        iconStyle == .dark
    }

    // Legacy initializer for backward compatibility
    init(tintColor: TintColor, symbol: String, size: CGFloat) {
        self.tintColor = tintColor
        self.iconType = .emoji
        self.iconValue = symbol
        self.iconScale = ConfigurationDefaults.iconScale
        self.size = size
    }

    // New initializer with explicit icon type (legacy without scale)
    init(tintColor: TintColor, iconType: IconType, iconValue: String, size: CGFloat) {
        self.tintColor = tintColor
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconScale = ConfigurationDefaults.iconScale
        self.size = size
    }

    // Full initializer with icon scale
    init(tintColor: TintColor, iconType: IconType, iconValue: String, iconScale: Int, size: CGFloat) {
        self.tintColor = tintColor
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconScale = iconScale
        self.size = size
    }

    private var cornerRadius: CGFloat {
        size * 0.225  // 18pt for 80pt, 36pt for 160pt
    }

    private var symbolSize: CGFloat {
        // Base ratio: maps iconScale 10-20 to approximately 0.30-0.65
        let baseRatio = 0.30 + (CGFloat(iconScale - 10) * 0.035)

        // Emoji gets +5% offset for visual weight
        let ratio = iconType == .emoji ? baseRatio + 0.05 : baseRatio

        return size * ratio
    }

    /// Colors based on current icon style
    private var styleColors: (backgroundTop: Color, backgroundBottom: Color, foreground: Color) {
        tintColor.colors(for: iconStyle)
    }

    var body: some View {
        ZStack {
            // Gradient background with squircle shape (icon style-aware)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [styleColors.backgroundTop, styleColors.backgroundBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Beveled glass effect (inner stroke)
            // In dark style, use a subtler stroke
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    isDarkStyle
                        ? Color.white.opacity(0.2)
                        : Color.white.opacity(0.5),
                    lineWidth: 0.5
                )

            // Icon content (SF Symbol or Emoji)
            iconContent
        }
        .frame(width: size, height: size)
        // NOTE: No drop shadow here - the Dock adds shadows dynamically
        // This preview shows exactly what the icon file looks like
    }

    @ViewBuilder
    private var iconContent: some View {
        switch iconType {
        case .sfSymbol:
            // SF Symbol with icon style-aware color
            // Default: white symbol on colored gradient
            // Dark: tint-colored symbol on dark background
            Image(systemName: iconValue)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundColor(styleColors.foreground)
            // NOTE: No text shadow - native macOS icons don't have baked-in text shadows

        case .emoji:
            // Emojis: "Sticker on Glass" metaphor
            // Keep full color, add subtle shadow in dark style to lift off the surface
            Text(iconValue)
                .font(.system(size: symbolSize))
                .shadow(
                    color: isDarkStyle ? Color.black.opacity(0.3) : Color.clear,
                    radius: isDarkStyle ? 2 : 0,
                    y: isDarkStyle ? 1 : 0
                )
        }
    }
}

// MARK: - Convenience Initializers

extension DockTileIconPreview {
    /// Create preview for Screen 3 (80×80pt) - Legacy emoji support
    static func small(tintColor: TintColor, symbol: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, symbol: symbol, size: 80)
    }

    /// Create preview for Screen 4 (160×160pt) - Legacy emoji support
    static func large(tintColor: TintColor, symbol: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, symbol: symbol, size: 160)
    }

    /// Create preview for Screen 3 (80×80pt)
    static func small(tintColor: TintColor, iconType: IconType, iconValue: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, iconType: iconType, iconValue: iconValue, size: 80)
    }

    /// Create preview for Screen 4 (160×160pt)
    static func large(tintColor: TintColor, iconType: IconType, iconValue: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, iconType: iconType, iconValue: iconValue, size: 160)
    }

    /// Create from a full configuration
    static func fromConfig(_ config: DockTileConfiguration, size: CGFloat) -> DockTileIconPreview {
        DockTileIconPreview(
            tintColor: config.tintColor,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            size: size
        )
    }
}

// MARK: - Previews

#Preview("Default Style") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            DockTileIconPreview(
                tintColor: .blue,
                iconType: .sfSymbol,
                iconValue: "star.fill",
                iconScale: 14,
                size: 80
            )
            DockTileIconPreview(
                tintColor: .orange,
                iconType: .sfSymbol,
                iconValue: "folder.fill",
                iconScale: 14,
                size: 80
            )
            DockTileIconPreview(
                tintColor: .purple,
                iconType: .emoji,
                iconValue: "🚀",
                iconScale: 14,
                size: 80
            )
        }

        HStack(spacing: 20) {
            DockTileIconPreview.small(tintColor: .orange, symbol: "🎨")
            DockTileIconPreview.small(tintColor: .red, symbol: "❤️")
            DockTileIconPreview.small(tintColor: .gray, symbol: "⚙️")
        }

        HStack(spacing: 20) {
            DockTileIconPreview.large(
                tintColor: .green,
                iconType: .sfSymbol,
                iconValue: "leaf.fill"
            )
            DockTileIconPreview.large(tintColor: .pink, symbol: "🚀")
        }

        DockTileIconPreview(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 18,
            size: 160
        )
    }
    .padding(60)
    .background(Color(hex: "#F5F5F7"))
}

#Preview("Dark Style Simulation") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            DockTileIconPreview(
                tintColor: .blue,
                iconType: .sfSymbol,
                iconValue: "star.fill",
                iconScale: 14,
                size: 80
            )
            DockTileIconPreview(
                tintColor: .orange,
                iconType: .sfSymbol,
                iconValue: "folder.fill",
                iconScale: 14,
                size: 80
            )
            DockTileIconPreview(
                tintColor: .purple,
                iconType: .emoji,
                iconValue: "🚀",
                iconScale: 14,
                size: 80
            )
        }

        HStack(spacing: 20) {
            DockTileIconPreview.small(tintColor: .orange, symbol: "🎨")
            DockTileIconPreview.small(tintColor: .red, symbol: "❤️")
            DockTileIconPreview.small(tintColor: .gray, symbol: "⚙️")
        }

        HStack(spacing: 20) {
            DockTileIconPreview.large(
                tintColor: .green,
                iconType: .sfSymbol,
                iconValue: "leaf.fill"
            )
            DockTileIconPreview.large(tintColor: .pink, symbol: "🚀")
        }
    }
    .padding(60)
    .background(Color(hex: "#1C1C1E"))
    .preferredColorScheme(.dark)
}
