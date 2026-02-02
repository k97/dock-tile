import Testing
import Foundation
import ImageIO
@testable import DockTile

// MARK: - Helper Bundle Lifecycle Integration Tests

/// These are integration tests that verify the full helper bundle lifecycle.
/// They should be run locally (not in CI) as they require:
/// - Real file system access
/// - Ability to create app bundles
/// - Code signing capabilities
///
/// These tests use unique tile names to avoid conflicts with user's real tiles.

@Suite("Helper Bundle Lifecycle Integration Tests", .disabled("Run locally only - requires real system access"))
@MainActor
struct HelperBundleLifecycleTests {

    // MARK: - Test Helpers

    /// Generate a unique tile name for testing
    private func uniqueTileName() -> String {
        "Test Tile \(UUID().uuidString.prefix(8))"
    }

    // MARK: - Full Lifecycle Tests

    @Test("Full helper lifecycle: create, verify, delete")
    func fullHelperLifecycle() async throws {
        let config = DockTileConfiguration(
            name: uniqueTileName(),
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            isVisibleInDock: false  // Don't actually add to Dock during test
        )

        let manager = HelperBundleManager.shared

        // 1. Install helper (without adding to Dock)
        // Note: This would need a modified version that doesn't add to Dock
        // For now, we just verify the path calculation
        let expectedPath = manager.helperPath(for: config)

        #expect(expectedPath.lastPathComponent == "\(config.name).app")

        // 2. If we were to install, we'd verify:
        // - Bundle exists at path
        // - Info.plist has correct bundle ID
        // - Icon files exist
        // - Code signature is valid

        // 3. Cleanup would verify:
        // - Bundle is removed
        // - No leftover files
    }

    @Test("Helper path generation is consistent")
    func helperPathConsistency() {
        let config = DockTileConfiguration(name: "Consistency Test")
        let manager = HelperBundleManager.shared

        let path1 = manager.helperPath(for: config)
        let path2 = manager.helperPath(for: config)

        #expect(path1 == path2)
    }

    @Test("Different configs get different paths")
    func differentConfigsDifferentPaths() {
        let config1 = DockTileConfiguration(name: "Tile A")
        let config2 = DockTileConfiguration(name: "Tile B")
        let manager = HelperBundleManager.shared

        let path1 = manager.helperPath(for: config1)
        let path2 = manager.helperPath(for: config2)

        #expect(path1 != path2)
    }

    @Test("Helper exists returns false for non-existent bundle")
    func helperExistsReturnsFalse() {
        let config = DockTileConfiguration(name: uniqueTileName())
        let manager = HelperBundleManager.shared

        let exists = manager.helperExists(for: config)

        #expect(exists == false)
    }
}

// MARK: - Dock Integration Tests

/// Tests for Dock plist integration
/// These require real Dock access and should be run locally only

@Suite("Dock Integration Tests", .disabled("Run locally only - requires real Dock access"))
@MainActor
struct DockIntegrationTests {

    @Test("Can read Dock persistent apps")
    func readDockPersistentApps() {
        let apps = CFPreferencesCopyAppValue(
            "persistent-apps" as CFString,
            "com.apple.dock" as CFString
        ) as? [[String: Any]]

        // Dock should have some apps
        #expect(apps != nil)
        #expect(apps?.isEmpty == false)
    }

    @Test("findInDock returns nil for non-existent bundle ID")
    func findInDockReturnsNil() {
        let manager = HelperBundleManager.shared

        let result = manager.findInDock(bundleId: "com.nonexistent.app.that.definitely.does.not.exist")

        #expect(result == nil)
    }

    @Test("isInDock returns false for non-existent path")
    func isInDockReturnsFalse() async {
        let manager = HelperBundleManager.shared
        let fakePath = URL(fileURLWithPath: "/Applications/NonExistentApp.app")

        let result = await manager.isInDock(at: fakePath)

        #expect(result == false)
    }
}

// MARK: - Icon Generation Integration Tests

/// Tests for icon generation that produce actual files

@Suite("Icon Generation Integration Tests")
@MainActor
struct IconGenerationIntegrationTests {

    @Test("Generate all icon sizes for iconset")
    func generateAllIconSizes() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconGenTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Generate .icns file
        let outputURL = tempDir.appendingPathComponent("TestIcon.icns")

        try IconGenerator.generateIcns(
            tintColor: .blue,
            iconType: .sfSymbol,
            iconValue: "star.fill",
            iconScale: 14,
            outputURL: outputURL
        )

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify file is not empty
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        #expect(fileSize > 0, "Icon file should not be empty")
    }

    @Test("Generated icon can be extracted back to iconset")
    func extractIconset() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconExtractTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Generate .icns file
        let icnsURL = tempDir.appendingPathComponent("TestIcon.icns")
        try IconGenerator.generateIcns(
            tintColor: .green,
            iconType: .emoji,
            iconValue: "📁",
            iconScale: 14,
            outputURL: icnsURL
        )

        // Extract back to iconset using iconutil
        let iconsetURL = tempDir.appendingPathComponent("Extracted.iconset")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "iconset", icnsURL.path, "-o", iconsetURL.path]

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0, "iconutil should succeed")

        // Verify extracted iconset has all required sizes
        let contents = try FileManager.default.contentsOfDirectory(atPath: iconsetURL.path)

        let expectedFiles = [
            "icon_16x16.png",
            "icon_16x16@2x.png",
            "icon_32x32.png",
            "icon_32x32@2x.png",
            "icon_128x128.png",
            "icon_128x128@2x.png",
            "icon_256x256.png",
            "icon_256x256@2x.png",
            "icon_512x512.png",
            "icon_512x512@2x.png"
        ]

        for expectedFile in expectedFiles {
            #expect(contents.contains(expectedFile), "Should contain \(expectedFile)")
        }
    }

    @Test("Icon images have correct pixel dimensions")
    func iconPixelDimensions() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconDimensionsTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Generate and extract
        let icnsURL = tempDir.appendingPathComponent("TestIcon.icns")
        try IconGenerator.generateIcns(
            tintColor: .purple,
            iconType: .sfSymbol,
            iconValue: "folder.fill",
            iconScale: 14,
            outputURL: icnsURL
        )

        let iconsetURL = tempDir.appendingPathComponent("Extracted.iconset")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "iconset", icnsURL.path, "-o", iconsetURL.path]
        try process.run()
        process.waitUntilExit()

        // Check specific file dimensions
        let icon16URL = iconsetURL.appendingPathComponent("icon_16x16.png")
        let icon16Data = try Data(contentsOf: icon16URL)

        if let imageSource = CGImageSourceCreateWithData(icon16Data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {

            let width = properties[kCGImagePropertyPixelWidth as String] as? Int
            let height = properties[kCGImagePropertyPixelHeight as String] as? Int

            #expect(width == 16, "16x16 icon should be 16 pixels wide")
            #expect(height == 16, "16x16 icon should be 16 pixels tall")
        }

        let icon512URL = iconsetURL.appendingPathComponent("icon_512x512@2x.png")
        let icon512Data = try Data(contentsOf: icon512URL)

        if let imageSource = CGImageSourceCreateWithData(icon512Data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {

            let width = properties[kCGImagePropertyPixelWidth as String] as? Int
            let height = properties[kCGImagePropertyPixelHeight as String] as? Int

            #expect(width == 1024, "512x512@2x icon should be 1024 pixels wide")
            #expect(height == 1024, "512x512@2x icon should be 1024 pixels tall")
        }
    }
}
