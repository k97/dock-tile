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
    case popover     // v2: top-level pane (was a drill-down inside General)
    case dockLock
    case about
}

/// What the sidebar currently has selected — either a tile or an inline Settings pane.
/// A single selection type lets the native `List(selection:)` drive the whole detail column.
enum SidebarSelection: Hashable {
    case tile(UUID)
    case settings(SettingsPane)
    /// The "No Tiles" placeholder row — selecting it shows the empty-state detail. Lets the user
    /// return to the empty state after visiting Settings, and gives first launch a concrete
    /// selection so the empty state (not a Settings pane) is what appears.
    case tilesPlaceholder
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

    /// Smart Add on/off (opt-out, default ON). Only decides whether the Add a Tile dialog is
    /// populated with suggestions — the dialog itself always opens, from every add entry point
    /// (sidebar +, General's row, the empty state). See `handleAddTapped` below. Main-app domain.
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
            // Sidebar: static Tiles / Settings / Dock Tile sections
            DockTileSidebarView(selection: $selection,
                                onAdd: { handleAddTapped(source: .toolbarPlus) })
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        // v2 chrome: the 52pt title band IS the page header. No window title, no sidebar toggle,
        // no toolbar surface — each pane hosts its title + actions as toolbar items (PaneTitleBand).
        // The toggle is removed once, on the sidebar's own `List` (DockTileSidebarView) — that is the
        // placement proven to work; the copies here and on this column were redundant.
        .toolbar(removing: .title)
        .toolbarBackground(.hidden, for: .windowToolbar)
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
            // Restore the persisted tile selection on first launch; with no tiles, land on the
            // empty-state placeholder so the user sees the empty state (not a Settings pane).
            if selection == nil {
                if let id = configManager.selectedConfigId {
                    selection = .tile(id)
                } else {
                    selection = .tilesPlaceholder
                }
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
            case .tilesPlaceholder:
                DiagnosticsLog.shared.ui("Sidebar → empty state (No Tiles)")
            case .none:
                break
            }
        }
        // External changes (create / delete / duplicate) jump the sidebar to that tile,
        // pulling focus out of a Settings pane if one was open. When the last tile is deleted
        // (selection becomes nil), fall back to the empty-state placeholder so the detail shows
        // the empty state and the "No Tiles" row is highlighted instead of a stale tile selection.
        .onChange(of: configManager.selectedConfigId) { _, newId in
            if let id = newId {
                if selection != .tile(id) { selection = .tile(id) }
            } else if case .tile = selection {
                selection = .tilesPlaceholder
            }
        }
        // ⌘, (and the Settings menu item) route here instead of opening a detached window.
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsPane)) { note in
            selection = .settings((note.object as? SettingsPane) ?? .general)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addTileRequested)) { _ in
            handleAddTapped(source: .generalSettings)
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
        // Add a Tile dialog: presented unconditionally from every add entry point. When there is
        // nothing to suggest it shows just the blank-tile row plus a "No suggestions yet" note.
        // Nothing here docks a tile — picking a suggestion only pre-fills Tile Detail; the
        // explicit Add to Dock confirm stays there.
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

    /// The + toolbar action (and every other add entry point). The Add a Tile dialog always
    /// opens — the blank row is the first thing you see. Smart Add only decides whether the
    /// dialog's suggestions are populated, never whether the dialog appears.
    /// Which affordance opened the dialog. Every entry point runs the SAME flow, so the trace has to
    /// carry the source or a diagnostics log can't tell the sidebar row from the toolbar +.
    enum AddSource: String {
        case toolbarPlus = "+ button"
        case emptyState = "empty state"
        case generalSettings = "General → Add a Tile"
    }

    private func handleAddTapped(source: AddSource) {
        let computed = smartAddEnabled
            ? smartAddEngine.computeSuggestions(existing: configManager.configurations) : []
        let suggestions = SmartAddEngine.suggestionsForAddFlow(enabled: smartAddEnabled, computed: computed)
        DiagnosticsLog.shared.ui("\(source.rawValue) → Add a Tile dialog (\(suggestions.count) suggestion(s), smartAdd=\(smartAddEnabled))")
        smartAddPresentation = SmartAddPresentation(suggestions: suggestions)
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selection {
        case .settings(let pane):
            settingsDetail(pane)
        case .tile, .tilesPlaceholder, .none:
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
        case .popover:
            PopoverAppearanceView()
                .environmentObject(configManager)
        case .dockLock:
            DockLockSettingsView()
        case .about:
            AboutPaneView()
                .environmentObject(configManager)
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
            // Empty state — routes through the same Smart Add flow as the sidebar +.
            EmptyConfigurationView(onAdd: { handleAddTapped(source: .emptyState) })
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

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified

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

    /// Same action as the sidebar +: compute Smart Add suggestions, else fall back to a blank tile.
    var onAdd: () -> Void

    var body: some View {
        // Apple's canonical empty-state component: it owns the icon size, typography,
        // spacing rhythm, and light/dark treatment, so the layout stays HIG-correct.
        ContentUnavailableView {
            Label(AppStrings.Empty.createFirstTile, systemImage: "square.stack.3d.up")
        } description: {
            Text(AppStrings.Empty.createFirstTileDescription)
        } actions: {
            Button(action: onAdd) {
                Label(AppStrings.Button.addATile, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Pane title band

/// Squircle badge for Settings/About sidebar rows. The title band itself is title-only — see
/// `paneTitleBand` below — this identity lives on in the sidebar (`DockTileSidebarView`).
struct PaneIcon: Equatable {
    let systemName: String
    let tint: Color
    static let general  = PaneIcon(systemName: "gearshape.fill", tint: .gray)
    static let popover  = PaneIcon(systemName: "macwindow.on.rectangle", tint: .indigo)
    static let dockLock = PaneIcon(systemName: "lock.display", tint: .blue)
    static let about    = PaneIcon(systemName: "info.circle.fill", tint: .gray)
}

/// The title item shared by both `PaneTitleBand` variants below — written exactly once so the plain
/// band and the trailing-actions band can never drift apart.
@ToolbarContentBuilder
private func paneTitleItem(title: String) -> some ToolbarContent {
    if #available(macOS 26.0, *) {
        ToolbarItem(placement: .navigation) { PaneTitleLabel(title: title) }
            .sharedBackgroundVisibility(.hidden)   // no Liquid Glass capsule around a title
    } else {
        ToolbarItem(placement: .navigation) { PaneTitleLabel(title: title) }
    }
}

private struct PaneTitleLabel: View {
    let title: String

    /// Nudge that lands the title on the pane's CONTENT leading edge rather than the toolbar's own,
    /// narrower inset — the title band IS the page header, so a title starting left of the first row
    /// below it reads as misaligned on every pane. Every pane insets its content by 20pt from the
    /// detail column; the toolbar item supplies part of that, and this covers the remainder.
    /// Measured, not guessed: with this value the title's AX frame and the first card's AX frame
    /// share a leading edge on both the Tile Detail (ScrollView) and Settings (Form) panes.
    static let leadingAdjustment: CGFloat = 12

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.leading, Self.leadingAdjustment)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PaneTitleBand: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content.toolbar {
            paneTitleItem(title: title)
        }
    }
}

/// Title band + trailing toolbar actions in ONE `.toolbar {}` call — title, the flexible spacer, and
/// `trailing` all ride together, so a pane's action items can never land in a separately-ordered
/// `.toolbar {}` block (`ToolbarContentBuilder` has no zero-argument `buildBlock()`, which is why this
/// needs its own modifier rather than the plain `PaneTitleBand` fed empty content).
private struct PaneTitleBandWithActions<Trailing: ToolbarContent>: ViewModifier {
    let title: String
    let trailing: Trailing

    init(title: String, @ToolbarContentBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    func body(content: Content) -> some View {
        content.toolbar {
            paneTitleItem(title: title)
            // `.toolbar(removing: .title)` (DockTileConfigurationView) drops the toolbar's automatic
            // flexible space, so trailing-placed items would otherwise collapse leftward next to the
            // title instead of trailing the band. Push them back to the trailing edge.
            //
            // `ToolbarSpacer` is macOS 26+. The pre-26 branch is the older idiom for the same job —
            // a toolbar item that is nothing but a `Spacer`, which the AppKit toolbar renders as a
            // flexible space. UNVERIFIED on real macOS 15 hardware (this machine is Tahoe): if it
            // misbehaves there, the failure mode is cosmetic — the actions sit beside the title,
            // which is exactly where they land with no spacer at all.
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.flexible)
            } else {
                ToolbarItem(placement: .automatic) { Spacer() }
            }
            trailing
        }
    }
}

extension View {
    /// Page header in the title band: the title text only. Replaces `.navigationTitle`.
    func paneTitleBand(_ title: String) -> some View {
        modifier(PaneTitleBand(title: title))
    }

    /// Page header with trailing toolbar actions (e.g. a primary-action button/group).
    func paneTitleBand<Trailing: ToolbarContent>(
        _ title: String,
        @ToolbarContentBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(PaneTitleBandWithActions(title: title, trailing: trailing))
    }

    /// The app's one switch size, for a **labels-hidden** toggle in a hand-built row (Tile Detail,
    /// Popover). Renders 36×16 — the size SwiftUI's `Form` already gives its own toggles, so the
    /// Settings panes match without setting anything.
    ///
    /// **Do NOT apply this to a `Form` toggle that carries a text label** (General, Dock Lock):
    /// `controlSize` scales the label typography too, so forcing `.mini` there would shrink their
    /// title and description text. Those panes match by inheriting the Form default — that is
    /// deliberate, not an oversight. One decision, two mechanisms, for a reason.
    func tileSwitch() -> some View {
        labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
    }
}

// MARK: - Preview

#Preview {
    DockTileConfigurationView()
        .environmentObject(ConfigurationManager())
        .environmentObject(UpdateController())
        .environmentObject(SmartAddEngine.shared)
}
