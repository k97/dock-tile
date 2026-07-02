//
//  DockTileSidebarView.swift
//  DockTile
//
//  Sidebar with list of dock tile configurations
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct DockTileSidebarView: View {
    @EnvironmentObject private var configManager: ConfigurationManager

    /// Drives the whole detail column (tiles + inline Settings). Owned by the parent so the
    /// detail pane and the sidebar stay in lock-step. See `SidebarSelection`.
    @Binding var selection: SidebarSelection?

    /// Invoked when the toolbar + is pressed. The parent decides whether to show the Smart Add
    /// sheet (if the engine has suggestions) or fall through to a blank tile — see
    /// `DockTileConfigurationView`. Kept as a closure so the sheet stays hosted in the parent.
    var onAdd: () -> Void

    /// Accordion expand/collapse state, persisted so it survives relaunch (Apple Notes-style).
    @AppStorage("sidebar.tilesExpanded") private var tilesExpanded = true
    @AppStorage("sidebar.settingsExpanded") private var settingsExpanded = true

    var body: some View {
        List(selection: $selection) {
            // Tiles — collapsible accordion section with an always-visible disclosure triangle.
            Section(AppStrings.Sidebar.tilesSection, isExpanded: $tilesExpanded) {
                if configManager.configurations.isEmpty {
                    // Tappable so the user can return to the empty-state detail after visiting a
                    // Settings pane (with zero tiles there's no tile row to select otherwise).
                    Text(AppStrings.Empty.noTiles)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .tag(SidebarSelection.tilesPlaceholder)
                } else {
                    ForEach(configManager.configurations) { config in
                        ConfigurationRow(config: config)
                            .tag(SidebarSelection.tile(config.id))
                            .contextMenu {
                                ConfigurationContextMenu(config: config)
                            }
                    }
                }
            }

            // Settings — inline panes that replace the old detached ⌘, window.
            Section(AppStrings.Sidebar.settingsSection, isExpanded: $settingsExpanded) {
                SettingsRow(
                    title: AppStrings.Settings.general,
                    systemName: "gearshape.fill",
                    tint: .gray
                )
                .tag(SidebarSelection.settings(.general))

                SettingsRow(
                    title: AppStrings.Settings.dockLock,
                    systemName: "lock.display",
                    tint: .blue
                )
                .tag(SidebarSelection.settings(.dockLock))
            }
        }
        // `.sidebar` style gives the collapsible "Show/Hide" section headers (the Apple
        // Notes-style accordion) and the tile-row selection highlight.
        .listStyle(.sidebar)
        .navigationTitle(AppStrings.Sidebar.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addTileButton")
                .disabled(!configManager.canCreateNewTile)
                .help(configManager.canCreateNewTile
                    ? AppStrings.Tooltip.createNewTile
                    : AppStrings.Tooltip.editFirst)
            }
        }
    }
}

// MARK: - Settings Row

/// A sidebar row for an inline Settings pane. Mirrors `ConfigurationRow`'s layout (24pt squircle
/// badge + 13pt label) so Settings entries sit visually flush with the tiles above them.
struct SettingsRow: View {
    let title: String
    let systemName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            SettingsBadgeIcon(systemName: systemName, tint: tint)

            Text(title)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

/// A squircle badge matching the tile icon look (`DockTileIconPreview`): continuous rounded
/// rect, top-to-bottom gradient, white SF Symbol, subtle inner glass stroke, and the same
/// Liquid-Glass depth (top sheen + glyph contact shadow) as the tiles. Settings badges always
/// render in the colourful Default style, so the depth seam is read with `.defaultStyle`.
struct SettingsBadgeIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 24

    private var cornerRadius: CGFloat { size * 0.225 }

    private var glyphShadow: IconDepthMetrics.GlyphShadow? {
        IconDepthMetrics.glyphShadow(style: .defaultStyle, iconType: .sfSymbol, nominalSize: size)
    }

    private var glyphForeground: AnyShapeStyle {
        if let darken = IconDepthMetrics.glyphBottomDarken(style: .defaultStyle, iconType: .sfSymbol, nominalSize: size) {
            return AnyShapeStyle(
                LinearGradient(colors: [.white, Color.white.darkened(by: darken)], startPoint: .top, endPoint: .bottom)
            )
        }
        return AnyShapeStyle(Color.white)
    }

    var body: some View {
        let sheenAlpha = IconDepthMetrics.surfaceSheenAlpha(style: .defaultStyle, nominalSize: size)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(IconDepthMetrics.strokeOpacity(style: .defaultStyle)),
                    lineWidth: IconDepthMetrics.strokeLineWidth(nominalSize: size)
                )

            if sheenAlpha > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(sheenAlpha), location: 0),
                                .init(color: .clear, location: IconDepthMetrics.surfaceSheenHeightFraction)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(glyphForeground)
                .shadow(
                    color: glyphShadow.map { Color.black.opacity($0.blackAlpha) } ?? .clear,
                    radius: glyphShadow?.blur ?? 0,
                    y: glyphShadow?.offset ?? 0
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Configuration Row

struct ConfigurationRow: View {
    let config: DockTileConfiguration

    var body: some View {
        HStack(spacing: 12) {
            // Mini icon preview (24×24pt) - uses same component as other previews
            DockTileIconPreview.fromConfig(config, size: 24)

            Text(config.name)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Context Menu

struct ConfigurationContextMenu: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration

    var body: some View {
        Button(AppStrings.Button.duplicate) {
            DiagnosticsLog.shared.ui("Sidebar context menu → Duplicate '\(config.name)'")
            configManager.duplicateConfiguration(config)
        }

        Divider()

        Button(AppStrings.Button.delete, role: .destructive) {
            DiagnosticsLog.shared.ui("Sidebar context menu → Delete '\(config.name)'")
            configManager.deleteConfiguration(config.id)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationSplitView {
        DockTileSidebarView(selection: .constant(nil), onAdd: {})
            .environmentObject({
                let manager = ConfigurationManager()
                manager.createConfiguration()
                return manager
            }())
    } detail: {
        Text(AppStrings.Empty.detail)
    }
}
