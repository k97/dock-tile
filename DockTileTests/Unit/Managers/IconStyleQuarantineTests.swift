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

    // MARK: - refreshRawStyle's pure decision: adopt only when the token actually differs

    // `IconStyleManager.refreshRawStyle()` (wired to didBecomeActiveNotification, main app only)
    // re-reads AppleIconAppearanceTheme and must publish `rawStyle` ONLY when the freshly read
    // token differs from the current one — an unconditional assignment on every activation would
    // fire spurious `objectWillChange` on every foreground, even when nothing changed. This is the
    // pure decision that guards it.
    @Test("shouldAdopt: differing tokens adopt")
    func differingTokensAdopt() {
        #expect(IconStyleManager.shouldAdopt(newToken: .value("RegularDark"), current: .absent))
        #expect(IconStyleManager.shouldAdopt(newToken: .absent, current: .value("RegularDark")))
        #expect(IconStyleManager.shouldAdopt(newToken: .value("RegularDark"), current: .value("ClearAutomatic")))
        #expect(IconStyleManager.shouldAdopt(newToken: .unreadable, current: .absent))
    }

    @Test("shouldAdopt: an equal token never adopts")
    func equalTokenNeverAdopts() {
        #expect(!IconStyleManager.shouldAdopt(newToken: .absent, current: .absent))
        #expect(!IconStyleManager.shouldAdopt(newToken: .value("RegularDark"), current: .value("RegularDark")))
        #expect(!IconStyleManager.shouldAdopt(newToken: .unreadable, current: .unreadable))
    }

    // NOTE on `refreshRawStyle()`'s notification wiring: there is deliberately NO unit test for
    // "posting didBecomeActiveNotification actually refreshes IconStyleManager.shared.rawStyle".
    // Any such test would compare `manager.rawStyle` against `IconStyleManager.token(from:
    // IconStyle.rawPreferencesObject)` read fresh in the test — but that is the SAME live key
    // `refreshRawStyle()` itself reads, so a broken wiring (the notification never registered, or
    // registered but never calling refreshRawStyle) would leave the init-seeded `rawStyle` at
    // whatever the live key already read at launch — which is what the "after" comparison would
    // also compute. The test could not tell "refresh ran and read the live value" apart from
    // "refresh never ran, but the init seed already matches the live value" without independently
    // mutating AppleIconAppearanceTheme, which this suite must not do: it is a real, global,
    // user-facing setting, and this machine's production Dock Tile helpers run PRE-QUARANTINE
    // binaries (built before `shouldRunDetection` existed) that react to it by rewriting and
    // re-signing their own bundles — this branch's own quarantined code would ignore the key, but
    // the machine it runs on is not running this branch's code everywhere. The `shouldAdopt` tests
    // above cover the seam's actual decision logic exactly; the wiring itself (does
    // configureAsMainApp really register `didBecomeActiveNotification` → `refreshRawStyle()`) is
    // covered by the plan's Task 5 manual verification, not a unit test — a documented gap beats a
    // decorative green check, per `.claude/rules/testing.md` "A guard must be able to fail".

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
