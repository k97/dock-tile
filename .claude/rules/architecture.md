# Architecture

## Multi-Instance Model

Users create Helper Bundles (copies of main app) stored in `~/Library/Application Support/DockTile/`. Each maintains independent app lists and icons. Shared config at `~/Library/Preferences/com.docktile.configs.json`.

## Helper Bundle Lifecycle

**Creation** (`HelperBundleManager.installHelper`):
1. Copies main DockTile.app as template
2. **Removes `Assets.car`** — prevents main app icon overriding custom icons (macOS prioritises asset catalogs over `CFBundleIconFile`)
3. Updates Info.plist (unique bundle ID, name, LSUIElement based on mode)
4. Generates `.icns` icon for all 4 style variants
5. Code signs with ad-hoc signature
6. Saves/restores Dock position, restarts Dock, launches helper

**Runtime** (`HelperAppDelegate`): Sets activation policy based on Ghost/App mode, shows NSPopover on click.

**Deletion** (`HelperBundleManager.uninstallHelper`): Quits helper → removes from Dock plist → deletes bundle → restarts Dock. Uses `async Task.sleep` (not sync `Thread.sleep`).

## Ghost Mode vs App Mode

macOS constraint: no supported way to have Dock icon + hidden from Cmd+Tab + working context menu simultaneously.

| Mode | `showInAppSwitcher` | `LSUIElement` | Cmd+Tab | Context Menu |
|------|---------------------|---------------|---------|--------------|
| Ghost (default) | `false` | `true` | Hidden | No |
| App | `true` | Not set | Visible | Yes |

Set in `HelperBundleManager.updateInfoPlist()` (build time) and `HelperAppDelegate.applicationWillFinishLaunching()` (runtime).

## NSPopover Positioning

`FloatingPanel.swift` anchors to Dock edge using `visibleFrame` boundary (not mouse position):
- Compares `NSScreen.main.frame` vs `visibleFrame` to detect Dock side (largest gap = Dock location)
- Anchors flush to `visibleFrame.minY/minX/maxX` — mouse coordinate only for the axis parallel to the Dock
- `NSVisualEffectView` with `.popover` material for native vibrancy
- Keyboard navigation via `KeyboardCaptureView` (custom NSView)

## Dock Integration (CFPreferences API)

All Dock plist operations use `CFPreferencesCopyAppValue`/`CFPreferencesSetAppValue` with `"com.apple.dock"`. Matches industry tools (dockutil), avoids `cfprefsd` cache sync issues from direct plist file writing.

Race condition prevention: `installingBundleIds` and `removingBundleIds` Sets prevent double operations.

## Dock Position Preservation

`lastDockIndex` (v5 field) persists tile position across show/hide toggles. `findDockIndex(bundleId:)` saves position before removal; `addToDock(at:atIndex:)` restores it.

## Dock Plist Watcher & Visibility Sync

`DockPlistWatcher.swift` monitors `com.apple.dock.plist` via `DispatchSource.makeFileSystemObjectSource` to detect manual tile removals and sync `isVisibleInDock` state.

**Visibility ownership (critical invariant)**: `isVisibleInDock` is written **only** by `DockTileDetailView.performDockAction()`, after the Dock add/remove actually completes. The Show Tile toggle must **not** persist visibility via the debounced auto-save — that decoupling caused a "hidden in config but still pinned in Dock" desync that never self-healed. The auto-save preserves the stored visibility/`lastDockIndex`.

`ConfigurationManager.syncDockVisibility(reconcileDockedHiddenTiles:)` reconciles **both** directions: visible-but-absent → mark hidden; and (launch only, `reconcile=true`) hidden-but-still-pinned → actually remove. The destructive direction runs only on the one-shot launch sync, never the live watcher (avoids restart loops).

