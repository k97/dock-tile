//
//  LauncherView.swift
//  DockTile
//
//  Medical White launcher grid with Liquid Glass aesthetic
//  Xiaomi/HOTO inspired minimalist design
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

// MARK: - Notification for Dismissal

extension Notification.Name {
    static let dismissLauncher = Notification.Name("dismissLauncher")
}

struct LauncherView: View {

    // MARK: - Design Tokens (Medical White Aesthetic)

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

    // MARK: - State

    @State private var isVisible = false

    // MARK: - Computed Properties

    private var apps: [AppItem] {
        configuration?.appItems ?? []
    }

    private var tileName: String {
        configuration?.name ?? "DockTile"
    }

    private var layoutMode: LayoutMode {
        configuration?.layoutMode ?? .grid2x3
    }

    private var frameSize: (width: CGFloat, height: CGFloat) {
        switch layoutMode {
        case .grid2x3:
            return (280, 200)  // Compact grid
        case .horizontal1x6:
            return (400, 90)   // Compact horizontal
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // App grid only - no header, popover handles chrome
            appGridView
                .padding(DesignTokens.gridPadding)
        }
        // No custom background - NSPopover provides native appearance
        .frame(width: frameSize.width, height: frameSize.height)
        .onAppear {
            isVisible = true
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(tileName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DesignTokens.textColor.opacity(0.6))

            Spacer()

            // App count indicator
            Text("\(apps.count) apps")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(DesignTokens.textColor.opacity(0.3))
        }
        .padding(.horizontal, DesignTokens.gridPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var appGridView: some View {
        if apps.isEmpty {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "app.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.textColor.opacity(0.3))
                Text("No apps configured")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.textColor.opacity(0.5))
                Text("Right-click → Configure to add apps")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.textColor.opacity(0.3))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if layoutMode == .grid2x3 {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DesignTokens.itemSpacing),
                    GridItem(.flexible(), spacing: DesignTokens.itemSpacing),
                    GridItem(.flexible(), spacing: DesignTokens.itemSpacing)
                ],
                spacing: DesignTokens.itemSpacing
            ) {
                ForEach(apps.prefix(6)) { app in
                    AppIconButton(app: app, onLaunch: dismissLauncher)
                }
            }
        } else {
            // Horizontal 1x6 layout
            HStack(spacing: DesignTokens.itemSpacing) {
                ForEach(apps.prefix(6)) { app in
                    AppIconButton(app: app, onLaunch: dismissLauncher)
                }
            }
        }
    }

    // MARK: - Actions

    private func dismissLauncher() {
        NotificationCenter.default.post(name: .dismissLauncher, object: nil)
    }
}

// MARK: - App Icon Button Component

struct AppIconButton: View {
    let app: AppItem
    let onLaunch: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            // App icon - no background, just the icon
            appIconView
                .frame(width: 48, height: 48)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)

            // App name
            Text(app.name)
                .font(.system(size: LauncherView.DesignTokens.appNameSize, weight: .regular, design: .default))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            launchApp()
        }
    }

    // MARK: - App Icon View

    @ViewBuilder
    private var appIconView: some View {
        // Try to get actual app icon
        if let nsImage = getAppIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            // Fallback to SF Symbol
            Image(systemName: "app")
                .font(.system(size: 24))
                .foregroundColor(LauncherView.DesignTokens.textColor)
        }
    }

    private func getAppIcon() -> NSImage? {
        // First try from stored icon data
        if let iconData = app.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

        // Try to get from bundle identifier
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

    // MARK: - App Launching

    private func launchApp() {
        print("🚀 Launching: \(app.name)")

        let workspace = NSWorkspace.shared

        // Try by bundle identifier first
        if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    print("❌ Failed to launch \(app.name): \(error.localizedDescription)")
                } else {
                    print("✅ Launched \(app.name)")
                }
            }
        } else {
            // Fallback: try to find by name in /Applications
            let searchPaths = [
                "/Applications/\(app.name).app",
                "/System/Applications/\(app.name).app",
                "/Applications/Utilities/\(app.name).app"
            ]

            for path in searchPaths {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    let config = NSWorkspace.OpenConfiguration()
                    workspace.openApplication(at: url, configuration: config) { _, error in
                        if let error = error {
                            print("❌ Failed to launch \(app.name): \(error.localizedDescription)")
                        } else {
                            print("✅ Launched \(app.name) from \(path)")
                        }
                    }
                    break
                }
            }
        }

        // Dismiss the popover
        onLaunch()
    }
}

// MARK: - Preview

#Preview {
    LauncherView(configuration: DockTileConfiguration(
        name: "Dev Tools",
        tintColor: .blue,
        symbolEmoji: "🛠️",
        appItems: [
            AppItem(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode"),
            AppItem(bundleIdentifier: "com.apple.Terminal", name: "Terminal"),
            AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari"),
            AppItem(bundleIdentifier: "com.apple.Notes", name: "Notes"),
            AppItem(bundleIdentifier: "com.apple.Music", name: "Music"),
            AppItem(bundleIdentifier: "com.apple.Photos", name: "Photos")
        ]
    ))
    .frame(width: 360, height: 240)
}
