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

        // Refuse early (with an actionable error) if we can't safely copy ourselves as a template.
        try verifyCanGenerateBundles()

        installingBundleIds.insert(config.bundleIdentifier)
        defer { installingBundleIds.remove(config.bundleIdentifier) }

        print("🔧 Installing helper for: \(config.name)")
        print("   Bundle ID: \(config.bundleIdentifier)")

        // Crashlytics breadcrumb: which step of the fragile install flow we're in, so a
        // crash here is attributable. Cleared at the end of a successful install.
        AnalyticsService.shared.setBreadcrumb(config.bundleIdentifier, for: "installing_bundle_id")
        AnalyticsService.shared.setBreadcrumb("start", for: "install_step")

        // Display name (CFBundleName) stays the clean human name; the FOLDER may be disambiguated
        // when another tile already owns `<name>.app` (same-name tiles are allowed).
        let appName = sanitizeAppName(config.name)
        let helperPath = preferredHelperPath(for: config)

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
        AnalyticsService.shared.setBreadcrumb("bundle_copy", for: "install_step")
        try generateHelperBundle(
            appName: appName,
            bundleId: config.bundleIdentifier,
            helperPath: helperPath,
            showInAppSwitcher: config.showInAppSwitcher
        )

        // 2. Generate icons for ALL icon styles (Default/Dark/Clear/Tinted)
        // We generate all styles upfront so switching is instant at runtime
        let resourcesPath = helperPath.appendingPathComponent("Contents/Resources")

        for style in IconStyle.allCases {
            let iconPath = self.iconPath(for: style, in: resourcesPath)
            try IconGenerator.generateIcns(
                tintColor: config.tintColor,
                iconType: config.iconType,
                iconValue: config.iconValue,
                iconScale: config.iconScale,
                iconWeight: config.iconWeight,
                outputURL: iconPath,
                iconStyle: style
            )
            print("   ✓ Generated \(style.rawValue) style icon")
        }

        // Copy appropriate icon to AppIcon.icns based on current icon style
        let currentStyle = IconStyle.current
        let sourceIconPath = iconPath(for: currentStyle, in: resourcesPath)
        let iconDestPath = resourcesPath.appendingPathComponent("AppIcon.icns")
        try? FileManager.default.removeItem(at: iconDestPath)
        try FileManager.default.copyItem(at: sourceIconPath, to: iconDestPath)
        print("   ✓ Set active icon (style: \(currentStyle.rawValue))")

        // 3. Code sign the bundle
        AnalyticsService.shared.setBreadcrumb("codesign", for: "install_step")
        try codesignHelper(at: helperPath)
        print("   ✓ Code signed")

        // 4. Touch the bundle to invalidate icon cache and re-register with Launch Services
        touchBundle(at: helperPath)
        print("   ✓ Refreshed icon cache")

        // 5. Add to Dock (we already removed it earlier if it was there)
        // If this is an update, restore the original position; otherwise append to end
        addToDock(at: helperPath, atIndex: originalDockIndex)

        // 6. Restart Dock to apply changes
        AnalyticsService.shared.setBreadcrumb("dock_restart", for: "install_step")
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
        AnalyticsService.shared.setBreadcrumb("launch", for: "install_step")
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

        AnalyticsService.shared.setBreadcrumb("done", for: "install_step")
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
        // Mark this as a background (programmatic) launch so the helper does NOT auto-show
        // its popover. Only a real user Dock/Finder cold-launch (no argument) auto-shows.
        config.arguments = ["--background-launch"]

        NSWorkspace.shared.openApplication(at: helperPath, configuration: config) { app, error in
            if let error = error {
                print("   ⚠️ Failed to launch helper: \(error.localizedDescription)")
            } else {
                print("   ✓ Helper launched: \(app?.localizedName ?? "unknown")")
            }
        }
    }

    /// Uninstall a helper bundle for the given configuration.
    /// The Dock is restarted only when an actual Dock plist entry was removed — deleting a
    /// never-pinned or already-hidden tile must NOT bounce the Dock (its `isVisibleInDock`
    /// flag defaults to true before the tile is ever pinned, so the flag is NOT a presence signal).
    func uninstallHelper(for config: DockTileConfiguration) async throws {
        print("🗑️ Uninstalling helper for: \(config.name)")

        // Find helper by bundle ID (handles renamed helpers)
        let helperPath = findExistingHelper(bundleId: config.bundleIdentifier)

        // Quit if running
        if isHelperRunning(bundleId: config.bundleIdentifier) {
            quitHelper(bundleId: config.bundleIdentifier)
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        // Always attempt plist cleanup (also sweeps stale entries); remember whether it changed.
        let didRemoveFromDock = removeFromDockPlist(bundleId: config.bundleIdentifier)

        // Delete the bundle if it exists
        if let helperPath = helperPath {
            try FileManager.default.removeItem(at: helperPath)
            print("   ✓ Removed: \(helperPath.path)")
        } else {
            print("   ✓ No helper bundle found to delete")
        }

        // Restart Dock after bundle is deleted to avoid "?" icon — but only if the Dock changed
        if didRemoveFromDock {
            restartDock()
        } else {
            print("   ✓ Tile was not in the Dock — Dock not restarted")
        }

        print("✅ Helper uninstalled for: \(config.name)")
    }

    /// Check if a helper bundle exists for the given configuration (by bundle ID)
    func helperExists(for config: DockTileConfiguration) -> Bool {
        return findExistingHelper(bundleId: config.bundleIdentifier) != nil
    }

    /// Get the path to a helper bundle (finds by bundle ID, or returns the path a new one would use).
    func helperPath(for config: DockTileConfiguration) -> URL {
        // First try to find existing helper by bundle ID (handles renames + prior disambiguation).
        if let existingPath = findExistingHelper(bundleId: config.bundleIdentifier) {
            return existingPath
        }
        return preferredHelperPath(for: config)
    }

    /// The folder a NEW (or renamed) helper should be written to. Helpers are stored by display
    /// name (`<name>.app`), but two tiles legitimately can share a name — without disambiguation
    /// the second install writes over the first's `<name>.app`, orphaning it (broken Dock icon,
    /// "visible but never pinned"). So: keep the clean name when the path is free or already this
    /// tile's; otherwise suffix with the tile's short id (`<name>-<shortId>.app`). Identity on disk
    /// stays the unique bundle ID — only the folder name is disambiguated.
    private func preferredHelperPath(for config: DockTileConfiguration) -> URL {
        let base = sanitizeAppName(config.name)
        let cleanPath = helperDirectory.appendingPathComponent("\(base).app")
        let takenByOther = FileManager.default.fileExists(atPath: cleanPath.path)
            && bundleId(atHelperPath: cleanPath) != config.bundleIdentifier
        let folder = Self.helperFolderName(
            baseName: base,
            cleanNameTakenByOther: takenByOther,
            shortId: String(config.id.uuidString.prefix(8))
        )
        return helperDirectory.appendingPathComponent(folder)
    }

    /// Pure rule for the on-disk folder name of a helper bundle. Clean `<name>.app` unless a
    /// *different* tile already owns it, in which case a short-id suffix keeps same-named tiles
    /// from colliding. Extracted so the regression is unit-testable without FileManager.
    nonisolated static func helperFolderName(baseName: String, cleanNameTakenByOther: Bool, shortId: String) -> String {
        cleanNameTakenByOther ? "\(baseName)-\(shortId).app" : "\(baseName).app"
    }

    /// The CFBundleIdentifier recorded in a helper bundle on disk (nil if absent/unreadable).
    private func bundleId(atHelperPath path: URL) -> String? {
        let infoPlist = path.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: infoPlist)?["CFBundleIdentifier"] as? String
    }

    // MARK: - Self-heal integrity probes

    /// True when a helper bundle carries a complete generated icon set: the active `AppIcon.icns`
    /// plus all four style variants, each present and non-empty. Catches a helper left structurally
    /// broken by a killed-mid-generation write (e.g. a leftover `.iconset` + only the stale template
    /// `AppIcon-Dev.icns`, with `AppIcon.icns` and the variants absent) — which the Dock renders as
    /// a generic/broken icon.
    func helperIconsComplete(at bundlePath: URL) -> Bool {
        let resources = bundlePath.appendingPathComponent("Contents/Resources")
        let required = ["AppIcon.icns"] + IconStyle.allCases.map { Self.iconFilename(for: $0) }
        let fm = FileManager.default
        for name in required {
            let path = resources.appendingPathComponent(name).path
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? Int, size > 0 else {
                return false
            }
        }
        return true
    }

    /// The marketing version baked into a helper bundle (its own `CFBundleShortVersionString`, set
    /// when the app copied itself as a template). Distinguishes "built by an older app" from the
    /// config's stamped `helperAppVersion`, which a past stamp-only could have set to current while
    /// the bundle stayed old. `nil` if unreadable.
    func helperBakedVersion(at bundlePath: URL) -> String? {
        let infoPlist = bundlePath.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: infoPlist)?["CFBundleShortVersionString"] as? String
    }

    /// Bundle identifiers currently pinned in the Dock, read in ONE synchronized pass (so a
    /// self-heal sweep does a single Dock read, not one per tile). Collects the `bundle-identifier`
    /// stored in each `tile-data` entry — which our `addToDock` always writes.
    func pinnedBundleIds() -> Set<String> {
        let dockAppId = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(dockAppId)
        guard let persistentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            return []
        }
        var ids: Set<String> = []
        for entry in persistentApps {
            if let tileData = entry["tile-data"] as? [String: Any],
               let id = tileData["bundle-identifier"] as? String {
                ids.insert(id)
            }
        }
        return ids
    }

    /// Remove tile from Dock only (without deleting bundle)
    /// Use this when user toggles "Show Tile" OFF - removes from Dock but keeps bundle
    /// Returns the Dock index before removal (for position restoration later)
    @discardableResult
    func removeFromDock(for config: DockTileConfiguration) async throws -> Int? {
        // Prevent double-removal if this bundle is already being removed
        guard !removingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping remove - already in progress for: \(config.name)")
            DiagnosticsLog.shared.log("dock", "removeFromDock SKIPPED (remove already in progress) — '\(config.name)'")
            return nil
        }

        // Also prevent removal while installation is in progress
        guard !installingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping remove - installation in progress for: \(config.name)")
            DiagnosticsLog.shared.log("dock", "removeFromDock SKIPPED (install in progress) — '\(config.name)'")
            return nil
        }

        removingBundleIds.insert(config.bundleIdentifier)
        defer { removingBundleIds.remove(config.bundleIdentifier) }

        print("🗑️ Removing from Dock only: \(config.name)")
        print("   Bundle ID: \(config.bundleIdentifier)")

        // CRITICAL: a removal with nothing to remove must leave the Dock alone. A never-pinned
        // or already-removed tile reaches this path (e.g. "Done" on a hidden tile), and blindly
        // restarting the Dock here was the "Dock keeps restarting on every Done" regression.
        // Returning nil is safe: callers only overwrite lastDockIndex on a non-nil result.
        let wasInDock = findInDock(bundleId: config.bundleIdentifier) != nil
        let helperRunning = isHelperRunning(bundleId: config.bundleIdentifier)
        guard Self.shouldPerformDockRemoval(isInDock: wasInDock, isHelperRunning: helperRunning) else {
            print("   ✓ Not in Dock and no helper running — nothing to remove, Dock left alone")
            DiagnosticsLog.shared.log("dock", "removeFromDock NO-OP for '\(config.name)' (not pinned, helper not running) — Dock NOT restarted")
            return nil
        }

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

        // Remove from Dock plist (works even if bundle doesn't exist). Only an actual plist
        // change warrants restarting the Dock — e.g. the tile may have only had a running
        // helper to quit, with no persistent-apps entry left to clean up.
        let didRemoveFromPlist = removeFromDockPlist(bundleId: config.bundleIdentifier)

        if didRemoveFromPlist {
            // Restart Dock to apply changes
            restartDock()

            // Wait for Dock to fully restart and plist to update
            try await waitForTileRemoval(bundleId: config.bundleIdentifier)

            // Final verification (should always succeed now)
            if findInDock(bundleId: config.bundleIdentifier) == nil {
                print("   ✓ Verified tile removed from Dock")
                DiagnosticsLog.shared.log("dock", "Removed '\(config.name)' from Dock (verified)")
            } else {
                print("   ⚠️ Tile still in Dock after restart - this shouldn't happen")
                DiagnosticsLog.shared.log("dock", "'\(config.name)' STILL in Dock after restart — removal did not take")
            }
        } else {
            print("   ✓ No Dock plist entry to remove — Dock not restarted")
            DiagnosticsLog.shared.log("dock", "removeFromDock for '\(config.name)': no plist entry — Dock NOT restarted")
        }

        print("✅ Removed from Dock: \(config.name)")
        return savedDockIndex
    }

    /// Pure seam (regression-guard convention): whether the hide/remove path has any real work
    /// to do. When the tile has no Dock plist entry AND no helper process is running, removal is
    /// a complete no-op and the Dock must NOT be restarted. Guarded by `DockActionResolutionTests`.
    nonisolated static func shouldPerformDockRemoval(isInDock: Bool, isHelperRunning: Bool) -> Bool {
        isInDock || isHelperRunning
    }

    // MARK: - Bundle Generation (Pure Swift)

    /// Pre-flight for any op that copies the running app as a helper template. When the app is
    /// running from an App Translocation mount (quarantined + launched from ~/Downloads etc.) the
    /// copy fails deep inside FileManager with an opaque Cocoa 260 — the exact non-fatal seen in
    /// Crashlytics. Throwing early turns that into an actionable, catchable error so callers can
    /// point the user at "move to /Applications" instead of silently recording a failure.
    func verifyCanGenerateBundles() throws {
        guard AppRelocationManager.shared.canGenerateBundles else {
            throw HelperBundleError.appTranslocated
        }
    }

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

        // CRITICAL: strip the main app's baked icons (Assets.car + the stale AppIcon.icns, which
        // is replaced by the generated one). macOS icon priority is Assets.car > CFBundleIconFile,
        // so without removing the asset catalog the helper shows the main DockTile icon instead of
        // its custom generated one.
        Self.stripMainAppIcons(inBundle: helperPath)
        print("   ✓ Removed main app icon assets (Assets.car)")

        // Note: We keep the full binary copy (no symlink) because codesign
        // requires the main executable to be a regular file, not a symlink
    }

    /// Remove the main app's baked icon assets from a freshly-copied helper bundle: the asset
    /// catalog (`Assets.car`) AND the template `AppIcon.icns` (replaced by the generated icon).
    /// macOS resolves icons `Assets.car` > `CFBundleIconFile`, so the catalog MUST go or the
    /// helper renders the main app icon. Returns what was present (for logging/tests). Missing
    /// files are not an error — a no-op is fine.
    @discardableResult
    nonisolated static func stripMainAppIcons(inBundle helperPath: URL) -> (assetsCar: Bool, icns: Bool) {
        let resources = helperPath.appendingPathComponent("Contents/Resources")
        let assetsCar = resources.appendingPathComponent("Assets.car")
        let icns = resources.appendingPathComponent("AppIcon.icns")

        let hadAssetsCar = FileManager.default.fileExists(atPath: assetsCar.path)
        let hadIcns = FileManager.default.fileExists(atPath: icns.path)

        try? FileManager.default.removeItem(at: icns)
        try? FileManager.default.removeItem(at: assetsCar)

        return (hadAssetsCar, hadIcns)
    }

    private func updateInfoPlist(at helperPath: URL, bundleId: String, appName: String, showInAppSwitcher: Bool) throws {
        let infoPlistPath = helperPath.appendingPathComponent("Contents/Info.plist")

        guard let base = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] else {
            throw HelperBundleError.infoPlistReadFailed
        }

        let plist = Self.helperInfoPlist(
            from: base,
            bundleId: bundleId,
            appName: appName,
            showInAppSwitcher: showInAppSwitcher
        )

        // Write back
        let nsDict = plist as NSDictionary
        guard nsDict.write(to: infoPlistPath, atomically: true) else {
            throw HelperBundleError.infoPlistWriteFailed
        }
    }

    /// Pure transform from the copied main-app Info.plist to a helper's Info.plist. Centralises
    /// the helper invariants so they are unit-testable without a real bundle on disk:
    ///   • `CFBundleIconFile = "AppIcon"` — so macOS uses the generated `.icns` (paired with the
    ///     `Assets.car` removal in `stripMainAppIcons`).
    ///   • Ghost vs App mode via `LSUIElement` (set when hidden from Cmd+Tab, removed otherwise).
    ///   • Strip Sparkle keys — helpers must never self-update; only the main app does.
    ///   • Strip `CFBundleURLTypes` — only the main app handles `docktile://` deep links.
    nonisolated static func helperInfoPlist(
        from base: [String: Any],
        bundleId: String,
        appName: String,
        showInAppSwitcher: Bool
    ) -> [String: Any] {
        var plist = base

        // Bundle metadata
        plist["CFBundleIdentifier"] = bundleId
        plist["CFBundleName"] = appName
        plist["CFBundleDisplayName"] = appName

        // CRITICAL: use the generated icon at Contents/Resources/AppIcon.icns.
        plist["CFBundleIconFile"] = "AppIcon"

        // Ghost Mode (default): LSUIElement hides the helper from Cmd+Tab.
        // App Mode: LSUIElement removed so the helper is a regular Cmd+Tab app with a context menu.
        // (macOS links Dock-icon visibility to Cmd+Tab visibility — this is the supported trade-off.)
        if showInAppSwitcher {
            plist.removeValue(forKey: "LSUIElement")
        } else {
            plist["LSUIElement"] = true
        }

        // Helpers must never check for updates — strip Sparkle keys.
        plist.removeValue(forKey: "SUFeedURL")
        plist.removeValue(forKey: "SUPublicEDKey")
        plist.removeValue(forKey: "SUEnableAutomaticChecks")
        plist.removeValue(forKey: "SUScheduledCheckInterval")

        // Only the main app should claim the docktile:// URL scheme.
        plist.removeValue(forKey: "CFBundleURLTypes")

        return plist
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
            DiagnosticsLog.shared.log("dock", "codesign FAILED (status \(process.terminationStatus)) for \(helperPath.lastPathComponent)")
            throw HelperBundleError.codesignFailed
        }
    }

    /// Touch bundle to invalidate icon cache and re-register with Launch Services
    /// This forces macOS to reload the icon from the .icns file
    /// Invalidate macOS icon cache and re-register with Launch Services.
    ///
    /// Two-step process:
    /// 1. **Update modification date** — macOS uses mtime to detect when an app bundle has changed.
    ///    Without this, `iconservicesd` may serve stale cached icons even after the .icns file is replaced.
    /// 2. **Re-register with Launch Services** (`lsregister -f -R`) — Forces the LS database to
    ///    re-index the app bundle, picking up the new `CFBundleIconFile` and any plist changes.
    ///    The `-f` flag forces re-registration even if the bundle appears unchanged.
    private func touchBundle(at helperPath: URL) {
        let now = Date()
        let fm = FileManager.default

        // Step 1: Update modification dates to invalidate icon services cache
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: helperPath.path)
        let iconFilePath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns").path
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: iconFilePath)

        // Step 2: Re-register with Launch Services to refresh its index
        let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
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

    // MARK: - Dock Plist Operations (CFPreferences API)
    //
    // All Dock plist reads/writes use CFPreferences instead of direct file I/O.
    //
    // Why CFPreferences?
    // - Reads from cfprefsd in-memory cache (avoids stale data from disk)
    // - Writes sync directly to cfprefsd (no cache invalidation issues)
    // - No privacy prompts (unlike `defaults import` shell command)
    // - Industry standard: same approach used by dockutil and other Dock tools
    //
    // The Dock stores persistent apps in com.apple.dock → "persistent-apps" array.
    // Each entry has: tile-data → { bundle-identifier, file-data → { _CFURLString } }

    /// Check if app is already in Dock (by path)
    func isInDock(at appPath: URL) -> Bool {
        let dockAppId = "com.apple.dock" as CFString
        // Force cfprefsd to pull the latest on-disk state before reading ANOTHER app's domain —
        // a cold/stale cache (notably right after login, when the Dock has just repopulated) would
        // otherwise miss genuinely-pinned tiles and silently skip them during migration.
        CFPreferencesAppSynchronize(dockAppId)
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
        // Force cfprefsd to pull the latest on-disk state before reading ANOTHER app's domain —
        // a cold/stale cache (notably right after login, when the Dock has just repopulated) would
        // otherwise miss genuinely-pinned tiles and silently skip them during migration.
        CFPreferencesAppSynchronize(dockAppId)
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
        // Force cfprefsd to pull the latest on-disk state before reading ANOTHER app's domain —
        // a cold/stale cache (notably right after login, when the Dock has just repopulated) would
        // otherwise miss genuinely-pinned tiles and silently skip them during migration.
        CFPreferencesAppSynchronize(dockAppId)
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
        // Fresh read before mutating persistent-apps (avoid a stale-cache read-modify-write).
        CFPreferencesAppSynchronize(dockAppId)
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
    /// Returns `true` when an entry was actually found and removed — the caller uses this to
    /// decide whether a Dock restart is warranted at all. A no-op removal must NOT restart the
    /// Dock (regression: acting on an already-hidden tile bounced the Dock every time).
    @discardableResult
    private func removeFromDockPlist(bundleId: String) -> Bool {
        print("📌 Removing from Dock plist: \(bundleId)")

        // Read current persistent-apps using CFPreferences
        let dockAppId = "com.apple.dock" as CFString
        // Fresh read before mutating persistent-apps (avoid a stale-cache read-modify-write).
        CFPreferencesAppSynchronize(dockAppId)
        guard let currentApps = CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] else {
            print("   ⚠️ Could not read persistent-apps from CFPreferences")
            return false
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
            return true
        } else {
            print("   ✓ Entry not found in Dock")
            return false
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
        // Fresh read before mutating persistent-apps (avoid a stale-cache read-modify-write).
        CFPreferencesAppSynchronize(dockAppId)
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
        // Fresh read before mutating persistent-apps (avoid a stale-cache read-modify-write).
        CFPreferencesAppSynchronize(dockAppId)
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

        // Let Dock Lock re-assert the anchor: a relaunched Dock can come back on a different
        // display, and the clamp only prevents drift — it doesn't relocate. Posted on the main
        // actor (this type is @MainActor); the handler no-ops unless the Dock actually drifted.
        NotificationCenter.default.post(name: .dockDidRestart, object: nil)
    }

    /// Wait for Dock to fully restart and plist to update after tile removal
    /// Polls CFPreferences to ensure the tile is actually gone before proceeding
    private func waitForTileRemoval(bundleId: String, maxAttempts: Int = 30) async throws {
        print("   ⏳ Waiting for Dock plist to update...")

        for attempt in 1...maxAttempts {
            // Re-read from CFPreferences to get fresh state
            if findInDock(bundleId: bundleId) == nil {
                print("   ✓ Dock plist updated (verified after \(attempt) checks)")
                return
            }

            // Wait 100ms between checks (total max wait: 3 seconds)
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // If we get here, tile is still in plist after max wait
        print("   ⚠️ Tile still in plist after \(maxAttempts) checks (3s)")
    }

    // MARK: - Migration Support API

    /// Current main app version (marketing version string)
    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Regenerate a helper bundle in-place WITHOUT Dock operations.
    /// Used by HelperMigrationManager for batch updates (single Dock restart at end).
    func regenerateHelperBundle(for config: DockTileConfiguration) async throws {
        try verifyCanGenerateBundles()
        let appName = sanitizeAppName(config.name)
        let helperPath = preferredHelperPath(for: config)

        // If existing helper has a different name (was renamed), find by bundle ID
        let existingHelperPath = findExistingHelper(bundleId: config.bundleIdentifier)

        // If name changed, clean up old path
        if let existingPath = existingHelperPath, existingPath != helperPath {
            try? FileManager.default.removeItem(at: existingPath)
        }

        // 1. Generate helper bundle structure (copy main app)
        try generateHelperBundle(
            appName: appName,
            bundleId: config.bundleIdentifier,
            helperPath: helperPath,
            showInAppSwitcher: config.showInAppSwitcher
        )

        // 2. Generate icons for all styles
        let resourcesPath = helperPath.appendingPathComponent("Contents/Resources")
        for style in IconStyle.allCases {
            let iconDest = self.iconPath(for: style, in: resourcesPath)
            try IconGenerator.generateIcns(
                tintColor: config.tintColor,
                iconType: config.iconType,
                iconValue: config.iconValue,
                iconScale: config.iconScale,
                iconWeight: config.iconWeight,
                outputURL: iconDest,
                iconStyle: style
            )
        }

        // Copy current style icon to AppIcon.icns
        let currentStyle = IconStyle.current
        let sourceIconPath = iconPath(for: currentStyle, in: resourcesPath)
        let iconDestPath = resourcesPath.appendingPathComponent("AppIcon.icns")
        try? FileManager.default.removeItem(at: iconDestPath)
        try FileManager.default.copyItem(at: sourceIconPath, to: iconDestPath)

        // 3. Code sign
        try codesignHelper(at: helperPath)

        // 4. Touch bundle to refresh icon cache
        touchBundle(at: helperPath)
    }

    /// Quit a helper and wait for termination (public for migration)
    func quitHelperAndWait(bundleId: String) async {
        guard isHelperRunning(bundleId: bundleId) else { return }
        quitHelper(bundleId: bundleId)
        var waitCount = 0
        while isHelperRunning(bundleId: bundleId) && waitCount < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waitCount += 1
        }
    }

    /// Launch helper for a config (public for migration)
    func launchHelperIfExists(for config: DockTileConfiguration) {
        if let path = findExistingHelper(bundleId: config.bundleIdentifier) {
            launchHelper(at: path)
        }
    }

    /// Restart Dock (public for migration batch use)
    func performDockRestart() {
        restartDock()
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
    /// The app is running from an App Translocation mount (quarantined + launched from e.g.
    /// ~/Downloads), so it cannot copy itself as a helper template. Actionable: move to /Applications.
    case appTranslocated

    var errorDescription: String? {
        switch self {
        case .infoPlistReadFailed:
            return AppStrings.Error.failedToReadInfoPlist
        case .infoPlistWriteFailed:
            return AppStrings.Error.failedToWriteInfoPlist
        case .bundleCopyFailed:
            return AppStrings.Error.failedToCopyBundle
        case .codesignFailed:
            return AppStrings.Error.failedToCodeSign
        case .mainAppNotFound:
            return AppStrings.Error.mainAppNotFound
        case .appTranslocated:
            return AppStrings.Error.appTranslocated
        }
    }
}
