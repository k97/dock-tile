# Audit round 3 — the items rounds 1 and 2 did not do (queued 2026-11-04)

Everything from the 2026-11-04 whole-repo audit, and from rounds 1–2's own checks, that is **not done**:
the items the owner cut from round 2 ("Not doing" in `2026-11-04-audit-round-2.md`), the follow-ups found
during the hands-on checks, and the accepted round-1 residual. Owner request (2026-11-04): "make a note of
not dones into a round 3 and start lining them up".

**Status: queued, not gated.** Starts after rounds 1–2 merge and ship. Line numbers below were read on
2026-11-04 (some before round 2 moved code): re-check every one against `main` before the `--plan` gate,
and re-decide each item with the owner one at a time. Several were cut on purpose; re-queuing them here is
not a decision to do them.

Order: **1** user-visible problems → **2** measure first → **3** rare robustness → **4** lean →
**5** design. Inside a tier, top to bottom.

---

## Tier 1 — users can see these

### R3-1 · A tile holding Downloads asks for access at launch, and again after every Update (#36)
- **Facts:** the prompt follows `Icon cache prewarmed` (the helper renders the folder's icon at launch,
  which TCC counts as a Downloads access). Confirmed by the owner on 2026-11-04 that it re-prompts after
  every Update: ad-hoc helpers get a new cdhash per rebuild, a new identity to TCC. Predates the audit.
- **Options (issue #36):** a generic icon for protected folders; skipping the prewarm for them (the prompt
  likely moves to the first open); a stable designated requirement so a grant survives rebuilds.
- **Verify:** reproduce from #36 before and after; read tccd's verdict, not the dialog (architecture.md's
  App Management note: prompts show once per identity).

