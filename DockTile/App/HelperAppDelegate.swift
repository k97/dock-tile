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

    /// Track if popover was shown due to app activation (Cmd+Tab)
    private var showedPopoverOnActivation = false

    // MARK: - Runtime Detection

    /// Current bundle ID
    private var currentBundleId: String {
        Bundle.main.bundleIdentifier ?? "com.docktile.app"
    }

    // MARK: - Application Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        print("🚀 Helper app will finish launching...")
        print("   Bundle ID: \(currentBundleId)")

        // Disable automatic window restoration before app finishes launching
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // CRITICAL: Set activation policy BEFORE app finishes launching
        // This must happen early or macOS will ignore the policy change
        let showInAppSwitcher = readShowInAppSwitcherFromDisk()
        if showInAppSwitcher {
            NSApp.setActivationPolicy(.regular)
            print("   App Switcher: visible (regular)")
        } else {
            NSApp.setActivationPolicy(.accessory)
            print("   App Switcher: hidden (accessory)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Helper app did finish launching...")

        // Create configuration manager for runtime use
        configManager = ConfigurationManager()

        if let config = getCurrentConfiguration() {
            print("✓ Loaded config: \(config.name) with \(config.appItems.count) apps")
        } else {
            print("⚠️ No configuration found for bundle ID: \(currentBundleId)")
        }

        print("✓ Helper app ready")
        // App is now running in Dock - popover will show when user clicks the icon
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Helper app terminating...")
    }

    /// Keep helper apps running even when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Stay running to respond to dock clicks
    }

    /// Called when app becomes active (e.g., via Cmd+Tab)
    func applicationDidBecomeActive(_ notification: Notification) {
        // Only show popover on activation if showInAppSwitcher is enabled
        guard let config = getCurrentConfiguration(), config.showInAppSwitcher else {
            return
        }

        // Show popover when activated via Cmd+Tab (if not already visible)
        if !floatingPanel.isVisible {
            print("⌘Tab activated - showing popover with keyboard navigation")
            showPopover(withKeyboardFocus: true)
            showedPopoverOnActivation = true
        }
    }

    /// Called when app loses focus
    func applicationDidResignActive(_ notification: Notification) {
        // Hide popover when app loses focus
        if floatingPanel.isVisible && showedPopoverOnActivation {
            hidePopover()
            showedPopoverOnActivation = false
        }
    }

    // MARK: - Dock Icon Click Handler

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("🖱️ Helper dock icon clicked (hasVisibleWindows: \(flag))")
        showedPopoverOnActivation = false  // This was a dock click, not Cmd+Tab
        togglePopover()
        return true
    }

    // MARK: - UI Management

    private func togglePopover() {
        if floatingPanel.isVisible {
            hidePopover()
        } else {
            showPopover(withKeyboardFocus: false)
        }
    }

    private func showPopover(withKeyboardFocus: Bool) {
        print("📍 Showing popover for helper tile (keyboard focus: \(withKeyboardFocus))")

        // Get configuration
        let config = getCurrentConfiguration()
        print("   Configuration: \(config?.name ?? "nil") with \(config?.appItems.count ?? 0) apps")

        // Set configuration before showing (panel is lazily created)
        floatingPanel.configuration = config

        // Show popover
        print("   Calling floatingPanel.show()...")
        floatingPanel.show(animated: true, withKeyboardFocus: withKeyboardFocus)
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
        launchMainAppWithDeepLink()
    }

    /// Launch main app with deep link to select this helper's configuration
    private func launchMainAppWithDeepLink() {
        // Create deep link URL with this helper's bundle ID
        // docktile://configure?bundleId=com.docktile.XXXXX
        let deepLinkURL = URL(string: "docktile://configure?bundleId=\(currentBundleId)")!

        print("🔗 Opening configurator with deep link: \(deepLinkURL)")

        // Try to open via URL scheme first (works if main app is installed)
        let workspace = NSWorkspace.shared

        workspace.open(deepLinkURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                print("⚠️ Deep link failed: \(error.localizedDescription)")
                // Fallback to direct app launch
                Task { @MainActor in
                    self.launchMainAppDirectly()
                }
            } else {
                print("✅ Opened configurator via deep link")
            }
        }
    }

    /// Fallback: Launch main app directly (without deep link)
    private func launchMainAppDirectly() {
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

    /// Read showInAppSwitcher directly from disk (for early initialization)
    /// This is used before ConfigurationManager is created
    private func readShowInAppSwitcherFromDisk() -> Bool {
        let preferencesDir = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Preferences")

        let storageURL = preferencesDir.appendingPathComponent("com.docktile.configs.json")

        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL) else {
            print("   No config file found, defaulting to hidden")
            return false
        }

        // Decode configurations and find ours by bundle ID
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let configs = try? decoder.decode([DockTileConfiguration].self, from: data) else {
            print("   Failed to decode configs, defaulting to hidden")
            return false
        }

        if let config = configs.first(where: { $0.bundleIdentifier == currentBundleId }) {
            print("   Found config '\(config.name)': showInAppSwitcher = \(config.showInAppSwitcher)")
            return config.showInAppSwitcher
        }

        print("   Config not found for \(currentBundleId), defaulting to hidden")
        return false
    }
}
