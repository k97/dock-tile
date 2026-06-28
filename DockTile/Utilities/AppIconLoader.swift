//
//  AppIconLoader.swift
//  DockTile
//
//  Shared utility for loading app icons from AppItem models.
//  Handles Asset Catalog detection, icon style awareness, and fallback paths.
//  Swift 6 - Strict Concurrency
//

import AppKit

@MainActor
enum AppIconLoader {

    /// Load the appropriate icon for an AppItem.
    /// - Resolves through `NSWorkspace` so the icon matches what the Dock / Finder / Mission
    ///   Control show — including macOS Tahoe's system-applied dark / clear / tinted treatment.
    /// - Falls back to common paths, then stored icon data.
    static func icon(for item: AppItem) -> NSImage? {
        // For folders, get icon from folder path
        if item.isFolder, let folderPath = item.folderPath {
            return NSWorkspace.shared.icon(forFile: folderPath)
        }

        // Get from bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return iconFromAppURL(appURL)
        }

        // The app still exists at its last-known path even though Launch Services no longer
        // resolves the bundle ID (app moved, or LS not yet re-registered after an update). Load
        // the live icon from disk rather than falling through to the stale cached `iconData`.
        if let lastKnownPath = item.lastKnownPath,
           FileManager.default.fileExists(atPath: lastKnownPath) {
            return iconFromAppURL(URL(fileURLWithPath: lastKnownPath))
        }

        // Try common paths for apps
        for path in AppInstallChecker.commonSearchPaths(forName: item.name) {
            if FileManager.default.fileExists(atPath: path) {
                return iconFromAppURL(URL(fileURLWithPath: path))
            }
        }

        // Fallback to stored icon data
        if let iconData = item.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

        return nil
    }

    // MARK: - Private Helpers

    /// Load an app's icon the same way the system surfaces it everywhere else.
    ///
    /// `NSWorkspace.icon(forFile:)` returns the icon IconServices renders for the Dock, Finder and
    /// Mission Control — which on macOS Tahoe includes the system-generated dark / clear / tinted
    /// treatment even for apps that ship only a single light `.icns` and no `Assets.car` (e.g. VS
    /// Code, most Electron apps). A previous version bypassed this for non-Assets.car apps and read
    /// the raw `.icns` directly to "avoid unwanted dark tinting" — but that suppressed the *correct*
    /// system treatment, so those apps were stuck showing their light icon while the Dock showed
    /// them dark. We now always go through `NSWorkspace`; the popover/list re-render on icon-style
    /// changes via their `.id(...)` composites, so the variant tracks live.
    ///
    /// NOTE: this only ever loads *third-party* app icons (the apps a user adds to a tile). It is
    /// never used for DockTile's own helper tile faces — those are generated with their own dark
    /// variant by `IconGenerator` / `IconStyleManager` — so there's no risk of double-treatment.
    private static func iconFromAppURL(_ appURL: URL) -> NSImage {
        let workspaceIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        if !workspaceIcon.representations.isEmpty {
            return workspaceIcon
        }
        // Defensive fallback: if NSWorkspace somehow returns an empty image, read the bundle's
        // declared `.icns` directly rather than handing back a blank icon.
        return loadIconDirectlyFromBundle(atPath: appURL.path) ?? workspaceIcon
    }

    /// Load icon directly from app bundle's .icns file (defensive fallback only)
    private static func loadIconDirectlyFromBundle(atPath path: String) -> NSImage? {
        let infoPlistURL = URL(fileURLWithPath: path)
            .appendingPathComponent("Contents/Info.plist")
        guard let infoPlist = NSDictionary(contentsOf: infoPlistURL) else {
            return nil
        }

        guard var iconName = infoPlist["CFBundleIconFile"] as? String
                ?? infoPlist["CFBundleIconName"] as? String else {
            return nil
        }

        if !iconName.hasSuffix(".icns") {
            iconName += ".icns"
        }

        let iconURL = URL(fileURLWithPath: path)
            .appendingPathComponent("Contents/Resources/\(iconName)")
        return NSImage(contentsOf: iconURL)
    }
}

