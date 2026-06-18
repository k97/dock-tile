//
//  UserDefaultsKeys.swift
//  DockTile
//
//  Centralized UserDefaults key constants to prevent magic string bugs.
//  Swift 6 - Strict Concurrency
//

import Foundation

enum UserDefaultsKeys {
    static let hasAcknowledgedDockRestart = "hasAcknowledgedDockRestart"
    static let lastSelectedConfigId = "lastSelectedConfigId"
    static let lastMigratedAppVersion = "lastMigratedAppVersion"

    // Note: "Start tiles at login" has no UserDefaults key — its state lives in
    // SMAppService (see LoginItemManager), which is the system source of truth.

    // Dock Lock: keep the Dock pinned to one display
    static let dockLockEnabled = "dockLockEnabled"
    static let dockLockAnchorDisplay = "dockLockAnchorDisplay"

    /// Analytics & Crashlytics consent (opt-out, default ON).
    /// Stored in the SHARED suite below — NOT the per-app default domain — because helper
    /// bundles run under their own bundle IDs and must read the same value as the main app.
    static let analyticsEnabled = "analyticsEnabled"

    /// Shared UserDefaults suite readable by the main app and every helper bundle.
    /// Used for cross-process settings like analytics consent.
    static let sharedSuiteName = "com.docktile.shared"
}