**Never-pinned guard (critical)**: direction 1 (visible-but-absent → mark hidden) must skip tiles that were **never pinned** — gated on `HelperBundleManager.helperExists(for:)`. A brand-new tile defaults to `isVisibleInDock = true` but has no helper bundle on disk until the user clicks **Add to Dock**; without this guard the reconciler flips it hidden, the action button degrades "Add to Dock" → "Done", and the tile never pins. (A genuinely removed tile keeps its bundle on disk, so the guard only spares new tiles.) This regressed when #5 stopped the editor auto-save re-asserting visibility — the premature hide then stuck instead of bouncing back.

**Helpers must not touch the Dock**: helper processes also construct a `ConfigurationManager` (for popover config), so `init()` returns early via `AppEnvironment.isHelper` before `startDockWatcher()`/`syncDockVisibility()` — only the main app watches/reconciles the Dock, preventing multi-writer races on the config file and Dock plist.

## Popover Configure Gear Icon

Both `StackPopoverView` (grid) and `ListPopoverView` (list) have a gear icon that opens the main app to configure that tile. Posts `.openConfigurator` notification → `HelperAppDelegate` handles routing via `docktile://configure?bundleId=...` deep link. Routes to correct build: DerivedData for dev, `/Applications/` for release.

Helper bundles have `CFBundleURLTypes` stripped from Info.plist (prevents helpers from claiming the URL scheme).

## Helper Migration Pipeline

`HelperMigrationManager` detects stale helper bundles on main app launch and batch-regenerates them with a single Dock restart.

**Version tracking**: `helperAppVersion` (v6 schema field) stamps which app version built each helper. `nil` = pre-migration, treated as stale.

**Flow**: Check `UserDefaultsKeys.lastMigratedAppVersion` → find stale visible helpers → quit → regenerate bundle in-place via `HelperBundleManager.regenerateHelperBundle()` → single Dock restart → relaunch all.

**Edge cases**: Missing bundle on disk → stamp and skip. Not in Dock → stamp and skip. Regeneration fails → log error, stamp version anyway (no retry loop). Already migrated → immediate return.

## Missing App Detection

Tiles reference apps by `bundleIdentifier` (+ `lastKnownPath`, v8). When an app is uninstalled,
`AppIconLoader` used to fall back to the cached `iconData` and paint the **stale icon at full
opacity**, hiding the "app is gone" state. Detection now flags those apps instead.

- **Two-signal check**: `AppItem.lastKnownPath` (v8 field, stamped on add, healed on scan) is a
  second installation signal beside the bundle ID. Distinguishes a real uninstall from a
  transiently-unregistered Launch Services entry, and lets a **moved/updated** app self-heal by
  re-resolving rather than being flagged.
- **Pure seam**: `AppInstallChecker.classifyInstallStatus(bundleResolves:onDiskPathExists:)` →
  `.installed` / `.missing` (in `AppIconLoader.swift`, unit-tested). Installed = LS resolves the
  bundle ID **or** an app bundle exists on disk (last-known path / common dir); else missing. A
  cached `iconData` is **not** an install signal — it's DockTile's own snapshot. (An earlier
  `.unknown` case exempted pre-v8 entries that had a cached icon but no path; since *every* legacy
  entry fits that shape, any app uninstalled before upgrading was permanently un-flagged and kept
  its stale icon. Removed — detection is non-destructive, so flag it; a rare transient miss
  self-heals next scan.)
- **Sweep**: `ConfigurationManager.scanForMissingApps()` runs **once per session** on window launch
  (after migration), throttled like `lastMigratedAppVersion`. Cheap — LS lookups + `stat()`, no
  icon rasterisation. **Main-app only** (`AppEnvironment.isHelper` guard), heals paths, publishes
  `missingAppIDs`.
- **UX is non-destructive** (critical): missing apps render a distinct `questionmark.app.dashed`
  placeholder (dimmed + "Not installed"), never the stale icon. A consolidated **Remove / Keep**
  alert is the *only* path that deletes — detection flakiness must never cause silent data loss.
  Helper popovers resolve status **synchronously** in the view body so a deleted app never flashes
  its stale icon before the placeholder.

