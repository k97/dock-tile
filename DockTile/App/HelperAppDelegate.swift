//
//  HelperAppDelegate.swift
//  DockTile
//
//  NSApplicationDelegate for helper bundles (the tiles that appear in the Dock).
//  Pure AppKit - no SwiftUI to avoid window creation crashes.
//
//  HELPER MODE ARCHITECTURE:
//  Supports two modes based on showInAppSwitcher config:
//
//  - Ghost Mode (default): .accessory policy, hidden from Cmd+Tab
//    Left-click shows popover, right-click context menu won't work
//
//  - App Mode: .regular policy, visible in Cmd+Tab
//    Left-click shows popover, right-click shows "Configure..." menu
//
//  The mode is determined at launch by reading the config file.
//  Changing modes requires regenerating the helper bundle (via "Update" button).
//
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

    /// Observers for icon style changes (distributed notifications)
    private var iconStyleObservers: [any NSObjectProtocol] = []

    /// Poll timer for icon style changes (reliable fallback)
    private var iconStylePollTimer: Timer?

    /// Current icon style (Default/Dark/Clear/Tinted)
    private var currentIconStyle: IconStyle = .defaultStyle

    // MARK: - Runtime Detection

    /// Current bundle ID
    private var currentBundleId: String {
        Bundle.main.bundleIdentifier ?? "com.docktile.app"
    }

    /// Current bundle path
    private var currentBundlePath: URL {
        Bundle.main.bundleURL
    }

    // MARK: - Application Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        print("🚀 Helper app will finish launching...")
        print("   Bundle ID: \(currentBundleId)")

        // Disable automatic window restoration before app finishes launching
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // HELPER MODE ARCHITECTURE:
        // We support two modes based on user preference (showInAppSwitcher config):
        //
        // MODE A: "Ghost Mode" (showInAppSwitcher = false, DEFAULT)
        //   - LSUIElement = true was set in Info.plist during bundle generation
        //   - We use .accessory activation policy here
        //   - Result: Dock icon visible (via Dock plist), hidden from Cmd+Tab
        //   - Trade-off: Right-click context menu (applicationDockMenu) won't work
        //
        // MODE B: "App Mode" (showInAppSwitcher = true)
        //   - LSUIElement was NOT set in Info.plist
        //   - We use .regular activation policy here
        //   - Result: Dock icon visible, visible in Cmd+Tab, context menu works
        //
        // Read the config to determine which mode to use
        let showInAppSwitcher = readShowInAppSwitcherFromDisk()

        if showInAppSwitcher {
            // MODE B: App Mode - full Dock integration with context menu
            NSApp.setActivationPolicy(.regular)
            print("   Mode: App Mode (.regular) - visible in Cmd+Tab, context menu enabled")
        } else {
            // MODE A: Ghost Mode - hidden from Cmd+Tab, no context menu
            NSApp.setActivationPolicy(.accessory)
            print("   Mode: Ghost Mode (.accessory) - hidden from Cmd+Tab, no context menu")
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

        // Set up icon style observation for dynamic icon switching
        // NOTE: This observes "Icon and widget style" setting, NOT "Appearance" (Light/Dark)
        setupIconStyleObservation()

        // Set initial icon based on current icon style
        currentIconStyle = IconStyle.current
        updateIconForCurrentStyle()

        // Observe configure notification from popover gear icon
        NotificationCenter.default.addObserver(
            forName: .openConfigurator,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openConfigurator()
            }
        }

        print("✓ Helper app ready")
        // App is now running in Dock - popover will show when user clicks the icon
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Helper app terminating...")
        cleanupIconStyleObservation()
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
        // NOTE: This method is only called when the helper is in "App Mode" (showInAppSwitcher = true)
        // In "Ghost Mode" (LSUIElement = true), the Dock treats the app as a shortcut
        // and doesn't call this delegate method.
        NSLog("🔧 applicationDockMenu called (App Mode)")
        print("🔧 applicationDockMenu called (App Mode)")
        let menu = NSMenu()

        // "Configure..." option
        let configureItem = NSMenuItem(
            title: AppStrings.Menu.configure,
            action: #selector(openConfigurator),
            keyEquivalent: ""
        )
        configureItem.target = self
        menu.addItem(configureItem)

        menu.addItem(NSMenuItem.separator())

        // Add app list from current configuration
        if let config = getCurrentConfiguration() {
            if config.appItems.isEmpty {
                let item = NSMenuItem(
                    title: AppStrings.Empty.noApps,
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
        // Build deep link URL safely
        var components = URLComponents()
        components.scheme = "docktile"
        components.host = "configure"
        components.queryItems = [URLQueryItem(name: "bundleId", value: currentBundleId)]
        guard let deepLinkURL = components.url else {
            print("❌ Failed to construct deep link URL")
            return
        }

        print("🔗 Opening configurator with deep link: \(deepLinkURL)")

        let workspace = NSWorkspace.shared

        // Find the correct main app (dev build in DerivedData, or release in /Applications)
        if let mainAppURL = findMainApp() {
            print("   Targeting app at: \(mainAppURL.path)")
            let config = NSWorkspace.OpenConfiguration()
            workspace.open([deepLinkURL], withApplicationAt: mainAppURL, configuration: config) { _, error in
                if let error = error {
                    print("⚠️ Targeted deep link failed: \(error.localizedDescription)")
                    // Fallback to URL scheme routing
                    workspace.open(deepLinkURL)
                } else {
                    print("✅ Opened configurator via targeted deep link")
                }
            }
        } else {
            // Fallback: let macOS route the URL scheme
            workspace.open(deepLinkURL)
        }
    }

    /// Find the correct main app based on environment
    private func findMainApp() -> URL? {
        // Dev builds: check DerivedData first
        if AppEnvironment.isDev {
            if let derivedApp = findDockTileInDerivedData() {
                return derivedApp
            }
        }

        // Standard install locations (PRODUCT_NAME has a space: "Dock Tile")
        let paths = [
            "/Applications/Dock Tile.app",
            "\(NSHomeDirectory())/Applications/Dock Tile.app"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // Only fall back to DerivedData for dev builds
        if AppEnvironment.isDev {
            return findDockTileInDerivedData()
        }

        return nil
    }

    private func findDockTileInDerivedData() -> URL? {
        let derivedData = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: derivedData,
            includingPropertiesForKeys: nil
        ) else { return nil }

        // Dev build is "Dock Tile Dev.app", Release is "Dock Tile.app"
        let appNames = ["Dock Tile Dev.app", "Dock Tile.app"]

        for dir in contents where dir.lastPathComponent.hasPrefix("DockTile-") {
            let productsDir = dir.appendingPathComponent("Build/Products/Debug")
            for name in appNames {
                let appPath = productsDir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: appPath.path) {
                    return appPath
                }
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
            print("❌ Could not find application with bundle ID: \(bundleId)")
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

    // MARK: - Icon Style Observation (Dynamic Icon Switching)
    // NOTE: This observes "Icon and widget style" setting (Default/Dark/Clear/Tinted)
    // This is SEPARATE from "Appearance" (Light/Dark) - macOS Tahoe has two independent settings

    /// Set up observers for icon style changes
    private func setupIconStyleObservation() {
        // Observe distributed notifications that might indicate icon style changes
        // macOS Tahoe may use various notification names for this setting
        let notificationNames = [
            "AppleIconAppearanceThemeChangedNotification",
            "AppleInterfaceThemeChangedNotification",  // May also fire for icon style
            "com.apple.desktop.darkModeChanged"
        ]

        for name in notificationNames {
            let observer = DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // Capture notification name for logging (avoid sending Notification across actors)
                let notificationName = name
                Task { @MainActor in
                    print("[HelperAppDelegate] Notification received: \(notificationName)")
                    self?.handleIconStyleChange()
                }
            }
            iconStyleObservers.append(observer)
        }

        // Set up polling as a reliable fallback (every 1 second)
        iconStylePollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForIconStyleChange()
            }
        }

        print("   ✓ Icon style observation set up")
    }

    /// Handle icon style change by switching the dock icon
    private func handleIconStyleChange() {
        let newStyle = IconStyle.current
        guard newStyle != currentIconStyle else {
            return // No change
        }

        print("🎨 Icon style changed: \(currentIconStyle.rawValue) → \(newStyle.rawValue)")
        currentIconStyle = newStyle
        updateIconForCurrentStyle()
    }

    /// Check for icon style change (called by poll timer)
    private func checkForIconStyleChange() {
        let newStyle = IconStyle.current
        guard newStyle != currentIconStyle else {
            return // No change
        }

        print("🎨 Poll detected icon style change: \(currentIconStyle.rawValue) → \(newStyle.rawValue)")
        currentIconStyle = newStyle
        updateIconForCurrentStyle()
    }

    /// Update the dock icon to match the current icon style
    private func updateIconForCurrentStyle() {
        // Switch the icon files based on icon style
        let success = HelperBundleManager.switchIcon(for: currentBundlePath, to: currentIconStyle)

        if success {
            print("   ✓ Switched dock icon to \(currentIconStyle.rawValue) style")
        } else {
            print("   ⚠️ Failed to switch dock icon")
        }
    }

    /// Clean up observers when the app terminates
    private func cleanupIconStyleObservation() {
        iconStylePollTimer?.invalidate()
        iconStylePollTimer = nil
        for observer in iconStyleObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        iconStyleObservers.removeAll()
    }
}
