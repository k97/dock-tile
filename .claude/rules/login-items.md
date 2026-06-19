# Start Tiles at Login

Warms every visible tile's helper process at login so they respond instantly, instead of
launching on first click. A **global app feature**, ON by default (opt-out).

## Engine (`LoginItemManager`)

Single `@MainActor` singleton — the only access point. State lives in **SMAppService**, not a
config field.

- Registers ONE launcher agent (`SMAppService.agent(plistName:)`), a plist bundled at
  `Contents/Library/LaunchAgents/<bundleId>.tilelauncher.plist`. It runs the main binary headless
  with `--login-spawn-tiles`. WHY one agent (not one per tile): SMAppService can't manage the
  external ad-hoc-signed helpers, and per-tile agents are noisy/"Unknown" in System Settings.
- Plist name derives from `AppEnvironment.mainAppBundleId`, so dev/release pick separate agents.

## Login spawn path (`LoginTileSpawner`)

`run()` fires only when the binary is launched with `--login-spawn-tiles`. It launches every
`isVisibleInDock` helper in the background then `exit(0)` — **never** creates an `NSApplication`
(no Dock icon/window at login). Deliberately self-contained: does NOT touch ConfigurationManager
or HelperBundleManager (avoids DockPlistWatcher side effects + MainActor before the run loop).

## Opt-out model (ON by default)

- Persisted as `UserDefaultsKeys.startAtLoginOptedOut` (main-app domain, default `false` → ON).
  SMAppService `status` alone can't distinguish "user turned it off" from "macOS dropped it", so
  the opt-out flag is the durable intent.
- `enable()` clears opt-out + `register()`; `disable()` sets opt-out + `unregister()`.

## Reconcile on launch (Sparkle fix)

`reconcileOnLaunch()` (called from `AppDelegate.configureAsMainApp`) registers the agent whenever
`shouldBeEnabled` and it isn't already enabled. This both auto-enables new users AND re-asserts
after a **Sparkle update** — replacing the app bundle demotes the SMAppService item to
`.requiresApproval`/`.notRegistered`, which previously read as the toggle silently turning off.

## UI

`GeneralSettingsView` toggle reflects `isEnabled || requiresApproval` (so a held-for-approval item
still reads ON, with an "Open Login Items" approval button). An `onChange` guard ignores
programmatic syncs so refreshing state never re-registers in a loop.
