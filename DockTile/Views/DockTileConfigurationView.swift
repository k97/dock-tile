//
//  DockTileConfigurationView.swift
//  DockTile
//
//  Screen 3: Main configuration window with sidebar and drill-down support
//  Swift 6 - Strict Concurrency
//

import SwiftUI

struct DockTileConfigurationView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @State private var isDrilledDown = false

    var body: some View {
        NavigationSplitView {
            // Sidebar with configuration list
            DockTileSidebarView()
        } detail: {
            if let selectedConfig = configManager.selectedConfiguration {
                ZStack {
                    if !isDrilledDown {
                        // Detail view (Screen 3)
                        DockTileDetailView(
                            config: selectedConfig,
                            onCustomise: {
                                isDrilledDown = true
                            }
                        )
                        .transition(.move(edge: .leading))
                    }

                    if isDrilledDown {
                        // Drill-down view (Screen 4)
                        CustomiseTileView(
                            config: selectedConfig,
                            onBack: {
                                isDrilledDown = false
                            }
                        )
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isDrilledDown)
            } else {
                // Empty state
                EmptyConfigurationView()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
}

// MARK: - Empty State

struct EmptyConfigurationView: View {
    @EnvironmentObject private var configManager: ConfigurationManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Create Your First Tile")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Click the + button in the sidebar to create a new dock tile")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                configManager.createConfiguration()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("New Tile")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    DockTileConfigurationView()
        .environmentObject(ConfigurationManager())
}
