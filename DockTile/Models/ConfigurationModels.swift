//
//  ConfigurationModels.swift
//  DockTile
//
//  Core data models for dock tile configurations
//  Uses decodeIfPresent for backward compatibility when adding new fields
//  Swift 6 - Strict Concurrency
//

import Foundation
import SwiftUI
import AppKit

// MARK: - DockTile Configuration

struct DockTileConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var tintColor: TintColor
    var symbolEmoji: String  // Legacy: kept for backward compatibility
    var iconType: IconType  // v3: Distinguishes between SF Symbol and Emoji
    var iconValue: String  // v3: The actual symbol name or emoji character
    var iconScale: Int  // v4: Icon size scale (10-20 range, affects symbol/emoji size)
    var iconWeight: IconWeight  // v7: SF Symbol stroke weight (ignored for emojis)
    var background: TileBackground  // v9: Colour fill or Mono (white/near-black)
    var iconFace: IconFace  // v10: glyph (symbol/emoji) or the Apps grid
    var appsBackground: AppsGridBackground  // v12: App Grid plate (Follow System, Dark Grey, Light, Custom)
    var appsBackgroundColor: String  // v12: the Custom plate's sRGB hex; kept while another plate is picked
    var savedSymbol: SavedGlyph?  // v11: last symbol + size, restored when the Symbol style is picked again
    var savedEmoji: SavedGlyph?  // v11: last emoji + size, restored when the Emoji style is picked again
    var layoutMode: LayoutMode
    var appItems: [AppItem]
    var isVisibleInDock: Bool
    var showInAppSwitcher: Bool  // v2: Show in Cmd+Tab app switcher
    var bundleIdentifier: String  // e.g., "com.docktile.dev"
    var lastDockIndex: Int?  // v5: Saved Dock position for show/hide restoration
    var helperAppVersion: String?  // v6: App version when helper was last built/updated

    // MARK: - Diagnostic identity

    /// First 8 characters of the tile's UUID — the same prefix the bundle identifier carries and
    /// the suffix a same-named helper folder gets (`<name>-<shortId>.app`).
    var shortId: String { String(id.uuidString.prefix(8)) }

    /// How a tile is named in diagnostics: `'Utils' (B4EF96A2)`. Two tiles may share a name, so
    /// the name alone can't identify one in a report; the short id ties the line to the Dock
    /// entry, the helper folder and the `[helper:…]` process tag.
    var diagnosticName: String { "'\(name)' (\(shortId))" }

    /// Fingerprint of everything that shapes the tile's Dock icon, stamped into the helper's
    /// Info.plist when it is built (`HelperBundleManager.iconSignatureKey`), so the app can tell
    /// whether the helper on disk still shows this look (issue #22). A plain string, NOT a
    /// `Hasher` value: `Hasher` is seeded per process, and this is compared across launches.
    var iconSignature: String {
        let tint: String
        switch tintColor {
        case .preset(let preset): tint = preset.rawValue
        case .custom(let hex): tint = hex
        }
        let base = [tint, iconType.rawValue, iconValue, String(iconScale), iconWeight.rawValue, background.rawValue]
            .joined(separator: "|")
        guard iconFace == .apps else { return base }
        if appsBackground == .automatic { return base + "|apps|" + appsFaceIdentities.joined(separator: ",") }
        let plate = ["background-v2", appsBackground.rawValue,
                     appsBackground == .custom ? appsBackgroundColor : ""].joined(separator: "|")
        return base + "|apps|" + plate + "|" + appsFaceIdentities.joined(separator: ",")
    }

    /// Fingerprint of everything the tile's helper shows — its icon, name, popover layout, app list
    /// and Ghost/App mode — stamped into the helper's Info.plist when it is built
    /// (`HelperBundleManager.dockSignatureKey`). A helper reads its config once at launch, so until
    /// Update rebuilds and relaunches it, the Dock shows the tile as of this stamp; Tile Detail
    /// compares the two to decide whether Update has anything to apply. A plain string, like
    /// `iconSignature`, because it is compared across launches.
    var dockSignature: String {
        [iconSignature, name, layoutMode.rawValue, String(showInAppSwitcher),
         appItems.map(\.id.uuidString).joined(separator: ",")]
            .joined(separator: "\u{1F}")
    }

    /// Identities of the first `AppsFaceGrid.maxItems` items as the Apps face would draw them.
    var appsFaceIdentities: [String] {
        appItems.prefix(AppsFaceGrid.maxItems).map { $0.isFolder ? ($0.folderPath ?? $0.name) : $0.bundleIdentifier }
    }

    // MARK: - Duplicate

    /// A copy that looks exactly like this tile. Only identity and Dock bookkeeping are new: a fresh
    /// `id` (and so a fresh bundle identifier — the copy must never share this tile's helper), the
    /// given name, not visible in the Dock until the user adds it, and no saved Dock position or
    /// helper version. Every content field is passed explicitly — a defaulted one would silently
    /// reset (issue #21). Guarded by `DockTileDuplicateTests`, which also fails when a new field is
    /// added without a non-default value in its sample.
    func duplicate(named name: String) -> DockTileConfiguration {
        DockTileConfiguration(
            name: name,
            tintColor: tintColor,
            symbolEmoji: symbolEmoji,
            iconType: iconType,
            iconValue: iconValue,
            iconScale: iconScale,
            iconWeight: iconWeight,
            background: background,
            iconFace: iconFace,
            appsBackground: appsBackground,
            appsBackgroundColor: appsBackgroundColor,
            savedSymbol: savedSymbol,
            savedEmoji: savedEmoji,
            layoutMode: layoutMode,
            appItems: appItems,
            isVisibleInDock: false,
            showInAppSwitcher: showInAppSwitcher
        )
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String = ConfigurationDefaults.name,
        tintColor: TintColor = ConfigurationDefaults.tintColor,
        symbolEmoji: String = ConfigurationDefaults.symbolEmoji,
        iconType: IconType = ConfigurationDefaults.iconType,
        iconValue: String = ConfigurationDefaults.iconValue,
        iconScale: Int = ConfigurationDefaults.iconScale,
        iconWeight: IconWeight = ConfigurationDefaults.iconWeight,
        background: TileBackground = ConfigurationDefaults.background,
        iconFace: IconFace = ConfigurationDefaults.iconFace,
        appsBackground: AppsGridBackground = ConfigurationDefaults.appsBackground,
        appsBackgroundColor: String = ConfigurationDefaults.appsBackgroundColor,
        savedSymbol: SavedGlyph? = nil,
        savedEmoji: SavedGlyph? = nil,
        layoutMode: LayoutMode = ConfigurationDefaults.layoutMode,
        appItems: [AppItem] = [],
        isVisibleInDock: Bool = ConfigurationDefaults.isVisibleInDock,
        showInAppSwitcher: Bool = ConfigurationDefaults.showInAppSwitcher,
        bundleIdentifier: String? = nil,
        lastDockIndex: Int? = nil,
        helperAppVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.tintColor = tintColor
        self.symbolEmoji = symbolEmoji
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconScale = iconScale
        self.iconWeight = iconWeight
        self.background = background
        self.iconFace = iconFace
        self.appsBackground = appsBackground
        self.appsBackgroundColor = appsBackgroundColor
        self.savedSymbol = savedSymbol
        self.savedEmoji = savedEmoji
        self.layoutMode = layoutMode
        self.appItems = appItems
        self.isVisibleInDock = isVisibleInDock
        self.showInAppSwitcher = showInAppSwitcher
        // Use environment-specific prefix for bundle IDs
        // Dev: com.docktile.dev.<UUID>  |  Release: com.docktile.<UUID>
        self.bundleIdentifier = bundleIdentifier ?? "\(AppEnvironment.helperBundlePrefix).\(id.uuidString)"
        self.lastDockIndex = lastDockIndex
        self.helperAppVersion = helperAppVersion
    }

    // MARK: - Custom Decoder (backward compatibility)

    /// Decodes configuration with defaults for missing fields
    /// See ConfigurationSchema.swift for version history
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Core fields (v1) - required
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tintColor = try container.decode(TintColor.self, forKey: .tintColor)
        symbolEmoji = try container.decode(String.self, forKey: .symbolEmoji)
        layoutMode = try container.decode(LayoutMode.self, forKey: .layoutMode)
        appItems = try container.decode([AppItem].self, forKey: .appItems)
        isVisibleInDock = try container.decode(Bool.self, forKey: .isVisibleInDock)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)

        // v2 fields - optional with defaults
        showInAppSwitcher = try container.decodeIfPresent(Bool.self, forKey: .showInAppSwitcher)
            ?? ConfigurationDefaults.showInAppSwitcher

        // v3 fields - icon type and value
        iconType = try container.decodeIfPresent(IconType.self, forKey: .iconType)
            ?? ConfigurationDefaults.iconType
        // If iconValue not present, migrate from symbolEmoji
        iconValue = try container.decodeIfPresent(String.self, forKey: .iconValue)
            ?? symbolEmoji

        // v4 fields - icon scale
        iconScale = try container.decodeIfPresent(Int.self, forKey: .iconScale)
            ?? ConfigurationDefaults.iconScale

        // v7 fields - icon weight (old configs default to .medium)
        iconWeight = try container.decodeIfPresent(IconWeight.self, forKey: .iconWeight)
            ?? ConfigurationDefaults.iconWeight

        // v9 fields - tile background (old configs are Colour tiles)
        background = try container.decodeIfPresent(TileBackground.self, forKey: .background)
            ?? ConfigurationDefaults.background

        // v10 fields - tile face. The missing-key fallback is the LITERAL .glyph, not
        // ConfigurationDefaults.iconFace (.apps, for NEW tiles): existing tiles must not change on upgrade.
        iconFace = try container.decodeIfPresent(IconFace.self, forKey: .iconFace) ?? .glyph

        // v11 fields - per-type glyph memory (old configs have none saved)
        savedSymbol = try container.decodeIfPresent(SavedGlyph.self, forKey: .savedSymbol)
        savedEmoji = try container.decodeIfPresent(SavedGlyph.self, forKey: .savedEmoji)

        // v12 fields - App Grid plate (old configs follow the system, as before)
        appsBackground = try container.decodeIfPresent(AppsGridBackground.self, forKey: .appsBackground)
            ?? ConfigurationDefaults.appsBackground
        appsBackgroundColor = try container.decodeIfPresent(String.self, forKey: .appsBackgroundColor)
            ?? ConfigurationDefaults.appsBackgroundColor

        // v5 fields - last Dock position
        lastDockIndex = try container.decodeIfPresent(Int.self, forKey: .lastDockIndex)

        // v6 fields - helper app version tracking
        helperAppVersion = try container.decodeIfPresent(String.self, forKey: .helperAppVersion)
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        // v1 fields
        case id, name, tintColor, symbolEmoji, layoutMode, appItems
        case isVisibleInDock, bundleIdentifier
        // v2 fields
        case showInAppSwitcher
        // v3 fields
        case iconType, iconValue
        // v4 fields
        case iconScale
        // v7 fields
        case iconWeight
        // v9 fields
        case background
        // v10 fields
        case iconFace
        // v11 fields
        case savedSymbol, savedEmoji
        // v12 fields
        case appsBackground, appsBackgroundColor
        // v5 fields
        case lastDockIndex
        // v6 fields
        case helperAppVersion
    }
}

