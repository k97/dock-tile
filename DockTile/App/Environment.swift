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

    /// THIS process's bundle identifier: the main app's ("com.docktile.app" / "com.docktile.dev.app")
    /// in the main app, but a helper's own per-tile id inside a helper.
    static let mainAppBundleId: String = {
        Bundle.main.bundleIdentifier ?? "com.docktile.app"
    }()

    /// Prefix for helper bundle identifiers (e.g., "com.docktile" or "com.docktile.dev")
    static let helperBundlePrefix: String = {
        Bundle.main.infoDictionary?["DTHelperPrefix"] as? String ?? "com.docktile"
    }()

    /// Whether this process is a helper bundle (a copy of the main app with a per-tile
    /// bundle ID like `com.docktile.<UUID>`) rather than the main app itself. The ONE helper check:
    /// `main.swift` branches on it to pick the helper or main-app delegate.
    static let isHelper: Bool = isHelper(bundleId: mainAppBundleId)

    /// The rule behind `isHelper`, on a plain value (`HelperDetectionTests`).
    static func isHelper(bundleId: String) -> Bool {
        let mainAppBundleIds: Set<String> = ["com.docktile.app", "com.docktile.dev.app", "com.docktile"]
        if mainAppBundleIds.contains(bundleId) { return false }
        return bundleId.hasPrefix("com.docktile.")
    }

    /// Analytics/Crashlytics role label for the current process.
    static var appRole: String { isHelper ? "helper" : "main" }

    /// Whether the process is running inside an XCTest / Swift Testing host. `xcodebuild test`
    /// injects the test bundle into the app host (`TEST_HOST = Dock Tile Dev.app`), so the host's
    /// normal launch path runs against the user's LIVE dev data. Gate launch-time side effects
    /// (helper migration/regeneration, Dock reconcile + watch, login-item registration, Smart Add
    /// observing) on `!isRunningTests` so a test run can never mutate or corrupt real tiles.
    static let isRunningTests: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }()

    /// Started by the login spawner, or relaunched by an idle-time update, to sit in the menu bar with
    /// no window and no Dock icon (#13). Latched once, on first read (`applicationWillFinishLaunching`).
    static let quietLaunchFlag = "--quiet-launch"
    static let isQuietLaunch: Bool = {
        if CommandLine.arguments.contains(quietLaunchFlag) { return true }
        guard let flaggedAt = UserDefaults.standard.object(forKey: UserDefaultsKeys.relaunchQuietlyAt) as? Date else {
            return false
        }
        // Cleared at once, so a failed install can't make a later normal launch silent.
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.relaunchQuietlyAt)
        return IdleInstall.isQuietRelaunch(flaggedAt: flaggedAt, now: Date())
    }()

    /// Marketing version string (e.g., "1.2.1").
    static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
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
