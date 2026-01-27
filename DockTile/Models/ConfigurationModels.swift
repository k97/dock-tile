//
//  ConfigurationModels.swift
//  DockTile
//
//  Core data models for dock tile configurations
//  Swift 6 - Strict Concurrency
//

import Foundation
import SwiftUI

// MARK: - DockTile Configuration

struct DockTileConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var tintColor: TintColor
    var symbolEmoji: String
    var layoutMode: LayoutMode
    var appItems: [AppItem]
    var isVisibleInDock: Bool
    var bundleIdentifier: String  // e.g., "com.docktile.dev"

    init(
        id: UUID = UUID(),
        name: String = "My DockTile",
        tintColor: TintColor = .none,
        symbolEmoji: String = "⭐",
        layoutMode: LayoutMode = .grid2x3,
        appItems: [AppItem] = [],
        isVisibleInDock: Bool = true,  // Default to visible
        bundleIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.tintColor = tintColor
        self.symbolEmoji = symbolEmoji
        self.layoutMode = layoutMode
        self.appItems = appItems
        self.isVisibleInDock = isVisibleInDock
        self.bundleIdentifier = bundleIdentifier ?? "com.docktile.\(id.uuidString)"
    }
}

// MARK: - Tint Color

enum TintColor: String, CaseIterable, Codable, Hashable {
    case none = "none"
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
        case .none: return "No Colour"
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

    /// Primary color for icon background gradient (top)
    var colorTop: Color {
        switch self {
        case .none: return Color(hex: "#F5F5F7")
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

    /// Secondary color for icon background gradient (bottom)
    var colorBottom: Color {
        switch self {
        case .none: return Color(hex: "#E5E5E7")
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

    /// SwiftUI Color for UI elements (picker, etc.)
    var color: Color {
        return colorBottom
    }
}

// MARK: - Layout Mode

enum LayoutMode: String, Codable, Hashable {
    case grid2x3 = "grid2x3"
    case horizontal1x6 = "horizontal1x6"

    var displayName: String {
        switch self {
        case .grid2x3: return "Grid (2×3)"
        case .horizontal1x6: return "Horizontal (1×6)"
        }
    }

    var iconName: String {
        switch self {
        case .grid2x3: return "square.grid.2x2"
        case .horizontal1x6: return "rectangle.grid.1x2"
        }
    }
}

// MARK: - App Item

struct AppItem: Identifiable, Codable, Hashable {
    let id: UUID
    var bundleIdentifier: String
    var name: String
    var iconData: Data?  // Serialized NSImage as PNG/TIFF data

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        name: String,
        iconData: Data? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.iconData = iconData
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
            iconData: iconData
        )
    }
}
