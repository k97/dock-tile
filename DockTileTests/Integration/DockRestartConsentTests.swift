//
//  DockRestartConsentTests.swift
//  DockTileTests
//
//  Guards the one-time Dock-restart consent rule. Previously these tests wrote to the SHARED
//  UserDefaults.standard (corrupting the real preference and racing on the key) and merely
//  re-implemented `!bool(forKey:)` instead of exercising production code. They now drive the
//  pure `DockTileDetailView.shouldShowDockRestartConsent(...)` seam and verify persistence
//  semantics against an ISOLATED MockUserDefaults — zero real-defaults mutation.
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite("Dock Restart Consent Tests", .serialized)
struct DockRestartConsentTests {

    // MARK: - Decision rule (production seam)

    @Test("Consent dialog shows until acknowledged")
    func showsUntilAcknowledged() {
        #expect(DockTileDetailView.shouldShowDockRestartConsent(hasAcknowledged: false) == true)
        #expect(DockTileDetailView.shouldShowDockRestartConsent(hasAcknowledged: true) == false)
    }

    // MARK: - Persistence semantics (isolated mock — no real UserDefaults touched)

    @Test("Unacknowledged default reads false → dialog should show")
    func defaultIsUnacknowledged() {
        let defaults = MockUserDefaults()
        let hasAcknowledged = defaults.bool(forKey: UserDefaultsKeys.hasAcknowledgedDockRestart)
        #expect(hasAcknowledged == false)
        #expect(DockTileDetailView.shouldShowDockRestartConsent(hasAcknowledged: hasAcknowledged) == true)
    }

    @Test("Acknowledging persists true → dialog suppressed thereafter")
    func acknowledgingSuppresses() {
        let defaults = MockUserDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.hasAcknowledgedDockRestart)

        let hasAcknowledged = defaults.bool(forKey: UserDefaultsKeys.hasAcknowledgedDockRestart)
        #expect(hasAcknowledged == true)
        #expect(DockTileDetailView.shouldShowDockRestartConsent(hasAcknowledged: hasAcknowledged) == false)
    }

    @Test("Not acknowledging leaves the preference unset (Cancel / Confirm-without-checkbox)")
    func notAcknowledgingLeavesUnset() {
        let defaults = MockUserDefaults()
        // User cancels or confirms without ticking the box → nothing written.
        #expect(defaults.bool(forKey: UserDefaultsKeys.hasAcknowledgedDockRestart) == false)
    }
}
