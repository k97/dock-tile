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

    // NOTE on the `currentStyle` readability contract (a named "Produces" bullet of the task
    // that quarantined detection): there is deliberately NO runtime test for it here.
    //
    // A prior version of this suite asserted `IconStyleManager.shared.currentStyle ==
    // IconStyle.current` right after construction. That does not discriminate the regression it
    // was meant to catch: `currentStyle`'s declared property default was `.defaultStyle`, and
    // `IconStyle.current` also resolves to `.defaultStyle` whenever `AppleIconAppearanceTheme` is
    // unset (the common case, and this machine's actual state) — so if the seed were ever moved
    // below `setupObservers()`'s guard (or deleted), both sides of that comparison would still
    // collapse to the same default and the test would pass straight through the break. Writing a
    // discriminating version would require the system icon style to already be non-Default, which
    // this suite must not force: AppleIconAppearanceTheme is a real, global, user-facing setting,
    // and the production Dock Tile helpers running on this machine react to it by rewriting and
    // re-signing their own bundles.
    //
    // Instead the guarantee is now STRUCTURAL: `IconStyleManager.currentStyle` has no declared
    // default (see its doc comment), so Swift's two-phase initialization requires it to be
    // assigned before `init()` may call any instance method — including `setupObservers()`, which
    // is where the detection guard lives. Reordering the seed below the guard, or deleting it, is
    // therefore a BUILD FAILURE, not a runtime regression a test could miss. No test is kept for
    // this because none would add anything the compiler doesn't already guarantee.
}