// MARK: - Tolerant Decoding

/// What `DockTileConfiguration.decodeTolerantly` read from a config file.
struct TolerantDecode {
    var tiles: [DockTileConfiguration]
    /// Elements that failed to decode and were left out.
    var skipped: Int
    /// The first decode error (an element's, or the whole file's).
    var firstError: Error?
    /// The file is not a JSON array at all (truncated, not JSON, another shape): no tiles.
    var wholeFileUnreadable: Bool
}

extension DockTileConfiguration {
    /// Decode a config file one tile at a time, so one tile this build cannot read (a value from a
    /// newer build, a hand edit) is skipped instead of failing the whole array. The whole-array
    /// decode it replaced turned one bad tile into an empty list, and the next save then wrote that
    /// list over every tile. Every reader of the config file goes through this (`ConfigDecodeToleranceTests`).
    nonisolated static func decodeTolerantly(_ data: Data, using decoder: JSONDecoder) -> TolerantDecode {
        let elements: [FailableTile]
        do {
            elements = try decoder.decode([FailableTile].self, from: data)
        } catch {
            return TolerantDecode(tiles: [], skipped: 0, firstError: error, wholeFileUnreadable: true)
        }
        var tiles: [DockTileConfiguration] = []
        var firstError: Error?
        for element in elements {
            switch element.result {
            case .success(let tile): tiles.append(tile)
            case .failure(let error): if firstError == nil { firstError = error }
            }
        }
        return TolerantDecode(tiles: tiles, skipped: elements.count - tiles.count,
                              firstError: firstError, wholeFileUnreadable: false)
    }

