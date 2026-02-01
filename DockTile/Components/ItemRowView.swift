//
//  ItemRowView.swift
//  DockTile
//
//  Individual app item row with drag handle and remove button
//  Fetches fresh icons from system to respect current icon style
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct ItemRowView: View {
    let item: AppItem
    let onRemove: () -> Void

    @State private var isHovered = false

    // Observe IconStyleManager for icon style changes
    // This triggers view refresh when system icon style changes
    @ObservedObject private var iconStyleManager = IconStyleManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 16)

            // App icon - fetch fresh from system to respect current icon style
            appIconView
                .frame(width: 32, height: 32)

            // App name
            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            // Remove button (visible on hover)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove app")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 52)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        // Reference iconStyleManager.currentStyle to trigger re-render when icon style changes
        // This ensures NSWorkspace returns the correct style-aware icon
        let _ = iconStyleManager.currentStyle

        if let nsImage = getAppIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            // Fallback icon
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.2))
                .overlay(
                    Image(systemName: "app")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                )
        }
    }

    /// Fetch app icon fresh from system (respects current icon style)
    private func getAppIcon() -> NSImage? {
        // For folders, get icon from folder path
        if item.isFolder, let folderPath = item.folderPath {
            return NSWorkspace.shared.icon(forFile: folderPath)
        }

        // Get from bundle identifier - returns style-aware icon from macOS
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // Try common paths for apps
        let searchPaths = [
            "/Applications/\(item.name).app",
            "/System/Applications/\(item.name).app",
            "/Applications/Utilities/\(item.name).app",
            "\(NSHomeDirectory())/Applications/\(item.name).app"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        // Fallback to stored icon data if fresh fetch fails
        if let iconData = item.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

        return nil
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        ItemRowView(
            item: AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari"),
            onRemove: {}
        )
        Divider()
        ItemRowView(
            item: AppItem(bundleIdentifier: "com.apple.mail", name: "Mail"),
            onRemove: {}
        )
    }
    .background(Color(hex: "#000000").opacity(0.04))
    .frame(width: 400)
}
