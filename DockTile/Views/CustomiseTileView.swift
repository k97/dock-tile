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
    @State private var showWeightInfo: Bool = false

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

            // Inspector Card — fills remaining vertical space
            inspectorCard
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NSColorBackgroundView.windowBackground)
        .navigationTitle(AppStrings.Navigation.customiseTile)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    DiagnosticsLog.shared.ui("Customise → Back to Tile Detail '\(editedConfig.name)'")
                    onBack()
                }) {
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
        // Per-control diagnostics. Colour and size change continuously (colour-panel drag /
        // stepper repeat) so they're verbose; icon selection is a discrete click.
        .onChange(of: editedConfig.tintColor) { _, newValue in
            DiagnosticsLog.shared.log("tile", "Colour changed for '\(editedConfig.name)' → \(newValue)", verbose: true)
        }
        .onChange(of: editedConfig.iconScale) { _, newValue in
            DiagnosticsLog.shared.log("tile", "Icon size changed to \(newValue) for '\(editedConfig.name)'", verbose: true)
        }
        .onChange(of: editedConfig.iconValue) { _, newValue in
            DiagnosticsLog.shared.log("tile", "Icon changed to \(editedConfig.iconType == .emoji ? "emoji" : "symbol") '\(newValue)' for '\(editedConfig.name)'")
        }
        .onChange(of: editedConfig.iconWeight) { _, newValue in
            DiagnosticsLog.shared.ui("Customise → Icon weight \(newValue.displayName) for '\(editedConfig.name)'")
        }
        .onChange(of: selectedIconTab) { _, newTab in
            DiagnosticsLog.shared.ui("Customise → Icon picker tab '\(newTab == .symbol ? "Symbol" : "Emoji")'")
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
                    iconWeight: editedConfig.iconWeight,
                    size: 100
                )

                // Apple icon guide grid overlay (adaptive color based on background)
                IconGridOverlay(
                    size: 100,
                    backgroundColor: editedConfig.tintColor
                )
            }

            // Tile name anchored below preview
            Text(editedConfig.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
        .padding(.top, 4) // Tight offset to clear the toolbar area
        .background(StudioCanvasBackgroundView().ignoresSafeArea(edges: .top))
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
        .background(NSColorBackgroundView.formGroup)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Colour Section

    private var colourSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(AppStrings.Label.colour)
                .font(.system(size: 13))
                .foregroundColor(.primary)

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

    /// Segmented picker with flexible button sizing (macOS 26+)
    @available(macOS 26.0, *)
    private var pickerWithFlexibleSizing: some View {
        Picker("", selection: $selectedIconTab) {
            Text(AppStrings.Tab.symbol).tag(IconPickerTab.symbol)
            Text(AppStrings.Tab.emoji).tag(IconPickerTab.emoji)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .buttonSizing(.flexible)
    }

    /// Segmented picker with standard sizing (macOS 15.0+)
    private var pickerWithStandardSizing: some View {
        Picker("", selection: $selectedIconTab) {
            Text(AppStrings.Tab.symbol).tag(IconPickerTab.symbol)
            Text(AppStrings.Tab.emoji).tag(IconPickerTab.emoji)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var segmentedPicker: some View {
        if #available(macOS 26.0, *) {
            pickerWithFlexibleSizing
        } else {
            pickerWithStandardSizing
        }
    }

    // MARK: - Tile Icon Size Section

    /// Maximum allowed scale value (keeps icon within its type's safe area)
    private var maxIconScale: Int {
        // Symbols step to 19 (clamped at IconDepthMetrics.maxSafeRatio, 0.60). Emoji step
        // to 22 under their own ceiling (emojiMaxSafeRatio, 0.78) — and because emoji are
        // ink-normalised (emojiInkFit), the ratio bounds the measured artwork, so every
        // emoji stays inside the safe area at every step.
        editedConfig.iconType == .emoji ? 22 : 19
    }

    /// Combined row: Icon Size stepper on the left, Icon Weight pull-down on the
    /// right, split by a vertical divider (matches the inspector design).
    private var tileIconSizeSection: some View {
        HStack(spacing: 12) {
            // Icon Size (left half)
            HStack(spacing: 8) {
                Text(AppStrings.Label.iconSize)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer(minLength: 8)

                Stepper(value: $editedConfig.iconScale, in: 10...maxIconScale) {
                    Text("\(editedConfig.iconScale)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 28)

            // Icon Weight (right half)
            HStack(spacing: 6) {
                Text(AppStrings.Label.iconWeight)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                iconWeightInfoButton

                Spacer(minLength: 8)

                iconWeightPicker
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 52)
    }

    /// Small info affordance next to the Icon Weight label. Click reveals a popover
    /// explaining the setting's scope (Apple's pattern for a note too minor for a
    /// persistent subtitle); hover shows the same text as a help tag for accessibility.
    private var iconWeightInfoButton: some View {
        Button {
            showWeightInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(AppStrings.Label.iconWeightInfo)
        .accessibilityLabel(AppStrings.Label.iconWeightInfoAccessibility)
        .popover(isPresented: $showWeightInfo, arrowEdge: .bottom) {
            Text(AppStrings.Label.iconWeightInfo)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 220, alignment: .leading)
                .padding(12)
        }
    }

    /// Native macOS pull-down (pop-up button) for choosing the SF Symbol weight.
    /// Stays enabled for emojis — the renderers simply ignore weight for emoji content.
    private var iconWeightPicker: some View {
        Picker("", selection: $editedConfig.iconWeight) {
            ForEach(IconWeight.allCases, id: \.self) { weight in
                Text(weight.displayName).tag(weight)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
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

            // Icon grid — fills remaining space in the inspector card
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
                            iconWeight: editedConfig.iconWeight,
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
            .frame(maxHeight: .infinity)
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

// MARK: - Native Background Views

// Studio Canvas background now lives in NativeBackgroundViews.swift as the shared
// `StudioCanvasBackgroundView`, reused by the Popover Appearance preview hero.

// WindowBackgroundView, ControlBackgroundView, FormGroupBackgroundView
// replaced by shared NSColorBackgroundView in NativeBackgroundViews.swift

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
