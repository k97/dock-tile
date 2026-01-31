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
    static let name = "New Tile"
    static let tintColor: TintColor = .gray
    static let symbolEmoji = "⭐"  // Legacy field
    static let layoutMode: LayoutMode = .grid2x3

    // v3: Icon type and value
    static let iconType: IconType = .sfSymbol
    static let iconValue = "star.fill"

    // Visibility
    static let isVisibleInDock = true  // Show in Dock by default
    static let showInAppSwitcher = false  // Hidden from Cmd+Tab by default
}
