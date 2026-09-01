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

/// Errors from `IconCompiler.compile`. Every case carries enough to debug from — a broken or
/// unvalidated `Assets.car` is never returned silently.
enum IconCompilerError: Error, Equatable {
    /// `compilerURL` does not point to an executable file.
    case compilerMissing
    /// The compiler subprocess exited non-zero; the associated value is its captured stderr.
    case compileFailed(String)
    /// The compiler exited zero but the result failed structural validation — no `Assets.car`,
    /// or a car with no `IconImageStack` rendition (the Apple `actool` silent-flattening class).
    case invalidOutput(String)
}

/// Invokes the vendored `docktile-actool` to compile an Icon Composer `.icon` document into an
/// `Assets.car`, then verifies the result actually contains layered icon renditions before
/// handing it back. Apple's own `actool` has shipped builds that silently flatten a layered icon
/// into a single non-layered image with no error anywhere — so a compile here is never trusted by
/// eyeball, only by checking `assetutil --info`.
enum IconCompiler {
    /// The bundled compiler inside the running app (main app only — Task 13 wires the build
    /// phase that copies it in; `nil` in helpers, which must never compile, and in any build
    /// from before that phase exists).
    static var bundledCompilerURL: URL? {
        Bundle.main.url(forResource: "docktile-actool", withExtension: nil)
    }

    /// Compiles `document` (an Icon Composer `.icon` directory) into `outputDir/Assets.car` using
    /// the compiler at `compilerURL`. Throws loudly on every failure mode — a missing compiler, a
    /// non-zero compile, or a structurally-invalid result — and never returns an unvalidated car.
    static func compile(document: URL, outputDir: URL, compilerURL: URL) throws -> URL {
        try DiagnosticsLog.shared.measure("compile tile car") {
            guard FileManager.default.isExecutableFile(atPath: compilerURL.path) else {
                throw IconCompilerError.compilerMissing
            }
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let appIconName = document.deletingPathExtension().lastPathComponent
            let process = Process()
            process.executableURL = compilerURL
            process.arguments = [
                document.path,
                "--compile", outputDir.path,
                "--app-icon", appIconName,
                "--output-partial-info-plist", outputDir.appendingPathComponent("partial.plist").path,
                "--platform", "macosx",
                "--target-device", "mac",
                "--minimum-deployment-target", "15.0"
            ]
            // stdout just echoes a partial-info-plist we don't need, so discard it — only stderr
            // needs draining. Read stderr to EOF BEFORE waitUntilExit: a child that fills a pipe
            // buffer while this thread blocks in waitUntilExit deadlocks it (this runs on the
            // main actor during tile creation).
            let stderrPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderrPipe
            try process.run()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw IconCompilerError.compileFailed(String(data: stderrData, encoding: .utf8) ?? "unknown compiler error")
            }

            let carURL = outputDir.appendingPathComponent("Assets.car")
            guard FileManager.default.fileExists(atPath: carURL.path) else {
                throw IconCompilerError.invalidOutput("compiler exited successfully but produced no Assets.car")
            }

            let info = Process()
            info.executableURL = URL(fileURLWithPath: "/usr/bin/assetutil")
            info.arguments = ["--info", carURL.path]
            let infoPipe = Pipe()
            info.standardOutput = infoPipe
            info.standardError = FileHandle.nullDevice
            try info.run()
            let infoData = infoPipe.fileHandleForReading.readDataToEndOfFile()
            info.waitUntilExit()

            guard validate(assetutilJSON: infoData) else {
                throw IconCompilerError.invalidOutput(
                    "assetutil --info reports no IconImageStack rendition — the compiler silently flattened the icon")
            }

            return carURL
        }
    }

    /// Pure classification of `assetutil --info <car>` JSON: valid only when it parses to a
    /// non-empty array containing at least one `IconImageStack` rendition. This is the guard
    /// against Apple's documented `actool` defect class where a build silently flattens a layered
    /// icon into a single image with no error anywhere. `assetutil` can preface its output with a
    /// stray non-JSON line, so parsing starts at the first `[`.
    nonisolated static func validate(assetutilJSON data: Data) -> Bool {
        guard let jsonStart = data.firstIndex(of: UInt8(ascii: "[")),
              let array = try? JSONSerialization.jsonObject(with: data[jsonStart...]) as? [[String: Any]]
        else { return false }
        return array.contains { ($0["AssetType"] as? String) == "IconImageStack" }
    }
}
