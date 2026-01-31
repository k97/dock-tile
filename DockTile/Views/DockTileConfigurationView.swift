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

    // Fixed window dimensions (System Settings style)
    private let windowWidth: CGFloat = 768
    private let minWindowHeight: CGFloat = 500

    var body: some View {
        NavigationSplitView {
            // Sidebar with configuration list
            DockTileSidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            if let selectedConfig = configManager.selectedConfiguration {
                ZStack {
                    if !isDrilledDown {
                        // Detail view (Screen 3)
                        // IMPORTANT: Use .id() to force view recreation when config changes
                        // Without this, SwiftUI may reuse the view and editedConfig gets stale
                        DockTileDetailView(
                            config: selectedConfig,
                            onCustomise: {
                                isDrilledDown = true
                            }
                        )
                        .id(selectedConfig.id)
                        .transition(.move(edge: .leading))
                    }

                    if isDrilledDown {
                        // Drill-down view (Screen 4)
                        // IMPORTANT: Use .id() to force view recreation when config changes
                        CustomiseTileView(
                            config: selectedConfig,
                            onBack: {
                                isDrilledDown = false
                            }
                        )
                        .id(selectedConfig.id)
                        .transition(.move(edge: .trailing))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
                .animation(.easeInOut(duration: 0.3), value: isDrilledDown)
            } else {
                // Empty state
                EmptyConfigurationView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        // Strict frame enforcement: fixed width, flexible height
        .frame(
            minWidth: windowWidth,
            idealWidth: windowWidth,
            maxWidth: windowWidth,
            minHeight: minWindowHeight,
            maxHeight: .infinity
        )
        .background(WindowAccessor(isCustomising: isDrilledDown))
    }
}

// MARK: - Window Accessor (AppKit Bridge)

/// NSViewRepresentable that configures the window at the AppKit level
/// This is the "secret sauce" that prevents horizontal resize cursor
private struct WindowAccessor: NSViewRepresentable {
    let isCustomising: Bool

    private let fixedWidth: CGFloat = 768
    private let defaultMinHeight: CGFloat = 500
    private let customiseMinHeight: CGFloat = 700

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configureWindow(window, animated: false)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Reconfigure on update in case window changed or isCustomising toggled
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configureWindow(window, animated: true)
        }
    }

    private func configureWindow(_ window: NSWindow, animated: Bool) {
        let minHeight = isCustomising ? customiseMinHeight : defaultMinHeight

        // Lock horizontal size, allow vertical resize
        window.contentMinSize = NSSize(width: fixedWidth, height: minHeight)
        window.contentMaxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)

        // Set current size if needed
        var frame = window.frame
        var needsResize = false

        // Fix width if incorrect
        if frame.width != fixedWidth {
            frame.size.width = fixedWidth
            needsResize = true
        }

        // Grow window height if below minimum for current mode
        if frame.height < minHeight {
            let heightDelta = minHeight - frame.height
            frame.size.height = minHeight
            // Grow upward (keep bottom edge fixed)
            frame.origin.y -= heightDelta
            needsResize = true
        }

        if needsResize {
            window.setFrame(frame, display: true, animate: animated)
        }
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