    /// One array element that keeps its own decode error rather than throwing it to the array.
    private struct FailableTile: Decodable {
        let result: Result<DockTileConfiguration, Error>
        init(from decoder: Decoder) throws {
            result = Result { try DockTileConfiguration(from: decoder) }
        }
    }
}

// MARK: - Saved Glyph

/// A symbol or emoji the tile showed before its Style switched away, with the icon size it had.
/// Restored when that Style card is picked again, so switching never loses a choice (v11).
struct SavedGlyph: Codable, Hashable {
    var value: String
    var scale: Int
    /// Colour / Mono and the tile colour are local to the Symbol and Emoji styles too. Optional: a
    /// glyph saved before these fields existed decodes with nil, and restoring it keeps the tile's
    /// current value. (Icon weight needs no copy: only Symbol shows or uses it.)
    var background: TileBackground? = nil
    var tint: TintColor? = nil
}

// MARK: - Icon Type

/// Distinguishes between SF Symbols and Emojis for icon display
enum IconType: String, Codable, Hashable {
    case sfSymbol = "sfSymbol"
    case emoji = "emoji"
}

// MARK: - Icon Weight

/// Curated SF Symbol stroke weights selectable per tile (v7).
///
/// Applies to SF Symbols only — emojis are colour glyphs and ignore weight, so the
/// renderers (`IconGenerator`, `DockTileIconPreview`) never apply it to emoji content.
/// The curated set drops the extremes (ultralight/thin/black) that read poorly at
/// tile size.
enum IconWeight: String, Codable, CaseIterable, Hashable {
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy

