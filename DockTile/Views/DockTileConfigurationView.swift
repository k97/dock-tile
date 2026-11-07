//
//  DockTileConfigurationView.swift
//  DockTile
//
//  Screen 3: Main configuration window: sidebar, detail column and the Customise inspector
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

/// What the View menu's inspector item reads from the focused main window.
struct InspectorCommand {
    let isEnabled: Bool
    /// The PRESENTED state, so the title reads "Hide" only while the inspector is actually visible.
    let isShown: Bool
    let toggle: () -> Void
}

private struct InspectorCommandKey: FocusedValueKey {
    typealias Value = InspectorCommand
}

extension FocusedValues {
    var inspectorCommand: InspectorCommand? {
        get { self[InspectorCommandKey.self] }
        set { self[InspectorCommandKey.self] = newValue }
    }
}

/// What File ▸ Revert to Dock Version reads from the focused tile's detail view.
struct RevertCommand {
    let isEnabled: Bool
    let revert: () -> Void
}

private struct RevertCommandKey: FocusedValueKey {
    typealias Value = RevertCommand
}

extension FocusedValues {
    var revertCommand: RevertCommand? {
        get { self[RevertCommandKey.self] }
        set { self[RevertCommandKey.self] = newValue }
    }
}

/// File ▸ Revert to Dock Version. Disabled without a focused tile or with nothing to revert.
struct RevertMenuItem: View {
    @FocusedValue(\.revertCommand) private var command

    var body: some View {
        Button(AppStrings.Tooltip.revertToDock) { command?.revert() }
            .disabled(command?.isEnabled != true)
    }
}

/// View ▸ Show/Hide Inspector (⌥⌘I). Disabled when no window is focused or no tile row is selected.
struct InspectorMenuItem: View {
    @FocusedValue(\.inspectorCommand) private var command

    var body: some View {
        let isShown = command?.isShown == true
        Button(isShown ? AppStrings.Menu.hideInspector : AppStrings.Menu.showInspector) {
            DiagnosticsLog.shared.ui(isShown ? "Menu → Hide Inspector (⌥⌘I)" : "Menu → Show Inspector (⌥⌘I)")
            command?.toggle()
        }
        .keyboardShortcut("i", modifiers: [.command, .option])
        .disabled(command?.isEnabled != true)
    }
}

