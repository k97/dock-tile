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
            // Only probe disk/Dock when the tile could actually need regeneration (visible AND
            // not already current) — keeps the classifier's inputs lazy, matching the original.
            let needsProbe = config.isVisibleInDock && config.helperAppVersion != currentVersion
            let helperExistsOnDisk = needsProbe ? helperManager.helperExists(for: config) : false
            let isInDock = needsProbe ? (helperManager.findInDock(bundleId: config.bundleIdentifier) != nil) : false

            switch Self.classifyForMigration(
                isVisibleInDock: config.isVisibleInDock,
                helperAppVersion: config.helperAppVersion,
                currentVersion: currentVersion,
                helperExistsOnDisk: helperExistsOnDisk,
                isInDock: isInDock
            ) {
            case .skipUpToDate:
                continue

            case .stampOnly:
                print("[Migration]   '\(config.name)' — stamping only (not visible / no bundle / not in Dock)")
                configsToStamp.append(config.id)

            case .regenerate:
                let reason = config.helperAppVersion == nil ? "pre-migration" : "v\(config.helperAppVersion!)"
                print("[Migration]   '\(config.name)' — stale (\(reason))")
                staleBundleConfigs.append(config)
            }
        }

        // Stamp configs that don't need regeneration
        for id in configsToStamp {
            stampVersion(id, version: currentVersion)
        }

        // Regenerate stale helpers
        if !staleBundleConfigs.isEmpty {
            print("[Migration] Regenerating \(staleBundleConfigs.count) helper(s)...")
            DiagnosticsLog.shared.log("migration", "Regenerating \(staleBundleConfigs.count) stale helper(s) for v\(currentVersion)")
            await regenerateBatch(staleBundleConfigs, currentVersion: currentVersion)
        }

        // Save and mark migration complete
        configManager.saveAllConfigurations()
        UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastMigratedAppVersion)
        AnalyticsService.shared.log(.helperMigrationRun, [
            "from_version": lastMigrated ?? "none",
            "to_version": currentVersion,
            "stale_count": staleBundleConfigs.count
        ])
        print("[Migration] Complete for v\(currentVersion)")
    }

    // MARK: - Private

    private func regenerateBatch(_ configs: [DockTileConfiguration], currentVersion: String) async {
        let helperManager = HelperBundleManager.shared

        let outcome = await Self.runRegenerationBatch(
            configs,
            quit: { await helperManager.quitHelperAndWait(bundleId: $0) },
            regenerate: { config in
                do {
                    try await helperManager.regenerateHelperBundle(for: config)
                    print("[Migration]   Regenerated '\(config.name)'")
                } catch {
                    DiagnosticsLog.shared.log("migration", "FAILED to regenerate '\(config.name)': \(error.localizedDescription)")
                    AnalyticsService.shared.record(error, context: "regenerateHelperBundle",
                                                   keys: ["bundle_id": config.bundleIdentifier])
                    throw error
                }
            }
        )

        // Stamp EVERY config — successes and failures alike — so a broken helper isn't retried
        // on every launch (see `runRegenerationBatch`).
        for id in outcome.stampedIds {
            stampVersion(id, version: currentVersion)
        }

        let regeneratedConfigs = configs.filter { outcome.regeneratedIds.contains($0.id) }
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

    /// Outcome of a regeneration batch: every input id is stamped (the no-retry invariant), and
    /// the subset that actually regenerated is reported so the caller restarts/relaunches only it.
    struct BatchOutcome: Equatable {
        var stampedIds: [UUID]
        var regeneratedIds: [UUID]
    }

    /// Drives a regeneration batch with injected side effects, so the **stamp-on-failure**
    /// invariant is unit-testable without touching real bundles or the Dock: each config is
    /// quit, then regenerated; whether regeneration succeeds or throws, the config is stamped.
    /// Only the configs whose `regenerate` returned without throwing are reported as regenerated.
    /// (MainActor-isolated via the enclosing class — the injected closures capture MainActor state.)
    static func runRegenerationBatch(
        _ configs: [DockTileConfiguration],
        quit: (String) async -> Void,
        regenerate: (DockTileConfiguration) async throws -> Void
    ) async -> BatchOutcome {
        var stamped: [UUID] = []
        var regenerated: [UUID] = []

        for config in configs {
            await quit(config.bundleIdentifier)
            do {
                try await regenerate(config)
                regenerated.append(config.id)
            } catch {
                // Swallowed here on purpose: the caller logs/records. The stamp below STILL runs.
            }
            stamped.append(config.id)  // INVARIANT: always stamp, success or failure.
        }

        return BatchOutcome(stampedIds: stamped, regeneratedIds: regenerated)
    }

    // MARK: - Migration triage (pure seam)

    /// What `migrateIfNeeded` should do with a single helper. Pure data so the triage rules —
    /// which decide regeneration vs. a cheap version stamp — are unit-testable without touching
    /// the filesystem or Dock. A wrong rule here causes either regeneration thrash on every
    /// launch or rebuilding helpers that don't exist.
    enum MigrationAction: Equatable {
        case skipUpToDate   // helper already stamped at the current version — nothing to do
        case stampOnly      // not visible / no bundle on disk / not in Dock → just stamp version
        case regenerate     // visible, stale, bundle present and pinned → rebuild the bundle
    }

    /// Pure triage rule. Order matters and mirrors `migrateIfNeeded`'s original guards:
    /// visibility → up-to-date → bundle-on-disk → in-Dock → regenerate.
    nonisolated static func classifyForMigration(
        isVisibleInDock: Bool,
        helperAppVersion: String?,
        currentVersion: String,
        helperExistsOnDisk: Bool,
        isInDock: Bool
    ) -> MigrationAction {
        guard isVisibleInDock else { return .stampOnly }
        if helperAppVersion == currentVersion { return .skipUpToDate }
        guard helperExistsOnDisk else { return .stampOnly }
        guard isInDock else { return .stampOnly }
        return .regenerate
    }

    private func stampVersion(_ configId: UUID, version: String) {
        guard let index = configManager.configurations.firstIndex(where: { $0.id == configId }) else {
            return
        }
        configManager.configurations[index].helperAppVersion = version
    }
}
