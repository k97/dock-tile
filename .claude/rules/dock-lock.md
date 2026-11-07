# Dock Lock

Pins the macOS Dock to one ("anchor") display so it stops jumping between screens on
multi-monitor setups. A **global app feature**, not a per-tile property.

## Engine (`DockLockManager`)

Single `@MainActor` `ObservableObject` singleton — the only access point.

- Installs a `CGEvent` tap (`.cgSessionEventTap`, `.defaultTap`) on mouse-move/drag. In the
  callback it clamps the cursor out of the Dock-trigger band on **non-anchor** displays, so
  macOS never relocates the Dock there. The anchor display is untouched.
- Reads the Dock's `orientation` from `com.apple.dock` (CFPreferences) to build the band on
  the correct edge — works with bottom, left, or right Docks.
- **Exposed-segment detection**: only clamps edge segments not backed by an adjacent display,
  so the cursor can still cross between monitors (matters for side-by-side layouts).
- Recomputes trigger zones live via `DockPlistWatcher` (orientation change) and
  `didChangeScreenParameters` (display reconfig). Falls back to the main display if the
  anchor is unplugged.

## Accessibility permission (TCC)

An active event tap requires Accessibility access. Requested only on enable; grant detected
via `didBecomeActive` + the `com.apple.accessibility.api` notification + the pane's `.onAppear`
(no polling). **Dev-build signing caveats and the full permission UX live in
[docs/dock-lock-accessibility.md](../../docs/dock-lock-accessibility.md).**

## UI & lifecycle

- Controls live in the Settings window (⌘,) → **Dock Lock** tab (`DockLockSettingsView`).
- Toggle on → permission UX → an anchor **picker** appears. First option is **Default** (`id 0`,
  no clamping, Dock follows macOS); the rest are the connected displays. Selecting one is
  **real-time**: `selectAnchor(_:)` persists, recomputes zones, and `moveDockToAnchor()` nudges
  the Dock onto it immediately (cursor warp to the Dock edge — the only available "move" hook).
  A `lock.fill` indicator confirms the locked display. No separate "Move Dock" button.
- `apply()` re-asserts the Dock onto the anchor on enable / permission grant / **relaunch** (so a
  reboot that drifted the Dock self-heals); no-op for Default.
- The main app stays resident while the lock is enabled so the tap survives closing the window: the
  rule `AppDelegate.staysResident(dockLock:menuBar:)`, shared with the menu bar icon (menu-bar.md), drives
  `applicationShouldTerminateAfterLastWindowClosed`. A resident app installs updates while idle.
- **At login** the spawner starts the main app quietly for Dock Lock only when the stored anchor display
  is connected beside another and Accessibility is granted (`DockLockManager.anchorIsActionable`,
  menu-bar.md). It used to start nothing, so Dock Lock waited for the user to open Dock Tile.
- **A display change with the anchor unchanged** (docking a MacBook whose own screen is the anchor)
  schedules one re-check 1.5 s later, cancelled by the next change, only while anchored with 2+ displays
  (`scheduleMoveAfterDisplayChange`); the anchor reconnecting moves at once, as before.
- **Anchor persisted by display UUID** (`dockLockAnchorUUID`, via `CGDisplayCreateUUIDFromDisplayID`),
  NOT the raw `CGDirectDisplayID` — IDs reshuffle across reboot/sleep/replug. `anchorDisplayID` is
  the live resolved value (`private(set)`, `0` when the chosen display is absent); the stored UUID
  is the durable intent. Legacy `dockLockAnchorDisplay` int is migrated once then dropped.
  `resolveAnchorFromPersisted()` re-derives the live ID on `didChangeScreenParameters` without
  forgetting the choice — unplug → Default, replug → re-anchors and re-nudges.