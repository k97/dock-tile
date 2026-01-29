//
//  HelperAppDelegate.swift
//  DockTile
//
//  Pure AppKit delegate for helper apps - no SwiftUI to avoid window creation crashes
//  Swift 6 - Strict Concurrency
//

import AppKit

@MainActor
final class HelperAppDelegate: NSObject, NSApplicationDelegate {
    /// Floating panel for the popover - created lazily and kept alive
    private lazy var floatingPanel: FloatingPanel = FloatingPanel()

    /// Configuration manager - created once at launch
    private var configManager: ConfigurationManager?

    // MARK: - Runtime Detection

    /// Current bundle ID
    private var currentBundleId: String {
        Bundle.main.bundleIdentifier ?? "com.docktile.app"
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Helper app launching...")
        print("   Bundle ID: \(currentBundleId)")

        // Disable window restoration - helpers don't have windows to restore
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Set up as regular app (shows in Dock)
        NSApp.setActivationPolicy(.regular)

        // Create configuration manager
        configManager = ConfigurationManager()

        // Pre-load and verify configuration
        if let config = getCurrentConfiguration() {
            print("✓ Loaded config: \(config.name) with \(config.appItems.count) apps")
        } else {
            print("⚠️ No configuration found for bundle ID: \(currentBundleId)")
        }

        print("✓ Helper app ready")
        // App is now running in Dock - popover will show when user clicks the icon
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disable automatic window restoration before app finishes launching
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Helper app terminating...")
    }

    /// Keep helper apps running even when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Stay running to respond to dock clicks
    }

    // MARK: - Dock Icon Click Handler

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("🖱️ Helper dock icon clicked (hasVisibleWindows: \(flag))")
        togglePopover()
        return true
    }

    // MARK: - UI Management

    private func togglePopover() {
        if floatingPanel.isVisible {
            hidePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        print("📍 Showing popover for helper tile")

        // Get configuration
        let config = getCurrentConfiguration()
        print("   Configuration: \(config?.name ?? "nil") with \(config?.appItems.count ?? 0) apps")

        // Set configuration before showing (panel is lazily created)
        floatingPanel.configuration = config

        // Show popover
        print("   Calling floatingPanel.show()...")
        floatingPanel.show(animated: true)
        print("   Popover show complete")
    }

    private func hidePopover() {
        print("🚫 Hiding popover")
        floatingPanel.hide(animated: true)
    }

    // MARK: - Context Menu (Right-Click)

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // "Configure..." option
        menu.addItem(NSMenuItem(
            title: "Configure...",
            action: #selector(openConfigurator),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        // Add app list from current configuration
        if let config = getCurrentConfiguration() {
            if config.appItems.isEmpty {
                let item = NSMenuItem(
                    title: "No apps configured",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for appItem in config.appItems {
                    let item = NSMenuItem(
                        title: appItem.name,
                        action: #selector(launchApp(_:)),
                        keyEquivalent: ""
                    )
                    item.representedObject = appItem.bundleIdentifier
                    item.target = self
                    menu.addItem(item)
                }
            }
        } else {
            let item = NSMenuItem(
                title: "No configuration",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }

        return menu
    }

    @objc private func openConfigurator() {
        launchMainApp()
    }

    private func launchMainApp() {
        let workspace = NSWorkspace.shared

        // Try standard locations
        let mainAppPaths = [
            "/Applications/DockTile.app",
            "\(NSHomeDirectory())/Applications/DockTile.app"
        ]

        for path in mainAppPaths {
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                let config = NSWorkspace.OpenConfiguration()
                workspace.openApplication(at: url, configuration: config) { _, error in
                    if let error = error {
                        print("❌ Failed to open main app: \(error.localizedDescription)")
                    } else {
                        print("✅ Launched main DockTile.app")
                    }
                }
                return
            }
        }

        // Fallback: try to find in DerivedData for development
        if let derivedDataApp = findDockTileInDerivedData() {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: derivedDataApp, configuration: config) { _, error in
                if let error = error {
                    print("❌ Failed to open main app from DerivedData: \(error.localizedDescription)")
                } else {
                    print("✅ Launched main DockTile.app from DerivedData")
                }
            }
        } else {
            print("❌ Could not find main DockTile.app")
        }
    }

    private func findDockTileInDerivedData() -> URL? {
        let derivedData = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: derivedData,
            includingPropertiesForKeys: nil
        ) else { return nil }

        for dir in contents where dir.lastPathComponent.hasPrefix("DockTile-") {
            let appPath = dir.appendingPathComponent("Build/Products/Debug/DockTile.app")
            if FileManager.default.fileExists(atPath: appPath.path) {
                return appPath
            }
        }
        return nil
    }

    @objc private func launchApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }

        let workspace = NSWorkspace.shared

        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    print("❌ Failed to launch app: \(error.localizedDescription)")
                }
            }
        } else {
            // Fallback
            workspace.launchApplication(
                withBundleIdentifier: bundleId,
                options: [],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
        }
    }

    // MARK: - Configuration Access

    private func getCurrentConfiguration() -> DockTileConfiguration? {
        guard let configManager = configManager else { return nil }
        return configManager.configuration(forBundleId: currentBundleId)
    }
}
