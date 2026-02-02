//
//  HelperBundleManager.swift
//  DockTile
//
//  Manages creation, installation, and deletion of helper app bundles.
//  Each helper bundle is a copy of the main DockTile.app that runs independently
//  in the Dock with its own configuration, icon, and app list.
//
//  HELPER MODE ARCHITECTURE:
//  Helpers support two modes based on user preference (showInAppSwitcher toggle):
//
//  - Ghost Mode (default): LSUIElement=true, .accessory policy
//    Hidden from Cmd+Tab, no right-click context menu
//
//  - App Mode: No LSUIElement, .regular policy
//    Visible in Cmd+Tab, right-click context menu works
//
//  This dual-mode exists because macOS doesn't support having a Dock icon
//  while being hidden from Cmd+Tab AND having applicationDockMenu work.
//
//  Swift 6 - Strict Concurrency
//

import AppKit
import Foundation

@MainActor
final class HelperBundleManager {
    static let shared = HelperBundleManager()

    // MARK: - Properties

    /// Directory where helper bundles are stored
    /// Dev: ~/Library/Application Support/DockTile-Dev/
    /// Release: ~/Library/Application Support/DockTile/
    private let helperDirectory: URL

    /// Track bundle IDs currently being installed to prevent double-installation
    private var installingBundleIds: Set<String> = []

    /// Track bundle IDs currently being removed to prevent double-removal
    private var removingBundleIds: Set<String> = []

    // MARK: - Initialization

    private init() {
        // Use environment-specific support folder
        helperDirectory = AppEnvironment.supportURL

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: helperDirectory,
            withIntermediateDirectories: true
        )

