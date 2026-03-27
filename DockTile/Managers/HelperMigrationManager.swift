//
//  HelperMigrationManager.swift
//  DockTile
//
//  Automatically migrates helper bundles when the main app updates.
//  Detects stale helpers (version mismatch or pre-migration), regenerates
//  them in batch with a single Dock restart, and stamps the new version.
//
//  Swift 6 - Strict Concurrency
//

import Foundation

@MainActor
final class HelperMigrationManager {

    private let configManager: ConfigurationManager

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    // MARK: - Public API

    /// Check and migrate stale helpers if needed.
    /// Call once on main app launch. No-op if already migrated for this version.
    func migrateIfNeeded() async {
        let currentVersion = HelperBundleManager.currentAppVersion

        // Already migrated for this version?
        let lastMigrated = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastMigratedAppVersion)
        if lastMigrated == currentVersion {
            return
        }

        print("[Migration] Checking helpers for v\(currentVersion) (last migrated: \(lastMigrated ?? "never"))")

        let helperManager = HelperBundleManager.shared
        var staleBundleConfigs: [DockTileConfiguration] = []
        var configsToStamp: [UUID] = []

        for config in configManager.configurations {
            // Not visible = no helper on disk to update. Just stamp version.
            guard config.isVisibleInDock else {
                configsToStamp.append(config.id)
                continue
            }

            // Already up to date?
            if config.helperAppVersion == currentVersion {
                continue
            }

            // Bundle doesn't exist on disk (user deleted it). Stamp and move on.
            guard helperManager.helperExists(for: config) else {
                print("[Migration]   '\(config.name)' — no bundle on disk, stamping only")
                configsToStamp.append(config.id)
                continue
            }

            // Not in Dock (user dragged it out). Stamp and move on.
            if helperManager.findInDock(bundleId: config.bundleIdentifier) == nil {
                print("[Migration]   '\(config.name)' — not in Dock, stamping only")
                configsToStamp.append(config.id)
                continue
            }

            // Needs regeneration
            let reason = config.helperAppVersion == nil ? "pre-migration" : "v\(config.helperAppVersion!)"
            print("[Migration]   '\(config.name)' — stale (\(reason))")
            staleBundleConfigs.append(config)
        }

        // Stamp configs that don't need regeneration
        for id in configsToStamp {
            stampVersion(id, version: currentVersion)
        }

        // Regenerate stale helpers
        if !staleBundleConfigs.isEmpty {
            print("[Migration] Regenerating \(staleBundleConfigs.count) helper(s)...")
            await regenerateBatch(staleBundleConfigs, currentVersion: currentVersion)
        }

        // Save and mark migration complete
        configManager.saveAllConfigurations()
        UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastMigratedAppVersion)
        print("[Migration] Complete for v\(currentVersion)")
    }

    // MARK: - Private

    private func regenerateBatch(_ configs: [DockTileConfiguration], currentVersion: String) async {
        let helperManager = HelperBundleManager.shared
        var regeneratedConfigs: [DockTileConfiguration] = []

        for config in configs {
            // Quit running helper
            await helperManager.quitHelperAndWait(bundleId: config.bundleIdentifier)

            do {
                try await helperManager.regenerateHelperBundle(for: config)
                regeneratedConfigs.append(config)
                print("[Migration]   Regenerated '\(config.name)'")
            } catch {
                print("[Migration]   FAILED '\(config.name)': \(error.localizedDescription)")
            }

            // Stamp version regardless (avoid retrying broken configs every launch)
            stampVersion(config.id, version: currentVersion)
        }

        guard !regeneratedConfigs.isEmpty else { return }

        // Single Dock restart for the whole batch
        print("[Migration] Restarting Dock for \(regeneratedConfigs.count) updated helper(s)")
        helperManager.performDockRestart()

        // Wait for Dock to stabilize
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Relaunch regenerated helpers
        for config in regeneratedConfigs {
            helperManager.launchHelperIfExists(for: config)
        }
    }

    private func stampVersion(_ configId: UUID, version: String) {
        guard let index = configManager.configurations.firstIndex(where: { $0.id == configId }) else {
            return
        }
        configManager.configurations[index].helperAppVersion = version
    }
}
