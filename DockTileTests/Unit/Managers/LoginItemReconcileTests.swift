//
//  LoginItemReconcileTests.swift
//  DockTileTests
//
//  Guards the start-at-login reconcile decision — specifically the Sparkle-update regression
//  where replacing the app bundle demotes the SMAppService agent and the toggle appeared to
//  silently turn itself off. Exercises the pure `shouldReregisterOnLaunch` seam.
//

import Testing
import ServiceManagement
@testable import Dock_Tile

@Suite("Start-at-login reconcile decision")
struct LoginItemReconcileTests {

    /// A genuine opt-out must be honoured for EVERY system status — the agent never re-registers
    /// itself behind the user's back.
    @Test("Opted out → never re-register", arguments: [
        SMAppService.Status.enabled,
        .requiresApproval,
        .notRegistered,
        .notFound
    ])
    func optedOutNeverReregisters(_ status: SMAppService.Status) {
        #expect(LoginItemManager.shouldReregisterOnLaunch(userOptedOut: true, status: status) == false)
    }

    @Test("Not opted out + already enabled → no-op (don't re-register)")
    func enabledIsNoop() {
        #expect(LoginItemManager.shouldReregisterOnLaunch(userOptedOut: false, status: .enabled) == false)
    }

    /// The core Sparkle fix: a demoted agent (requiresApproval / notRegistered / notFound) plus
    /// no opt-out MUST re-register, otherwise start-at-login silently dies after an update.
    @Test("Not opted out + demoted status → re-register", arguments: [
        SMAppService.Status.requiresApproval,
        .notRegistered,
        .notFound
    ])
    func demotedStatusReregisters(_ status: SMAppService.Status) {
        #expect(LoginItemManager.shouldReregisterOnLaunch(userOptedOut: false, status: status) == true)
    }
}
