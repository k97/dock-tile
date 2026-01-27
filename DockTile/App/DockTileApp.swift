//
//  DockTileApp.swift
//  DockTile
//
//  Created for macOS 15.0+ (Tahoe)
//  Swift 6 - Strict Concurrency
//

import SwiftUI

/// Detect if running as helper app based on bundle ID (computed at launch)
private let isHelperAppAtLaunch: Bool = {
    let bundleId = Bundle.main.bundleIdentifier ?? "com.docktile.app"
    if bundleId == "com.docktile.app" || bundleId == "com.docktile" {
        return false
    }
    return bundleId.hasPrefix("com.docktile.")
}()

@main
struct DockTileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var configManager = ConfigurationManager()

    var body: some Scene {
        // Main app: configuration window
        WindowGroup {
            Group {
                if isHelperAppAtLaunch {
                    // Helper: show minimal invisible view
                    // AppDelegate will hide this window after SwiftUI finishes setup
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onAppear {
                            // Pass config manager to AppDelegate
                            appDelegate.configManager = configManager
                        }
                } else {
                    // Main app: show configuration view
                    DockTileConfigurationView()
                        .environmentObject(configManager)
                        .frame(minWidth: 1000, minHeight: 700)
                        .onAppear {
                            appDelegate.configManager = configManager
                        }
                }
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
