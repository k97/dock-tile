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

    /// True when we auto-presented the popover on a user-initiated cold launch.
    /// Used to swallow the reopen event macOS may deliver right after launch, so the
    /// auto-shown popover isn't immediately toggled back off.
    private var didAutoShowOnLaunch = false

    /// Timestamp of the last handled Dock reopen, used to coalesce click bursts.
    private var lastReopenTime: CFAbsoluteTime = 0

    /// Reopen events arriving within this window of each other are ignored. After a cold
    /// start, macOS flushes the queued clicks back-to-back; coalescing collapses that
    /// burst into a single action instead of show→hide→show→hide flicker.
    private let reopenCoalesceWindow: CFAbsoluteTime = 0.3

    /// A Dock click that dismisses an open popover ALSO delivers a reopen. If the popover
    /// became hidden within this window, treat the reopen as the tail of that dismissing
    /// click and suppress the reshow — otherwise the popover bounces straight back open and
    /// can never be closed from the Dock.
    private let dismissReshowGuard: CFAbsoluteTime = 0.25

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
            // Tag this process in the shared diagnostics log with the tile name.
            DiagnosticsLog.shared.setLabel("helper:\(config.name) (\(config.shortId))")
            DiagnosticsLog.shared.log("helper", "Ready — \(config.appItems.count) app(s), mode=\(config.showInAppSwitcher ? "app" : "ghost"), bundle=\(currentBundleId)")
        } else {
            print("⚠️ No configuration found for bundle ID: \(currentBundleId)")
            DiagnosticsLog.shared.log("helper", "No configuration found for bundle \(currentBundleId)")
        }

        // Runaway-CPU evidence: the July 2026 "AI Tile at 82.9 % for 16 h" report left no stack
        // (no hang reporting for helpers, 1 h log retention). If this process pegs a core, it now
        // samples itself into <support>/spins/ and Copy Diagnostics carries the hottest frames.
        SpinWatchdog.shared.start()

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

        // Auto-show the popover when the user cold-launched this tile by clicking it in
        // the Dock. A cold Dock click sends a launch ('oapp') event, NOT a reopen ('rapp')
        // event, so without this the very first click would just start the process and
        // show nothing. Background launches (from the main app, or the login LaunchAgent)
        // pass --background-launch and must stay silent.
        let isBackgroundLaunch = CommandLine.arguments.contains("--background-launch")
        if !isBackgroundLaunch {
            print("🟢 User cold-launch detected — showing popover immediately")
            didAutoShowOnLaunch = true
            DiagnosticsLog.shared.log("helper", "Cold-launch (Dock click) — auto-showing popover")
            showPopover(withKeyboardFocus: false)
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
        DiagnosticsLog.shared.ui("Dock icon clicked (popover \(floatingPanel.isVisible ? "open" : "closed"))")
        showedPopoverOnActivation = false  // This was a dock click, not Cmd+Tab

        // Swallow the reopen macOS delivers right after a user cold-launch — we already
        // auto-showed the popover in applicationDidFinishLaunching.
        if didAutoShowOnLaunch {
            didAutoShowOnLaunch = false
            lastReopenTime = CFAbsoluteTimeGetCurrent()
            print("   Ignoring post-launch reopen (popover already shown)")
            return true
        }

        // Coalesce rapid bursts (e.g. queued clicks flushed after a cold start) so they
        // collapse into a single toggle instead of flickering the popover.
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastReopenTime < reopenCoalesceWindow {
            print("   Ignoring reopen within coalesce window")
            return true
        }
        lastReopenTime = now

        if floatingPanel.isVisible {
            // Popover is up → this Dock click toggles it closed.
            hidePopover()
        } else if now - floatingPanel.lastHiddenAt < dismissReshowGuard {
            // The popover was open a moment ago and the SAME Dock click just dismissed it
            // (transient close + global click monitor). Don't bounce it back open.
            print("   Dock click dismissed popover — suppressing immediate reshow")
            DiagnosticsLog.shared.log("helper", "Dock click dismissed popover (no reshow)", verbose: true)
        } else {
            showPopover(withKeyboardFocus: false)
        }
        return true
    }

    // MARK: - UI Management

    private func showPopover(withKeyboardFocus: Bool) {
        print("📍 Showing popover for helper tile (keyboard focus: \(withKeyboardFocus))")

        // A click is a reconciliation moment: cheap, and it covers the one gap events can't —
        // an appearance change made while this Mac was asleep, with no observer running to hear
        // it. Two preference reads, only on an explicit user action.
        IconStyleManager.shared.reconcile(reason: "popover")

        // Get configuration
        let config = getCurrentConfiguration()
        print("   Configuration: \(config?.name ?? "nil") with \(config?.appItems.count ?? 0) apps")

        // Set configuration before showing (panel is lazily created)
        floatingPanel.configuration = config

        AnalyticsService.shared.log(.popoverOpened, [
            "layout": config?.layoutMode.rawValue ?? "unknown",
            "app_count": config?.appItems.count ?? 0,
            "keyboard": withKeyboardFocus
        ])

        // Show popover
        print("   Calling floatingPanel.show()...")
        DiagnosticsLog.shared.measure("Show popover '\(config?.name ?? "?")'") {
            floatingPanel.show(animated: true, withKeyboardFocus: withKeyboardFocus)
        }
        print("   Popover show complete")
        DiagnosticsLog.shared.log("helper", "Popover shown — \(config?.appItems.count ?? 0) app(s), layout=\(config?.layoutMode.rawValue ?? "?"), keyboard=\(withKeyboardFocus)")
    }

    private func hidePopover() {
        print("🚫 Hiding popover")
        floatingPanel.hide(animated: true)
        DiagnosticsLog.shared.log("helper", "Popover hidden", verbose: true)
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
        AnalyticsService.shared.log(.configureGearTapped)
        DiagnosticsLog.shared.log("helper", "Configure gear tapped — launching main app via deep link")
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

        AnalyticsService.shared.log(.appLaunchedFromTile, ["source": "context_menu"])

        let workspace = NSWorkspace.shared

        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    print("❌ Failed to launch app: \(error.localizedDescription)")
                    DiagnosticsLog.shared.log("helper", "App launch FAILED (context menu) \(bundleId): \(error.localizedDescription)")
                } else {
                    DiagnosticsLog.shared.log("helper", "Launched app (context menu) \(bundleId)")
                }
            }
        } else {
            print("❌ Could not find application with bundle ID: \(bundleId)")
            DiagnosticsLog.shared.log("helper", "App not found (context menu) \(bundleId)")
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

    /// Subscribe to icon style changes.
    ///
    /// DETECTION IS NOT DONE HERE. `IconStyleManager` is the single owner of "what is the current
    /// icon style" for the whole process; this delegate only reacts by rewriting the Dock icon.
    /// Previously both ran their own detection — this delegate polled every 1s and the manager
    /// every 2s, each with its own copy of the resolve logic and its own set of distributed
    /// observers. Nobody intended two; the concern simply had no owner, so it got implemented
    /// twice and the two could disagree.
    private func setupIconStyleObservation() {
        // Touch the singleton so its observers exist even if no popover has ever been built.
        // In a helper, IconStyleManager was previously only constructed lazily by the SwiftUI
        // popover views, so a tile that had never been clicked had no manager at all.
        let manager = IconStyleManager.shared
        currentIconStyle = manager.currentStyle

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iconStyleDidChange),
            name: .iconStyleDidChange,
            object: nil
        )

        // Heal a stale icon at launch. Seeding `currentIconStyle` only records what the style IS;
        // it never checked what is actually on disk, so a tile whose icon disagreed stayed wrong
        // until the style next CHANGED. That covers both gaps events cannot: a change made while
        // this helper wasn't running, and an event this helper missed while it was.
        if !HelperBundleManager.iconMatchesStyle(bundlePath: currentBundlePath, style: currentIconStyle) {
            DiagnosticsLog.shared.log(
                "helper",
                "Icon on disk did not match resolved style \(currentIconStyle.rawValue) at launch — correcting"
            )
            updateIconForCurrentStyle()
        }

        print("   ✓ Icon style observation set up (IconStyleManager owns detection)")
    }

    /// `IconStyleManager` resolved a genuinely different style — adopt it on the Dock icon.
    @objc private func iconStyleDidChange(_ note: Notification) {
        guard let newStyle = note.object as? IconStyle else { return }
        applyIconStyle(newStyle, detectedBy: "IconStyleManager")
    }

    /// Adopt a resolved icon style on the Dock icon.
    ///
    /// The caller has already established that this is a genuine, resolved style — an
    /// unrecognised `AppleIconAppearanceTheme` value never reaches here, because
    /// `IconStyleManager` does not publish one. That guard matters: an unresolved read used to
    /// fall back to `.defaultStyle`, which read as a real transition, so a single anomalous read
    /// cost two style changes (out and back) and two icon rewrites on disk.
    private func applyIconStyle(_ newStyle: IconStyle, detectedBy source: String) {
        guard newStyle != currentIconStyle else {
            return // No change
        }

        print("🎨 Icon style changed (\(source)): \(currentIconStyle.rawValue) → \(newStyle.rawValue)")
        AnalyticsService.shared.log(.iconStyleChanged, ["style": newStyle.rawValue])
        currentIconStyle = newStyle
        updateIconForCurrentStyle()
    }

    /// Update the dock icon to match the current icon style
    private func updateIconForCurrentStyle() {
        // Switch the icon files based on icon style
        let success = HelperBundleManager.switchIcon(for: currentBundlePath, to: currentIconStyle)

        if success {
            print("   ✓ Switched dock icon to \(currentIconStyle.rawValue) style")
            DiagnosticsLog.shared.log("helper", "Switched dock icon to \(currentIconStyle.rawValue) style")
        } else {
            print("   ⚠️ Failed to switch dock icon")
            DiagnosticsLog.shared.log("helper", "FAILED to switch dock icon to \(currentIconStyle.rawValue)")
        }
    }

    /// Clean up observers when the app terminates.
    /// Detection lives in `IconStyleManager`, so there is nothing here but our subscription.
    private func cleanupIconStyleObservation() {
        NotificationCenter.default.removeObserver(self, name: .iconStyleDidChange, object: nil)
        IconStyleManager.shared.cleanup()
    }
}