// MARK: - App Install Checker

/// Whether the app/folder an `AppItem` points to is still present on this Mac.
enum AppInstallStatus: Equatable {
    /// Resolved on disk (live bundle, last-known path, or a common search path).
    case installed
    /// Confirmed gone — flag it in the UI and offer to remove it. NOT shown with the stale icon.
    case missing
    /// Can't be sure (pre-v8 config with a cached icon but no path, and the bundle ID didn't
    /// resolve right now). Rendered with the cached icon; never auto-flagged, to avoid false
    /// positives on legacy data or a transiently-unregistered Launch Services entry.
    case unknown
}

/// Determines whether the app behind an `AppItem` is still installed.
///
/// Detection is deliberately cheap — Launch Services bundle-ID lookups plus `stat()` calls, no
/// icon rasterisation — so a full sweep across every tile costs a few milliseconds. The actual
/// decision is the pure `classifyInstallStatus(...)` seam below so it can be unit-tested without
/// touching CFPreferences / FileManager (mirrors `classifyForMigration`, `resolveDockVisibility`).
@MainActor
enum AppInstallChecker {

    /// Result of resolving an `AppItem` against the live filesystem.
    struct Resolution: Equatable {
        let status: AppInstallStatus
        /// The current on-disk path when `installed` — used to heal a stale `lastKnownPath`.
        let resolvedPath: String?
    }

    /// Resolve an item's install status against the live system.
    static func resolve(_ item: AppItem) -> Resolution {
        // Folders are validated purely by their stored path.
        if item.isFolder {
            if let path = item.folderPath, FileManager.default.fileExists(atPath: path) {
                return Resolution(status: .installed, resolvedPath: path)
            }
            return Resolution(status: .missing, resolvedPath: nil)
        }

        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier)

        // Highest-confidence on-disk path: last-known location, else a common install dir.
        let onDiskPath: String? = {
            if let path = item.lastKnownPath, FileManager.default.fileExists(atPath: path) {
                return path
            }
            return commonSearchPaths(forName: item.name).first { FileManager.default.fileExists(atPath: $0) }
        }()

        let status = classifyInstallStatus(
            bundleResolves: bundleURL != nil,
            hasLastKnownPath: item.lastKnownPath != nil,
            onDiskPathExists: onDiskPath != nil,
            hasCachedIcon: item.iconData != nil
        )

        return Resolution(status: status, resolvedPath: bundleURL?.path ?? onDiskPath)
    }

    /// Pure decision seam — given installation signals, classify the item. No I/O.
    /// - bundleResolves: Launch Services found an app for the bundle ID right now.
    /// - hasLastKnownPath: the item carries a stored `lastKnownPath` (i.e. it's a v8+ entry).
    /// - onDiskPathExists: an app bundle exists at the last-known path or a common search path.
    /// - hasCachedIcon: the item has serialized `iconData` to fall back on.
    nonisolated static func classifyInstallStatus(
        bundleResolves: Bool,
        hasLastKnownPath: Bool,
        onDiskPathExists: Bool,
        hasCachedIcon: Bool
    ) -> AppInstallStatus {
        // Either signal present → definitely installed.
        if bundleResolves || onDiskPathExists {
            return .installed
        }
        // Bundle ID doesn't resolve and nothing is on disk where we expect it.
        // We had a concrete path on record and it's now gone → confidently missing.
        if hasLastKnownPath {
            return .missing
        }
        // Pre-v8 entry with no path on record: if it still has a cached icon we can't be sure
        // it's gone (LS may just be momentarily stale), so stay `unknown` rather than flag it.
        // With no path AND no cached icon, there's nothing left to point at → missing.
        return hasCachedIcon ? .unknown : .missing
    }

    /// Common locations to probe for an app bundle by display name.
    nonisolated static func commonSearchPaths(forName name: String) -> [String] {
        [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
            "/Applications/Utilities/\(name).app",
            "\(NSHomeDirectory())/Applications/\(name).app"
        ]
    }
}
