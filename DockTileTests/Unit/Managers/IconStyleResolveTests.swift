//
//  IconStyleResolveTests.swift
//  DockTileTests
//
//  Guards the `IconStyle.resolve(preferencesValue:isDarkMode:)` seam — the *strict* mapping that
//  answers `nil` for an UNRECOGNISED `AppleIconAppearanceTheme` string instead of claiming
//  `.defaultStyle`.
//
//  Why it matters: the helper's style watchers compare the freshly read style against the cached
//  one and treat any difference as a real change (analytics event + icon rewrite on disk). With
//  the old lossy fallback, ONE anomalous read cost two style transitions (out and back) and two
//  icon rewrites — the shape seen in production telemetry (548 changes in a day against a
//  baseline of 1–2). An unknown value must mean "unresolved, do not act", NOT "Default".
//
//  The distinction that carries the fix: a genuinely ABSENT key (nil) is documented, legitimate
//  "Default" and must keep resolving to `.defaultStyle`; only an unrecognised *string* is nil.
//

import Testing
@testable import Dock_Tile

@Suite("IconStyle.resolve strict mapping")
struct IconStyleResolveTests {

    // MARK: - The defect: an unrecognised string must not read as a real style

    @Test("An unrecognised value is unresolved (nil), not .defaultStyle", arguments: [true, false])
    func unrecognisedValueIsUnresolved(_ isDarkMode: Bool) {
        #expect(IconStyle.resolve(preferencesValue: "SomeFutureStyle", isDarkMode: isDarkMode) == nil)
    }

    @Test("Other anomalous strings are unresolved too", arguments: [
        "", "RegularAutomatic ", "regularautomatic", "Regular", "GlassAutomatic"
    ])
    func anomalousStringsAreUnresolved(_ value: String) {
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: true) == nil)
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: false) == nil)
    }

    // MARK: - The distinction: absent key is a REAL answer, not an unresolved one

    @Test("nil (key genuinely unset) resolves to .defaultStyle, never nil")
    func absentKeyIsDefaultStyle() {
        #expect(IconStyle.resolve(preferencesValue: nil, isDarkMode: true) == .defaultStyle)
        #expect(IconStyle.resolve(preferencesValue: nil, isDarkMode: false) == .defaultStyle)
    }

    // MARK: - Every previously recognised value keeps its exact mapping

    @Test("Automatic family still follows the system appearance", arguments: ["RegularAutomatic", "Automatic"])
    func automaticFamilyFollowsAppearance(_ value: String) {
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: true) == .dark)
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: false) == .defaultStyle)
    }

    @Test("Explicit styles resolve identically to the lossy seam", arguments: [
        ("RegularDark", IconStyle.dark),
        ("Dark", IconStyle.dark),
        ("RegularLight", IconStyle.defaultStyle),
        ("Light", IconStyle.defaultStyle),
        ("ClearAutomatic", IconStyle.clear),
        ("Clear", IconStyle.clear),
        ("RegularClear", IconStyle.clear),
        ("TintedAutomatic", IconStyle.tinted),
        ("Tinted", IconStyle.tinted),
        ("RegularTinted", IconStyle.tinted)
    ])
    func recognisedValuesAreAppearanceIndependent(_ value: String, _ expected: IconStyle) {
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: true) == expected)
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: false) == expected)
    }

    // MARK: - The values macOS 26 actually writes

    /// Captured on macOS 26.6.2 (2026-08-31) by clicking through System Settings → Appearance →
    /// Icon and widget style with a probe reading the key back live. Apple publishes no list, so
    /// this measurement is the only authority we have — see
    /// docs/macos-appearance-detection-research.md §F1.
    ///
    /// History worth keeping: "ClearLight"/"ClearDark"/"TintedDark" were first added as guesses,
    /// then REMOVED when an initial capture (the `*Automatic` options only) didn't show them, then
    /// restored the same day when a fuller click-through proved macOS really writes them — three
    /// live selections were silently ignored in between. Lesson: an absent observation is not an
    /// observation of absence. "TintedLight" remains unobserved and is mapped by symmetry.
    @Test("Every value macOS 26 was observed to write resolves as expected", arguments: [
        ("RegularAutomatic", IconStyle.dark),      // Automatic + Dark appearance
        ("ClearAutomatic", IconStyle.clear),
        ("TintedAutomatic", IconStyle.tinted),
        ("RegularDark", IconStyle.dark),
        ("ClearLight", IconStyle.clear),           // observed 20:09:05
        ("ClearDark", IconStyle.clear),            // observed 20:09:24
        ("TintedDark", IconStyle.tinted),          // observed 20:09:25
        ("TintedLight", IconStyle.tinted)          // unobserved; symmetry with the above
    ])
    func observedValuesResolve(_ value: String, _ expected: IconStyle) {
        #expect(IconStyle.resolve(preferencesValue: value, isDarkMode: true) == expected)
    }

    @Test("Selecting Default removes the key entirely, which must resolve to Default")
    func observedAbsentIsDefault() {
        // Verified: choosing Default deletes AppleIconAppearanceTheme rather than writing a value.
        #expect(IconStyle.resolve(preferencesValue: nil, isDarkMode: true) == .defaultStyle)
        #expect(IconStyle.resolve(preferencesValue: nil, isDarkMode: false) == .defaultStyle)
    }

    // MARK: - Back-compat: the seeded variant is unchanged

    @Test("from(...) still seeds .defaultStyle for an unrecognised string", arguments: [true, false])
    func fromStillFallsBackToDefault(_ isDarkMode: Bool) {
        #expect(IconStyle.from(preferencesValue: "SomeFutureStyle", isDarkMode: isDarkMode) == .defaultStyle)
    }

    @Test("from(...) mirrors resolve(...) for every recognised value", arguments: [
        "RegularAutomatic", "Automatic", "RegularDark", "Dark", "RegularLight", "Light",
        "ClearAutomatic", "Clear", "RegularClear", "ClearLight", "ClearDark",
        "TintedAutomatic", "Tinted", "RegularTinted", "TintedLight", "TintedDark"
    ])
    func fromMirrorsResolveWhenRecognised(_ value: String) {
        for isDarkMode in [true, false] {
            let resolved = IconStyle.resolve(preferencesValue: value, isDarkMode: isDarkMode)
            #expect(IconStyle.from(preferencesValue: value, isDarkMode: isDarkMode) == resolved)
        }
    }
}
