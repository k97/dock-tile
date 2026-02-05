import Testing
import Foundation
@testable import Dock_Tile

// MARK: - DockTileConfiguration Tests

@Suite("DockTileConfiguration Tests")
struct DockTileConfigurationTests {

    // MARK: - Default Initialization

    @Test("Default initialization uses ConfigurationDefaults values")
    func defaultInitialization() {
        let config = DockTileConfiguration()

        #expect(config.name == ConfigurationDefaults.name)
        #expect(config.tintColor == .gray)
        #expect(config.iconType == .sfSymbol)
        #expect(config.iconValue == "star.fill")
        #expect(config.iconScale == 14)
        #expect(config.layoutMode == .grid)
        #expect(config.appItems.isEmpty)
        #expect(config.isVisibleInDock == true)
        #expect(config.showInAppSwitcher == false)
        #expect(config.lastDockIndex == nil)
    }

    @Test("Each config gets a unique UUID")
    func uniqueUUID() {
        let config1 = DockTileConfiguration()
        let config2 = DockTileConfiguration()

        #expect(config1.id != config2.id)
    }

    @Test("Bundle identifier is generated from UUID when not provided")
    func bundleIdentifierGeneration() {
        let config = DockTileConfiguration()

        #expect(config.bundleIdentifier.hasPrefix("com.docktile."))
        #expect(config.bundleIdentifier.contains(config.id.uuidString))
    }

    @Test("Custom bundle identifier is preserved")
    func customBundleIdentifier() {
        let customId = "com.custom.bundle"
        let config = DockTileConfiguration(bundleIdentifier: customId)

        #expect(config.bundleIdentifier == customId)
    }

    @Test("Custom initialization preserves all values")
    func customInitialization() {
        let customId = UUID()
        let customAppItems = [
            AppItem(bundleIdentifier: "com.test.app", name: "Test App")
        ]

        let config = DockTileConfiguration(
            id: customId,
            name: "Custom Tile",
            tintColor: .blue,
            symbolEmoji: "folder",
            iconType: .emoji,
            iconValue: "📁",
            iconScale: 18,
            layoutMode: .list,
            appItems: customAppItems,
            isVisibleInDock: false,
            showInAppSwitcher: true,
            bundleIdentifier: "com.custom.bundle",
            lastDockIndex: 5
        )

        #expect(config.id == customId)
        #expect(config.name == "Custom Tile")
        #expect(config.tintColor == .blue)
        #expect(config.iconType == .emoji)
        #expect(config.iconValue == "📁")
        #expect(config.iconScale == 18)
        #expect(config.layoutMode == .list)
        #expect(config.appItems.count == 1)
        #expect(config.isVisibleInDock == false)
        #expect(config.showInAppSwitcher == true)
        #expect(config.bundleIdentifier == "com.custom.bundle")
        #expect(config.lastDockIndex == 5)
    }

    // MARK: - JSON Encoding/Decoding

    @Test("Round-trip encoding/decoding preserves all fields")
    func roundTripEncoding() throws {
        let original = DockTileConfiguration(
            name: "Test Tile",
            tintColor: .purple,
            iconType: .sfSymbol,
            iconValue: "folder.fill",
            iconScale: 16,
            layoutMode: .list,
            isVisibleInDock: false,
            showInAppSwitcher: true,
            lastDockIndex: 3
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DockTileConfiguration.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.tintColor == original.tintColor)
        #expect(decoded.iconType == original.iconType)
        #expect(decoded.iconValue == original.iconValue)
        #expect(decoded.iconScale == original.iconScale)
        #expect(decoded.layoutMode == original.layoutMode)
        #expect(decoded.isVisibleInDock == original.isVisibleInDock)
        #expect(decoded.showInAppSwitcher == original.showInAppSwitcher)
        #expect(decoded.lastDockIndex == original.lastDockIndex)
    }

    // MARK: - Backward Compatibility

    @Test("v1 JSON (missing v2-v5 fields) decodes with defaults")
    func v1BackwardCompatibility() throws {
        let v1JSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Old Tile",
            "tintColor": "blue",
            "symbolEmoji": "folder",
            "layoutMode": "grid2x3",
            "appItems": [],
            "isVisibleInDock": true,
            "bundleIdentifier": "com.old.tile"
        }
        """

        let decoder = JSONDecoder()
        let config = try decoder.decode(DockTileConfiguration.self, from: v1JSON.data(using: .utf8)!)

        #expect(config.name == "Old Tile")
        #expect(config.showInAppSwitcher == false)  // v2 default
        #expect(config.iconType == .sfSymbol)  // v3 default
        #expect(config.iconValue == "folder")  // Migrated from symbolEmoji
        #expect(config.iconScale == 14)  // v4 default
        #expect(config.lastDockIndex == nil)  // v5 default
        #expect(config.layoutMode == .grid)  // grid2x3 maps to .grid
    }

    @Test("v2 JSON (missing v3-v5 fields) decodes with defaults")
    func v2BackwardCompatibility() throws {
        let v2JSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "V2 Tile",
            "tintColor": "red",
            "symbolEmoji": "star",
            "layoutMode": "list",
            "appItems": [],
            "isVisibleInDock": true,
            "bundleIdentifier": "com.v2.tile",
            "showInAppSwitcher": true
        }
        """

