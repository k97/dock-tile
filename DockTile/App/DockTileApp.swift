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

/// Main SwiftUI App - only used by main Dock Tile app, not helpers
/// Called from main.swift when running as main app
struct DockTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configManager = ConfigurationManager()

    // Fixed window dimensions (System Settings style)
    private let windowWidth: CGFloat = 768
    private let minWindowHeight: CGFloat = 500

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
