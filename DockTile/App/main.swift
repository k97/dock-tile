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
    print("🚀 Starting as helper app (pure AppKit)")

    let app = NSApplication.shared
    let delegate = HelperAppDelegate()
    app.delegate = delegate
    app.run()
} else {
    // Main app: Use SwiftUI
    print("🚀 Starting as main app (SwiftUI)")
    DockTileApp.main()
}
