# Menu Bar Icon (issue #13)

An optional menu bar icon listing the tiles in the Dock and their apps. A **global app feature**, main app
only. Shipped as a native `NSMenu`; a Control Centre-style panel was mocked up and deferred (owner,
2026-11-07: "keep it simple for the first release").

## Owner and menu

- `MenuBarController.shared` (`@MainActor`) owns the ONE `NSStatusItem`. `apply(enabled:)` is
  idempotent; the image is the brand glyph (`SFSymbolCatalog.brandGlyph`) copied at 18×18 as a template.
- The menu is rebuilt in `menuNeedsUpdate`, so tiles, install state and icons are current on every open.
- **One builder, two menus**: `TileMenu.tileItems` builds the tile part of both the menu bar menu and the
  main app's own Dock menu (`AppDelegate.applicationDockMenu`, which used to list only the selected
  tile's apps). Tiles in sidebar order, only `isVisibleInDock` ones (owner decision); each submenu is
  built lazily: its apps (missing ones greyed), then **Configure Tile…**, the same path as a tile's gear
  link (`revealTile` → `docktile://configure`). Launches go through `AppLauncher.launch` (source
  `menu_bar` / `main_dock_menu`). Guarded by `TileMenuTests`.
- Zero tiles → **Add a Tile…** (the sidebar `+` path, `handleAddTapped(source: .menuBar)`, posted on the
  next turn so a just-recreated window is subscribed). Always last: **Open Dock Tile…**, **Quit Dock
  Tile** (⌘Q).

## Setting

`UserDefaultsKeys.menuBarEnabled`, main-app domain. **Seeded once** in `configureAsMainApp`, before
`HasLaunchedBefore` is written: ON for a new install, OFF for an existing user
(`MenuBarController.initialEnabled`, `MenuBarDefaultTests`). Absent reads OFF for any reader that runs
before the main app ever has (the login spawner). UI: General's "Menu Bar" section, before "Adding
Tiles". Analytics: `setting_changed` with `setting: "menu_bar"`; no new event.

## Lifetime and Dock icon

- **Stays running with the window closed while Dock Lock or the icon is on**:
  `AppDelegate.staysResident(dockLock:menuBar:)` drives `applicationShouldTerminateAfterLastWindowClosed`.
- With the icon on, Dock Tile's own Dock icon shows only while its window is open: `windowWillClose` →
  `.accessory`, `showConfigurationWindow` → `.regular`; turning the icon off → `.regular`.
- **Ordering out the only window counts as the last window closing**: with nothing keeping it resident,
  a hidden-window app calls `terminate:` within half a second (measured 2026-11-06).

## Quiet launch at login (critical)

- `LoginTileSpawner` launches the helpers, then — after their launches are acknowledged, because the main
  app's migration may rebuild them — the main app with `--quiet-launch`, `createsNewApplicationInstance`
  (the spawner already has the bundle id), not activated. Decided BEFORE the no-visible-tiles exit (every
  tile hidden + the icon is a real setup), by `launchesMainApp(menuBarEnabled:dockLockReady:mainAppPids:ownPid:)`:
  the spawner's own pid never counts as a running main app (`LoginSpawnPlanTests`). It logs
  `main app starts|stays closed (menu bar N, Dock Lock ready N)`.
