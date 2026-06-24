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

    /// Accordion expand/collapse state, persisted so it survives relaunch (Apple Notes-style).
    @AppStorage("sidebar.tilesExpanded") private var tilesExpanded = true
    @AppStorage("sidebar.settingsExpanded") private var settingsExpanded = true

    var body: some View {
        List(selection: $selection) {
            // Tiles — collapsible accordion section with an always-visible disclosure triangle.
            Section(AppStrings.Sidebar.tilesSection, isExpanded: $tilesExpanded) {
                if configManager.configurations.isEmpty {
                    Text(AppStrings.Empty.noTiles)
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
                Button(action: {
                    configManager.createConfiguration()
                }) {
                    Image(systemName: "plus")
                }
                .disabled(!configManager.selectedConfigHasBeenEdited)
                .help(configManager.selectedConfigHasBeenEdited
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
/// rect, top-to-bottom gradient, white SF Symbol, subtle inner glass stroke.
struct SettingsBadgeIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 24

    private var cornerRadius: CGFloat { size * 0.225 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)

            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
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
            configManager.duplicateConfiguration(config)
        }

        Divider()

        Button(AppStrings.Button.delete, role: .destructive) {
            configManager.deleteConfiguration(config.id)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationSplitView {
        DockTileSidebarView(selection: .constant(nil))
            .environmentObject({
                let manager = ConfigurationManager()
                manager.createConfiguration()
                return manager
            }())
    } detail: {
        Text(AppStrings.Empty.detail)
    }
}
