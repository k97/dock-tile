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
import CoreServices
import Foundation
import Security

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

        // 2. Write the tile icon into the bundle (declarative Assets.car on macOS 26+, the
        // four baked style variants before that) — after the strip, before signing.
        try installTileIcons(for: config, at: helperPath)

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
            shortId: config.shortId
        )
        return helperDirectory.appendingPathComponent(folder)
    }

    /// Pure rule for the on-disk folder name of a helper bundle. Clean `<name>.app` unless a
    /// *different* tile already owns it, in which case a short-id suffix keeps same-named tiles
    /// from colliding. Extracted so the regression is unit-testable without FileManager.
    nonisolated static func helperFolderName(baseName: String, cleanNameTakenByOther: Bool, shortId: String) -> String {
        cleanNameTakenByOther ? "\(baseName)-\(shortId).app" : "\(baseName).app"
    }

    /// Pure rule for the Dock entry's `file-label` — the tooltip the Dock shows for a pinned tile.
    /// The Dock renders this string verbatim and never re-derives it from Launch Services (verified:
    /// rewriting the field + `killall Dock` sticks), so it must be the tile's display name, NOT the
    /// folder stem — a same-named tile lives in `<name>-<shortId>.app`, and the stem leaked the id
    /// into the tooltip ("Utils-B4EF96A2"). `CFBundleDisplayName` → `CFBundleName` → stem mirrors
    /// what the Finder shows for a bundle whose folder matches its display name and what
    /// `NSRunningApplication.localizedName` reports for the running helper (Cmd-Tab / Force Quit).
    /// See docs/dock-tile-display-names.md. Blank values count as absent.
    nonisolated static func dockFileLabel(infoPlist: [String: Any], folderStem: String) -> String {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let value = infoPlist[key] as? String, !value.isEmpty { return value }
        }
        return folderStem
    }

    /// The CFBundleIdentifier recorded in a helper bundle on disk (nil if absent/unreadable).
    private func bundleId(atHelperPath path: URL) -> String? {
        let infoPlist = path.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: infoPlist)?["CFBundleIdentifier"] as? String
    }

    // MARK: - Self-heal integrity probes

    /// True when a helper bundle carries a complete generated icon set for the given pipeline.
    /// Declarative bundles (macOS 26) need `Assets.car` + the active `AppIcon.icns`, both present
    /// and non-empty — macOS renders every appearance from the car itself. Legacy bundles need
    /// `AppIcon.icns` plus all four style variants, each present and non-empty. Pure over plain
    /// byte sizes so it's unit-testable without touching a filesystem.
    ///
    /// A LEGACY-shaped bundle (four variants, no car) evaluated with `declarative: true` is
    /// deliberately INCOMPLETE — that's the mechanism that makes every pre-declarative helper
    /// regenerate into the new shape on its first launch of a declarative-pipeline app version.
    nonisolated static func helperIconsComplete(resourcesContents: [String: Int], declarative: Bool) -> Bool {
        let required = declarative
            ? ["Assets.car", "AppIcon.icns"]
            : ["AppIcon.icns"] + IconStyle.allCases.map { Self.iconFilename(for: $0) }
        return required.allSatisfy { (resourcesContents[$0] ?? 0) > 0 }
    }

    /// Catches a helper left structurally broken by a killed-mid-generation write (e.g. a leftover
    /// `.iconset` + only the stale template `AppIcon-Dev.icns`, with `AppIcon.icns`/`Assets.car`
    /// absent) — which the Dock renders as a generic/broken icon. Reads the real bundle's
    /// `Contents/Resources` and delegates the decision to the pure seam above, gated on the real
    /// running OS's pipeline.
    func helperIconsComplete(at bundlePath: URL) -> Bool {
        let resources = bundlePath.appendingPathComponent("Contents/Resources")
        let names = ["Assets.car", "AppIcon.icns"] + IconStyle.allCases.map { Self.iconFilename(for: $0) }
        let fm = FileManager.default
        var sizes: [String: Int] = [:]
        for name in names {
            let path = resources.appendingPathComponent(name).path
            if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? Int {
                sizes[name] = size
            }
        }
        return Self.helperIconsComplete(resourcesContents: sizes, declarative: IconPipeline.isDeclarative)
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

    // MARK: - Copy Diagnostics icon inventory

    /// Per-pinned-helper icon-shape inventory for Copy Diagnostics (Dock icon-size-flap
    /// investigation). Report-time only — called from `DiagnosticsLog.report()` when the user
    /// presses File → Copy Diagnostics, never on a timer or at launch. Main-app only: helpers never
    /// call this (nothing helper-side invokes `report()`), but the guard mirrors every other
    /// main-app-only path (e.g. `scanForMissingApps`) in case that ever changes.
    ///
    /// Read-only by construction: every probe below is `--verify`/`--info`/`stat`-shaped. Nothing
    /// here writes a file, re-signs a bundle, or touches the Dock plist — a diagnostics reader that
    /// mutates state would be worse than no diagnostics.
    ///
    /// Scoped to `configurations` (not every `pinnedBundleIds()` entry) so a third-party Dock icon
    /// never shows up as a bogus "no helper bundle found" row — only OUR tiles that are ALSO
    /// currently pinned are inspected, matching how `HelperMigrationManager.classifyHelperHealth`
    /// scopes its self-heal sweep.
    func collectIconInventory(configurations: [DockTileConfiguration]) -> [HelperIconInventory] {
        guard !AppEnvironment.isHelper else { return [] }
        let pinned = pinnedBundleIds()
        return configurations
            .filter { pinned.contains($0.bundleIdentifier) }
            .map { config in
                guard let bundlePath = findExistingHelper(bundleId: config.bundleIdentifier) else {
                    return HelperIconInventory(
                        tileName: config.diagnosticName, sealValid: false, liveIconMatchesVariant: nil,
                        carPresent: false, carRenditionSummary: nil, iconFileMTimes: [:],
                        inspectionError: "pinned in the Dock but no helper bundle found on disk"
                    )
                }
                return Self.inspectIconShape(bundlePath: bundlePath, tileName: config.diagnosticName)
            }
    }

    /// Inspects one helper bundle's Resources folder: seal validity, which icon shape it's
    /// actually in (legacy variant match vs declarative `Assets.car`, determined from what's
    /// really on disk — NOT from `IconPipeline.isDeclarative`, since a machine mid-migration can
    /// hold both shapes at once), and every icon file's mtime.
    private static func inspectIconShape(bundlePath: URL, tileName: String) -> HelperIconInventory {
        let resources = bundlePath.appendingPathComponent("Contents/Resources")
        let fm = FileManager.default

        let sealValid = verifySeal(bundlePath: bundlePath)

        let carURL = resources.appendingPathComponent("Assets.car")
        let carPresent = fm.fileExists(atPath: carURL.path)
        let carSummary = carPresent ? carRenditionSummary(carURL: carURL) : nil

        var variantMatch: String?
        if !carPresent {
            let liveURL = resources.appendingPathComponent("AppIcon.icns")
            if fm.fileExists(atPath: liveURL.path) {
                let matched = IconStyle.allCases.first { style in
                    let variantURL = resources.appendingPathComponent(iconFilename(for: style))
                    return fm.fileExists(atPath: variantURL.path)
                        && fm.contentsEqual(atPath: liveURL.path, andPath: variantURL.path)
                }
                variantMatch = matched.map { iconFilename(for: $0) } ?? "none"
            }
        }

        var mtimes: [String: Date] = [:]
        let candidateNames = ["Assets.car", "AppIcon.icns"] + IconStyle.allCases.map { iconFilename(for: $0) }
        for name in candidateNames {
            let path = resources.appendingPathComponent(name).path
            if let attrs = try? fm.attributesOfItem(atPath: path), let date = attrs[.modificationDate] as? Date {
                mtimes[name] = date
            }
        }

        return HelperIconInventory(
            tileName: tileName, sealValid: sealValid, liveIconMatchesVariant: variantMatch,
            carPresent: carPresent, carRenditionSummary: carSummary, iconFileMTimes: mtimes,
            inspectionError: nil
        )
    }

    /// Code-signature validity via Security.framework — the same check `DiagnosticsLog`'s existing
    /// per-bundle seal report uses, so no subprocess is needed for this half of the inspection.
    /// `false` for both "unreadable" and "genuinely broken": either way the seal can't be trusted,
    /// which is the only thing this line reports.
    private static func verifySeal(bundlePath: URL) -> Bool {
        var staticCode: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(bundlePath as CFURL, [], &staticCode)
        guard created == errSecSuccess, let code = staticCode else { return false }
        return SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess
    }

    /// `assetutil --info <car>`, summarised to "<N> renditions, IconImageStack: yes/no". Read-only
    /// (info only — never `--compile` or anything that writes). Drains BOTH stdout and stderr
    /// concurrently, on background queues, BEFORE `waitUntilExit` — a child filling either pipe's
    /// buffer while this thread blocks in `waitUntilExit` deadlocks it (mirrors
    /// `IconCompiler.compile`'s drain, the proven pattern for this exact hazard). Returns `nil` on
    /// any failure (missing binary, non-zero exit, unparseable JSON) rather than throwing — a
    /// broken car degrades this one field, not the whole report.
    private static func carRenditionSummary(carURL: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/assetutil")
        process.arguments = ["--info", carURL.path]
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return nil
        }

        nonisolated(unsafe) var outData = Data()
        let drainGroup = DispatchGroup()
        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            drainGroup.leave()
        }
        drainGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            drainGroup.leave()
        }
        drainGroup.wait()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        guard let jsonStart = outData.firstIndex(of: UInt8(ascii: "[")),
              let array = try? JSONSerialization.jsonObject(with: outData[jsonStart...]) as? [[String: Any]]
        else { return nil }

        let renditionCount = array.filter { $0["AssetType"] != nil }.count
        let hasIconImageStack = array.contains { ($0["AssetType"] as? String) == "IconImageStack" }
        return "\(renditionCount) renditions, IconImageStack: \(hasIconImageStack ? "yes" : "no")"
    }

    /// Remove tile from Dock only (without deleting bundle)
    /// Use this when user toggles "Show Tile" OFF - removes from Dock but keeps bundle
    /// Returns the Dock index before removal (for position restoration later)
    @discardableResult
    func removeFromDock(for config: DockTileConfiguration) async throws -> Int? {
        // Prevent double-removal if this bundle is already being removed
        guard !removingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping remove - already in progress for: \(config.name)")
            DiagnosticsLog.shared.log("dock", "removeFromDock SKIPPED (remove already in progress) — \(config.diagnosticName)")
            return nil
        }

        // Also prevent removal while installation is in progress
        guard !installingBundleIds.contains(config.bundleIdentifier) else {
            print("⚠️ Skipping remove - installation in progress for: \(config.name)")
            DiagnosticsLog.shared.log("dock", "removeFromDock SKIPPED (install in progress) — \(config.diagnosticName)")
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
            DiagnosticsLog.shared.log("dock", "removeFromDock NO-OP for \(config.diagnosticName) (not pinned, helper not running) — Dock NOT restarted")
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

            if findInDock(bundleId: config.bundleIdentifier) == nil {
                print("   ✓ Verified tile removed from Dock")
                DiagnosticsLog.shared.log("dock", "Removed \(config.diagnosticName) from Dock (verified)")
            } else {
                // The entry came back: a Dock still holding the OLD persistent-apps in memory
                // flushed it over our write when `killall` signalled it (measured — repeated
                // plain removals left entries stranded, and this is the 'STILL in Dock after
                // restart' line from the July 2026 report). Re-remove with the Dock actually
                // gone, so there is no process left to flush stale prefs on top of us.
                print("   ⚠️ Tile reappeared after restart (Dock flushed stale prefs) — retrying")
                DiagnosticsLog.shared.log("dock", "\(config.diagnosticName) reappeared in Dock after restart — retrying removal with the Dock quit")

                quitDockAndWaitForExit()
                removeFromDockPlist(bundleId: config.bundleIdentifier)
                try await waitForTileRemoval(bundleId: config.bundleIdentifier)

                if findInDock(bundleId: config.bundleIdentifier) == nil {
                    print("   ✓ Verified tile removed from Dock (on retry)")
                    DiagnosticsLog.shared.log("dock", "Removed \(config.diagnosticName) from Dock (verified on retry)")
                } else {
                    print("   ⚠️ Tile still in Dock after retry")
                    DiagnosticsLog.shared.log("dock", "\(config.diagnosticName) STILL in Dock after retry — removal did not take")
                }
            }
        } else {
            print("   ✓ No Dock plist entry to remove — Dock not restarted")
            DiagnosticsLog.shared.log("dock", "removeFromDock for \(config.diagnosticName): no plist entry — Dock NOT restarted")
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

    /// Which `Contents/Resources` entries a freshly-copied helper must not keep.
    ///
    /// - `Assets.car` and the template `AppIcon.icns` — macOS resolves icons
    ///   `Assets.car` > `CFBundleIconFile`, so the main app's catalog MUST go or the helper renders
    ///   the main app icon. (On the declarative path the helper's OWN compiled catalog is written
    ///   back afterwards; the copy that comes out of the main app is still the wrong one.)
    /// - `docktile-actool` — **unconditionally, on every macOS version.** A helper never compiles
    ///   anything: `IconCompiler.bundledCompilerURL` documents the binary as absent from helpers,
    ///   and this strip is what makes that true. The pipeline the *generating* app happens to be
    ///   running is irrelevant to that — gating this entry on it would leave a pre-Tahoe host
    ///   shipping a dead multi-megabyte executable inside every tile, with the extra signing
    ///   surface that implies.
    nonisolated static func resourcesToStripFromHelper() -> [String] {
        ["Assets.car", "AppIcon.icns", "docktile-actool"]
    }

    /// Remove the resources named by `resourcesToStripFromHelper` from a freshly-copied helper
    /// bundle. Returns whether the two icon entries were present (for logging/tests). Missing
    /// files are not an error — a no-op is fine.
    @discardableResult
    nonisolated static func stripMainAppIcons(inBundle helperPath: URL) -> (assetsCar: Bool, icns: Bool) {
        let resources = helperPath.appendingPathComponent("Contents/Resources")
        let assetsCar = resources.appendingPathComponent("Assets.car")
        let icns = resources.appendingPathComponent("AppIcon.icns")

        let hadAssetsCar = FileManager.default.fileExists(atPath: assetsCar.path)
        let hadIcns = FileManager.default.fileExists(atPath: icns.path)

        for name in resourcesToStripFromHelper() {
            try? FileManager.default.removeItem(at: resources.appendingPathComponent(name))
        }

        return (hadAssetsCar, hadIcns)
    }

    // MARK: - Tile Icon Installation

    /// Write the tile's icon into a freshly-generated helper bundle.
    ///
    /// THE availability branch for icon generation (activation point 1 of the three
    /// `IconPipeline.isDeclarative` consults). Called by BOTH `installHelper` and
    /// `regenerateHelperBundle` so the two flows cannot diverge, and always AFTER
    /// `generateHelperBundle` (which strips the main app's catalog) and BEFORE `codesignHelper`
    /// — nothing may write into the bundle once it is sealed.
    private func installTileIcons(for config: DockTileConfiguration, at helperPath: URL) throws {
        let resourcesPath = helperPath.appendingPathComponent("Contents/Resources")

        guard IconPipeline.isDeclarative else {
            // LEGACY (pre-macOS-26): bake all four style variants upfront so the runtime style
            // switch is a file copy, and seed the live icon from the style in effect right now.
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

            let currentStyle = IconStyle.current
            let sourceIconPath = iconPath(for: currentStyle, in: resourcesPath)
            let iconDestPath = resourcesPath.appendingPathComponent("AppIcon.icns")
            try? FileManager.default.removeItem(at: iconDestPath)
            try FileManager.default.copyItem(at: sourceIconPath, to: iconDestPath)
            print("   ✓ Set active icon (style: \(currentStyle.rawValue))")
            return
        }

        try installDeclarativeIcon(for: config, resourcesPath: resourcesPath)
        print("   ✓ Compiled declarative icon (Assets.car + fallback AppIcon.icns)")
    }

    /// macOS 26+: author an Icon Composer `.icon` document for this tile, compile it to a
    /// per-tile `Assets.car`, and drop one fallback `.icns` beside it. The system then renders
    /// every appearance itself — no variants, no detection, and the bundle's icon is never
    /// touched again after signing.
    private func installDeclarativeIcon(for config: DockTileConfiguration, resourcesPath: URL) throws {
        let (specs, pngs) = try declarativeLayerSpecs(for: config)

        // Backgrounds are JSON fills, not pixels — and they are exactly the colours the legacy
        // bake uses (near-black for a Dark symbol tile, darkened-own-tint for a Dark emoji tile),
        // read from the same `nsColors(for:iconType:)` seam so the two paths cannot drift.
        let light = config.tintColor.nsColors(for: .defaultStyle, iconType: config.iconType)
        let dark = config.tintColor.nsColors(for: .dark, iconType: config.iconType)
        let tinted = config.tintColor.nsColors(for: .tinted, iconType: config.iconType)

        let json = IconDocumentBuilder.iconJSON(
            fillTopP3: try Self.p3Components(light.backgroundTop),
            fillBottomP3: try Self.p3Components(light.backgroundBottom),
            darkFillTopP3: try Self.p3Components(dark.backgroundTop),
            darkFillBottomP3: try Self.p3Components(dark.backgroundBottom),
            tintedFillTopP3: try Self.p3Components(tinted.backgroundTop),
            tintedFillBottomP3: try Self.p3Components(tinted.backgroundBottom),
            layers: specs
        )

        // Scratch lives in the TEMP dir with `defer` cleanup — never inside the helper bundle.
        // A process killed mid-generation must not leave a stray `.icon`/`Assets.car` staging
        // directory sealed into a tile (the killed-mid-generation damage class the self-heal
        // exists to detect).
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("docktile-icon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let document = try IconDocumentBuilder.writeDocument(
            json: json, layerPNGs: pngs, name: "AppIcon", parent: scratch
        )
        guard let compiler = IconCompiler.bundledCompilerURL else {
            throw IconCompilerError.compilerMissing
        }
        let car = try IconCompiler.compile(
            document: document,
            outputDir: scratch.appendingPathComponent("compiled"),
            compilerURL: compiler
        )

        let carDestination = resourcesPath.appendingPathComponent("Assets.car")
        try? FileManager.default.removeItem(at: carDestination)
        try FileManager.default.copyItem(at: car, to: carDestination)

        // ONE fallback `.icns` (not four variants) for the contexts that read `CFBundleIconFile`.
        try IconGenerator.generateFallbackIcns(
            tintColor: config.tintColor,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            iconWeight: config.iconWeight,
            outputURL: resourcesPath.appendingPathComponent("AppIcon.icns")
        )
    }

    /// The glyph layers of this tile's `.icon` document, with their rendered PNGs.
    ///
    /// TWO layers for a symbol/brand tile, never three: the `.tinted` render is byte-identical to
    /// `.light` (guarded by `GlyphLayerRenderTests`), so the document reuses the light layer for
    /// tinted rather than shipping a duplicate asset in every tile. `exclusiveTo` is only ever
    /// `.light`/`.dark` — its polarity formula is undefined for `.tinted`, which would compile
    /// cleanly into a layer hidden in EVERY appearance.
    ///
    /// ONE layer for an emoji tile: a colour glyph cannot be recoloured, so a single full-colour
    /// layer (`exclusiveTo: nil` — visible everywhere) serves every appearance and the dark
    /// treatment lives entirely in the background fill.
    private func declarativeLayerSpecs(
        for config: DockTileConfiguration
    ) throws -> (specs: [IconDocumentBuilder.LayerSpec], pngs: [String: Data]) {
        func layerPNG(_ appearance: IconAppearance) throws -> Data {
            // Every value comes from the tile's own config — the renderer has no defaults for
            // scale or weight, so the user's settings cannot be silently substituted here.
            try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance,
                tintColor: config.tintColor,
                iconType: config.iconType,
                iconValue: config.iconValue,
                iconScale: config.iconScale,
                iconWeight: config.iconWeight
            )
        }

        switch config.iconType {
        case .emoji:
            return (
                [.init(name: "glyph", imageName: "glyph.png", exclusiveTo: nil)],
                ["glyph.png": try layerPNG(.light)]
            )
        case .sfSymbol:
            return (
                [
                    .init(name: "glyph-light", imageName: "glyph-light.png", exclusiveTo: .light),
                    .init(name: "glyph-dark", imageName: "glyph-dark.png", exclusiveTo: .dark)
                ],
                [
                    "glyph-light.png": try layerPNG(.light),
                    "glyph-dark.png": try layerPNG(.dark)
                ]
            )
        }
    }

    /// Display-P3 components for an icon.json fill stop. The document format is P3-native, so the
    /// colour is converted rather than reinterpreted.
    ///
    /// THROWS rather than substituting a fallback colour. Every colour reaching here comes from
    /// `nsColors(for:iconType:)` and is component-backed, so the conversion should not fail — which
    /// is exactly why a silent `(0, 0, 0)` would be so damaging: it would bake a black-gradient
    /// tile, with no error in the diagnostics log and nothing for the user to report.
    nonisolated private static func p3Components(_ color: NSColor) throws -> (r: Double, g: Double, b: Double) {
        guard let converted = color.usingColorSpace(.displayP3) ?? color.usingColorSpace(.sRGB) else {
            throw IconGeneratorError.colorConversionFailed
        }
        return (
            Double(converted.redComponent),
            Double(converted.greenComponent),
            Double(converted.blueComponent)
        )
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
            showInAppSwitcher: showInAppSwitcher,
            declarative: IconPipeline.isDeclarative
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
    ///   • `CFBundleIconName = "AppIcon"` on the declarative path ONLY — names the icon inside the
    ///     per-tile compiled `Assets.car`. Set ALONGSIDE `CFBundleIconFile`, never instead of it:
    ///     the catalog is what the Dock renders, the loose `.icns` remains the fallback for
    ///     contexts that read it. The legacy path is left exactly as it has always been — it
    ///     inherits whatever the main app's plist carried, which is inert without a catalog.
    ///   • Ghost vs App mode via `LSUIElement` (set when hidden from Cmd+Tab, removed otherwise).
    ///   • Strip Sparkle keys — helpers must never self-update; only the main app does.
    ///   • Strip `CFBundleURLTypes` — only the main app handles `docktile://` deep links.
    nonisolated static func helperInfoPlist(
        from base: [String: Any],
        bundleId: String,
        appName: String,
        showInAppSwitcher: Bool,
        declarative: Bool
    ) -> [String: Any] {
        var plist = base

        // Bundle metadata
        plist["CFBundleIdentifier"] = bundleId
        plist["CFBundleName"] = appName
        plist["CFBundleDisplayName"] = appName

        // CRITICAL: use the generated icon at Contents/Resources/AppIcon.icns.
        plist["CFBundleIconFile"] = "AppIcon"

        if declarative {
            plist["CFBundleIconName"] = "AppIcon"
        }

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

    /// Whether the bundle's live `AppIcon.icns` is already the variant for `style`.
    ///
    /// WHY: a helper seeds its cached style at launch but nothing applied it, so a bundle whose
    /// on-disk icon disagreed with the resolved style stayed wrong until the style next *changed*
    /// — which could be days. Two ways in: the process missed a change while it wasn't running,
    /// or it missed an event while it was. Comparing bytes heals both, and costs one file
    /// comparison at launch that answers "already correct" in the overwhelmingly common case.
    ///
    /// Returns `true` when they match OR when the comparison can't be made (missing variant), so
    /// an unanswerable question never triggers a needless rewrite-and-reseal.
    nonisolated static func iconMatchesStyle(bundlePath: URL, style: IconStyle) -> Bool {
        let resources = bundlePath.appendingPathComponent("Contents/Resources")
        let live = resources.appendingPathComponent("AppIcon.icns").path
        let variant = resources.appendingPathComponent(iconFilename(for: style)).path

        let fm = FileManager.default
        guard fm.fileExists(atPath: live), fm.fileExists(atPath: variant) else { return true }
        return fm.contentsEqual(atPath: live, andPath: variant)
    }

    /// Re-seal a helper bundle after its `AppIcon.icns` was swapped in place.
    ///
    /// WHY (critical): a bundle's resources are covered by its code signature, so rewriting
    /// `AppIcon.icns` inside an already-signed helper **breaks the seal** — verified on a live
    /// install, which failed `codesign --verify` with "a sealed resource is missing or invalid /
    /// file modified: …/AppIcon.icns" while helpers that had never switched style verified clean.
    /// Apple's guidance is to avoid modifying an app the user has already run; short of the
    /// copy-modify-swap dance that would imply, re-sealing immediately restores a valid signature.
    ///
    /// Deliberately NOT `--deep`, unlike `codesignHelper`: only a resource of the outer bundle
    /// changed, so the nested Sparkle/Firebase frameworks keep their existing, still-valid
    /// signatures. Re-signing them on every appearance change would cost far more and Apple
    /// discourages `--deep` for signing in any case.
    ///
    /// Failure is logged, not thrown: the icon HAS changed by this point, and leaving the tile
    /// showing a stale icon would be worse than leaving the seal as broken as it is today.
    private func resealAfterIconSwap(at helperPath: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", helperPath.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                DiagnosticsLog.shared.log(
                    "helper",
                    "Re-seal FAILED (status \(process.terminationStatus)) after icon swap for \(helperPath.lastPathComponent) — signature left invalid"
                )
                return
            }
        } catch {
            DiagnosticsLog.shared.log(
                "helper",
                "Re-seal could not run after icon swap for \(helperPath.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    /// Touch bundle to invalidate icon cache and re-register with Launch Services
    /// This forces macOS to reload the icon from the .icns file
    /// Invalidate macOS icon cache and re-register with Launch Services.
    ///
    /// Two-step process:
    /// 1. **Update modification date** — macOS uses mtime to detect when an app bundle has changed.
    ///    Without this, `iconservicesd` may serve stale cached icons even after the .icns file is replaced.
    /// 2. **Re-register with Launch Services** (`LSRegisterURL(_:inUpdate:)`) — Forces the LS
    ///    database to re-index the app bundle, picking up the new `CFBundleIconFile` and any plist
    ///    changes. `inUpdate: true` forces re-registration even if the bundle appears unchanged.
    private func touchBundle(at helperPath: URL) {
        let now = Date()
        let fm = FileManager.default

        // Step 1: Update modification dates to invalidate icon services cache
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: helperPath.path)
        let iconFilePath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns").path
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: iconFilePath)

        // Step 2: Re-register with Launch Services to refresh its index.
        //
        // Uses the PUBLIC `LSRegisterURL` (macOS 10.3+, not deprecated) rather than spawning the
        // `lsregister` tool. Apple DTS is explicit that lsregister is "for debugging only; ... not
        // considered API" and "do not ship anything that depends on the presence or output of this
        // tool" — and we were shipping it on a path driven by an appearance poll. `inUpdate: true`
        // is the same semantic as the `-f` (force) flag we passed.
        //
        // This also drops two costs: the synchronous `waitUntilExit()` that blocked the calling
        // actor while a subprocess launched, and the `-R` recursive descent, which walked into the
        // bundled Sparkle, Firebase and Google frameworks on every single icon change for no
        // benefit — only the app bundle itself needs re-registering.
        let status = LSRegisterURL(helperPath as CFURL, true)
        if status != noErr {
            DiagnosticsLog.shared.log(
                "helper",
                "LSRegisterURL failed for \(helperPath.lastPathComponent) (OSStatus \(status))"
            )
        }
    }

    // MARK: - Icon Path Helpers

    /// Get the icon filename for a given icon style
    /// - Parameter style: The icon style
    /// - Returns: The filename (e.g., "AppIcon-dark.icns")
    nonisolated private static func iconFilename(for style: IconStyle) -> String {
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
            try replaceIconAtomically(source: actualSourcePath, destination: destIconPath)
            print("[HelperBundleManager] Switched icon to: \(actualSourcePath.lastPathComponent) (style: \(iconStyle.rawValue))")

            // Restore the signature seal the icon rewrite just broke. MUST happen before
            // touchBundle: codesign writes _CodeSignature and bumps the bundle's mtime itself, so
            // re-registering with Launch Services afterwards indexes the final, sealed state.
            HelperBundleManager.shared.resealAfterIconSwap(at: bundlePath)

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

    /// Atomically replace the live `AppIcon.icns` with `source`. The old two-step
    /// (remove, then copy) was interruptible: a thrown copy or a process killed between the
    /// calls left the helper with NO icon at all plus a broken seal, unrepaired until the
    /// once-per-session self-heal — and only if the tile was pinned. Stages the copy in the
    /// temp directory and swaps via `replaceItemAt`, so the destination either keeps its old
    /// bytes or has the new ones — never neither. Guarded by `IconSwapAtomicityTests`.
    nonisolated static func replaceIconAtomically(source: URL, destination: URL) throws {
        let fm = FileManager.default
        let staged = fm.temporaryDirectory
            .appendingPathComponent("docktile-icon-\(UUID().uuidString).icns")
        try fm.copyItem(at: source, to: staged)
        defer { try? fm.removeItem(at: staged) }
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: staged)
        } else {
            try fm.moveItem(at: staged, to: destination)
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

    /// Re-seat a pinned helper's Dock entry — remove it from `persistent-apps` and re-add it at the
    /// same index — WITHOUT restarting the Dock, so a *subsequent* single restart makes the Dock load
    /// a FRESH icon for it. No-op if the tile isn't pinned.
    ///
    /// WHY (critical): after an **in-place** regenerate, `touchBundle` (mtime bump + `lsregister`)
    /// does NOT invalidate the Dock's per-entry icon cache — the Dock keeps drawing the OLD render
    /// for the unchanged persistent-apps entry even though `AppIcon.icns` on disk is new. Only
    /// re-adding the entry (which mints a new GUID) forces a fresh icon load. This is exactly why
    /// `installHelper` (remove + re-add) shows the new icon immediately, while the migration/self-heal
    /// batch — which regenerated in place and only restarted the Dock — kept showing stale icons
    /// until the user manually re-configured each tile.
    func refreshDockEntry(for config: DockTileConfiguration) {
        guard findInDock(bundleId: config.bundleIdentifier) != nil else { return }
        let index = findDockIndex(bundleId: config.bundleIdentifier)
        guard removeFromDockPlist(bundleId: config.bundleIdentifier) else { return }
        addToDock(at: helperPath(for: config), atIndex: index)
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

        // Read the helper's Info.plist once: bundle ID for identity, display name for the label.
        let infoPlistPath = appPath.appendingPathComponent("Contents/Info.plist")
        let infoPlist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] ?? [:]
        guard let bundleId = infoPlist["CFBundleIdentifier"] as? String else {
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
                // Shown verbatim as the tile's tooltip — the display name, never the folder stem.
                "file-label": Self.dockFileLabel(
                    infoPlist: infoPlist,
                    folderStem: appPath.deletingPathExtension().lastPathComponent
                ),
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

    /// Quit the Dock and block until the process has actually exited, then let launchd bring it
    /// back (the same lifecycle `restartDock()` relies on).
    ///
    /// WHY (critical): `killall Dock` only *signals* the Dock. A Dock that still holds the previous
    /// `persistent-apps` in memory writes that stale list back to cfprefsd as it shuts down, which
    /// can silently undo a removal we just wrote — the "STILL in Dock after restart" line. Writing
    /// only after the process is gone leaves nothing behind to flush on top of us. Measured on
    /// 2026-08-29: plain write-then-`killall` removals stranded 7 entries that a single
    /// quit-then-write pass cleaned up. Used only on the retry path, so the common case is
    /// unchanged.
    private func quitDockAndWaitForExit(timeout: TimeInterval = 3) {
        restartDock()  // posts .dockDidRestart for Dock Lock

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").isEmpty {
                print("   ✓ Dock process exited")
                return
            }
            usleep(10_000)  // 10ms
        }
        print("   ⚠️ Dock still running after \(timeout)s — proceeding anyway")
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

        // 2. Write the tile icon into the bundle (same branch as install)
        try installTileIcons(for: config, at: helperPath)

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
