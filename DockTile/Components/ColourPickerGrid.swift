//
//  ColourPickerGrid.swift
//  DockTile
//
//  Color picker grid with 8 preset color options
//  Legacy component - CustomiseTileView now uses inline color strip
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct ColourPickerGrid: View {
    @Binding var selectedColor: TintColor

    private let circleSize: CGFloat = 56
    private let selectedSize: CGFloat = 68  // Outer glow size
    private let spacing: CGFloat = 16

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ],
            spacing: spacing
        ) {
            ForEach(TintColor.allPresets, id: \.self) { color in
                ColorCircle(
                    color: color,
                    isSelected: selectedColor == color,
                    circleSize: circleSize,
                    selectedSize: selectedSize
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedColor = color
                    }
                }
            }
        }
    }
}

// MARK: - Color Circle

struct ColorCircle: View {
    let color: TintColor
    let isSelected: Bool
    let circleSize: CGFloat
    let selectedSize: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Selected indicator (outer glow)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: selectedSize, height: selectedSize)
                        .shadow(color: color.color.opacity(0.3), radius: 8, x: 0, y: 0)
                }

                // Color circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.colorTop, color.colorBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )

                // Checkmark for selected state
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: selectedSize, height: selectedSize)
        .contentShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        ColourPickerGrid(selectedColor: .constant(.blue))
            .padding()

        ColourPickerGrid(selectedColor: .constant(.gray))
            .padding()
    }
    .frame(width: 400)
    .background(Color(hex: "#F5F5F7"))
}
