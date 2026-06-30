//
//  NativePopoverViews.swift
//  DockTile
//
//  Native macOS Dock-style popover views with vibrancy
//  Mimics the native Dock folder Stack and List views
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

// MARK: - Arrow Direction Enum

enum ArrowDirection {
    case up, down, left, right
}

// MARK: - Keyboard Navigation Handler

/// NSViewRepresentable that captures keyboard events for popover navigation.
///
/// **Why NSView instead of SwiftUI `.onKeyPress`?**
/// The popover is hosted inside an NSPopover which manages its own key window status.
/// SwiftUI's `.onKeyPress` doesn't reliably receive events when the popover's NSWindow
/// isn't the key window. Using an NSView subclass as first responder ensures we capture
/// keyboard events regardless of window focus state - critical for Dock popover interaction.
struct KeyboardNavigationHandler: NSViewRepresentable {
    let enabled: Bool
    let onArrowKey: (ArrowDirection) -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyboardCaptureView {
        let view = KeyboardCaptureView()
        view.onArrowKey = onArrowKey
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureView, context: Context) {
        nsView.onArrowKey = onArrowKey
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape

        if enabled {
            // Make key window and first responder
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// Custom NSView that captures keyboard events
final class KeyboardCaptureView: NSView {
    var onArrowKey: ((ArrowDirection) -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    /// Key codes from Carbon.HIToolbox (kVK_* constants)
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: onArrowKey?(.up)      // kVK_UpArrow
        case 125: onArrowKey?(.down)    // kVK_DownArrow
        case 123: onArrowKey?(.left)    // kVK_LeftArrow
        case 124: onArrowKey?(.right)   // kVK_RightArrow
        case 36, 76: onEnter?()         // kVK_Return, kVK_ANSI_KeypadEnter
        case 53: onEscape?()            // kVK_Escape
        default: super.keyDown(with: event)
        }
    }
}

// MARK: - Visual Effect View (NSVisualEffectView Wrapper for Liquid Glass)

/// NSViewRepresentable wrapper for NSVisualEffectView
/// Configured for the macOS "Liquid Glass" aesthetic with proper vibrancy
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    let isEmphasized: Bool

    /// Creates a Liquid Glass visual effect view
    /// - Parameters:
    ///   - material: The material type (.popover or .menu for maximum translucency)
    ///   - blendingMode: Must be .behindWindow for Dock/wallpaper bleed-through
    ///   - state: Must be .active to maintain vibrancy when clicking away
    ///   - isEmphasized: Whether the view should appear emphasized (brighter)
    init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isEmphasized = isEmphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configureView(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configureView(nsView)
    }

    private func configureView(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        // CRITICAL: state must be .active to maintain "liquid" effect when app loses focus
        // Otherwise it turns flat gray
        view.state = state
        view.isEmphasized = isEmphasized
        view.wantsLayer = true
        // Ensure the view doesn't add its own shadow (let NSPopover handle it)
        view.shadow = nil
    }
}

/// Convenience initializer for common Liquid Glass configurations
extension VisualEffectView {
    /// Standard Liquid Glass popover background
    static var liquidGlass: VisualEffectView {
        VisualEffectView(
            material: .popover,
            blendingMode: .behindWindow,
            state: .active
        )
    }

    /// Menu-style Liquid Glass (slightly more translucent)
    static var liquidGlassMenu: VisualEffectView {
        VisualEffectView(
            material: .menu,
            blendingMode: .behindWindow,
            state: .active
        )
    }

    /// Same `.popover` Liquid Glass material as the real popover, but blended `.withinWindow` so it
    /// stays vibrant when embedded INSIDE a window (e.g. the Settings → Popover live preview, where
    /// `.behindWindow` would flatten to grey). Use to reproduce the popover surface in-app.
    static var popoverSurfaceInWindow: VisualEffectView {
        VisualEffectView(
            material: .popover,
            blendingMode: .withinWindow,
            state: .active
        )
    }
}

// MARK: - Stack (Grid) Popover View

/// Native macOS Dock folder "Stack" view with large icons in a grid
/// Matches the native Applications Dock folder popover:
/// - Fixed/anchored title at top (doesn't scroll)
/// - Vertically scrolling grid below
/// - Scrollbar only appears in grid area
/// - Liquid Glass effect across entire background
struct StackPopoverView: View {
    let configuration: DockTileConfiguration?
    let onLaunch: () -> Void
    /// When false, the view skips its own Liquid Glass background — the host supplies the surface
    /// (used by the Settings preview, which wraps it in popover chrome). Real popover keeps it ON.
    var showsBackground: Bool = true
    /// When true (Settings preview), the panel stays interactive for hover but performs NO actions —
    /// clicks never launch apps or open the configurator. The real popover leaves this false.
    var isPreview: Bool = false

