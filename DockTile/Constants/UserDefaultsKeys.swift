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
    /// One-time consent for the "apply Popover Appearance to running tiles" action, which rebuilds
    /// helpers and briefly restarts the Dock. Separate from `hasAcknowledgedDockRestart` so the user
    /// gets one tailored heads-up for this specific action; remembered after the first confirm.
    static let hasAcknowledgedPopoverApplyRestart = "hasAcknowledgedPopoverApplyRestart"
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

    // Popover Appearance — per-layout defaults for every tile's Dock popover. Grid and List are
    // stored INDEPENDENTLY (a grid tile reads the grid keys, a list tile the list keys), all in the
    // SHARED suite so HELPER bundles (which render the popover) read the same values as the main app.
    // Absent → the defaults in `PopoverSettings.default`. Keys are resolved per layout by
    // `PopoverSettings.keys(for:)`; the two size keys are exposed for the General summary row.
    /// Grid popover size (column count). `PopoverSizeTier` rawValue. Default "medium".
    static let popoverGridSize = "popover.grid.size"
    static let popoverGridTileSize = "popover.grid.tileSize"
    static let popoverGridAnimation = "popover.grid.animation"
    static let popoverGridSpacing = "popover.grid.spacing"
    /// Grid only: show app names under icons. Bool, default ON (absent = ON). (List always labels.)
    static let popoverGridShowLabels = "popover.grid.showLabels"
    static let popoverGridHighlightOnHover = "popover.grid.highlightOnHover"
    /// List popover size (width). `PopoverSizeTier` rawValue. Default "medium".
    static let popoverListSize = "popover.list.size"
    static let popoverListTileSize = "popover.list.tileSize"
    static let popoverListAnimation = "popover.list.animation"
    static let popoverListSpacing = "popover.list.spacing"
    static let popoverListHighlightOnHover = "popover.list.highlightOnHover"

    /// Shared UserDefaults suite readable by the main app and every helper bundle.
    /// Used for cross-process settings like analytics consent and popover appearance.
    static let sharedSuiteName = "com.docktile.shared"
}
