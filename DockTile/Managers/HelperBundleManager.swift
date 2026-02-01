//
//  HelperBundleManager.swift
//  DockTile
//
//  Manages creation and deletion of helper app bundles for multi-instance support
//  Swift 6 - Strict Concurrency
//

import AppKit
import Foundation

@MainActor
final class HelperBundleManager {
    static let shared = HelperBundleManager()

    // MARK: - Properties

    /// Directory where helper bundles are stored: ~/Library/Application Support/DockTile/
    private let helperDirectory: URL

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        helperDirectory = appSupport.appendingPathComponent("DockTile")

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

        print("   isUpdate: \(isUpdate), wasRunning: \(wasRunning), wasInDock: \(wasInDock)")

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
            helperPath: helperPath
        )

        // 2. Generate icons for different icon styles (Default/Dark/Clear/Tinted)
        // NOTE: macOS Tahoe has TWO independent settings:
        //       - "Appearance" (Light/Dark) - controls window chrome
        //       - "Icon and widget style" (Default/Dark/Clear/Tinted) - controls icons
        // We generate icons for each icon style
        let resourcesPath = helperPath.appendingPathComponent("Contents/Resources")

        // Generate default style icon (colorful gradient background)
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

        // Copy appropriate icon to AppIcon.icns based on current icon style
        let currentStyle = IconStyle.current
        let sourceIconPath = currentStyle == .dark ? darkIconPath : defaultIconPath
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
        addToDock(at: helperPath)

        // 5. Restart Dock to apply changes and launch the helper
        // The helper will be launched by Dock since it's now a persistent app
        restartDock()

        // 6. Wait a moment for Dock to stabilize, then ensure helper is running
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Check if Dock auto-launched it, if not launch manually
        if !isHelperRunning(bundleId: config.bundleIdentifier) {
            print("   Launching helper app...")
            launchHelper(at: helperPath)
        } else {
            print("   ✓ Helper auto-launched by Dock")
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
    func removeFromDock(for config: DockTileConfiguration) throws {
        print("🗑️ Removing from Dock only: \(config.name)")
        print("   Bundle ID: \(config.bundleIdentifier)")

        // Quit helper if running
        if isHelperRunning(bundleId: config.bundleIdentifier) {
            quitHelper(bundleId: config.bundleIdentifier)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Remove from Dock plist (works even if bundle doesn't exist)
        removeFromDockPlist(bundleId: config.bundleIdentifier)

        // Restart Dock to apply changes
        restartDock()

        print("✅ Removed from Dock: \(config.name)")
    }

    // MARK: - Bundle Generation (Pure Swift)

    private func generateHelperBundle(
        appName: String,
        bundleId: String,
        helperPath: URL
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

        // Update Info.plist
        try updateInfoPlist(
            at: helperPath,
            bundleId: bundleId,
            appName: appName
        )
        print("   ✓ Updated Info.plist")

        // Remove existing icon (will be replaced with generated one)
        let existingIconPath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns")
        try? FileManager.default.removeItem(at: existingIconPath)

        // Note: We keep the full binary copy (no symlink) because codesign
        // requires the main executable to be a regular file, not a symlink
    }

    private func updateInfoPlist(at helperPath: URL, bundleId: String, appName: String) throws {
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

        // CRITICAL: Set LSUIElement = true so app doesn't appear in Cmd+Tab by default
        // The app will still appear in Dock because we add it via Dock plist
        // At launch, if showInAppSwitcher is true, we call setActivationPolicy(.regular)
        // to make it visible in Cmd+Tab
        plist["LSUIElement"] = true

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

        // Map icon style to icon file
        // For now, default/clear/tinted all use the "default" colorful icon
        // Dark uses the dark icon
        let sourceIconName: String
        switch iconStyle {
        case .dark:
            sourceIconName = "AppIcon-dark.icns"
        case .defaultStyle, .clear, .tinted:
            sourceIconName = "AppIcon-default.icns"
        }

        let sourceIconPath = resourcesPath.appendingPathComponent(sourceIconName)
        let destIconPath = resourcesPath.appendingPathComponent("AppIcon.icns")

        // Check if source icon exists - fallback to AppIcon-light.icns for backward compatibility
        var actualSourcePath = sourceIconPath
        if !FileManager.default.fileExists(atPath: sourceIconPath.path) {
            // Try fallback to old naming (AppIcon-light.icns)
            let fallbackPath = resourcesPath.appendingPathComponent("AppIcon-light.icns")
            if FileManager.default.fileExists(atPath: fallbackPath.path) {
                actualSourcePath = fallbackPath
                print("[HelperBundleManager] Using fallback icon: AppIcon-light.icns")
            } else {
                print("[HelperBundleManager] Source icon not found: \(sourceIconPath.path)")
                return false
            }
        }

        do {
            // Remove current icon and copy the new one
            try? FileManager.default.removeItem(at: destIconPath)
            try FileManager.default.copyItem(at: actualSourcePath, to: destIconPath)
            print("[HelperBundleManager] Switched icon to: \(sourceIconName) (style: \(iconStyle.rawValue))")

            // Touch bundle and refresh icon cache
            HelperBundleManager.shared.touchBundle(at: bundlePath)

            // Refresh the dock tile icon
            // Note: This may require a Dock restart to fully take effect
            // We'll use NSApplication.setApplicationIconImage as a workaround for in-memory icon
            if let iconImage = NSImage(contentsOf: destIconPath) {
                NSApp.applicationIconImage = iconImage
                print("[HelperBundleManager] Updated in-memory app icon")
            }

            return true
        } catch {
            print("[HelperBundleManager] Failed to switch icon: \(error)")
            return false
        }
    }

    /// Check if app is already in Dock (by path)
    func isInDock(at appPath: URL) -> Bool {
        let dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let dockPlist = NSDictionary(contentsOf: dockPlistPath),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]] else {
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

    /// Check if app with given bundle ID is already in Dock (returns the dock entry path if found)
    func findInDock(bundleId: String) -> URL? {
        let dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let dockPlist = NSDictionary(contentsOf: dockPlistPath),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]] else {
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

                // Check if this app has the bundle ID we're looking for
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
    func removeFromDock(bundleId: String) {
        print("📌 Removing from Dock by bundle ID: \(bundleId)")

        let dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let dockPlist = NSMutableDictionary(contentsOf: dockPlistPath),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]] else {
            print("   ⚠️ Could not read Dock plist")
            return
        }

        // Filter out apps with matching bundle ID
        let filteredApps = persistentApps.filter { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString) else {
                return true  // Keep entries we can't parse
            }

            let appPath = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let infoPlistPath = URL(fileURLWithPath: appPath)
                .appendingPathComponent("Contents/Info.plist")

            if let plist = NSDictionary(contentsOf: infoPlistPath),
               let existingBundleId = plist["CFBundleIdentifier"] as? String,
               existingBundleId == bundleId {
                print("   Found and removing: \(appPath)")
                return false  // Remove this entry
            }
            return true  // Keep this entry
        }

        if filteredApps.count < persistentApps.count {
            dockPlist["persistent-apps"] = filteredApps
            if dockPlist.write(to: dockPlistPath, atomically: true) {
                print("   ✓ Removed from Dock plist")
            }
        } else {
            print("   ✓ Bundle ID not found in Dock")
        }
    }

    /// Remove app from Dock plist by path pattern (doesn't require bundle to exist)
    /// Used during uninstall when bundle may be deleted before Dock restart
    private func removeFromDockPlist(bundleId: String) {
        print("📌 Removing from Dock plist: \(bundleId)")

        let dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let dockPlist = NSMutableDictionary(contentsOf: dockPlistPath),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]] else {
            print("   ⚠️ Could not read Dock plist")
            return
        }

        // Filter out apps - check both by Info.plist (if exists) and by path pattern
        let filteredApps = persistentApps.filter { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString) else {
                return true  // Keep entries we can't parse
            }

            let appPath = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let infoPlistPath = URL(fileURLWithPath: appPath)
                .appendingPathComponent("Contents/Info.plist")

            // Try to read bundle ID from Info.plist
            if let plist = NSDictionary(contentsOf: infoPlistPath),
               let existingBundleId = plist["CFBundleIdentifier"] as? String,
               existingBundleId == bundleId {
                print("   Found by bundle ID: \(appPath)")
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

        if filteredApps.count < persistentApps.count {
            dockPlist["persistent-apps"] = filteredApps
            if dockPlist.write(to: dockPlistPath, atomically: true) {
                print("   ✓ Removed from Dock plist")
            }
        } else {
            print("   ✓ Entry not found in Dock")
        }
    }

    /// Add app to Dock without launching it (only if not already present)
    func addToDock(at appPath: URL) {
        print("📌 Adding to Dock: \(appPath.lastPathComponent)")
        print("   App path: \(appPath.path)")

        // Check if already in Dock first
        if isInDock(at: appPath) {
            print("   ✓ Already in Dock - no action needed")
            return
        }

        print("   Not in Dock yet, adding...")

        // Use defaults to add to com.apple.dock persistent-apps
        let dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let dockPlist = NSMutableDictionary(contentsOf: dockPlistPath),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]] else {
            print("   ⚠️ Could not read Dock plist")
            return
        }

        // Get bundle identifier from the app
        let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
        let bundleId = (NSDictionary(contentsOf: infoPlistPath)?["CFBundleIdentifier"] as? String) ?? ""

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

        // Add to persistent apps
        var updatedApps = persistentApps
        updatedApps.append(newEntry)
        dockPlist["persistent-apps"] = updatedApps

        // Write back (caller is responsible for restarting Dock)
        if dockPlist.write(to: dockPlistPath, atomically: true) {
            print("   ✓ Added to Dock plist (GUID: \(guid), bundle: \(bundleId))")
        } else {
            print("   ⚠️ Failed to write Dock plist")
        }
    }

    /// Remove app from Dock (by path)
    func removeFromDock(at appPath: URL) {
        print("📌 Removing from Dock: \(appPath.lastPathComponent)")

        let dockPlistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let dockPlist = NSMutableDictionary(contentsOf: dockPlistPath),
              let persistentApps = dockPlist["persistent-apps"] as? [[String: Any]] else {
            print("   ⚠️ Could not read Dock plist")
            return
        }

        // Filter out the app
        let appName = appPath.lastPathComponent
        let filteredApps = persistentApps.filter { entry in
            if let tileData = entry["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let path = fileData["_CFURLString"] as? String {
                return !path.contains(appName)
            }
            return true
        }

        if filteredApps.count < persistentApps.count {
            dockPlist["persistent-apps"] = filteredApps
            if dockPlist.write(to: dockPlistPath, atomically: true) {
                print("   ✓ Removed from Dock plist")
                restartDock()
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
            return "Main DockTile.app not found"
        }
    }
}
