//
//  AboutView.swift
//  DockTile
//
//  Custom About window with "Check for Updates" button
//

import SwiftUI

struct AboutView: View {
    let onCheckForUpdates: () -> Void

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 12) {
            // App icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            // App name
            Text("Dock Tile")
                .font(.system(size: 18, weight: .semibold))

            // Version
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Copyright
            Text(copyright)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Divider()
                .padding(.horizontal, 20)

            // Check for Updates button
            Button("Check for Updates...") {
                onCheckForUpdates()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))

            // Website link
            Link("docktile.rkarthik.co", destination: URL(string: "https://docktile.rkarthik.co")!)
                .font(.system(size: 11))
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .padding(.horizontal, 40)
        .frame(width: 300)
    }
}

// MARK: - About Window Controller

@MainActor
final class AboutWindowController {
    private var window: NSWindow?

    func showAbout(onCheckForUpdates: @escaping () -> Void) {
        // If window exists, just bring it to front
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView(onCheckForUpdates: onCheckForUpdates)
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "About Dock Tile"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
