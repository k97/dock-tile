//
//  LauncherView.swift
//  DockTile
//
//  Native macOS Dock-style launcher with vibrancy
//  Supports Stack (grid) and List (menu) layout modes
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

// MARK: - Notification for Dismissal

extension Notification.Name {
    static let dismissLauncher = Notification.Name("dismissLauncher")
    static let enableKeyboardNavigation = Notification.Name("enableKeyboardNavigation")
    static let openConfigurator = Notification.Name("openConfigurator")
    /// Posted by the ⌘, menu command to select an inline Settings pane in the main window.
    /// `object` is an optional `SettingsPane` (defaults to `.general`).
    static let openSettingsPane = Notification.Name("openSettingsPane")
    /// Posted by the `docktile://configure` deep link (a tile's Configure gear) to select that tile
    /// with Customise open in the main window. `object` is the tile's `UUID`.
    static let revealTile = Notification.Name("revealTile")
    /// The menu bar icon's "Add a Tile…" (zero tiles): runs the sidebar +'s Add flow.
    static let openAddTile = Notification.Name("openAddTile")
}

// MARK: - Launcher View (Layout Mode Router)

struct LauncherView: View {

    // MARK: - Configuration

    let configuration: DockTileConfiguration?

    // MARK: - Computed Properties

    private var layoutMode: LayoutMode {
        configuration?.layoutMode ?? .grid
    }

    // MARK: - Body

    var body: some View {
        // Route to the appropriate native popover view based on layout mode
        switch layoutMode {
        case .grid:
            StackPopoverView(
                configuration: configuration,
                onLaunch: dismissLauncher
            )
        case .list:
            ListPopoverView(
                configuration: configuration,
                onLaunch: dismissLauncher
            )
        }
    }

    // MARK: - Actions

    private func dismissLauncher() {
        NotificationCenter.default.post(name: .dismissLauncher, object: nil)
    }
}

// MARK: - Previews

#Preview("Grid Layout") {
    LauncherView(configuration: DockTileConfiguration(
        name: "mac-ai-shortcuts",
        tintColor: .blue,
        symbolEmoji: "🤖",
        layoutMode: .grid,
        appItems: [
            AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
            AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
            AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
            AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
        ]
    ))
}

#Preview("List Layout") {
    LauncherView(configuration: DockTileConfiguration(
        name: "mac-ai-shortcuts",
        tintColor: .blue,
        symbolEmoji: "🤖",
        layoutMode: .list,
        appItems: [
            AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
            AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
            AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
            AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
        ]
    ))
}
