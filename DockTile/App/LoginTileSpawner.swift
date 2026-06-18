//
//  LoginTileSpawner.swift
//  DockTile
//
//  Headless "warm the tiles at login" path. Invoked when the main app binary is
//  launched with `--login-spawn-tiles` by the SMAppService launcher agent (see
//  LoginItemManager + the bundled Contents/Library/LaunchAgents plist).
//
//  It launches every visible tile's helper bundle in the background and then exits.
//  It NEVER creates an NSApplication, so no Dock icon or window appears at login —
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

        let configs = loadVisibleConfigs()
        guard !configs.isEmpty else {
            NSLog("🌅 LoginTileSpawner: no visible tiles to warm — exiting")
            exit(0)
        }

        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
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

        // Wait for the launches to be acknowledged, with a safety timeout, then exit.
        _ = group.wait(timeout: .now() + 15)
        NSLog("🌅 LoginTileSpawner: done — exiting")
        exit(0)
    }

    // MARK: - Self-contained helpers

    /// Decode the shared config JSON and return only tiles that should be in the Dock.
    private static func loadVisibleConfigs() -> [DockTileConfiguration] {
        let url = AppEnvironment.preferencesURL
        guard let data = try? Data(contentsOf: url) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601  // matches ConfigurationManager
        guard let configs = try? decoder.decode([DockTileConfiguration].self, from: data) else {
            NSLog("🌅 LoginTileSpawner: could not decode configs at %@", url.path)
            return []
        }
        return configs.filter { $0.isVisibleInDock }
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