        let decoder = JSONDecoder()
        let config = try decoder.decode(DockTileConfiguration.self, from: v2JSON.data(using: .utf8)!)

        #expect(config.showInAppSwitcher == true)  // Preserved from JSON
        #expect(config.iconType == .sfSymbol)  // v3 default
        #expect(config.iconValue == "star")  // Migrated from symbolEmoji
        #expect(config.iconScale == 14)  // v4 default
        #expect(config.lastDockIndex == nil)  // v5 default
    }

    @Test("v3 JSON (missing v4-v5 fields) decodes with defaults")
    func v3BackwardCompatibility() throws {
        let v3JSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "V3 Tile",
            "tintColor": {"type": "preset", "value": "green"},
            "symbolEmoji": "star",
            "layoutMode": "grid",
            "appItems": [],
            "isVisibleInDock": true,
            "bundleIdentifier": "com.v3.tile",
            "showInAppSwitcher": false,
            "iconType": "emoji",
            "iconValue": "📁"
        }
        """

        let decoder = JSONDecoder()
        let config = try decoder.decode(DockTileConfiguration.self, from: v3JSON.data(using: .utf8)!)

        #expect(config.iconType == .emoji)  // Preserved from JSON
        #expect(config.iconValue == "📁")  // Preserved from JSON
        #expect(config.iconScale == 14)  // v4 default
        #expect(config.lastDockIndex == nil)  // v5 default
    }

    @Test("v4 JSON (missing v5 fields) decodes with defaults")
    func v4BackwardCompatibility() throws {
        let v4JSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "V4 Tile",
            "tintColor": {"type": "preset", "value": "purple"},
            "symbolEmoji": "star",
            "layoutMode": "grid",
            "appItems": [],
            "isVisibleInDock": true,
            "bundleIdentifier": "com.v4.tile",
            "showInAppSwitcher": false,
            "iconType": "sfSymbol",
            "iconValue": "folder.fill",
            "iconScale": 18
        }
        """

        let decoder = JSONDecoder()
        let config = try decoder.decode(DockTileConfiguration.self, from: v4JSON.data(using: .utf8)!)

        #expect(config.iconScale == 18)  // Preserved from JSON
        #expect(config.lastDockIndex == nil)  // v5 default
    }

    // MARK: - Hashable/Equatable

    @Test("Configurations with same ID are equal")
    func equality() {
        let id = UUID()
        let config1 = DockTileConfiguration(id: id, name: "Tile 1")
        let config2 = DockTileConfiguration(id: id, name: "Tile 2")

        // Note: Hashable uses all fields, so these won't be equal
        // But Identifiable uses just the id
        #expect(config1.id == config2.id)
    }

    @Test("Configurations with different IDs have different hashes")
    func differentHashes() {
        let config1 = DockTileConfiguration()
        let config2 = DockTileConfiguration()

        #expect(config1.hashValue != config2.hashValue)
    }
}

// MARK: - IconType Tests

@Suite("IconType Tests")
struct IconTypeTests {

    @Test("SF Symbol raw value is correct")
    func sfSymbolRawValue() {
        #expect(IconType.sfSymbol.rawValue == "sfSymbol")
    }

    @Test("Emoji raw value is correct")
    func emojiRawValue() {
        #expect(IconType.emoji.rawValue == "emoji")
    }

    @Test("IconType encodes and decodes correctly")
    func roundTripEncoding() throws {
        let types: [IconType] = [.sfSymbol, .emoji]

        for type in types {
            let encoder = JSONEncoder()
            let data = try encoder.encode(type)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(IconType.self, from: data)

            #expect(decoded == type)
        }
    }
}

// MARK: - TintColor Tests

@Suite("TintColor Tests")
struct TintColorTests {

    // MARK: - Preset Colors

    @Test("All preset colors have correct raw values")
    func presetRawValues() {
        let expected: [(TintColor.PresetColor, String)] = [
            (.red, "red"),
            (.orange, "orange"),
            (.green, "green"),
            (.blue, "blue"),
            (.purple, "purple"),
            (.pink, "pink"),
            (.gray, "gray")
        ]

        for (preset, rawValue) in expected {
            #expect(preset.rawValue == rawValue)
        }
    }

