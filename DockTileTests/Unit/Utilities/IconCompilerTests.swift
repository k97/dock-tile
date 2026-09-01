//
//  IconCompilerTests.swift
//  DockTileTests
//
//  Regression guards for IconCompiler: the pure `validate` classifier (the flattening-bug guard
//  that a car with no IconImageStack rendition must never be trusted) and the subprocess
//  `compile` wrapper's error paths. The end-to-end test against the real vendored compiler
//  SKIPS (never fails) until Task 13 wires the compiler into the app bundle.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("IconCompiler")
struct IconCompilerTests {

    // MARK: - validate: pure classification of `assetutil --info` JSON

    @Test("A car with IconImageStack renditions validates")
    func stackRenditionsValidate() {
        let json = #"[{"AssetType":"IconImageStack","Name":"x"},{"AssetType":"Color"}]"#
        #expect(IconCompiler.validate(assetutilJSON: Data(json.utf8)))
    }

    @Test("A flattened car (no stack) is INVALID — the Xcode silent-flattening class")
    func flattenedCarIsInvalid() {
        let json = #"[{"AssetType":"MultiSized Image","Name":"x"},{"AssetType":"Color"}]"#
        #expect(!IconCompiler.validate(assetutilJSON: Data(json.utf8)))
        #expect(!IconCompiler.validate(assetutilJSON: Data("[]".utf8)))
        #expect(!IconCompiler.validate(assetutilJSON: Data("not json".utf8)))
    }

    @Test("A stray non-JSON preamble line before the array is tolerated")
    func preambleLineIsTolerated() {
        let json = "assetutil: some warning line\n" + #"[{"AssetType":"IconImageStack"}]"#
        #expect(IconCompiler.validate(assetutilJSON: Data(json.utf8)))
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
