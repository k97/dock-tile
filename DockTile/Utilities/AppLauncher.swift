//
//  AppLauncher.swift
//  DockTile
//
//  Shared utility for launching apps and opening folders from AppItem models.
//  Swift 6 - Strict Concurrency
//

import AppKit

@MainActor
enum AppLauncher {

    /// Launch an app or open a folder for the given AppItem. `source` attributes the launch in
    /// analytics: "popover" for a left-click / Return, "item_menu" for the context menu's Open,
    /// "context_menu" for an App-mode tile's Dock menu, "main_dock_menu" for the main app's Dock menu.
    static func launch(_ app: AppItem, source: String = "popover") {
        AnalyticsService.shared.log(.appLaunchedFromTile, ["source": source, "is_folder": app.isFolder])

        let workspace = NSWorkspace.shared

        if app.isFolder, let folderPath = app.folderPath {
            DiagnosticsLog.shared.log("launch", "Opening folder from tile: \(app.name)")
            workspace.open(URL(fileURLWithPath: folderPath))
        } else if let appURL = AppItem.resolvedAppURL(
            lastKnownPath: app.lastKnownPath,
            pathExists: app.lastKnownPath.map { FileManager.default.fileExists(atPath: $0) } ?? false,
            bundleResolvedURL: workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
        ) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, error in
                if let error {
                    DiagnosticsLog.shared.log("launch", "App launch FAILED from tile: \(app.name) (\(app.bundleIdentifier)): \(error.localizedDescription)")
                } else {
                    DiagnosticsLog.shared.log("launch", "Launched \(app.name) (\(app.bundleIdentifier)) from tile")
                }
            }
        } else {
            DiagnosticsLog.shared.log("launch", "App not found from tile: \(app.name) (\(app.bundleIdentifier))")
        }
    }
}
