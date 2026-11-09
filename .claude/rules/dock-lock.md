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
  `didChangeScreenParameters` (display reconfig), which re-resolves the setup's anchor (below).

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
- **At login** the spawner starts the main app quietly for Dock Lock only when the connected displays
  have an anchor to hold (`DockLockManager.storedAnchor`, the same rule as the engine) and Accessibility
  is granted (menu-bar.md). It used to start nothing, so Dock Lock waited for the user to open Dock Tile.
  Accepted risk: a display not yet enumerated when the spawner runs makes a known setup read as unknown.
- **One anchor per display setup (#37, 2026-11-08).** A setup = the EXACT set of connected displays
  (`connectedDisplayUUIDs()`: CoreGraphics, mirrors once), keyed by `setupKey` (UUIDs sorted, joined).
  `dockLockSetupAnchors` maps setup key → anchor UUID, `""` = Default picked there. The picker sets the
  CURRENT setup's entry only (`remembered(_:picking:connected:)`); there is no setups list (owner).
  `resolveAnchor` (`DockLockSetupTests`): one display → nothing; own entry wins (`""` included); else the
  pre-#37 single anchor (`dockLockAnchorUUID`; written only by the one-time raw-ID migration, never removed) when connected — so
  nothing changed on update; else **unknown setup → leave the Dock alone**, even with another setup's
  anchor connected. Reader and writer build the key from `connectedDisplayUUIDs()`, never `displays`
  (NSScreen), which can disagree mid-burst.
- **Every display change moves at most once, after it settles**: the live anchor and clamp zones change
  at once (`resolveAnchorFromPersisted`), the Dock moves 1.5 s after the last change of a burst
  (`scheduleMoveAfterDisplayChange`, reason `displays_changed`), only while an anchor is connected beside
  another display. A dock adds displays one at a time and each in-between set is its own setup, so an
  immediate move warped the cursor once per step (plan gate, 2026-11-08); the old instant
  `display_reconnected` move is gone. The `Setup of N displays → anchor X` log line fires only when the
  anchor CHANGES, so a display change that keeps the anchor leaves no line: read the setup from
  `defaults read com.docktile.dev.app dockLockSetupAnchors` (hands-on, 2026-11-08).
- **Anchors are stored by display UUID** (`CGDisplayCreateUUIDFromDisplayID`), NOT the raw
  `CGDirectDisplayID` — IDs reshuffle across reboot/sleep/replug. `anchorDisplayID` is the live resolved
  value (`private(set)`, `0` = nothing to hold here). Legacy `dockLockAnchorDisplay` int is migrated
  once into `dockLockAnchorUUID`, then dropped. Identical monitors without serial numbers can share a
  UUID; AirPlay/Sidecar displays may not keep one (unmeasured) — such a setup can read as unknown.