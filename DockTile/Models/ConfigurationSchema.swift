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
    static let layoutMode: LayoutMode = .grid

    // v3: Icon type and value
    static let iconType: IconType = .sfSymbol
    // The decode / style-restore fallback glyph. A NEW blank tile no longer starts on it: it draws a
    // random starter symbol and emoji instead (`starterGlyphs`, owner 2026-10-22).
    static let iconValue = "plus"

    /// The pools a new blank tile draws its symbol and emoji from, so every new tile starts
    /// different. Symbols must exist on the macOS 15 floor (`StarterGlyphTests` resolves each one).
    static let starterSymbols = [
        "star.fill", "heart.fill", "bolt.fill", "leaf.fill", "flame.fill", "moon.fill",
        "sun.max.fill", "cloud.fill", "sparkles", "paperplane.fill", "music.note",
        "gamecontroller.fill", "book.fill", "camera.fill", "cup.and.saucer.fill", "briefcase.fill"
    ]
    static let starterEmoji = [
        "🚀", "🎯", "🌈", "🍀", "🔥", "🎨", "📚", "🎧", "☕️", "🌙", "⚡️", "🧩", "🎮", "🌿", "💡", "🪐"
    ]

    /// One symbol and one emoji at random from the pools. Pure — the generator is injected.
    static func starterGlyphs<G: RandomNumberGenerator>(using generator: inout G) -> (symbol: String, emoji: String) {
        (starterSymbols.randomElement(using: &generator) ?? iconValue,
         starterEmoji.randomElement(using: &generator) ?? symbolEmoji)
    }

    // v4: Icon scale (10-20 range, affects symbol/emoji size relative to icon bounds)
    static let iconScale = 14

    // v7: SF Symbol stroke weight (ignored for emojis)
    static let iconWeight: IconWeight = .medium

    // v9: Tile background — existing tiles stay Colour
    static let background: TileBackground = .colour

    // v10: Tile face — App Grid for NEW tiles; the decoder keeps an existing tile's glyph
    static let iconFace: IconFace = .apps

    // v11: savedSymbol / savedEmoji — nil (nothing saved) for new and pre-v11 tiles

    // v12: App Grid plate — follow the system unless a tile picks its own
    static let appsBackground: AppsGridBackground = .automatic
    static let appsBackgroundColor = "#404040"

    // v13: Show in Menu Bar — off unless the caller passes one; the decoder gives an existing tile
    // its own isVisibleInDock, so the menu bar menu lists what it did before
    static let showInMenuBar = false

    // Visibility
    static let isVisibleInDock = true  // Show in Dock by default
    static let showInAppSwitcher = false  // Hidden from Cmd+Tab by default
}
