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
        WindowGroup {
            DockTileConfigurationView()
                .environmentObject(configManager)
                .onAppear {
                    appDelegate.configManager = configManager
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: windowWidth, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Dock Tile") {
                    aboutWindowController.showAbout {
                        updateController.checkForUpdates()
                    }
                }
                Divider()
                Button("Check for Updates...") {
                    updateController.checkForUpdates()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(AppStrings.Menu.newTile) {
                    configManager.createConfiguration()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!configManager.selectedConfigHasBeenEdited)
            }
        }
    }
}
