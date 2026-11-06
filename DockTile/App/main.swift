//
//  main.swift
//  DockTile
//
//  Custom entry point to handle helper apps without SwiftUI window creation
//  Swift 6 - Strict Concurrency
//

import AppKit

// Check before any SwiftUI initialization
if CommandLine.arguments.contains(LoginTileSpawner.flag) {
    // Headless login path: the SMAppService launcher agent started us to warm the
    // tiles. Launch the visible helpers and exit — never spins up an NSApplication,
    // so no Dock icon or window appears at login.
    LoginTileSpawner.run()
} else if AppEnvironment.isHelper {
    // Helper app (bundle ID com.docktile.<UUID> / com.docktile.dev.<UUID>): Pure AppKit, no SwiftUI WindowGroup
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    NSLog("🚀 Starting as helper app (pure AppKit) - Bundle ID: %@", bundleId)
    print("🚀 Starting as helper app (pure AppKit) - Bundle ID: \(bundleId)")

    // Analytics/Crashlytics (helpers report popover usage with app_role=helper).
    AnalyticsService.shared.configure()
    AnalyticsService.shared.log(.appLaunched)

    DiagnosticsLog.shared.log("lifecycle", "Helper launched — \(bundleId)")

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

    // One main app at a time (#13): the login spawner starts a new instance on purpose, and "Reopen
    // windows when logging back in" can start another at the same moment; both would write the
    // config and the Dock plist. Held for the process's life. The loser waits up to 5 s first, because
    // the move to /Applications launches the new copy before the old one quits.
    let mainAppLock: TileBuildLock? = AppEnvironment.isRunningTests ? nil : {
        for _ in 0..<50 {
            if let lock = TileBuildLock.acquire(bundleId: "main-app", stagingDirectory: AppEnvironment.supportURL) {
                return lock
            }
            usleep(100_000)
        }
        return nil
    }()
    if !AppEnvironment.isRunningTests && mainAppLock == nil {
        DiagnosticsLog.shared.log("lifecycle", "Another Dock Tile is running — exiting (quiet: \(AppEnvironment.isQuietLaunch))")
        exit(0)
    }

    // Analytics/Crashlytics — configure before SwiftUI spins up.
    AnalyticsService.shared.configure()
    AnalyticsService.shared.log(.appLaunched)

    // Skip under a test host so a `xcodebuild test` doesn't trim/pollute the user's live dev log.
    if !AppEnvironment.isRunningTests {
        DiagnosticsLog.shared.prepareOnLaunch()  // main-app-only: trim shared log to the last hour
        DiagnosticsLog.shared.log("lifecycle", "Main app launched — v\(AppEnvironment.appVersion) (\(AppEnvironment.current))")
    }

    // Never restore AppKit window state: after an unclean exit (crash, Force Quit) it records "no
    // windows", SwiftUI then creates none — even with `.defaultLaunchBehavior(.presented)` — and
    // without it `onAppear` (the Open Dock Tile… handle) and the launch-maintenance `.task` never run
    // (#13, measured 2026-11-06). The frame is kept apart, under `NSWindow Frame …`.
    UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])

    // An optimised build may release a local after its last use; the lock must outlive the run loop.
    withExtendedLifetime(mainAppLock) {
        DockTileApp.main()
    }
}
