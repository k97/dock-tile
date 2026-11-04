//
//  ConfigReadFailureTests.swift
//  DockTileTests
//
//  A config file that exists but can't be READ at launch loaded as an empty list, and the next
//  save wrote that list over every tile. These run a real `ConfigurationManager` against a temp
//  file. Failing value: without the save guard, the atomic save replaces the unreadable file
//  (its directory is writable, so the rename succeeds) and its bytes become "[]".
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("Config read failure", .serialized)
@MainActor
struct ConfigReadFailureTests {

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigReadFailureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let real = try #require(realpath(dir.path, nil))
        defer { free(real) }
        return URL(fileURLWithPath: String(cString: real), isDirectory: true)
    }

    @Test("An existing file that can't be read is never overwritten")
    func unreadableFileIsNeverOverwritten() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("configs.json")
        let original = Data(#"[{"marker":"the user's tiles"}]"#.utf8)
        try original.write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }

        let manager = ConfigurationManager(storageURL: file)
        #expect(manager.readFailed)
        #expect(manager.configurations.isEmpty)
        manager.saveAllConfigurations()

        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        #expect(try Data(contentsOf: file) == original)
    }

    @Test("A missing file is a fresh start: it is not a read failure and saving works")
    func missingFileStillSaves() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("configs.json")

        let manager = ConfigurationManager(storageURL: file)
        #expect(!manager.readFailed)
        manager.saveAllConfigurations()

        let saved = try Data(contentsOf: file)
        let list = try #require(try JSONSerialization.jsonObject(with: saved) as? [Any])
        #expect(list.count == 0)
    }
}
