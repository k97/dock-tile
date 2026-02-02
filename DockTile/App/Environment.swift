//
//  Environment.swift
//  DockTile
//
//  Runtime environment constants read from Info.plist
//  Values are set via xcconfig files (Dev.xcconfig / Release.xcconfig)
//  See RELEASE.md for documentation on Dev/Release workflow
//

import Foundation

/// App environment configuration read from Info.plist at runtime.
/// These values are set by xcconfig files and injected into Info.plist during build.
enum AppEnvironment {

    // MARK: - Environment Detection

    /// Current environment: "DEV" or "RELEASE"
    static let current: String = {
        Bundle.main.infoDictionary?["DTEnvironment"] as? String ?? "RELEASE"
    }()

    /// Whether this is a development build
    static let isDev: Bool = current == "DEV"

    /// Whether this is a release/production build
    static let isRelease: Bool = current == "RELEASE"

    // MARK: - Bundle Identifiers

    /// Main app bundle identifier (e.g., "com.docktile.app" or "com.docktile.dev.app")
    static let mainAppBundleId: String = {
        Bundle.main.bundleIdentifier ?? "com.docktile.app"
    }()

    /// Prefix for helper bundle identifiers (e.g., "com.docktile" or "com.docktile.dev")
    static let helperBundlePrefix: String = {
        Bundle.main.infoDictionary?["DTHelperPrefix"] as? String ?? "com.docktile"
    }()

    // MARK: - File Paths

    /// Preferences JSON filename (e.g., "com.docktile.configs.json")
    static let preferencesFilename: String = {
        Bundle.main.infoDictionary?["DTPrefsFilename"] as? String ?? "com.docktile.configs.json"
    }()

    /// Application Support subfolder name (e.g., "DockTile" or "DockTile-Dev")
    static let supportFolderName: String = {
        Bundle.main.infoDictionary?["DTSupportFolder"] as? String ?? "DockTile"
    }()

    // MARK: - Computed Paths

    /// Full path to preferences JSON file
    static var preferencesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(preferencesFilename)")
    }

    /// Full path to Application Support folder for helper bundles
    static var supportURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(supportFolderName)")
    }
}
