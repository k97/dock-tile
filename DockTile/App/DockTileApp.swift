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

/// Main SwiftUI App - only used by main DockTile app, not helpers
/// Called from main.swift when running as main app
struct DockTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configManager = ConfigurationManager()

    var body: some Scene {
        WindowGroup {
            DockTileConfigurationView()
                .environmentObject(configManager)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear {
                    appDelegate.configManager = configManager
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New DockTile") {
                    configManager.createConfiguration()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