- **Dock Lock starts it too, but only with its display to hold (owner, 2026-11-07: "contextual, only the
  last configured display")**: enabled, Accessibility granted (`AXIsProcessTrusted()`, never a prompt) and
  `DockLockManager.anchorIsActionable` — the stored anchor UUID among the connected displays
  (`connectedDisplayUUIDs`, CoreGraphics so it works without an `NSApplication`, a mirror counted once)
  and not the only one (`DockLockReadinessTests`). Before 2026-11-07 nothing started the main app at login
  for Dock Lock: it ran only once the user opened Dock Tile.
- `AppEnvironment.isQuietLaunch` (latched): the argument, or the idle-install relaunch flag (below).
  `.accessory` in `applicationWillFinishLaunching` ONLY while the menu bar icon is on — a Dock Lock-only
  quiet launch keeps its Dock icon, or nothing would show Dock Tile is running; the relocation nudge and the translation invitation
  wait for a normal launch; launch maintenance DOES run (owner: at most one Dock restart, first login
  after an update).
- **The window is created, then hidden — never suppressed (critical).** Its `onAppear` hands over the
  manager and SwiftUI's `openWindow` (Open Dock Tile…, Configure Tile…, deep links) and its `.task` runs
  launch maintenance; without the window all of that is dead. SwiftUI has ordered it in, undrawn, by
  `applicationDidFinishLaunching`, so `hideQuietLaunchWindow()` sets `alphaValue = 0` + `orderOut` there;
  `showConfigurationWindow` restores alpha 1. Proven with a ~2 ms window-server probe
  (`CGWindowListCopyWindowInfo` by pid — metadata only; a screen recording films the owner's screen):
  0 visible samples in every quiet run, 1182/1182 on a normal launch.
- **AppKit window restoration is ignored** (`ApplePersistenceIgnoreState` registered in `main.swift`):
  after an UNCLEAN exit (crash, Force Quit, SIGTERM) the saved state says "no windows" and SwiftUI then
  creates none on the next launch, quiet or normal — `.defaultLaunchBehavior(.presented)` did not change
  that. The frame survives (`NSWindow Frame com.docktile.configuration` is separate). The same is why a
  dev relaunch should quit gracefully (`osascript -e 'tell application id "com.docktile.dev.app" to quit'`),
  never `kill`.
- **One main app at a time**: `main.swift` holds `TileBuildLock` on `<support>/main-app.lock` for the
  process's life (`withExtendedLifetime`; an optimised build may release a local early). The spawner's
  new instance and "Reopen windows when logging back in" can start together. A loser waits up to 5 s,
  because the move to /Applications launches the new copy before the old one quits. Then
  `MainAppLock.outcome` (`MainAppLockTests`, incl. a real two-open test): only `EWOULDBLOCK` is "another
  copy" — any other open error runs WITHOUT the lock, never refuses to open; a user's launch hands off
  (posts `AppDelegate.showWindowRequest`, a per-environment distributed notification the running copy
  answers with `showConfigurationWindow` — its Dock icon may be hidden) and exits. NOT Launch Services:
  `openApplication(at:)` from the losing process reopened that process itself, and nothing appeared
  (reproduced 2026-11-07). macOS 14+ refuses a background app's `activate`, so the window opened BEHIND
  the frontmost app (window-order check, 2026-11-07): `showWindowForSecondLaunch` raises it with
  `orderFrontRegardless` (focus stays put until the user clicks it). Observed from
  `applicationWillFinishLaunching`, so a request during the login race is not dropped. Spoofable by any
  local process; worst case the window opens;
  a quiet loser just exits. It reads the argument, not `isQuietLaunch`, which would clear the idle-install
  flag. Skipped under the test host (it runs beside the dev app).

## Install updates while idle

Sparkle installs a silently downloaded update at quit, and a resident Dock Tile rarely quits. While
`staysResident`, `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)` returns YES and
`IdleInstaller` holds the handler, checking every 60 s ONLY while one is held. It installs when
`IdleInstall.shouldInstall` holds: the configuration window neither `isVisible` (a hidden quiet-launch
window still exists) nor minimised, no Dock operation in flight for any tile, ≥ 600 s without input
(`kCGAnyInputEventType` = `CGEventType(rawValue: ~0)`; `.null` is event 0 and reads far older). It writes
`relaunchQuietlyAt` first; the relaunch is quiet only if the flag is under 120 s old, and clears it
(`IdleInstallTests`). Not resident: NO, unchanged.

- **Risk:** YES stalls Sparkle's update cycle, its "impatient" prompt included, until the handler runs or
  the app quits. A trigger that never fires stops updates for resident users with no remote fix.
- **End-to-end recipe (passed 2026-11-07, keep for any change here):** copy the Debug product twice into
  scratch (A = installed, B = update with only `CFBundleVersion` bumped — a marketing-version change
  would run migration on the dev tiles); point both `SUFeedURL`s at `http://127.0.0.1:<port>/appcast.xml`
  (Sparkle downloads only over http/https: a `file://` feed fails with 2001) and their `SUPublicEDKey` at
  a throwaway Ed25519 key made with CryptoKit, NEVER `generate_keys` (it writes the login keychain beside
  the real key); re-sign with `--preserve-metadata=entitlements,flags`; zip B, sign it, serve the folder
  with `python3 -m http.server`; shorten the threshold with an uncommitted `defaults`-read edit; set
  `SULastCheckTime` old; quit the dev app (it holds the lock); launch A quietly; leave the Mac. Afterwards
  `lsregister -u` the copies — the login agent finds the app by bundle id.

## Gotchas

- **A menu bar manager hides new icons** (Thaw, Ice, Bartender): the item is created, `isVisible` is
  true, its frame has zero height and it has no AX element. Ask about one before debugging. macOS 26+
  also has System Settings → Menu Bar → "Allow in the Menu Bar"; switched off, Dock Tile runs invisibly
  and is reached by opening it from Finder or Spotlight (the reopen shows the window).
- **A stale dev product can run at login**: the login agent and Launch Services resolve
  `com.docktile.dev.app` by bundle id, and on 2026-11-07 a leftover worktree product started beside the
  current one (it predated the lock). Delete a worktree's DerivedData with the worktree
  (driving-the-dev-build.md).
- Menu build cost (#39, Debug test host, 2026-11-08): 12 tiles (App Grid / Symbol / Emoji, 9 apps
  each) build in 14 ms the first time and 7 ms after; a 9-app submenu fills in 1 ms. The first
  `ImageRenderer` use in a process costs ~50–200 ms once, which the window's sidebar has normally
  paid already. Under the 50 ms bar, so no icon cache; add one keyed by `iconSignature` only if a
  `✔ Build … menu` line says otherwise.
- Not run on hardware: the display-change re-check (#38).