    var displayName: String {
        switch self {
        case .light: return AppStrings.IconWeight.light
        case .regular: return AppStrings.IconWeight.regular
        case .medium: return AppStrings.IconWeight.medium
        case .semibold: return AppStrings.IconWeight.semibold
        case .bold: return AppStrings.IconWeight.bold
        case .heavy: return AppStrings.IconWeight.heavy
        }
    }

    /// SwiftUI font weight — used by the live preview and the symbol picker grid.
    var fontWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }

    /// AppKit font weight — used by the baked `.icns` via `NSImage.SymbolConfiguration`.
    var nsFontWeight: NSFont.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }

    /// `Codable`'s default `RawRepresentable` decoding THROWS on an unrecognised raw value —
    /// and `decodeIfPresent` at the call site does not protect against that, because the key IS
    /// present, it's just the value that's unrecognised. Without this override, a config written
    /// by a newer app version (or a hand-edited file) with a future weight case would fail to
    /// decode the ENTIRE `DockTileConfiguration`, not just this field. Fall back to the same
    /// `.medium` default the missing-key case already uses.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IconWeight(rawValue: raw) ?? .medium
    }
}

// MARK: - Tile Background

/// Where a tile's one colour goes (v9). `.colour` fills the tile (white symbol); `.mono` is white
/// in Light Mode and near-black in Dark Mode with the colour on the symbol. The concrete tones come
/// from `TilePalette` — never stored, so tuning the tone map re-renders every tile consistently.
enum TileBackground: String, Codable, CaseIterable, Hashable {
    case colour
    case mono

