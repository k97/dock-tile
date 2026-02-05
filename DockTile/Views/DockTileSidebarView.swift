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

    var body: some View {
        Group {
            if configManager.configurations.isEmpty {
                // Empty sidebar state
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text(AppStrings.Empty.noTiles)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Click + to create your first tile")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $configManager.selectedConfigId) {
                    ForEach(configManager.configurations) { config in
                        ConfigurationRow(config: config)
                            .tag(config.id)
                            .contextMenu {
                                ConfigurationContextMenu(config: config)
                            }
                    }
                }
            }
        }
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
        DockTileSidebarView()
            .environmentObject({
                let manager = ConfigurationManager()
                manager.createConfiguration()
                return manager
            }())
    } detail: {
        Text(AppStrings.Empty.detail)
    }
}
