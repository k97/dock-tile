//
//  CustomiseTileView.swift
//  DockTile
//
//  Studio Canvas design for tile customization
//  Full-width preview header with unified scrolling inspector
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct CustomiseTileView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration
    let onBack: () -> Void

    @State private var editedConfig: DockTileConfiguration
    @State private var selectedIconTab: IconPickerTab = .symbol
    @State private var customColor: Color = .blue
    @State private var searchText: String = ""

    init(config: DockTileConfiguration, onBack: @escaping () -> Void) {
        self.config = config
        self.onBack = onBack
        self._editedConfig = State(initialValue: config)
        // Initialize selected tab based on current icon type
        self._selectedIconTab = State(initialValue: config.iconType == .sfSymbol ? .symbol : .emoji)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Studio Canvas - Full-width header area with vibrancy
            studioCanvas

            // Inspector Card
            inspectorCard
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowBackgroundView())
        .navigationTitle(AppStrings.Navigation.customiseTile)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label(AppStrings.Button.back, systemImage: "chevron.left")
                }
            }
        }
        .onChange(of: editedConfig) { oldValue, newValue in
            // Mark as edited immediately (enables + button)
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                configManager.markSelectedConfigAsEdited()
            }

            // Only save if the config actually changed (prevent infinite loop)
            if oldValue.id == newValue.id {
                Task {
                    // Wait 300ms before saving (debounce)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    configManager.updateConfiguration(newValue)
                }
            }
        }
    }

    // MARK: - Studio Canvas (Hero Section)

    private var studioCanvas: some View {
        VStack(spacing: 12) {
            // Icon preview with grid overlay
            ZStack {
                DockTileIconPreview(
                    tintColor: editedConfig.tintColor,
                    iconType: editedConfig.iconType,
                    iconValue: editedConfig.iconValue,
                    iconScale: editedConfig.iconScale,
                    size: 120
                )

                // Apple icon guide grid overlay (adaptive color based on background)
                IconGridOverlay(
                    size: 120,
                    backgroundColor: editedConfig.tintColor
                )
            }

            // Tile name anchored below preview
            Text(editedConfig.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.top, 28) // Extra padding to account for toolbar area
        .background(QuaternaryFillView().ignoresSafeArea(edges: .top))
    }

    // MARK: - Inspector Card

    private var inspectorCard: some View {
        VStack(spacing: 0) {
            // Colour Section
            colourSection

            // Separator (matches form group style)
            Rectangle()
                .fill(Color(nsColor: .quinaryLabel))
                .frame(height: 1)

            // Tile Icon Size Section (moved above Tile Icon)
            tileIconSizeSection

            // Separator
            Rectangle()
                .fill(Color(nsColor: .quinaryLabel))
                .frame(height: 1)

            // Tile Icon Section
            tileIconSection
        }
        .padding(.horizontal, 10)
        .background(FormGroupBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Colour Section

    private var colourSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Label.colour)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Text(AppStrings.Subtitle.chooseColour)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Colour picker strip (right-aligned)
            colourPickerStrip
        }
        .frame(height: 52)
    }

    private var colourPickerStrip: some View {
        HStack(spacing: 8) {
            // Preset colors
            ForEach(TintColor.PresetColor.allCases, id: \.self) { preset in
                ColorSwatchButton(
                    color: preset.colorBottom,
                    isSelected: isPresetSelected(preset),
                    size: 24
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        editedConfig.tintColor = .preset(preset)
                    }
                }
            }

            // Custom color picker styled as "+" button
            CustomColorPickerButton(
                selectedColor: $customColor,
                isSelected: isCustomColorSelected,
                size: 24
            ) { newColor in
                let hexString = newColor.toHexString()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    editedConfig.tintColor = .custom(hexString)
                }
            }
        }
    }

    private var isCustomColorSelected: Bool {
        if case .custom = editedConfig.tintColor {
            return true
        }
        return false
    }

    private func isPresetSelected(_ preset: TintColor.PresetColor) -> Bool {
        if case .preset(let currentPreset) = editedConfig.tintColor {
            return currentPreset == preset
        }
        return false
    }

    // MARK: - Segmented Picker

    @ViewBuilder
    private var segmentedPicker: some View {
        let picker = Picker("", selection: $selectedIconTab) {
            Text(AppStrings.Tab.symbol).tag(IconPickerTab.symbol)
            Text(AppStrings.Tab.emoji).tag(IconPickerTab.emoji)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)

        // macOS 26+ supports flexible button sizing for full-width segmented controls
        if #available(macOS 26.0, *) {
            picker.buttonSizing(.flexible)
        } else {
            picker
        }
    }

    // MARK: - Tile Icon Size Section

    /// Maximum allowed scale value based on icon type (keeps icon within safe area)
    private var maxIconScale: Int {
        // Emoji has +5% offset, so needs lower max to stay within safe area
        editedConfig.iconType == .emoji ? 16 : 17
    }

    private var tileIconSizeSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Label.tileIconSize)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Text(AppStrings.Subtitle.iconSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Stepper(value: $editedConfig.iconScale, in: 10...maxIconScale) {
                Text("\(editedConfig.iconScale)")
                    .monospacedDigit()
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .frame(height: 52)
    }

    // MARK: - Tile Icon Section

    private var tileIconSection: some View {
        VStack(spacing: 12) {
            Text(AppStrings.Label.tileIcon)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Segmented control for Symbol/Emoji - full width
            // Note: Switching tabs only changes the picker view, NOT the iconType
            // iconType only changes when user explicitly selects a new icon
            segmentedPicker

            // Search field - sticky (outside ScrollView)
            iconSearchField

            // Icon grid with fixed height and internal scrolling
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    switch selectedIconTab {
                    case .symbol:
                        SymbolPickerGrid(
                            selectedSymbol: Binding(
                                get: {
                                    // Only show selection if current icon is an SF Symbol
                                    editedConfig.iconType == .sfSymbol ? editedConfig.iconValue : ""
                                },
                                set: { newValue in
                                    editedConfig.iconType = .sfSymbol
                                    editedConfig.iconValue = newValue
                                    editedConfig.symbolEmoji = newValue  // Keep legacy field in sync
                                }
                            ),
                            searchText: $searchText,
                            onSelect: { symbol in
                                editedConfig.iconType = .sfSymbol
                                editedConfig.iconValue = symbol
                                editedConfig.symbolEmoji = symbol
                            }
                        )

                    case .emoji:
                        EmojiPickerGrid(
                            selectedEmoji: Binding(
                                get: {
                                    // Only show selection if current icon is an emoji
                                    editedConfig.iconType == .emoji ? editedConfig.iconValue : ""
                                },
                                set: { newValue in
                                    editedConfig.iconType = .emoji
                                    editedConfig.iconValue = newValue
                                    editedConfig.symbolEmoji = newValue  // Keep legacy field in sync
                                }
                            ),
                            searchText: $searchText,
                            onSelect: { emoji in
                                editedConfig.iconType = .emoji
                                editedConfig.iconValue = emoji
                                editedConfig.symbolEmoji = emoji
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 280)
        }
        .padding(.vertical, 12)
        .onChange(of: selectedIconTab) { _, _ in
            // Clear search when switching tabs
            searchText = ""
        }
    }

    // MARK: - Icon Search Field

    private var iconSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField(
                selectedIconTab == .symbol ? AppStrings.Search.symbols : AppStrings.Search.emojis,
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Icon Picker Tab

private enum IconPickerTab {
    case symbol
    case emoji
}

// MARK: - Native Background Views (AppKit Bridged)

/// Window background color using NSViewRepresentable
private struct WindowBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
}

/// Quaternary system fill for Studio Canvas - semi-transparent gray with vibrancy
private struct QuaternaryFillView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Control background color for inspector card
private struct ControlBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
}

/// Form group background using quaternarySystemFill (matches detail view form groups)
private struct FormGroupBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
    }
}

