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

**Same-name disambiguation (critical)**: helpers are stored on disk by display name
(`<name>.app`), but two tiles may legitimately share a name. Identity is the unique bundle ID
(`<prefix>.<UUID>`), not the folder — so the write path resolves through `preferredHelperPath`:
clean `<name>.app` when free or already this tile's, else `<name>-<shortId>.app` (pure
`HelperBundleManager.helperFolderName` seam, guarded by `HelperFolderNameTests`). Without this the
second same-named install overwrote the first's `<name>.app` and orphaned it — a broken Dock icon
plus permanent "visible but never pinned" churn (its bundle ID no longer had a bundle on disk).
`findExistingHelper(bundleId:)` still locates the bundle by ID for update/regenerate, so renames and
prior disambiguation are handled; `CFBundleName` keeps the clean human name regardless of folder.

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

**Restart the Dock only when it actually changed (critical)**: every removal path is gated on
real work happening — `removeFromDock(for:)` no-ops (no plist write, no restart, no wait) when the
tile has no Dock entry and no running helper (`shouldPerformDockRemoval` seam), and both it and
`uninstallHelper` restart only when `removeFromDockPlist` reports it actually removed an entry.
`isVisibleInDock` is **not** a presence signal (a never-pinned tile defaults to visible) — gate on
`findInDock`, never the config flag. Regression this kills: every "Done"/delete on a hidden or
never-pinned tile bounced the Dock.

**Tile Detail action button** resolves through the pure `DockTileDetailView.resolveDockAction`
seam: visible → install (Add to Dock / Update, always enabled — Update deliberately re-renders the
helper); hidden+pinned → remove (always enabled); hidden+not-pinned → **saveOnly** — persists edits
without ever calling HelperBundleManager, skips the Dock-restart consent dialog, and is disabled
until new edits (`contentSignature` dirty tracking, which ignores `lastDockIndex` /
`helperAppVersion` / `isVisibleInDock` bookkeeping). While processing, the button shows the spinner
**inside** itself (same pattern as the Popover Appearance Save button), not a separate toolbar
spinner. Guarded by `DockActionResolutionTests`.

## Dock Position Preservation

`lastDockIndex` (v5 field) persists tile position across show/hide toggles. `findDockIndex(bundleId:)` saves position before removal; `addToDock(at:atIndex:)` restores it.

## Dock Plist Watcher & Visibility Sync

`DockPlistWatcher.swift` monitors `com.apple.dock.plist` via `DispatchSource.makeFileSystemObjectSource` to detect manual tile removals and sync `isVisibleInDock` state.

**Visibility ownership (critical invariant)**: `isVisibleInDock` is written **only** by `DockTileDetailView.performDockAction()`, after the Dock add/remove actually completes. The Show Tile toggle must **not** persist visibility via the debounced auto-save — that decoupling caused a "hidden in config but still pinned in Dock" desync that never self-healed. The auto-save preserves the stored visibility/`lastDockIndex`.

`ConfigurationManager.syncDockVisibility(reconcileDockedHiddenTiles:)` reconciles **both** directions: visible-but-absent → mark hidden; and (launch only, `reconcile=true`) hidden-but-still-pinned → actually remove. The destructive direction runs only on the one-shot launch sync, never the live watcher (avoids restart loops).

**Never-pinned guard (critical)**: direction 1 (visible-but-absent → mark hidden) must skip tiles that were **never pinned** — gated on `HelperBundleManager.helperExists(for:)`. A brand-new tile defaults to `isVisibleInDock = true` but has no helper bundle on disk until the user clicks **Add to Dock**; without this guard the reconciler flips it hidden, the action button degrades "Add to Dock" → "Done", and the tile never pins. (A genuinely removed tile keeps its bundle on disk, so the guard only spares new tiles.) This regressed when #5 stopped the editor auto-save re-asserting visibility — the premature hide then stuck instead of bouncing back.

**Helpers must not touch the Dock**: helper processes also construct a `ConfigurationManager` (for popover config), so `init()` returns early via `AppEnvironment.isHelper` before `startDockWatcher()`/`syncDockVisibility()` — only the main app watches/reconciles the Dock, preventing multi-writer races on the config file and Dock plist.

## Sidebar Selection & Empty State

The main window's `SidebarSelection` (a tile, a Settings pane, or the `.tilesPlaceholder`
"No Tiles" row) is the single source of truth driving the detail column; tile selection mirrors
into `ConfigurationManager.selectedConfigId`. Both the empty state and Settings live in the same
detail column, so navigation invariants matter:

