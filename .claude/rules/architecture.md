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

**The Dock label is the display name, never the folder stem (critical)**: the Dock renders a
`persistent-apps` entry's `file-label` **verbatim** as the tile's tooltip and never re-derives it
from Launch Services (verified: rewriting the field + `killall Dock` sticks), so `addToDock` writes
it through the pure `HelperBundleManager.dockFileLabel` seam (`CFBundleDisplayName` →
`CFBundleName` → stem; guarded by `DockFileLabelTests`). It used to write the folder stem, so the
second same-named tile's tooltip read `Utils-B4EF96A2`. Finder/Spotlight still show the folder name
(Apple's documented rule: a bundle's `CFBundleDisplayName` is honoured only when it matches the
file-system name — see [docs/dock-tile-display-names.md](../../docs/dock-tile-display-names.md)),
which is acceptable; Cmd-Tab / Force Quit already use the bundle's display name. The Dock plist
schema itself is undocumented (dockutil also writes the path stem) — there is no public API for a
pinned tile's label. Existing wrong labels self-heal on the next version-bump migration, because
`refreshDockEntry` re-seats every pinned entry through `addToDock`.

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

`FloatingPanel.swift` anchors via the pure seam `FloatingPanel.resolveAnchor` +
`DockPrefs.read()` (guarded by `FloatingPanelAnchorTests`), resolved once per open —
**anchor-and-hold**, never chased (the real Dock's stack popover holds its body when
magnification collapses; only its tail tracks, which nothing public can replicate).

- **Orientation from the pref, never gap inference (critical)**: `DockPrefs.read()`
  (synchronize-first, per-open) supplies `orientation`/`magnification`/`tilesize`/`largesize`/
  `autohide`; `DockLockManager.currentDockEdge()` delegates to it. An auto-hidden Dock reserves
  **zero** `visibleFrame` on every screen, so the old largest-gap detection had no signal there.
- **Magnification clearance (critical)**: magnified icons overdraw *above* the reserved
  `visibleFrame` band, and every readable source (AX tree, CGWindow bounds, `CoreDockGetRect`)
  reports only the RESTING layout while icons are magnified — so the anchor lifts to the
  worst-case envelope `largesize + 25` (matches DockAltTab, the only shipping tool that
  compensates). The clicked icon is under the cursor, so it IS at full largesize. Without this
  the popover pinned on top of the magnified icon. `largesize ≤ tilesize` → no lift; clearance
  capped at 40% of the screen axis (defends against `defaults write largesize 512`).
- **Autohide**: measured gap < 20pt ⇒ fall back to `tilesize + 25` (the click proves the Dock
  is revealed right now). Resting clearance otherwise uses the *measured* gap, which
  self-corrects when a crowded Dock auto-shrinks below the `tilesize` pref.