// MARK: - Color Swatch Button

private struct ColorSwatchButton: View {
    let color: Color
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: size - 4, height: size - 4)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Color Picker Button

private struct CustomColorPickerButton: View {
    @Binding var selectedColor: Color
    let isSelected: Bool
    let size: CGFloat
    let onColorChange: (Color) -> Void

    var body: some View {
        Button {
            openColorPanel()
        } label: {
            ZStack {
                // Background circle with rainbow gradient border
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .purple, .red
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: size, height: size)

                // Inner circle (white or selected color)
                Circle()
                    .fill(isSelected ? selectedColor : Color.white)
                    .frame(width: size - 6, height: size - 6)

                // Plus icon when not selected, checkmark when selected
                if !isSelected {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = NSColor(selectedColor)
        panel.setTarget(nil)
        panel.setAction(nil)

        // Use a delegate to capture color changes
        let delegate = ColorPanelDelegate(onColorChange: { nsColor in
            let newColor = Color(nsColor: nsColor)
            selectedColor = newColor
            onColorChange(newColor)
        })

        // Store delegate to keep it alive
        objc_setAssociatedObject(panel, &ColorPanelDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)

        panel.setTarget(delegate)
        panel.setAction(#selector(ColorPanelDelegate.colorChanged(_:)))
        panel.orderFront(nil)
    }
}

// MARK: - Color Panel Delegate

@MainActor
private class ColorPanelDelegate: NSObject {
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    let onColorChange: (NSColor) -> Void

    init(onColorChange: @escaping (NSColor) -> Void) {
        self.onColorChange = onColorChange
    }

    @objc func colorChanged(_ sender: NSColorPanel) {
        onColorChange(sender.color)
    }
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    func toHexString() -> String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return "#007AFF"  // Default to blue
        }

        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - Preview

#Preview {
    CustomiseTileView(
        config: DockTileConfiguration(
            name: "AI Tile",
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "sparkles"
        ),
        onBack: {}
    )
    .environmentObject(ConfigurationManager())
    .frame(width: 500, height: 700)
}
