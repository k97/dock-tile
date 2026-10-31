# Architecture

## Multi-Instance Model

Users create Helper Bundles (copies of main app) stored in `~/Library/Application Support/DockTile/`. Each maintains independent app lists and icons. Shared config at `~/Library/Preferences/com.docktile.configs.json`.

## Helper Bundle Lifecycle

**Creation** (`HelperBundleManager.installHelper`), steps 1–5 built in STAGING (below):
1. Copies main DockTile.app as template
2. **Removes `Assets.car`** — prevents main app icon overriding custom icons (macOS prioritises asset catalogs over `CFBundleIconFile`). The copy also carries every `.lproj` (helpers localize to the system language). It must never carry an `InfoPlist.strings`: that overrides the rewritten `CFBundleName`, so every tile would read "Dock Tile" (see localization-macos.md)
3. Updates Info.plist (unique bundle ID, name, LSUIElement based on mode)
4. Generates `.icns` icon for all 4 style variants
5. Code signs with ad-hoc signature
6. Quits the old helper, swaps the new bundle in, registers + launches it, re-seats (or adds) the Dock entry at its saved position, verified Dock restart

**Staged rebuild + swap (critical, 2.6.3)**: every rebuild (`installHelper`, `regenerateHelperBundle`
→ migration / self-heal / Popover Apply) runs `buildAndSwap`: build at `<support>/.staging/<bundleId>.app`
while the old helper keeps running, then quit it and `renamex_np(RENAME_SWAP)` into place. WHY: the
in-place rebuild left the tile's folder holding a copy of the MAIN app (its bundle id) for a moment;
the Dock resolves a pinned entry by bundle id (#35), so on 2026-10-29 Force Quit on the dead tile
killed Dock Tile itself mid-migration and the migration ran twice. The ORDER is the fix and is pinned
by the pure seam `runStagedRebuild` (`StagedRebuildTests`): build/sign → quit old → swap → remove a
renamed tile's old folder (decided BEFORE the swap by `oldFolderToRemove`, path-normalised, or a
trailing-slash spelling would delete the new bundle) → register → quit AGAIN (a Dock click in the gap
relaunches the old bundle) → launch. A build failure leaves the old tile untouched; a swap failure
relaunches it. Never register the staging path; it is dot-prefixed (Spotlight skips it) and every
support-folder scan lists top-level `*.app` only. A per-tile `flock` (`TileBuildLock`) stops a second
Dock Tile process; the launch task removes unlocked leftovers (`removeStaleStaging`). Needs APFS (any
supported boot volume). **Update no longer removes the Dock entry before building** — that only
guarded against the Dock relaunching a half-built bundle; it re-seats after the swap instead.

