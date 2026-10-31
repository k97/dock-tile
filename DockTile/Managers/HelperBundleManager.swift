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

    /// Track bundle IDs currently inside the bundle-BUILD critical section
    /// (`generateHelperBundle` → `installTileIcons` → `codesignHelper`). Both entry points —
    /// `installHelper` and `regenerateHelperBundle` — register here, because that sequence now
    /// suspends (see `canBeginBundleBuild`) and the main actor no longer serialises it for free.
    private var buildingBundleIds: Set<String> = []

    /// Track bundle IDs currently being removed to prevent double-removal
    private var removingBundleIds: Set<String> = []
    /// Per-tile count of `restartDockAndVerify` runs checking it (see `verifyingBundleIds`).
    private var verifyingCounts: [String: Int] = [:]

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

    /// Mutual exclusion for the bundle-BUILD critical section (`generateHelperBundle` →
    /// `installTileIcons` → `codesignHelper`).
    ///
    /// **Why a lock is needed at all (critical)**: that sequence used to contain no `await`, so the
    /// main actor serialised it implicitly. Moving the icon compile and the codesign off the main
    /// actor (to kill a ~1.4 s hang per tile) inserted suspension points into it, so two callers can
    /// now be parked inside it for the same `preferredHelperPath`: a migration / Popover-Appearance
    /// batch calls `regenerateHelperBundle` while the UI stays live, and a user pressing **Update**
    /// calls `installHelper`, whose `generateHelperBundle` deletes and re-copies the very directory
    /// the suspended regenerate is about to write into and sign. That is the "killed
    /// mid-generation" shape (`helperIconsComplete` false, or a broken seal) that only
    /// `selfHealIfNeeded` repairs, with a Dock restart, in the user's real support folder.
    ///
    /// Both entry points register in `buildingBundleIds` with `defer`-ed removal, so a second
    /// operation on the same bundle id is REFUSED rather than interleaved. Guarded by
    /// `HelperBuildExclusionTests`.
    nonisolated static func canBeginBundleBuild(bundleId: String, inFlight: Set<String>) -> Bool {
        !inFlight.contains(bundleId)
    }

    /// Install a helper bundle for the given configuration, or update the existing one (found by
    /// bundle ID). The new bundle is built in staging and swapped in, so the old one stays whole and
    /// running (showing the rebuild bar) until then — see `runStagedRebuild`.
    ///
    /// Returns `false` when a build for this bundle id is already in flight and this install was
    /// refused — the caller must NOT then stamp `helperAppVersion`, or the config would claim a
    /// rebuild that never happened (a stamp-only lie migration can never re-detect).
    @discardableResult
    func installHelper(for config: DockTileConfiguration) async throws -> Bool {
        // Refuse if another build (install OR regenerate) owns this bundle — see canBeginBundleBuild.
        guard Self.canBeginBundleBuild(bundleId: config.bundleIdentifier, inFlight: buildingBundleIds) else {
            print("⚠️ Skipping install - already in progress for: \(config.name)")
            DiagnosticsLog.shared.log("tile", "installHelper SKIPPED (bundle build already in progress) — \(config.diagnosticName)")
            return false
        }

        // Refuse early (with an actionable error) if we can't safely copy ourselves as a template.
        try verifyCanGenerateBundles()

        buildingBundleIds.insert(config.bundleIdentifier)
        defer { buildingBundleIds.remove(config.bundleIdentifier) }

        print("🔧 Installing helper for: \(config.name)")
        print("   Bundle ID: \(config.bundleIdentifier)")

        // Crashlytics breadcrumb: which step of the fragile install flow we're in, so a
        // crash here is attributable. Cleared at the end of a successful install.
        AnalyticsService.shared.setBreadcrumb(config.bundleIdentifier, for: "installing_bundle_id")
        AnalyticsService.shared.setBreadcrumb("start", for: "install_step")

        // Check if this bundle ID is already in the Dock (might be with different name)
        let wasInDock = findInDock(bundleId: config.bundleIdentifier) != nil

        // The Dock position to keep: live when pinned, else the saved lastDockIndex
        let originalDockIndex: Int?
        if wasInDock {
            originalDockIndex = findDockIndex(bundleId: config.bundleIdentifier)
        } else {
            // Use saved position from config (set when tile was hidden)
            originalDockIndex = config.lastDockIndex
        }

        print("   wasInDock: \(wasInDock), originalIndex: \(originalDockIndex ?? -1), savedLastDockIndex: \(config.lastDockIndex ?? -1)")

        // 1–4. Build in staging while the old helper keeps running (it shows the rebuild bar), then
        // swap the complete, signed bundle in, register and launch it. The Dock entry is NOT removed
        // first any more: that only guarded against the Dock relaunching a half-built bundle, and
        // the tile's folder never holds one now.
        AnalyticsService.shared.setBreadcrumb("bundle_copy", for: "install_step")
        let helperPath = try await buildAndSwap(for: config)
        print("   ✓ Built, signed and swapped in")

        // 5. Re-seat a pinned entry (a new GUID makes the Dock load the new icon) at its slot, or
        // add a new tile at its saved position (end when none).
        if wasInDock {
            refreshDockEntry(for: config)
        } else {
            addToDock(at: helperPath, atIndex: originalDockIndex)
        }

        // 6–8. Restart the Dock, then verify the entry is at THIS helper's path (retrying once).
        // A failure is thrown at the end, after the helper is launched: the bundle is built either way.
        AnalyticsService.shared.setBreadcrumb("dock_restart", for: "install_step")
        let dockKept = await restartDockAndVerify(
            [DockExpectation(bundleId: config.bundleIdentifier, path: helperPath.path,
                             index: originalDockIndex, name: config.diagnosticName)],
            ownedBundleIds: [config.bundleIdentifier])

        AnalyticsService.shared.setBreadcrumb("done", for: "install_step")
        print("✅ Helper installed at: \(helperPath.path)")
        guard dockKept else { throw HelperBundleError.dockChangeNotKept }
        return true
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

        // Restart Dock after bundle is deleted to avoid "?" icon — but only if the Dock changed.
        // A removal that didn't stick is logged only: the config is already gone, and the caller
        // only records errors.
        if didRemoveFromDock {
            let removed = await restartDockAndVerify(
                [DockExpectation(bundleId: config.bundleIdentifier, path: nil, index: nil, name: config.diagnosticName)],
                ownedBundleIds: [config.bundleIdentifier])
            if !removed {
                DiagnosticsLog.shared.log("dock", "Delete of \(config.diagnosticName): its Dock entry is still there after the retry")
            }
        } else {
            print("   ✓ Tile was not in the Dock — Dock not restarted")
        }

        print("✅ Helper uninstalled for: \(config.name)")
    }

    /// Info.plist key holding `DockTileConfiguration.iconSignature` of the look a helper was built from.
    nonisolated static let iconSignatureKey = "DTIconSignature"

    /// The tile's helper on disk and the look it was built from (`nil` signature = a helper built
    /// before the stamp existed). `nil` when no helper exists. Scans the helper folder, so callers
    /// only reach for it when they need it (`TileFace` does so under the Tinted style only).
    func builtIconSignature(for config: DockTileConfiguration) -> (path: URL, signature: String?)? {
        guard let path = findExistingHelper(bundleId: config.bundleIdentifier) else { return nil }
        let plist = NSDictionary(contentsOf: path.appendingPathComponent("Contents/Info.plist"))
        return (path, plist?[Self.iconSignatureKey] as? String)
    }

    /// Info.plist key holding `DockTileConfiguration.dockSignature` of the tile a helper was built from.
    nonisolated static let dockSignatureKey = "DTDockSignature"

    /// `DockTileConfiguration.dockSignature` of the tile the helper on disk was built from; `nil` when
    /// no helper exists or it was built before the stamp. Scans the helper folder (one plist read per
    /// helper), so Tile Detail reads it on appear and after an action only.
    func builtDockSignature(for config: DockTileConfiguration) -> String? {
        guard let path = findExistingHelper(bundleId: config.bundleIdentifier) else { return nil }
        let plist = NSDictionary(contentsOf: path.appendingPathComponent("Contents/Info.plist"))
        return plist?[Self.dockSignatureKey] as? String
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

    /// Each pinned bundle id → its entries' paths in Dock order (nil = unparseable), in ONE
    /// synchronized read — what self-heal feeds to the shared `dockEntriesAreCurrent` predicate.
    func pinnedEntryPaths() -> [String: [String?]] {
        var paths: [String: [String?]] = [:]
        for entry in readPersistentApps() {
            if let id = (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String {
                paths[id, default: []].append(Self.dockEntryPath(entry))
            }
        }
        return paths
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
    ///
    /// `sealStates` comes from `helperSealStates()` (keyed by bundle folder name) so the ~70 ms
    /// `SecStaticCodeCheckValidity` pass this report already ran for the signatures section is
    /// reused here rather than repeated per pinned tile.
    func collectIconInventory(
        configurations: [DockTileConfiguration], sealStates: [String: HelperSealState]
    ) -> [HelperIconInventory] {
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
                // Both sides enumerate the same support folder, so the lookup always hits; the
                // fallback keeps a miss honest rather than silently reporting a valid seal BROKEN.
                let seal = sealStates[bundlePath.lastPathComponent] ?? Self.sealState(bundlePath: bundlePath)
                return Self.inspectIconShape(
                    bundlePath: bundlePath, tileName: config.diagnosticName, sealValid: seal.isValid)
            }
    }

    /// Seal state for every helper bundle in the support folder, keyed by bundle folder name
    /// (`<name>.app`) — unique within one directory. One `SecStaticCodeCheckValidity` per bundle,
    /// which is the whole point: see `HelperSealState`.
    func helperSealStates() -> [String: HelperSealState] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: helperDirectory, includingPropertiesForKeys: nil
        ) else { return [:] }

        var states: [String: HelperSealState] = [:]
        for bundle in entries where bundle.pathExtension == "app" {
            states[bundle.lastPathComponent] = Self.sealState(bundlePath: bundle)
        }
        return states
    }

    /// Inspects one helper bundle's Resources folder: seal validity, which icon shape it's
    /// actually in (legacy variant match vs declarative `Assets.car`, determined from what's
    /// really on disk — NOT from `IconPipeline.isDeclarative`, since a machine mid-migration can
    /// hold both shapes at once), and every icon file's mtime.
    private static func inspectIconShape(
        bundlePath: URL, tileName: String, sealValid: Bool
    ) -> HelperIconInventory {
        let resources = bundlePath.appendingPathComponent("Contents/Resources")
        let fm = FileManager.default

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

    /// THE code-signature check for helper bundles — Security.framework, no subprocess. The only
    /// implementation: both Copy Diagnostics sections read its result through `helperSealStates()`
    /// rather than validating a bundle twice.
    nonisolated static func sealState(bundlePath: URL) -> HelperSealState {
        var staticCode: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(bundlePath as CFURL, [], &staticCode)
        guard created == errSecSuccess, let code = staticCode else { return .unreadable(created) }
        let status = SecStaticCodeCheckValidity(code, [], nil)
        return status == errSecSuccess ? .valid : .broken(status)
    }

    /// `assetutil --info <car>`, summarised to "<N> renditions, IconImageStack: yes/no". Read-only
    /// (info only — never `--compile` or anything that writes). stderr is discarded and stdout,
    /// the only pipe, is read to EOF on THIS thread before `waitUntilExit`, so a full pipe can't
    /// block the child and nothing waits on another thread (draining on `DispatchQueue.global`
    /// blocks could starve — see `IconCompiler.compile`). Returns `nil` on any failure (missing
    /// binary, non-zero exit, unparseable JSON) rather than throwing — a broken car degrades this
    /// one field, not the whole report.
    private static func carRenditionSummary(carURL: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/assetutil")
        process.arguments = ["--info", carURL.path]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
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

        // Also prevent removal while a bundle build (install or regenerate) is in progress.
        //
        // THROWS rather than returning nil (critical): `nil` already means "there was nothing to
        // remove", and the caller writes `isVisibleInDock = false` on that. Reporting a REFUSAL the
        // same way produces the documented "hidden in config but still pinned" desync — the tile is
        // marked hidden while its Dock entry is untouched, and nothing heals it until the next
        // launch reconcile. Widening this guard from installs to all bundle builds (so a migration
        // or Apply batch is covered too) widened that window, which is why the signal had to become
        // unambiguous. Both call sites already catch: Tile Detail surfaces the message and leaves
        // visibility alone, and the stuck-tile sweep logs and retries on the next launch.
        guard Self.canBeginBundleBuild(bundleId: config.bundleIdentifier, inFlight: buildingBundleIds) else {
            print("⚠️ Skipping remove - bundle build in progress for: \(config.name)")
            DiagnosticsLog.shared.log("dock", "removeFromDock REFUSED (bundle build in progress) — \(config.diagnosticName)")
            throw HelperBundleError.bundleBuildInProgress
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
            // Restart, then verify no entry for this tile is left (retrying once). A removal that
            // did not stick THROWS: returning normally would make the caller store the tile hidden
            // while it is still pinned.
            let removed = await restartDockAndVerify(
                [DockExpectation(bundleId: config.bundleIdentifier, path: nil, index: nil, name: config.diagnosticName)],
                ownedBundleIds: [config.bundleIdentifier])
            guard removed else { throw HelperBundleError.dockChangeNotKept }
            print("   ✓ Verified tile removed from Dock")
            DiagnosticsLog.shared.log("dock", "Removed \(config.diagnosticName) from Dock (verified)")
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
        showInAppSwitcher: Bool,
        iconSignature: String,
        dockSignature: String
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
            showInAppSwitcher: showInAppSwitcher,
            iconSignature: iconSignature,
            dockSignature: dockSignature
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
    private func installTileIcons(for config: DockTileConfiguration, at helperPath: URL) async throws {
        let resourcesPath = helperPath.appendingPathComponent("Contents/Resources")

        // Apps face: bake the tile's installed apps instead of its symbol/emoji. With none, the
        // empty 2x2's slots — an App Grid never falls back to the tile's symbol (owner, 2026-10-22).
        if config.iconFace == .apps {
            let face = appsFaceEntries(for: config)
            if face.entries.isEmpty {
                DiagnosticsLog.shared.log("tile", "Apps face for \(config.diagnosticName): no installed items — baking the empty grid")
            }
            if face.skipped > 0 {
                DiagnosticsLog.shared.log("tile", "Apps face for \(config.diagnosticName): skipped \(face.skipped) missing item(s)")
            }
            if IconPipeline.isDeclarative {
                // One grid per appearance slot, each app rendered in that slot's style — NOT the
                // style the system happens to be in during this Update. The fallback `.icns` (the
                // light composition) takes the Default renders for the same reason.
                var layerPNGs: [String: Data] = [:]
                var standardMinis: [IconGenerator.AppsFaceMini] = []
                var fallbacks = 0
                for style in AppIconRenderStyle.allCases {
                    let styled = Self.styledAppsFaceMinis(face.entries, style: style)
                    fallbacks += styled.fallbacks
                    if style == .standard { standardMinis = styled.minis }
                    layerPNGs[IconDocumentBuilder.appsFaceImageName(for: style)] =
                        try IconGenerator.generateAppsLayerPNG(minis: styled.minis, onDarkGlass: AppsFaceGrid.layerOnDarkGlass(
                            slot: style, background: config.appsBackground, customHex: config.appsBackgroundColor))
                }
                if fallbacks > 0 {
                    DiagnosticsLog.shared.log("tile", "Apps face for \(config.diagnosticName): \(fallbacks) styled render(s) unavailable — used the current-style icon")
                }
                try await installCompiledIcon(
                    json: IconDocumentBuilder.appsFaceIconJSON(
                        background: config.appsBackground, customHex: config.appsBackgroundColor), layerPNGs: layerPNGs, resourcesPath: resourcesPath)
                try IconGenerator.generateAppsFallbackIcns(
                    minis: standardMinis,
                    outputURL: resourcesPath.appendingPathComponent("AppIcon.icns"),
                    background: config.appsBackground, customHex: config.appsBackgroundColor
                )
                print("   ✓ Compiled Apps-face icon (Assets.car + fallback AppIcon.icns)")
            } else {
                let minis = face.entries.map { IconGenerator.AppsFaceMini(image: $0.image, isFolder: $0.item.isFolder) }
                for style in IconStyle.allCases {
                    try IconGenerator.generateAppsIcns(
                        minis: minis,
                        outputURL: iconPath(for: style, in: resourcesPath),
                        iconStyle: style,
                        background: config.appsBackground, customHex: config.appsBackgroundColor
                    )
                    print("   ✓ Generated \(style.rawValue) style Apps-face icon")
                }
                let currentStyle = IconStyle.current
                let sourceIconPath = iconPath(for: currentStyle, in: resourcesPath)
                let iconDestPath = resourcesPath.appendingPathComponent("AppIcon.icns")
                try? FileManager.default.removeItem(at: iconDestPath)
                try FileManager.default.copyItem(at: sourceIconPath, to: iconDestPath)
                print("   ✓ Set active icon (style: \(currentStyle.rawValue))")
            }
            return
        }

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
                    background: config.background,
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

        try await installDeclarativeIcon(for: config, resourcesPath: resourcesPath)
        print("   ✓ Compiled declarative icon (Assets.car + fallback AppIcon.icns)")
    }

    /// One item an Apps-face tile draws, with its icon from the public loader (the current system
    /// style) — the fallback whenever a styled render is unavailable.
    struct AppsFaceEntry {
        let item: AppItem
        let image: NSImage
    }

    /// The installed items an Apps-face tile draws, resolved to images. An item whose icon
    /// cannot be loaded counts as skipped, like a missing one.
    func appsFaceEntries(for config: DockTileConfiguration) -> (entries: [AppsFaceEntry], skipped: Int) {
        let picked = AppsFaceGrid.select(items: config.appItems) { AppInstallChecker.isInstalled($0) }
        var skipped = picked.skipped
        var entries: [AppsFaceEntry] = []
        for item in picked.selected {
            guard let image = AppIconLoader.icon(for: item) else { skipped += 1; continue }
            entries.append(AppsFaceEntry(item: item, image: image))
        }
        return (entries, skipped)
    }

    /// The minis for one `.icon` appearance slot: each app re-rendered in `style` through
    /// `AppIconStyleRenderer`, at its draw-box size on the 1024 canvas. Folders (IconServices draws
    /// them the same in every style) keep the public image; so does an app the private renderer
    /// cannot draw, counted in `fallbacks`.
    static func styledAppsFaceMinis(_ entries: [AppsFaceEntry], style: AppIconRenderStyle)
        -> (minis: [IconGenerator.AppsFaceMini], fallbacks: Int) {
        guard let cell = AppsFaceGrid.cells(count: entries.count).first else { return ([], 0) }
        let pixelSize = Int((AppsFaceGrid.drawBox(for: cell, isFolder: false).width * 1024).rounded(.up))
        var fallbacks = 0
        let minis = entries.map { entry -> IconGenerator.AppsFaceMini in
            guard !entry.item.isFolder else { return .init(image: entry.image, isFolder: true) }
            guard let path = AppInstallChecker.resolve(entry.item).resolvedPath,
                  let rendered = AppIconStyleRenderer.render(
                    appAt: URL(fileURLWithPath: path).resolvingSymlinksInPath(), pixelSize: pixelSize, style: style)
            else {
                fallbacks += 1
                return .init(image: entry.image, isFolder: false)
            }
            return .init(image: NSImage(cgImage: rendered, size: NSSize(width: pixelSize, height: pixelSize)),
                         isFolder: false)
        }
        return (minis, fallbacks)
    }

    struct DeclarativeFills {
        let lightTop, lightBottom, darkTop, darkBottom, tintedTop, tintedBottom: (r: Double, g: Double, b: Double)
    }

    /// The `.icon` background fills for a tile, Display-P3 — read from `TilePalette` through
    /// `nsColors`, so the compiled icon, the fallback `.icns` and the preview cannot drift
    /// (a Dark emoji fill included).
    nonisolated static func declarativeFillsP3(for config: DockTileConfiguration) throws -> DeclarativeFills {
        let light = config.tintColor.nsColors(for: .defaultStyle, iconType: config.iconType, background: config.background)
        let dark = config.tintColor.nsColors(for: .dark, iconType: config.iconType, background: config.background)
        let tinted = config.tintColor.nsColors(for: .tinted, iconType: config.iconType, background: config.background)
        return DeclarativeFills(
            lightTop: try p3Components(light.backgroundTop), lightBottom: try p3Components(light.backgroundBottom),
            darkTop: try p3Components(dark.backgroundTop), darkBottom: try p3Components(dark.backgroundBottom),
            tintedTop: try p3Components(tinted.backgroundTop), tintedBottom: try p3Components(tinted.backgroundBottom))
    }

    /// macOS 26+: author an Icon Composer `.icon` document for this tile, compile it to a
    /// per-tile `Assets.car`, and drop one fallback `.icns` beside it. The system then renders
    /// every appearance itself — no variants, no detection, and the bundle's icon is never
    /// touched again after signing.
    private func installDeclarativeIcon(for config: DockTileConfiguration, resourcesPath: URL) async throws {
        let (specs, pngs) = try declarativeLayerSpecs(for: config)

        // Backgrounds are JSON fills, not pixels (see `declarativeFillsP3`).
        let fills = try Self.declarativeFillsP3(for: config)

        let json = IconDocumentBuilder.iconJSON(
            fillTopP3: fills.lightTop,
            fillBottomP3: fills.lightBottom,
            darkFillTopP3: fills.darkTop,
            darkFillBottomP3: fills.darkBottom,
            tintedFillTopP3: fills.tintedTop,
            tintedFillBottomP3: fills.tintedBottom,
            layers: specs
        )

        try await installCompiledIcon(json: json, layerPNGs: pngs, resourcesPath: resourcesPath)

        // ONE fallback `.icns` (not four variants) for the contexts that read `CFBundleIconFile`.
        try IconGenerator.generateFallbackIcns(
            tintColor: config.tintColor,
            background: config.background,
            iconType: config.iconType,
            iconValue: config.iconValue,
            iconScale: config.iconScale,
            iconWeight: config.iconWeight,
            outputURL: resourcesPath.appendingPathComponent("AppIcon.icns")
        )
    }

    /// Writes `json` + layer PNGs as an `.icon` document in scratch, compiles it, and installs
    /// the resulting `Assets.car` into the helper's Resources.
    private func installCompiledIcon(json: [String: Any], layerPNGs pngs: [String: Data], resourcesPath: URL) async throws {
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
        let car = try await IconCompiler.compileOffMain(
            document: document,
            outputDir: scratch.appendingPathComponent("compiled"),
            compilerURL: compiler
        )

        let carDestination = resourcesPath.appendingPathComponent("Assets.car")
        try? FileManager.default.removeItem(at: carDestination)
        try FileManager.default.copyItem(at: car, to: carDestination)
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
                background: config.background,
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
    /// `nsColors(for:iconType:background:)` and is component-backed, so the conversion should not fail — which
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

    private func updateInfoPlist(at helperPath: URL, bundleId: String, appName: String, showInAppSwitcher: Bool,
                                 iconSignature: String, dockSignature: String) throws {
        let infoPlistPath = helperPath.appendingPathComponent("Contents/Info.plist")

        guard let base = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] else {
            throw HelperBundleError.infoPlistReadFailed
        }

        let plist = Self.helperInfoPlist(
            from: base,
            bundleId: bundleId,
            appName: appName,
            showInAppSwitcher: showInAppSwitcher,
            declarative: IconPipeline.isDeclarative,
            iconSignature: iconSignature,
            dockSignature: dockSignature
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
    ///   • Record the look the icon is built from (`iconSignatureKey`) — see `builtIconSignature` —
    ///     and everything the helper shows (`dockSignatureKey`) — see `builtDockSignature`.
    nonisolated static func helperInfoPlist(
        from base: [String: Any],
        bundleId: String,
        appName: String,
        showInAppSwitcher: Bool,
        declarative: Bool,
        iconSignature: String,
        dockSignature: String
    ) -> [String: Any] {
        var plist = base
        plist[iconSignatureKey] = iconSignature
        plist[dockSignatureKey] = dockSignature

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
        plist.removeValue(forKey: "SUAutomaticallyUpdate")

        // Only the main app should claim the docktile:// URL scheme.
        plist.removeValue(forKey: "CFBundleURLTypes")

        return plist
    }

    private func codesignHelper(at helperPath: URL) async throws {
        // `codesign --deep` waits hundreds of ms; do that wait off the main actor.
        let status = try await Task.detached(priority: .userInitiated) {
            try Self.runCodesign(path: helperPath.path)
        }.value

        guard status == 0 else {
            DiagnosticsLog.shared.log("dock", "codesign FAILED (status \(status)) for \(helperPath.lastPathComponent)")
            throw HelperBundleError.codesignFailed
        }
    }

    private nonisolated static func runCodesign(path: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
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
            // The bundle-identifier stored in tile-data comes FIRST, before the URL is parsed: an
            // entry whose URL can't be parsed is still this tile's (the shared predicate counts it
            // as a stale entry), so an "expect absent" retry must be able to remove it.
            if let storedBundleId = (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String,
               storedBundleId == bundleId {
                print("   Found by tile-data bundle-identifier: \(Self.dockEntryPath(entry) ?? "<unparseable>")")
                return false  // Remove this entry
            }

            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString) else {
                return true  // Keep other entries we can't parse
            }

            let appPath = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

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
    /// WHY (critical): after a rebuild at the same path (in place before 2.6.3, staged + swapped
    /// since), `touchBundle` (mtime bump + `lsregister`) does NOT invalidate the Dock's per-entry
    /// icon cache — the Dock keeps drawing the OLD render for the unchanged persistent-apps entry
    /// even though the icon on disk is new. Only re-adding the entry (which mints a new GUID) forces
    /// a fresh icon load. The migration/self-heal batch once regenerated and only restarted the Dock,
    /// and kept showing stale icons until the user manually re-configured each tile; `installHelper`
    /// and the batch both re-seat through here now.
    func refreshDockEntry(for config: DockTileConfiguration) {
        // findDockIndex matches the bundle id BEFORE parsing the URL (findInDock skips an
        // unparseable entry), so the stale entries self-heal flags are re-seated too.
        guard let index = findDockIndex(bundleId: config.bundleIdentifier) else { return }
        guard removeFromDockPlist(bundleId: config.bundleIdentifier) else { return }
        addToDock(at: helperPath(for: config), atIndex: index)
    }

    // MARK: - Dock entry identity (2.6.2)
    //
    // ONE predicate for "is this tile's Dock entry current?", shared by addToDock, the verified
    // restart and self-heal so they can never disagree: exactly one entry, and it is the SAME FILE
    // as the helper (device + inode). WHY: on 2026-10-29 a rename + Update left an entry with the
    // right bundle id pointing at the deleted old folder, and every bundle-id-only check called it
    // fine. Same-file, not same-bundle-id: helperPath(for:) already finds the bundle BY id, so a
    // second path carrying that id is a leftover copy that would launch old code.

    /// The bundle id an entry carries in `tile-data` (our addToDock always writes it).
    nonisolated private static func tileBundleId(_ entry: [String: Any]) -> String? {
        (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
    }

    /// The entry's `_CFURLString` as a file path, normalised like `findInDock` (`%20` decoded,
    /// trailing slash trimmed). Accepts a plain absolute path too, as `findInDock` does. nil when
    /// the string is missing or any other scheme.
    nonisolated static func dockEntryPath(_ entry: [String: Any]) -> String? {
        guard let tileData = entry["tile-data"] as? [String: Any],
              let fileData = tileData["file-data"] as? [String: Any],
              let urlString = fileData["_CFURLString"] as? String else { return nil }
        let rawPath: String
        if urlString.hasPrefix("/") {
            rawPath = urlString
        } else if let url = URL(string: urlString), url.isFileURL {
            rawPath = url.path
        } else {
            return nil
        }
        return "/" + rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// One path per entry carrying `bundleId`, in Dock order; nil for an entry that can't be parsed.
    nonisolated static func dockEntryPaths(bundleId: String, in apps: [[String: Any]]) -> [String?] {
        apps.filter { tileBundleId($0) == bundleId }.map(dockEntryPath)
    }

    /// Current = exactly one entry, parseable, and the same file as the helper.
    nonisolated static func dockEntriesAreCurrent(_ paths: [String?], helperPath: String,
                                                  sameFile: (String, String) -> Bool) -> Bool {
        guard paths.count == 1, let path = paths[0] else { return false }
        return sameFile(path, helperPath)
    }

    /// Same file by `stat()` device + inode. `stat()` follows symlinks, and the
    /// `/System/Volumes/Data` spelling is the same file; a missing path is never the same file.
    nonisolated static func isSameFile(_ a: String, _ b: String) -> Bool {
        var statA = stat(), statB = stat()
        guard stat(a, &statA) == 0, stat(b, &statB) == 0 else { return false }
        return statA.st_dev == statB.st_dev && statA.st_ino == statB.st_ino
    }

    /// `apps` with this tile's entries replaced by `newEntry`, or nil when they are already current
    /// (no write needed). A stale, unparseable or duplicate entry is replaced in the FIRST slot it
    /// held; a missing one goes in at `atIndex` when that is in range, else at the end. Entries of
    /// other bundle ids are never touched.
    nonisolated static func reconciledDockApps(_ apps: [[String: Any]], bundleId: String, path: String,
                                               newEntry: [String: Any], atIndex: Int?,
                                               sameFile: (String, String) -> Bool) -> [[String: Any]]? {
        if dockEntriesAreCurrent(dockEntryPaths(bundleId: bundleId, in: apps), helperPath: path, sameFile: sameFile) {
            return nil
        }
        var result = apps.filter { tileBundleId($0) != bundleId }
        if let firstSlot = apps.firstIndex(where: { tileBundleId($0) == bundleId }) {
            // Every entry before the first match survived the filter, so the slot index is unchanged.
            result.insert(newEntry, at: firstSlot)
        } else if let index = atIndex, (0...result.count).contains(index) {
            result.insert(newEntry, at: index)
        } else {
            result.append(newEntry)
        }
        return result
    }

    /// Add app to Dock without launching it. When this tile already has entries, they are kept if
    /// current (`dockEntriesAreCurrent`) and otherwise replaced in their slot (`reconciledDockApps`).
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

        // Keep this tile's entry if it is current; otherwise replace it in its slot (or insert it at
        // the index / end). A same-bundle-id entry at another path is NOT "already in Dock": that is
        // exactly the stale entry the 2026-10-29 rename left behind.
        guard let updatedApps = Self.reconciledDockApps(currentApps, bundleId: bundleId, path: appPathString,
                                                        newEntry: newEntry, atIndex: atIndex,
                                                        sameFile: Self.isSameFile) else {
            print("   ✓ Already in Dock at this path - no action needed")
            return
        }
        let replacedPaths = Self.dockEntryPaths(bundleId: bundleId, in: currentApps)
        if !replacedPaths.isEmpty {
            DiagnosticsLog.shared.log("dock", "Replacing stale Dock entry at \(replacedPaths.map { $0 ?? "<unparseable>" }) with \(appPathString) (\(bundleId))")
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

    /// `killall` arguments for every Dock restart: SIGKILL, so the dying Dock cannot save its
    /// stale persistent-apps over the write we just made (SIGTERM lost 14/14 writes within 2.5 s
    /// of a restart, SIGKILL kept 13/13 — docs/dock-modification-prior-art.md §6). launchd
    /// relaunches the Dock either way (proven on macOS 15 and 26 by the `dock-kill-check` CI job).
    nonisolated static let dockRestartArguments = ["-KILL", "Dock"]

    /// Restart Dock to apply plist changes. Sends SIGKILL (see `dockRestartArguments`); the accepted
    /// cost is that a Dock edit the Dock hasn't saved yet (an icon dragged a moment ago) is lost.
    private func restartDock() {
        print("   🔄 Restarting Dock...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = Self.dockRestartArguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("   ✓ Dock restarted")
            } else {
                // killall exits 1 when no Dock process matched.
                DiagnosticsLog.shared.log("dock", "Dock restart: killall exited \(process.terminationStatus) (no Dock running?)")
            }
        } catch {
            DiagnosticsLog.shared.log("dock", "Dock restart FAILED: could not run killall — \(error.localizedDescription)")
        }

        // Let Dock Lock re-assert the anchor: a relaunched Dock can come back on a different
        // display, and the clamp only prevents drift — it doesn't relocate. Posted on the main
        // actor (this type is @MainActor); the handler no-ops unless the Dock actually drifted.
        NotificationCenter.default.post(name: .dockDidRestart, object: nil)
    }

    // MARK: - Verified Dock restart (2.6.2)
    //
    // Every Dock change goes through `restartDockAndVerify`: SIGKILL restart, wait for the new
    // Dock + 1 s, check each tile's entry with the shared predicate (`dockEntriesAreCurrent`),
    // retry once, never loop. It reads the plist, so it can't see the plist and the running Dock
    // disagree, and the +1 s read can come before the new Dock's own write-back (a few seconds
    // after launch). Accepted, but NOT because that write-back is always ours: on macOS 27 the
    // Dock re-resolves a pinned entry's path through Launch Services when it loads (issue #35), so
    // a stale LS registration can rewrite the entry after this check passed.

    /// What one tile's Dock entry must look like after a restart. `path == nil` = no entry at all;
    /// `index` is where a missing entry is re-added; `name` is the `diagnosticName`, for logs.
    struct DockExpectation: Equatable, Sendable {
        let bundleId: String
        let path: String?
        let index: Int?
        let name: String
    }

    /// The expectations NOT met by `apps`, in input order. Absent: no entry with the bundle id.
    /// Present: the shared predicate (`dockEntriesAreCurrent`).
    nonisolated static func unmetExpectations(_ expectations: [DockExpectation], in apps: [[String: Any]],
                                              sameFile: (String, String) -> Bool) -> [DockExpectation] {
        expectations.filter { expectation in
            let paths = dockEntryPaths(bundleId: expectation.bundleId, in: apps)
            guard let path = expectation.path else { return !paths.isEmpty }
            return !dockEntriesAreCurrent(paths, helperPath: path, sameFile: sameFile)
        }
    }

    /// A batch expects presence only for tiles that were pinned BEFORE it (keys of
    /// `pinnedIndices`, read before the re-seat), never for one the user dragged off: Popover Apply
    /// rebuilds `isVisibleInDock && helperExists` tiles, and expecting one of those would make the
    /// retry re-pin it.
    nonisolated static func batchExpectations(_ tiles: [(bundleId: String, path: String, name: String)],
                                              pinnedIndices: [String: Int]) -> [DockExpectation] {
        tiles.compactMap { tile in
            guard let index = pinnedIndices[tile.bundleId] else { return nil }
            return DockExpectation(bundleId: tile.bundleId, path: tile.path, index: index, name: tile.name)
        }
    }

    /// The unmet expectations a retry may act on: every one whose tile another of our operations
    /// is building or removing right now is left to that operation (Q16/Q18) — a batch's retry
    /// would otherwise re-pin a tile the user is hiding, or remove one the user is adding. `owned`
    /// keeps the caller's own tile, which it holds in `buildingBundleIds` / `removingBundleIds`.
    nonisolated static func retryableExpectations(_ unmet: [DockExpectation], busy: Set<String>,
                                                  owned: Set<String>) -> [DockExpectation] {
        unmet.filter { !busy.contains($0.bundleId) || owned.contains($0.bundleId) }
    }

    /// Per-tile verification counts. A count, not a set: two verifications can overlap on one
    /// tile, and with a set the first to finish would clear it while the second still checks it.
    nonisolated static func incrementingCounts(_ counts: [String: Int], for ids: [String]) -> [String: Int] {
        var result = counts
        for id in ids { result[id, default: 0] += 1 }
        return result
    }

    /// The inverse of `incrementingCounts`; a key that reaches 0 is dropped.
    nonisolated static func decrementingCounts(_ counts: [String: Int], for ids: [String]) -> [String: Int] {
        var result = counts
        for id in ids {
            let remaining = (result[id] ?? 0) - 1
            result[id] = remaining > 0 ? remaining : nil
        }
        return result
    }

    /// Restart, check, retry the unmet ones once, check those again. Everything external is
    /// injected so the control flow ("retry once, never loop", "leave busy tiles alone") is
    /// unit-tested (`DockExpectationTests`). Returns whether every expectation it owns is met.
    static func runDockVerification(_ expectations: [DockExpectation], ownedBundleIds: Set<String>,
                                    restartAndWait: () async -> Void, readApps: () -> [[String: Any]],
                                    busy: () -> Set<String>, applyFix: (DockExpectation) -> Void,
                                    sameFile: (String, String) -> Bool) async -> Bool {
        func leavingBusyTiles(_ unmet: [DockExpectation]) -> [DockExpectation] {
            let retryable = retryableExpectations(unmet, busy: busy(), owned: ownedBundleIds)
            for dropped in unmet where !retryable.contains(dropped) {
                DiagnosticsLog.shared.log("dock", "\(dropped.name) has another Dock operation in flight — leaving it to that operation")
            }
            return retryable
        }

        await restartAndWait()
        let firstApps = readApps()
        let toRetry = leavingBusyTiles(unmetExpectations(expectations, in: firstApps, sameFile: sameFile))
        guard !toRetry.isEmpty else { return true }

        // No `await` between the busy check above and these fixes, so a Hide can't start in between.
        for expectation in toRetry {
            let found = dockEntryPaths(bundleId: expectation.bundleId, in: firstApps).map { $0 ?? "<unparseable>" }
            DiagnosticsLog.shared.log("dock", "\(expectation.name) not at its expected Dock path after restart (found: \(found)) — retrying")
            applyFix(expectation)
        }

        // Re-check ONLY what was retried: a tile dropped as busy belongs to its own operation, and
        // re-checking it after that operation finished would report a false STILL.
        await restartAndWait()
        let unmetAfterRetry = unmetExpectations(toRetry, in: readApps(), sameFile: sameFile)
        let stillUnmet = leavingBusyTiles(unmetAfterRetry)
        for expectation in stillUnmet {
            DiagnosticsLog.shared.log("dock", "\(expectation.name) STILL not at its expected Dock path after retry")
        }
        let verified = toRetry.filter { !unmetAfterRetry.contains($0) }
        if !verified.isEmpty {
            DiagnosticsLog.shared.log("dock", "\(verified.map(\.name).joined(separator: ", ")) verified on retry")
        }
        return stillUnmet.isEmpty
    }

    /// The bundle ids a verification is checking right now (read by the Dock-plist watcher, which
    /// skips them — Q12).
    var verifyingBundleIds: Set<String> { Set(verifyingCounts.keys) }

    /// Whether any of our Dock operations is running for `bundleId`: a build (install or
    /// regenerate), a removal, or a verification (a batch checking it). The Dock-plist watcher
    /// leaves such a tile alone. NOT the build lock: `canBeginBundleBuild` sees only builds, so a
    /// Hide is never refused because a batch is verifying (Q9).
    nonisolated static func dockOperationInFlight(bundleId: String, building: Set<String>,
                                                  removing: Set<String>, verifying: Set<String>) -> Bool {
        building.contains(bundleId) || removing.contains(bundleId) || verifying.contains(bundleId)
    }

    func isDockOperationInFlight(bundleId: String) -> Bool {
        Self.dockOperationInFlight(bundleId: bundleId, building: buildingBundleIds,
                                   removing: removingBundleIds, verifying: verifyingBundleIds)
    }

    /// Restart the Dock and verify `expectations`, retrying once (`runDockVerification`). Runs in
    /// an unstructured task on purpose: once the Dock is killed the verification must finish, and a
    /// cancelled caller (the main window's `.task`, closed mid-batch) would otherwise turn every
    /// `Task.sleep` into an instant return and the PID poll into a spin.
    func restartDockAndVerify(_ expectations: [DockExpectation], ownedBundleIds: Set<String>) async -> Bool {
        let ids = expectations.map(\.bundleId)
        verifyingCounts = Self.incrementingCounts(verifyingCounts, for: ids)
        defer { verifyingCounts = Self.decrementingCounts(verifyingCounts, for: ids) }

        return await Task { @MainActor in
            await Self.runDockVerification(
                expectations, ownedBundleIds: ownedBundleIds,
                restartAndWait: { await self.restartDockAndWaitForNewDock() },
                readApps: { self.readPersistentApps() },
                busy: { self.buildingBundleIds.union(self.removingBundleIds) },
                applyFix: { expectation in
                    if let path = expectation.path {
                        self.addToDock(at: URL(fileURLWithPath: path), atIndex: expectation.index)
                    } else {
                        self.removeFromDockPlist(bundleId: expectation.bundleId)
                    }
                },
                sameFile: Self.isSameFile)
        }.value
    }

    /// SIGKILL the Dock, wait up to 5 s for a Dock with a NEW pid (the killed one can still be
    /// listed for a moment), then 1 s more. Assumes `NSRunningApplication` updates while the main
    /// actor is suspended in `Task.sleep`; a "no new Dock within 5 s" line on every restart would
    /// mean it doesn't.
    private func restartDockAndWaitForNewDock() async {
        let oldPID = Self.runningDockPID(other: nil)
        restartDock()
        let oldLabel = oldPID.map(String.init) ?? "none"
        if let newPID = await waitForDock(other: oldPID) {
            DiagnosticsLog.shared.log("dock", "Dock restarted (pid \(oldLabel) → \(newPID))", verbose: true)
        } else {
            // No Dock came back. launchd relaunches a SIGKILLed Dock, but one that something else
            // stopped cleanly just before (a Terminal `killall Dock`, another tool) is marked
            // "service inactive" and is NOT relaunched — measured 2026-10-30: the Dock stayed down
            // for over a minute. Start it ourselves rather than leave the user without a Dock.
            DiagnosticsLog.shared.log("dock", "no new Dock within 5 s (pid \(oldLabel)) — starting it via launchctl")
            kickstartDock()
            if let startedPID = await waitForDock(other: nil) {
                DiagnosticsLog.shared.log("dock", "Dock started via launchctl (pid \(startedPID))")
            } else {
                DiagnosticsLog.shared.log("dock", "Dock still not running after launchctl kickstart")
            }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    /// Polls every 50 ms, for up to 5 s, for a live Dock whose pid isn't `other` (nil = any Dock).
    private func waitForDock(other: pid_t?) async -> pid_t? {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let pid = Self.runningDockPID(other: other) { return pid }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    /// Starts the Dock's launchd agent (`launchctl kickstart gui/<uid>/com.apple.Dock.agent`).
    private func kickstartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "gui/\(getuid())/com.apple.Dock.agent"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                DiagnosticsLog.shared.log("dock", "launchctl kickstart of the Dock exited \(process.terminationStatus)")
            }
        } catch {
            DiagnosticsLog.shared.log("dock", "launchctl kickstart of the Dock FAILED — \(error.localizedDescription)")
        }
    }

    /// The pid of a live Dock other than `other` (nil = any live Dock).
    private static func runningDockPID(other: pid_t?) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
            .first { !$0.isTerminated && $0.processIdentifier != other }?
            .processIdentifier
    }

    /// `persistent-apps`, synchronized first (another app's domain can read stale otherwise).
    private func readPersistentApps() -> [[String: Any]] {
        let dockAppId = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(dockAppId)
        return CFPreferencesCopyAppValue("persistent-apps" as CFString, dockAppId) as? [[String: Any]] ?? []
    }

    // MARK: - Migration Support API

    /// Current main app version (marketing version string)
    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Rebuild a helper in staging and swap it in (then launch it), WITHOUT Dock operations.
    /// Used by HelperMigrationManager for batch updates (single Dock restart at end).
    func regenerateHelperBundle(for config: DockTileConfiguration) async throws {
        // Same critical section as installHelper, so the same lock — see canBeginBundleBuild.
        // THROWING (not returning) is deliberate: `runRegenerationBatch` stamps only on success, so
        // a refused regenerate is left unstamped and retried on a later launch, which is exactly
        // the convergent-migration behaviour a transient failure already gets.
        guard Self.canBeginBundleBuild(bundleId: config.bundleIdentifier, inFlight: buildingBundleIds) else {
            DiagnosticsLog.shared.log("migration", "regenerateHelperBundle REFUSED (bundle build already in progress) — \(config.diagnosticName)")
            throw HelperBundleError.bundleBuildInProgress
        }
        try verifyCanGenerateBundles()
        buildingBundleIds.insert(config.bundleIdentifier)
        defer { buildingBundleIds.remove(config.bundleIdentifier) }

        _ = try await buildAndSwap(for: config)
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

    /// Launch helper for a config (public for migration). Skips a running helper: opening a running
    /// app can deliver a reopen, which would open its popover.
    func launchHelperIfExists(for config: DockTileConfiguration) {
        guard !isHelperRunning(bundleId: config.bundleIdentifier) else { return }
        if let path = findExistingHelper(bundleId: config.bundleIdentifier) {
            launchHelper(at: path)
        }
    }

    // MARK: - Staged rebuild (2.6.3)
    //
    // A tile's new bundle is built in a hidden staging folder on the same volume while its old helper
    // keeps running, then swapped in with ONE atomic rename. WHY: the in-place rebuild left the tile's
    // folder holding a copy of the main app, with the main app's bundle id, for a moment; the Dock
    // resolves a pinned entry by bundle id, so on 2026-10-29 Force Quit on a dead tile killed Dock
    // Tile itself mid-migration. The staging folder is dot-prefixed so Spotlight skips it, every
    // support-folder scan lists only top-level `*.app`, and it is never registered with Launch Services.

    /// `<support>/.staging`
    nonisolated static func stagingDirectory(helperDirectory: URL) -> URL {
        helperDirectory.appendingPathComponent(".staging", isDirectory: true)
    }

    /// `<support>/.staging/<bundleId>.app` — one per tile, so a leftover is found by the next build.
    nonisolated static func stagingBundleURL(helperDirectory: URL, bundleId: String) -> URL {
        stagingDirectory(helperDirectory: helperDirectory).appendingPathComponent("\(bundleId).app", isDirectory: true)
    }

    /// Put `staged` at `final` atomically. With a bundle already at `final`, `RENAME_SWAP` exchanges
    /// the two (so `final` always holds a complete bundle), then the old one, now at `staged`, is
    /// deleted. Needs APFS, which every supported boot volume is. On any failure `final` is untouched.
    nonisolated static func swapIntoPlace(staged: URL, final: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: staged.path) else {
            DiagnosticsLog.shared.log("tile", "Swap FAILED: no staged bundle at \(staged.path)")
            throw HelperBundleError.bundleCopyFailed
        }
        let exchanging = fm.fileExists(atPath: final.path)
        let status = exchanging
            ? renamex_np(staged.path, final.path, UInt32(RENAME_SWAP))
            : rename(staged.path, final.path)
        guard status == 0 else {
            let code = errno
            DiagnosticsLog.shared.log("tile", "Swap FAILED (\(exchanging ? "exchange" : "rename"), errno \(code): \(String(cString: strerror(code)))) for \(final.lastPathComponent)")
            throw HelperBundleError.bundleCopyFailed
        }
        if exchanging {
            do { try fm.removeItem(at: staged) } catch {
                DiagnosticsLog.shared.log("tile", "Old bundle left in staging after swap (\(error.localizedDescription)); removed on next launch")
            }
        }
    }

    /// The folder to delete after a swap: the tile's previous folder when a rename moved it, else
    /// nil. `contentsOfDirectory` and `appendingPathComponent` can spell one folder differently, and
    /// deleting on a false "different" AFTER the swap deletes the brand-new bundle. So: same
    /// standardized path without a trailing slash, OR the same file on disk (`isSameFile`) — a
    /// case-only rename (`utils.app` → `Utils.app`) is one folder on case-insensitive APFS.
    nonisolated static func oldFolderToRemove(existing: URL?, final: URL) -> URL? {
        guard let existing else { return nil }
        func normalized(_ url: URL) -> String {
            var path = url.standardizedFileURL.path
            while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
            return path
        }
        if normalized(existing) == normalized(final) { return nil }
        return isSameFile(existing.path, final.path) ? nil : existing
    }

    /// The staged rebuild's ORDER, with every side effect injected so it is pinned by
    /// `StagedRebuildTests`: build and sign while the old helper runs (posting the bar's stages), quit
    /// it, swap, remove a renamed tile's old folder, register, quit AGAIN (a Dock click in the gap
    /// relaunches the old bundle from the tile path), launch. A build failure cancels the bar and
    /// leaves the old tile untouched; a swap failure relaunches whatever bundle is still in place.
    static func runStagedRebuild(_ steps: StagedRebuildSteps) async throws {
        guard steps.acquireLock() else { throw HelperBundleError.bundleBuildInProgress }
        steps.post(.begin)
        do {
            try await steps.copy()
            steps.post(.copied)
            try await steps.buildIcons()
            steps.post(.iconsBuilt)
            try await steps.sign()
            steps.post(.signed)
        } catch {
            steps.post(.cancelled)
            steps.removeStaged()
            throw error
        }
        steps.post(.ready)
        await steps.quitOld()
        do {
            try steps.swap()
        } catch {
            steps.post(.cancelled)
            steps.removeStaged()
            steps.launchExisting()
            throw error
        }
        steps.removeOldFolder()
        steps.register()
        await steps.quitOld()
        steps.launchNew()
    }

    /// Build the tile's helper in staging and swap it into place (the one build path of
    /// `installHelper` and `regenerateHelperBundle`). Returns the final helper path; the new helper
    /// is running. Callers hold `buildingBundleIds` and have run `verifyCanGenerateBundles`.
    private func buildAndSwap(for config: DockTileConfiguration) async throws -> URL {
        let bundleId = config.bundleIdentifier
        let stagingDirectory = Self.stagingDirectory(helperDirectory: helperDirectory)
        let staged = Self.stagingBundleURL(helperDirectory: helperDirectory, bundleId: bundleId)
        let final = preferredHelperPath(for: config)
        // Decided BEFORE the swap: afterwards the tile's folder holds the new bundle.
        let oldFolder = Self.oldFolderToRemove(existing: findExistingHelper(bundleId: bundleId), final: final)
        var lock: TileBuildLock?
        defer { lock?.release() }

        let steps = StagedRebuildSteps(
            acquireLock: {
                lock = TileBuildLock.acquire(bundleId: bundleId, stagingDirectory: stagingDirectory)
                return lock != nil
            },
            post: { self.postRebuild($0, bundleId: bundleId) },
            copy: {
                try self.generateHelperBundle(
                    appName: self.sanitizeAppName(config.name), bundleId: bundleId, helperPath: staged,
                    showInAppSwitcher: config.showInAppSwitcher, iconSignature: config.iconSignature,
                    dockSignature: config.dockSignature)
            },
            buildIcons: { try await self.installTileIcons(for: config, at: staged) },
            sign: { try await self.codesignHelper(at: staged) },
            quitOld: { await self.quitHelperAndWait(bundleId: bundleId) },
            swap: { try Self.swapIntoPlace(staged: staged, final: final) },
            removeOldFolder: {
                // Never the folder now holding the new bundle, however it is spelled.
                guard let oldFolder, !Self.isSameFile(oldFolder.path, final.path) else { return }
                do { try FileManager.default.removeItem(at: oldFolder) } catch {
                    DiagnosticsLog.shared.log("tile", "Could not remove renamed tile's old folder \(oldFolder.lastPathComponent): \(error.localizedDescription)")
                }
            },
            removeStaged: { try? FileManager.default.removeItem(at: staged) },
            register: { self.touchBundle(at: final) },
            launchNew: { self.launchHelper(at: final) },
            launchExisting: {
                if let path = self.findExistingHelper(bundleId: bundleId) { self.launchHelper(at: path) }
            }
        )

        do {
            try await Self.runStagedRebuild(steps)
        } catch {
            DiagnosticsLog.shared.log("tile", "Staged rebuild FAILED for \(config.diagnosticName): \(error.localizedDescription)")
            throw error
        }
        DiagnosticsLog.shared.log("tile", "Swapped \(config.diagnosticName) into place")
        return final
    }

    /// Tell the tile's running helper how far its rebuild is (it draws the bar). A helper that is not
    /// running, or was built before 2.6.3, has no observer: the tile is then rebuilt silently.
    func postRebuild(_ stage: TileRebuildStage, bundleId: String) {
        DistributedNotificationCenter.default().postNotificationName(
            TileRebuildSignal.name, object: bundleId,
            userInfo: TileRebuildSignal.userInfo(stage), deliverImmediately: true)
    }

    /// Launch-time sweep of staging leftovers (main app only, from the launch maintenance task).
    func removeStaleStaging() {
        let removed = Self.removeStaleStaging(stagingDirectory: Self.stagingDirectory(helperDirectory: helperDirectory))
        if !removed.isEmpty {
            DiagnosticsLog.shared.log("tile", "Removed \(removed.count) stale staging bundle(s): \(removed.joined(separator: ", "))")
        }
    }

    /// Delete staging bundles no build owns (left by a crash or a Force Quit mid-build). A bundle is
    /// removed only when its tile's `TileBuildLock` can be taken, so another process's live build is
    /// never pulled from under it. Returns the removed folder names.
    nonisolated static func removeStaleStaging(stagingDirectory: URL) -> [String] {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: stagingDirectory.path)) ?? []
        var removed: [String] = []
        for name in items.sorted() where name.hasSuffix(".app") {
            let bundleId = String(name.dropLast(".app".count))
            guard let lock = TileBuildLock.acquire(bundleId: bundleId, stagingDirectory: stagingDirectory) else { continue }
            defer { lock.release() }
            if (try? FileManager.default.removeItem(at: stagingDirectory.appendingPathComponent(name))) != nil {
                removed.append(name)
            }
        }
        return removed
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

/// The side effects of one staged rebuild, injected into `HelperBundleManager.runStagedRebuild` so its
/// order is unit-tested without real bundles, Launch Services or the Dock.
@MainActor
struct StagedRebuildSteps {
    var acquireLock: () -> Bool
    var post: (TileRebuildStage) -> Void
    var copy: () async throws -> Void
    var buildIcons: () async throws -> Void
    var sign: () async throws -> Void
    var quitOld: () async -> Void
    var swap: () throws -> Void
    var removeOldFolder: () -> Void
    var removeStaged: () -> Void
    var register: () -> Void
    var launchNew: () -> Void
    var launchExisting: () -> Void
}

/// Exclusive per-tile build lock shared by every Dock Tile process of one build flavour (an
/// `flock`-style `O_EXLOCK` on `<staging>/<bundleId>.lock`). The in-process `buildingBundleIds` set
/// cannot see a second process; this can, and the kernel drops it when its holder dies, so a crash
/// never leaves a tile locked. Two `open()`s conflict even within one process.
final class TileBuildLock: @unchecked Sendable {
    private var fd: Int32

    private init(fd: Int32) { self.fd = fd }

    /// nil when another build (any process) holds this tile's lock, or the lock file can't be made.
    static func acquire(bundleId: String, stagingDirectory: URL) -> TileBuildLock? {
        try? FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let path = stagingDirectory.appendingPathComponent("\(bundleId).lock").path
        let fd = open(path, O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK, 0o644)
        return fd == -1 ? nil : TileBuildLock(fd: fd)
    }

    func release() {
        guard fd != -1 else { return }
        close(fd)
        fd = -1
    }

    deinit { release() }
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
    /// Another bundle build (install or regenerate) already owns this bundle id, so this one was
    /// refused rather than allowed to interleave — see `HelperBundleManager.canBeginBundleBuild`.
    case bundleBuildInProgress
    /// The Dock change was written, but after the restart and one retry the Dock still did not
    /// have it (`HelperBundleManager.restartDockAndVerify`).
    case dockChangeNotKept

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
        case .bundleBuildInProgress:
            return AppStrings.Error.bundleBuildInProgress
        case .dockChangeNotKept:
            return AppStrings.Error.dockChangeNotKept
        }
    }
}
