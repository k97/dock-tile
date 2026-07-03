//
//  HelperMigrationTriageTests.swift
//  DockTileTests
//
//  Guards the helper-migration triage rules. A wrong guard here regresses into either
//  regeneration thrash (rebuilding on every launch) or rebuilding helpers that don't exist.
//  Exercises the pure `HelperMigrationManager.classifyForMigration(...)` seam.
//

import Testing
@testable import Dock_Tile

@Suite("Helper migration triage")
struct HelperMigrationTriageTests {

    private typealias Action = HelperMigrationManager.MigrationAction

    private func classify(
        visible: Bool,
        version: String?,
        current: String = "1.4.1",
        onDisk: Bool,
        inDock: Bool
    ) -> Action {
        HelperMigrationManager.classifyForMigration(
            isVisibleInDock: visible,
            helperAppVersion: version,
            currentVersion: current,
            helperExistsOnDisk: onDisk,
            isInDock: inDock
        )
    }

    @Test("Invisible tile is stamp-only (never regenerated), regardless of disk/Dock/version")
    func invisibleIsStampOnly() {
        #expect(classify(visible: false, version: nil, onDisk: true, inDock: true) == .stampOnly)
        #expect(classify(visible: false, version: "0.9", onDisk: true, inDock: true) == .stampOnly)
        // Even an already-current invisible tile takes the stamp path (idempotent, visibility wins).
        #expect(classify(visible: false, version: "1.4.1", onDisk: false, inDock: false) == .stampOnly)
    }

    @Test("Visible + already current → skip (no regeneration thrash)")
    func currentVisibleSkips() {
        #expect(classify(visible: true, version: "1.4.1", onDisk: true, inDock: true) == .skipUpToDate)
    }

    @Test("Visible + stale + no bundle on disk → stamp only (don't rebuild a missing bundle)")
    func staleNoBundleStamps() {
        #expect(classify(visible: true, version: "1.0", onDisk: false, inDock: true) == .stampOnly)
    }

    @Test("Visible + stale + on disk + dragged out of Dock → stamp only")
    func staleNotInDockStamps() {
        #expect(classify(visible: true, version: "1.0", onDisk: true, inDock: false) == .stampOnly)
    }

    @Test("Visible + stale + on disk + in Dock → regenerate")
    func staleInDockRegenerates() {
        #expect(classify(visible: true, version: "1.0", onDisk: true, inDock: true) == .regenerate)
    }

    /// A pre-migration helper (helperAppVersion == nil) that is visible, present and pinned is
    /// the canonical "needs regeneration" case.
    @Test("Pre-migration (nil version) visible+present+pinned → regenerate")
    func nilVersionRegenerates() {
        #expect(classify(visible: true, version: nil, onDisk: true, inDock: true) == .regenerate)
    }
}

// MARK: - Stamp-on-success invariant (convergent migration)

private enum BatchTestError: Error { case boom }

@Suite("Helper migration batch (stamp-on-success)")
@MainActor
struct HelperMigrationBatchTests {

    /// THE convergence invariant: a config that FAILS to regenerate must NOT be stamped, so the
    /// next launch retries it (a transient failure — killed mid-generation, a momentary FS error —
    /// heals instead of being permanently marked "migrated" while broken). Only successes are
    /// stamped AND reported as regenerated (so only they get relaunched + trigger the Dock restart).
    @Test("A failed config is left unstamped and unreported; the successful one is stamped")
    func stampsOnSuccessOnly() async {
        let ok = DockTileConfiguration(name: "ok-tile")
        let bad = DockTileConfiguration(name: "bad-tile")
        var quitOrder: [String] = []

        let outcome = await HelperMigrationManager.runRegenerationBatch(
            [ok, bad],
            quit: { quitOrder.append($0) },
            regenerate: { config in
                if config.name == "bad-tile" { throw BatchTestError.boom }
            }
        )

        // Only the success is stamped — the failure stays stale so it retries next launch.
        #expect(outcome.stampedIds == [ok.id])
        #expect(outcome.regeneratedIds == [ok.id])
        // Both were still quit before their (attempted) regeneration.
        #expect(Set(quitOrder) == Set([ok.bundleIdentifier, bad.bundleIdentifier]))
    }

    @Test("All-success batch stamps and regenerates every config")
    func allSucceed() async {
        let a = DockTileConfiguration(name: "a")
        let b = DockTileConfiguration(name: "b")

        let outcome = await HelperMigrationManager.runRegenerationBatch(
            [a, b], quit: { _ in }, regenerate: { _ in })

        #expect(outcome.stampedIds == [a.id, b.id])
        #expect(outcome.regeneratedIds == [a.id, b.id])
    }

    @Test("All-failure batch stamps and regenerates nothing (everything retries next launch)")
    func allFail() async {
        let a = DockTileConfiguration(name: "a")
        let b = DockTileConfiguration(name: "b")

        let outcome = await HelperMigrationManager.runRegenerationBatch(
            [a, b], quit: { _ in }, regenerate: { _ in throw BatchTestError.boom })

        #expect(outcome.stampedIds.isEmpty)
        #expect(outcome.regeneratedIds.isEmpty)
    }
}
