//
//  main.swift
//  DockTile
//
//  Custom entry point to handle helper apps without SwiftUI window creation
//  Swift 6 - Strict Concurrency
//

import AppKit

/// Detect if running as helper app based on bundle ID
/// Main apps: com.docktile.app (release) or com.docktile.dev.app (dev)
/// Helper apps: com.docktile.<UUID> (release) or com.docktile.dev.<UUID> (dev)
private func isHelperApp() -> Bool {
    let bundleId = Bundle.main.bundleIdentifier ?? "com.docktile.app"

    // Main app bundle IDs (not helpers)
    let mainAppBundleIds = [
        "com.docktile.app",      // Release
        "com.docktile.dev.app",  // Dev
        "com.docktile"           // Legacy/fallback
    ]

    if mainAppBundleIds.contains(bundleId) {
        return false
    }

    // Helper apps have bundle IDs like com.docktile.<UUID> or com.docktile.dev.<UUID>
    return bundleId.hasPrefix("com.docktile.")
}

// Check before any SwiftUI initialization
if isHelperApp() {
    // Helper app: Pure AppKit, no SwiftUI WindowGroup
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    NSLog("🚀 Starting as helper app (pure AppKit) - Bundle ID: %@", bundleId)
    print("🚀 Starting as helper app (pure AppKit) - Bundle ID: \(bundleId)")

    // Create autoreleasepool to manage memory properly
    autoreleasepool {
        let app = NSApplication.shared
        // IMPORTANT: Store delegate in a variable that persists for the lifetime of run()
        // NSApplication.delegate is a weak reference, so we must keep a strong reference
        let delegate = HelperAppDelegate()
        app.delegate = delegate
        NSLog("✓ Delegate set: %@", String(describing: type(of: delegate)))

        // Use withExtendedLifetime to ensure delegate isn't deallocated during run()
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
} else {
    // Main app: Use SwiftUI
    print("🚀 Starting as main app (SwiftUI)")
    DockTileApp.main()
}
