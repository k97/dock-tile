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

    var body: some View {
        List(selection: $selection) {
            Section(AppStrings.Sidebar.tilesSection) {
                if configManager.configurations.isEmpty {
                    // Navigation, NOT an add affordance: the empty-state detail already carries the
                    // single "Add a Tile…" button. This row exists so the user can get BACK to that
                    // empty state after visiting a Settings pane — with zero tiles there is no other
                    // selectable row in this section, and without it they are stranded in Settings.
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
            Section(AppStrings.Sidebar.settingsSection) {
                SettingsRow(
                    title: AppStrings.Settings.general,
                    systemName: PaneIcon.general.systemName,
                    tint: PaneIcon.general.tint
                )
                .tag(SidebarSelection.settings(.general))

                SettingsRow(
                    title: AppStrings.Settings.popover,
                    systemName: PaneIcon.popover.systemName,
                    tint: PaneIcon.popover.tint
                )
                .tag(SidebarSelection.settings(.popover))

                SettingsRow(
                    title: AppStrings.Settings.dockLock,
                    systemName: PaneIcon.dockLock.systemName,
                    tint: PaneIcon.dockLock.tint
                )
                .tag(SidebarSelection.settings(.dockLock))
            }

            Section(AppStrings.Sidebar.dockTileSection) {
                SettingsRow(title: AppStrings.About.title, systemName: PaneIcon.about.systemName, tint: PaneIcon.about.tint)
                    .tag(SidebarSelection.settings(.about))
            }
        }
        // `.sidebar` style gives the section headers their native treatment and the tile-row
        // selection highlight.
        .listStyle(.sidebar)
        // The sidebar keeps the standard macOS header pair — the collapse toggle and +, as in Notes
        // and Reminders. (v2 briefly dropped the toggle; it is deliberately back.)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addTileButton")
                .accessibilityLabel(AppStrings.Button.addATile)
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
/// rect, top-to-bottom gradient, SF Symbol glyph, subtle inner glass stroke, and the same
/// Liquid-Glass depth (top sheen + glyph contact shadow) as the tiles. Follows the LIVE icon
/// style the way the tile icons beside it do (`IconStyle.forDisplay` + `TintColor.badgeColors`)
/// — the badges used to pin `.defaultStyle` and stayed colourful while every tile icon in the
/// same sidebar restyled dark (2026-09-06 feedback).
struct SettingsBadgeIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 24

    @ObservedObject private var iconStyleManager = IconStyleManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var style: IconStyle {
        IconStyle.forDisplay(raw: iconStyleManager.rawStyle, colorScheme: colorScheme, fallback: .defaultStyle)
    }

    private var cornerRadius: CGFloat { size * 0.225 }

    private var glyphShadow: IconDepthMetrics.GlyphShadow? {
        IconDepthMetrics.glyphShadow(style: style, iconType: .sfSymbol, nominalSize: size)
    }

    private var glyphForeground: AnyShapeStyle {
        let base = TintColor.badgeColors(for: style, tint: tint).foreground
        if let darken = IconDepthMetrics.glyphBottomDarken(style: style, iconType: .sfSymbol, nominalSize: size) {
            return AnyShapeStyle(
                LinearGradient(colors: [base, base.darkened(by: darken)], startPoint: .top, endPoint: .bottom)
            )
        }
        return AnyShapeStyle(base)
    }

    var body: some View {
        let sheenAlpha = IconDepthMetrics.surfaceSheenAlpha(style: style, nominalSize: size)
        let colors = TintColor.badgeColors(for: style, tint: tint)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [colors.top, colors.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(IconDepthMetrics.strokeOpacity(style: style)),
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
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration

    var body: some View {
        HStack(spacing: 12) {
            // Mini icon preview (24×24pt) - uses same component as other previews
            DockTileIconPreview.fromConfig(config, size: 24)

            // The COMMITTED name, not the stored one: a rename in the editor re-titles the live
            // preview immediately but only reaches this row on Add to Dock / Update / Done.
            Text(configManager.displayName(for: config.id))
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
