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

    /// Tracks whether the currently selected tile has been edited since creation/last save
    /// Used to disable the + button until user engages with the new tile
    @Published var selectedConfigHasBeenEdited: Bool = true

    /// Internal flag to prevent didSet from overriding selectedConfigHasBeenEdited during creation
    private var isCreatingNewConfig: Bool = false

    @Published var selectedConfigId: UUID? {
        didSet {
            // Persist selection whenever it changes
            if let id = selectedConfigId {
                UserDefaults.standard.set(id.uuidString, forKey: lastSelectedConfigKey)

                // When switching to an existing config, mark it as "edited" (i.e., not a fresh new tile)
                // This enables the + button for existing tiles
                // Skip this when creating a new config (isCreatingNewConfig flag is set)
                if oldValue != id && !isCreatingNewConfig {
                    selectedConfigHasBeenEdited = true
                }
            } else {
                UserDefaults.standard.removeObject(forKey: lastSelectedConfigKey)
            }
        }
    }

    // MARK: - Storage

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// UserDefaults key for persisting last selected config
    private let lastSelectedConfigKey = UserDefaultsKeys.lastSelectedConfigId

    // MARK: - Dock Sync

    private var dockWatcher: DockPlistWatcher?

    // MARK: - Initialization

    init() {
        // Set up storage location using environment-specific filename
        // Dev: ~/Library/Preferences/com.docktile.dev.configs.json
        // Release: ~/Library/Preferences/com.docktile.configs.json
        self.storageURL = AppEnvironment.preferencesURL

        // Configure JSON encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // Load existing configurations
        loadConfigurations()

        print("📦 ConfigurationManager initialized")
        print("   Storage: \(storageURL.path)")
        print("   Loaded \(configurations.count) configuration(s)")

        // Restore last selected config (or auto-select first if configs exist)
        restoreOrAutoSelectConfig()

        // Dock visibility is the MAIN app's responsibility only. Helper processes also
        // construct a ConfigurationManager (see HelperAppDelegate) purely to read their own
        // tile's config for the popover — they must NOT watch or reconcile the Dock, or every
        // running helper would redundantly sync and race the main app on the shared config
        // file and the Dock plist.
        guard !AppEnvironment.isHelper else { return }

        // Sync dock visibility on launch — reconcile both directions, including removing
        // any tiles left stuck in the Dock that the config says should be hidden.
        syncDockVisibility(reconcileDockedHiddenTiles: true)

        // Start watching for Dock changes
        startDockWatcher()
    }

    /// Restore last selected config from UserDefaults, or auto-select first config if available
    private func restoreOrAutoSelectConfig() {
        // Try to restore last selected config
        if let savedIdString = UserDefaults.standard.string(forKey: lastSelectedConfigKey),
           let savedId = UUID(uuidString: savedIdString),
           configurations.contains(where: { $0.id == savedId }) {
            selectedConfigId = savedId
            print("   ✓ Restored last selected config: \(savedIdString)")
        }
        // If no saved selection but configs exist, select the first one
        else if !configurations.isEmpty {
            selectedConfigId = configurations.first?.id
            print("   ✓ Auto-selected first config")
        }
    }

    // MARK: - CRUD Operations

    /// Create a new configuration with default values
    @discardableResult
    func createConfiguration() -> DockTileConfiguration {
        let config = DockTileConfiguration(
            name: generateUniqueName(base: ConfigurationDefaults.name),
            tintColor: ConfigurationDefaults.tintColor,
            symbolEmoji: ConfigurationDefaults.symbolEmoji,
            iconType: ConfigurationDefaults.iconType,
            iconValue: ConfigurationDefaults.iconValue
        )

        configurations.append(config)

        // Mark as not yet edited - disables + button until user makes changes
        // Use flag to prevent selectedConfigId's didSet from overriding this
        isCreatingNewConfig = true
        selectedConfigHasBeenEdited = false
        selectedConfigId = config.id
        isCreatingNewConfig = false

        saveConfigurations()

        AnalyticsService.shared.log(.tileCreated)
        print("✅ Created configuration: \(config.name) [\(config.id)]")
        print("   selectedConfigHasBeenEdited = \(selectedConfigHasBeenEdited) (should be false)")
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

    /// Mark the currently selected config as edited (enables + button)
    /// Called by detail view when user makes any change
    func markSelectedConfigAsEdited() {
        if !selectedConfigHasBeenEdited {
            selectedConfigHasBeenEdited = true
            print("✏️ Selected config marked as edited")
        }
    }

    /// Delete a configuration by ID
    func deleteConfiguration(_ id: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else {
            print("⚠️ Configuration not found: \(id)")
            return
        }

        let config = configurations[index]

        // Always clean up helper bundle, but only restart Dock if tile was visible
        Task {
            do {
                try await HelperBundleManager.shared.uninstallHelper(
                    for: config,
                    restartDock: config.isVisibleInDock
                )
                print("🗑️ Removed helper bundle for: \(config.name)")
            } catch {
                AnalyticsService.shared.record(error, context: "uninstallHelper",
                                               keys: ["bundle_id": config.bundleIdentifier])
            }
        }

        AnalyticsService.shared.log(.tileRemoved, ["app_count": config.appItems.count])
        configurations.remove(at: index)

        // If deleted config was selected, select another one (or nil if none left)
        if selectedConfigId == id {
            selectedConfigId = configurations.first?.id
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

    /// Save configurations to disk (public access for migration manager)
    func saveAllConfigurations() {
        saveConfigurations()
    }

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
    /// Uses decodeIfPresent in DockTileConfiguration for backward compatibility
    private func loadConfigurations() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            print("📁 No existing configuration file found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            configurations = try decoder.decode([DockTileConfiguration].self, from: data)
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

    /// Select a configuration by ID (used for deep linking from helpers)
    /// Returns true if the config was found and selected
    @discardableResult
    func selectConfiguration(id: UUID) -> Bool {
        guard configurations.contains(where: { $0.id == id }) else {
            print("⚠️ Cannot select config - not found: \(id)")
            return false
        }
        selectedConfigId = id
        print("✓ Selected config via deep link: \(id)")
        return true
    }

    /// Select a configuration by bundle identifier (used when helper requests configure)
    /// Returns true if the config was found and selected
    @discardableResult
    func selectConfiguration(bundleId: String) -> Bool {
        guard let config = configuration(forBundleId: bundleId) else {
            print("⚠️ Cannot select config - bundle ID not found: \(bundleId)")
            return false
        }
        selectedConfigId = config.id
        print("✓ Selected config via bundle ID: \(bundleId)")
        return true
    }

    // MARK: - Dock Visibility Sync

    /// Sync configuration visibility with actual Dock state, in both directions:
    ///
    /// 1. Config says **visible** but the tile is **absent** from the Dock → flip the
    ///    config to hidden (the user removed it manually via the Dock).
    /// 2. Config says **hidden** but the tile is still **present** in the Dock → actually
    ///    remove it (a previous hide didn't fully take — e.g. clobbered by another
    ///    instance or interrupted), so reality matches the user's stored intent.
    ///
    /// - Parameter reconcileDockedHiddenTiles: when `true`, direction 2 actively removes
    ///   stuck tiles from the Dock. This restarts the Dock, so it is only enabled for the
    ///   one-shot launch sync — NOT the live `DockPlistWatcher` path, where repeatedly
    ///   removing could fight the user or spin the Dock in a restart loop.
    func syncDockVisibility(reconcileDockedHiddenTiles: Bool = false) {
        print("🔄 Syncing Dock visibility (reconcile=\(reconcileDockedHiddenTiles))...")

        var hasChanges = false
        var stuckHiddenConfigs: [DockTileConfiguration] = []

        for index in configurations.indices {
            let config = configurations[index]
            let isActuallyInDock = HelperBundleManager.shared.findInDock(bundleId: config.bundleIdentifier) != nil

            if config.isVisibleInDock, !isActuallyInDock {
                // Direction 1: visible config, but gone from the Dock → mark hidden.
                print("   ⚠️ '\(config.name)' was removed from Dock - updating visibility")
                configurations[index].isVisibleInDock = false
                hasChanges = true
            } else if !config.isVisibleInDock, isActuallyInDock {
                // Direction 2: hidden config, but still in the Dock → remove it for real.
                guard reconcileDockedHiddenTiles else { continue }
                print("   ⚠️ '\(config.name)' is hidden but still in Dock - removing to match config")
                stuckHiddenConfigs.append(config)
            }
        }

        if hasChanges {
            saveConfigurations()
            print("   ✓ Dock visibility synced")
        } else {
            print("   ✓ All tiles in sync")
        }

        // Remove stuck tiles after the loop. removeFromDock guards against double-removal
        // via its own in-flight set, and once removed findInDock returns nil so a
        // subsequent sync is a no-op — no restart loop.
        for config in stuckHiddenConfigs {
            Task {
                do {
                    try await HelperBundleManager.shared.removeFromDock(for: config)
                } catch {
                    print("   ⚠️ Failed to remove stuck hidden tile '\(config.name)': \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Dock Watcher

    private func startDockWatcher() {
        dockWatcher = DockPlistWatcher()
        dockWatcher?.onDockChanged = { [weak self] in
            self?.syncDockVisibility()
        }
        dockWatcher?.startWatching()
    }

    /// Stop watching for Dock changes (call on app termination if needed)
    func stopDockWatcher() {
        dockWatcher?.stopWatching()
        dockWatcher = nil
    }
}
