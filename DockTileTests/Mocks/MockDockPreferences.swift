import Foundation

/// Protocol for Dock preferences abstraction to enable testing
/// This abstracts CFPreferences API calls for Dock plist manipulation
protocol DockPreferencesProtocol {
    func persistentApps() -> [[String: Any]]?
    func setPersistentApps(_ apps: [[String: Any]])
    func synchronize() -> Bool
}

/// Real implementation using CFPreferences API
final class RealDockPreferences: DockPreferencesProtocol {

    func persistentApps() -> [[String: Any]]? {
        CFPreferencesCopyAppValue(
            "persistent-apps" as CFString,
            "com.apple.dock" as CFString
        ) as? [[String: Any]]
    }

    func setPersistentApps(_ apps: [[String: Any]]) {
        CFPreferencesSetAppValue(
            "persistent-apps" as CFString,
            apps as CFArray,
            "com.apple.dock" as CFString
        )
    }

    func synchronize() -> Bool {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
    }
}

/// Mock implementation for testing
final class MockDockPreferences: DockPreferencesProtocol, @unchecked Sendable {

    // MARK: - State

    /// In-memory persistent apps array
    private var apps: [[String: Any]] = []

    /// Track method calls for verification
    var setPersistentAppsCalls: [[[String: Any]]] = []
    var synchronizeCalls = 0

    // MARK: - Initialization

    init(initialApps: [[String: Any]] = []) {
        apps = initialApps
    }

    // MARK: - DockPreferencesProtocol

    func persistentApps() -> [[String: Any]]? {
        apps.isEmpty ? nil : apps
    }

    func setPersistentApps(_ newApps: [[String: Any]]) {
        setPersistentAppsCalls.append(newApps)
        apps = newApps
    }

    func synchronize() -> Bool {
        synchronizeCalls += 1
        return true
    }

    // MARK: - Test Helpers

    /// Add an app entry to the mock Dock
    func addApp(bundleIdentifier: String, path: String, name: String? = nil) {
        let entry: [String: Any] = [
            "tile-data": [
                "bundle-identifier": bundleIdentifier,
                "file-data": [
                    "_CFURLString": path,
                    "_CFURLStringType": 0
                ],
                "file-label": name ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            ] as [String: Any],
            "tile-type": "file-tile"
        ]
        apps.append(entry)
    }

    /// Remove an app by bundle identifier
    func removeApp(bundleIdentifier: String) {
        apps.removeAll { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let bundleId = tileData["bundle-identifier"] as? String else {
                return false
            }
            return bundleId == bundleIdentifier
        }
    }

    /// Check if an app with the given bundle identifier is in the Dock
    func containsApp(bundleIdentifier: String) -> Bool {
        apps.contains { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let bundleId = tileData["bundle-identifier"] as? String else {
                return false
            }
            return bundleId == bundleIdentifier
        }
    }

    /// Get the index of an app by bundle identifier
    func indexOfApp(bundleIdentifier: String) -> Int? {
        apps.firstIndex { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let bundleId = tileData["bundle-identifier"] as? String else {
                return false
            }
            return bundleId == bundleIdentifier
        }
    }

    /// Reset all state
    func reset() {
        apps.removeAll()
        setPersistentAppsCalls.removeAll()
        synchronizeCalls = 0
    }

    /// Get the current number of apps
    var appCount: Int {
        apps.count
    }
}