struct DockTileConfigurationView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @EnvironmentObject private var smartAddEngine: SmartAddEngine
    @AppStorage(UserDefaultsKeys.inspectorShown) private var inspectorShown = false
    /// The selected tile's edit session, shared by Tile Detail and the Customise inspector.
    @StateObject private var editSessions = TileEditSessionStore()

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

    // Window width range lives on AppDelegate (min/max); this is the ideal width
    private let windowWidth: CGFloat = AppDelegate.minWindowWidth
    private let minWindowHeight: CGFloat = 500

    var body: some View {
        NavigationSplitView {
            // Sidebar: static Tiles / Settings / Dock Tile sections
            DockTileSidebarView(selection: $selection,
                                onAdd: { handleAddTapped(source: .toolbarPlus) })
                .navigationSplitViewColumnWidth(min: AppDelegate.sidebarMinWidth, ideal: 240, max: AppDelegate.sidebarMaxWidth)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        // On the NavigationSplitView itself, not inside Tile Detail: only here does the toolbar get
        // an inspector section, so the inspector's own band lands over its column (R10, 2026-10-20).
        // R9: the setter acts only when SwiftUI writes a value that differs from what is PRESENTED,
        // and then sets exactly that value (never a toggle). SwiftUI echoes every change back
        // through it, and on a Settings pane the presented value is `false` while the stored flag
        // stays `true`, which must not change anything. The flag is read from UserDefaults:
        // `@AppStorage` read here returned the old value (logged 2026-10-20: set true,
        // appStorage=false, stored=true), which toggled twice per press.
        .inspector(isPresented: Binding(
            get: { Self.inspectorIsPresented(stored: inspectorShown, selection: selection) },
            set: { newValue in
                if let shown = Self.inspectorSetterWrites(newValue: newValue, stored: Self.storedInspectorShown, selection: selection) {
                    setInspectorShown(shown)
                }
            }
        )) {
            inspectorColumn
                .inspectorColumnWidth(AppDelegate.inspectorWidth)
        }
        // A SELECTION change shows or hides the inspector instantly; only the user's own toggle
        // animates (AppKit's own split: plain `isCollapsed` vs `animator()`). The animated collapse
        // on the way to a Settings pane was the single largest cost of the open inspector: on an
        // optimised build the 12-switch Settings sequence went from 39 main-thread hangs
        // (4.05 s frozen) to 12 (2.95 s) with this alone (2026-10-21, Animation Hitches
        // instrument; baseline noise ±2 hangs), and the collapse animation is where both AppKit
        // constraint-loop crashes came from. `.transaction(value:)` applies only to transactions that changed `selection`, so
        // the toggle's transaction is untouched.
        .transaction(value: selection) { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
        // v2 chrome: the 52pt title band IS the page header. No window title, no sidebar toggle,
        // no toolbar surface — each pane hosts its title + actions as toolbar items (PaneTitleBand).
        // The toggle is removed once, on the sidebar's own `List` (DockTileSidebarView) — that is the
        // placement proven to work; the copies here and on this column were redundant.
        .toolbar(removing: .title)
        .toolbarBackground(.hidden, for: .windowToolbar)
        // Width resizable within the allowed range, flexible height
        .frame(
            minWidth: windowWidth,
            idealWidth: windowWidth,
            maxWidth: AppDelegate.maxWindowWidth,
            minHeight: minWindowHeight,
            maxHeight: .infinity
        )
        .background(WindowAccessor(inspectorShown: inspectorShown))
        .focusedSceneValue(\.inspectorCommand, InspectorCommand(
            isEnabled: Self.inspectorCommandIsEnabled(selection: selection),
            isShown: Self.inspectorIsPresented(stored: inspectorShown, selection: selection),
            toggle: toggleInspector
        ))
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
            // Coming back to a tile starts a fresh edit seeded from configManager, as the old
            // `.id` recreation of Tile Detail did.
            if case .tile = newValue {} else { editSessions.clear() }
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
        .onReceive(NotificationCenter.default.publisher(for: .openAddTile)) { _ in
            handleAddTapped(source: .menuBar)
        }
        // A tile's Configure gear lands on that tile with Customise open, from any pane (#31).
        .onReceive(NotificationCenter.default.publisher(for: .revealTile)) { note in
            guard let id = note.object as? UUID else { return }
            selection = .tile(id)
            if !Self.storedInspectorShown { setInspectorShown(true) }
        }
        // Non-destructive prompt raised by the launch scan when tiles reference uninstalled apps.
        // "Keep" just dismisses — the rows stay flagged inline so the user can act later.
        .alert(
            AppStrings.Alert.missingAppsTitle,
            isPresented: $configManager.showMissingAppsPrompt
        ) {
            Button(AppStrings.Button.remove, role: .destructive) {
                configManager.removeMissingApps()
                // R16: the live edit session still holds the removed apps; without this the next
                // edit's debounced save writes them back.
                editSessions.syncAppItems(from: configManager.configurations)
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
        case menuBar = "menu bar"
    }

    /// The inspector shows only while a tile row is selected; the stored flag survives Settings.
    nonisolated static func inspectorIsPresented(stored: Bool, selection: SidebarSelection?) -> Bool {
        guard stored, case .tile = selection else { return false }
        return true
    }

    /// R9: what the `.inspector` binding's setter stores. `nil` = ignore (SwiftUI wrote back what is
    /// already presented: our own echo, or `false` on a Settings pane where the stored flag must stay
    /// `true`); otherwise exactly `newValue`, never a toggle.
    nonisolated static func inspectorSetterWrites(newValue: Bool, stored: Bool, selection: SidebarSelection?) -> Bool? {
        newValue == inspectorIsPresented(stored: stored, selection: selection) ? nil : newValue
    }

    /// The View menu item is live exactly when the inspector could be presented: a tile row is selected.
    nonisolated static func inspectorCommandIsEnabled(selection: SidebarSelection?) -> Bool {
        inspectorIsPresented(stored: true, selection: selection)
    }

    /// The button / menu entry point. Negates the STORED flag — the one source the R9 setter
    /// reads too — so a stale `@AppStorage` copy in an escaping closure can't flip the wrong way.
    private func toggleInspector() {
        setInspectorShown(!Self.storedInspectorShown)
    }

    /// Writes the flag to exactly `shown`, logs, and applies the window minimum / growth.
    private func setInspectorShown(_ shown: Bool) {
        inspectorShown = shown
        DiagnosticsLog.shared.ui("Inspector → \(shown ? "shown" : "hidden")")
        AppDelegate.resizeConfigurationWindow(forInspectorShown: shown)
    }

    private static var storedInspectorShown: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.inspectorShown)
    }

    private func handleAddTapped(source: AddSource) {
        // Smart Add OFF skips the dialog entirely: a sheet holding only the blank-tile row is a
        // pointless extra step, so the + creates the blank tile directly (review feedback
        // 2026-09-02 — supersedes the v2 "dialog always opens" rule for the disabled case).
        guard smartAddEnabled else {
            DiagnosticsLog.shared.ui("\(source.rawValue) → blank tile directly (smartAdd off)")
            configManager.createConfiguration()
            return
        }
        let computed = smartAddEngine.computeSuggestions(existing: configManager.configurations)
        let suggestions = SmartAddEngine.suggestionsForAddFlow(enabled: true, computed: computed)
        DiagnosticsLog.shared.ui("\(source.rawValue) → Add a Tile dialog (\(suggestions.count) suggestion(s))")
        smartAddPresentation = SmartAddPresentation(suggestions: suggestions)
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selection {
        case .settings(let pane):
            // Same reported minimum as Tile Detail: while the inspector collapses on the way to a
            // Settings pane, the split view still counts it twice, and the Popover pane's own width
            // (its segmented rows) then overflowed the window — an endless layout pass and an
            // NSException (2026-10-21; General survived, Popover crashed).
            settingsDetail(pane)
                .frame(minWidth: AppDelegate.detailColumnMinWidth, maxWidth: .infinity, maxHeight: .infinity)
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
            // IMPORTANT: .id() recreates Tile Detail per tile, so its @State (name field, dirty
            // signature, pending save) never carries over from the previous tile
            DockTileDetailView(
                session: editSessions.session(for: selectedConfig),
                inspectorShown: inspectorShown,
                onToggleInspector: toggleInspector
            )
            .id(selectedConfig.id)
            // `minWidth` caps the minimum Tile Detail reports below its content's, so the split
            // view's minimum fits the window's with the inspector open (see detailColumnMinWidth).
            .frame(minWidth: AppDelegate.detailColumnMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            // Empty state — routes through the same Smart Add flow as the sidebar +.
            EmptyConfigurationView(onAdd: { handleAddTapped(source: .emptyState) })
        }
    }

    /// Customise Tile for the selected tile, editing the same session as Tile Detail.
    @ViewBuilder
    private var inspectorColumn: some View {
        if case .tile = selection, let selectedConfig = configManager.selectedConfiguration {
            CustomiseInspectorColumn(
                session: editSessions.session(for: selectedConfig),
                isPresented: Self.inspectorIsPresented(stored: inspectorShown, selection: selection),
                onToggleInspector: toggleInspector
            )
            .id(selectedConfig.id)
        }
    }
}

/// Holds the selected tile's `TileEditSession`: the same one while that tile stays selected, a
/// fresh one per tile. Not published — handing out a session never re-renders anything.
@MainActor
final class TileEditSessionStore: ObservableObject {
    private var current: TileEditSession?

    func session(for config: DockTileConfiguration) -> TileEditSession {
        if let current, current.id == config.id { return current }
        let session = TileEditSession(config: config)
        current = session
        return session
    }

    func clear() { current = nil }

    /// After the missing-apps Remove: copy ONLY `appItems` from the stored config into the current
    /// session. Never a general sync — that would overwrite unsaved edits whenever another tile saves.
    func syncAppItems(from configurations: [DockTileConfiguration]) {
        guard let current, let stored = configurations.first(where: { $0.id == current.id }) else { return }
        current.config.appItems = stored.appItems
    }
}

/// Observes the session so the inspector re-renders on every edit, wherever it came from.
/// R15: SwiftUI builds inspector content while it is closed, so `CustomiseTileView` is built only
/// while presented; otherwise every Name keystroke re-rendered the whole hidden Customise view.
/// This `isPresented` check is the content's one gate: it also keeps the inspector band's toolbar
/// items out of the main band while closed.
///
/// Built in the SAME frame as Tile Detail, deliberately. A skeleton-then-content deferral was tried
/// (2026-10-21, 32 ms settle) and measured worse — 19–20 hangs over 12 switches against 13–15
/// without it (optimised build) — so it was removed. What the open inspector does cost per switch is
/// in `docs/perf/customise-inspector-cost-2026-10.md`.
private struct CustomiseInspectorColumn: View {
    @ObservedObject var session: TileEditSession
    let isPresented: Bool
    let onToggleInspector: () -> Void

    var body: some View {
        Group {
            if isPresented {
                // The band rides on the presented content, never on the column: the column is built
                // while closed too, and its band then leaked "Customise Tile" + a second toggle into
                // the main band (owner report 2026-10-21, after d514d27 hoisted it here).
                CustomiseTileView(config: $session.config)
                    .inspectorTitleBand(AppStrings.Title.customiseTile, onToggle: onToggleInspector)
            } else {
                Color.clear
            }
        }
        // Pinned: AppKit throws (update-constraints loop) when the content's minimum width exceeds its column.
        .frame(width: AppDelegate.inspectorWidth)
        // No drawn line along the leading edge: the inspector's glass against Tile Detail's page is
        // the separation, as in Xcode (owner's call, 2026-10-21; the 1 pt line dated from the
        // opaque inspector).
    }
}

// MARK: - Window Accessor (AppKit Bridge)

/// NSViewRepresentable that configures the window at the AppKit level
/// Configures the unified title bar and the width range (AppDelegate.minWindowWidth...maxWindowWidth)
private struct WindowAccessor: NSViewRepresentable {
    let inspectorShown: Bool

    private let minHeight: CGFloat = 500

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configureWindow(window, clampsFrame: true)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Reconfigure on update in case window changed or the inspector toggled. Never moves the
        // frame: an inspector change is resized only by AppDelegate.resizeConfigurationWindow.
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configureWindow(window, clampsFrame: false)
        }
    }

    private func configureWindow(_ window: NSWindow, clampsFrame: Bool) {
        // Tag the window so AppDelegate can reliably find this single configuration window
        // (for Dock-icon reopen / deep-link bring-to-front) instead of guessing by title.
        if window.identifier?.rawValue != AppDelegate.configurationWindowID {
            window.identifier = NSUserInterfaceItemIdentifier(AppDelegate.configurationWindowID)
        }

        // The open minimum rests on `windowWillResize`: SwiftUI's root frame resets `contentMinSize`
        // to the closed minimum. So every window gets the delegate here, on every creation path
        // (launch, Dock reopen, deep link, ⌘,), not once at launch.
        if let delegate = AppDelegate.instance, window.delegate !== delegate {
            window.delegate = delegate
            DiagnosticsLog.shared.log("window", "delegate set by WindowAccessor", verbose: true)
        }

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified

        // Bound horizontal size to the allowed range, allow vertical resize
        window.contentMinSize = NSSize(width: AppDelegate.clampedWindowWidth(0, inspectorShown: inspectorShown), height: minHeight)
        window.contentMaxSize = NSSize(width: AppDelegate.maxWindowWidth, height: CGFloat.greatestFiniteMagnitude)

        // The one launch-time frame fix. With the inspector stored open, the restored frame takes
        // the same rule as opening it (`windowFrame`), so growing to 960 never pushes a frame saved
        // near the screen's right edge off it; closed, the plain clamp into the allowed range.
        guard clampsFrame else { return }
        var frame = window.frame
        if inspectorShown, let screen = window.screen ?? NSScreen.main {
            frame = AppDelegate.windowFrame(forInspectorShown: true, from: frame, visibleFrame: screen.visibleFrame)
        } else {
            frame.size.width = AppDelegate.clampedWindowWidth(frame.width, inspectorShown: inspectorShown)
        }
        if frame != window.frame {
            window.setFrame(frame, display: true, animate: false)
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

    /// The inspector band passes its own measured value (`InspectorTitleBand.titleLeadingAdjustment`).
    var leadingAdjustment: CGFloat = PaneTitleLabel.leadingAdjustment
    /// 16 pt is the page title; the inspector band's title is one step smaller (`InspectorTitleBand`).
    var fontSize: CGFloat = 16

    var body: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, leadingAdjustment)
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

/// The Customise inspector's own band: its title, a flexible spacer and the close toggle. Not
/// `PaneTitleBand`, on purpose (spike, 2026-10-20): a `.navigation` title is pulled into the DETAIL
/// band, so the title is placed `.automatic`. Built only while the inspector is presented —
/// `CustomiseInspectorColumn` gates the content — or these items would leak into the main band.
private struct InspectorTitleBand: ViewModifier {
    /// Lands "Customise Tile" on the inspector cards' leading edge. Measured by AX frame on the
    /// signed dev build (macOS 27, inspector on the NavigationSplitView): at 12 the title text sat
    /// 8 pt right of the first card (1163 vs 1155, 1200 pt window); at 4 the edges match at both
    /// widths — 1155 vs 1155 at 1200 pt, 1115 vs 1115 at 1160 pt. Unchanged at the 14 pt title
    /// (re-measured 2026-10-20): 1264 vs 1264 at 1028 pt, 1252 vs 1252 at 1200 pt.
    static let titleLeadingAdjustment: CGFloat = 4

    /// One step below the 16 pt page title; 13 pt is the row-label size (spec Decision 11).
    static let titleFontSize: CGFloat = 14

    let title: String
    let onToggle: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .automatic) {
                    PaneTitleLabel(title: title, leadingAdjustment: Self.titleLeadingAdjustment, fontSize: Self.titleFontSize)
                }
                .sharedBackgroundVisibility(.hidden)   // no Liquid Glass capsule around a title
                ToolbarSpacer(.flexible)
            } else {
                ToolbarItem(placement: .automatic) {
                    PaneTitleLabel(title: title, leadingAdjustment: Self.titleLeadingAdjustment, fontSize: Self.titleFontSize)
                }
                ToolbarItem(placement: .automatic) { Spacer() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: onToggle) {
                    Image(systemName: "sidebar.trailing")
                }
                .help(AppStrings.Tooltip.toggleCustomiseTile)
                .accessibilityLabel(AppStrings.Tooltip.toggleCustomiseTile)
            }
        }
    }
}

