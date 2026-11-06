//
//  LoginTileSpawner.swift
//  DockTile
//
//  Headless "warm the tiles at login" path. Invoked when the main app binary is
//  launched with `--login-spawn-tiles` by the SMAppService launcher agent (see
//  LoginItemManager + the bundled Contents/Library/LaunchAgents plist).
//
//  It launches every visible tile's helper bundle in the background, then — while the menu bar
//  icon is on (#13) — the main app with `--quiet-launch` (no window, no Dock icon), and exits.
//  It NEVER creates an NSApplication itself, so no Dock icon or window appears at login —
//  the user just sees their tiles become responsive.
//
//  Deliberately self-contained: it does NOT touch ConfigurationManager (whose init
//  starts a DockPlistWatcher and mutates state) or the @MainActor HelperBundleManager
//  (MainActor isolation is awkward before the app's run loop exists). The small amount
//  of duplicated logic — decoding configs and finding a helper bundle by bundle ID —
//  is the price of keeping this path side-effect-free.
//
//  Swift 6 - Strict Concurrency
//

import AppKit

enum LoginTileSpawner {

    /// Command-line flag that selects this path (passed by the launcher agent plist).
    static let flag = "--login-spawn-tiles"

    /// Launch all visible tiles in the background, then terminate the process.
    static func run() -> Never {
        NSLog("🌅 LoginTileSpawner: warming visible tiles at login")

        let runningApps = NSWorkspace.shared.runningApplications
        let running = Set(runningApps.compactMap { $0.bundleIdentifier })
        // Decided before the no-tiles exit: every tile hidden + the menu bar icon is a real setup.
        let launchesMain = launchesMainApp(
            menuBarEnabled: UserDefaults.standard.bool(forKey: UserDefaultsKeys.menuBarEnabled),
            mainAppPids: runningApps.filter { $0.bundleIdentifier == AppEnvironment.mainAppBundleId }
                .map(\.processIdentifier),
            ownPid: ProcessInfo.processInfo.processIdentifier)

        let configs = loadVisibleConfigs()
        if configs.isEmpty { NSLog("🌅 LoginTileSpawner: no visible tiles to warm") }

        let group = DispatchGroup()

        for config in configs {
            guard !running.contains(config.bundleIdentifier) else {
                NSLog("🌅 LoginTileSpawner: %@ already running — skipping", config.bundleIdentifier)
                continue
            }
            guard let helperURL = helperBundleURL(forBundleId: config.bundleIdentifier) else {
                NSLog("🌅 LoginTileSpawner: no helper bundle for %@ — skipping", config.bundleIdentifier)
                continue
            }

            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.activates = false
            openConfig.addsToRecentItems = false
            openConfig.arguments = ["--background-launch"]

            group.enter()
            NSWorkspace.shared.openApplication(at: helperURL, configuration: openConfig) { _, error in
                if let error {
                    NSLog("🌅 LoginTileSpawner: failed to launch %@: %@",
                          config.bundleIdentifier, error.localizedDescription)
                }
                group.leave()
            }
        }

        // Wait for the launches to be acknowledged, with a safety timeout.
        _ = group.wait(timeout: .now() + 15)

        // After the helpers: the main app's launch maintenance may rebuild them.
        if launchesMain {
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.activates = false
            openConfig.addsToRecentItems = false
            openConfig.createsNewApplicationInstance = true  // this process already has the bundle id
            openConfig.arguments = [AppEnvironment.quietLaunchFlag]
            let launched = DispatchGroup()
            launched.enter()
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: openConfig) { _, error in
                // On failure the icon appears the next time the user opens Dock Tile.
                if let error { NSLog("🌅 LoginTileSpawner: failed to launch the main app: %@", error.localizedDescription) }
                launched.leave()
            }
            _ = launched.wait(timeout: .now() + 15)
        }
        NSLog("🌅 LoginTileSpawner: done — exiting")
        exit(0)
    }

    /// The main app sits in the menu bar from login only while the icon is on and no other copy runs.
    /// This process shares the main app's bundle id, so its own pid never counts (`LoginSpawnPlanTests`).
    static func launchesMainApp(menuBarEnabled: Bool, mainAppPids: [pid_t], ownPid: pid_t) -> Bool {
        menuBarEnabled && !mainAppPids.contains { $0 != ownPid }
    }

    // MARK: - Self-contained helpers

    /// Decode the shared config JSON and return only tiles that should be in the Dock.
    private static func loadVisibleConfigs() -> [DockTileConfiguration] {
        let url = AppEnvironment.preferencesURL
        guard let data = try? Data(contentsOf: url) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601  // matches ConfigurationManager
        let decoded = DockTileConfiguration.decodeTolerantly(data, using: decoder)
        if decoded.skipped > 0 || decoded.wholeFileUnreadable {
            NSLog("🌅 LoginTileSpawner: could not decode some configs at %@ (skipped %ld)", url.path, decoded.skipped)
        }
        return decoded.tiles.filter { $0.isVisibleInDock }
    }

    /// Find a helper `.app` in the support folder whose Info.plist bundle ID matches.
    /// Mirrors HelperBundleManager.findExistingHelper, kept local to avoid MainActor.
    private static func helperBundleURL(forBundleId bundleId: String) -> URL? {
        let dir = AppEnvironment.supportURL
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return nil }

        for item in contents where item.pathExtension == "app" {
            let infoPlist = item.appendingPathComponent("Contents/Info.plist")
            if let plist = NSDictionary(contentsOf: infoPlist),
               plist["CFBundleIdentifier"] as? String == bundleId {
                return item
            }
        }
        return nil
    }
}
