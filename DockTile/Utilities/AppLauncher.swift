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

    /// Launch an app or open a folder for the given AppItem
    static func launch(_ app: AppItem) {
        let workspace = NSWorkspace.shared

        if app.isFolder, let folderPath = app.folderPath {
            workspace.open(URL(fileURLWithPath: folderPath))
        } else if let appURL = workspace.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: config) { _, _ in }
        }
    }
}