- **Screen = the one under the mouse** (a Dock click lands on the Dock's display), not
  `NSScreen.main` (the key window's screen — differs on multi-display, e.g. with Dock Lock).
- Mouse coordinate only for the axis parallel to the Dock (best icon-centre estimate without
  AX — which helpers can't get: per-binary TCC grants, regenerated bundles). NSPopover slides
  its arrow within the preferred edge near screen corners; no lateral compensation needed.
- `NSVisualEffectView` with `.popover` material for native vibrancy
- Keyboard navigation via `KeyboardCaptureView` (custom NSView)

## Dock Integration (CFPreferences API)

All Dock plist operations use `CFPreferencesCopyAppValue`/`CFPreferencesSetAppValue` with `"com.apple.dock"`. Matches industry tools (dockutil), avoids `cfprefsd` cache sync issues from direct plist file writing.

Race condition prevention: `installingBundleIds` and `removingBundleIds` Sets prevent double operations.

**The dying Dock can undo your write (critical)**: `killall Dock` only *signals* the Dock — a Dock
still holding the previous `persistent-apps` in memory flushes that stale list back to cfprefsd as it
exits, silently reverting the add or removal just written (this is the `'<tile>' STILL in Dock after
restart` line, and the "had to press hide twice" symptom). Distinct from the stale-*read* problem the
synchronize-first reads defend against. So every Dock mutation must **verify** afterwards rather than
assume it stuck: `installHelper` re-adds + restarts if `findInDock` misses, and `removeFromDock(for:)`
retries via `quitDockAndWaitForExit()` — re-writing with the Dock process actually gone, so nothing
is left alive to flush over us. Measured 2026-08-29: plain write-then-`killall` stranded 7 entries
under concurrent restarts while a single quit-then-write pass cleared them; on a settled Dock the
plain path succeeded 12/12, so it stays the fast path and quit-and-wait is the retry only.

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
spinner. Guarded by `DockActionResolutionTests`. The button lives in the title band
(`ToolbarItemGroup(.primaryAction)`, trailing the trash/Delete Tile icon); install actions render
`.borderedProminent`, remove/saveOnly render `.bordered`.

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
detail column, so navigation invariants matter.

**v2 chrome**: the window has no title (`.toolbar(removing: .title)` on
`DockTileConfigurationView`) — the 52pt title band IS the page header (`paneTitleBand`, see "Tile
editor" below), and it carries the pane's **title text only, no pane icon**. The sidebar keeps the
**standard macOS header pair — the collapse toggle and `+`** (as in Notes/Reminders); v2 briefly
removed the toggle via `.toolbar(removing: .sidebarToggle)` and that was **deliberately reverted**,
so do not re-add it. The sidebar is three **static** sections — **Tiles · Settings (General,
Popover, Dock Lock) · Dock Tile (About)** — the old accordion `@AppStorage` expand state is gone.

- **Window-level chrome (AppKit, `WindowAccessor.configureWindow`)**: `titlebarAppearsTransparent
  = true`, `titleVisibility = .hidden`, `toolbarStyle = .unified` — these three are what actually
  collapse the native title bar into the toolbar strip that the SwiftUI-level `.toolbar(removing:)`
  call then repurposes as the title band. `.toolbar(removing: .title)` alone is not enough without
  this AppKit trio; `WindowAccessor` is an `NSViewRepresentable` bridge run once on `makeNSView`
  and again on every `updateNSView`.
- **`ToolbarSpacer(.flexible)` must ride in the SAME `.toolbar {}` call as the title (critical)**:
  `PaneTitleBandWithActions` builds `paneTitleItem` (the title), `ToolbarSpacer(.flexible)`
  (`#available(macOS 26.0, *)`-gated — it's a macOS 26 API, absent on older toolbars), and the
  pane's trailing actions inside one `.toolbar { }` closure — never split across two `.toolbar {}`
  modifiers (`ToolbarContentBuilder` has no zero-argument `buildBlock()`, which is why this needs
  its own `PaneTitleBandWithActions` modifier rather than the plain title-only `PaneTitleBand` fed
  empty trailing content). `.toolbar(removing: .title)` drops SwiftUI's automatic flexible space
  between leading and trailing toolbar content, so trailing-placed items in a *separate* `.toolbar`
  block collapse leftward and land right next to the title instead of trailing the band; the
  spacer is what pushes them back out to the trailing edge, and it only works with the items it
  shares a toolbar block with.
- **`.sharedBackgroundVisibility(.hidden)` is macOS-26-gated**: on macOS 26+ the title
  `ToolbarItem` is wrapped `.sharedBackgroundVisibility(.hidden)` so Tahoe doesn't draw it inside a
  Liquid Glass capsule (title text should read as plain text, not a pill button); older macOS gets
  the same `ToolbarItem` without that modifier, since the capsule treatment doesn't exist there.
  Both branches live in `paneTitleItem`, the single `@ToolbarContentBuilder` function shared by
  every pane so the two title-band variants can't drift apart.
- **`PaneIcon` survives only for sidebar rows**: the title band itself is text-only by design (see
  above) — `PaneIcon` (the squircle badge icon + tint per pane) is no longer used in any title
  band. It lives on only as the leading badge icon for the Settings/About rows in
  `DockTileSidebarView` (`PaneIcon.general` / `.popover` / `.dockLock` / `.about`).

- **One switch size app-wide — 36×16 (`.controlSize(.mini)`)**. Measured, not guessed: `.small`
  renders 44×20 and stood out against every Settings pane. It is encoded two ways **on purpose**:
  a labels-hidden toggle in a hand-built row (Tile Detail, Popover) uses the shared
  `View.tileSwitch()` modifier; a `Form` toggle that carries a text label (General, Dock Lock)
  sets **nothing** and inherits the Form default, which already renders 36×16. **Never apply
  `.tileSwitch()` / `.controlSize(.mini)` to a labelled Form toggle** — `controlSize` scales the
  label typography too, so it would shrink those panes' title and description text. Verify a
  change by reading the AX frame (`size of every checkbox …`), not by eye.

- **`.tilesPlaceholder` (critical)**: the "No Tiles" row is a **selectable** placeholder that routes
  to the empty-state detail. Without it, once the user opened a Settings pane at zero tiles there was
  no selectable tile row to click back to, stranding them in Settings. First launch and
  last-tile-deletion both default `selection` to it, so the empty state (not a Settings pane) is what
  appears. `EmptyConfigurationView`'s single **Add a Tile…** action wires to the **same**
  `handleAddTapped` as the sidebar + — every add entry point now opens the Smart Add dialog
  unconditionally (see smart-add.md "The + flow (v2: the dialog always opens)") — the entry points
  must not diverge.
- **+ gate must never deadlock (critical)**: the toolbar + is gated by the pure
  `ConfigurationManager.canCreateNewTile(hasSelection:selectedEdited:)` seam — disabled **only** while
  an unedited freshly-created tile is *selected*, always enabled when there's no selection. Gating on
  `selectedConfigHasBeenEdited` alone left + permanently disabled after deleting the last blank tile
  (the flag stayed `false` with zero tiles, nothing to edit to flip it back). `deleteConfiguration`
  also resets the flag to `true` when the list empties so the stored value stays honest. Guarded by
  `ConfigurationManagerTests`.

## Tile editor = the real popover (critical)

"In This Tile" (Tile Detail) renders `PopoverPreviewCanvas` — the wallpaper canvas around the SAME
`StackPopoverView` / `ListPopoverView` helpers ship — with `PopoverEditing(onRemove:onMove:)`
handlers: hover ×, context-menu Remove, Delete key, VoiceOver Remove action, drag reorder via
`PopoverItemDropDelegate`. `editing` is `nil` in helpers and the Popover settings preview — the
panels' shipped rendering is untouched **by construction**: the shared modifiers
(`editingOnly`/`removeAffordances`/`reorderable`) live inside `if let editing` branches whose
`else` is bare `self`. `editing != nil` implies `isPreview` (no app launches, no configurator jump)
so an editor click can never fire a real action. Reorder/remove go through the pure `AppListEditor`
seam (`.removing(_:from:)` / `.moving(_:onto:in:)`, `AppListEditorTests`). Adding apps stays the
native `NSOpenPanel` (multi-select, unchanged). There is no apps table any more; do not reintroduce
one.

`PopoverPreviewCanvas`'s `.id`-equivalent re-render key (`signature`) must **not** include the app
list — `configuration` is a value type, so add/remove/reorder already re-renders the embedded panel
without a new view identity, while keying on the list would destroy-and-rebuild it mid-edit and
drop an in-flight drag or keyboard focus.

## About pane

The sidebar's "Dock Tile" section routes to `AboutPaneView` ([AboutView.swift](../../DockTile/Views/AboutView.swift)),
which replaced the old detached `AboutWindowController` window — About is now a pane in the same
detail column as tiles and Settings, not a separate window. It is the **only** home of Software
Update (moved out of General). `AboutLinks.feedback` reads Info.plist `DTFeedbackEmail` (mailto:,
built through `URLComponents` so the subject is encoded), falling back to the website when the key
is absent or the URL can't be built. That fallback is **silent and looks like the Website row**
while the copy still promises the message reaches the developer, so `AboutLinksTests` pins both the
shipped address (`hello@happymachines.company`) and the exact mailto the button opens.

## Popover Configure Gear Icon

Both `StackPopoverView` (grid) and `ListPopoverView` (list) have a gear icon that opens the main app to configure that tile. Posts `.openConfigurator` notification → `HelperAppDelegate` handles routing via `docktile://configure?bundleId=...` deep link. Routes to correct build: DerivedData for dev, `/Applications/` for release.

Helper bundles have `CFBundleURLTypes` stripped from Info.plist (prevents helpers from claiming the URL scheme).

## Helper Migration Pipeline

`HelperMigrationManager` detects stale helper bundles on main app launch and batch-regenerates them with a single Dock restart.

**Version tracking**: `helperAppVersion` (v6 schema field) stamps which app version built each helper. `nil` = pre-migration, treated as stale. **This per-tile field is the source of truth**; `UserDefaultsKeys.lastMigratedAppVersion` is only a fast-path/bookkeeping marker.

**Flow**: classify every tile (pure `classifyForMigration` seam) → stamp the confident no-rebuild ones → quit + regenerate stale visible+pinned helpers via `regenerateHelperBundle()` → single Dock restart → relaunch the regenerated ones.

**Convergent, not one-shot (critical)**: migration does **not** hard-early-return on `lastMigrated == currentVersion`. It re-derives per-tile state from `helperAppVersion` each launch, so a tile left stale by a previous run **retries until it succeeds** (the loop is cheap when all are current — each is `skipUpToDate` with no probe). This fixes the "some very-first bundles never migrated" class: a single transient miss no longer stamps a tile "migrated" forever.

- **Reliable reads (critical)**: every Dock read (`findInDock`/`findDockIndex`/`isInDock`/`addToDock`) calls `CFPreferencesAppSynchronize("com.apple.dock")` **before** `CFPreferencesCopyAppValue` — reading another app's domain can return a cold/stale cfprefsd cache (notably right after login), which used to make `findInDock` miss genuinely-pinned tiles and skip them.
- **Refresh the Dock icon cache after an in-place regenerate (critical)**: rewriting a helper's `.icns` in place + `touchBundle` (mtime bump + `lsregister`) does **NOT** invalidate the Dock's per-entry icon cache — the Dock keeps drawing the OLD render for the unchanged `persistent-apps` entry. So `regenerateBatch` calls `HelperBundleManager.refreshDockEntry(for:)` (remove + re-add the entry at the same index → new GUID → fresh icon load) for every regenerated tile **before** the single Dock restart. This is why `installHelper` (which removes + re-adds) always showed new icons while the migration/self-heal batch shipped correct files that the Dock rendered stale (1.8.2 regression). Any new "regenerate in place then restart" path MUST re-seat the entry or icons silently go stale.
- **Stamp on SUCCESS only (`runRegenerationBatch`)**: a failed regeneration is left **unstamped** so it retries next launch (heals a killed-mid-generation / transient-FS failure), reversing the old "stamp anyway". Failures never restart the Dock (only successes do), so a persistently-broken tile can't churn it.
- **Translocation pre-flight**: if `AppRelocationManager.canGenerateBundles` is false, the regenerate batch is **skipped entirely** (not force-quit-then-fail) and tiles are left stale to retry once the app is moved — the launch relocation nudge asks the user.
- **Completion**: `lastMigratedAppVersion` is stamped only when **no visible tile remains stale** (fully converged); otherwise it's left so the next launch retries the remainder.
- **Edge cases**: not visible → `stampOnly` (rebuilds via `installHelper` when next shown). Visible + no bundle on disk → `stampOnly` (repair is the version-independent self-heal below, not the normal pass).

**Version-independent self-heal (`selfHealIfNeeded`)**: runs once per session after migration + `scanForMissingApps`. Migration keys on the *config's* `helperAppVersion`; a pre-fix release could have stamped that "current" while the bundle is actually broken (a stamp-only lie), so migration skips it forever. Self-heal instead keys on the **actual on-disk state**, catching that existing damage. It repairs a tile only when it is **pinned in the Dock** AND its bundle is missing, structurally corrupt (`helperIconsComplete` — `AppIcon.icns` + the four variants all present and non-empty; catches a killed-mid-generation bundle), or built by an older app (`helperBakedVersion` != current). **Draft-safe by construction (critical)**: gated on `HelperBundleManager.pinnedBundleIds()` (one synchronized Dock read) — a tile the user never Added is never in that set, so self-heal can't force-pin a draft (unlike a `helperExists`-based check, which can't tell an orphan from a draft). Repairs via the shared `regenerateBatch` (single Dock restart), translocation-pre-flighted, throttled once/session. Pure `classifyHelperHealth` seam guarded by `HelperSelfHealTests`; emits `helperSelfHeal` analytics.

## Missing App Detection

Tiles reference apps by `bundleIdentifier` (+ `lastKnownPath`, v8). When an app is uninstalled,
`AppIconLoader` used to fall back to the cached `iconData` and paint the **stale icon at full
opacity**, hiding the "app is gone" state. Detection now flags those apps instead.

- **Two-signal check**: `AppItem.lastKnownPath` (v8 field, stamped on add, healed on scan) is a
  second installation signal beside the bundle ID. Distinguishes a real uninstall from a
  transiently-unregistered Launch Services entry, and lets a **moved/updated** app self-heal by
  re-resolving rather than being flagged.
- **Pure seams**: `AppInstallChecker.classifyInstallStatus(bundleResolves:onDiskPathExists:)` →
  `.installed` / `.missing`, fed by `acceptsProbedPath(exists:isTrashed:foundBundleId:expected:)` and
  `isTrashed(_:)` (in `AppIconLoader.swift`, unit-tested). Installed = LS resolves the bundle ID
  **or** an app bundle exists on disk (last-known path / common dir); else missing.
- **A signal must prove identity, not just presence (critical)**: both probes are verified before they
  count. A Launch Services hit must still exist on disk and sit outside the Trash — a registration
  outlives the bundle, and dragging an app to the Trash (how most people uninstall) leaves it both
  present and registered. A path probe must additionally host the **expected bundle identifier**:
  `commonSearchPaths(forName:)` matches on display name, and two different apps can share one. Both
  gaps produced the same shipped bug — an uninstalled Chrome web-app shim named "Claude" stayed
  "installed" because `/Applications/Claude.app` (the unrelated native app) answered the name probe,
  so the tile and its Dock popover kept drawing the survivor's icon and Settings → Scan reported
  all-clear. It also self-perpetuated: `scanForMissingApps` writes `resolvedPath` back into
  `lastKnownPath`, so an unverified match poisons the item into confirming itself forever. Guarded by
  `AppInstallEvidenceTests` + `AppInstallCheckerResolveTests`. A
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
