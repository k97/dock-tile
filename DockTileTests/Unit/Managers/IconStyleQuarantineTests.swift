//
//  IconStyleQuarantineTests.swift
//  DockTileTests
//
//  Guards `IconStyleManager.shouldRunDetection` — the availability gate that quarantines the
//  legacy icon-style detection lifecycle (KVO, distributed notification, wake/popover reconciles,
//  launch self-heal byte-compare) on the declarative pipeline, where macOS renders every
//  appearance itself and there is nothing to detect or swap.
//

import Testing
@testable import Dock_Tile

@Suite("Icon style detection quarantine gate")
struct IconStyleQuarantineTests {

    @Test("Declarative pipeline disables detection")
    func declarativeDisablesDetection() {
        #expect(IconStyleManager.shouldRunDetection(isDeclarative: true) == false)
    }

    @Test("Legacy (non-declarative) pipeline keeps detection running")
    func legacyKeepsDetectionRunning() {
        #expect(IconStyleManager.shouldRunDetection(isDeclarative: false) == true)
    }

    /// Guards the readability half of the interface contract — a named "Produces" bullet of the
    /// task that quarantined detection, and otherwise unguarded: nothing else asserts on
    /// `currentStyle` itself. Today it's correct only because `IconStyleManager.init` seeds it
    /// UNCONDITIONALLY, before `setupObservers()` consults the gate. This test exists so a future
    /// edit that reorders those two lines — moving the seed below the guard, or making it
    /// conditional — fails loudly here instead of silently breaking helper popovers' and the
    /// main-app preview's re-render trigger with no test catching it. Do not delete this as
    /// "redundant with the boolean gate tests above": it exercises the property, not the gate.
    @MainActor
    @Test("currentStyle is seeded from IconStyle.current regardless of the detection gate")
    func currentStyleStaysReadableUnderQuarantine() {
        #expect(IconStyleManager.shared.currentStyle == IconStyle.current)
    }
}