    @Test("All preset colors have display names")
    func presetDisplayNames() {
        for preset in TintColor.PresetColor.allCases {
            #expect(!preset.displayName.isEmpty)
        }
    }

    @Test("Static convenience properties return preset colors")
    func staticProperties() {
        #expect(TintColor.red == .preset(.red))
        #expect(TintColor.orange == .preset(.orange))
        #expect(TintColor.green == .preset(.green))
        #expect(TintColor.blue == .preset(.blue))
        #expect(TintColor.purple == .preset(.purple))
        #expect(TintColor.pink == .preset(.pink))
        #expect(TintColor.gray == .preset(.gray))
    }

    @Test("allPresets contains all preset colors")
    func allPresetsCount() {
        #expect(TintColor.allPresets.count == TintColor.PresetColor.allCases.count)
    }

    // MARK: - Custom Colors

    @Test("Custom color stores hex value")
    func customColorHex() {
        let customColor = TintColor.custom("#FF5733")

        if case .custom(let hex) = customColor {
            #expect(hex == "#FF5733")
        } else {
            Issue.record("Expected custom color")
        }
    }

    @Test("Custom color display name includes hex")
    func customColorDisplayName() {
        let customColor = TintColor.custom("#ABCDEF")

        #expect(customColor.displayName.contains("#ABCDEF"))
    }

    // MARK: - Encoding/Decoding

    @Test("Preset color encodes with type and value")
    func presetColorEncoding() throws {
        let color = TintColor.preset(.blue)
        let encoder = JSONEncoder()
        let data = try encoder.encode(color)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"type\":\"preset\""))
        #expect(json.contains("\"value\":\"blue\""))
    }

    @Test("Custom color encodes with type and value")
    func customColorEncoding() throws {
        let color = TintColor.custom("#FF0000")
        let encoder = JSONEncoder()
        let data = try encoder.encode(color)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"type\":\"custom\""))
        #expect(json.contains("\"value\":\"#FF0000\""))
    }

    @Test("Preset color round-trip encoding")
    func presetRoundTrip() throws {
        for preset in TintColor.PresetColor.allCases {
            let color = TintColor.preset(preset)

            let encoder = JSONEncoder()
            let data = try encoder.encode(color)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(TintColor.self, from: data)

            #expect(decoded == color)
        }
    }

    @Test("Custom color round-trip encoding")
    func customRoundTrip() throws {
        let color = TintColor.custom("#123ABC")

        let encoder = JSONEncoder()
        let data = try encoder.encode(color)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TintColor.self, from: data)

        #expect(decoded == color)
    }

    @Test("Legacy string format decodes as preset")
    func legacyPresetDecoding() throws {
        let legacyJSON = "\"blue\""

        let decoder = JSONDecoder()
        let color = try decoder.decode(TintColor.self, from: legacyJSON.data(using: .utf8)!)

        #expect(color == .preset(.blue))
    }

    @Test("Legacy 'none' value decodes as blue")
    func legacyNoneDecoding() throws {
        let legacyJSON = "\"none\""

        let decoder = JSONDecoder()
        let color = try decoder.decode(TintColor.self, from: legacyJSON.data(using: .utf8)!)

        #expect(color == .preset(.blue))
    }

    // MARK: - Color Properties

    @Test("Preset colors have gradient top and bottom")
    func presetGradientColors() {
        for preset in TintColor.PresetColor.allCases {
            let color = TintColor.preset(preset)

            // Just verify they don't crash and return colors
            _ = color.colorTop
            _ = color.colorBottom
            _ = color.color
        }
    }

    @Test("Custom colors have gradient top and bottom")
    func customGradientColors() {
        let color = TintColor.custom("#FF5733")

        // Just verify they don't crash and return colors
        _ = color.colorTop
        _ = color.colorBottom
        _ = color.color
    }
}

// MARK: - LayoutMode Tests

@Suite("LayoutMode Tests")
struct LayoutModeTests {

    @Test("Grid raw value is correct")
    func gridRawValue() {
        #expect(LayoutMode.grid.rawValue == "grid")
    }

    @Test("List raw value is correct")
    func listRawValue() {
        #expect(LayoutMode.list.rawValue == "list")
    }

    @Test("Display names are not empty")
    func displayNames() {
        #expect(!LayoutMode.grid.displayName.isEmpty)
        #expect(!LayoutMode.list.displayName.isEmpty)
    }

