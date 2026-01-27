//
//  SymbolPickerButton.swift
//  DockTile
//
//  Symbol picker button that opens macOS Character Viewer
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct SymbolPickerButton: View {
    @Binding var symbol: String

    var body: some View {
        Button(action: openCharacterViewer) {
            HStack(spacing: 16) {
                // Current symbol display
                Text(symbol)
                    .font(.system(size: 32))

                Spacer()

                HStack(spacing: 8) {
                    Text("Emoji")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#F5F5F7"))
            )
        }
        .buttonStyle(.plain)
    }

    private func openCharacterViewer() {
        // Open macOS Character Viewer
        NSApp.orderFrontCharacterPalette(nil)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SymbolPickerButton(symbol: .constant("💻"))

        SymbolPickerButton(symbol: .constant("🎨"))

        SymbolPickerButton(symbol: .constant("⭐"))
    }
    .padding(24)
    .frame(width: 400)
    .background(Color.white)
}
