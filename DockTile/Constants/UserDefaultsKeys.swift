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
    /// Legacy: anchor stored as a raw CGDirectDisplayID. Unstable across reboots/reconnects —
    /// migrated to `dockLockAnchorUUID` on first launch. Read once for migration, then unused.
    static let dockLockAnchorDisplay = "dockLockAnchorDisplay"
    /// Anchor display persisted by its stable UUID (`CGDisplayCreateUUIDFromDisplayID`) so the
    /// user's choice survives reboots, sleep/wake, and unplug/replug. Absent = "Default".
    static let dockLockAnchorUUID = "dockLockAnchorUUID"

    /// Analytics & Crashlytics consent (opt-out, default ON).
    /// Stored in the SHARED suite below — NOT the per-app default domain — because helper
    /// bundles run under their own bundle IDs and must read the same value as the main app.
    static let analyticsEnabled = "analyticsEnabled"

    // Popover Appearance — global defaults for every tile's Dock popover (Grid / List).
    // All stored in the SHARED suite so HELPER bundles (which render the popover) read the
    // same values as the main app. Absent → the defaults in `PopoverSettings.default`.
    /// Overall popover width / grid column count. `PopoverSizeTier` rawValue. Default "medium".
    static let popoverSize = "popoverSize"
    /// Icon/cell size within the popover. `PopoverSizeTier` rawValue. Default "medium".
    static let popoverTileSize = "popoverTileSize"
    /// Open/close + content motion. `PopoverAnimationTier` rawValue. Default "default".
    static let popoverAnimation = "popoverAnimation"
    /// Gap + padding between items. `PopoverSpacingTier` rawValue. Default "comfortable".
    static let popoverSpacing = "popoverSpacing"
    /// Grid: show app names under icons. Bool, default ON (absent = ON).
    static let popoverShowLabels = "popoverShowLabels"
    /// Subtle background fill on the hovered item. Bool, default ON (absent = ON).
    static let popoverHighlightOnHover = "popoverHighlightOnHover"

    /// Shared UserDefaults suite readable by the main app and every helper bundle.
    /// Used for cross-process settings like analytics consent and popover appearance.
    static let sharedSuiteName = "com.docktile.shared"
}
