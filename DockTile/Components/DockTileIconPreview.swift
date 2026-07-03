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
    let iconWeight: IconWeight  // SF Symbol stroke weight (ignored for emojis)
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
        self.iconWeight = ConfigurationDefaults.iconWeight
        self.size = size
    }

    // New initializer with explicit icon type (legacy without scale)
    init(tintColor: TintColor, iconType: IconType, iconValue: String, size: CGFloat) {
        self.tintColor = tintColor
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconScale = ConfigurationDefaults.iconScale
        self.iconWeight = ConfigurationDefaults.iconWeight
        self.size = size
    }

    // Full initializer with icon scale and weight
    init(
        tintColor: TintColor,
        iconType: IconType,
        iconValue: String,
        iconScale: Int,
        iconWeight: IconWeight = ConfigurationDefaults.iconWeight,
        size: CGFloat
    ) {
        self.tintColor = tintColor
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconScale = iconScale
        self.iconWeight = iconWeight
        self.size = size
    }

    private var cornerRadius: CGFloat {
        size * 0.225  // 18pt for 80pt, 36pt for 160pt
    }

    private var symbolSize: CGFloat {
        // Shared seam handles the brand curve + SF-Symbol safe-area cap, so the preview and
        // the baked .icns pick identical glyph sizes (the inline copy here used to omit the cap).
        size * IconDepthMetrics.glyphSizeRatio(iconScale: iconScale, iconType: iconType, iconValue: iconValue)
    }

    /// Colors based on current icon style. Threads `iconType` so Dark style splits the same way
    /// the baked `.icns` does: SF Symbol → tinted glyph on neutral near-black; emoji → darkened
    /// own-tint (tint-coloured symbol on dark background).
    private var styleColors: (backgroundTop: Color, backgroundBottom: Color, foreground: Color) {
        tintColor.colors(for: iconStyle, iconType: iconType)
    }

    // MARK: Depth treatment (mirrors IconGenerator via the shared seam)

    private var glyphShadow: IconDepthMetrics.GlyphShadow? {
        IconDepthMetrics.glyphShadow(style: iconStyle, iconType: iconType, nominalSize: size)
    }

    private var glyphBottomDarken: CGFloat? {
        IconDepthMetrics.glyphBottomDarken(style: iconStyle, iconType: iconType, nominalSize: size)
    }

    private var surfaceSheenAlpha: CGFloat {
        IconDepthMetrics.surfaceSheenAlpha(style: iconStyle, nominalSize: size)
    }

    /// Liquid-Glass specular sheen for SF Symbols / brand glyph (nil for emoji / too small).
    private var glyphSheen: IconDepthMetrics.GlyphSheen? {
        IconDepthMetrics.glyphSheen(style: iconStyle, iconType: iconType, nominalSize: size)
    }

    /// Top→bottom shading fill for SF Symbols / brand glyph; flat foreground when suppressed.
    private var glyphForeground: AnyShapeStyle {
        if let darken = glyphBottomDarken {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [styleColors.foreground, styleColors.foreground.darkened(by: darken)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(styleColors.foreground)
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

            // Beveled glass effect (inner stroke) — opacity + width from the shared seam.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(IconDepthMetrics.strokeOpacity(style: iconStyle)),
                    lineWidth: IconDepthMetrics.strokeLineWidth(nominalSize: size)
                )

            // Liquid-Glass surface sheen: soft top specular gloss, clipped to the squircle.
            if surfaceSheenAlpha > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(surfaceSheenAlpha), location: 0),
                                .init(color: .clear, location: IconDepthMetrics.surfaceSheenHeightFraction)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Icon content (SF Symbol or Emoji)
            iconContent
        }
        .frame(width: size, height: size)
        // NOTE: No outer drop shadow — the Dock adds that. The glyph's contact shadow below is
        // an inner lift effect (mirrors the baked .icns), not the tile's system shadow.
    }

    /// The bare glyph (brand image or SF Symbol) at the current size, filled with `style`.
    /// Reused for both the visible fill and as the mask for the specular sheen so the two
    /// can't diverge.
    @ViewBuilder
    private func glyphShape<S: ShapeStyle>(_ style: S) -> some View {
        if iconValue == SFSymbolCatalog.brandSymbolName, let logo = SFSymbolCatalog.brandGlyph {
            // The DockTile brand logo is a bundled template image, not a system symbol.
            Image(nsImage: logo)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: symbolSize, height: symbolSize)
                .foregroundStyle(style)
        } else {
            Image(systemName: iconValue)
                .font(.system(size: symbolSize, weight: iconWeight.fontWeight))
                .foregroundStyle(style)
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch iconType {
        case .sfSymbol:
            // SF Symbol with icon style-aware fill + soft contact shadow (raised-on-glass),
            // topped by a Liquid-Glass specular sheen clipped to the glyph shape.
            glyphShape(glyphForeground)
                .overlay {
                    if let sheen = glyphSheen {
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(sheen.alpha), location: 0),
                                .init(color: .clear, location: sheen.heightFraction)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        // Mask the gloss to the glyph's own shape (colour is irrelevant to a mask).
                        .mask(glyphShape(Color.white))
                    }
                }
                .shadow(
                    color: glyphShadow.map { Color.black.opacity($0.blackAlpha) } ?? .clear,
                    radius: glyphShadow?.blur ?? 0,
                    y: glyphShadow?.offset ?? 0
                )

        case .emoji:
            // Emojis: "Sticker on Glass" metaphor — full colour + a subtle contact shadow in
            // every style (seam-driven), topped by a gentle glossy-sticker specular sheen.
            Text(iconValue)
                .font(.system(size: symbolSize))
                .overlay {
                    if let sheen = glyphSheen {
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(sheen.alpha), location: 0),
                                .init(color: .clear, location: sheen.heightFraction)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        // Mask the gloss to the emoji's silhouette (its rendered alpha).
                        .mask(Text(iconValue).font(.system(size: symbolSize)))
                    }
                }
                .shadow(
                    color: glyphShadow.map { Color.black.opacity($0.blackAlpha) } ?? .clear,
                    radius: glyphShadow?.blur ?? 0,
                    y: glyphShadow?.offset ?? 0
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
            iconWeight: config.iconWeight,
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
