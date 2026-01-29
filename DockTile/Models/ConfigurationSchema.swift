//
//  ConfigurationSchema.swift
//  DockTile
//
//  Centralized default values for configuration properties
//  Swift 6 - Strict Concurrency
//

import Foundation

// MARK: - Configuration Defaults

/// Centralized default values for all configuration properties
/// When adding new fields, add their defaults here and use
/// `decodeIfPresent` in DockTileConfiguration's init(from:) decoder
enum ConfigurationDefaults {
    // Core properties
    static let name = "My DockTile"
    static let tintColor: TintColor = .none
    static let symbolEmoji = "⭐"
    static let layoutMode: LayoutMode = .grid2x3

    // Visibility
    static let isVisibleInDock = false  // User must explicitly enable
    static let showInAppSwitcher = false  // Hidden from Cmd+Tab by default
}
