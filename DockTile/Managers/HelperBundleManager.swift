//
//  HelperBundleManager.swift
//  DockTile
//
//  Manages creation and deletion of helper app bundles for multi-instance support
//  Swift 6 - Strict Concurrency
//

import AppKit
import Foundation

@MainActor
final class HelperBundleManager {
    static let shared = HelperBundleManager()

    // MARK: - Properties

    /// Directory where helper bundles are stored: ~/Library/Application Support/DockTile/
    private let helperDirectory: URL

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        helperDirectory = appSupport.appendingPathComponent("DockTile")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: helperDirectory,
            withIntermediateDirectories: true
        )

        print("📁 HelperBundleManager initialized")
        print("   Helper directory: \(helperDirectory.path)")
    }

    // MARK: - Public API

    /// Install a helper bundle for the given configuration
    func installHelper(for config: DockTileConfiguration) async throws {
        print("🔧 Installing helper for: \(config.name)")

        let appName = sanitizeAppName(config.name)
        let helperPath = helperDirectory.appendingPathComponent("\(appName).app")

        // 1. Generate helper bundle structure (copy main app)
        try generateHelperBundle(
            appName: appName,
            bundleId: config.bundleIdentifier,
            helperPath: helperPath
        )

        // 2. Generate icon AFTER bundle is created, directly into Resources
        let iconDestPath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns")
        try IconGenerator.generateIcns(
            tintColor: config.tintColor,
            symbol: config.symbolEmoji,
            outputURL: iconDestPath
        )
        print("   ✓ Generated icon")

        // 3. Code sign the bundle
        try codesignHelper(at: helperPath)
        print("   ✓ Code signed")

        print("✅ Helper installed at: \(helperPath.path)")
    }

    /// Uninstall a helper bundle for the given configuration
    func uninstallHelper(for config: DockTileConfiguration) throws {
        print("🗑️ Uninstalling helper for: \(config.name)")

        let appName = sanitizeAppName(config.name)
        let helperPath = helperDirectory.appendingPathComponent("\(appName).app")

        if FileManager.default.fileExists(atPath: helperPath.path) {
            try FileManager.default.removeItem(at: helperPath)
            print("   ✓ Removed: \(helperPath.path)")
        }

        print("✅ Helper uninstalled for: \(config.name)")
    }

    /// Check if a helper bundle exists for the given configuration
    func helperExists(for config: DockTileConfiguration) -> Bool {
        let appName = sanitizeAppName(config.name)
        let helperPath = helperDirectory.appendingPathComponent("\(appName).app")
        return FileManager.default.fileExists(atPath: helperPath.path)
    }

    /// Get the path to a helper bundle
    func helperPath(for config: DockTileConfiguration) -> URL {
        let appName = sanitizeAppName(config.name)
        return helperDirectory.appendingPathComponent("\(appName).app")
    }

    // MARK: - Bundle Generation (Pure Swift)

    private func generateHelperBundle(
        appName: String,
        bundleId: String,
        helperPath: URL
    ) throws {
        let mainAppPath = Bundle.main.bundlePath

        print("   Generating helper bundle...")
        print("   Main app: \(mainAppPath)")
        print("   Helper: \(helperPath.path)")

        // Remove existing helper if present
        if FileManager.default.fileExists(atPath: helperPath.path) {
            try FileManager.default.removeItem(at: helperPath)
        }

        // Copy main app bundle
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: mainAppPath),
            to: helperPath
        )
        print("   ✓ Copied bundle structure")

        // Update Info.plist
        try updateInfoPlist(
            at: helperPath,
            bundleId: bundleId,
            appName: appName
        )
        print("   ✓ Updated Info.plist")

        // Remove existing icon (will be replaced with generated one)
        let existingIconPath = helperPath.appendingPathComponent("Contents/Resources/AppIcon.icns")
        try? FileManager.default.removeItem(at: existingIconPath)

        // Note: We keep the full binary copy (no symlink) because codesign
        // requires the main executable to be a regular file, not a symlink
    }

    private func updateInfoPlist(at helperPath: URL, bundleId: String, appName: String) throws {
        let infoPlistPath = helperPath.appendingPathComponent("Contents/Info.plist")

        guard var plist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any] else {
            throw HelperBundleError.infoPlistReadFailed
        }

        // Update bundle metadata
        plist["CFBundleIdentifier"] = bundleId
        plist["CFBundleName"] = appName
        plist["CFBundleDisplayName"] = appName

        // Keep LSUIElement false (or remove) so app shows in Dock
        // User can right-click "Keep in Dock" to make it permanent
        plist.removeValue(forKey: "LSUIElement")

        // Write back
        let nsDict = plist as NSDictionary
        guard nsDict.write(to: infoPlistPath, atomically: true) else {
            throw HelperBundleError.infoPlistWriteFailed
        }
    }

    private func codesignHelper(at helperPath: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", helperPath.path]

        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw HelperBundleError.codesignFailed
        }
    }

    // MARK: - Helpers

    /// Sanitize app name for use as bundle name (replace special chars)
    private func sanitizeAppName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        return name
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Errors

enum HelperBundleError: Error, LocalizedError {
    case infoPlistReadFailed
    case infoPlistWriteFailed
    case bundleCopyFailed
    case codesignFailed
    case mainAppNotFound

    var errorDescription: String? {
        switch self {
        case .infoPlistReadFailed:
            return "Failed to read Info.plist"
        case .infoPlistWriteFailed:
            return "Failed to write Info.plist"
        case .bundleCopyFailed:
            return "Failed to copy bundle"
        case .codesignFailed:
            return "Failed to code sign helper bundle"
        case .mainAppNotFound:
            return "Main DockTile.app not found"
        }
    }
}
