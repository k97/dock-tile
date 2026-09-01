//
//  IconCompilerTests.swift
//  DockTileTests
//
//  Regression guards for IconCompiler: the pure `validationFailure` classifier (the flattening-bug
//  guard — a car that does not carry all three appearance stacks must never be trusted) and the
//  subprocess `compile` wrapper's error paths. The two end-to-end tests against the real vendored
//  compiler SKIP (never fail) where `Scripts/build-compiler.sh` has not been run.
//

import AppKit
import Foundation
import Testing
@testable import Dock_Tile

@Suite("IconCompiler")
struct IconCompilerTests {

    // MARK: - validationFailure: pure classification of `assetutil --info` JSON

    /// The three appearance stacks a real compiled car carries, in `assetutil --info` shape.
    private static func stacks(_ appearances: [String]) -> String {
        let entries = appearances
            .map { #"{"AssetType":"IconImageStack","Name":"x","Appearance":"\#($0)"}"# }
            .joined(separator: ",")
        return "[\(entries),{\"AssetType\":\"Color\"}]"
    }

    private static let allThree = ["NSAppearanceNameAqua", "NSAppearanceNameDarkAqua", "ISAppearanceTintable"]

    @Test("A car with all three appearance stacks validates")
    func stackRenditionsValidate() {
        #expect(IconCompiler.validationFailure(assetutilJSON: Data(Self.stacks(Self.allThree).utf8)) == nil)
    }

    @Test("A SINGLE-stack car is rejected — 'at least one stack' would have passed the collapse")
    func singleStackCarIsRejected() throws {
        let reason = try #require(IconCompiler.validationFailure(
            assetutilJSON: Data(Self.stacks(["NSAppearanceNameAqua"]).utf8)))
        #expect(reason.contains("1 IconImageStack rendition"))
        #expect(reason.contains("must carry exactly 3"))
    }

    @Test("Three stacks that are all the SAME appearance are rejected")
    func duplicateAppearanceStacksAreRejected() throws {
        let reason = try #require(IconCompiler.validationFailure(
            assetutilJSON: Data(Self.stacks(Array(repeating: "NSAppearanceNameAqua", count: 3)).utf8)))
        #expect(reason.contains("must carry exactly 3"))
    }

    @Test("A flattened car (no stack) is INVALID — the Xcode silent-flattening class")
    func flattenedCarIsInvalid() throws {
        let json = #"[{"AssetType":"MultiSized Image","Name":"x"},{"AssetType":"Color"}]"#
        #expect(try #require(IconCompiler.validationFailure(assetutilJSON: Data(json.utf8)))
            .contains("appearances: none"))
        #expect(IconCompiler.validationFailure(assetutilJSON: Data("[]".utf8)) != nil)
        #expect(try #require(IconCompiler.validationFailure(assetutilJSON: Data("not json".utf8)))
            .contains("could not be parsed"))
    }

    @Test("A stray non-JSON preamble line before the array is tolerated")
    func preambleLineIsTolerated() {
        let json = "assetutil: some warning line\n" + Self.stacks(Self.allThree)
        #expect(IconCompiler.validationFailure(assetutilJSON: Data(json.utf8)) == nil)
    }

    // MARK: - compile: error paths (self-contained — no real compiler needed)

    @Test("A non-executable compilerURL throws .compilerMissing")
    func missingCompilerThrows() throws {
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let bogusCompiler = scratch.appendingPathComponent("no-such-tool")
        let document = scratch.appendingPathComponent("x.icon")

        #expect(throws: IconCompilerError.compilerMissing) {
            _ = try IconCompiler.compile(
                document: document, outputDir: scratch.appendingPathComponent("out"), compilerURL: bogusCompiler)
        }
    }

    @Test("A non-zero compiler exit throws .compileFailed carrying its exact stderr")
    func compilerFailureThrowsWithStderr() throws {
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let fakeCompiler = try writeFakeCompiler(in: scratch, script: "echo 'boom' >&2\nexit 1\n")
        let document = scratch.appendingPathComponent("x.icon")

        #expect(throws: IconCompilerError.compileFailed("boom\n")) {
            _ = try IconCompiler.compile(
                document: document, outputDir: scratch.appendingPathComponent("out"), compilerURL: fakeCompiler)
        }
    }

    @Test("A zero exit that produces no Assets.car throws .invalidOutput")
    func missingCarThrowsInvalidOutput() throws {
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let fakeCompiler = try writeFakeCompiler(in: scratch, script: "exit 0\n")
        let document = scratch.appendingPathComponent("x.icon")

        #expect(throws: IconCompilerError.invalidOutput("compiler exited successfully but produced no Assets.car")) {
            _ = try IconCompiler.compile(
                document: document, outputDir: scratch.appendingPathComponent("out"), compilerURL: fakeCompiler)
        }
    }

    @Test("assetutil --info itself failing is reported distinctly from the flattening diagnosis")
    func assetutilFailureIsNotMisdiagnosedAsFlattening() throws {
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }
        // A fake compiler that "succeeds" but leaves a garbage (unreadable-by-assetutil) car —
        // outputDir.path lands at $3 in the invocation compile() builds.
        let fakeCompiler = try writeFakeCompiler(in: scratch, script: "echo garbage > \"$3/Assets.car\"\nexit 0\n")
        let document = scratch.appendingPathComponent("x.icon")

        do {
            _ = try IconCompiler.compile(
                document: document, outputDir: scratch.appendingPathComponent("out"), compilerURL: fakeCompiler)
            Issue.record("expected compile to throw")
        } catch let IconCompilerError.invalidOutput(reason) {
            #expect(reason.contains("assetutil --info failed"))
            #expect(!reason.contains("silently flattened"))
        } catch {
            Issue.record("expected .invalidOutput, got \(error)")
        }
    }

    @Test("A thrown compileFailed's localizedDescription carries the stderr text (the Diagnostics gate)")
    func compileFailedLocalizedDescriptionCarriesDetail() throws {
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let fakeCompiler = try writeFakeCompiler(in: scratch, script: "echo 'boom' >&2\nexit 1\n")
        let document = scratch.appendingPathComponent("x.icon")

        do {
            _ = try IconCompiler.compile(
                document: document, outputDir: scratch.appendingPathComponent("out"), compilerURL: fakeCompiler)
            Issue.record("expected compile to throw")
        } catch {
            // Exactly the code path DiagnosticsLog.measure's catch block exercises — proves the
            // detail survives being boxed into `any Error`, not just that `errorDescription`
            // exists on the concrete type.
            #expect(error.localizedDescription.contains("boom"))
        }
    }

    @Test("A compilerURL that is a directory throws .compilerMissing, not a raw NSError")
    func directoryCompilerURLThrowsCompilerMissing() throws {
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let document = scratch.appendingPathComponent("x.icon")

        #expect(throws: IconCompilerError.compilerMissing) {
            _ = try IconCompiler.compile(
                document: document, outputDir: scratch.appendingPathComponent("out"), compilerURL: scratch)
        }
    }

    // MARK: - Integration: the real vendored compiler against the proven fixture

    static var builtCompilerPath: String {
        projectRoot.appendingPathComponent("Vendor/actool/target/release/docktile-actool").path
    }

    @Test("End-to-end: fixture .icon compiles to a valid layered car",
          .enabled(if: FileManager.default.fileExists(atPath: IconCompilerTests.builtCompilerPath)))
    func fixtureCompilesToValidCar() throws {
        let document = Self.projectRoot.appendingPathComponent("docs/icon-spike-fixtures/devtile-fix.icon")
        let outputDir = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let carURL = try IconCompiler.compile(
            document: document, outputDir: outputDir, compilerURL: URL(fileURLWithPath: Self.builtCompilerPath))

        #expect(carURL.lastPathComponent == "Assets.car")
        #expect(FileManager.default.fileExists(atPath: carURL.path))
    }

    /// The test above compiles a hand-authored STATIC fixture, so it can only prove the compiler
    /// still works on the input someone typed months ago. This one closes the loop that actually
    /// ships: `IconDocumentBuilder.iconJSON` + `IconGenerator.generateGlyphLayerPNG` — the exact
    /// bytes `HelperBundleManager.installDeclarativeIcon` writes — fed to the real compiler. A P3
    /// string format drift, a key the crate rejects, or a layer PNG it can't read would otherwise
    /// surface only in the field, on every tile creation on every user's Mac.
    ///
    /// Both tile shapes, because they build structurally different documents: a symbol tile has
    /// two layers wired by `hidden-specializations`, an emoji tile exactly one with none.
    ///
    /// `compile` throws unless the result carries all three appearance stacks, so reaching the
    /// assertions below IS the proof that the strict `validationFailure` gate accepts a genuine
    /// car built from this app's own output.
    @MainActor
    @Test("End-to-end: the app's OWN builder + layer renderer compile to a valid layered car",
          .enabled(if: FileManager.default.fileExists(atPath: IconCompilerTests.builtCompilerPath)),
          arguments: [(IconType.sfSymbol, "hammer.fill"), (IconType.emoji, "🔨")])
    func builderOutputCompilesToValidCar(_ iconType: IconType, _ iconValue: String) throws {
        // A real per-tile identity: custom tint, non-default scale, non-default weight.
        let tint = TintColor.custom("#5F00FF")
        let scratch = try makeScratchDir()
        defer { try? FileManager.default.removeItem(at: scratch) }

        func layerPNG(_ appearance: IconAppearance) throws -> Data {
            try IconGenerator.generateGlyphLayerPNG(
                appearance: appearance, tintColor: tint, iconType: iconType,
                iconValue: iconValue, iconScale: 16, iconWeight: .semibold)
        }

        // Layer model mirrors HelperBundleManager.declarativeLayerSpecs exactly.
        let specs: [IconDocumentBuilder.LayerSpec]
        let pngs: [String: Data]
        switch iconType {
        case .emoji:
            specs = [.init(name: "glyph", imageName: "glyph.png", exclusiveTo: nil)]
            pngs = ["glyph.png": try layerPNG(.light)]
        case .sfSymbol:
            specs = [
                .init(name: "glyph-light", imageName: "glyph-light.png", exclusiveTo: .light),
                .init(name: "glyph-dark", imageName: "glyph-dark.png", exclusiveTo: .dark)
            ]
            pngs = ["glyph-light.png": try layerPNG(.light), "glyph-dark.png": try layerPNG(.dark)]
        }

        let light = tint.nsColors(for: .defaultStyle, iconType: iconType)
        let dark = tint.nsColors(for: .dark, iconType: iconType)
        let tinted = tint.nsColors(for: .tinted, iconType: iconType)
        let json = IconDocumentBuilder.iconJSON(
            fillTopP3: try Self.p3(light.backgroundTop),
            fillBottomP3: try Self.p3(light.backgroundBottom),
            darkFillTopP3: try Self.p3(dark.backgroundTop),
            darkFillBottomP3: try Self.p3(dark.backgroundBottom),
            tintedFillTopP3: try Self.p3(tinted.backgroundTop),
            tintedFillBottomP3: try Self.p3(tinted.backgroundBottom),
            layers: specs)

        let document = try IconDocumentBuilder.writeDocument(
            json: json, layerPNGs: pngs, name: "AppIcon", parent: scratch)
        let carURL = try IconCompiler.compile(
            document: document,
            outputDir: scratch.appendingPathComponent("compiled"),
            compilerURL: URL(fileURLWithPath: Self.builtCompilerPath))

        let size = try #require(
            try FileManager.default.attributesOfItem(atPath: carURL.path)[.size] as? Int)
        #expect(size > 10_000)   // a real layered car, not an empty shell
    }

    /// Mirrors `HelperBundleManager.p3Components` (private) — the same conversion the fills take.
    private static func p3(_ color: NSColor) throws -> (r: Double, g: Double, b: Double) {
        let converted = try #require(color.usingColorSpace(.displayP3))
        return (Double(converted.redComponent), Double(converted.greenComponent), Double(converted.blueComponent))
    }

    // MARK: - Helpers

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // IconCompilerTests.swift
            .deletingLastPathComponent()  // Utilities/
            .deletingLastPathComponent()  // Unit/
            .deletingLastPathComponent()  // DockTileTests/
    }

    private func makeScratchDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFakeCompiler(in dir: URL, script: String) throws -> URL {
        let url = dir.appendingPathComponent("fake-compiler")
        try "#!/bin/sh\n\(script)".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
}