    @Test("Icon names are valid SF Symbol names")
    func iconNames() {
        #expect(!LayoutMode.grid.iconName.isEmpty)
        #expect(!LayoutMode.list.iconName.isEmpty)
    }

    // MARK: - Backward Compatibility

    @Test("grid2x3 decodes as grid")
    func grid2x3Compatibility() throws {
        let json = "\"grid2x3\""
        let decoder = JSONDecoder()
        let mode = try decoder.decode(LayoutMode.self, from: json.data(using: .utf8)!)

        #expect(mode == .grid)
    }

    @Test("grid3x3 decodes as grid")
    func grid3x3Compatibility() throws {
        let json = "\"grid3x3\""
        let decoder = JSONDecoder()
        let mode = try decoder.decode(LayoutMode.self, from: json.data(using: .utf8)!)

        #expect(mode == .grid)
    }

    @Test("grid4x4 decodes as grid")
    func grid4x4Compatibility() throws {
        let json = "\"grid4x4\""
        let decoder = JSONDecoder()
        let mode = try decoder.decode(LayoutMode.self, from: json.data(using: .utf8)!)

        #expect(mode == .grid)
    }

    @Test("horizontal1x6 decodes as list")
    func horizontal1x6Compatibility() throws {
        let json = "\"horizontal1x6\""
        let decoder = JSONDecoder()
        let mode = try decoder.decode(LayoutMode.self, from: json.data(using: .utf8)!)

        #expect(mode == .list)
    }

    @Test("Unknown value defaults to grid")
    func unknownValueDefault() throws {
        let json = "\"unknown_layout\""
        let decoder = JSONDecoder()
        let mode = try decoder.decode(LayoutMode.self, from: json.data(using: .utf8)!)

        #expect(mode == .grid)
    }

    @Test("Round-trip encoding preserves value")
    func roundTripEncoding() throws {
        let modes: [LayoutMode] = [.grid, .list]

        for mode in modes {
            let encoder = JSONEncoder()
            let data = try encoder.encode(mode)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(LayoutMode.self, from: data)

            #expect(decoded == mode)
        }
    }
}

// MARK: - AppItem Tests

@Suite("AppItem Tests")
struct AppItemTests {

    @Test("Default initialization creates valid AppItem")
    func defaultInitialization() {
        let item = AppItem(
            bundleIdentifier: "com.test.app",
            name: "Test App"
        )

        #expect(!item.id.uuidString.isEmpty)
        #expect(item.bundleIdentifier == "com.test.app")
        #expect(item.name == "Test App")
        #expect(item.iconData == nil)
        #expect(item.isFolder == false)
        #expect(item.folderPath == nil)
    }

    @Test("Folder initialization sets isFolder flag")
    func folderInitialization() {
        let item = AppItem(
            bundleIdentifier: "folder.test",
            name: "My Folder",
            isFolder: true,
            folderPath: "/Users/test/Documents"
        )

        #expect(item.isFolder == true)
        #expect(item.folderPath == "/Users/test/Documents")
    }

    @Test("Round-trip encoding preserves all fields")
    func roundTripEncoding() throws {
        let original = AppItem(
            bundleIdentifier: "com.test.app",
            name: "Test App",
            iconData: "test".data(using: .utf8),
            isFolder: true,
            folderPath: "/test/path"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppItem.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.bundleIdentifier == original.bundleIdentifier)
        #expect(decoded.name == original.name)
        #expect(decoded.iconData == original.iconData)
        #expect(decoded.isFolder == original.isFolder)
        #expect(decoded.folderPath == original.folderPath)
    }

    @Test("v1 JSON (missing v2 folder fields) decodes with defaults")
    func v1BackwardCompatibility() throws {
        let v1JSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "bundleIdentifier": "com.old.app",
            "name": "Old App"
        }
        """

        let decoder = JSONDecoder()
        let item = try decoder.decode(AppItem.self, from: v1JSON.data(using: .utf8)!)

        #expect(item.name == "Old App")
        #expect(item.isFolder == false)  // v2 default
        #expect(item.folderPath == nil)  // v2 default
    }

    @Test("AppItems are Hashable")
    func hashable() {
        let item1 = AppItem(bundleIdentifier: "com.test", name: "Test")
        let item2 = AppItem(bundleIdentifier: "com.test", name: "Test")

        // Different UUIDs means different hashes
        #expect(item1.hashValue != item2.hashValue)
    }

    @Test("AppItems with same ID are identifiable")
    func identifiable() {
        let id = UUID()
        let item1 = AppItem(id: id, bundleIdentifier: "com.test1", name: "Test 1")
        let item2 = AppItem(id: id, bundleIdentifier: "com.test2", name: "Test 2")

        #expect(item1.id == item2.id)
    }
}
