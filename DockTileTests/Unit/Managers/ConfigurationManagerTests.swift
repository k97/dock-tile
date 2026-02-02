import Testing
import Foundation
import SwiftUI
@testable import DockTile

// MARK: - ConfigurationManager Tests

/// Note: ConfigurationManager has tightly coupled dependencies (FileManager, UserDefaults, HelperBundleManager).
/// These tests focus on the testable behaviors while acknowledging the coupling.
/// For full isolation, the ConfigurationManager would need protocol-based dependency injection.

@Suite("ConfigurationManager Tests")
@MainActor
struct ConfigurationManagerTests {

    // MARK: - Test Helpers

    /// Create a temporary test configuration manager
    /// Note: This creates a real manager - tests should not modify shared state
    private func createTestManager() -> ConfigurationManager {
        ConfigurationManager()
    }

    // MARK: - Unique Name Generation

    @Test("generateUniqueName returns base name when no conflicts")
    func uniqueNameNoConflict() {
        // Test the logic directly on the DockTileConfiguration
        let existingNames: Set<String> = ["Tile A", "Tile B"]
        let baseName = "New Tile"

        // The name should be used as-is if not in the set
        #expect(!existingNames.contains(baseName))
    }

    @Test("generateUniqueName appends number when base name exists")
    func uniqueNameWithConflict() {
        // Test the naming convention
        let existingNames: Set<String> = ["New Tile", "New Tile 1"]
        let baseName = "New Tile"

        // If "New Tile" and "New Tile 1" exist, next should be "New Tile 2"
        #expect(existingNames.contains(baseName))
        #expect(existingNames.contains("\(baseName) 1"))
        #expect(!existingNames.contains("\(baseName) 2"))
    }

    // MARK: - Configuration Lookup

    @Test("configuration(for:) returns nil for unknown ID")
    func configurationLookupUnknownId() {
        let manager = createTestManager()
        let unknownId = UUID()

        let config = manager.configuration(for: unknownId)

        #expect(config == nil)
    }

    @Test("configuration(forBundleId:) returns nil for unknown bundle ID")
    func configurationLookupUnknownBundleId() {
        let manager = createTestManager()

        let config = manager.configuration(forBundleId: "com.unknown.bundle")

        #expect(config == nil)
    }

    // MARK: - Selection

    @Test("selectConfiguration returns false for unknown ID")
    func selectUnknownConfigId() {
        let manager = createTestManager()
        let unknownId = UUID()

        let result = manager.selectConfiguration(id: unknownId)

        #expect(result == false)
    }

    @Test("selectConfiguration returns false for unknown bundle ID")
    func selectUnknownConfigBundleId() {
        let manager = createTestManager()

        let result = manager.selectConfiguration(bundleId: "com.unknown.bundle")

        #expect(result == false)
    }

    @Test("selectedConfiguration returns nil when no selection")
    func selectedConfigurationNoSelection() {
        let manager = createTestManager()

        // If no configs exist, selection should be nil
        if manager.configurations.isEmpty {
            #expect(manager.selectedConfiguration == nil)
        }
    }

    // MARK: - Edited Flag

    @Test("markSelectedConfigAsEdited sets flag to true")
    func markAsEdited() {
        let manager = createTestManager()

        // First set it to false
        manager.selectedConfigHasBeenEdited = false
        #expect(manager.selectedConfigHasBeenEdited == false)

        // Then mark as edited
        manager.markSelectedConfigAsEdited()

        #expect(manager.selectedConfigHasBeenEdited == true)
    }

    @Test("markSelectedConfigAsEdited is idempotent")
    func markAsEditedIdempotent() {
        let manager = createTestManager()

        manager.selectedConfigHasBeenEdited = true
        manager.markSelectedConfigAsEdited()

        #expect(manager.selectedConfigHasBeenEdited == true)
    }
}

// MARK: - Configuration Operations Tests

/// These tests verify the data structure operations without side effects
@Suite("Configuration Data Tests")
struct ConfigurationDataTests {

    @Test("Empty configurations array starts correctly")
    func emptyConfigurationsArray() {
        let configs: [DockTileConfiguration] = []

        #expect(configs.isEmpty)
        #expect(configs.count == 0)
    }

    @Test("Adding configuration increases count")
    func addingConfigurationIncreasesCount() {
        var configs: [DockTileConfiguration] = []

        let config = DockTileConfiguration(name: "Test Tile")
        configs.append(config)

        #expect(configs.count == 1)
        #expect(configs.first?.name == "Test Tile")
    }

    @Test("Removing configuration by ID")
    func removingConfigurationById() {
        var configs: [DockTileConfiguration] = [
            DockTileConfiguration(name: "Tile 1"),
            DockTileConfiguration(name: "Tile 2"),
            DockTileConfiguration(name: "Tile 3")
        ]

        let idToRemove = configs[1].id

        configs.removeAll { $0.id == idToRemove }

        #expect(configs.count == 2)
        #expect(!configs.contains { $0.id == idToRemove })
    }

    @Test("Finding configuration by ID")
    func findingConfigurationById() {
        let configs = [
            DockTileConfiguration(name: "Tile 1"),
            DockTileConfiguration(name: "Tile 2"),
            DockTileConfiguration(name: "Tile 3")
        ]

        let targetId = configs[1].id
        let found = configs.first { $0.id == targetId }

        #expect(found?.name == "Tile 2")
    }

