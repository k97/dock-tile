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
}

// MARK: - Launcher View (Layout Mode Router)

struct LauncherView: View {

    // MARK: - Design Tokens (Kept for backwards compatibility)

    enum DesignTokens {
        // Colors
        static let background = Color(hex: "#F5F5F7").opacity(0.8)
        static let textColor = Color(hex: "#1D1D1F")
        static let strokeColor = Color.white.opacity(0.5)

        // Spacing
        static let gridPadding: CGFloat = 16
        static let itemSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 24

        // Typography
        static let appNameSize: CGFloat = 11
        static let iconSize: CGFloat = 48
    }

    // MARK: - Configuration

    let configuration: DockTileConfiguration?

    // MARK: - Computed Properties

    private var layoutMode: LayoutMode {
        configuration?.layoutMode ?? .grid2x3
    }

    // MARK: - Body

    var body: some View {
        // Route to the appropriate native popover view based on layout mode
        switch layoutMode {
        case .grid2x3:
            StackPopoverView(
                configuration: configuration,
                onLaunch: dismissLauncher
            )
        case .horizontal1x6:
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

#Preview("Stack Layout") {
    LauncherView(configuration: DockTileConfiguration(
        name: "mac-ai-shortcuts",
        tintColor: .blue,
        symbolEmoji: "🤖",
        layoutMode: .grid2x3,
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
        layoutMode: .horizontal1x6,
        appItems: [
            AppItem(bundleIdentifier: "com.google.gemini", name: "Google Gemini"),
            AppItem(bundleIdentifier: "com.google.notebooklm", name: "NotebookLM"),
            AppItem(bundleIdentifier: "com.openai.chatgpt", name: "ChatGPT"),
            AppItem(bundleIdentifier: "com.anthropic.claude", name: "Claude")
        ]
    ))
}
