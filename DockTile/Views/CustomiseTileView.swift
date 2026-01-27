//
//  CustomiseTileView.swift
//  DockTile
//
//  Screen 4: Customise Tile drill-down view with color and symbol pickers
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct CustomiseTileView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration
    let onBack: () -> Void

    @State private var editedConfig: DockTileConfiguration

    init(config: DockTileConfiguration, onBack: @escaping () -> Void) {
        self.config = config
        self.onBack = onBack
        self._editedConfig = State(initialValue: config)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            headerView

            Divider()

            // Main content
            ScrollView {
                VStack(spacing: 32) {
                    // Large icon preview (160×160pt)
                    DockTileIconPreview.large(
                        tintColor: editedConfig.tintColor,
                        symbol: editedConfig.symbolEmoji
                    )
                    .padding(.top, 32)

                    // Name (read-only)
                    Text(editedConfig.name)
                        .font(.title3)
                        .fontWeight(.medium)

                    Divider()
                        .padding(.horizontal, 24)

                    // Colour section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("COLOUR")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ColourPickerGrid(
                            selectedColor: $editedConfig.tintColor
                        )
                    }
                    .padding(.horizontal, 24)

                    // Symbol section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SYMBOL")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SymbolPickerButton(
                            symbol: $editedConfig.symbolEmoji
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onChange(of: editedConfig) { _, newValue in
            configManager.updateConfiguration(newValue)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 14))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Customise Tile")
                .font(.headline)

            Spacer()

            // Balance layout with invisible back button
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back")
                    .font(.system(size: 14))
            }
            .opacity(0)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CustomiseTileView(
        config: DockTileConfiguration(name: "Dev", tintColor: .blue, symbolEmoji: "💻"),
        onBack: {}
    )
    .environmentObject(ConfigurationManager())
    .frame(width: 760, height: 700)
}
