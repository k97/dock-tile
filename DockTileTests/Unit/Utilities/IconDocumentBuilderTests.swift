//
//  IconDocumentBuilderTests.swift
//  DockTileTests
//
//  Regression guards for the pure `.icon` document author. Asserts against the exact schema of
//  docs/icon-spike-fixtures/devtile-fix.icon/icon.json — the proven-working fixture that is the
//  only ground truth for this undocumented format.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("IconDocumentBuilder JSON shape")
struct IconDocumentBuilderTests {
    private func makeJSON(layers: [IconDocumentBuilder.LayerSpec]) -> [String: Any] {
        IconDocumentBuilder.iconJSON(
            fillTopP3: (0.41961, 0.81176, 0.49804), fillBottomP3: (0.20392, 0.78039, 0.34902),
            darkFillTopP3: (0.10980, 0.10980, 0.11765), darkFillBottomP3: (0.05490, 0.05490, 0.06275),
            tintedFillTopP3: (0.55686, 0.55686, 0.57647), tintedFillBottomP3: (0.42353, 0.42353, 0.43922),
            layers: layers)
    }

    @Test("Top-level fill AND a no-appearance first entry in fill-specializations (defect-1 workaround)")
    func defaultFillIsDuplicatedIntoSpecializations() throws {
        let json = makeJSON(layers: [])
        let fill = try #require(json["fill"] as? [String: Any])
        let stops = try #require(fill["linear-gradient"] as? [String])
        #expect(stops == ["display-p3:0.41961,0.81176,0.49804,1.00000",
                          "display-p3:0.20392,0.78039,0.34902,1.00000"])
        let specs = try #require(json["fill-specializations"] as? [[String: Any]])
        #expect(specs.count == 3)                       // fixture parity: default, dark, tinted
        #expect(specs[0]["appearance"] == nil)          // the default IN the list, first
        #expect(specs[1]["appearance"] as? String == "dark")
        #expect(specs[2]["appearance"] as? String == "tinted")
    }

    @Test("Symbol model: light layer hidden for dark; dark layer default-hidden, shown for dark")
    func symbolLayersSwapByHiddenSpecializations() throws {
        let json = makeJSON(layers: [
            .init(name: "glyph-light", imageName: "glyph-light.png", exclusiveTo: .light),
            .init(name: "glyph-dark",  imageName: "glyph-dark.png",  exclusiveTo: .dark)])
        let groups = try #require(json["groups"] as? [[String: Any]])
        let layers = try #require(groups[0]["layers"] as? [[String: Any]])
        let lightHidden = try #require(layers[0]["hidden-specializations"] as? [[String: Any]])
        #expect(lightHidden[0]["appearance"] == nil && lightHidden[0]["value"] as? Bool == false)
        #expect(lightHidden[1]["appearance"] as? String == "dark" && lightHidden[1]["value"] as? Bool == true)
        let darkHidden = try #require(layers[1]["hidden-specializations"] as? [[String: Any]])
        #expect(darkHidden[0]["value"] as? Bool == true)
        #expect(darkHidden[1]["appearance"] as? String == "dark" && darkHidden[1]["value"] as? Bool == false)
    }

    @Test("Emoji model: single always-visible layer, NO hidden-specializations")
    func emojiSingleLayerHasNoSpecializations() throws {
        let json = makeJSON(layers: [.init(name: "glyph-emoji", imageName: "glyph-emoji.png", exclusiveTo: nil)])
        let layers = try #require((json["groups"] as? [[String: Any]])?[0]["layers"] as? [[String: Any]])
        #expect(layers[0]["hidden-specializations"] == nil)
        #expect(layers[0]["fill"] as? String == "none")
    }

    @Test("Platforms + layer position match the proven fixture")
    func fixtureInvariants() throws {
        let json = makeJSON(layers: [.init(name: "glyph-light", imageName: "glyph-light.png", exclusiveTo: .light)])
        let platforms = try #require(json["supported-platforms"] as? [String: [String]])
        #expect(platforms["squares"] == ["macOS"])
        let layer = try #require((json["groups"] as? [[String: Any]])?[0]["layers"] as? [[String: Any]])?[0]
        let position = try #require(layer?["position"] as? [String: Any])
        #expect(position["scale"] as? Double == 1.0)
    }

    @Test("writeDocument lays out icon.json + Assets/")
    func writeDocumentLayout() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try IconDocumentBuilder.writeDocument(
            json: makeJSON(layers: []), layerPNGs: ["glyph-light.png": Data([1, 2, 3])],
            name: "tile", parent: dir)
        #expect(url.lastPathComponent == "tile.icon")
        #expect(FileManager.default.fileExists(atPath: url.appendingPathComponent("icon.json").path))
        #expect(try Data(contentsOf: url.appendingPathComponent("Assets/glyph-light.png")) == Data([1, 2, 3]))
    }
}
