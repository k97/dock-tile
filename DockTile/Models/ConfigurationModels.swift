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

// MARK: - DockTile Configuration

struct DockTileConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var tintColor: TintColor
    var symbolEmoji: String  // Legacy: kept for backward compatibility
    var iconType: IconType  // v3: Distinguishes between SF Symbol and Emoji
    var iconValue: String  // v3: The actual symbol name or emoji character
    var iconScale: Int  // v4: Icon size scale (10-20 range, affects symbol/emoji size)
    var layoutMode: LayoutMode
    var appItems: [AppItem]
    var isVisibleInDock: Bool
    var showInAppSwitcher: Bool  // v2: Show in Cmd+Tab app switcher
    var bundleIdentifier: String  // e.g., "com.docktile.dev"
    var lastDockIndex: Int?  // v5: Saved Dock position for show/hide restoration

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String = ConfigurationDefaults.name,
        tintColor: TintColor = ConfigurationDefaults.tintColor,
        symbolEmoji: String = ConfigurationDefaults.symbolEmoji,
        iconType: IconType = ConfigurationDefaults.iconType,
        iconValue: String = ConfigurationDefaults.iconValue,
        iconScale: Int = ConfigurationDefaults.iconScale,
        layoutMode: LayoutMode = ConfigurationDefaults.layoutMode,
        appItems: [AppItem] = [],
        isVisibleInDock: Bool = ConfigurationDefaults.isVisibleInDock,
        showInAppSwitcher: Bool = ConfigurationDefaults.showInAppSwitcher,
        bundleIdentifier: String? = nil,
        lastDockIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.tintColor = tintColor
        self.symbolEmoji = symbolEmoji
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconScale = iconScale
        self.layoutMode = layoutMode
        self.appItems = appItems
        self.isVisibleInDock = isVisibleInDock
        self.showInAppSwitcher = showInAppSwitcher
        self.bundleIdentifier = bundleIdentifier ?? "com.docktile.\(id.uuidString)"
        self.lastDockIndex = lastDockIndex
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

        // v5 fields - last Dock position
        lastDockIndex = try container.decodeIfPresent(Int.self, forKey: .lastDockIndex)
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
        // v5 fields
        case lastDockIndex
    }
}

// MARK: - Icon Type

/// Distinguishes between SF Symbols and Emojis for icon display
enum IconType: String, Codable, Hashable {
    case sfSymbol = "sfSymbol"
    case emoji = "emoji"
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
        case yellow = "yellow"
        case green = "green"
        case blue = "blue"
        case purple = "purple"
        case pink = "pink"
        case gray = "gray"

        var displayName: String {
            switch self {
            case .red: return "Red"
            case .orange: return "Orange"
            case .yellow: return "Yellow"
            case .green: return "Green"
            case .blue: return "Blue"
            case .purple: return "Purple"
            case .pink: return "Pink"
            case .gray: return "Gray"
            }
        }

        /// Primary color for icon background gradient (top) - lighter shade
        var colorTop: Color {
            switch self {
            case .red: return Color(hex: "#FF6B6B")
            case .orange: return Color(hex: "#FFA94D")
            case .yellow: return Color(hex: "#FFD93D")
            case .green: return Color(hex: "#6BCF7F")
            case .blue: return Color(hex: "#4DABF7")
            case .purple: return Color(hex: "#B197FC")
            case .pink: return Color(hex: "#FF6B9D")
            case .gray: return Color(hex: "#ADB5BD")
            }
        }

        /// Secondary color for icon background gradient (bottom) - darker/saturated shade
        var colorBottom: Color {
            switch self {
            case .red: return Color(hex: "#FF3B30")
            case .orange: return Color(hex: "#FF9500")
            case .yellow: return Color(hex: "#FFCC00")
            case .green: return Color(hex: "#34C759")
            case .blue: return Color(hex: "#007AFF")
            case .purple: return Color(hex: "#AF52DE")
            case .pink: return Color(hex: "#FF2D55")
            case .gray: return Color(hex: "#8E8E93")
            }
        }

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
    static let yellow = TintColor.preset(.yellow)
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
        case .grid: return "Grid"
        case .list: return "List"
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
    var iconData: Data?  // Serialized NSImage as PNG/TIFF data
    var isFolder: Bool  // v2: Distinguishes folders from applications
    var folderPath: String?  // v2: Path to folder (only set when isFolder is true)

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        name: String,
        iconData: Data? = nil,
        isFolder: Bool = false,
        folderPath: String? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.iconData = iconData
        self.isFolder = isFolder
        self.folderPath = folderPath
    }

    // MARK: - Custom Decoder (backward compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        name = try container.decode(String.self, forKey: .name)
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)

        // v2 fields - optional with defaults
        isFolder = try container.decodeIfPresent(Bool.self, forKey: .isFolder) ?? false
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath)
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleIdentifier, name, iconData
        case isFolder, folderPath
    }

    /// Create AppItem from .app bundle URL
    static func from(appURL: URL) -> AppItem? {
        guard let bundle = Bundle(url: appURL) else { return nil }

        let bundleId = bundle.bundleIdentifier ?? appURL.lastPathComponent
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                      ?? appURL.deletingPathExtension().lastPathComponent

        // Extract icon data
        var iconData: Data?
        if let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let iconPath = bundle.path(forResource: iconFile, ofType: nil)
                          ?? bundle.path(forResource: iconFile, ofType: "icns")
            if let path = iconPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                iconData = data
            }
        }

        return AppItem(
            bundleIdentifier: bundleId,
            name: appName,
            iconData: iconData,
            isFolder: false,
            folderPath: nil
        )
    }

    /// Create AppItem from folder URL
    static func from(folderURL: URL) -> AppItem? {
        let folderName = folderURL.lastPathComponent
        let folderPath = folderURL.path

        // Get folder icon from system
        let icon = NSWorkspace.shared.icon(forFile: folderPath)
        let iconData = icon.tiffRepresentation

        return AppItem(
            bundleIdentifier: "folder.\(folderPath.hashValue)",  // Unique identifier for folder
            name: folderName,
            iconData: iconData,
            isFolder: true,
            folderPath: folderPath
        )
    }
}
