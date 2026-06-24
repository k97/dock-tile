//
//  IconStyleTests.swift
//  DockTileTests
//
//  Guards the AppleIconAppearanceTheme → IconStyle mapping, especially the Tahoe-default
//  "RegularAutomatic" case that MUST follow the system appearance (dark icons in Dark mode).
//  This mapping was previously untested because it read CFPreferences directly; the
//  `from(preferencesValue:isDarkMode:)` seam injects the appearance so it is pure & testable.
//

import Testing
@testable import Dock_Tile

@Suite("IconStyle.from mapping")
struct IconStyleMappingTests {

    // MARK: - The regression-prone Automatic case

    @Test("RegularAutomatic resolves to .dark in Dark mode")
    func regularAutomaticDark() {
        #expect(IconStyle.from(preferencesValue: "RegularAutomatic", isDarkMode: true) == .dark)
    }

    @Test("RegularAutomatic resolves to .defaultStyle in Light mode")
    func regularAutomaticLight() {
        #expect(IconStyle.from(preferencesValue: "RegularAutomatic", isDarkMode: false) == .defaultStyle)
    }

    @Test("Bare 'Automatic' alias also follows appearance")
    func automaticAliasFollowsAppearance() {
        #expect(IconStyle.from(preferencesValue: "Automatic", isDarkMode: true) == .dark)
        #expect(IconStyle.from(preferencesValue: "Automatic", isDarkMode: false) == .defaultStyle)
    }

    // MARK: - Explicit (appearance-independent) styles

    @Test("Explicit styles ignore the system appearance", arguments: [
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
    func explicitStylesAreAppearanceIndependent(_ value: String, _ expected: IconStyle) {
        // Same result regardless of dark mode — only the Automatic family flips.
        #expect(IconStyle.from(preferencesValue: value, isDarkMode: true) == expected)
        #expect(IconStyle.from(preferencesValue: value, isDarkMode: false) == expected)
    }

    // MARK: - Defaults / unknowns

    @Test("nil (key unset) is the colourful default")
    func nilIsDefault() {
        #expect(IconStyle.from(preferencesValue: nil, isDarkMode: true) == .defaultStyle)
        #expect(IconStyle.from(preferencesValue: nil, isDarkMode: false) == .defaultStyle)
    }

    @Test("Unknown values fall back to .defaultStyle (forward-compatible)")
    func unknownFallsBackToDefault() {
        #expect(IconStyle.from(preferencesValue: "SomeFutureStyle", isDarkMode: true) == .defaultStyle)
    }
}
