import Testing
import Foundation
import SwiftUI
import AppKit
@testable import Dock_Tile

/// Guards the v7 `iconWeight` field: the curated weight set, its SwiftUI/AppKit mappings, and
/// backward-compatible decoding. The mapping is the regression-prone seam — the live preview
/// (`Font.Weight`) and the baked `.icns` (`NSFont.Weight`) must agree, or a tile would look one
/// way in the customiser and another in the Dock.
@Suite("IconWeight Tests")
struct IconWeightTests {

    /// The curated set is exactly six weights, light→heavy, dropping the extremes. Order matters:
    /// it's the order the picker renders. A silent reorder/add/remove would change the UI.
    @Test("Curated weight set is exactly the six expected cases in order")
    func curatedSetExact() {
        #expect(IconWeight.allCases == [.light, .regular, .medium, .semibold, .bold, .heavy])
    }

    /// Each weight maps to its matching SwiftUI `Font.Weight` (used by the preview + picker grid).
    @Test("fontWeight maps each case to the matching SwiftUI Font.Weight", arguments: [
        (IconWeight.light, Font.Weight.light),
        (IconWeight.regular, Font.Weight.regular),
        (IconWeight.medium, Font.Weight.medium),
        (IconWeight.semibold, Font.Weight.semibold),
        (IconWeight.bold, Font.Weight.bold),
        (IconWeight.heavy, Font.Weight.heavy),
    ])
    func fontWeightMapping(_ weight: IconWeight, _ expected: Font.Weight) {
        #expect(weight.fontWeight == expected)
    }

    /// Each weight maps to its matching AppKit `NSFont.Weight` (used by the baked `.icns`).
    @Test("nsFontWeight maps each case to the matching NSFont.Weight", arguments: [
        (IconWeight.light, NSFont.Weight.light),
        (IconWeight.regular, NSFont.Weight.regular),
        (IconWeight.medium, NSFont.Weight.medium),
        (IconWeight.semibold, NSFont.Weight.semibold),
        (IconWeight.bold, NSFont.Weight.bold),
        (IconWeight.heavy, NSFont.Weight.heavy),
    ])
    func nsFontWeightMapping(_ weight: IconWeight, _ expected: NSFont.Weight) {
        #expect(weight.nsFontWeight == expected)
    }

    /// The default weight is `.medium` — both the schema default and the decode fallback rely on
    /// this. Changing it silently restyles every existing tile and every new one.
    @Test("Default weight is medium")
    func defaultIsMedium() {
        #expect(ConfigurationDefaults.iconWeight == .medium)
        #expect(DockTileConfiguration(name: "Default").iconWeight == .medium)
    }

    /// A pre-v7 config has no `iconWeight` key; decode MUST fall back to `.medium` rather than
    /// throw. This is the backward-compatibility contract every tile on disk depends on.
    @Test("Pre-v7 JSON without iconWeight defaults to medium")
    func legacyJSONDefaultsToMedium() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Pre-v7 Tile",
            "tintColor": {"type": "preset", "value": "blue"},
            "symbolEmoji": "star",
            "layoutMode": "grid",
            "appItems": [],
            "isVisibleInDock": true,
            "bundleIdentifier": "com.prev7.tile",
            "iconType": "sfSymbol",
            "iconValue": "folder.fill",
            "iconScale": 14
        }
        """

        let config = try JSONDecoder().decode(DockTileConfiguration.self, from: json.data(using: .utf8)!)
        #expect(config.iconWeight == .medium)
    }

    /// When present, `iconWeight` is read verbatim, and a full round-trip preserves it exactly.
    @Test("iconWeight is decoded when present and survives a round-trip")
    func decodedAndRoundTripped() throws {
        let original = DockTileConfiguration(
            name: "Weighted",
            iconType: .sfSymbol,
            iconValue: "bolt.fill",
            iconWeight: .bold
        )

        let decoded = try JSONDecoder().decode(
            DockTileConfiguration.self,
            from: try JSONEncoder().encode(original)
        )
        #expect(decoded.iconWeight == .bold)
    }
}
