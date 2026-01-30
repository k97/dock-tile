//
//  IconGridOverlay.swift
//  DockTile
//
//  Apple-style icon design guide overlay with grid, circles, and diagonals
//  Based on macOS/iOS app icon template guidelines
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct IconGridOverlay: View {
    let size: CGFloat
    let lineColor: Color
    let lineWidth: CGFloat

    init(
        size: CGFloat,
        lineColor: Color = Color(hex: "#5DB3F9").opacity(0.6),
        lineWidth: CGFloat = 1
    ) {
        self.size = size
        self.lineColor = lineColor
        self.lineWidth = lineWidth
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
        // Outer circle: ~80% of half-width
        // Middle circle: ~50% of half-width
        // Inner circle: ~20% of half-width
        let radii: [CGFloat] = [
            rect.width * 0.40,  // Outer
            rect.width * 0.25,  // Middle
            rect.width * 0.10   // Inner
        ]

        var circlePath = Path()

        for radius in radii {
            circlePath.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }

        context.stroke(circlePath, with: .color(lineColor), lineWidth: lineWidth)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Show overlay on colored background
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

            IconGridOverlay(size: 160)
        }

        // Show overlay alone
        IconGridOverlay(size: 160, lineColor: .blue.opacity(0.5))
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
    .padding(60)
    .background(Color(NSColor.windowBackgroundColor))
}