    /// Tolerant decode, same reason as `IconWeight`: a key that is present with an unknown value
    /// would otherwise fail the ENTIRE configuration decode. Fall back to the default.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TileBackground(rawValue: raw) ?? .colour
    }
}

// MARK: - Icon Face

/// What a tile's Dock icon shows (v10): its glyph (SF Symbol / emoji) or the Apps grid. A separate
/// field rather than an `IconType` case because `IconType` decodes strictly; this one decodes
/// tolerantly like `TileBackground`, so an unknown value never fails the whole configuration.
enum IconFace: String, Codable, CaseIterable, Hashable {
    case glyph
    case apps

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IconFace(rawValue: raw) ?? .glyph
    }
}

// MARK: - Tint Color

/// Represents a tile's background color - either a preset or custom hex color
enum TintColor: Hashable, Codable {
    case preset(PresetColor)
    case custom(String)  // Hex string like "#FF5733"

    // MARK: - Preset Colors

    enum PresetColor: String, CaseIterable, Codable, Hashable {
        case red = "red"
        case orange = "orange"
        case green = "green"
        case blue = "blue"
        case purple = "purple"
        case pink = "pink"
        case gray = "gray"

        var displayName: String {
            switch self {
            case .red: return "Red"
            case .orange: return "Orange"
            case .green: return "Green"
            case .blue: return "Blue"
            case .purple: return "Purple"
            case .pink: return "Pink"
            case .gray: return "Gray"
            }
        }

        /// Lighter stop (the gradient top before tone-mapping; still the Colour+Dark+emoji source).
        var lightHex: String {
            switch self {
            case .red: return "#FF6B6B"
            case .orange: return "#FFA94D"
            case .green: return "#6BCF7F"
            case .blue: return "#4DABF7"
            case .purple: return "#B197FC"
            case .pink: return "#FF6B9D"
            case .gray: return "#ADB5BD"
            }
        }

        /// The saturated base every tone is derived from (`TilePalette`).
        var baseHex: String {
            switch self {
            case .red: return "#FF3B30"
            case .orange: return "#FF9500"
            case .green: return "#34C759"
            case .blue: return "#007AFF"
            case .purple: return "#AF52DE"
            case .pink: return "#FF2D55"
            case .gray: return "#8E8E93"
            }
        }

        /// Primary color for icon background gradient (top) - lighter shade
        var colorTop: Color { Color(hex: lightHex) }

        /// Secondary color for icon background gradient (bottom) - darker/saturated shade
        var colorBottom: Color { Color(hex: baseHex) }

        /// Primary SwiftUI Color (uses bottom/saturated color)
        var color: Color {
            return colorBottom
        }
    }

    // MARK: - Color Properties

    /// Primary color for icon background gradient (top)
    var colorTop: Color {
        switch self {
        case .preset(let preset):
            return preset.colorTop
        case .custom(let hex):
            // For custom colors, create a lighter shade for the top gradient
            // Using a lighter shade (not opacity) ensures the gradient fills completely
            let baseColor = Color(hex: hex)
            return baseColor.lighterShade(by: 0.15)
        }
    }

