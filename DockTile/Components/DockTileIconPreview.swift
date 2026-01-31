//
//  DockTileIconPreview.swift
//  DockTile
//
//  Icon preview component with gradient background and symbol/emoji
//  Supports SF Symbols and Emojis with multiple sizes
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct DockTileIconPreview: View {
    let tintColor: TintColor
    let iconType: IconType
    let iconValue: String
    let iconScale: Int  // 10-20 range, default 14
    let size: CGFloat

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

    private var shadowRadius: CGFloat {
        size * 0.075  // 6pt for 80pt, 12pt for 160pt
    }

    private var shadowOffset: CGFloat {
        size * 0.0375  // 3pt for 80pt, 6pt for 160pt
    }

    var body: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tintColor.colorTop, tintColor.colorBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Beveled glass effect (inner stroke)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)

            // Icon content (SF Symbol or Emoji)
            iconContent
        }
        .frame(width: size, height: size)
        .shadow(
            color: Color.black.opacity(0.2),
            radius: shadowRadius,
            x: 0,
            y: shadowOffset
        )
    }

    @ViewBuilder
    private var iconContent: some View {
        switch iconType {
        case .sfSymbol:
            Image(systemName: iconValue)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)

        case .emoji:
            Text(iconValue)
                .font(.system(size: symbolSize))
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

    /// Create preview with explicit icon type (small)
    static func small(tintColor: TintColor, iconType: IconType, iconValue: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, iconType: iconType, iconValue: iconValue, size: 80)
    }

    /// Create preview with explicit icon type (large)
    static func large(tintColor: TintColor, iconType: IconType, iconValue: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, iconType: iconType, iconValue: iconValue, size: 160)
    }

    /// Create preview from configuration
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

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // SF Symbols
        HStack(spacing: 40) {
            DockTileIconPreview(
                tintColor: .blue,
                iconType: .sfSymbol,
                iconValue: "sparkles",
                size: 80
            )
            DockTileIconPreview(
                tintColor: .purple,
                iconType: .sfSymbol,
                iconValue: "star.fill",
                size: 80
            )
            DockTileIconPreview(
                tintColor: .green,
                iconType: .sfSymbol,
                iconValue: "leaf.fill",
                size: 80
            )
        }

        // Emojis
        HStack(spacing: 40) {
            DockTileIconPreview.small(tintColor: .orange, symbol: "🎨")
            DockTileIconPreview.small(tintColor: .red, symbol: "❤️")
            DockTileIconPreview.small(tintColor: .gray, symbol: "⚙️")
        }

        // Large preview
        HStack(spacing: 40) {
            DockTileIconPreview.large(
                tintColor: .preset(.blue),
                iconType: .sfSymbol,
                iconValue: "sparkles"
            )
            DockTileIconPreview.large(tintColor: .pink, symbol: "🚀")
        }

        // Custom color
        DockTileIconPreview(
            tintColor: .custom("#FF5733"),
            iconType: .sfSymbol,
            iconValue: "flame.fill",
            size: 120
        )
    }
    .padding(60)
    .background(Color(hex: "#F5F5F7"))
}
