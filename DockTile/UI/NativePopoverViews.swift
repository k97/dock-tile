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

/// NSViewRepresentable that captures keyboard events for navigation
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

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            onArrowKey?(.up)
        case 125: // Down arrow
            onArrowKey?(.down)
        case 123: // Left arrow
            onArrowKey?(.left)
        case 124: // Right arrow
            onArrowKey?(.right)
        case 36, 76: // Return, Enter
            onEnter?()
        case 53: // Escape
            onEscape?()
        default:
            super.keyDown(with: event)
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

    @State private var selectedIndex: Int? = nil
    @State private var keyboardNavigationEnabled = false

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? "DockTile"
    }

    // Grid configuration: 3 columns (like native Dock folders)
    private let columns = [
        GridItem(.fixed(100), spacing: 8),
        GridItem(.fixed(100), spacing: 8),
        GridItem(.fixed(100), spacing: 8)
    ]

    private let columnCount = 3

    // Layout constants
    private let headerHeight: CGFloat = 36
    private let popoverWidth: CGFloat = 340
    private let gridTopPadding: CGFloat = 16
    private let gridBottomPadding: CGFloat = 16
    private let gridHorizontalPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Anchored Header (Fixed - doesn't scroll)
            Text(tileName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: headerHeight)

            // MARK: Scrollable Grid Content
            if apps.isEmpty {
                emptyStateView
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            StackAppItem(
                                app: app,
                                isSelected: selectedIndex == index,
                                onLaunch: onLaunch
                            )
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
        // LIQUID GLASS: Single translucent surface for header + grid
        .background(Color.clear)
        .background(VisualEffectView.liquidGlass)
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
            Text("No apps configured")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Configure to add apps")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func calculateHeight() -> CGFloat {
        guard !apps.isEmpty else { return 180 }

        // Calculate grid content height
        let rows = ceil(Double(apps.count) / Double(columnCount))
        let itemHeight: CGFloat = 100  // Approximate height per grid item
        let gridContentHeight = CGFloat(rows) * itemHeight + gridTopPadding + gridBottomPadding

        // Total = header + grid content, capped at max
        let totalHeight = headerHeight + gridContentHeight
        return min(totalHeight, 400)
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
        guard index < apps.count else { return }
        let app = apps[index]
        launchApp(app)
        onLaunch()
    }

    private func launchApp(_ app: AppItem) {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, _ in }
        }
    }
}

// MARK: - Stack App Item (Large Icon + Label)

struct StackAppItem: View {
    let app: AppItem
    let isSelected: Bool  // Keyboard navigation selection only
    let onLaunch: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Large app icon (64x64 like native Dock folders)
            appIconView
                .frame(width: 64, height: 64)

            // App name - truncated with ellipsis
            // Use hierarchical style for vibrancy optimization
            Text(app.name)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 90)
        }
        .padding(6)
        .background(
            // Keyboard selection only - no hover effect for grid view
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var appIconView: some View {
        if let nsImage = getAppIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }

    private func getAppIcon() -> NSImage? {
        // Try stored icon data first
        if let iconData = app.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

        // Get from bundle identifier (this returns clean icon without alias arrow)
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // Try common paths
        let searchPaths = [
            "/Applications/\(app.name).app",
            "/System/Applications/\(app.name).app",
            "/Applications/Utilities/\(app.name).app",
            "\(NSHomeDirectory())/Applications/\(app.name).app"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        return nil
    }
}

// MARK: - List Popover View (Context Menu Style)

/// Native macOS Dock folder "List" view with small icons in vertical rows
/// Matches the native Dock context menu appearance
struct ListPopoverView: View {
    let configuration: DockTileConfiguration?
    let onLaunch: () -> Void

    @State private var selectedIndex: Int? = nil
    @State private var keyboardNavigationEnabled = false

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? "DockTile"
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
                            onLaunch: onLaunch
                        )
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
                title: "Options",
                hasSubmenu: true,
                action: { /* Options submenu */ }
            )

            ListMenuRow(
                icon: "folder",
                title: "Open in Finder",
                hasSubmenu: false,
                action: openInFinder
            )
        }
        .padding(.vertical, 8)
        .frame(width: 220)
        // LIQUID GLASS: Transparent SwiftUI background to allow NSVisualEffectView through
        .background(Color.clear)
        .background(VisualEffectView.liquidGlassMenu)
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
        Text("No apps configured")
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
        guard index < apps.count else { return }
        let app = apps[index]
        launchApp(app)
        onLaunch()
    }

    private func launchApp(_ app: AppItem) {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, _ in }
        }
    }

    private func openInFinder() {
        // Open the Applications folder or configured folder
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        onLaunch()
    }
}

// MARK: - List App Row (Small Icon + Name)

struct ListAppRow: View {
    let app: AppItem
    let isSelected: Bool
    let onLaunch: () -> Void

    @State private var isHovered = false

    /// Whether to show highlight (selection takes priority over hover)
    private var isHighlighted: Bool {
        isSelected || isHovered
    }

    var body: some View {
        HStack(spacing: 8) {
            // Small icon (16x16 like native menu items)
            appIconView
                .frame(width: 16, height: 16)

            // App name - white text on selection for contrast (works in light & dark mode)
            Text(app.name)
                .font(.system(size: 13))
                .foregroundStyle(isHighlighted ? .white : .primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            // LIQUID GLASS: Use system selectedContentBackgroundColor for vibrant selection
            // This maintains the glassy look even when selected
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHighlighted ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        if let nsImage = getAppIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func getAppIcon() -> NSImage? {
        if let iconData = app.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        let searchPaths = [
            "/Applications/\(app.name).app",
            "/System/Applications/\(app.name).app",
            "/Applications/Utilities/\(app.name).app",
            "\(NSHomeDirectory())/Applications/\(app.name).app"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        return nil
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
                    .foregroundStyle(isHovered ? .white : .primary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(isHovered ? .white : .primary)

                Spacer()

                if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isHovered ? .white.opacity(0.7) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                // LIQUID GLASS: Use system selectedContentBackgroundColor for vibrant hover
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
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