**Rebuild bar (2.6.3)**: while a pinned tile rebuilds, the main app posts `TileRebuildSignal` stages
(distributed notification, object = the tile's bundle id) and the RUNNING helper's
`TileRebuildPresenter` draws style C (icon darkened, white bar along its bottom) into `NSApp.dockTile`
and ignores Dock clicks, ⌘Tab activation and its custom Dock menu. A Ghost helper switches to
`.regular` while the bar shows: as `.accessory` its dock tile never reaches the pinned icon (measured
macOS 15/26/27, spec 2026-10-30-tile-rebuild-progress-design.md). For those seconds a Ghost tile has
a running dot, a ⌘Tab / Force Quit entry and the Dock's standard menu (Quit hits only the tile). No
bar where no helper of 2.6.3+ is running (the update TO 2.6.3, a stopped helper) — built silently. The
signal is spoofable by any local process (worst case: clicks ignored for the 30 s expiry). No timer
runs in a helper while no bar shows.

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
- **The Dock's hover label stays up beside the popover; accepted, no fix (2026-10-20)**: the
  Dock draws the label inside its one full-screen window (layer 20; it has no window of its own)
  and keeps it through and after the click (captured at 0–1500 ms). It does the same for any
  app's Dock tile. No public API hides it or reports its frame. A synthetic mouse move needs
  Accessibility for every helper. Covering the label by anchoring lower was rejected after a
  hands-on check: the label rises with the magnified icon, so a popover low enough to cover it
  looks worse at high magnification than the overlap does. Measured at largesize 68: magnified
  icon top ≈ `largesize + 6`, label band ≈ 80–114 pt above the screen edge. **Recheck every
  macOS release / WWDC** for an API that hides a Dock tile's label or exposes its geometry.
- **Autohide**: measured gap < 20pt ⇒ fall back to `tilesize + 25` (the click proves the Dock
  is revealed right now). Resting clearance otherwise uses the *measured* gap, which
  self-corrects when a crowded Dock auto-shrinks below the `tilesize` pref.
- **Screen = the one under the mouse** (a Dock click lands on the Dock's display), not
  `NSScreen.main` (the key window's screen — differs on multi-display, e.g. with Dock Lock).
- Mouse coordinate only for the axis parallel to the Dock (best icon-centre estimate without
  AX — which helpers can't get: per-binary TCC grants, regenerated bundles). NSPopover slides
  its arrow within the preferred edge near screen corners; no lateral compensation needed.
- **⌘Tab (App mode) has no click, so never the mouse (issue #15)**: a keyboard show anchors at
  the tile's last Dock click (`FloatingPanel.keyboardAnchorPoint`, guarded by
  `FloatingPanelKeyboardAnchorTests`), else the centre of the primary screen. The click is
  saved in the helper's own defaults (`lastDockClickPoint`) so a restart doesn't lose it. No
  public, permission-free API gives a tile its own icon's position (the Dock's only window spans
  the screen), and the click can drift about half a tile when the Dock re-centres. A cold launch
  from Spotlight/Finder saves a non-icon point; the next Dock click corrects it.
- **⌘Tab activation can be followed by a reopen (issue #15)**: macOS 26 always sent one ~100 ms
  after the activation that already showed the popover; macOS 27 sometimes does (16 ms,
  observed). The reopen toggled the popover straight back off. `applicationDidBecomeActive`
  stamps `autoShownAt`, so `shouldSwallowReopen` treats it like the cold-launch trailing reopen
  (issue #12). Replay it on any macOS by activating the helper, then opening its bundle via
  `NSWorkspace.openApplication` ~100 ms later.
- **One `NSPopover` per helper, for its whole life (critical)**: `FloatingPanel.popover` is a `let`.
  On macOS 26 every `NSPopover` INSTANCE leaks its Liquid Glass backdrop (AppKit bug, 3–5 MB per
  open); a new popover per click shipped through 2.0.1. Fresh *content* is attached per open and
  released on close, so settings still re-read each click. Never construct a `FloatingPanel` or an
  `NSPopover` per open. Details + repro: `docs/macos-26-popover-glass-leak.md`.
  **Keep it on macOS 27+.** The leak no longer reproduces on macOS 27.0 (bare probe, 2026-09-29;
  Apple's release notes mention no fix), but the deployment target is macOS 15 and macOS 26 users
  still need the workaround; on 27 it costs nothing. Do not `#available`-gate it or remove it
  while adopting macOS 27.
- `NSVisualEffectView` with `.popover` material for native vibrancy
- Keyboard navigation via `KeyboardCaptureView` (custom NSView)

## Dock Integration (CFPreferences API)

All Dock plist operations use `CFPreferencesCopyAppValue`/`CFPreferencesSetAppValue` with `"com.apple.dock"`. Matches industry tools (dockutil), avoids `cfprefsd` cache sync issues from direct plist file writing.

Race condition prevention: `installingBundleIds` and `removingBundleIds` Sets prevent double operations.

**The dying Dock can undo your write (critical)**: a plain `killall Dock` (SIGTERM) only *signals* the
Dock — a Dock still holding the previous `persistent-apps` in memory flushes that stale list back to
cfprefsd as it exits, silently reverting the add or removal just written (this is the `'<tile>' STILL
in Dock after restart` line, and the "had to press hide twice" symptom). Distinct from the stale-*read*
problem the synchronize-first reads defend against. **So every restart is write-then-SIGKILL**
(`HelperBundleManager.dockRestartArguments`, 2.6.2): a killed Dock cannot flush. Measured 2026-10-29
(docs/dock-modification-prior-art.md §6, macOS 27): write-then-SIGTERM lost 14/14 writes made within
2.5 s of a restart; write-then-SIGKILL kept 13/13. Kill-then-write is NOT the same: launchd can relaunch
the Dock before the write lands and the plist and the running Dock then disagree. It depends on launchd
relaunching a killed Dock (KeepAlive), proven on macOS 15 and 26 by the `dock-kill-check` CI job
(ci-release.md) and on macOS 27 by §6. **Accepted cost:** a Dock edit the Dock hasn't saved yet (an icon
dragged a second before an Update) is lost.

**Every Dock change is a verified restart (critical, 2.6.2)**: install, Hide, delete and the
migration / self-heal / Popover Apply batch all go through `HelperBundleManager.restartDockAndVerify`
— SIGKILL, wait for a Dock with a NEW pid (≤ 5 s) + 1 s, then check each tile with the ONE shared
predicate (`dockEntriesAreCurrent`: exactly one entry, the same FILE as the helper by device + inode;
absent = no entry with the bundle id), retry the unmet ones once, never loop (`runDockVerification`,
`DockExpectationTests`). The same predicate drives `addToDock`'s reconcile and self-heal, so the three
can never disagree. It replaced bundle-id-only checks: on 2026-10-29 a rename + Update left an entry
with the right bundle id at the DELETED old folder and every check called it fine.
- **What a failure does:** Tile Detail actions throw `dockChangeNotKept`, shown in the red error text
  under the editor like every other failure on that button (and recorded as a Crashlytics non-fatal);
  the success-path bookkeeping is skipped, so one successful retry completes it. Delete, the batch and
  the launch stuck-tile sweep only log.
- **Limits, accepted:** it reads the plist, so it can't see the plist and the running Dock disagree
  (that needs Accessibility, which the main app has only with Dock Lock on); and the +1 s read can come
  before the new Dock's own write-back a few seconds after launch — accepted to keep Update fast, but
  that write-back is NOT always ours: the Dock re-resolves entries through Launch Services (next
  bullet), so a stale registration can rewrite an entry after the check passed.
- **No Dock after 5 s → `launchctl kickstart gui/<uid>/com.apple.Dock.agent` (Q21)**: launchd relaunches
  a SIGKILLed Dock, but a Dock something else stopped cleanly just before (a Terminal `killall Dock`) can
  be left `service inactive` and not relaunched — measured 2026-10-30 (once in six SIGTERMs), the Dock
  stayed down for over a minute while our check passed on the plist. The fallback path is not
  exercised by any test (the state didn't reproduce on demand); `kickstart` itself restored that Dock.
- **The Dock re-resolves entries through Launch Services (macOS 27, measured 2026-10-30)**: on load it
  rewrote a pinned entry's path to whatever Launch Services resolves its bundle id to — 3/3, from a
  missing path, from another existing bundle, and with the helper quit. So a stale LS registration (the
  deleted old folder of a renamed tile) is the likelier cause of the 2026-10-29 incident than the write
  race alone (unproven; issue #35 holds the experiment). **Unmeasured either way:** whether the rewrite
  lands before the +1 s check (→ `dockChangeNotKept`) or after it (→ the check passes and the entry
  reverts). **Risk, not yet seen:** while LS resolves a tile's bundle id to a path other than
  `helperPath(for:)`, self-heal's stale-entry rule never converges — every launch rebuilds the tile and
  restarts the Dock (the ping-pong class). It also means seeding the Dock plist can't exercise
  self-heal's stale-entry path.
- **It ignores the caller's cancellation**: it runs in an unstructured task, because once the Dock is
  killed the check must finish (a cancelled window `.task` would otherwise turn the PID poll into a spin).
- **Batches (Q9/Q12/Q16/Q18):** the batch expects presence only for tiles pinned BEFORE its re-seat
  (`batchExpectations`), verifies outside the per-tile build locks (so a Hide is never refused while a
  batch checks), and holds its tiles in a per-tile COUNT (`verifyingBundleIds`) that the Dock-plist
  watcher skips. Any retry skips a tile another operation is building or removing, except the caller's
  own (`retryableExpectations`), and the re-check covers only what was retried.
- **Residuals, accepted:** a tile dragged off within ~1 s of a restart can be re-pinned by a retry
  (Q8); a Hide that starts AND finishes inside a batch's ~1 s check can be re-pinned and is then removed
  by the next launch's reconcile (Q16); a delete during a batch's check logs a false "STILL" line; and
  Popover Apply overlapping the launch batch restarts the Dock in turns but converges (Q19).

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
(three separate `.primaryAction` `ToolbarItem`s — Delete, the action, the inspector toggle — with a
`ToolbarSpacer(.fixed)` between them on macOS 26+: in one `ToolbarItemGroup` the toolbar merged the
bordered buttons into a single glass capsule whenever none was prominent, so a quiet Update looked
grouped beside a separate Done; spike-verified 2026-10-21). **A bright Update means the
Dock is behind (2026-10-21)**: Add to Dock is always `.borderedProminent`; Update is prominent only while
the tile differs from what its helper was built from, else `.bordered` (still enabled — it is also the
manual rebuild that refreshes an App Grid face after an app's icon or install state changed);
remove/saveOnly are always `.bordered`. A helper reads its config once at launch, so the Dock shows the
tile as of its last build: every build stamps `DockTileConfiguration.dockSignature` (icon signature,
name, layout, Ghost/App mode, app list) into the helper's Info.plist as `DTDockSignature`, and Tile
Detail compares it on appear and after an action (`builtDockSignature`). A helper built before the stamp
reads as pending until its next Update or migration. Pure seam `DockTileDetailView.actionIsProminent`,
guarded by `DockSignatureTests`.

## Dock Position Preservation

`lastDockIndex` (v5 field) persists tile position across show/hide toggles. `findDockIndex(bundleId:)` saves position before removal; `addToDock(at:atIndex:)` restores it.

## Dock Plist Watcher & Visibility Sync

`DockPlistWatcher.swift` monitors `com.apple.dock.plist` via `DispatchSource.makeFileSystemObjectSource` to detect manual tile removals and sync `isVisibleInDock` state.

**Visibility ownership (critical invariant)**: `isVisibleInDock` is written **only** by `DockTileDetailView.performDockAction()`, after the Dock add/remove actually completes. The Show Tile toggle must **not** persist visibility via the debounced auto-save — that decoupling caused a "hidden in config but still pinned in Dock" desync that never self-healed. The auto-save preserves the stored visibility/`lastDockIndex`. **The watcher leaves a tile alone while one of our Dock operations is running for it** (building, removing, or being verified after a batch — `HelperBundleManager.isDockOperationInFlight`, 2.6.2): install re-seats the entry (remove + re-add) after the swap — before 2.6.3 it removed it early and re-added it seconds later — and the watcher used to mark the tile hidden in that gap, which a failed install then left as "hidden but pinned". The skip only suppresses mark-hidden and the launch removal, so its worst case is "visible but absent" until the next Dock change or launch.

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
- **Scroll-edge scrim, not a toolbar background**: the band has no surface at rest (the
  `.toolbarBackground(.hidden, for: .windowToolbar)` on `DockTileConfigurationView` must stay), so
  a scrolling pane's content slides straight under the 52pt band and collided with the title —
  the fix is `paneScrollEdgeEffect()` (beside `PaneTitleBand`), a material scrim + gradient tail
  overlaid on each pane's scroll container that fades in with scroll offset (the Apple Notes
  treatment; pure ramp seam `PaneScrollEdgeEffect.opacity(forOffset:)`). Attach it to every
  title-banded pane's ScrollView/Form alongside `paneTitleBand` — a pane without it regresses to
  the title-over-content collision. Do NOT fix this by un-hiding the toolbar background: that
  gives every pane a permanent surface and kills the chromeless-at-rest v2 look.
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

- **Window widths: 700 closed, 960 open, 1200 max** (`AppDelegate.minWindowWidth` / `inspectorWidth` 260 /
  `maxWindowWidth`; `DockTileApp`, `DockTileConfigurationView` and `WindowAccessor` read them). The pure
  `AppDelegate.clampedWindowWidth(_:inspectorShown:)` clamps `windowWillResize` and a restored saved
  frame; `windowFrame(forInspectorShown:from:visibleFrame:)` is the frame rule. Guarded by `MainWindowWidthTests`.
  **The split view's own minimum must fit inside those (critical).** With the inspector open the split
  view counts it TWICE: the SwiftUI hosting view's fitting size includes the inspector (its safe-area
  inset), and the NSSplitView adds the inspector column again, so the minimum is sidebar + Tile
  Detail's minimum + 2 × 260 (measured 2026-10-20 from each `NSSplitViewItem` view's `fittingSize`:
  1022 = 228 + 274 + 520; closed, 502 = 228 + 274). Tile Detail's own minimum (274, the hero row with
  its labels squeezed away) therefore asked for 1022 pt, above the earlier 988 pt open minimum
  (2026-10-20): the inspector was clipped off the right edge, and opening at 988–994 pt (or resizing an open window to 1010) threw in AppKit's
  update-constraints pass. So Tile Detail reports `AppDelegate.detailColumnMinWidth` (150) through
  `.frame(minWidth:)` in `DockTileConfigurationView.tileDetail`, below its content's own minimum on
  purpose — and so does EVERY Settings pane (`detailColumn`'s `.settings` branch): the inspector
  collapses on the way to a Settings pane and is still counted twice while it collapses, so the
  Popover pane's own width froze the app in an endless layout pass and then threw (2026-10-21;
  General happened to fit, Popover did not, the bug predated that day's Popover edits); the content's room comes from the window minimums (at least 420 pt: 700 − 280, or
  960 − 280 − 260, which holds the 406 pt hero row). `.navigationSplitViewColumnWidth(min:)` alone
  does NOT lower that minimum (measured: the item's `minimumThickness` changed, the floor did not).
  The sidebar range is `sidebarMinWidth` / `sidebarMaxWidth` (220 / 280); the inequalities with the
  widest sidebar are pinned in `MainWindowWidthTests`. Known limit, very rare: on a screen whose
  visible frame is narrower than 960, `windowFrame` caps the open window to the screen, which can fall
  below the split floor with a wide sidebar.
  **The open floor rests on `windowWillResize`**: SwiftUI's root `.frame(minWidth:)` resets
  `contentMinSize` to the closed minimum, so `WindowAccessor` sets `AppDelegate.instance` as the window
  delegate on every window creation (launch, Dock reopen, deep link, ⌘,) — set once at launch, a window
  created later had no delegate and could be dragged below the floor. Do not make the root frame's
  `minWidth` follow the flag instead: it would grow a restored window before `WindowAccessor`'s frame
  fix, which then no longer shifts a right-edge frame on screen.
  **One launch-frame writer**: `WindowAccessor` (on window creation) fixes a restored frame — with the
  flag stored on, through `windowFrame(forInspectorShown: true, …)`, so a frame saved near the right edge
  grows to 960 on screen; off, the plain clamp. `AppDelegate.configureMainWindowSizing` sets only the
  size limits (its own frame fix ran after WindowAccessor's and never fired).
- **Customise Tile is a native trailing `.inspector`, not a screen (critical).** The old drill-down
  (a canvas, a floating Select Apps pill, a 700 pt window height) is gone.
  - **Placement**: `.inspector` is attached to the `NavigationSplitView` in `DockTileConfigurationView`,
    NOT inside `DockTileDetailView`. Only that placement gives the window toolbar a real inspector
    section; inside the detail, the "Customise Tile" title landed beside Update at a gap that changed
    with window width (measured 2026-10-20).
  - **One edit session**: the edited config lives in `TileEditSession` (an `ObservableObject` holding
    `config`). `DockTileDetailView` observes it and owns the ONLY save path: 300 ms debounce,
    `onDisappear` flush, `willTerminate` flush (⌘Q delivers neither the debounce nor `onDisappear`;
    #30; no unit test reaches it — re-check by stretching the debounce to 5 s, editing, ⌘Q, and
    reading the config), `preservingStoredVisibility`, `performDockAction`. The inspector edits
    `$session.config` and never saves. `TileEditSessionStore` hands out a fresh session per tile and
    clears it when the selection leaves the tiles.
  - **Presentation** comes from the seam `inspectorIsPresented(stored:selection:)` (stored flag AND a
    tile row selected; `InspectorVisibilityTests`). The binding's setter calls `setInspectorShown(_:)`
    only when the value differs from what is presented, and reads the stored flag from `UserDefaults`:
    `@AppStorage` was measured stale inside the setter and toggled twice per press.
  - **The window KEEPS its width when the inspector toggles** (Xcode/Pages/Keynote). Opening grows it
    only when narrower than 960; closing never changes the frame. Shrinking in the same turn as the
    inspector collapsed crashed AppKit's constraint pass. `AppDelegate.resizeConfigurationWindow` is
    `static` because `NSApp.delegate as? AppDelegate` is nil under SwiftUI's
    `NSApplicationDelegateAdaptor` proxy, so the instance call silently never ran.
    `WindowAccessor.updateNSView` never moves the frame.
  - **Content pinned to 260 pt** (`CustomiseInspectorColumn`): AppKit throws in a constraint loop when
    the content's minimum width exceeds its column. No drawn separator: the glass against Tile
    Detail's page separates them, as in Xcode (a 1 pt line from the opaque-inspector days was
    removed 2026-10-21).
  - **Inspector band**: `InspectorTitleBand` places its title `.automatic` (never `.navigation`), at
    14 pt semibold, one step below the 16 pt page title (`PaneTitleLabel(fontSize:)`). Its toolbar
    has no guard of its own: `CustomiseInspectorColumn`'s presented check is the content gate, so
    the band's items exist only while open. Built while closed, they leaked into the main band —
    so the modifier goes on the presented `CustomiseTileView`, never on the column (which is built
    while closed; hoisting it there leaked the title and a second toggle again, 2026-10-21).
  - **Inspector content follows Tile Detail's form**: group headers like "In This Tile" (13 pt
    semibold, primary), captions like its hint (11 pt, tertiary), 40 pt rows with 13 pt labels, cards
    inset 10 pt with full-width 1 pt `quinaryLabel` dividers, 13 pt Style-card and Background-chip labels.
  - **The inspector is the sidebar's material, like Xcode (2026-10-21)**: AppKit backs both split
    items with the same Liquid Glass view (`NSGlassEffectView`, measured on macOS 27), so the
    inspector paints NO background of its own — a window-background fill used to hide the glass.
    Its cards (`InspectorCard`) are `NSColorBackgroundView.inspectorCard`, translucent white 50% Light /
    8% Dark, one step lighter than the glass in both appearances; Tile Detail's `formGroup`
    (quaternarySystemFill) is for an opaque page and read darker than the glass in Light. The picker's
    search is the system `NSSearchField` (`NativeSearchField`), so it is the macOS 27 capsule there
    and the OS's own field on macOS 15 — never a hand-drawn imitation. macOS 15 shows whatever SwiftUI gives an inspector
    there — not checked on that OS.
  - **One moving toggle** (`sidebar.trailing`, tooltip and accessibility label "Toggle Customise Tile"):
    it trails Update in Tile Detail while closed and the inspector band while open. There is no
    Customise button; the hero icon toggles both ways ("Toggle Customiser"; a default
    `accessibilityAction` makes its button trait answer AXPress / VoiceOver). ⌥⌘I is in the View
    menu (Show / Hide Inspector) via a `FocusedValue` (`InspectorCommand`), enabled only for a
    tile row (`inspectorCommandIsEnabled`, `InspectorEntryPointTests`).
  - **Hero**: `heroIconSize` 122 pt, the Tile Name card's height (3 × 40 pt rows + 2 × 1 pt dividers),
    so they align top and bottom. Canonical Default/Dark while the inspector is open, Dark only where
    the Dock icon follows the appearance (macOS 26+; macOS 15 stays Default), live `TileFace` while
    closed (`DockTileDetailView.heroForcedStyle`, `InspectorEntryPointTests`).
  - **Content only while presented (R15)**: SwiftUI instantiates inspector content while it is closed,
    so `CustomiseInspectorColumn` builds `CustomiseTileView` only while presented (an empty
    placeholder otherwise); built while closed, every Name keystroke re-rendered the whole hidden Customise view.
    Still no `onAppear` work in the inspector.
  - **A selection change never animates the inspector (critical)**: `.transaction(value: selection)`
    on the `NavigationSplitView` sets `disablesAnimations` and `animation = nil`, so the collapse on
    the way to a Settings pane and the expand back to a tile are instant; only the user's own toggle
    animates. The animated collapse was the single largest cost of the open inspector — the 12-switch
    Settings sequence went from 39 main-thread hangs (4.05 s frozen) to 12 (2.95 s) on an optimised
    build (2026-10-21) — and it is where both AppKit constraint-loop crashes came from.
  - **Built in the SAME frame as Tile Detail.** With the inspector open a tile switch freezes
    ~115 ms longer and a Settings switch ~70 ms longer than v2.4.0 (optimised hang traces,
    2026-10-22); closed, it matches the release. A skeleton-then-content deferral (32 ms settle) was
    built and measured WORSE (more hangs), and stable `ToolbarItem(id:)`s changed nothing, so both
    were removed — see performance-measurement.md "Main-window navigation" and `docs/perf/customise-inspector-cost-2026-10.md`.
  Design handoff (superseded where it describes a screen): `docs/design_handoff_customise_tile/README.md`.
- **Two defaults for the tile face (critical)**: a NEW tile starts on App Grid
  (`ConfigurationDefaults.iconFace = .apps`), while a stored config missing the `iconFace` key loads as
  `.glyph` (decoder literal) so no existing tile changes look on upgrade. Smart Add-created tiles open
  in the design their card showed (App Grid, Symbol or Emoji — one of each per dialog, smart-add.md). See icon-system.md "Apps
  tile face".
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

**The link reveals the tile with Customise open (issue #31)**: `AppDelegate.handleDeepLink` selects
the tile, then posts `.revealTile`, and `DockTileConfigurationView` sets `selection = .tile(id)` and
opens the inspector (the stored flag, so it stays open, Xcode-style). Never rely on
`selectedConfigId`'s `onChange` alone: a Settings pane keeps it on the last tile, so configuring that
tile wrote an equal value, nothing fired, and the pane stayed up. A URL that arrives before
`configManager` is set (cold launch) is held in `pendingDeepLink` and replayed by its `didSet`. The
helper's Dock-menu Configure… uses the same link.

Helper bundles have `CFBundleURLTypes` stripped from Info.plist (prevents helpers from claiming the URL scheme).

## Popover Item Context Menu (issue #17)

Right-click / Control-click on an app or folder in the SHIPPED popover shows a native context menu
([PopoverItemMenu.swift](../../DockTile/UI/PopoverItemMenu.swift)). Finder's own context menu cannot be
obtained through any public API (Spotlight, Raycast and Alfred all build curated menus), so this is
built from public AppKit pieces.

- **Apps never get Show in Finder / Get Info / Quick Look / Share (critical, App Management)**: handing
  a third-party app bundle (`/Applications`) to Finder, Quick Look, a share service or even
  `/usr/bin/open -R` from a helper makes macOS check `kTCCServiceSystemPolicyAppBundles` for the helper,
  refuse ("does not allow prompting for unentitled binaries"), and show "*<tile>* was prevented from
  modifying apps on your Mac", once per tile identity. Verified 2026-10-05; re-signing a helper with
  Developer ID did not help. Launching (`openApplication`) never triggers it, nor do folders or apps on
  the read-only system volume. Enforced by `entries` + `appsNeverHandOffTheBundle`. Prove a change
  against tccd's log (an enforced check is `preflight=no` plus "unentitled binaries"; `preflight=yes`
  queries are harmless), never by watching for the alert, which shows only once per identity.
- **Built at click time, AppKit `NSMenu`, not SwiftUI `.contextMenu` (critical)**: a transparent overlay
  `NSView` claims only secondary clicks (`PopoverItemMenu.claimsEvent`); left-click, hover, drag and
  scroll fall through to SwiftUI. Building per click keeps install status and running state live and
  enables the ⌥ Force Quit alternate. Cost: one overlay view per cell, measured ~+9 ms per open and
  +18 MB on a 100-app tile (Debug, 2026-10-10), flat across opens.
- **Composition** = pure seam `PopoverItemMenu.entries`. Folder: Open · Show in Finder · Get Info
  (macOS 26+ only) · Quick Look · Share…. App: Open, then Hide (omitted when hidden) · Quit/⌥Force Quit
  when running. Missing items get **no menu**. No tile-level items.
- **Share… shows `NSSharingServicePicker` relative to the cell, never `standardShareMenuItem`
  (critical)**: on macOS 27 that item is no submenu but a button that presents the picker against a
  window AppKit chooses; a helper whose only window is the transient popover gives it none, so Share
  silently did nothing (services were computed, nothing appeared). The plain item also carries no icon.
- **Running app = matched by bundle PATH, never bundle id alone** (`runningMatchIndex`): PWAs and
  side-by-side installs share an id. The path comes from `targetPath`, which resolves an app by the
  same rule `AppLauncher.launch` uses (`AppItem.resolvedAppURL`, lastKnownPath first), so Hide/Quit hit
  the copy Open launches; `targetPath` is also the missing-item → no-menu check.
- **Get Info = Finder's "Show Info" service via `NSPerformService`, never AppleScript (critical)**: each
  helper is separately ad-hoc signed, so Automation consent would prompt per tile and re-prompt after
  every rebuild.
- **Dismissal** (`dismissesPopover`): every action closes the popover except Share and Get Info, which
  we never close mid-action. macOS or the click-outside monitor may still close it when Finder or the share UI
  takes focus, which is accepted. Do not add `FloatingPanel` dismissal special cases for this.
- **Quick Look uses the supported controller path**: `HelperAppDelegate` implements
  `acceptsPreviewPanelControl` / `begin…` / `end…` (nonisolated + `MainActor.assumeIsolated`) and
  hands the panel the process-lifetime `QuickLookPresenter`. Never set `QLPreviewPanel.dataSource`
  without controlling the panel.
- **Shipped popover only**: hooks are nil when `editing != nil` or `isPreview`; the editor keeps its own
  Remove menu. VoiceOver: `.accessibilityAction(.showMenu)` (not yet verified hands-on). Analytics:
  `popover_item_action`.

## Helper Migration Pipeline

`HelperMigrationManager` detects stale helper bundles on main app launch and batch-regenerates them with a single Dock restart.

**Version tracking**: `helperAppVersion` (v6 schema field) stamps which app version built each helper. `nil` = pre-migration, treated as stale. **This per-tile field is the source of truth**; `UserDefaultsKeys.lastMigratedAppVersion` is only a fast-path/bookkeeping marker.

**Flow**: classify every tile (pure `classifyForMigration` seam) → stamp the confident no-rebuild ones → regenerate stale visible+pinned helpers via `regenerateHelperBundle()` (each staged, then quit + swapped + relaunched, so its bar clears at its own swap) → re-seat → single Dock restart → launch any regenerated helper not running.

**Convergent, not one-shot (critical)**: migration does **not** hard-early-return on `lastMigrated == currentVersion`. It re-derives per-tile state from `helperAppVersion` each launch, so a tile left stale by a previous run **retries until it succeeds** (the loop is cheap when all are current — each is `skipUpToDate` with no probe). This fixes the "some very-first bundles never migrated" class: a single transient miss no longer stamps a tile "migrated" forever. **Once per launch, the whole sequence (2.6.2):** the main window's `.task` (migrate → scan → self-heal) is gated by `HelperMigrationManager.beginLaunchMaintenance()`. A window reopened mid-launch re-runs the `.task` while the first is still inside its batch; a migration-only guard sent that second pass straight to self-heal, which read the mid-rebuild tile and the unreached ones as broken and started a second batch that killed the Dock in turns with the first. Convergence across launches is unchanged (the flag starts cleared each launch).

- **Reliable reads (critical)**: every Dock read (`findInDock`/`findDockIndex`/`isInDock`/`addToDock`) calls `CFPreferencesAppSynchronize("com.apple.dock")` **before** `CFPreferencesCopyAppValue` — reading another app's domain can return a cold/stale cfprefsd cache (notably right after login), which used to make `findInDock` miss genuinely-pinned tiles and skip them.
- **Refresh the Dock icon cache after a regenerate at the same path (critical; staged + swapped since 2.6.3, the rule is unchanged)**: rewriting a helper's `.icns` in place + `touchBundle` (mtime bump + `lsregister`) does **NOT** invalidate the Dock's per-entry icon cache — the Dock keeps drawing the OLD render for the unchanged `persistent-apps` entry. So `regenerateBatch` calls `HelperBundleManager.refreshDockEntry(for:)` (remove + re-add the entry at the same index → new GUID → fresh icon load) for every regenerated tile **before** the single Dock restart. This is why `installHelper` (which removes + re-adds) always showed new icons while the migration/self-heal batch shipped correct files that the Dock rendered stale (1.8.2 regression). Any new "regenerate in place then restart" path MUST re-seat the entry or icons silently go stale.
- **Stamp on SUCCESS only (`runRegenerationBatch`)**: a failed regeneration is left **unstamped** so it retries next launch (heals a killed-mid-generation / transient-FS failure), reversing the old "stamp anyway". Failures never restart the Dock (only successes do), so a persistently-broken tile can't churn it.
- **Translocation pre-flight**: if `AppRelocationManager.canGenerateBundles` is false, the regenerate batch is **skipped entirely** (not force-quit-then-fail) and tiles are left stale to retry once the app is moved — the launch relocation nudge asks the user.
- **Completion**: `lastMigratedAppVersion` is stamped only when **no visible tile remains stale** (fully converged); otherwise it's left so the next launch retries the remainder.
- **Edge cases**: not visible → `stampOnly` (rebuilds via `installHelper` when next shown). Visible + no bundle on disk → `stampOnly` (repair is the version-independent self-heal below, not the normal pass).

**Version-independent self-heal (`selfHealIfNeeded`)**: runs once per session after migration + `scanForMissingApps`. Migration keys on the *config's* `helperAppVersion`; a pre-fix release could have stamped that "current" while the bundle is actually broken (a stamp-only lie), so migration skips it forever. Self-heal instead keys on the **actual on-disk state**, catching that existing damage. It repairs a tile only when it is **pinned in the Dock** AND its bundle is missing, structurally corrupt (`helperIconsComplete` — `AppIcon.icns` + the four variants all present and non-empty; catches a killed-mid-generation bundle), or built by an older app (`helperBakedVersion` != current), **or its Dock entry is stale** by the shared `dockEntriesAreCurrent` predicate (wrong path, unparseable or duplicated — the 2026-10-29 rename left an entry at the deleted old folder that a bundle-only check called healthy; this heals users already stranded by 2.6.1). It walks pinned tiles whatever `isVisibleInDock`, so a hidden tile with a stale pinned entry is rebuilt and re-seated, then removed by the next launch's reconcile — two extra restarts, then it settles (for an unparseable entry, the only path that clears it). **Draft-safe by construction (critical)**: gated on `HelperBundleManager.pinnedEntryPaths()` (one synchronized Dock read) — a tile the user never Added is never in that set, so self-heal can't force-pin a draft (unlike a `helperExists`-based check, which can't tell an orphan from a draft). Repairs via the shared `regenerateBatch` (single Dock restart), translocation-pre-flighted, throttled once/session. Pure `classifyHelperHealth` seam guarded by `HelperSelfHealTests`; emits `helperSelfHeal` analytics.

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
  `AppInstallEvidenceTests` + `AppInstallCheckerResolveTests`.
  Tiles no longer store an icon snapshot at all (`AppItem.iconData` was removed 2026-09: it put
  every app's whole `.icns` into the config — 10 MB release configs, ~100 ms saves — for a fallback
  the missing-app placeholder already superseded). Old configs carrying the key still load; the
  blob is dropped on their next save.
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