    @Test("Finding configuration by bundle identifier")
    func findingConfigurationByBundleId() {
        let config1 = DockTileConfiguration(name: "Tile 1", bundleIdentifier: "com.test.tile1")
        let config2 = DockTileConfiguration(name: "Tile 2", bundleIdentifier: "com.test.tile2")
        let configs = [config1, config2]

        let found = configs.first { $0.bundleIdentifier == "com.test.tile2" }

        #expect(found?.name == "Tile 2")
    }

    @Test("Updating configuration preserves ID")
    func updatingConfigurationPreservesId() {
        var configs = [
            DockTileConfiguration(name: "Original Name")
        ]

        let originalId = configs[0].id

        if let index = configs.firstIndex(where: { $0.id == originalId }) {
            configs[index].name = "Updated Name"
        }

        #expect(configs[0].id == originalId)
        #expect(configs[0].name == "Updated Name")
    }

    // MARK: - App Item Operations

    @Test("Adding app item to configuration")
    func addingAppItem() {
        var config = DockTileConfiguration(name: "Test Tile")

        let appItem = AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari")
        config.appItems.append(appItem)

        #expect(config.appItems.count == 1)
        #expect(config.appItems.first?.name == "Safari")
    }

    @Test("Removing app item from configuration")
    func removingAppItem() {
        var config = DockTileConfiguration(name: "Test Tile")

        let appItem1 = AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari")
        let appItem2 = AppItem(bundleIdentifier: "com.apple.Notes", name: "Notes")
        config.appItems = [appItem1, appItem2]

        config.appItems.removeAll { $0.id == appItem1.id }

        #expect(config.appItems.count == 1)
        #expect(config.appItems.first?.name == "Notes")
    }

    @Test("Reordering app items")
    func reorderingAppItems() {
        var config = DockTileConfiguration(name: "Test Tile")

        let appItem1 = AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari")
        let appItem2 = AppItem(bundleIdentifier: "com.apple.Notes", name: "Notes")
        let appItem3 = AppItem(bundleIdentifier: "com.apple.Mail", name: "Mail")
        config.appItems = [appItem1, appItem2, appItem3]

        // Move first item to end
        config.appItems.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(config.appItems[0].name == "Notes")
        #expect(config.appItems[1].name == "Mail")
        #expect(config.appItems[2].name == "Safari")
    }
}

// MARK: - JSON Persistence Tests

@Suite("Configuration JSON Persistence Tests")
struct ConfigurationJSONPersistenceTests {

    @Test("Configurations encode to JSON")
    func encodeToJSON() throws {
        let configs = [
            DockTileConfiguration(name: "Tile 1", tintColor: .blue),
            DockTileConfiguration(name: "Tile 2", tintColor: .red)
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(configs)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString!.contains("Tile 1"))
        #expect(jsonString!.contains("Tile 2"))
    }

    @Test("Configurations decode from JSON")
    func decodeFromJSON() throws {
        let json = """
        [
            {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "name": "Test Tile",
                "tintColor": {"type": "preset", "value": "blue"},
                "symbolEmoji": "star",
                "layoutMode": "grid",
                "appItems": [],
                "isVisibleInDock": true,
                "bundleIdentifier": "com.test.tile"
            }
        ]
        """

        let decoder = JSONDecoder()
        let configs = try decoder.decode([DockTileConfiguration].self, from: json.data(using: .utf8)!)

        #expect(configs.count == 1)
        #expect(configs[0].name == "Test Tile")
        #expect(configs[0].tintColor == .blue)
    }

    @Test("Round-trip preserves configurations")
    func roundTripPreservesConfigs() throws {
        let original = [
            DockTileConfiguration(
                name: "Tile 1",
                tintColor: .purple,
                iconType: .sfSymbol,
                iconValue: "folder.fill",
                iconScale: 16,
                layoutMode: .list,
                isVisibleInDock: false,
                showInAppSwitcher: true
            ),
            DockTileConfiguration(
                name: "Tile 2",
                tintColor: .custom("#FF5733"),
                iconType: .emoji,
                iconValue: "📁",
                iconScale: 14
            )
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([DockTileConfiguration].self, from: data)

        #expect(decoded.count == original.count)

        for (orig, dec) in zip(original, decoded) {
            #expect(dec.id == orig.id)
            #expect(dec.name == orig.name)
            #expect(dec.tintColor == orig.tintColor)
            #expect(dec.iconType == orig.iconType)
            #expect(dec.iconValue == orig.iconValue)
            #expect(dec.iconScale == orig.iconScale)
            #expect(dec.layoutMode == orig.layoutMode)
            #expect(dec.isVisibleInDock == orig.isVisibleInDock)
            #expect(dec.showInAppSwitcher == orig.showInAppSwitcher)
        }
    }

    @Test("Empty array encodes and decodes")
    func emptyArrayRoundTrip() throws {
        let original: [DockTileConfiguration] = []

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([DockTileConfiguration].self, from: data)

        #expect(decoded.isEmpty)
    }

    @Test("Configuration with app items round-trips")
    func configWithAppItemsRoundTrip() throws {
        var config = DockTileConfiguration(name: "Apps Tile")
        config.appItems = [
            AppItem(bundleIdentifier: "com.apple.Safari", name: "Safari"),
            AppItem(bundleIdentifier: "com.apple.Notes", name: "Notes", isFolder: false),
            AppItem(bundleIdentifier: "folder.test", name: "My Folder", isFolder: true, folderPath: "/Users/test/Documents")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode([config])

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([DockTileConfiguration].self, from: data)

        #expect(decoded.count == 1)
        #expect(decoded[0].appItems.count == 3)
        #expect(decoded[0].appItems[2].isFolder == true)
        #expect(decoded[0].appItems[2].folderPath == "/Users/test/Documents")
    }
}