    /// Secondary color for icon background gradient (bottom)
    var colorBottom: Color {
        switch self {
        case .preset(let preset):
            return preset.colorBottom
        case .custom(let hex):
            return Color(hex: hex)
        }
    }

    /// SwiftUI Color for UI elements
    var color: Color {
        return colorBottom
    }

    var displayName: String {
        switch self {
        case .preset(let preset):
            return preset.displayName
        case .custom(let hex):
            return "Custom (\(hex))"
        }
    }

    // MARK: - Convenience Static Properties (backward compatibility)

    static let red = TintColor.preset(.red)
    static let orange = TintColor.preset(.orange)
    static let green = TintColor.preset(.green)
    static let blue = TintColor.preset(.blue)
    static let purple = TintColor.preset(.purple)
    static let pink = TintColor.preset(.pink)
    static let gray = TintColor.preset(.gray)

    /// All preset colors for iteration
    static var allPresets: [TintColor] {
        PresetColor.allCases.map { .preset($0) }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        // First try decoding as the new format
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let type = try container.decode(String.self, forKey: .type)
            let value = try container.decode(String.self, forKey: .value)

            if type == "preset", let preset = PresetColor(rawValue: value) {
                self = .preset(preset)
                return
            } else if type == "custom" {
                self = .custom(value)
                return
            }
        }

        // Fall back to legacy string format for backward compatibility
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Handle legacy "none" value - default to blue
        if rawValue == "none" {
            self = .preset(.blue)
            return
        }

        if let preset = PresetColor(rawValue: rawValue) {
            self = .preset(preset)
        } else {
            // Assume it's a custom hex color
            self = .custom(rawValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .preset(let preset):
            try container.encode("preset", forKey: .type)
            try container.encode(preset.rawValue, forKey: .value)
        case .custom(let hex):
            try container.encode("custom", forKey: .type)
            try container.encode(hex, forKey: .value)
        }
    }
}

// MARK: - Layout Mode

enum LayoutMode: String, Hashable {
    case grid = "grid"      // Dynamic grid (auto-adjusts columns based on app count)
    case list = "list"      // Vertical list view

    var displayName: String {
        switch self {
        case .grid: return AppStrings.Layout.grid
        case .list: return AppStrings.Layout.list
        }
    }

    var iconName: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - LayoutMode Codable (Backward Compatibility)

extension LayoutMode: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Map old values to new simplified enum
        switch rawValue {
        case "grid", "grid2x3", "grid3x3", "grid4x4":
            self = .grid
        case "list", "horizontal1x6":
            self = .list
        default:
            self = .grid  // Default to grid for unknown values
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - App Item

struct AppItem: Identifiable, Codable, Hashable {
    let id: UUID
    var bundleIdentifier: String
    var name: String
    var isFolder: Bool  // v2: Distinguishes folders from applications
    var folderPath: String?  // v2: Path to folder (only set when isFolder is true)
    /// v8: Last on-disk path the app was resolved at. A second installation signal alongside
    /// `bundleIdentifier` — lets the install checker (a) distinguish a genuinely-uninstalled app
    /// from a transiently-unregistered Launch Services entry and (b) self-heal an app that merely
    /// moved/updated by re-resolving instead of flagging it missing. Stamped on add and refreshed
    /// by `ConfigurationManager.scanForMissingApps()`. `nil` = pre-v8 config (treated as unknown).
    var lastKnownPath: String?

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        name: String,
        isFolder: Bool = false,
        folderPath: String? = nil,
        lastKnownPath: String? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isFolder = isFolder
        self.folderPath = folderPath
        self.lastKnownPath = lastKnownPath
    }

    // MARK: - Custom Decoder (backward compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        name = try container.decode(String.self, forKey: .name)

        // v2 fields - optional with defaults
        isFolder = try container.decodeIfPresent(Bool.self, forKey: .isFolder) ?? false
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath)

