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
    /// - Asset Catalog-aware: apps without Assets.car load .icns directly
    ///   to avoid macOS applying unwanted dark tinting.
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

        // Try common paths for apps
        let searchPaths = [
            "/Applications/\(item.name).app",
            "/System/Applications/\(item.name).app",
            "/Applications/Utilities/\(item.name).app",
            "\(NSHomeDirectory())/Applications/\(item.name).app"
        ]

        for path in searchPaths {
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

    /// Load icon from an app URL, using Asset Catalog detection
    private static func iconFromAppURL(_ appURL: URL) -> NSImage {
        // Apps WITHOUT Assets.car don't support icon variants, so load directly from .icns
        // to avoid macOS applying unwanted dark tinting
        if !appHasAssetCatalog(atPath: appURL.path) {
            if let icon = loadIconDirectlyFromBundle(atPath: appURL.path) {
                return icon
            }
        }
        // App has Asset Catalog - use NSWorkspace which respects icon style
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    /// Check if app bundle has an Asset Catalog (Assets.car)
    private static func appHasAssetCatalog(atPath path: String) -> Bool {
        let assetCatalogPath = path + "/Contents/Resources/Assets.car"
        return FileManager.default.fileExists(atPath: assetCatalogPath)
    }

    /// Load icon directly from app bundle's .icns file
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
