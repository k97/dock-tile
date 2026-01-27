//
//  DockTileIconPreview.swift
//  DockTile
//
//  Icon preview component with gradient background and symbol
//  Supports multiple sizes: 80×80pt (Screen 3), 160×160pt (Screen 4)
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct DockTileIconPreview: View {
    let tintColor: TintColor
    let symbol: String
    let size: CGFloat

    private var cornerRadius: CGFloat {
        size * 0.225  // 18pt for 80pt, 36pt for 160pt
    }

    private var symbolSize: CGFloat {
        size * 0.4  // 32pt for 80pt, 64pt for 160pt
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

            // Symbol emoji
            Text(symbol)
                .font(.system(size: symbolSize))
        }
        .frame(width: size, height: size)
        .shadow(
            color: Color.black.opacity(0.2),
            radius: shadowRadius,
            x: 0,
            y: shadowOffset
        )
    }
}

// MARK: - Convenience Initializers

extension DockTileIconPreview {
    /// Create preview for Screen 3 (80×80pt)
    static func small(tintColor: TintColor, symbol: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, symbol: symbol, size: 80)
    }

    /// Create preview for Screen 4 (160×160pt)
    static func large(tintColor: TintColor, symbol: String) -> DockTileIconPreview {
        DockTileIconPreview(tintColor: tintColor, symbol: symbol, size: 160)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            DockTileIconPreview.small(tintColor: .blue, symbol: "💻")
            DockTileIconPreview.small(tintColor: .orange, symbol: "🎨")
            DockTileIconPreview.small(tintColor: .green, symbol: "📊")
        }

        HStack(spacing: 40) {
            DockTileIconPreview.large(tintColor: .purple, symbol: "🚀")
            DockTileIconPreview.large(tintColor: .red, symbol: "❤️")
        }

        DockTileIconPreview(tintColor: .none, symbol: "⭐", size: 120)
    }
    .padding(60)
    .background(Color(hex: "#F5F5F7"))
}
