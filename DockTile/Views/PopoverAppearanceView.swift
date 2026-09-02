//
//  PopoverAppearanceView.swift
//  DockTile
//
//  Settings → General → "Popover Appearance" drill-down. Global controls for how every tile's
//  Dock popover (Grid / List) looks: popover size, tile size, animation, spacing, labels, hover.
//
//  A live-preview hero at the top mirrors the Customise-Tile icon studio — it sits on the same
//  `StudioCanvasBackgroundView` treatment and re-renders on every control change. Values persist
//  to the SHARED suite so helper popovers read them (see PopoverSettings / UserDefaultsKeys).
//
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct PopoverAppearanceView: View {
    /// Grid and List are configured **independently** — each layout has its own staged draft, only
    /// written to the shared suite on **Save** (draft/commit). A grid tile reads the grid config, a
    /// list tile the list config. The live preview renders whichever the Configure switcher is on.
    @State private var gridDraft: PopoverSettings
    @State private var listDraft: PopoverSettings
    /// Last-saved baselines, used to drive the Save button's dirty state.
    @State private var gridBaseline: PopoverSettings
    @State private var listBaseline: PopoverSettings

    /// Seed each layout's draft + baseline from its persisted values so the preview opens on what's
    /// actually live, with no first-render flash through the defaults.
    init() {
        let grid = PopoverSettings.load(layout: .grid)
        let list = PopoverSettings.load(layout: .list)
        _gridDraft = State(initialValue: grid)
        _listDraft = State(initialValue: list)
        _gridBaseline = State(initialValue: grid)
        _listBaseline = State(initialValue: list)
    }

    /// Tile list + helper visibility — used to push the saved settings to the running Dock tiles.
    @EnvironmentObject private var configManager: ConfigurationManager

    /// True while helpers are being rebuilt + relaunched — drives the Save button's loading state.
    @State private var isApplying = false
    /// Presents the one-time "applying restarts the Dock" confirmation before the rebuild.
    @State private var showApplyRestartPrompt = false

    /// Which layout's config the form edits AND the preview shows. This is the **Configure** panel
    /// switcher — NOT a persisted tile setting (per-tile Grid/List lives on Tile Detail). Switching
    /// it just changes which independent config the controls below read from and write to.
    @State private var previewLayout: LayoutMode = .grid

    /// The config the form is currently editing — grid or list per the Configure switcher. All
    /// control handlers route through this so they only ever touch the active layout's config.
    private var activeDraft: Binding<PopoverSettings> {
        Binding(
            get: { previewLayout == .grid ? gridDraft : listDraft },
            set: { if previewLayout == .grid { gridDraft = $0 } else { listDraft = $0 } }
        )
    }

    /// Per-control bindings into the *active* config. `animation` is built explicitly because
    /// `$x.animation` would resolve to SwiftUI's `Binding.animation(_:)` method, not the field.
    private var popoverSize: Binding<PopoverSizeTier> {
        Binding(get: { activeDraft.wrappedValue.popoverSize }, set: { activeDraft.wrappedValue.popoverSize = $0 })
    }
    private var tileSize: Binding<PopoverSizeTier> {
        Binding(get: { activeDraft.wrappedValue.tileSize }, set: { activeDraft.wrappedValue.tileSize = $0 })
    }
    private var animation: Binding<PopoverAnimationTier> {
        Binding(get: { activeDraft.wrappedValue.animation }, set: { activeDraft.wrappedValue.animation = $0 })
    }
    private var spacing: Binding<PopoverSpacingTier> {
        Binding(get: { activeDraft.wrappedValue.spacing }, set: { activeDraft.wrappedValue.spacing = $0 })
    }
    private var highlightOnHover: Binding<Bool> {
        Binding(get: { activeDraft.wrappedValue.highlightOnHover }, set: { activeDraft.wrappedValue.highlightOnHover = $0 })
    }
    /// Show Labels is a Grid-only setting (a list popover always labels its rows), so it writes the
    /// grid config directly — its row is only shown when the Grid panel is active.
    private var showLabels: Binding<Bool> {
        Binding(get: { gridDraft.showLabels }, set: { gridDraft.showLabels = $0 })
    }

    /// Save is enabled when EITHER layout's draft differs from what's persisted (both are committed
    /// together). Reset affects only the active config, so it's gated on the active config alone.
    private var isDirty: Bool { gridDraft != gridBaseline || listDraft != listBaseline }
    private var isActiveAtDefaults: Bool { activeDraft.wrappedValue == .default }

    /// When the system Reduce Motion setting is on we force Animation to None and disable the
    /// control (HIG: animation speed follows the OS preference, not an in-app override).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motionDuration: Double {
        PopoverMetrics.animationDuration(activeDraft.wrappedValue.animation, reduceMotion: reduceMotion)
    }

    /// A signature of every value the real popover reads — changing it forces the embedded panel to
    /// re-init and re-read the active config, so the preview always mirrors the shipped rendering 1:1.
    private var previewSignature: String {
        let a = activeDraft.wrappedValue
        return [a.popoverSize.rawValue, a.tileSize.rawValue, a.spacing.rawValue, a.animation.rawValue,
                a.showLabels ? "L" : "l", a.highlightOnHover ? "H" : "h", previewLayout.rawValue]
            .joined(separator: "-")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroPreview
                controls
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 560)
            }
            .frame(maxWidth: .infinity)
        }
        .background(NSColorBackgroundView.windowBackground)
        // HIG: window-level actions live in the toolbar. Reset is the secondary (plain bordered)
        // button; Save is the primary (accent-tinted, prominent) action on the trailing edge. Trails
        // the title band via PaneTitleBand's own flexible spacer (single `.toolbar {}` call — see
        // PaneTitleBand in DockTileConfigurationView.swift).
        .paneTitleBand(AppStrings.Settings.popover) {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: resetToDefaults) {
                    Label(AppStrings.Button.resetToDefaults, systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .help(AppStrings.Button.resetToDefaults)
                .disabled(isActiveAtDefaults || isApplying)

                Button(action: save) {
                    if isApplying {
                        // Loading state while rebuilding the tiles: spinner + "Applying…".
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(AppStrings.Button.saving)
                        }
                    } else {
                        Text(AppStrings.Button.save)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                // A prominent (accent-filled) button uses a white "on-accent" label so it stays legible
                // on the fill in BOTH light and dark mode (the Tahoe toolbar otherwise tints the label
                // itself the accent colour → unreadable blue-on-blue).
                .foregroundStyle(.white)
                // HIG button states: a disabled control reduces prominence by dimming the WHOLE
                // control. In this toolbar `.disabled()` dims only the label, leaving a bright-blue
                // fill with faded text (uneven). Fading the whole button fades fill + label together,
                // so it reads as one uniformly-dimmed "disabled blue" button. Stays full while there's
                // something to do (dirty) or while applying (busy + spinner).
                .opacity((isDirty || isApplying) ? 1.0 : 0.45)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isApplying || !isDirty)
            }
        }
        .alert(AppStrings.Alert.applyPopoverTitle, isPresented: $showApplyRestartPrompt) {
            Button(AppStrings.Button.applyToTiles) {
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasAcknowledgedPopoverApplyRestart)
                Task { await applyToRunningTiles() }
            }
            Button(AppStrings.Button.cancel, role: .cancel) { }
        } message: {
            Text(AppStrings.Alert.applyPopoverMessage)
        }
    }

    // MARK: - Live preview hero

    /// The real popover panels embedded in the shared `PopoverPreviewCanvas`, zoomed to a fixed
    /// worst-case fit so control changes visibly spread/tighten the tiles instead of the panel
    /// re-filling the width and cancelling the change.
    private var heroPreview: some View {
        PopoverPreviewCanvas(configuration: PreviewAppCatalog.sampleConfiguration,
                             layout: previewLayout,
                             settings: activeDraft.wrappedValue,
                             fit: .worstCase(height: 300),
                             signature: previewSignature)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .animation(.easeInOut(duration: max(0.18, motionDuration)), value: previewSignature)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            configureStrip
            sectionHeader(AppStrings.Settings.popover)
            card {
                segmentedRow(AppStrings.Label.popoverSize, selection: popoverSize, options: PopoverSizeTier.allCases) {
                    AppStrings.PopoverOption.size($0)
                }
                divider
                segmentedRow(AppStrings.Label.tileSizeInPopover, selection: tileSize, options: PopoverSizeTier.allCases) {
                    AppStrings.PopoverOption.size($0)
                }
                divider
                animationRow
            }

            sectionHeader(AppStrings.Settings.popoverSectionTiles)
                .padding(.top, 18)
            card {
                segmentedRow(AppStrings.Label.popoverSpacing, selection: spacing, options: PopoverSpacingTier.allCases) {
                    AppStrings.PopoverOption.spacing($0)
                }
                divider
                showLabelsRow
                divider
                toggleRow(AppStrings.Label.highlightOnHover, isOn: highlightOnHover)
            }

            Text(AppStrings.Settings.popoverFooter)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 6)
        }
    }

    /// The "Configure" panel switcher: a header + subtitle on the left and a Grid/List segmented
    /// control on the right. This is NOT a persisted setting — it selects which independent config
    /// (grid / list) the form below edits and the preview shows.
    private var configureStrip: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.Settings.popoverConfigure)
                    .font(.system(size: 13, weight: .semibold))
                Text(AppStrings.Settings.popoverConfigureSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $previewLayout) {
                ForEach(LayoutMode.allCases, id: \.self) { layout in
                    Text(layout.displayName).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    // Animation row: disabled + forced to None when Reduce Motion is on, with an explanatory caption.
    private var animationRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text(AppStrings.Label.popoverAnimation)
                    .font(.system(size: 13))
                    .foregroundStyle(reduceMotion ? .secondary : .primary)
                Spacer()
                Picker("", selection: reduceMotion ? .constant(PopoverAnimationTier.none) : animation) {
                    ForEach(PopoverAnimationTier.allCases, id: \.self) { tier in
                        Text(AppStrings.PopoverOption.animation(tier)).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .disabled(reduceMotion)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 40)

            if reduceMotion {
                HStack(spacing: 8) {
                    Text(AppStrings.Settings.popoverReduceMotionNote)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(AppStrings.Button.openAccessibilitySettings, action: openAccessibilitySettings)
                        .controlSize(.small)
                        .buttonStyle(.link)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    // Show Labels: a real toggle in Grid; a disabled hint in List (list always labels).
    private var showLabelsRow: some View {
        HStack {
            Text(AppStrings.Label.showLabels)
                .font(.system(size: 13))
                .foregroundStyle(previewLayout == .list ? .secondary : .primary)
            Spacer()
            if previewLayout == .list {
                Text(AppStrings.Label.listAlwaysLabelled)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Toggle("", isOn: showLabels)
                    .tileSwitch()
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    // MARK: - Reusable row helpers

    private func segmentedRow<T: Hashable>(
        _ label: String,
        selection: Binding<T>,
        options: [T],
        title: @escaping (T) -> String
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(title(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: isOn)
                .tileSwitch()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4).padding(.bottom, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(NSColorBackgroundView.formGroup)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    // MARK: - Actions

    /// Visible tiles that have a helper bundle on disk — the ones a rebuild can push the new look to.
    private var applicableHelpers: [DockTileConfiguration] {
        configManager.configurations.filter {
            $0.isVisibleInDock && HelperBundleManager.shared.helperExists(for: $0)
        }
    }

    /// Commit the staged draft to the shared suite, then offer to push it to the running tiles.
    /// Persisting alone is enough for the *next* popover open; applying now rebuilds the pinned
    /// helpers so the change takes effect immediately (one Dock restart).
    private func save() {
        // Both independent configs are committed together.
        gridDraft.persist(layout: .grid)
        listDraft.persist(layout: .list)
        gridBaseline = gridDraft
        listBaseline = listDraft
        AnalyticsService.shared.log(.settingChanged, ["setting": "popover_appearance", "saved": true])
        DiagnosticsLog.shared.log("settings", "Popover appearance saved (grid + list)")

        // No pinned tiles → nothing to push; the save is done.
        guard !applicableHelpers.isEmpty else { return }
        // Consent is read/written explicitly (not via @AppStorage) so the gate can't be skewed by a
        // stale cross-process defaults cache — the prompt must reliably show the first time.
        let acknowledged = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasAcknowledgedPopoverApplyRestart)
        if acknowledged {
            Task { await applyToRunningTiles() }
        } else {
            showApplyRestartPrompt = true   // first time: warn that the Dock will restart
        }
    }

    /// Rebuild + relaunch the pinned helpers so their popovers adopt the just-saved settings.
    /// Drives the Save button's loading state for the duration (rebuild + single Dock restart).
    @MainActor
    private func applyToRunningTiles() async {
        isApplying = true
        defer { isApplying = false }
        await HelperMigrationManager(configManager: configManager).reapply(applicableHelpers)
        DiagnosticsLog.shared.log("settings", "Popover appearance applied to running tiles")
    }

    /// Stage the spec defaults into the **active** config only (previewed live). The other layout's
    /// config is untouched. The user still presses **Save** to commit — consistent with the model.
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: max(0.18, motionDuration))) {
            activeDraft.wrappedValue = .default
        }
        DiagnosticsLog.shared.log("settings", "Popover \(previewLayout.rawValue) config reset to defaults (staged)")
    }

    private func openAccessibilitySettings() {
        // Motion preference lives in Accessibility → Display.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Sample configuration for the preview

/// Builds a representative `DockTileConfiguration` from stock macOS apps that are actually installed
/// on this Mac, so the embedded real panel resolves the SAME app icons (via `AppIconLoader`) the
/// user sees in their Dock — no mock tiles. Resolved once and cached for the window's lifetime.
@MainActor
enum PreviewAppCatalog {
    /// (bundle id, display name). Order = preferred display order in the preview.
    private static let candidates: [(bundleID: String, name: String)] = [
        ("com.apple.mail", "Mail"),
        ("com.apple.Safari", "Safari"),
        ("com.apple.Notes", "Notes"),
        ("com.apple.iCal", "Calendar"),
        ("com.apple.reminders", "Reminders"),
        ("com.apple.Photos", "Photos"),
        ("com.apple.AddressBook", "Contacts"),
        ("com.apple.podcasts", "Podcasts"),
        ("com.apple.Music", "Music"),
        ("com.apple.Maps", "Maps"),
        ("com.apple.MobileSMS", "Messages"),
        ("com.apple.systempreferences", "Settings"),
    ]

    private static var cached: DockTileConfiguration?

    /// A "Work" tile populated with up to 6 installed stock apps — enough that every Popover Size
    /// (4 / 5 / 6 columns) renders a genuinely different real layout. The real panel resolves each
    /// app's live icon; the install check passes because we stamp the resolved on-disk path.
    static var sampleConfiguration: DockTileConfiguration {
        if let cached { return cached }
        let workspace = NSWorkspace.shared
        var items: [AppItem] = []
        for (bundleID, name) in candidates {
            guard items.count < 6,
                  let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else { continue }
            items.append(AppItem(bundleIdentifier: bundleID, name: name, lastKnownPath: url.path))
        }
        let config = DockTileConfiguration(name: "Work", tintColor: .blue, appItems: items)
        cached = config
        return config
    }
}

extension LayoutMode: CaseIterable {
    static var allCases: [LayoutMode] { [.grid, .list] }
}

// MARK: - Popover preview canvas (shared by Popover settings, Tile Detail, About)

/// The wallpaper-style surface (`underWindowBackground`) with the REAL popover panel floating on it in
/// NSPopover-like chrome. `.natural` renders 1:1 (Tile Detail's editor); `.worstCase(height:)` zooms to
/// a fixed fit derived from the largest possible panel (Settings preview), so control changes visibly
/// spread/tighten instead of re-filling the width.
struct PopoverPreviewCanvas: View {
    enum Fit: Equatable { case natural; case worstCase(height: CGFloat) }

    let configuration: DockTileConfiguration
    let layout: LayoutMode
    var settings: PopoverSettings? = nil
    var fit: Fit = .natural
    var signature: String = ""
    /// When set, the embedded panel becomes the tile's app editor (Tile Detail). nil in Settings,
    /// which shows the panel exactly as it ships.
    var editing: PopoverEditing? = nil

    private let cornerRadius: CGFloat = 14

    /// The `.natural` fit's outer inset. One constant so the fit maths and the padding can't drift.
    private static let naturalInset: CGFloat = 22

    /// Height the `.natural` container reserves, published from inside its `GeometryReader` (which
    /// is the only place the real available width is known) and read back for the outer frame.
    @State private var naturalHeight: CGFloat? = nil

    nonisolated static func fitScale(available: CGSize, worst: CGSize) -> CGFloat {
        let fit = min((available.width - 56) / worst.width, (available.height - 44) / worst.height)
        let rawFit = min((available.width - 8) / worst.width, (available.height - 8) / worst.height)
        return min(rawFit, fit * 1.10, 1.04)
    }

    var body: some View {
        Group {
            switch fit {
            case .natural:
                naturalFit
            case .worstCase(let height):
                GeometryReader { proxy in
                    let scale = Self.fitScale(available: proxy.size, worst: Self.worstCasePanelSize(for: layout, appCount: configuration.appItems.count))
                    chrome
                        .fixedSize()
                        .scaleEffect(scale, anchor: .center)
                        .shadow(color: .black.opacity(0.28), radius: 22 * scale, y: 10 * scale)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(height: height)
            }
        }
        .background(StudioCanvasBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
    }

    /// The `.natural` fit: the real panel at 1:1 when it fits, scaled DOWN to fit when it doesn't.
    ///
    /// `StackPopoverView` pins itself to a fixed `popoverWidth` (columns x cell width), so a tile
    /// with several apps is WIDER than the fixed-width window's detail column. `.scaleEffect` alone
    /// does **not** change a view's layout size — scaling without also pinning the frame to the
    /// scaled size left the column still claiming the panel's full intrinsic width, which stretched
    /// the enclosing VStack and pushed the section header's controls (layout picker, + Add) off the
    /// window where they were clipped. So the LAYOUT width/height must be the SCALED size, and the
    /// width must come from a `GeometryReader` (which always reports the width it was *proposed*,
    /// and so can never be inflated by its own oversized content). Never scales above 1: a small
    /// tile still renders exactly 1:1.
    private var naturalFit: some View {
        let panelSize = Self.naturalPanelSize(
            layout: layout,
            appCount: configuration.appItems.count,
            settings: settings ?? PopoverSettings.load(layout: layout),
            isEditing: editing != nil,
            // Mirrors `ListPopoverView.tileName` — a cleared name draws no title row.
            hasHeader: !configuration.name.isEmpty,
            // Mirrors `StackPopoverView.showsMissingCaption` — the editor's "Not installed"
            // caption makes a grid row taller, and this canvas CLIPS what it frames.
            includesMissingCaption: editing != nil && layout == .grid
                && configuration.appItems.contains { AppInstallChecker.resolve($0).status == .missing }
        )
        return GeometryReader { proxy in
            let scale = Self.naturalScale(availableWidth: proxy.size.width, panelWidth: panelSize.width)
            let height = panelSize.height * scale + Self.naturalInset * 2
            chrome
                .fixedSize()
                .scaleEffect(scale, anchor: .center)
                .frame(width: proxy.size.width, height: height)
                .preference(key: NaturalCanvasHeightKey.self, value: height)
        }
        .frame(height: naturalHeight ?? (panelSize.height + Self.naturalInset * 2))
        .onPreferenceChange(NaturalCanvasHeightKey.self) { naturalHeight = $0 }
        // Drop the cached height when the layout flips: it was measured for the OTHER panel, and the
        // container would wear that stale height for a frame before the preference re-published.
        // The `??` fallback above is already computed from the current layout, so nil is correct.
        .onChange(of: layout) { naturalHeight = nil }
    }

    /// Scale that fits `panelWidth` (plus the canvas inset on both sides) into `availableWidth`,
    /// clamped so the panel is never blown UP. A non-positive width (the first layout pass, before
    /// the GeometryReader has a proposal) falls back to 1:1.
    nonisolated static func naturalScale(availableWidth: CGFloat, panelWidth: CGFloat) -> CGFloat {
        let usable = availableWidth - naturalInset * 2
        guard usable > 0, panelWidth > 0 else { return 1 }
        return min(1, usable / panelWidth)
    }

    /// The panel's intrinsic layout size for the ACTUAL settings and app count — the SAME formulas
    /// the real panels size themselves from (`PopoverPanelLayout`, which is also where
    /// `StackPopoverView.calculateHeight` and `ListPopoverView`'s paddings read their constants), so
    /// the canvas cannot undershoot the panel it frames. Guarded by `PopoverPreviewCanvasTests`.
    nonisolated static func naturalPanelSize(
        layout: LayoutMode,
        appCount: Int,
        settings: PopoverSettings,
        isEditing: Bool,
        hasHeader: Bool = true,
        includesMissingCaption: Bool = false
    ) -> CGSize {
        switch layout {
        case .grid:
            return PopoverPanelLayout.gridPanelSize(
                metrics: PopoverMetrics.grid(popoverSize: settings.popoverSize,
                                             tileSize: settings.tileSize,
                                             spacing: settings.spacing,
                                             showLabels: settings.showLabels),
                appCount: appCount,
                showLabels: settings.showLabels,
                includesMissingCaption: includesMissingCaption
            )
        case .list:
            // `.natural` only ever renders with `editing != nil` (see `naturalFit`), so an empty tile
            // shows `ListPopoverView`'s EDIT-mode empty state — the taller of the two — which is what
            // `listPanelSize` bills for.
            return PopoverPanelLayout.listPanelSize(
                metrics: PopoverMetrics.list(popoverSize: settings.popoverSize,
                                             tileSize: settings.tileSize,
                                             spacing: settings.spacing),
                appCount: appCount,
                isEditing: isEditing,
                hasHeader: hasHeader
            )
        }
    }

    @ViewBuilder private var panel: some View {
        Group {
            if layout == .grid {
                StackPopoverView(configuration: configuration, onLaunch: {}, showsBackground: false,
                                 isPreview: true, settingsOverride: settings, editing: editing)
            } else {
                ListPopoverView(configuration: configuration, onLaunch: {}, showsBackground: false,
                                isPreview: true, settingsOverride: settings, editing: editing)
            }
        }
        .id(signature)
    }

    private var chrome: some View {
        panel
            .background(VisualEffectView.popoverSurfaceInWindow)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .shadow(color: .black.opacity(fit == .natural ? 0.22 : 0), radius: 18, y: 8)
    }

    /// Largest footprint over every tier, at the roomiest Tile Size / Spacing / Labels combination.
    /// Only used to derive the Settings preview's fixed zoom, so control changes visibly spread and
    /// tighten instead of re-filling the width.
    ///
    /// Goes through `PopoverPanelLayout` like every other size in this file. It used to re-implement
    /// the geometry with its own literals and a different list-row formula — the exact drift the
    /// seam exists to prevent, and the reason an empty list panel was once clipped.
    private static func worstCasePanelSize(for layout: LayoutMode, appCount count: Int) -> CGSize {
        let apps = max(1, count)
        switch layout {
        case .grid:
            // Column count varies per tier, so the widest/tallest tier isn't the same one — take
            // the max of both axes across all of them.
            return PopoverSizeTier.allCases.reduce(CGSize(width: 1, height: 1)) { worst, tier in
                let size = PopoverPanelLayout.gridPanelSize(
                    metrics: PopoverMetrics.grid(popoverSize: tier, tileSize: .large,
                                                 spacing: .spacious, showLabels: true),
                    appCount: apps,
                    showLabels: true
                )
                return CGSize(width: max(worst.width, size.width),
                              height: max(worst.height, size.height))
            }
        case .list:
            // The list's width is fixed per tier and its height grows with the rows, so the
            // roomiest tier IS the worst case. Utility rows included: this preview shows the panel
            // exactly as it ships (`editing == nil`).
            return PopoverPanelLayout.listPanelSize(
                metrics: PopoverMetrics.list(popoverSize: .large, tileSize: .large, spacing: .spacious),
                appCount: apps,
                isEditing: false,
                hasHeader: true
            )
        }
    }
}

/// Publishes the `.natural` canvas height out of its `GeometryReader` (see `naturalFit`).
private struct NaturalCanvasHeightKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}
