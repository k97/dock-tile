//
//  DockTileApp.swift
//  DockTile
//
//  Created for macOS 15.0+ (Tahoe)
//  Swift 6 - Strict Concurrency
//
//  Note: @main removed - using custom main.swift entry point
//  This allows helper apps to bypass SwiftUI entirely
//

import SwiftUI
import Sparkle

/// Main SwiftUI App - only used by main Dock Tile app, not helpers
/// Called from main.swift when running as main app
struct DockTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configManager = ConfigurationManager()
    @StateObject private var updateController = UpdateController()

    // Fixed window dimensions (System Settings style)
    private let windowWidth: CGFloat = 768
    private let minWindowHeight: CGFloat = 500

    private let aboutWindowController = AboutWindowController()

    var body: some Scene {
        // `Window` (not `WindowGroup`) — the configuration UI is a single, unique window.
        // WindowGroup let every Dock-icon click / `docktile://configure` deep link spawn a
        // *duplicate* window in the same process; `Window` guarantees exactly one instance.
        Window(AppStrings.appName, id: AppDelegate.configurationWindowID) {
            DockTileConfigurationView()
                .environmentObject(configManager)
                .environmentObject(updateController)
                .environmentObject(SmartAddEngine.shared)
                .onAppear {
                    appDelegate.configManager = configManager
                    // Refresh the on-device usage signal so the next + press has fresh suggestions.
                    SmartAddEngine.shared.warmUp()
                }
                // Hand SwiftUI's openWindow action to the AppDelegate so AppKit-side code
                // (deep links, Dock-icon reopen) can recreate this window after it's closed.
                .modifier(CaptureOpenWindow { action in
                    appDelegate.openConfigurationWindow = action
                })
                .task {
                    // Never regenerate helpers or scan under a test host — it runs against the
                    // user's live dev tiles (migration once corrupted one mid-generation).
                    guard !AppEnvironment.isRunningTests else { return }

                    // Migrate stale helper bundles after app launch
                    let migration = HelperMigrationManager(configManager: configManager)
                    await migration.migrateIfNeeded()

                    // Then flag any apps that have been uninstalled since last launch. Cheap,
                    // throttled to once per session, and heals moved-app paths along the way.
                    configManager.scanForMissingApps()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: windowWidth, height: 600)

        .commands {
            // Settings now live inline in the main window's sidebar (not a detached ⌘, window).
            // Re-point the standard Settings menu item / ⌘, at the inline General pane.
            CommandGroup(replacing: .appSettings) {
                Button(AppStrings.Menu.settings) {
                    DiagnosticsLog.shared.ui("Menu → Settings (⌘,)")
                    NotificationCenter.default.post(name: .openSettingsPane, object: SettingsPane.general)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Dock Tile") {
                    DiagnosticsLog.shared.ui("Menu → About Dock Tile")
                    aboutWindowController.showAbout {
                        updateController.checkForUpdates()
                    }
                }
                Divider()
                Button("Check for Updates...") {
                    DiagnosticsLog.shared.ui("Menu → Check for Updates")
                    updateController.checkForUpdates()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(AppStrings.Menu.newTile) {
                    DiagnosticsLog.shared.ui("Menu → New Tile (⌘N)")
                    configManager.createConfiguration()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!configManager.selectedConfigHasBeenEdited)
            }
            CommandGroup(after: .newItem) {
                Button(AppStrings.Menu.copyDiagnostics) {
                    DiagnosticsLog.shared.ui("Menu → Copy Diagnostics")
                    DiagnosticsLog.shared.copyToPasteboard()
                }
            }
        }
    }
}

/// Captures SwiftUI's `openWindow` action and hands it to the `AppDelegate`.
///
/// AppKit-side entry points (the `docktile://configure` deep link and the Dock-icon reopen
/// handler) need to bring up the configuration window even after the user has fully closed it
/// — at which point there is no live SwiftUI view to read `@Environment(\.openWindow)`. The
/// captured `OpenWindowAction` stays valid for the app's lifetime, so storing it once lets
/// those handlers recreate the single window on demand.
private struct CaptureOpenWindow: ViewModifier {
    let store: (@escaping () -> Void) -> Void
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            store { openWindow(id: AppDelegate.configurationWindowID) }
        }
    }
}