    @State private var selectedIndex: Int? = nil
    @State private var keyboardNavigationEnabled = false

    // Observe IconStyleManager for icon style changes
    // Used to force view recreation via .id() modifier
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Global popover-appearance settings, read once from the shared suite when this popover is
    /// built. Helpers render the popover, so this picks up the main app's Settings → Popover values
    /// on the next open (matches the icon-style propagation model).
    private let settings = PopoverSettings.load()

    private var metrics: PopoverGridMetrics {
        PopoverMetrics.grid(
            popoverSize: settings.popoverSize,
            tileSize: settings.tileSize,
            spacing: settings.spacing,
            showLabels: settings.showLabels
        )
    }

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? AppStrings.appName
    }

    // MARK: - Dynamic Grid Configuration

    /// Column count from the global Popover Size (Small 4 / Medium 5 / Large 6), capped at the app
    /// count so a tile with few apps stays tight rather than padding out empty trailing columns.
    private var columnCount: Int {
        max(1, min(metrics.columns, max(1, apps.count)))
    }

    /// Grid columns sized by Tile Size; spacing by Spacing.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(metrics.cellWidth), spacing: metrics.gap), count: columnCount)
    }

    /// Popover width from cell width × columns.
    private var popoverWidth: CGFloat {
        metrics.cellWidth * CGFloat(columnCount) + metrics.gap * CGFloat(columnCount - 1) + gridHorizontalPadding * 2
    }

    // Layout constants
    private let headerHeight: CGFloat = 36
    private let gridTopPadding: CGFloat = 16
    private let gridBottomPadding: CGFloat = 16
    private let gridHorizontalPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Anchored Header (Fixed - doesn't scroll)
            HStack {
                // Invisible spacer to balance the gear icon and keep title centered
                Color.clear
                    .frame(width: 28, height: 28)

                Spacer()

                Text(tileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                // Settings gear icon — opens main app to configure this tile
                Button(action: openConfigurator) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(AppStrings.Menu.configureTile)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: headerHeight)

            // MARK: Scrollable Grid Content
            if apps.isEmpty {
                emptyStateView
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: metrics.gap) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            StackAppItem(
                                app: app,
                                isSelected: selectedIndex == index,
                                iconSize: metrics.iconSize,
                                cellWidth: metrics.cellWidth,
                                showLabel: settings.showLabels,
                                highlightOnHover: settings.highlightOnHover,
                                onLaunch: onLaunch
                            )
                            // Composite ID forces SwiftUI to destroy/recreate the view when icon style
                            // changes, which clears NSWorkspace's cached icon and re-fetches the
                            // correct variant (Default/Dark/Clear/Tinted) from the app bundle.
                            .id("\(app.id)-\(iconStyleManager.currentStyle.rawValue)")
                            .onTapGesture {
                                launchAppAt(index: index)
                            }
                        }
                    }
                    .padding(.top, gridTopPadding)
                    .padding(.bottom, gridBottomPadding)
                    .padding(.horizontal, gridHorizontalPadding)
                }
            }
        }
        .frame(width: popoverWidth, height: calculateHeight())
        // LIQUID GLASS: Single translucent surface for header + grid (host-supplied in previews).
        .background(Color.clear)
        .background {
            if showsBackground { VisualEffectView.liquidGlass }
        }
        .onReceive(NotificationCenter.default.publisher(for: .enableKeyboardNavigation)) { _ in
            keyboardNavigationEnabled = true
            selectedIndex = apps.isEmpty ? nil : 0
        }
        .background(KeyboardNavigationHandler(
            enabled: keyboardNavigationEnabled,
            onArrowKey: handleArrowKey,
            onEnter: handleEnter,
            onEscape: handleEscape
        ))
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(AppStrings.Empty.noApps)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(AppStrings.Subtitle.configureToAdd)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func calculateHeight() -> CGFloat {
        guard !apps.isEmpty else { return 180 }

        // Item height = icon + (label line, when shown) + cell padding. Rows spaced by Spacing.
        let rows = ceil(Double(apps.count) / Double(columnCount))
        let labelHeight: CGFloat = settings.showLabels ? 4 + 14 : 0
        let itemHeight = metrics.iconSize + labelHeight + 4  // 2pt cell padding top+bottom
        let gridContentHeight = CGFloat(rows) * itemHeight
            + CGFloat(max(0, Int(rows) - 1)) * metrics.gap
            + gridTopPadding + gridBottomPadding

        // Total = header + grid content, capped at max
        let totalHeight = headerHeight + gridContentHeight
        return min(totalHeight, 600)
    }

    // MARK: - Keyboard Navigation

    private func handleArrowKey(_ direction: ArrowDirection) {
        guard !apps.isEmpty else { return }

        let current = selectedIndex ?? 0
        var newIndex = current

        switch direction {
        case .up:
            newIndex = max(0, current - columnCount)
        case .down:
            newIndex = min(apps.count - 1, current + columnCount)
        case .left:
            newIndex = max(0, current - 1)
        case .right:
            newIndex = min(apps.count - 1, current + 1)
        }

        selectedIndex = newIndex
    }

    private func handleEnter() {
        if let index = selectedIndex, index < apps.count {
            launchAppAt(index: index)
        }
    }

    private func handleEscape() {
        NotificationCenter.default.post(name: .dismissLauncher, object: nil)
    }

    private func launchAppAt(index: Int) {
        guard !isPreview, index < apps.count else { return }
        AppLauncher.launch(apps[index])
        onLaunch()
    }

    private func openConfigurator() {
        guard !isPreview else { return }
        NotificationCenter.default.post(name: .openConfigurator, object: nil)
        onLaunch()
    }
}

