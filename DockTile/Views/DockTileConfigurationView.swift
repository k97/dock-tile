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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .background(WindowAccessor())
    }
}

// MARK: - Window Accessor (AppKit Bridge)

/// NSViewRepresentable that configures the window at the AppKit level
/// This is the "secret sauce" that prevents horizontal resize cursor
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configureWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Reconfigure on update in case window changed
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        let fixedWidth: CGFloat = 768
        let minHeight: CGFloat = 500

        // Lock horizontal size, allow vertical resize
        window.contentMinSize = NSSize(width: fixedWidth, height: minHeight)
        window.contentMaxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)

        // Set current size if not already correct
        var frame = window.frame
        if frame.width != fixedWidth {
            frame.size.width = fixedWidth
            window.setFrame(frame, display: true, animate: false)
        }

        // Disable horizontal resize (keep vertical)
        // styleMask already includes .resizable, but we constrain via min/max
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
