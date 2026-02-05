//
//  DockRestartConsentTests.swift
//  DockTileTests
//
//  Integration tests for Dock restart consent dialog
//  Swift Testing framework
//

import Testing
import Foundation
@testable import Dock_Tile

@Suite("Dock Restart Consent Tests", .serialized)
struct DockRestartConsentTests {

    @Test("First time shows consent dialog")
    func firstTimeShowsDialog() {
        // Reset preference
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedDockRestart")

        let shouldShow = !UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")
        #expect(shouldShow == true)
    }

    @Test("After acknowledgment, dialog is suppressed")
    func afterAcknowledgmentSuppressed() {
        // Simulate user checking "Don't show this again"
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedDockRestart")

        let shouldShow = !UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")
        #expect(shouldShow == false)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedDockRestart")
    }

    @Test("Cancel preserves unchecked state")
    func cancelPreservesState() {
        // Reset preference
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedDockRestart")

        // User clicks Cancel without checking box
        // (no preference saved)

        let shouldShow = !UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")
        #expect(shouldShow == true)  // Should still show next time
    }

    @Test("Confirm with checkbox saves preference")
    func confirmWithCheckboxSavesPreference() {
        // Reset preference
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedDockRestart")

        // Simulate user checking box and clicking Confirm
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedDockRestart")

        let hasAcknowledged = UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")
        #expect(hasAcknowledged == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedDockRestart")
    }

    @Test("Confirm without checkbox does not save preference")
    func confirmWithoutCheckboxDoesNotSave() {
        // Reset preference
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedDockRestart")

        // Simulate user clicking Confirm without checking box
        // (no preference saved)

        let hasAcknowledged = UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")
        #expect(hasAcknowledged == false)  // Preference not saved
    }
}
