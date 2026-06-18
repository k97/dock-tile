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
- The main app stays resident while the lock is enabled (`AppDelegate`
  `applicationShouldTerminateAfterLastWindowClosed`) so the tap survives closing the window.
- Persisted via `UserDefaultsKeys.dockLock*`.