## User Consent for Dock Modifications

One-time consent dialog (NSAlert) before any Dock-modifying action. Preference stored as `UserDefaultsKeys.hasAcknowledgedDockRestart`. Covers add, update, show, hide, and remove operations.

## Popover Appearance (global settings)

Six **app-wide** settings tune every tile's Dock popover (Grid + List): Popover Size, Tile Size,
Animation, Spacing, Show Labels, Highlight on Hover. Reached via **Settings → General → Popover
Appearance** — a `NavigationStack` drill-down inside `GeneralSettingsView` (NOT a separate sidebar
pane), titled "Popover" with a "‹ General" back. Per-tile Grid/List still lives on Tile Detail.

- **Persistence**: all six keys live in the **shared suite** (`com.docktile.shared`, like analytics
  consent), so HELPER processes — which actually render the popover — read the same values. Defaults
  in `PopoverSettings.default` keep absent keys roomy. Model: [PopoverAppearance.swift](../../DockTile/Models/PopoverAppearance.swift).
- **Explicit save (draft/commit), NOT auto-save**: the pane is no longer `@AppStorage`-backed.
  Edits stage into a `@State draft: PopoverSettings`; only the **Save** toolbar button writes them to
  the shared suite via `PopoverSettings.persist()` (the symmetric counterpart to `load()`). A
  `savedBaseline` drives dirty state. **Reset to Defaults** stages `.default` into the draft (still
  needs Save to commit). HIG toolbar placement (`.primaryAction`): Reset is a secondary **icon-only**
  button (`arrow.counterclockwise`, `.bordered`, `.labelStyle(.iconOnly)`) with a `.help("Reset to
  Defaults")` tooltip + accessibility label; Save is the trailing primary (`.borderedProminent`, ⌘S).
  Save disables when not dirty, Reset when already at defaults. The live preview renders the **draft** (not the shared suite) via a new
  `settingsOverride: PopoverSettings?` param on `StackPopoverView`/`ListPopoverView` (nil in the real
  popover, which always loads saved values), so unsaved edits preview without persisting.
- **Pure metrics seam** (`PopoverMetrics`, `PopoverSettings.resolve`): the single source of truth
  mapping tiers → concrete sizes. Drives BOTH the live preview and the real `StackPopoverView` /
  `ListPopoverView`, so they can't drift. Unit-tested (`PopoverMetricsTests`). Popover Size = grid
  column count (Small 4 / Medium 5 / Large 6) **capped at the app count** so few-app tiles stay tight
  — meaning Popover Size is a visual no-op for a tile with ≤4 apps (the preview uses 6 sample apps so
  all three tiers differ). Animation is forced to 0 when system Reduce Motion is on.
- **Live preview = the real panels** (critical): the hero embeds the actual `StackPopoverView` /
  `ListPopoverView` (not a mock) for true 1:1 fidelity, re-`.id()`'d on every control change so they
  re-read `PopoverSettings.load()`. Two view flags keep this safe (both default to shipping
  behaviour): `showsBackground:false` lets the preview supply its own popover chrome (NSPopover's
  rounded surface is lost when embedding the bare content view — reproduce it with the `.popover`
  material `withinWindow` + ~14pt continuous corner + shadow); `isPreview:true` keeps the panel
  interactive for hover yet neutralises every action (clicks never launch apps / open the
  configurator). The preview hero sits on the shared `StudioCanvasBackgroundView` (same
  `underWindowBackground` treatment as the Customise-Tile studio).
- **Hover highlight**: mouse hover uses the subtle Liquid-Glass `.quaternary` fill (the Tahoe
  treatment), NOT the bold accent — the accent is reserved for keyboard-focus selection. Applies to
  the real popover too. The preview scales with `.scaleEffect` (a *fixed* per-layout fit, not a
  width-refill, so Spacing changes stay visible); `.scaleEffect` preserves `.onHover` hit-testing.