- **`.tilesPlaceholder` (critical)**: the "No Tiles" row is a **selectable** placeholder that routes
  to the empty-state detail. Without it, once the user opened a Settings pane at zero tiles there was
  no selectable tile row to click back to, stranding them in Settings. First launch and
  last-tile-deletion both default `selection` to it, so the empty state (not a Settings pane) is what
  appears. `EmptyConfigurationView` takes an `onAdd` closure wired to the **same** `handleAddTapped`
  as the sidebar + (Smart Add if suggestions exist, else a blank tile) — the two entry points must
  not diverge.
- **+ gate must never deadlock (critical)**: the toolbar + is gated by the pure
  `ConfigurationManager.canCreateNewTile(hasSelection:selectedEdited:)` seam — disabled **only** while
  an unedited freshly-created tile is *selected*, always enabled when there's no selection. Gating on
  `selectedConfigHasBeenEdited` alone left + permanently disabled after deleting the last blank tile
  (the flag stayed `false` with zero tiles, nothing to edit to flip it back). `deleteConfiguration`
  also resets the flag to `true` when the list empties so the stored value stays honest. Guarded by
  `ConfigurationManagerTests`.

## Popover Configure Gear Icon

Both `StackPopoverView` (grid) and `ListPopoverView` (list) have a gear icon that opens the main app to configure that tile. Posts `.openConfigurator` notification → `HelperAppDelegate` handles routing via `docktile://configure?bundleId=...` deep link. Routes to correct build: DerivedData for dev, `/Applications/` for release.

Helper bundles have `CFBundleURLTypes` stripped from Info.plist (prevents helpers from claiming the URL scheme).

## Helper Migration Pipeline

`HelperMigrationManager` detects stale helper bundles on main app launch and batch-regenerates them with a single Dock restart.

**Version tracking**: `helperAppVersion` (v6 schema field) stamps which app version built each helper. `nil` = pre-migration, treated as stale. **This per-tile field is the source of truth**; `UserDefaultsKeys.lastMigratedAppVersion` is only a fast-path/bookkeeping marker.

**Flow**: classify every tile (pure `classifyForMigration` seam) → stamp the confident no-rebuild ones → quit + regenerate stale visible+pinned helpers via `regenerateHelperBundle()` → single Dock restart → relaunch the regenerated ones.

**Convergent, not one-shot (critical)**: migration does **not** hard-early-return on `lastMigrated == currentVersion`. It re-derives per-tile state from `helperAppVersion` each launch, so a tile left stale by a previous run **retries until it succeeds** (the loop is cheap when all are current — each is `skipUpToDate` with no probe). This fixes the "some very-first bundles never migrated" class: a single transient miss no longer stamps a tile "migrated" forever.

- **Reliable reads (critical)**: every Dock read (`findInDock`/`findDockIndex`/`isInDock`/`addToDock`) calls `CFPreferencesAppSynchronize("com.apple.dock")` **before** `CFPreferencesCopyAppValue` — reading another app's domain can return a cold/stale cfprefsd cache (notably right after login), which used to make `findInDock` miss genuinely-pinned tiles and skip them.
- **Stamp on SUCCESS only (`runRegenerationBatch`)**: a failed regeneration is left **unstamped** so it retries next launch (heals a killed-mid-generation / transient-FS failure), reversing the old "stamp anyway". Failures never restart the Dock (only successes do), so a persistently-broken tile can't churn it.
- **Translocation pre-flight**: if `AppRelocationManager.canGenerateBundles` is false, the regenerate batch is **skipped entirely** (not force-quit-then-fail) and tiles are left stale to retry once the app is moved — the launch relocation nudge asks the user.
- **Completion**: `lastMigratedAppVersion` is stamped only when **no visible tile remains stale** (fully converged); otherwise it's left so the next launch retries the remainder.
- **Edge cases**: not visible → `stampOnly` (rebuilds via `installHelper` when next shown). Visible + no bundle on disk → `stampOnly` (repair is the deferred version-independent self-heal, not the normal pass).

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

## Popover Appearance (per-layout settings)

Moved to its own rule: [Popover Appearance](popover-appearance.md) — per-layout Grid/List configs,
shared-suite persistence, draft/Save/apply-to-running-helpers flow, PopoverMetrics seam, live preview.
