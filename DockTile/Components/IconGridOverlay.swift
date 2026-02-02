//
//  IconGridOverlay.swift
//  DockTile
//
//  Apple-style icon design guide overlay with grid, circles, and diagonals
//  Based on macOS/iOS app icon template guidelines
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct IconGridOverlay: View {
    let size: CGFloat
    let backgroundColor: TintColor?  // Optional: for adaptive color based on luminance
    let lineWidth: CGFloat
    let showSafeAreaWarning: Bool  // When true, outer circle shows in warning color

    /// Fixed line color (legacy initializer)
    init(
        size: CGFloat,
        lineColor: Color = Color(hex: "#5DB3F9").opacity(0.6),
        lineWidth: CGFloat = 1,
        showSafeAreaWarning: Bool = false
    ) {
        self.size = size
        self.backgroundColor = nil
        self.lineWidth = lineWidth
        self._fixedLineColor = lineColor
        self.showSafeAreaWarning = showSafeAreaWarning
    }

    /// Adaptive line color based on background luminance
    init(
        size: CGFloat,
        backgroundColor: TintColor,
        lineWidth: CGFloat = 1,
        showSafeAreaWarning: Bool = false
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.lineWidth = lineWidth
        self._fixedLineColor = nil
        self.showSafeAreaWarning = showSafeAreaWarning
    }

    // Store fixed color for legacy initializer
    private let _fixedLineColor: Color?

    private var lineColor: Color {
        // If fixed color provided (legacy), use it
        if let fixed = _fixedLineColor {
            return fixed
        }

        // Calculate adaptive color based on background luminance
        guard let bgColor = backgroundColor else {
            return Color(hex: "#5DB3F9").opacity(0.6)  // Default blue
        }

        let luminance = bgColor.colorBottom.luminance
        // Light backgrounds (yellow, etc.): darker overlay
        // Dark backgrounds (blue, purple): lighter overlay
        if luminance > 0.5 {
            return Color.black.opacity(0.25)
        } else {
            return Color.white.opacity(0.35)
        }
    }

    /// Warning color for outer circle when icon is at safe area limit
    private var warningColor: Color {
        Color.orange.opacity(0.8)
    }

    private var cornerRadius: CGFloat {
        size * 0.225  // Match icon corner radius
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)

            // Create clipping path for rounded rectangle
            let clipPath = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
            context.clip(to: clipPath)

            // Draw 8x8 grid lines
            drawGridLines(context: &context, rect: rect)

            // Draw diagonal lines (X pattern)
            drawDiagonals(context: &context, rect: rect)

            // Draw concentric circles
            drawConcentricCircles(context: &context, rect: rect)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    // MARK: - Grid Lines

    private func drawGridLines(context: inout GraphicsContext, rect: CGRect) {
        let gridCount = 8
        let spacing = rect.width / CGFloat(gridCount)

        var gridPath = Path()

        // Vertical lines
        for i in 1..<gridCount {
            let x = spacing * CGFloat(i)
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: rect.height))
        }

        // Horizontal lines
        for i in 1..<gridCount {
            let y = spacing * CGFloat(i)
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: rect.width, y: y))
        }

        context.stroke(gridPath, with: .color(lineColor), lineWidth: lineWidth)
    }

    // MARK: - Diagonal Lines

    private func drawDiagonals(context: inout GraphicsContext, rect: CGRect) {
        var diagonalPath = Path()

        // Top-left to bottom-right
        diagonalPath.move(to: CGPoint(x: 0, y: 0))
        diagonalPath.addLine(to: CGPoint(x: rect.width, y: rect.height))

        // Top-right to bottom-left
        diagonalPath.move(to: CGPoint(x: rect.width, y: 0))
        diagonalPath.addLine(to: CGPoint(x: 0, y: rect.height))

        context.stroke(diagonalPath, with: .color(lineColor), lineWidth: lineWidth)
    }

    // MARK: - Concentric Circles

    private func drawConcentricCircles(context: inout GraphicsContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Three circles at different radii (based on Apple's template)
        // Outer circle: ~80% of half-width (this is the safe area boundary)
        // Middle circle: ~50% of half-width
        // Inner circle: ~20% of half-width
        let outerRadius = rect.width * 0.40  // Outer (safe area boundary)
        let innerRadii: [CGFloat] = [
            rect.width * 0.25,  // Middle
            rect.width * 0.10   // Inner
        ]

        // Draw inner circles with normal line color
        var innerPath = Path()
        for radius in innerRadii {
            innerPath.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        context.stroke(innerPath, with: .color(lineColor), lineWidth: lineWidth)

        // Draw outer circle - use warning color if at safe area limit
        var outerPath = Path()
        outerPath.addEllipse(in: CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))

        let outerColor = showSafeAreaWarning ? warningColor : lineColor
        let outerLineWidth = showSafeAreaWarning ? lineWidth * 2 : lineWidth
        context.stroke(outerPath, with: .color(outerColor), lineWidth: outerLineWidth)
    }
}

// MARK: - Color Luminance Extension

extension Color {
    /// Calculate perceived luminance using standard formula
    /// Returns 0.0 (dark) to 1.0 (light)
    var luminance: CGFloat {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return 0.5 }
        // Standard luminance formula: 0.299R + 0.587G + 0.114B
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Show adaptive overlay on dark background (blue)
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4DABF7"), Color(hex: "#007AFF")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 160, height: 160)

            Text("✨")
                .font(.system(size: 64))

            IconGridOverlay(size: 160, backgroundColor: .blue)
        }

        // Show adaptive overlay on light background (yellow)
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD93D"), Color(hex: "#FFCC00")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 160, height: 160)

            Text("⭐")
                .font(.system(size: 64))

            IconGridOverlay(size: 160, backgroundColor: .yellow)
        }
    }
    .padding(60)
    .background(Color(NSColor.windowBackgroundColor))
}
