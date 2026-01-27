//
//  GhostModeManager.swift
//  DockTile
//
//  Manages Ghost Mode state and activation policy switching
//  Swift 6 - Strict Concurrency
//

import AppKit
import Foundation

@MainActor
final class GhostModeManager: ObservableObject {
    static let shared = GhostModeManager()

    @Published var isGhostModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isGhostModeEnabled, forKey: "isGhostModeEnabled")
            applyActivationPolicy()
        }
    }

    private init() {
        // Load persisted state
        self.isGhostModeEnabled = UserDefaults.standard.bool(forKey: "isGhostModeEnabled")
    }

    /// Apply the appropriate activation policy based on Ghost Mode state
    func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = isGhostModeEnabled ? .accessory : .regular

        guard NSApp.setActivationPolicy(policy) else {
            print("⚠️ Failed to set activation policy to \(policy)")
            return
        }

        print("✓ Activation policy set to: \(policy == .accessory ? "accessory (Ghost Mode)" : "regular")")
    }

    /// Toggle Ghost Mode on/off
    func toggleGhostMode() {
        isGhostModeEnabled.toggle()
        print("Ghost Mode: \(isGhostModeEnabled ? "ENABLED" : "DISABLED")")
    }
}
