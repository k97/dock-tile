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

    /// Once-per-session guard for `selfHealIfNeeded` (the manager is recreated per launch `.task`,
    /// so the throttle is static — mirrors `ConfigurationManager.hasScannedForMissingApps`).
    private static var didSelfHeal = false

    /// Once-per-launch guard for the WHOLE launch sequence (migrate → scan → self-heal) in the main
    /// window's `.task`. WHY: that `.task` runs again when the window is reopened during a launch
    /// (Dock click, deep link, ⌘,) while the first one is still suspended inside its batch — its
    /// cancellation doesn't stop the batch. A migration-only guard let the second pass go straight
    /// to self-heal, which read the tile mid-rebuild as icon-incomplete and the batch's unreached
    /// tiles as built by an older version, and started a second batch: two batches then kill the
    /// Dock in alternation. Each launch starts with the flag cleared, so convergence across
    /// launches is unchanged.
    private static var didStartLaunchMaintenance = false

    /// `true` exactly once per launch; the caller runs the launch sequence only then.
    static func beginLaunchMaintenance() -> Bool {
        guard !didStartLaunchMaintenance else { return false }
        didStartLaunchMaintenance = true
        return true
    }

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    // MARK: - Public API

    /// Check and migrate stale helpers if needed.
    /// Call once on main app launch. No-op if already migrated for this version.
    func migrateIfNeeded() async {
        let currentVersion = HelperBundleManager.currentAppVersion

        let lastMigrated = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastMigratedAppVersion)

        // NOTE: no hard early-return on `lastMigrated == currentVersion`. Migration is convergent —
        // it re-derives per-tile state from `helperAppVersion` every launch, so a tile left stale by
        // a previously failed or blocked run retries until it succeeds. The loop below is cheap when
        // everything is already current (each tile is skipUpToDate with no disk/Dock probe).
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

        // Converged already for this version — nothing to stamp or rebuild. Cheap fast-path.
        if configsToStamp.isEmpty && staleBundleConfigs.isEmpty {
            if lastMigrated != currentVersion {
                UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastMigratedAppVersion)
            }
            return
        }

        print("[Migration] Checking helpers for v\(currentVersion) (last migrated: \(lastMigrated ?? "never"))")

        // Stamp the confident no-rebuild tiles (hidden / no bundle / not pinned — each rebuilds via
        // installHelper when next shown, so stamping current is safe).
        for id in configsToStamp {
            stampVersion(id, version: currentVersion)
        }

        // Regenerate stale helpers — but only if we CAN. A translocated app can't copy itself, so
        // the batch would force-quit each helper and then fail; defer it and leave the tiles stale
        // so they retry once the app is relocated (the launch relocation nudge asks the user to
        // move). Skipping here also avoids re-quitting helpers every launch on a doomed machine.
        if !staleBundleConfigs.isEmpty {
            if AppRelocationManager.shared.canGenerateBundles {
                print("[Migration] Regenerating \(staleBundleConfigs.count) helper(s)...")
                DiagnosticsLog.shared.log("migration", "Regenerating \(staleBundleConfigs.count) stale helper(s) for v\(currentVersion)")
                await DiagnosticsLog.shared.measure("Migrate \(staleBundleConfigs.count) stale helper(s) → v\(currentVersion)") {
                    await regenerateBatch(staleBundleConfigs, currentVersion: currentVersion)
                }
            } else {
                DiagnosticsLog.shared.log("migration", "Migration deferred: bundle generation blocked (translocated) — \(staleBundleConfigs.count) helper(s) left stale, will retry once relocated")
            }
        }

        configManager.saveAllConfigurations()

        // Mark the version fully migrated ONLY when no visible tile remains stale (every
        // regeneration succeeded). If some failed or were blocked, leave the marker so the next
        // launch retries the remainder — correctness is the per-tile helperAppVersion, not this key.
        let stillStale = configManager.configurations.contains {
            $0.isVisibleInDock && $0.helperAppVersion != currentVersion
        }
        if !stillStale {
            UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastMigratedAppVersion)
        }

        AnalyticsService.shared.log(.helperMigrationRun, [
            "from_version": lastMigrated ?? "none",
            "to_version": currentVersion,
            "stale_count": staleBundleConfigs.count,
            "still_stale": stillStale ? 1 : 0
        ])
        print("[Migration] Complete for v\(currentVersion) (stillStale: \(stillStale))")
    }

    /// Version-independent self-heal: repair pinned tiles whose on-disk bundle is broken in a way
    /// normal migration misses — because a *pre-fix* app version stamped `helperAppVersion` current
    /// while the bundle is actually missing, structurally corrupt, or built by an older app — or
    /// whose Dock entry is stale (the shared `dockEntriesAreCurrent` predicate). Keys on the ACTUAL
    /// on-disk and Dock state, not the config stamp, so it catches damage the (config-stale-keyed)
    /// migration skips.
    ///
    /// **Draft-safe by construction**: gated on `pinnedEntryPaths` (a reliable, synchronized Dock
    /// read). A brand-new tile the user hasn't Added to the Dock is never in that set, so it is
    /// never touched — repairing only already-pinned tiles cannot create an unwanted pin.
    ///
    /// Call once per launch, after `migrateIfNeeded` + `scanForMissingApps`, main-app only.
    func selfHealIfNeeded() async {
        guard !Self.didSelfHeal else { return }
        Self.didSelfHeal = true

        let helperManager = HelperBundleManager.shared
        let currentVersion = HelperBundleManager.currentAppVersion

        // One synchronized Dock read for the whole sweep: each pinned bundle id → its entries' paths.
        let entries = helperManager.pinnedEntryPaths()
        let pinned = Set(entries.keys)
        guard !pinned.isEmpty else { return }

        var toHeal: [DockTileConfiguration] = []
        for config in configManager.configurations where pinned.contains(config.bundleIdentifier) {
            let bundlePath = helperManager.helperExists(for: config) ? helperManager.helperPath(for: config) : nil
            let bundleExists = bundlePath != nil
            let iconsComplete = bundlePath.map { helperManager.helperIconsComplete(at: $0) } ?? false
            let bakedMatches = bundlePath.flatMap { helperManager.helperBakedVersion(at: $0) } == currentVersion
            // A missing bundle already heals through bundleExists; an unparseable entry is stale.
            let entryCurrent = bundlePath.map {
                HelperBundleManager.dockEntriesAreCurrent(entries[config.bundleIdentifier] ?? [], helperPath: $0.path,
                                                          sameFile: HelperBundleManager.isSameFile)
            } ?? true

            if Self.classifyHelperHealth(
                isPinnedInDock: true,
                bundleExists: bundleExists,
                iconsComplete: iconsComplete,
                bakedVersionMatchesCurrent: bakedMatches,
                dockEntryIsCurrent: entryCurrent
            ) == .heal {
                DiagnosticsLog.shared.log("selfheal",
                    "Pinned tile '\(config.name)' needs repair (exists=\(bundleExists), icons=\(iconsComplete), bakedCurrent=\(bakedMatches), entry=\(entryCurrent))")
                toHeal.append(config)
            }
        }

        guard !toHeal.isEmpty else { return }

        // Don't force-quit + fail on a machine that can't generate bundles (translocated); defer.
        guard AppRelocationManager.shared.canGenerateBundles else {
            DiagnosticsLog.shared.log("selfheal",
                "Self-heal deferred: bundle generation blocked — \(toHeal.count) pinned tile(s) left broken")
            return
        }

        DiagnosticsLog.shared.log("selfheal", "Self-healing \(toHeal.count) broken pinned tile(s)")
        AnalyticsService.shared.log(.helperSelfHeal, ["count": toHeal.count])
        await DiagnosticsLog.shared.measure("Self-heal \(toHeal.count) pinned tile(s)") {
            await regenerateBatch(toHeal, currentVersion: currentVersion)
        }
    }

    /// On-demand rebuild + relaunch of the given helpers with a single Dock restart. Used when the
    /// user saves global Popover Appearance settings and chooses to apply them to running tiles now:
    /// regenerating each visible bundle redeploys the current binary, whose popover then reads the
    /// freshly-saved shared-suite values on its next open. Reuses the launch-time batch, so the same
    /// stamp-on-failure + single-restart invariants hold. Filters to tiles that are actually pinned
    /// with a bundle on disk; stamps them current so the launch migration won't redo the work.
    func reapply(_ configs: [DockTileConfiguration]) async {
        let targets = configs.filter {
            $0.isVisibleInDock && HelperBundleManager.shared.helperExists(for: $0)
        }
        guard !targets.isEmpty else {
            DiagnosticsLog.shared.log("settings", "Apply popover appearance: no visible helpers to update")
            return
        }
        // Fail loud, not silent: if the app is translocated it cannot rebuild any helper (the
        // regenerate batch would swallow the per-tile copy failures and record a bare non-fatal).
        // Surface the actionable "move to /Applications" prompt and skip the doomed batch.
        guard AppRelocationManager.shared.canGenerateBundles else {
            DiagnosticsLog.shared.log("settings", "Apply popover appearance blocked: app is translocated")
            AppRelocationManager.shared.presentBlockingPrompt()
            return
        }
        DiagnosticsLog.shared.log("settings", "Apply popover appearance: rebuilding \(targets.count) helper(s)")
        await DiagnosticsLog.shared.measure("Re-apply popover appearance to \(targets.count) helper(s)") {
            await regenerateBatch(targets, currentVersion: HelperBundleManager.currentAppVersion)
        }
        AnalyticsService.shared.log(.settingChanged, ["setting": "popover_apply", "count": targets.count])
    }

    // MARK: - Private

    private func regenerateBatch(_ configs: [DockTileConfiguration], currentVersion: String) async {
        let helperManager = HelperBundleManager.shared

        // Each tile is built in staging while its old helper runs (showing the rebuild bar), then
        // quit, swapped and relaunched by regenerateHelperBundle — so its bar clears at its own swap.
        let outcome = await Self.runRegenerationBatch(
            configs,
            regenerate: { config in
                do {
                    try await helperManager.regenerateHelperBundle(for: config)
                    print("[Migration]   Regenerated '\(config.name)'")
                } catch {
                    DiagnosticsLog.shared.log("migration", "FAILED to regenerate \(config.diagnosticName): \(error.localizedDescription)")
                    AnalyticsService.shared.record(error, context: "regenerateHelperBundle",
                                                   keys: ["bundle_id": config.bundleIdentifier])
                    throw error
                }
            }
        )

        // Stamp only the configs that actually regenerated. A failed regeneration is left stale so
        // the next launch retries it (convergent migration) — a transient failure (killed
        // mid-generation, a momentary FS error) heals instead of being permanently stamped
        // "migrated" while broken. Retries are cheap and never restart the Dock (only successes do,
        // below), so a persistently-broken tile can't churn the Dock.
        for id in outcome.stampedIds {
            stampVersion(id, version: currentVersion)
        }

        let regeneratedConfigs = configs.filter { outcome.regeneratedIds.contains($0.id) }
        guard !regeneratedConfigs.isEmpty else { return }

        // Re-seat each regenerated tile's Dock entry BEFORE the restart so the Dock loads FRESH
        // icons. A regenerate at the same path + touchBundle leaves the Dock serving its cached icon;
        // re-adding the persistent-apps entry (new GUID) is what forces the refresh — the same
        // mechanism installHelper uses, batched here into the single restart below. Without this the
        // new icons regenerate on disk but the Dock keeps showing the old render until the tile is
        // manually re-configured.
        // Which tiles are pinned is read BEFORE the re-seat: only those may be expected present
        // afterwards (a tile the user dragged off must not be re-pinned by the retry).
        var pinnedIndices: [String: Int] = [:]
        for config in regeneratedConfigs {
            if let index = helperManager.findDockIndex(bundleId: config.bundleIdentifier) {
                pinnedIndices[config.bundleIdentifier] = index
            }
        }
        for config in regeneratedConfigs {
            helperManager.refreshDockEntry(for: config)
        }

        // Single verified Dock restart for the whole batch; a failure is logged inside.
        print("[Migration] Restarting Dock for \(regeneratedConfigs.count) updated helper(s)")
        let expectations = HelperBundleManager.batchExpectations(
            regeneratedConfigs.map { (bundleId: $0.bundleIdentifier, path: helperManager.helperPath(for: $0).path, name: $0.diagnosticName) },
            pinnedIndices: pinnedIndices)
        _ = await helperManager.restartDockAndVerify(expectations, ownedBundleIds: [])

        // Relaunch any regenerated helper that is not running (each swap already launched its own).
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

    /// Drives a regeneration batch with injected side effects, so the **stamp-on-success**
    /// invariant is unit-testable without touching real bundles or the Dock: each config is
    /// regenerated (which quits its old helper only after the new bundle is built — see
    /// `HelperBundleManager.runStagedRebuild`); a config is stamped (and reported regenerated) ONLY
    /// if `regenerate` returned without throwing. A failure is left unstamped so `migrateIfNeeded` retries it on a
    /// later launch (convergent migration) rather than permanently marking a broken helper
    /// "migrated". (MainActor-isolated via the enclosing class — the injected closures capture
    /// MainActor state.)
    static func runRegenerationBatch(
        _ configs: [DockTileConfiguration],
        regenerate: (DockTileConfiguration) async throws -> Void
    ) async -> BatchOutcome {
        var stamped: [UUID] = []
        var regenerated: [UUID] = []

        for config in configs {
            do {
                try await regenerate(config)
                regenerated.append(config.id)
                stamped.append(config.id)  // stamp ONLY on success
            } catch {
                // Left unstamped on purpose: the caller logs/records, and the tile stays stale so
                // a future launch retries it. No Dock restart happens for a failure (see caller).
            }
        }

        return BatchOutcome(stampedIds: stamped, regeneratedIds: regenerated)
    }

    // MARK: - Self-heal triage (pure seam)

    enum HelperHealth: Equatable {
        case healthy   // pinned bundle is present, complete, and current — or the tile isn't pinned
        case heal      // pinned bundle is missing / structurally corrupt / built by an older app
    }

    /// Pure rule for `selfHealIfNeeded`. Only a tile that is **pinned in the Dock** can be a repair
    /// target — an unpinned draft is `.healthy` no matter what's on disk, so self-heal can never
    /// force-pin a tile the user never Added. Guarded by `HelperSelfHealTests`.
    nonisolated static func classifyHelperHealth(
        isPinnedInDock: Bool,
        bundleExists: Bool,
        iconsComplete: Bool,
        bakedVersionMatchesCurrent: Bool,
        dockEntryIsCurrent: Bool
    ) -> HelperHealth {
        guard isPinnedInDock else { return .healthy }
        if !bundleExists { return .heal }
        if !iconsComplete { return .heal }
        if !bakedVersionMatchesCurrent { return .heal }
        // A healthy bundle whose Dock entry is stale (wrong path, unparseable, duplicated — the
        // shared `dockEntriesAreCurrent` predicate): the 2026-10-29 rename left exactly this, and a
        // bundle-only check called it healthy forever.
        if !dockEntryIsCurrent { return .heal }
        return .healthy
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
