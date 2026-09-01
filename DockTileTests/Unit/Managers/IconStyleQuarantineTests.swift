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
}