### R3-2 · Arrow-key selection doesn't scroll into view (grid and list)
- **Facts:** neither popover has a `ScrollViewReader`; past the 600 pt cap (grid always could; the list can
  since round 2's A3) the keyboard selection moves out of sight.
- **Change:** one `ScrollViewReader` per panel, `scrollTo(selectedIndex)` on change.
- **Verify:** by eye on a 40-app grid tile and a 40-app list tile.

### R3-3 · The Dock-plist watcher stops after a real delete (audit #11, round-2 A6)
- **Facts:** on `.delete`/`.rename` the watcher re-arms at once (DockPlistWatcher.swift:86-90); if the
  file isn't back yet (`defaults delete com.apple.dock`), `open` fails (:63-68) and nothing retries, so
  visibility sync is off until relaunch.
- **Change:** retry `open` after 1 s, with ONE pending-retry flag and a stopped flag (the gate: a plain
  `asyncAfter` per failure stacks retries, and `DockLockManager` owns a second watcher, :583/:598).
- **Verify:** extend `DockPlistWatcherReplaceTests` (delete, recreate 1.5 s later, write → handler fires);
  mind that suite's CI flake history (testing.md).

### R3-4 · A failed bundle delete skips the second quit and the Dock restart (round-2 B1)
- **Facts:** `uninstallHelper`: `removeItem` throws AFTER the plist entry was removed, so neither the
  second `quitHelper` (round 1) nor the verified restart runs, and the running Dock can flush the deleted
  tile back in.
- **Change:** catch the delete error, still quit again and restart when `didRemoveFromDock`, rethrow.

## Tier 2 — measure first (performance-measurement.md: same-session A/B, optimised build)

### R3-5 · Popover cells probe Launch Services on every re-render (round-2 E1)
- **Facts:** each cell body runs `AppInstallChecker.resolve` + a `contentStamp` stat
  (NativePopoverViews.swift ~:658, ~:755, ~:1028, ~:1088); arrow keys and right-click re-render all cells.
- **Measure:** `sample` while holding an arrow key on a 100-app grid tile. **Fix if it shows:** resolve
  once per open, pass the result into the cells.

### R3-6 · A helper may read a stale icon style (round-2 E2)
- **Facts:** nothing in a helper synchronizes preferences before the raster-cache key read
  (AppIconLoader.swift ~:190); issue #22 notes an unsynced read can be stale.
- **Measure:** a 15-minute probe in a running helper while switching Icon & widget style.
  **Fix if it shows:** synchronize once per open in `FloatingPanel.configurePopoverForPresentation()`.

### R3-7 · Smart Add rewrites its log on every app switch (audit #18, round-2 D2)
- **Facts:** `recordLaunch` (SmartAddEngine.swift:236-245) re-encodes up to 800 events and writes
  atomically on the main thread per activation.
- **Measure** the main-thread cost; **fix if it shows:** a 30 s debounce + a `willTerminate` flush (check
  it like #30, no unit test reaches ⌘Q).

### R3-8 · App Grid desaturation per redraw (audit #19, round-2 D3)
- **Facts:** `IconGenerator.desaturated(_ cg:)` builds a fresh CIFilter + bitmap per call;
  `DockTileIconPreview` calls it per mini per body evaluation under Clear/Tinted.
- **Measure; fix if it shows:** cache the desaturated image in `TileIconRasterCache` (its key already
  carries the appearance token).

## Tier 3 — rare robustness (never observed; do only with a case)

### R3-9 · Hung build tools (round-2 B5)
- **Facts (gate):** the hang sits in `readDataToEndOfFile()` on `DispatchQueue.global`; only killing the
  child closes the pipe; a watchdog on the global pool is development.md's deadlock; `codesign` is
  unbounded too. Since round 1, a hung build also makes a Delete of that tile wait forever.
- **Change if wanted:** one watchdog on its own serial queue — `terminate()` at 60 s, `SIGKILL` 5 s later —
  for `docktile-actool`, `assetutil`, `codesign`; a stub-process test.

### R3-10 · A batch restarts the Dock with nothing to check (round-2 B2)
- **Facts (gate):** `batchExpectations` keys only on tiles pinned before the re-seat, so it is empty
  exactly when no re-seat happened. **Change:** skip the restart when it is empty.

### R3-11 · Two same-named tiles built at once share one folder (round-2 B3)
- **Facts (gate):** worse than first thought — `RENAME_SWAP` would move the other tile's bundle into
  staging, and the staging clean-up deletes it. **Change:** abort the swap when the bundle at `final`
  belongs to another bundle id; a real-filesystem `HelperSwapTests` case.

### R3-12 · Re-seat can pick a stale copy of a renamed tile (round-2 B4)
- Only after a failed old-folder delete. **Change:** `buildAndSwap` returns `final`; thread it to the
  re-seat and the expectation.

### R3-13 · Start-at-Login reconcile blocks launch on XPC (round-2 B6)
- ~20 ms once per launch (`reconcileOnLaunch`). Moving it off main can race a user toggle during launch.

### R3-14 · Stale migration stamp on Hide / Done (round-1 regression gap A, accepted)
- `.remove` / `.saveOnly` save the session's `helperAppVersion`. Harmless while migration treats hidden
  tiles as stamp-only; becomes real if hidden tiles are ever rebuilt on launch. **Change if needed:** take
  the stored stamp in those two branches.

## Tier 4 — lean

### R3-15 · One hex parser (audit #16, round-2 B7)
- **Facts (gate):** the black swatch comes from the call site (CustomiseTileView `Color(hex:)` on a bad plate
  hex), which must fall back to the bake's default plate; `ColorExtensionTests` pin `#F00`, ARGB and
  invalid → black, so those tests change. Fewer call sites remain since round 2's C3.

### R3-16 · Small duplicates (round-2 C4)
- `brandRatio`'s 0.30/0.035 slope repeats the symbol mapping (SymbolPickerGrid.swift ~:161 vs
  IconDepthMetrics); the brand-glyph view is written twice (SymbolPickerGrid / DockTileIconPreview);
  `EmojiPickerGrid` filters each category twice per render.

## Tier 5 — design

### R3-17 · Folder names in macOS permission prompts
- **Facts:** a prompt names a helper by its FOLDER whenever that differs from its display name
  (docs/dock-tile-display-names.md): an emoji-only tile asks as "Dock Tile <shortId>.app", "Work & Play"
  as "Work  Play.app".
- **Option:** keep emoji and most punctuation in folder names (strip only `/`, `:` and a leading dot), so
  the folder matches the tile name. Renames those tiles' folders on their next rebuild; verify emoji paths
  through codesign, Launch Services, the Dock plist URL and TCC first.

---

## Watching, no work queued
- **List popover first open after an Update:** the owner saw a plain-looking list on the first click and the
  styled one on the second (2026-11-04, a 46-app list tile); the log showed two normal `layout=list` opens
  and the owner confirmed the style loaded. Owner is watching for it; reopen with a screenshot.

## Still won't fix (decided 2026-11-04; listed so nothing is lost)
The legacy bitmap dedupe (frozen macOS 15 path); the `SettingsBadgeIcon` mirror (deliberate, tested);
`iconScale` not clamped on decode (no input path); the raster cache keeping replaced bitmaps (rebuilt every
release).