// MARK: - Stack App Item (Large Icon + Label)

struct StackAppItem: View {
    let app: AppItem
    let isSelected: Bool  // Keyboard navigation selection
    let iconSize: CGFloat
    let cellWidth: CGFloat
    let showLabel: Bool
    let highlightOnHover: Bool
    let onLaunch: () -> Void

    @State private var isHovered = false

    // Observe IconStyleManager for icon style changes
    // This triggers view refresh when system icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Mouse hover uses the subtle Liquid-Glass fill (`.quaternary`) like typical Mac apps; the
    /// stronger accent is reserved for keyboard-focus selection (accessibility). Hover honours the
    /// global "Highlight on Hover" toggle.
    private var highlightStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor)) }
        if highlightOnHover && isHovered { return AnyShapeStyle(.quaternary) }
        return AnyShapeStyle(Color.clear)
    }

    var body: some View {
        // Reference iconStyleManager.currentStyle to trigger re-render when icon style changes
        let _ = iconStyleManager.currentStyle

        VStack(spacing: 4) {
            // App icon, sized by the global Tile Size setting.
            appIconView
                .frame(width: iconSize, height: iconSize)

            if showLabel {
                // App name - truncated with ellipsis. Use hierarchical style for vibrancy.
                Text(app.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: cellWidth)
            }
        }
        // Keep the interactive cell ≥44pt even when the glyph is smaller (HIG hit target).
        .frame(minWidth: 44, minHeight: 44)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlightStyle)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var appIconView: some View {
        // Resolved synchronously (no @State/onAppear) so a deleted app never flashes its stale
        // cached icon before the placeholder appears.
        if AppInstallChecker.resolve(app).status == .missing {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: iconSize * 0.5))
                .foregroundStyle(.secondary)
        } else if let nsImage = AppIconLoader.icon(for: app) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app")
                .font(.system(size: iconSize * 0.5))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - List Popover View (Context Menu Style)

/// Native macOS Dock folder "List" view with small icons in vertical rows
/// Matches the native Dock context menu appearance
struct ListPopoverView: View {
    let configuration: DockTileConfiguration?
    let onLaunch: () -> Void
    /// When false, the view skips its own Liquid Glass background (host supplies the surface).
    var showsBackground: Bool = true
    /// When true (Settings preview), the panel stays interactive for hover but performs no actions.
    var isPreview: Bool = false

    @State private var selectedIndex: Int? = nil
    @State private var keyboardNavigationEnabled = false

    // Observe IconStyleManager for icon style changes
    // Used to force view recreation via .id() modifier
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Global popover-appearance settings, read once when the popover is built (see StackPopoverView).
    private let settings = PopoverSettings.load()