        print("📁 HelperBundleManager initialized")
        print("   Helper directory: \(helperDirectory.path)")
    }

    // MARK: - Public API

    /// Install a helper bundle for the given configuration
    /// If helper already exists (by bundle ID), updates it in place
    func installHelper(for config: DockTileConfiguration) async throws {
        // Prevent double-installation if this bundle is already being installed
        guard !installingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping install - already in progress for: \(config.name)")
            return
        }

        installingBundleIds.insert(config.bundleIdentifier)
        defer { installingBundleIds.remove(config.bundleIdentifier) }

        print("🔧 Installing helper for: \(config.name)")
        print("   Bundle ID: \(config.bundleIdentifier)")

        let appName = sanitizeAppName(config.name)
        let helperPath = helperDirectory.appendingPathComponent("\(appName).app")

        // Check if a helper with this bundle ID already exists (possibly with different name)
        let existingHelperPath = findExistingHelper(bundleId: config.bundleIdentifier)
        let isUpdate = existingHelperPath != nil
        let wasRunning = isHelperRunning(bundleId: config.bundleIdentifier)

        // Check if this bundle ID is already in the Dock (might be with different name)
        let existingDockPath = findInDock(bundleId: config.bundleIdentifier)
        let wasInDock = existingDockPath != nil

        // Save the original Dock position before removal (for updates)
        // If currently in Dock, use live position; otherwise fall back to saved lastDockIndex
        let originalDockIndex: Int?
        if wasInDock {
            originalDockIndex = findDockIndex(bundleId: config.bundleIdentifier)
        } else {
            // Use saved position from config (set when tile was hidden)
            originalDockIndex = config.lastDockIndex
        }

        print("   isUpdate: \(isUpdate), wasRunning: \(wasRunning), wasInDock: \(wasInDock), originalIndex: \(originalDockIndex ?? -1), savedLastDockIndex: \(config.lastDockIndex ?? -1)")

        // CRITICAL: Remove from Dock FIRST to prevent auto-relaunch during update
        // The Dock can relaunch persistent apps when it restarts, which causes stale process issues
        if wasInDock {
            print("   Removing from Dock before update (prevents auto-relaunch)")
            removeFromDock(bundleId: config.bundleIdentifier)
        }

        // If helper is running, force quit it and wait for it to fully terminate
        if wasRunning {
            quitHelper(bundleId: config.bundleIdentifier)
            // Wait for the app to fully terminate
            var waitCount = 0
            while isHelperRunning(bundleId: config.bundleIdentifier) && waitCount < 20 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                waitCount += 1
            }

            // Verify termination
            if isHelperRunning(bundleId: config.bundleIdentifier) {
                print("   ⚠️ Helper still running after 2 seconds, proceeding anyway")
            } else {
                print("   Helper terminated after \(waitCount) checks")
            }

            // Extra delay to ensure clean termination and file handle release
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }

        // If updating and name changed, clean up old helper bundle
        if let existingPath = existingHelperPath, existingPath != helperPath {
            print("   Renaming helper from \(existingPath.lastPathComponent) to \(helperPath.lastPathComponent)")
            try? FileManager.default.removeItem(at: existingPath)
        }

        // 1. Generate helper bundle structure (copy main app)
        try generateHelperBundle(
            appName: appName,
            bundleId: config.bundleIdentifier,
            helperPath: helperPath,
            showInAppSwitcher: config.showInAppSwitcher
        )

        // 2. Generate icons for ALL icon styles (Default/Dark/Clear/Tinted)
        // NOTE: macOS Tahoe has TWO independent settings:
        //       - "Appearance" (Light/Dark) - controls window chrome
        //       - "Icon and widget style" (Default/Dark/Clear/Tinted) - controls icons
        // We generate icons for each icon style upfront so switching is instant
        let resourcesPath = helperPath.appendingPathComponent("Contents/Resources")

        // Generate default style icon (colorful gradient background, white symbol)
        let defaultIconPath = resourcesPath.appendingPathComponent("AppIcon-default.icns")
        try IconGenerator.generateIcns(
            tintColor: config.tintColor,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            outputURL: defaultIconPath,
            iconStyle: .defaultStyle
        )
        print("   ✓ Generated default style icon")

        // Generate dark style icon (dark background, tint-colored symbol)
        let darkIconPath = resourcesPath.appendingPathComponent("AppIcon-dark.icns")
        try IconGenerator.generateIcns(
            tintColor: config.tintColor,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            outputURL: darkIconPath,
            iconStyle: .dark
        )
        print("   ✓ Generated dark style icon")

        // Generate clear style icon (semi-transparent gray background, tint-colored symbol)
        let clearIconPath = resourcesPath.appendingPathComponent("AppIcon-clear.icns")
        try IconGenerator.generateIcns(
            tintColor: config.tintColor,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            outputURL: clearIconPath,
            iconStyle: .clear
        )
        print("   ✓ Generated clear style icon")

        // Generate tinted style icon (muted gradient background, white symbol)
        let tintedIconPath = resourcesPath.appendingPathComponent("AppIcon-tinted.icns")
        try IconGenerator.generateIcns(
            tintColor: config.tintColor,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            outputURL: tintedIconPath,
            iconStyle: .tinted
        )
        print("   ✓ Generated tinted style icon")

        // Copy appropriate icon to AppIcon.icns based on current icon style
        let currentStyle = IconStyle.current
        let sourceIconPath = iconPath(for: currentStyle, in: resourcesPath)
        let iconDestPath = resourcesPath.appendingPathComponent("AppIcon.icns")
        try? FileManager.default.removeItem(at: iconDestPath)
        try FileManager.default.copyItem(at: sourceIconPath, to: iconDestPath)
        print("   ✓ Set active icon (style: \(currentStyle.rawValue))")

        // 3. Code sign the bundle
        try codesignHelper(at: helperPath)
        print("   ✓ Code signed")

        // 4. Touch the bundle to invalidate icon cache and re-register with Launch Services
        touchBundle(at: helperPath)
        print("   ✓ Refreshed icon cache")

        // 5. Add to Dock (we already removed it earlier if it was there)
        // If this is an update, restore the original position; otherwise append to end
        addToDock(at: helperPath, atIndex: originalDockIndex)

        // 6. Restart Dock to apply changes
        restartDock()

        // 7. Wait for Dock to fully restart and stabilize
        // The Dock takes time to reload the plist and render
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        // 8. Verify the app is in Dock after restart
        var verifyCount = 0
        while findInDock(bundleId: config.bundleIdentifier) == nil && verifyCount < 5 {
            print("   Waiting for Dock to register app (attempt \(verifyCount + 1))...")
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            verifyCount += 1
        }

        if findInDock(bundleId: config.bundleIdentifier) != nil {
            print("   ✓ App registered in Dock")
        } else {
            print("   ⚠️ App not found in Dock after restart, attempting to re-add...")
            // Try adding again - sometimes the first write doesn't take
            addToDock(at: helperPath)
            restartDock()
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        // 9. Launch the helper app (Dock doesn't auto-launch persistent apps)
        if !isHelperRunning(bundleId: config.bundleIdentifier) {
            print("   Launching helper app...")
            launchHelper(at: helperPath)

            // Wait for launch to complete
            var launchWaitCount = 0
            while !isHelperRunning(bundleId: config.bundleIdentifier) && launchWaitCount < 10 {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                launchWaitCount += 1
            }

            if isHelperRunning(bundleId: config.bundleIdentifier) {
                print("   ✓ Helper launched successfully")
            } else {
                print("   ⚠️ Helper may not have launched - user may need to click the Dock icon")
            }
        } else {
            print("   ✓ Helper already running")
        }

        print("✅ Helper installed at: \(helperPath.path)")
    }

    /// Find existing helper bundle by bundle identifier
    private func findExistingHelper(bundleId: String) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: helperDirectory,
            includingPropertiesForKeys: nil
        ) else { return nil }

        for item in contents where item.pathExtension == "app" {
            let infoPlistPath = item.appendingPathComponent("Contents/Info.plist")
            if let plist = NSDictionary(contentsOf: infoPlistPath),
               let existingBundleId = plist["CFBundleIdentifier"] as? String,
               existingBundleId == bundleId {
                return item
            }
        }
        return nil
    }

    /// Check if helper with given bundle ID is currently running
    private func isHelperRunning(bundleId: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == bundleId }
    }

    /// Quit a running helper app forcefully
    private func quitHelper(bundleId: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == bundleId {
            print("   Force quitting running helper: \(app.localizedName ?? bundleId)")
            // Use forceTerminate() to ensure the app exits immediately
            // This is necessary because terminate() can be ignored by the app
            app.forceTerminate()
        }
    }

    /// Launch a helper app
    private func launchHelper(at helperPath: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false  // Don't bring to foreground
        config.addsToRecentItems = false

        NSWorkspace.shared.openApplication(at: helperPath, configuration: config) { app, error in
            if let error = error {
                print("   ⚠️ Failed to launch helper: \(error.localizedDescription)")
            } else {
                print("   ✓ Helper launched: \(app?.localizedName ?? "unknown")")
            }
        }
    }

    /// Uninstall a helper bundle for the given configuration
    /// - Parameters:
    ///   - config: The configuration to uninstall
    ///   - shouldRestartDock: Whether to restart the Dock after uninstalling (default: true)
    func uninstallHelper(for config: DockTileConfiguration, restartDock shouldRestartDock: Bool = true) throws {
        print("🗑️ Uninstalling helper for: \(config.name)")

        // Find helper by bundle ID (handles renamed helpers)
        let helperPath = findExistingHelper(bundleId: config.bundleIdentifier)

        // Quit if running
        if isHelperRunning(bundleId: config.bundleIdentifier) {
            quitHelper(bundleId: config.bundleIdentifier)
            // Brief pause to let it quit
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Remove from Dock plist if it was in the Dock
        if shouldRestartDock {
            removeFromDockPlist(bundleId: config.bundleIdentifier)
        }

        // Delete the bundle if it exists
        if let helperPath = helperPath {
            try FileManager.default.removeItem(at: helperPath)
            print("   ✓ Removed: \(helperPath.path)")
        } else {
            print("   ✓ No helper bundle found to delete")
        }

        // Restart Dock after bundle is deleted to avoid "?" icon
        if shouldRestartDock {
            restartDock()
        }

        print("✅ Helper uninstalled for: \(config.name)")
    }

    /// Check if a helper bundle exists for the given configuration (by bundle ID)
    func helperExists(for config: DockTileConfiguration) -> Bool {
        return findExistingHelper(bundleId: config.bundleIdentifier) != nil
    }

    /// Get the path to a helper bundle (finds by bundle ID, or returns expected path)
    func helperPath(for config: DockTileConfiguration) -> URL {
        // First try to find existing helper by bundle ID
        if let existingPath = findExistingHelper(bundleId: config.bundleIdentifier) {
            return existingPath
        }
        // Otherwise return the expected path based on name
        let appName = sanitizeAppName(config.name)
        return helperDirectory.appendingPathComponent("\(appName).app")
    }

    /// Remove tile from Dock only (without deleting bundle)
    /// Use this when user toggles "Show Tile" OFF - removes from Dock but keeps bundle
    /// Returns the Dock index before removal (for position restoration later)
    @discardableResult
    func removeFromDock(for config: DockTileConfiguration) async throws -> Int? {
        // Prevent double-removal if this bundle is already being removed
        guard !removingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping remove - already in progress for: \(config.name)")
            return nil
        }

        // Also prevent removal while installation is in progress
        guard !installingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping remove - installation in progress for: \(config.name)")
            return nil
        }

        removingBundleIds.insert(config.bundleIdentifier)
        defer { removingBundleIds.remove(config.bundleIdentifier) }

        print("🗑️ Removing from Dock only: \(config.name)")
        print("   Bundle ID: \(config.bundleIdentifier)")

        // CRITICAL: Save Dock position BEFORE removal for later restoration
        let savedDockIndex = findDockIndex(bundleId: config.bundleIdentifier)
        if let index = savedDockIndex {
            print("   📍 Saving Dock position: \(index)")
        }

        // Quit helper if running
        if isHelperRunning(bundleId: config.bundleIdentifier) {
            quitHelper(bundleId: config.bundleIdentifier)

            // Wait for the app to fully terminate
            var waitCount = 0
            while isHelperRunning(bundleId: config.bundleIdentifier) && waitCount < 10 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                waitCount += 1
            }

            if isHelperRunning(bundleId: config.bundleIdentifier) {
                print("   ⚠️ Helper still running after 1 second")
            } else {
                print("   ✓ Helper terminated after \(waitCount) checks")
            }
        }

        // Remove from Dock plist (works even if bundle doesn't exist)
        removeFromDockPlist(bundleId: config.bundleIdentifier)

        // Restart Dock to apply changes
        restartDock()

        // Wait for Dock to fully restart
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Verify removal
        if findInDock(bundleId: config.bundleIdentifier) == nil {
            print("   ✓ Verified tile removed from Dock")
        } else {
            print("   ⚠️ Tile may still be in Dock - attempting re-removal...")
            removeFromDockPlist(bundleId: config.bundleIdentifier)
            restartDock()
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        print("✅ Removed from Dock: \(config.name)")
        return savedDockIndex
    }

    // MARK: - Bundle Generation (Pure Swift)

    private func generateHelperBundle(
        appName: String,
        bundleId: String,
        helperPath: URL,
        showInAppSwitcher: Bool
    ) throws {
        let mainAppPath = Bundle.main.bundlePath

        print("   Generating helper bundle...")
        print("   Main app: \(mainAppPath)")
        print("   Helper: \(helperPath.path)")

        // Remove existing helper if present
        if FileManager.default.fileExists(atPath: helperPath.path) {
            try FileManager.default.removeItem(at: helperPath)
        }

        // Copy main app bundle
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: mainAppPath),
            to: helperPath
        )
        print("   ✓ Copied bundle structure")

        // Update Info.plist (includes LSUIElement setting based on showInAppSwitcher)
        try updateInfoPlist(
            at: helperPath,
            bundleId: bundleId,
            appName: appName,
            showInAppSwitcher: showInAppSwitcher
        )
        print("   ✓ Updated Info.plist")

        // Remove existing icon files (will be replaced with generated ones)
        let existingIconPath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns")
        try? FileManager.default.removeItem(at: existingIconPath)

        // CRITICAL: Remove Assets.car to prevent macOS from using the main app's icons
        // macOS icon priority: Assets.car (asset catalog) > CFBundleIconFile (.icns)
        // Without removing this, helper tiles would show the main DockTile app icon
        // instead of their custom generated icons
        let assetsCarPath = helperPath.appendingPathComponent("Contents/Resources/Assets.car")
        try? FileManager.default.removeItem(at: assetsCarPath)
        print("   ✓ Removed main app icon assets (Assets.car)")

        // Note: We keep the full binary copy (no symlink) because codesign
        // requires the main executable to be a regular file, not a symlink
    }

    private func updateInfoPlist(at helperPath: URL, bundleId: String, appName: String, showInAppSwitcher: Bool) throws {
        let infoPlistPath = helperPath.appendingPathComponent("Contents/Info.plist")

        guard var plist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] else {
            throw HelperBundleError.infoPlistReadFailed
        }

        // Update bundle metadata
        plist["CFBundleIdentifier"] = bundleId
        plist["CFBundleName"] = appName
        plist["CFBundleDisplayName"] = appName

        // CRITICAL: Set CFBundleIconFile so macOS uses our generated icon
        // The icon file is placed at Contents/Resources/AppIcon.icns
        plist["CFBundleIconFile"] = "AppIcon"

        // HELPER MODE ARCHITECTURE:
        // We support two modes based on user preference (showInAppSwitcher toggle):
        //
        // MODE A: "Ghost Mode" (showInAppSwitcher = false, DEFAULT)
        //   - LSUIElement = true in Info.plist
        //   - Helper uses .accessory activation policy at runtime
        //   - Result: Dock icon visible (via Dock plist), hidden from Cmd+Tab
        //   - Trade-off: Right-click context menu (applicationDockMenu) won't work
        //   - Use case: Users who want minimal UI footprint
        //
        // MODE B: "App Mode" (showInAppSwitcher = true)
        //   - LSUIElement NOT set (removed from Info.plist)
        //   - Helper uses .regular activation policy at runtime
        //   - Result: Dock icon visible, visible in Cmd+Tab, context menu works
        //   - Use case: Users who want full Dock integration with right-click menu
        //
        // WHY THIS ARCHITECTURE:
        // macOS fundamentally links Dock icon visibility with Cmd+Tab visibility.
        // There's no supported way to have a Dock icon while hiding from Cmd+Tab
        // AND having applicationDockMenu work. This is an OS-level constraint.
        // We give users the choice of which trade-off they prefer.

        if showInAppSwitcher {
            // MODE B: App Mode - remove LSUIElement for full Dock integration
            plist.removeValue(forKey: "LSUIElement")
            print("   Mode: App Mode (visible in Cmd+Tab, context menu enabled)")
        } else {
            // MODE A: Ghost Mode - set LSUIElement for Cmd+Tab hiding
            plist["LSUIElement"] = true
            print("   Mode: Ghost Mode (hidden from Cmd+Tab, no context menu)")
        }

        // Write back
        let nsDict = plist as NSDictionary
        guard nsDict.write(to: infoPlistPath, atomically: true) else {
            throw HelperBundleError.infoPlistWriteFailed
        }
    }

    private func codesignHelper(at helperPath: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", helperPath.path]

        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw HelperBundleError.codesignFailed
        }
    }

    /// Touch bundle to invalidate icon cache and re-register with Launch Services
    /// This forces macOS to reload the icon from the .icns file
    private func touchBundle(at helperPath: URL) {
        // Touch the app bundle to update modification date
        let touchProcess = Process()
        touchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        touchProcess.arguments = [helperPath.path]
        touchProcess.standardOutput = FileHandle.nullDevice
        touchProcess.standardError = FileHandle.nullDevice
        try? touchProcess.run()
        touchProcess.waitUntilExit()

        // Also touch the icon file specifically
        let iconPath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns")
        let touchIconProcess = Process()
        touchIconProcess.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        touchIconProcess.arguments = [iconPath.path]
        touchIconProcess.standardOutput = FileHandle.nullDevice
        touchIconProcess.standardError = FileHandle.nullDevice
        try? touchIconProcess.run()
        touchIconProcess.waitUntilExit()

        // Clear icon services cache for this specific app
        // The cache is stored in /var/folders/*/*/com.apple.iconservices*
        // We can't delete the whole cache, but we can force a refresh by:
        // 1. Unregistering the app
        // 2. Re-registering it

        let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

        // First unregister to clear any cached data
        let unregisterProcess = Process()
        unregisterProcess.executableURL = URL(fileURLWithPath: lsregisterPath)
        unregisterProcess.arguments = ["-u", helperPath.path]
        unregisterProcess.standardOutput = FileHandle.nullDevice
        unregisterProcess.standardError = FileHandle.nullDevice
        try? unregisterProcess.run()
        unregisterProcess.waitUntilExit()

        // Re-register with Launch Services to refresh icon cache
        let lsProcess = Process()
        lsProcess.executableURL = URL(fileURLWithPath: lsregisterPath)
        lsProcess.arguments = ["-f", "-R", helperPath.path]
        lsProcess.standardOutput = FileHandle.nullDevice
        lsProcess.standardError = FileHandle.nullDevice
        try? lsProcess.run()
        lsProcess.waitUntilExit()
    }

    // MARK: - Icon Path Helpers

    /// Get the icon filename for a given icon style
    /// - Parameter style: The icon style
    /// - Returns: The filename (e.g., "AppIcon-dark.icns")
    private static func iconFilename(for style: IconStyle) -> String {
        switch style {
        case .defaultStyle:
            return "AppIcon-default.icns"
        case .dark:
            return "AppIcon-dark.icns"
        case .clear:
            return "AppIcon-clear.icns"
        case .tinted:
            return "AppIcon-tinted.icns"
        }
    }

    /// Get the full path to an icon for a given style
    /// - Parameters:
    ///   - style: The icon style
    ///   - resourcesPath: The Resources folder path
    /// - Returns: Full URL to the icon file
    private func iconPath(for style: IconStyle, in resourcesPath: URL) -> URL {
        return resourcesPath.appendingPathComponent(Self.iconFilename(for: style))
    }

    // MARK: - Dynamic Icon Switching (for Helper Apps)

    /// Switch the active icon to match the current icon style
    /// Called by helper apps when system icon style changes
    /// NOTE: This responds to "Icon and widget style" setting, NOT "Appearance" (Light/Dark)
    /// - Parameter bundlePath: Path to the helper bundle
    /// - Parameter iconStyle: The icon style to switch to (Default/Dark/Clear/Tinted)
    /// - Returns: True if icon was switched successfully
    @discardableResult
    static func switchIcon(for bundlePath: URL, to iconStyle: IconStyle) -> Bool {
        let resourcesPath = bundlePath.appendingPathComponent("Contents/Resources")

        // Get the icon file for this style
        let sourceIconName = iconFilename(for: iconStyle)
        let sourceIconPath = resourcesPath.appendingPathComponent(sourceIconName)
        let destIconPath = resourcesPath.appendingPathComponent("AppIcon.icns")

        // Check if source icon exists - fallback chain for backward compatibility
        var actualSourcePath = sourceIconPath
        if !FileManager.default.fileExists(atPath: sourceIconPath.path) {
            // Fallback 1: Try default icon (for old bundles without clear/tinted)
            let defaultPath = resourcesPath.appendingPathComponent("AppIcon-default.icns")
            if FileManager.default.fileExists(atPath: defaultPath.path) {
                actualSourcePath = defaultPath
                print("[HelperBundleManager] Fallback to AppIcon-default.icns for \(iconStyle.rawValue)")
            }
            // Fallback 2: Try old naming (AppIcon-light.icns) for very old bundles
            else {
                let lightPath = resourcesPath.appendingPathComponent("AppIcon-light.icns")
                if FileManager.default.fileExists(atPath: lightPath.path) {
                    actualSourcePath = lightPath
                    print("[HelperBundleManager] Fallback to AppIcon-light.icns")
                } else {
                    print("[HelperBundleManager] Source icon not found: \(sourceIconPath.path)")
                    return false
                }
            }
        }

        do {
            // Remove current icon and copy the new one
            try? FileManager.default.removeItem(at: destIconPath)
            try FileManager.default.copyItem(at: actualSourcePath, to: destIconPath)
            print("[HelperBundleManager] Switched icon to: \(sourceIconName) (style: \(iconStyle.rawValue))")

            // Touch bundle and refresh icon cache
            HelperBundleManager.shared.touchBundle(at: bundlePath)

            // NOTE: We intentionally do NOT set NSApp.applicationIconImage here.
            // Setting it programmatically causes the Dock icon to appear larger than
            // other apps. The file-based icon switch (AppIcon.icns) is sufficient -
            // macOS will pick up the change after touchBundle() refreshes the cache.

            return true
        } catch {
            print("[HelperBundleManager] Failed to switch icon: \(error)")
            return false
        }
    }

    /// Check if app is already in Dock (by path)
    /// Uses CFPreferences API to read from cfprefsd cache (not stale file on disk)
    func isInDock(at appPath: URL) -> Bool {
        let dockAppId = "com.apple.dock" as CFString
        guard let persistentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            return false
        }

        let appName = appPath.lastPathComponent
        return persistentApps.contains { entry in
            if let tileData = entry["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let path = fileData["_CFURLString"] as? String {
                // Check if path contains our app name
                return path.contains(appName)
            }
            return false
        }
    }

    /// Find the index of an app in the Dock by bundle ID
    /// Returns nil if not found
    /// Uses CFPreferences API to read from cfprefsd cache (not stale file on disk)
    func findDockIndex(bundleId: String) -> Int? {
        let dockAppId = "com.apple.dock" as CFString
        guard let persistentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            return nil
        }

        for (index, entry) in persistentApps.enumerated() {
            if let tileData = entry["tile-data"] as? [String: Any] {
                // First check the bundle-identifier stored directly in tile-data
                if let storedBundleId = tileData["bundle-identifier"] as? String,
                   storedBundleId == bundleId {
                    return index
                }

                // Fallback: check Info.plist
                if let fileData = tileData["file-data"] as? [String: Any],
                   let urlString = fileData["_CFURLString"] as? String,
                   let url = URL(string: urlString) {
                    let appPath = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let infoPlistPath = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist")

                    if let plist = NSDictionary(contentsOf: infoPlistPath),
                       let existingBundleId = plist["CFBundleIdentifier"] as? String,
                       existingBundleId == bundleId {
                        return index
                    }
                }
            }
        }
        return nil
    }

    /// Check if app with given bundle ID is already in Dock (returns the dock entry path if found)
    /// Uses CFPreferences API to read from cfprefsd cache (not stale file on disk)
    func findInDock(bundleId: String) -> URL? {
        let dockAppId = "com.apple.dock" as CFString
        guard let persistentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            return nil
        }

        for entry in persistentApps {
            if let tileData = entry["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String,
               let url = URL(string: urlString) {
                // Get the actual file path from the URL
                let appPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let fullPath = "/" + appPath

                // First check the bundle-identifier stored in the Dock plist entry itself
                // This is more reliable because it doesn't depend on the app bundle existing
                if let storedBundleId = tileData["bundle-identifier"] as? String,
                   storedBundleId == bundleId {
                    return URL(fileURLWithPath: fullPath)
                }

                // Fallback: Check if this app has the bundle ID in Info.plist
                // (for entries created by other means that don't have bundle-identifier in tile-data)
                let infoPlistPath = URL(fileURLWithPath: fullPath)
                    .appendingPathComponent("Contents/Info.plist")

                if let plist = NSDictionary(contentsOf: infoPlistPath),
                   let existingBundleId = plist["CFBundleIdentifier"] as? String,
                   existingBundleId == bundleId {
                    return URL(fileURLWithPath: fullPath)
                }
            }
        }
        return nil
    }

    /// Remove app from Dock by bundle ID (checks Info.plist of each app)
    /// Uses CFPreferences API (industry standard - same as dockutil) for reliable sync
    func removeFromDock(bundleId: String) {
        print("📌 Removing from Dock by bundle ID: \(bundleId)")

        // Read current persistent-apps using CFPreferences
        let dockAppId = "com.apple.dock" as CFString
        guard let currentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            print("   ⚠️ Could not read persistent-apps from CFPreferences")
            return
        }

        // Filter out apps with matching bundle ID
        let filteredApps = currentApps.filter { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString) else {
                return true  // Keep entries we can't parse
            }

            let appPath = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // First check the bundle-identifier stored directly in tile-data
            if let storedBundleId = tileData["bundle-identifier"] as? String,
               storedBundleId == bundleId {
                print("   Found and removing (tile-data): \(appPath)")
                return false  // Remove this entry
            }

            // Fallback: check Info.plist
            let infoPlistPath = URL(fileURLWithPath: appPath)
                .appendingPathComponent("Contents/Info.plist")

            if let plist = NSDictionary(contentsOf: infoPlistPath),
               let existingBundleId = plist["CFBundleIdentifier"] as? String,
               existingBundleId == bundleId {
                print("   Found and removing (Info.plist): \(appPath)")
                return false  // Remove this entry
            }
            return true  // Keep this entry
        }

        if filteredApps.count < currentApps.count {
            // Write using CFPreferences API
            CFPreferencesSetAppValue(
                "persistent-apps" as CFString,
                filteredApps as CFArray,
                dockAppId
            )

            if CFPreferencesAppSynchronize(dockAppId) {
                print("   ✓ Removed from Dock via CFPreferences")
            } else {
                print("   ⚠️ CFPreferences sync failed")
            }
        } else {
            print("   ✓ Bundle ID not found in Dock")
        }
    }

    /// Remove app from Dock plist by bundle ID (doesn't require bundle to exist)
    /// Uses CFPreferences API (industry standard - same as dockutil) for reliable sync
    /// Used during uninstall when bundle may be deleted before Dock restart
    private func removeFromDockPlist(bundleId: String) {
        print("📌 Removing from Dock plist: \(bundleId)")

        // Read current persistent-apps using CFPreferences
        let dockAppId = "com.apple.dock" as CFString
        guard let currentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            print("   ⚠️ Could not read persistent-apps from CFPreferences")
            return
        }

        // Filter out apps - check by bundle-identifier in tile-data first, then fallback to Info.plist
        let filteredApps = currentApps.filter { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString) else {
                return true  // Keep entries we can't parse
            }

            let appPath = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // First check the bundle-identifier stored directly in tile-data
            // This is the most reliable method as it doesn't depend on the app bundle existing
            if let storedBundleId = tileData["bundle-identifier"] as? String,
               storedBundleId == bundleId {
                print("   Found by tile-data bundle-identifier: \(appPath)")
                return false  // Remove this entry
            }

            // Fallback: Try to read bundle ID from Info.plist
            let infoPlistPath = URL(fileURLWithPath: appPath)
                .appendingPathComponent("Contents/Info.plist")

            if let plist = NSDictionary(contentsOf: infoPlistPath),
               let existingBundleId = plist["CFBundleIdentifier"] as? String,
               existingBundleId == bundleId {
                print("   Found by Info.plist bundle ID: \(appPath)")
                return false  // Remove this entry
            }

            // Also check if path contains bundle ID pattern (for when bundle is already deleted)
            // Our bundle IDs follow pattern: com.docktile.helper.XXXXXX
            if appPath.contains("DockTile") {
                // Check if Info.plist doesn't exist (bundle was deleted) - remove stale entry
                if !FileManager.default.fileExists(atPath: infoPlistPath.path) {
                    print("   Found stale entry (bundle deleted): \(appPath)")
                    return false  // Remove this stale entry
                }
            }

            return true  // Keep this entry
        }

        if filteredApps.count < currentApps.count {
            // Write using CFPreferences API
            CFPreferencesSetAppValue(
                "persistent-apps" as CFString,
                filteredApps as CFArray,
                dockAppId
            )

            if CFPreferencesAppSynchronize(dockAppId) {
                print("   ✓ Removed from Dock plist via CFPreferences")
            } else {
                print("   ⚠️ CFPreferences sync failed")
            }
        } else {
            print("   ✓ Entry not found in Dock")
        }
    }

    /// Add app to Dock without launching it (only if not already present)
    /// Uses CFPreferences API (industry standard - same as dockutil) for reliable sync
    /// - Parameters:
    ///   - appPath: Path to the app bundle
    ///   - atIndex: Optional index to insert at (preserves position during updates). If nil, appends to end.
    func addToDock(at appPath: URL, atIndex: Int? = nil) {
        print("📌 Adding to Dock: \(appPath.lastPathComponent)")
        print("   App path: \(appPath.path)")
        if let index = atIndex {
            print("   Target index: \(index) (preserving position)")
        }

        // Get bundle identifier from the app first
        let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
        guard let bundleId = NSDictionary(contentsOf: infoPlistPath)?["CFBundleIdentifier"] as? String else {
            print("   ⚠️ Could not read bundle ID from app")
            return
        }

        // Check if already in Dock by bundle ID (more reliable than path)
        if findInDock(bundleId: bundleId) != nil {
            print("   ✓ Already in Dock (bundle ID: \(bundleId)) - no action needed")
            return
        }

        print("   Not in Dock yet, adding...")

        // Read current persistent-apps using CFPreferences (industry standard approach)
        // This ensures we're reading from cfprefsd cache, not stale file on disk
        let dockAppId = "com.apple.dock" as CFString
        guard let currentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            print("   ⚠️ Could not read persistent-apps from CFPreferences")
            return
        }

        // Generate a unique GUID for the dock entry
        let guid = Int(Date().timeIntervalSince1970 * 1000) % Int(Int32.max)

        // Create dock entry with all required fields for persistence
        // Key fields: dock-extra=0 tells Dock this is a user-pinned app (not just running)
        let appPathString = appPath.path
        let newEntry: [String: Any] = [
            "GUID": guid,
            "tile-data": [
                "bundle-identifier": bundleId,
                "dock-extra": 0,  // Critical: 0 = user-pinned, 1 = system default
                "file-data": [
                    "_CFURLString": "file://\(appPathString)/",
                    "_CFURLStringType": 15
                ],
                "file-label": appPath.deletingPathExtension().lastPathComponent,
                "file-type": 41
            ],
            "tile-type": "file-tile"
        ]

        // Add to persistent apps (at specific index if provided, otherwise append)
        var updatedApps = currentApps
        if let index = atIndex, index >= 0, index <= updatedApps.count {
            updatedApps.insert(newEntry, at: index)
            print("   Inserting at index \(index)")
        } else {
            updatedApps.append(newEntry)
            print("   Appending to end")
        }

        // Write using CFPreferences API (industry standard - same approach as dockutil)
        // This writes directly to cfprefsd, avoiding the "write to file then sync" problem
        CFPreferencesSetAppValue(
            "persistent-apps" as CFString,
            updatedApps as CFArray,
            dockAppId
        )

        // Synchronize to flush changes to disk
        if CFPreferencesAppSynchronize(dockAppId) {
            print("   ✓ Added to Dock via CFPreferences (GUID: \(guid), bundle: \(bundleId))")
        } else {
            print("   ⚠️ CFPreferences sync failed")
        }
    }

    /// Remove app from Dock (by path)
    /// Uses CFPreferences API (industry standard - same as dockutil) for reliable sync
    func removeFromDock(at appPath: URL) {
        print("📌 Removing from Dock: \(appPath.lastPathComponent)")

        // Read current persistent-apps using CFPreferences
        let dockAppId = "com.apple.dock" as CFString
        guard let currentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            print("   ⚠️ Could not read persistent-apps from CFPreferences")
            return
        }

        // Filter out the app
        let appName = appPath.lastPathComponent
        let filteredApps = currentApps.filter { entry in
            if let tileData = entry["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let path = fileData["_CFURLString"] as? String {
                return !path.contains(appName)
            }
            return true
        }

        if filteredApps.count < currentApps.count {
            // Write using CFPreferences API
            CFPreferencesSetAppValue(
                "persistent-apps" as CFString,
                filteredApps as CFArray,
                dockAppId
            )

            if CFPreferencesAppSynchronize(dockAppId) {
                print("   ✓ Removed from Dock via CFPreferences")
                restartDock()
            } else {
                print("   ⚠️ CFPreferences sync failed")
            }
        } else {
            print("   ✓ Was not in Dock")
        }
    }

    /// Restart Dock to apply plist changes
    private func restartDock() {
        print("   🔄 Restarting Dock...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
        print("   ✓ Dock restarted")
    }

    // MARK: - Helpers

    /// Sanitize app name for use as bundle name (replace special chars)
    private func sanitizeAppName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        return name
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

}

// MARK: - Errors

enum HelperBundleError: Error, LocalizedError {
    case infoPlistReadFailed
    case infoPlistWriteFailed
    case bundleCopyFailed
    case codesignFailed
    case mainAppNotFound

    var errorDescription: String? {
        switch self {
        case .infoPlistReadFailed:
            return "Failed to read Info.plist"
        case .infoPlistWriteFailed:
            return "Failed to write Info.plist"
        case .bundleCopyFailed:
            return "Failed to copy bundle"
        case .codesignFailed:
            return "Failed to code sign helper bundle"
        case .mainAppNotFound:
            return AppStrings.Error.mainAppNotFound
        }
    }
}
