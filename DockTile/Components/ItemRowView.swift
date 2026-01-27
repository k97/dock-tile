//
//  ItemRowView.swift
//  DockTile
//
//  Individual app item row with drag handle and remove button
//  Swift 6 - Strict Concurrency
//

import SwiftUI
import AppKit

struct ItemRowView: View {
    let item: AppItem
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 16)

            // App icon
            if let iconData = item.iconData, let nsImage = NSImage(data: iconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                // Fallback icon
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    )
            }

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