/// Scroll-edge scrim for the title band (the Apple Notes treatment). The v2 chrome hides the
/// toolbar surface entirely (`.toolbarBackground(.hidden)` + transparent titlebar), so a pane's
/// content scrolls straight under the 52pt band and collides with the title/actions. This
/// modifier pins a material scrim behind the band that fades in as content scrolls beneath —
/// invisible at rest (the chromeless v2 look is untouched), opaque enough to read against a
/// dense app grid once scrolled. Applied to the pane's scroll container (ScrollView or Form —
/// both feed `onScrollGeometryChange`), never to the toolbar: the toolbar background must stay
/// hidden or every pane gains a permanent surface.
struct PaneScrollEdgeEffect: ViewModifier {
    /// The title band the scrim must cover (v2 chrome constant).
    static let bandHeight: CGFloat = 52
    /// Gradient tail below the band — the "progressive blur" read; a hard edge looks like a bar.
    static let fadeTail: CGFloat = 28
    /// Fraction of the pane width over which the scrim's leading edge dissolves toward the
    /// sidebar, so the column split doesn't show a hard vertical seam.
    static let leadingFade: CGFloat = 0.12

    /// Pure seam: scrim opacity for a scroll offset. 0 at rest and during rubber-band
    /// overscroll (offset ≤ 0), 1 once content has scrolled `ramp` points under the band,
    /// linear between — continuous, driven by the scroll itself, so no animation is needed
    /// (and Reduce Motion has nothing to object to). Guarded by PaneScrollEdgeEffectTests.
    nonisolated static func opacity(forOffset offset: CGFloat, ramp: CGFloat = 24) -> Double {
        Double(min(max(offset / ramp, 0), 1))
    }

    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
            .overlay(alignment: .top) {
                // `.ultraThinMaterial`, deliberately: `.regularMaterial` read as a light grey slab
                // in dark mode (2026-09-07 feedback "harsh"). The second mask dissolves the scrim's
                // leading edge so it bleeds toward the sidebar instead of hard-cutting at the
                // column split — the sidebar itself is a separate vibrant region the scrim must
                // never paint over.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: Self.bandHeight / (Self.bandHeight + Self.fadeTail)),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: Self.leadingFade),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                    .frame(height: Self.bandHeight + Self.fadeTail)
                    .ignoresSafeArea(edges: .top)
                    .opacity(Self.opacity(forOffset: scrollOffset))
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Page header in the title band: the title text only. Replaces `.navigationTitle`.
    func paneTitleBand(_ title: String) -> some View {
        modifier(PaneTitleBand(title: title))
    }

    /// The Customise inspector's band: title + close toggle (the content exists only while presented).
    func inspectorTitleBand(_ title: String, onToggle: @escaping () -> Void) -> some View {
        modifier(InspectorTitleBand(title: title, onToggle: onToggle))
    }

    /// Fades a material scrim in behind the title band while content scrolls beneath it.
    /// Attach to the pane's scroll container (ScrollView / Form), alongside `paneTitleBand`.
    func paneScrollEdgeEffect() -> some View {
        modifier(PaneScrollEdgeEffect())
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
