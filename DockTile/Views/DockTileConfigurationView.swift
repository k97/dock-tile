//
//  DockTileConfigurationView.swift
//  DockTile
//
//  Screen 3: Main configuration window with sidebar and drill-down support
//  Swift 6 - Strict Concurrency
//

import SwiftUI

/// One of the inline Settings panes, hosted in the detail column instead of a detached window.
enum SettingsPane: Hashable, CaseIterable {
    case general
    case dockLock
}

/// What the sidebar currently has selected — either a tile or an inline Settings pane.
/// A single selection type lets the native `List(selection:)` drive the whole detail column.
enum SidebarSelection: Hashable {
    case tile(UUID)
    case settings(SettingsPane)
}

struct DockTileConfigurationView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @State private var isDrilledDown = false

    /// Single source of truth for what the sidebar has selected and what fills the detail
    /// column — a tile or an inline Settings pane. Kept in sync with `configManager`'s tile
    /// selection (the rest of the app still reads `selectedConfigId`) via `onChange` below.
    @State private var selection: SidebarSelection?

    // Fixed window dimensions (System Settings style)
    private let windowWidth: CGFloat = 768
    private let minWindowHeight: CGFloat = 500

    var body: some View {
        NavigationSplitView {
            // Sidebar with tiles + inline Settings, accordion-style sections
            DockTileSidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailColumn
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
        .onAppear {
            // Restore the persisted tile selection on first launch.
            if selection == nil, let id = configManager.selectedConfigId {
                selection = .tile(id)
            }
        }
        // Selecting a tile in the sidebar drives the manager (which the rest of the app reads).
        .onChange(of: selection) { _, newValue in
            if case .tile(let id) = newValue, configManager.selectedConfigId != id {
                configManager.selectedConfigId = id
            }
        }
        // External changes (create / delete / duplicate) jump the sidebar to that tile,
        // pulling focus out of a Settings pane if one was open.
        .onChange(of: configManager.selectedConfigId) { _, newId in
            if let id = newId, selection != .tile(id) {
                selection = .tile(id)
            }
        }
        // ⌘, (and the Settings menu item) route here instead of opening a detached window.
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsPane)) { note in
            selection = .settings((note.object as? SettingsPane) ?? .general)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selection {
        case .settings(let pane):
            settingsDetail(pane)
        case .tile, .none:
            tileDetail
        }
    }

    /// Hosts a Settings pane inside the detail column. The grouped Forms fill the column and
    /// supply their own native insets — System Settings layout, no extra padding needed.
    @ViewBuilder
    private func settingsDetail(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general:
            GeneralSettingsView()
                .environmentObject(configManager)
        case .dockLock:
            DockLockSettingsView()
        }
    }

    @ViewBuilder
    private var tileDetail: some View {
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
        // Tag the window so AppDelegate can reliably find this single configuration window
        // (for Dock-icon reopen / deep-link bring-to-front) instead of guessing by title.
        if window.identifier?.rawValue != AppDelegate.configurationWindowID {
            window.identifier = NSUserInterfaceItemIdentifier(AppDelegate.configurationWindowID)
        }

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
                Text(AppStrings.Empty.createFirstTile)
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
                    Text(AppStrings.Button.newTile)
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
        .environmentObject(UpdateController())
}
