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
        .navigationTitle(AppStrings.Settings.popoverAppearance)
        .toolbar {
            // HIG: window-level actions live in the toolbar. Reset is the secondary (plain bordered)
            // button; Save is the primary (accent-tinted, prominent) action on the trailing edge.
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

    /// Fixed hero height; the real popover sits on the studio-canvas treatment (same backdrop as the
    /// Customise-Tile icon studio).
    private let heroHeight: CGFloat = 300

    /// Zoomed out so the panel reads as a floating popover with breathing room. The scale is FIXED
    /// per layout (derived from the worst-case config), NOT the current selection — so changing
    /// Spacing / Tile Size visibly spreads or tightens the tiles instead of the panel re-filling the
    /// width and cancelling the change. `.scaleEffect` preserves `.onHover` hit-testing at the
    /// visual position, so real mouse hover still lands on the tiles. Capped so it never zooms in.
    private var heroPreview: some View {
        GeometryReader { proxy in
            let worst = worstCasePanelSize(for: previewLayout)
            // Fit the worst-case panel with a comfortable margin, then zoom in ~10% so the panel
            // reads larger on the canvas. `rawFit` (a near-flush fit) clamps the boosted scale so the
            // extra zoom can never clip the panel against the hero edges.
            let fit = min((proxy.size.width - 56) / worst.width, (heroHeight - 44) / worst.height)
            let rawFit = min((proxy.size.width - 8) / worst.width, (heroHeight - 8) / worst.height)
            let scale = min(rawFit, fit * 1.10, 1.04)
            ZStack {
                popoverChrome
                    .fixedSize()
                    .scaleEffect(scale, anchor: .center)
                    // NSPopover-style drop shadow so the panel reads as floating on the canvas.
                    .shadow(color: .black.opacity(0.28), radius: 22 * scale, y: 10 * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .background(StudioCanvasBackgroundView().ignoresSafeArea(edges: .top))
        .animation(.easeInOut(duration: max(0.18, motionDuration)), value: previewSignature)
    }

    /// Largest panel footprint achievable for `layout` across all size/spacing tiers, computed from
    /// the same `PopoverMetrics` the real panel uses (grid widest at Large columns, tallest at Small
    /// columns → most rows). Drives the FIXED preview zoom so it never clips on any selection.
    private func worstCasePanelSize(for layout: LayoutMode) -> CGSize {
        let count = PreviewAppCatalog.sampleConfiguration.appItems.count
        switch layout {
        case .grid:
            var maxW: CGFloat = 1, maxH: CGFloat = 1
            for size in PopoverSizeTier.allCases {
                let m = PopoverMetrics.grid(popoverSize: size, tileSize: .large, spacing: .spacious, showLabels: true)
                let cols = max(1, min(m.columns, count))
                let rows = max(1, Int(ceil(Double(count) / Double(cols))))
                let w = m.cellWidth * CGFloat(cols) + m.gap * CGFloat(cols - 1) + 32   // gridHorizontalPadding * 2
                let itemH = m.iconSize + 18 + 4                                         // icon + label line + cell padding
                let h = 36 + CGFloat(rows) * itemH + CGFloat(rows - 1) * m.gap + 32     // header + grid + top/bottom pad
                maxW = max(maxW, w); maxH = max(maxH, h)
            }
            return CGSize(width: maxW, height: maxH)
        case .list:
            let m = PopoverMetrics.list(popoverSize: .large, tileSize: .large, spacing: .spacious)
            let rowH = max(m.iconSize, m.fontSize) + m.rowVerticalPadding * 2 + 4
            let h = 33 + CGFloat(count) * rowH + 9 + 42 + 16                            // header + rows + divider + 2 utility + outer pad
            return CGSize(width: m.width, height: h)
        }
    }

    /// macOS-popover corner radius for the preview chrome. NSPopover's exact radius is private and
    /// larger on Tahoe's Liquid Glass; 14pt (continuous) matches the design spec's popover card and
    /// the Tahoe rounding. The whole panel is scaled by the hero, so the visible radius scales too.
    private let popoverCornerRadius: CGFloat = 14

    /// The ACTUAL panel the helper tiles render — `StackPopoverView` / `ListPopoverView` from
    /// `NativePopoverViews` — so the preview is a true 1:1 of what ships. `.id(previewSignature)`
    /// re-inits it on any control change (it reads `PopoverSettings.load()` at init). `isPreview`
    /// keeps it interactive for *hover* while neutralising every action — so the user feels the real
    /// "Highlight on Hover" with their mouse, and a click never launches an app or opens anything.
    @ViewBuilder
    private var realPopoverPanel: some View {
        Group {
            if previewLayout == .grid {
                StackPopoverView(configuration: PreviewAppCatalog.sampleConfiguration,
                                 onLaunch: {}, showsBackground: false, isPreview: true,
                                 settingsOverride: activeDraft.wrappedValue)
            } else {
                ListPopoverView(configuration: PreviewAppCatalog.sampleConfiguration,
                                onLaunch: {}, showsBackground: false, isPreview: true,
                                settingsOverride: activeDraft.wrappedValue)
            }
        }
        .id(previewSignature)
    }

    /// Reproduces the real popover's *container chrome* around the embedded content: the same
    /// `.popover` Liquid Glass material (blended within-window so it stays vibrant in-app) clipped to
    /// the popover's continuous corner radius, with a hairline Liquid-Glass edge. The shadow is added
    /// by the hero so it can scale with the panel.
    private var popoverChrome: some View {
        realPopoverPanel
            .background(VisualEffectView.popoverSurfaceInWindow)
            .clipShape(RoundedRectangle(cornerRadius: popoverCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: popoverCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
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
                Text(AppStrings.Settings.popoverConfigure.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
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
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
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
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(NSColorBackgroundView.formGroup)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