        // v8 field - optional, nil for pre-v8 configs
        lastKnownPath = try container.decodeIfPresent(String.self, forKey: .lastKnownPath)
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleIdentifier, name
        case isFolder, folderPath
        case lastKnownPath
    }

    /// Create AppItem from .app bundle URL
    static func from(appURL: URL) -> AppItem? {
        guard let bundle = Bundle(url: appURL) else { return nil }

        let bundleId = bundle.bundleIdentifier ?? appURL.lastPathComponent
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                      ?? appURL.deletingPathExtension().lastPathComponent

        return AppItem(
            bundleIdentifier: bundleId,
            name: appName,
            isFolder: false,
            folderPath: nil,
            lastKnownPath: appURL.path  // stamp the resolved path so missing-app detection has two signals
        )
    }

    /// Create AppItem from folder URL
    static func from(folderURL: URL) -> AppItem? {
        let folderName = folderURL.lastPathComponent
        let folderPath = folderURL.path

        return AppItem(
            bundleIdentifier: "folder.\(folderPath.hashValue)",  // Unique identifier for folder
            name: folderName,
            isFolder: true,
            folderPath: folderPath
        )
    }

    // MARK: - Identity Helpers

    /// True when this (application) item refers to the same on-disk app as `path` / `bundleId`.
    ///
    /// Identity is the on-disk **path** — unique per `.app` bundle — because browser PWAs
    /// (Chrome/Edge) reuse a single `CFBundleIdentifier` across separate installs: the id derives
    /// from the site URL, so the same site added under different browser profiles (multi-account
    /// inboxes) yields distinct bundles that share one id. Bundle id is only a fallback for legacy
    /// pre-v8 items that never stamped a `lastKnownPath`.
    func matchesApp(path: String, bundleId: String?) -> Bool {
        guard !isFolder else { return false }
        if let known = lastKnownPath { return known == path }
        guard let bundleId else { return false }
        return bundleIdentifier == bundleId
    }

    /// Resolve the on-disk `.app` URL to act on for this item. Prefers the exact bundle at
    /// `lastKnownPath` (so PWAs that share a bundle id resolve to their OWN install and launch
    /// their OWN window), falling back to Launch Services bundle-id resolution when the path is
    /// stale/missing — which self-heals a moved or updated app. Pure decision: callers supply the
    /// probed facts so the rule stays unit-testable.
    nonisolated static func resolvedAppURL(
        lastKnownPath: String?,
        pathExists: Bool,
        bundleResolvedURL: @autoclosure () -> URL?
    ) -> URL? {
        if let path = lastKnownPath, pathExists {
            return URL(fileURLWithPath: path)
        }
        return bundleResolvedURL()
    }
}

// MARK: - App list editing (pure seam behind the Tile Detail preview editor)

/// Plain-value reducer for the editable popover preview. Mirrors the semantics of the old table's
/// `PopoverItemDropDelegate.dropEntered` (drag forward → after target, backward → before target).
enum AppListEditor {
    nonisolated static func removing(_ id: UUID, from items: [AppItem]) -> [AppItem] {
        items.filter { $0.id != id }
    }

    nonisolated static func moving(_ draggedID: UUID, onto targetID: UUID, in items: [AppItem]) -> [AppItem] {
        guard draggedID != targetID,
              let from = items.firstIndex(where: { $0.id == draggedID }),
              let to = items.firstIndex(where: { $0.id == targetID }) else { return items }
        var out = items
        out.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        return out
    }
}

/// App-grid plate settings are independent of the Symbol/Emoji face's tint and background.
enum AppsGridBackground: String, Codable, CaseIterable, Sendable {
    case automatic, charcoal, light, custom

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .automatic
    }

    var label: String {
        switch self {
        case .automatic: AppStrings.Label.appsBackgroundAutomatic
        case .charcoal: AppStrings.Label.appsBackgroundCharcoal
        case .light: AppStrings.Label.appsBackgroundLight
        case .custom: AppStrings.Label.appsBackgroundCustom
        }
    }
}
