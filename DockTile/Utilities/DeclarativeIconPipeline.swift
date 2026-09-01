//
//  DeclarativeIconPipeline.swift
//  DockTile
//
//  The declarative icon pipeline's availability seam plus the pure author of an Icon Composer
//  `.icon` document (icon.json + layer PNGs) from a tile's resolved identity. See
//  docs/icon-spike-fixtures/devtile-fix.icon/icon.json — the proven fixture this JSON schema
//  mirrors exactly (undocumented format; do not invent or "improve" keys).
//

import Foundation

/// THE one availability branch for the declarative icon pipeline. Consulted at exactly three
/// activation points: helper bundle generation, `IconStyleManager` activation, and
/// migration/self-heal probes.
enum IconPipeline {
    static var isDeclarative: Bool {
        if #available(macOS 26.0, *) { return true } else { return false }
    }
}

/// The three appearances an Icon Composer `.icon` document can author. `clear` is NOT
/// authorable — macOS derives it from `tinted`.
enum IconAppearance: String {
    case light, dark, tinted
}

/// Pure author of an Icon Composer `.icon` document from a tile's resolved fill colours and
/// glyph layers. No filesystem/network access beyond `writeDocument`'s final write.
enum IconDocumentBuilder {

    /// One glyph layer in the document's single group.
    struct LayerSpec {
        let name: String
        let imageName: String
        /// `nil` = visible in every appearance (the emoji single-layer model); otherwise the
        /// ONE appearance this layer is exclusive to (a `.light` layer hides for dark; a
        /// `.dark` layer starts hidden and shows for dark). Tinted reuses the light layer, so
        /// it is never consulted here.
        let exclusiveTo: IconAppearance?
    }

    /// Builds the `icon.json` dictionary. The default fill value is duplicated as the first,
    /// no-appearance entry in `fill-specializations` (fixture parity — also works around a
    /// defect in the vendored compiler; harmless for Apple's).
    nonisolated static func iconJSON(
        fillTopP3: (r: Double, g: Double, b: Double),
        fillBottomP3: (r: Double, g: Double, b: Double),
        darkFillTopP3: (r: Double, g: Double, b: Double),
        darkFillBottomP3: (r: Double, g: Double, b: Double),
        tintedFillTopP3: (r: Double, g: Double, b: Double),
        tintedFillBottomP3: (r: Double, g: Double, b: Double),
        layers: [LayerSpec]
    ) -> [String: Any] {
        let defaultFill = gradientValue(top: fillTopP3, bottom: fillBottomP3)
        let fillSpecializations: [[String: Any]] = [
            ["value": defaultFill],
            [
                "appearance": IconAppearance.dark.rawValue,
                "value": gradientValue(top: darkFillTopP3, bottom: darkFillBottomP3)
            ],
            [
                "appearance": IconAppearance.tinted.rawValue,
                "value": gradientValue(top: tintedFillTopP3, bottom: tintedFillBottomP3)
            ]
        ]
        return [
            "fill": defaultFill,
            "fill-specializations": fillSpecializations,
            "groups": [["layers": layers.map(layerDict)]],
            "supported-platforms": ["circles": [], "squares": ["macOS"]]
        ]
    }

    /// Writes `icon.json` + `Assets/<imageName>.png` into a new `<name>.icon` directory under
    /// `parent`. Returns the created `.icon` directory's URL.
    nonisolated static func writeDocument(
        json: [String: Any], layerPNGs: [String: Data], name: String, parent: URL
    ) throws -> URL {
        let iconDir = parent.appendingPathComponent("\(name).icon")
        let assetsDir = iconDir.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: iconDir.appendingPathComponent("icon.json"))

        for (fileName, pngData) in layerPNGs {
            try pngData.write(to: assetsDir.appendingPathComponent(fileName))
        }
        return iconDir
    }

    // MARK: - Private

    private static func layerDict(_ layer: LayerSpec) -> [String: Any] {
        var dict: [String: Any] = [
            "name": layer.name,
            "image-name": layer.imageName,
            "fill": "none",
            "position": [
                "scale": 1.0,
                "translation-in-points": [0, 0]
            ]
        ]
        if let exclusiveTo = layer.exclusiveTo {
            dict["hidden-specializations"] = [
                ["value": exclusiveTo != .light],
                ["appearance": IconAppearance.dark.rawValue, "value": exclusiveTo != .dark]
            ]
        }
        return dict
    }

    private static func gradientValue(
        top: (r: Double, g: Double, b: Double), bottom: (r: Double, g: Double, b: Double)
    ) -> [String: Any] {
        [
            "linear-gradient": [p3String(top), p3String(bottom)],
            "orientation": [
                "start": ["x": 0.5, "y": 0],
                "stop": ["x": 0.5, "y": 1]
            ]
        ]
    }

    private static func p3String(_ c: (r: Double, g: Double, b: Double)) -> String {
        String(format: "display-p3:%.5f,%.5f,%.5f,1.00000", c.r, c.g, c.b)
    }
}
