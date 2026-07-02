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
    @EnvironmentObject private var smartAddEngine: SmartAddEngine
    @State private var isDrilledDown = false

    /// Smart Add sheet state. Driven by `.sheet(item:)` — NOT `isPresented` + a separate array.
    /// With a separate `Bool` + array, SwiftUI can evaluate the sheet content while the array is
    /// still its old (empty) value, so the sheet opens with no cards. Carrying the suggestions in
    /// the item guarantees the content is built from the exact value that opened it.
    @State private var smartAddPresentation: SmartAddPresentation?

    /// Identifiable wrapper so `.sheet(item:)` builds the sheet with these exact suggestions.
    private struct SmartAddPresentation: Identifiable {
        let id = UUID()
        let suggestions: [TileSuggestion]
    }

    /// Smart Add on/off (opt-out, default ON). When OFF, + always creates a blank tile — see
    /// the General settings toggle. Main-app domain.
    @AppStorage(UserDefaultsKeys.smartAddEnabled) private var smartAddEnabled = true

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
            DockTileSidebarView(selection: $selection, onAdd: handleAddTapped)
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
            switch newValue {
            case .tile(let id):
                if configManager.selectedConfigId != id {
                    configManager.selectedConfigId = id
                }
                let name = configManager.configuration(for: id)?.name ?? "?"
                DiagnosticsLog.shared.ui("Sidebar → selected tile '\(name)'")
            case .settings(let pane):
                DiagnosticsLog.shared.ui("Sidebar → opened Settings '\(pane)'")
            case .none:
                break
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
        // Non-destructive prompt raised by the launch scan when tiles reference uninstalled apps.
        // "Keep" just dismisses — the rows stay flagged inline so the user can act later.
        .alert(
            AppStrings.Alert.missingAppsTitle,
            isPresented: $configManager.showMissingAppsPrompt
        ) {
            Button(AppStrings.Button.remove, role: .destructive) {
                configManager.removeMissingApps()
            }
            Button(AppStrings.Button.keep, role: .cancel) {
                configManager.showMissingAppsPrompt = false
            }
        } message: {
            Text(AppStrings.Alert.missingAppsMessage)
        }
        // Smart Add: shown when + finds on-device suggestions. Nothing here docks a tile — picking
        // a suggestion only pre-fills Tile Detail; the explicit Add to Dock confirm stays there.
        .sheet(item: $smartAddPresentation) { presentation in
            SmartAddSheet(
                suggestions: presentation.suggestions,
                onUse: { suggestion in
                    DiagnosticsLog.shared.ui("Smart Add sheet → 'Use this tile' \(suggestion.name) (\(suggestion.appItems.count) app(s))")
                    configManager.createConfiguration(from: suggestion)
                    smartAddPresentation = nil
                },
                onCreateNew: {
                    DiagnosticsLog.shared.ui("Smart Add sheet → 'Create New Tile'")
                    configManager.createConfiguration()
                    smartAddPresentation = nil
                },
                onClose: {
                    DiagnosticsLog.shared.ui("Smart Add sheet → dismissed (no tile)")
                    smartAddPresentation = nil
                }
            )
        }
    }

    /// The + toolbar action. Computes on-device suggestions: if any, present the Smart Add sheet;
    /// otherwise fall through to today's blank-tile flow unchanged.
    private func handleAddTapped() {
        // Smart Add off → always the blank-tile flow.
        guard smartAddEnabled else {
            DiagnosticsLog.shared.ui("+ pressed (Smart Add off) → new blank tile")
            configManager.createConfiguration()
            return
        }

        let suggestions = smartAddEngine.computeSuggestions(existing: configManager.configurations)
        if suggestions.isEmpty {
            DiagnosticsLog.shared.ui("+ pressed → no suggestions, new blank tile")
            configManager.createConfiguration()
        } else {
            DiagnosticsLog.shared.ui("+ pressed → Smart Add sheet with \(suggestions.count) suggestion(s)")
            smartAddPresentation = SmartAddPresentation(suggestions: suggestions)
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
        .environmentObject(SmartAddEngine.shared)
}
