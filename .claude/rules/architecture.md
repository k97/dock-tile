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

## User Consent for Dock Modifications

One-time consent dialog (NSAlert) before any Dock-modifying action. Preference stored as `UserDefaultsKeys.hasAcknowledgedDockRestart`. Covers add, update, show, hide, and remove operations.
