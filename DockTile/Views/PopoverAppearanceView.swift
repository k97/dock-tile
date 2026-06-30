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
    /// Edits are staged here and only written to the shared suite on **Save** (draft/commit model),
    /// so helper popovers never read a half-applied change. The live preview renders this draft.
    @State private var draft: PopoverSettings
    /// The last-saved baseline, used to drive the Save button's dirty state and to revert on close.
    @State private var savedBaseline: PopoverSettings

    /// Seed both draft and baseline from the persisted (shared-suite) values so the preview opens on
    /// what's actually live, with no first-render flash through the defaults.
    init() {
        let loaded = PopoverSettings.load()
        _draft = State(initialValue: loaded)
        _savedBaseline = State(initialValue: loaded)
    }

    /// Convenience bindings into the draft for each control. `animation` is built explicitly because
    /// `$draft.animation` would resolve to SwiftUI's `Binding.animation(_:)` method, not the field.
    private var popoverSize: Binding<PopoverSizeTier> { $draft.popoverSize }
    private var tileSize: Binding<PopoverSizeTier> { $draft.tileSize }
    private var animation: Binding<PopoverAnimationTier> {
        Binding(get: { draft.animation }, set: { draft.animation = $0 })
    }
    private var spacing: Binding<PopoverSpacingTier> { $draft.spacing }
    private var showLabels: Binding<Bool> { $draft.showLabels }
    private var highlightOnHover: Binding<Bool> { $draft.highlightOnHover }

    /// Save is enabled only when the draft differs from what's persisted; Reset only when the draft
    /// isn't already the spec defaults.
    private var isDirty: Bool { draft != savedBaseline }
    private var isAtDefaults: Bool { draft == .default }

    /// Which layout the *preview* shows. Preview-only — the real per-tile Grid/List choice still
    /// lives on the Tile Detail screen, so flipping this never touches any tile's config.
    @State private var previewLayout: LayoutMode = .grid

    /// When the system Reduce Motion setting is on we force Animation to None and disable the
    /// control (HIG: animation speed follows the OS preference, not an in-app override).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motionDuration: Double {
        PopoverMetrics.animationDuration(draft.animation, reduceMotion: reduceMotion)
    }

    /// A signature of every value the real popover reads — changing it forces the embedded panel to
    /// re-init and re-read `PopoverSettings.load()` from the shared suite (the @AppStorage writes
    /// land there first), so the preview always mirrors the shipped rendering 1:1.
    private var previewSignature: String {
        [draft.popoverSize.rawValue, draft.tileSize.rawValue, draft.spacing.rawValue, draft.animation.rawValue,
         draft.showLabels ? "L" : "l", draft.highlightOnHover ? "H" : "h", previewLayout.rawValue]
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
        .navigationTitle(AppStrings.Settings.popover)
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
                .disabled(isAtDefaults)

                Button(AppStrings.Button.save, action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!isDirty)
            }
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
                                 settingsOverride: draft)
            } else {
                ListPopoverView(configuration: PreviewAppCatalog.sampleConfiguration,
                                onLaunch: {}, showsBackground: false, isPreview: true,
                                settingsOverride: draft)
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
            sectionHeader(AppStrings.Settings.popover)
            card {
                segmentedRow(AppStrings.Label.popoverLayout, selection: $previewLayout, options: LayoutMode.allCases) {
                    $0.displayName
                }
                divider
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

    /// Commit the staged draft to the shared suite. Helpers pick it up on their next popover open.
    private func save() {
        draft.persist()
        savedBaseline = draft
        AnalyticsService.shared.log(.settingChanged, ["setting": "popover_appearance", "saved": true])
        DiagnosticsLog.shared.log("settings", "Popover appearance saved")
    }

    /// Stage the spec defaults into the draft (previewed live). The user still presses **Save** to
    /// commit — consistent with the explicit-save model.
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: max(0.18, motionDuration))) {
            draft = .default
        }
        DiagnosticsLog.shared.log("settings", "Popover appearance reset to defaults (staged)")
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
