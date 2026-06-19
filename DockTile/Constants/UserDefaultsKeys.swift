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

    // "Start tiles at login" is ON by default (opt-out). SMAppService is the source of truth for
    // the *current* status, but a Sparkle update replaces the app bundle and can silently demote
    // the registration. We persist the user's opt-out below so the main app can re-assert
    // registration on launch (see LoginItemManager.reconcileOnLaunch) unless the user turned it off.
    /// True only when the user has explicitly turned start-at-login OFF. Absent/false = ON by
    /// default. Main-app domain only (dev and release have separate bundle IDs / agents).
    static let startAtLoginOptedOut = "startAtLoginOptedOut"

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