    private var metrics: PopoverListMetrics {
        PopoverMetrics.list(
            popoverSize: settings.popoverSize,
            tileSize: settings.tileSize,
            spacing: settings.spacing
        )
    }

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? AppStrings.appName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title header (like native folder name)
            // Use hierarchical style for vibrancy
            if !tileName.isEmpty {
                Text(tileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            // App list
            if apps.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        ListAppRow(
                            app: app,
                            isSelected: selectedIndex == index,
                            metrics: metrics,
                            highlightOnHover: settings.highlightOnHover,
                            onLaunch: onLaunch
                        )
                        // Force view recreation when icon style changes
                        // This clears NSWorkspace icon cache for this view
                        .id("\(app.id)-\(iconStyleManager.currentStyle.rawValue)")
                        .onTapGesture {
                            launchAppAt(index: index)
                        }
                    }
                }
            }

            // Separator - use hierarchical opacity for vibrancy
            Divider()
                .padding(.vertical, 4)

            // Utility items
            ListMenuRow(
                icon: "gearshape",
                title: AppStrings.Menu.configure,
                hasSubmenu: false,
                action: openConfigurator
            )

            ListMenuRow(
                icon: "folder",
                title: AppStrings.Menu.openInFinder,
                hasSubmenu: false,
                action: openInFinder
            )
        }
        .padding(.vertical, 8)
        .frame(width: metrics.width)
        // LIQUID GLASS: Transparent SwiftUI background to allow NSVisualEffectView through
        .background(Color.clear)
        .background {
            if showsBackground { VisualEffectView.liquidGlassMenu }
        }
        .onReceive(NotificationCenter.default.publisher(for: .enableKeyboardNavigation)) { _ in
            keyboardNavigationEnabled = true
            selectedIndex = apps.isEmpty ? nil : 0
        }
        .background(KeyboardNavigationHandler(
            enabled: keyboardNavigationEnabled,
            onArrowKey: handleArrowKey,
            onEnter: handleEnter,
            onEscape: handleEscape
        ))
    }

    private var emptyStateView: some View {
        Text(AppStrings.Empty.noApps)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }

    // MARK: - Keyboard Navigation

    private func handleArrowKey(_ direction: ArrowDirection) {
        guard !apps.isEmpty else { return }

        let current = selectedIndex ?? 0
        var newIndex = current

        switch direction {
        case .up:
            newIndex = max(0, current - 1)
        case .down:
            newIndex = min(apps.count - 1, current + 1)
        case .left, .right:
            // No horizontal navigation in list view
            break
        }

        selectedIndex = newIndex
    }

    private func handleEnter() {
        if let index = selectedIndex, index < apps.count {
            launchAppAt(index: index)
        }
    }

    private func handleEscape() {
        NotificationCenter.default.post(name: .dismissLauncher, object: nil)
    }

    private func launchAppAt(index: Int) {
        guard !isPreview, index < apps.count else { return }
        AppLauncher.launch(apps[index])
        onLaunch()
    }

    private func openConfigurator() {
        guard !isPreview else { return }
        NotificationCenter.default.post(name: .openConfigurator, object: nil)
        onLaunch()
    }

    private func openInFinder() {
        guard !isPreview else { return }
        // Open the Applications folder or configured folder
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        onLaunch()
    }
}

// MARK: - List App Row (Small Icon + Name)

struct ListAppRow: View {
    let app: AppItem
    let isSelected: Bool
    let metrics: PopoverListMetrics
    let highlightOnHover: Bool
    let onLaunch: () -> Void

    @State private var isHovered = false

    // Observe IconStyleManager for icon style changes
    // This triggers view refresh when system icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    /// Mouse hover uses the subtle Liquid-Glass fill (`.quaternary`); the stronger accent is kept for
    /// keyboard-focus selection. Hover honours the global "Highlight on Hover" toggle.
    private var highlightStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor)) }
        if highlightOnHover && isHovered { return AnyShapeStyle(.quaternary) }
        return AnyShapeStyle(Color.clear)
    }

    var body: some View {
        // Reference iconStyleManager.currentStyle to trigger re-render when icon style changes
        let _ = iconStyleManager.currentStyle

        HStack(spacing: metrics.rowSpacing) {
            // Icon, sized by the global Tile Size setting.
            appIconView
                .frame(width: metrics.iconSize, height: metrics.iconSize)

            // White text on the accent keyboard-selection; normal text on the subtle hover fill.
            Text(app.name)
                .font(.system(size: metrics.fontSize))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, metrics.rowVerticalPadding)
        // Keep the row hit target ≥44pt wide even at the smallest tile/spacing tier.
        .frame(minHeight: 28)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(highlightStyle)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        // Resolved synchronously so a deleted app shows the placeholder, not its stale icon.
        if AppInstallChecker.resolve(app).status == .missing {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: metrics.iconSize * 0.75))
                .foregroundStyle(.secondary)
        } else if let nsImage = AppIconLoader.icon(for: app) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: metrics.iconSize * 0.75))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - List Menu Row (Utility Items)

struct ListMenuRow: View {
    let icon: String
    let title: String
    let hasSubmenu: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                // Subtle Liquid-Glass hover fill (matches the app rows), not the bold accent.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Previews

#Preview("Stack View") {
    StackPopoverView(
        configuration: DockTileConfiguration(
            name: "mac-ai-shortcuts",
            tintColor: .blue,
            symbolEmoji: "🤖",
            appItems: [
                AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
                AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
                AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
                AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
            ]
        ),
        onLaunch: {}
    )
    .frame(width: 340, height: 280)
}

#Preview("List View") {
    ListPopoverView(
        configuration: DockTileConfiguration(
            name: "mac-ai-shortcuts",
            tintColor: .blue,
            symbolEmoji: "🤖",
            appItems: [
                AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
                AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
                AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
                AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
            ]
        ),
        onLaunch: {}
    )
}
