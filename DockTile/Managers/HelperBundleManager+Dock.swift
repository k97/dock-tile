//
//  HelperBundleManager+Dock.swift
//  DockTile
//
//  Dock plist reads, the Dock-entry identity predicate and addToDock, split out of
//  HelperBundleManager.swift (2026-11-04) so the Dock side can be read on its own. Pure move.
//
//  Kept in HelperBundleManager.swift on purpose, because they use members that are private to it:
//  removeFromDockPlist, refreshDockEntry, removeFromDock(at:), restartDock, dockRestartArguments,
//  and the verified restart (it mutates the private in-flight sets).
//
//  Swift 6 - Strict Concurrency
//

import AppKit
import CoreServices
import Foundation
import Security

extension HelperBundleManager {
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
}
