//
//  ConfigurationManager.swift
//  DockTile
//
//  State management for dock tile configurations with JSON persistence
//  Swift 6 - Strict Concurrency
//

import Foundation
import SwiftUI

@MainActor
final class ConfigurationManager: ObservableObject {
    // MARK: - Published State

    @Published var configurations: [DockTileConfiguration] = []
    @Published var selectedConfigId: UUID?

    // MARK: - Storage

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init() {
        // Set up storage location: ~/Library/Preferences/com.docktile.configs.json
        let preferencesDir = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Preferences")

        self.storageURL = preferencesDir.appendingPathComponent("com.docktile.configs.json")

        // Configure JSON encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // Load existing configurations
        loadConfigurations()

        print("📦 ConfigurationManager initialized")
        print("   Storage: \(storageURL.path)")
        print("   Loaded \(configurations.count) configuration(s)")
    }

    // MARK: - CRUD Operations

    /// Create a new configuration with default values
    @discardableResult
    func createConfiguration() -> DockTileConfiguration {
        let config = DockTileConfiguration(
            name: generateUniqueName(base: "My DockTile"),
            tintColor: .blue,
            symbolEmoji: "⭐"
        )

        configurations.append(config)
        selectedConfigId = config.id

        saveConfigurations()

        print("✅ Created configuration: \(config.name) [\(config.id)]")
        return config
    }

    /// Update an existing configuration
    func updateConfiguration(_ config: DockTileConfiguration) {
        guard let index = configurations.firstIndex(where: { $0.id == config.id }) else {
            print("⚠️ Configuration not found: \(config.id)")
            return
        }

        configurations[index] = config
        saveConfigurations()

        print("💾 Updated configuration: \(config.name) [\(config.id)]")
    }

    /// Delete a configuration by ID
    func deleteConfiguration(_ id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else {
            print("⚠️ Configuration not found: \(id)")
            return
        }

        let config = configurations[index]

        // Delete helper bundle if it exists
        if config.isVisibleInDock {
            Task {
                do {
                    try HelperBundleManager.shared.uninstallHelper(for: config)
                    print("🗑️ Removed helper bundle for: \(config.name)")
                } catch {
                    print("⚠️ Failed to remove helper bundle: \(error.localizedDescription)")
                }
            }
        }

        configurations.remove(at: index)

        // Clear selection if deleted (show empty state)
        if selectedConfigId == id {
            selectedConfigId = nil
        }

        saveConfigurations()

        print("🗑️ Deleted configuration: \(config.name) [\(id)]")
    }

    /// Duplicate an existing configuration
    @discardableResult
    func duplicateConfiguration(_ config: DockTileConfiguration) -> DockTileConfiguration {
        let duplicate = DockTileConfiguration(
            name: generateUniqueName(base: config.name),
            tintColor: config.tintColor,
            symbolEmoji: config.symbolEmoji,
            layoutMode: config.layoutMode,
            appItems: config.appItems,
            isVisibleInDock: false  // Don't auto-show duplicate
        )

        configurations.append(duplicate)
        selectedConfigId = duplicate.id

        saveConfigurations()

        print("📋 Duplicated configuration: \(config.name) → \(duplicate.name)")
        return duplicate
    }

    // MARK: - App Item Management

    /// Add an app to a configuration
    func addAppItem(_ item: AppItem, to configId: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == configId }) else {
            print("⚠️ Configuration not found: \(configId)")
            return
        }

        configurations[index].appItems.append(item)
        saveConfigurations()

        print("➕ Added app '\(item.name)' to configuration: \(configurations[index].name)")
    }

    /// Remove an app from a configuration
    func removeAppItem(_ itemId: UUID, from configId: UUID) {
        guard let configIndex = configurations.firstIndex(where: { $0.id == configId }) else {
            print("⚠️ Configuration not found: \(configId)")
            return
        }

        configurations[configIndex].appItems.removeAll { $0.id == itemId }
        saveConfigurations()

        print("➖ Removed app from configuration: \(configurations[configIndex].name)")
    }

    /// Reorder apps in a configuration
    func reorderAppItems(from source: IndexSet, to destination: Int, in configId: UUID) {
        guard let configIndex = configurations.firstIndex(where: { $0.id == configId }) else {
            print("⚠️ Configuration not found: \(configId)")
            return
        }

        configurations[configIndex].appItems.move(fromOffsets: source, toOffset: destination)
        saveConfigurations()

        print("🔄 Reordered apps in configuration: \(configurations[configIndex].name)")
    }

    // MARK: - Persistence

    /// Save all configurations to JSON file
    private func saveConfigurations() {
        do {
            let data = try encoder.encode(configurations)
            try data.write(to: storageURL, options: [.atomic])
            print("💾 Saved \(configurations.count) configuration(s) to \(storageURL.lastPathComponent)")
        } catch {
            print("❌ Failed to save configurations: \(error.localizedDescription)")
        }
    }

    /// Load configurations from JSON file
    private func loadConfigurations() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            print("📁 No existing configuration file found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            configurations = try decoder.decode([DockTileConfiguration].self, from: data)

            // Don't auto-select - let app launch with empty state
            // User will click "+" to create new tile or select existing one

            print("📂 Loaded \(configurations.count) configuration(s) from \(storageURL.lastPathComponent)")
        } catch {
            print("❌ Failed to load configurations: \(error.localizedDescription)")
            print("   Starting with empty configuration list")
            configurations = []
        }
    }

    // MARK: - Helper Methods

    /// Generate a unique name by appending numbers if needed
    private func generateUniqueName(base: String) -> String {
        let existingNames = Set(configurations.map { $0.name })

        if !existingNames.contains(base) {
            return base
        }

        var counter = 1
        while existingNames.contains("\(base) \(counter)") {
            counter += 1
        }

        return "\(base) \(counter)"
    }

    /// Get configuration by ID
    func configuration(for id: UUID) -> DockTileConfiguration? {
        return configurations.first { $0.id == id }
    }

    /// Get configuration by bundle identifier (for helper apps)
    func configuration(forBundleId bundleId: String) -> DockTileConfiguration? {
        return configurations.first { $0.bundleIdentifier == bundleId }
    }

    /// Get currently selected configuration
    var selectedConfiguration: DockTileConfiguration? {
        guard let id = selectedConfigId else { return nil }
        return configuration(for: id)
    }
}
