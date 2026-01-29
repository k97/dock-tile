//
//  AppDelegate.swift
//  DockTile
//
//  Main application delegate for Dock integration and lifecycle management
//  Swift 6 - Strict Concurrency
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var ghostModeManager = GhostModeManager.shared
    private var floatingPanel: FloatingPanel?

    // Configuration manager (set by DockTileApp on launch)
    var configManager: ConfigurationManager?

    // Fixed window dimensions (System Settings style)
    private let fixedWindowWidth: CGFloat = 768
    private let minWindowHeight: CGFloat = 500

    // MARK: - Runtime Detection

    /// Main app bundle ID
    private let mainAppBundleId = "com.docktile.app"

    /// Current bundle ID
    private var currentBundleId: String {
        Bundle.main.bundleIdentifier ?? mainAppBundleId
    }

    /// Detect if running as main app or helper bundle
    private var isHelperApp: Bool {
        // Main app has bundle ID "com.docktile.app"
        // Helper apps have IDs like "com.docktile.UUID-STRING"
        let bundleId = currentBundleId
        if bundleId == mainAppBundleId || bundleId == "com.docktile" {
            return false
        }
        return bundleId.hasPrefix("com.docktile.")
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 DockTile launching...")
        print("   Bundle ID: \(currentBundleId)")
        print("   Is Helper: \(isHelperApp)")

        if isHelperApp {
            configureAsHelper()
        } else {
            configureAsMainApp()
        }

        print("✓ DockTile ready")
    }

    private func configureAsHelper() {
        // Helper apps: regular mode to show in Dock
        NSApp.setActivationPolicy(.regular)

        // Create our own ConfigurationManager for helpers since SwiftUI might not pass it in time
        if configManager == nil {
            configManager = ConfigurationManager()
        }

        // Pre-load and verify configuration
        if let config = getCurrentConfiguration() {
            print("✓ Loaded config: \(config.name) with \(config.appItems.count) apps")
        } else {
            print("⚠️ No configuration found for bundle ID: \(currentBundleId)")
        }

        print("✓ Helper app configured (dock mode)")
    }

    private func configureAsMainApp() {
        // Main app: Use regular mode to show dock icon
        NSApp.setActivationPolicy(.regular)

        // Configure window sizing after a brief delay to ensure window exists
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            configureMainWindowSizing()
        }

        // Check if first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")

        if !hasLaunchedBefore {
            print("🎉 First launch detected - showing configuration window")
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            showConfigurationWindow()
        } else {
            print("✓ Main app ready - dock icon visible")
        }
    }

    /// Configure window size constraints at the AppKit level
    private func configureMainWindowSizing() {
        guard let window = NSApp.windows.first(where: { $0.contentViewController != nil }) else {
            return
        }

        // Set ourselves as delegate for resize control
        window.delegate = self

        // Lock horizontal size, allow vertical resize
        window.contentMinSize = NSSize(width: fixedWindowWidth, height: minWindowHeight)
        window.contentMaxSize = NSSize(width: fixedWindowWidth, height: CGFloat.greatestFiniteMagnitude)

        // Ensure current frame has correct width
        var frame = window.frame
        if frame.width != fixedWindowWidth {
            frame.size.width = fixedWindowWidth
            window.setFrame(frame, display: true, animate: false)
        }

        print("✓ Window sizing configured: \(fixedWindowWidth)x\(minWindowHeight)+")
    }

    // MARK: - NSWindowDelegate

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Enforce fixed width during resize
        return NSSize(width: fixedWindowWidth, height: max(frameSize.height, minWindowHeight))
    }

    private func showConfigurationWindow() {
        // Activate app and show configuration window
        NSApp.activate(ignoringOtherApps: true)

        // Find and show the configuration window
        for window in NSApp.windows {
            if window.contentViewController is NSHostingController<AnyView> ||
               window.title.contains("DockTile") ||
               window.windowNumber > 0 {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 DockTile terminating...")
    }

    // MARK: - URL Handling (Deep Linking)

    /// Handle URLs like: docktile://configure?bundleId=com.docktile.XXXXX
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !isHelperApp else { return }  // Only main app handles URLs

        for url in urls {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        print("🔗 Handling deep link: \(url)")

        guard url.scheme == "docktile" else {
            print("   ⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }

        // Parse URL: docktile://configure?bundleId=XXX or docktile://configure?id=XXX
        guard url.host == "configure" else {
            print("   ⚠️ Unknown URL host: \(url.host ?? "nil")")
            return
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("   ⚠️ No query parameters found")
            return
        }

        // Try bundleId first (from helper context menu)
        if let bundleId = queryItems.first(where: { $0.name == "bundleId" })?.value {
            print("   📦 Selecting config by bundle ID: \(bundleId)")
            configManager?.selectConfiguration(bundleId: bundleId)
            showConfigurationWindow()
            return
        }

        // Try config ID (UUID)
        if let idString = queryItems.first(where: { $0.name == "id" })?.value,
           let id = UUID(uuidString: idString) {
            print("   🆔 Selecting config by ID: \(idString)")
            configManager?.selectConfiguration(id: id)
            showConfigurationWindow()
            return
        }

        print("   ⚠️ No valid config identifier in URL")
    }

    /// Keep helper apps running even when all windows are closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Helper apps should stay running to respond to dock clicks
        // Main app can terminate when window is closed
        return !isHelperApp
    }

    // MARK: - Dock Icon Click Handler

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("🖱️ Dock icon clicked (hasVisibleWindows: \(flag), isHelper: \(isHelperApp))")

        if isHelperApp {
            // Helper tiles: show popover with apps
            print("📍 About to show popover...")
            print("   Config manager: \(configManager != nil ? "exists" : "nil")")
            print("   Current config: \(getCurrentConfiguration()?.name ?? "nil")")
            togglePopover()
        } else {
            // Main DockTile app: show configuration window
            showConfigurationWindow()
        }

        return true
    }

    // MARK: - UI Management

    /// Toggle popover for helper tiles only
    private func togglePopover() {
        if let panel = floatingPanel, panel.isVisible {
            hidePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        print("📍 Showing popover for helper tile")

        // Get configuration first
        let config = getCurrentConfiguration()
        print("   Configuration: \(config?.name ?? "nil") with \(config?.appItems.count ?? 0) apps")

        // Create panel if not exists
        if floatingPanel == nil {
            print("   Creating new FloatingPanel...")
            floatingPanel = FloatingPanel()
        }

        // Set configuration before showing
        floatingPanel?.configuration = config

        // Show popover
        print("   Calling floatingPanel.show()...")
        floatingPanel?.show(animated: true)
        print("   Popover show complete")
    }

    private func hidePopover() {
        print("🚫 Hiding popover")
        floatingPanel?.hide(animated: true)
    }

    // MARK: - Ghost Mode Testing

    /// Expose toggle for testing (can be called from menu or keyboard shortcut later)
    func toggleGhostMode() {
        ghostModeManager.toggleGhostMode()
    }

    // MARK: - Context Menu (Right-Click)

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // "Configure..." option (opens main app if helper, or brings to front if main app)
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
            // No configuration found
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
        if isHelperApp {
            // Launch main DockTile.app
            launchMainApp()
        } else {
            // Already main app, just bring to front
            NSApp.activate(ignoringOtherApps: true)
            showConfigurationWindow()
        }
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
            // Fallback to deprecated API for compatibility
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

        if isHelperApp {
            // Find config by bundle ID for helper apps
            return configManager.configuration(forBundleId: currentBundleId)
        } else {
            // Main app: use selected configuration (or first if none selected)
            return configManager.selectedConfiguration ?? configManager.configurations.first
        }
    }
}
