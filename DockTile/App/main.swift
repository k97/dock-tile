//
//  main.swift
//  DockTile
//
//  Custom entry point to handle helper apps without SwiftUI window creation
//  Swift 6 - Strict Concurrency
//

import AppKit

/// Detect if running as helper app based on bundle ID
private func isHelperApp() -> Bool {
    let bundleId = Bundle.main.bundleIdentifier ?? "com.docktile.app"
    if bundleId == "com.docktile.app" || bundleId == "com.docktile" {
        return false
    }
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
