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

                    Text("No Tiles")
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
        .navigationTitle("DockTile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    configManager.createConfiguration()
                }) {
                    Image(systemName: "plus")
                }
                .help("Create new tile")
            }
        }
    }
}

// MARK: - Configuration Row

struct ConfigurationRow: View {
    let config: DockTileConfiguration

    var body: some View {
        HStack(spacing: 12) {
            // Mini icon preview (24×24pt)
            Text(config.symbolEmoji)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [config.tintColor.colorTop, config.tintColor.colorBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                if config.isVisibleInDock {
                    Text("\(config.appItems.count) apps")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if config.isVisibleInDock {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Context Menu

struct ConfigurationContextMenu: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    let config: DockTileConfiguration

    var body: some View {
        Button("Duplicate") {
            configManager.duplicateConfiguration(config)
        }

        Divider()

        Button("Delete", role: .destructive) {
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
        Text("Detail")
    }
}
