//
//  AppStrings.swift
//  Dock Tile
//
//  Centralized app strings for easy maintenance and future localization.
//  All user-visible strings should be defined here.
//

import Foundation

/// Centralized app strings for easy maintenance and future localization.
/// Usage: `AppStrings.appName` or `AppStrings.Menu.newTile`
enum AppStrings {
    /// The display name of the app
    static let appName = NSLocalizedString(
        "app.name",
        value: "Dock Tile",
        comment: "App display name"
    )

    /// Menu-related strings
    enum Menu {
        static let newTile = NSLocalizedString(
            "menu.newTile",
            value: "New Dock Tile",
            comment: "Menu item to create a new tile"
        )
    }

    /// Sidebar-related strings
    enum Sidebar {
        static let title = NSLocalizedString(
            "sidebar.title",
            value: "Dock Tile",
            comment: "Navigation title for sidebar"
        )
    }

    /// Error messages
    enum Error {
        static let mainAppNotFound = NSLocalizedString(
            "error.mainAppNotFound",
            value: "Main Dock Tile.app not found",
            comment: "Error when main app bundle cannot be found"
        )
    }

    /// Log messages (not localized, but centralized)
    enum Log {
        static let launching = "🚀 Dock Tile launching..."
        static let ready = "✓ Dock Tile ready"
        static let terminating = "👋 Dock Tile terminating..."
    }
}
