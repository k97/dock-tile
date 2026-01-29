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

        // If helper is running, quit it first and wait for it to fully terminate
        if wasRunning {
            quitHelper(bundleId: config.bundleIdentifier)
            // Wait for the app to fully terminate
            var waitCount = 0
            while isHelperRunning(bundleId: config.bundleIdentifier) && waitCount < 10 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                waitCount += 1
            }
            // Extra delay to ensure clean termination
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            print("   Helper terminated after \(waitCount) checks")
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

        // 2. Generate icon AFTER bundle is created, directly into Resources
        let iconDestPath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns")
        try IconGenerator.generateIcns(
            tintColor: config.tintColor,
            symbol: config.symbolEmoji,
            outputURL: iconDestPath
        )
        print("   ✓ Generated icon")

        // 3. Code sign the bundle
        try codesignHelper(at: helperPath)
        print("   ✓ Code signed")

        // 4. Handle Dock integration - use bundle ID to avoid duplicates
        if wasInDock {
            // Remove old dock entry (might have different path/name)
            removeFromDock(bundleId: config.bundleIdentifier)
        }

        // Add to dock with new path
        addToDock(at: helperPath)

        // Restart dock to apply changes
        restartDock()

        // 5. Launch the helper app so it's running and responsive
        print("   Launching helper app...")
        launchHelper(at: helperPath)

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

    /// Quit a running helper app
    private func quitHelper(bundleId: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps where app.bundleIdentifier == bundleId {
            print("   Quitting running helper: \(app.localizedName ?? bundleId)")
            app.terminate()
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
    func uninstallHelper(for config: DockTileConfiguration) throws {
        print("🗑️ Uninstalling helper for: \(config.name)")

        // Find helper by bundle ID (handles renamed helpers)
        let helperPath = findExistingHelper(bundleId: config.bundleIdentifier)

        // Quit if running
        if isHelperRunning(bundleId: config.bundleIdentifier) {
            quitHelper(bundleId: config.bundleIdentifier)
            // Brief pause to let it quit
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Remove from Dock by bundle ID (works even if bundle is deleted)
        // This modifies the plist but doesn't restart Dock yet
        removeFromDockPlist(bundleId: config.bundleIdentifier)

        // Delete the bundle if it exists
        if let helperPath = helperPath {
            try FileManager.default.removeItem(at: helperPath)
            print("   ✓ Removed: \(helperPath.path)")
        } else {
            print("   ✓ No helper bundle found to delete")
        }

        // Restart Dock after bundle is deleted to avoid "?" icon
        restartDock()

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
