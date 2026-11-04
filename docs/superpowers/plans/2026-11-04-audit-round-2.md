# Audit round 2 (documented 2026-11-04, starts after round 1 merges)

Everything from the 2026-11-04 whole-repo audit that round 1
(`2026-11-04-audit-must-fix.md`, items 1–5) does not cover: audit items 6–20, the 12 smaller findings the
report left out, and the decisions about which of those NOT to do. Owner decisions recorded here were made
2026-11-04 in the same session.

**Status: documented, not gated.** Run the `--plan` stage gate on this file when round 2 starts. Round 1
moves lines and adds a `current:` parameter, so re-check every file:line below against `main` first. Every
fact below was read in code on 2026-11-04 unless marked *(reviewer reading)*.

Branch: `fix/audit-round-2`, one commit per numbered group, no push until asked. The same verification as
round 1: targeted suites, the full suite on the Default icon style, a negative control per new test, a
signed rebuild, then `--dev`.

Load assumed: one person, one Mac, ~5–30 tiles; helpers run all day.

---

## Group A — correctness (Must fix in the audit)

### A1 · A tile named only with emoji or punctuation (audit #6)
- **Facts:** `sanitizeAppName` (HelperBundleManager.swift:2013-2019) keeps letters, digits, `-`, `_`,
  space; `preferredHelperPath` (:305) builds `"\(base).app"`. "🚀" → `.app`, a hidden file, and
  `URL(fileURLWithPath: "/a/.app").pathExtension == ""` (checked), so `findExistingHelper` (:170, filters
  on `pathExtension == "app"`) never finds it: Update, Delete and self-heal miss the bundle. `buildAndSwap`
  passes the SANITIZED name as `appName` (:1940), so `CFBundleName` is "" (blank in ⌘Tab / Force Quit)
  and "Work & Play" reads "Work  Play".
- **Owner decision:** folder fallback AND the real name in the bundle.
- **Change:** (1) the pure seam `helperFolderName(baseName:…)` (:320) gets the fallback: an empty
  `baseName` → `shortId`, so the rule stays in the tested seam. (2) Pass `config.name` (unsanitized) as
  `appName` to `generateHelperBundle`; check what else reads `appName` there (bundle names only; the
  folder already comes from `preferredHelperPath`).
- **Behaviour change, stated:** existing tiles whose names hold punctuation or emoji show their real name in
  ⌘Tab / Force Quit / the Dock tooltip after their next rebuild (the next version-bump migration rebuilds
  every pinned tile). `dockSignature` already uses `config.name`, so no tile reads "Update pending".
- **Verify:** `HelperFolderNameTests` cases: `"" → "<shortId>.app"`; `""` with the clean name taken →
  still distinct from another tile's. A test that `helperInfoPlist` (or whichever seam writes
  `CFBundleName`) keeps "Work & Play" and "🚀" verbatim. Negative control: drop the fallback → the empty
  case returns ".app".

### A2 · Turning analytics off doesn't reach running helpers (audit #7)
- **Facts:** each process applies consent once in `configure()` (AnalyticsService.swift:106-124);
  `setConsent` (:128) re-applies only in the main app. `log` / `record` check only `isConfigured`
  (:146, :166). A helper started at login keeps Firebase collection on after the user opts out, until it
  is rebuilt or the user logs out.
- **Change:** `log` and `record` call `applyCollectionState()` first (a shared-suite read + two Firebase
  setters, per event — events are per popover open, so cheap). Read the shared suite synchronize-first:
  architecture.md records a cross-process cfprefsd cache split that made `@AppStorage` read a stale value
  (Popover Apply consent).
- **Verify:** Debug never collects (`isRelease` false), so the Release path can't be exercised on the dev
  build. Unit-test what is testable: a seam deciding "re-apply needed" is decorative (it is
  `shouldCollect`), so the guard is code-read + the existing `AnalyticsServiceTests`. State the gap.
  Hands-on (owner, Release build only, optional): turn analytics off, open a tile, check Firebase
  DebugView shows no event from that helper.

### A3 · A List tile with many apps runs off the screen (audit #8)
- **Facts:** the list rows are a plain `VStack` (NativePopoverViews.swift:858-878) with no `ScrollView`;
  `PopoverPanelLayout.listPanelSize` (PopoverAppearance.swift:398-420) has no cap. The grid wraps its rows
  in a `ScrollView` (:446) and caps the height at `gridScrollCap` 600 (:546, PopoverAppearance.swift:319).
  ~30 rows ≈ 1,200 pt, taller than a laptop's visible frame, so rows past the edge can't be reached.
- **Change (consistency with the grid — Apple-design "familiarity"):** outside edit mode, wrap the rows in
  `ScrollView(.vertical)` and cap the content at the same 600 pt; apply the same cap in `listPanelSize` so
  the canvas's estimate (which the list relies on — it pins only its width) matches. The utility rows stay
  OUTSIDE the scroll view, always visible. Keyboard navigation: arrow-key selection must scroll the
  selected row into view — copy whatever the grid does (check for a `ScrollViewReader` there first; if the
  grid has none, keyboard selection off-screen is a second, shared bug — note it, don't widen this fix).
- **Verify:** `PopoverPanelLayout` test: `listPanelSize(appCount: 40, isEditing: false)` height == cap +
  utility rows + padding; `isEditing: true` stays uncapped (edit mode has no inner scroll view, same rule
  as the grid, :540-546). Negative control: remove the cap → test fails. By eye (owner): a 30-app list tile
  scrolls; the gear row stays visible.

### A4 · Hiding one tile can unpin another broken tile (audit #9)
- **Facts:** `removeFromDockPlist` (HelperBundleManager.swift:1385) matches its own entry by
  `tile-data.bundle-identifier` first (:1400), then by the bundle's Info.plist. After that, a sweep
  (:1430-1435) drops ANY entry whose path contains "DockTile" and whose Info.plist is missing — another
  tile's pinned-but-missing bundle (the case self-heal repairs; self-heal only walks pinned tiles), plus
  anything under `DockTile-Dev/` or a `DockTile-<hash>` DerivedData path.
- **Change:** delete the sweep (5 lines). The first match already covers our own entry, including one
  whose URL can't be parsed.
- **Verify:** grep that no test depends on the sweep; if a seam-level test of the filter is cheap, add one
  case (another tile's missing-bundle entry is kept). Full suite.

### A5 · The Dock right-click menus can't open folders (audit #10)
- **Facts:** both menus store `appItem.bundleIdentifier` and resolve it with `urlForApplication` —
  HelperAppDelegate.swift:376 + :498-520 (App-mode tile menu) and AppDelegate.swift:355 + :379-394 (main
  app's Dock menu). A folder's id is `folder.<hash>`, so it resolves to nil and only logs. PWAs sharing a
  bundle id open whichever copy Launch Services picks, unlike the popover's `AppLauncher` (lastKnownPath
  first).
- **Change:** both set `representedObject = appItem` and call `AppLauncher.launch(item, source:)`
  (`"context_menu"` / `"main_dock_menu"` — check the existing analytics `source` values first). Drop the
  handlers' own `appLaunchedFromTile` log, because `AppLauncher.launch` already logs it (AppLauncher.swift:17)
  — otherwise every menu launch counts twice. Two near-copies → one shared launch path.
- **Verify:** build + full suite; by eye (owner): App-mode tile's Dock menu opens a folder; the main app's
  Dock menu opens an app.

### A6 · The Dock-plist watcher stops after a real delete (audit #11)
- **Facts:** on `.delete`/`.rename` the watcher cancels and calls `startWatching()` at once
  (DockPlistWatcher.swift:86-90); if the file isn't there yet (`defaults delete com.apple.dock`), `open`
  fails (:63-68) and nothing retries. Visibility sync is dead until the app relaunches.
- **Change:** when `open` fails, retry once a second (`DispatchQueue.main.asyncAfter(deadline: .now() + 1)
  { [weak self] in self?.startWatching() }`), stopping when `stopWatching` was called (check how the
  watcher is torn down so a stopped watcher doesn't resurrect).
- **Verify:** extend `DockPlistWatcherReplaceTests` (it already drives a real temp file): delete the file,
  recreate it 1.5 s later, write → the handler fires. Mind the CI flake history of that suite
  (testing.md): generous deadline, diagnostics in the `#expect` message.

### A7 · A custom tile colour is saved in the wrong colour space (audit #12)
- **Facts:** `Color.toHexString` (CustomiseTileView.swift:806-819) converts through `.deviceRGB` and
  truncates (`Int(x * 255)`); its one caller is the colour panel (:506). Every reader treats the hex as
  sRGB (`SRGB(hex:)`, `Color(hex:)` uses `.sRGB`). The same file already converts correctly
  (sRGB, clamped, rounded) at :400-409.
- **Change:** move that correct conversion into one function both call sites use, and delete
  `toHexString`.
- **Verify:** unit test: a known sRGB colour (e.g. `#5F00FF`) round-trips through the function to the same
  hex; a Display P3 colour converts to the sRGB hex `NSColor.usingColorSpace(.sRGB)` gives. Negative
  control: the old deviceRGB path gives a different hex for the P3 colour.

---

## Group B — smaller correctness and robustness (left out of the report, kept)

### B1 · A failed bundle delete skips the Dock restart *(reviewer reading, confirmed in code)*
- **Facts:** `uninstallHelper` (HelperBundleManager.swift:232-247): `removeItem` throws AFTER the plist
  entry was removed, so the verified restart never runs; the running Dock can then flush its old list back
  (the dying-Dock rule) and the deleted tile stays pinned.
- **Change:** catch the delete error, still restart when `didRemoveFromDock`, then rethrow.

### B2 · A batch restarts the Dock with nothing to check *(reviewer reading)*
- **Facts:** `regenerateBatch` calls `restartDockAndVerify(expectations, …)` (HelperMigrationManager.swift
  ~:290) even when no regenerated tile was pinned (Popover Apply targets `isVisibleInDock && helperExists`),
  breaking "restart the Dock only when it actually changed".
- **Change:** skip the restart when no regenerated tile was pinned (`pinnedIndices.isEmpty`) — check first
  whether `batchExpectations` can be empty while a re-seat happened.

### B3 · Two same-named tiles built at once can swap into one folder *(reviewer reading)*
- **Facts:** `buildAndSwap` picks `final = preferredHelperPath(for:)` (:1930) before its awaits; two tiles
  renamed to the same name and built concurrently both pick `<name>.app`.
- **Change:** in the swap step, abort (throw) when the bundle now at `final` belongs to another bundle id.

### B4 · Re-seat can pick a stale copy of a renamed tile *(reviewer reading)*
- **Facts:** `refreshDockEntry` (:1472-1477) and the batch expectations resolve the path through
  `helperPath(for:)` / `findExistingHelper`, a directory scan in no defined order; a failed old-folder
  removal leaves two folders with one bundle id.
- **Change:** have `buildAndSwap` return `final` and thread it to the re-seat and the expectation. Decide
  at the gate whether this is worth it (it needs a failed delete first).

### B5 · The icon compiler can hang a build forever *(reviewer reading)*
- **Facts:** no timeout on the `docktile-actool` / `assetutil` waits (DeclarativeIconPipeline.swift
  ~:303, ~:339); `iconutil` (IconGenerator.swift:888-905) reads stderr only after `waitUntilExit` (the
  pipe-deadlock pattern development.md forbids; harmless while stderr is small). After round 1, a hung
  build also makes a Delete of that tile wait forever.
- **Change:** a bounded wait (e.g. 60 s, then `terminate()` and throw); iconutil's stderr read before the
  wait or sent to a file, its text put into the thrown error / `DiagnosticsLog` instead of `print`.
- **Verify:** `IconCompilerTests` already compiles end to end; add a timeout case only if it can be made
  deterministic (a stub executable that sleeps).

### B6 · Start-at-Login reconcile blocks launch on XPC *(reviewer reading)*
- **Facts:** `reconcileOnLaunch` (LoginItemManager.swift:121-136) reads `service.status` (~20 ms XPC, per
  the file's own comment) and may `register()`, on the main thread at launch; the General pane already
  moved its reads off main (`readStatus`).
- **Change:** run it in a detached task like `readStatus`, publishing the result on main.

### B7 · Hex parsers disagree (audit #16)
- **Facts:** `Color(hex:)` (ColorExtensions.swift:15-38) reads 8 digits as AARRGGBB and returns BLACK for
  invalid input; `SRGB(hex:)` (TilePalette.swift:30-38) reads RRGGBBAA and returns nil (callers fall back to
  a default). A bad plate hex shows a black swatch in Customise while the Dock bakes the default plate.
- **Change:** build `Color(hex:)` on `SRGB(hex:)` (one parser); check the 9 `Color(hex:)` call sites for any
  that pass 3- or 8-digit strings before dropping those formats.

---

## Group C — lean (delete code nobody calls)

Each deletion is re-grepped across `DockTile/`, `DockTileTests/`, `DockTileUITests/`, `Scripts/` (and
string/dynamic references) at implementation time; anything with a caller stays.

### C1 · Dead code (audit #13, confirmed by grep 2026-11-04)
`ConfigurationManager.addAppItem` / `removeAppItem` / `reorderAppItems` / `stopDockWatcher`;
`LauncherView.DesignTokens`; `HelperBundleManager.removeFromDock(at:)` (unverified restart, substring
match); `isInDock(at:)` (test-only, substring match — delete with its `HelperBundleLifecycleTests` call);
`HelperBundleError.mainAppNotFound` (never thrown; update `HelperBuildExclusionTests`' case list); the
`appSwitcherChanged` print in `performDockAction`; `IconStyle.from(preferencesValue:)` /
`.resolve(preferencesValue:)` one-argument overloads (IconStyleManager.swift:81-89, no callers);
`ListMenuRow.hasSubmenu` (always `false`, NativePopoverViews.swift:889/896/1107); analytics events
`tileShown` / `tintColorChanged` / `layoutModeChanged`; AppStrings keys `popoverLayout` /
`dockLockAccessibilityGranted` / `settingsSectionHeader` (remove the catalog entries through `l10n.py`,
then `check`).

### C2 · Stray files (audit #14)
`git rm Scripts/generate_helper.sh` (first commit, nothing calls it), `Scripts/add-string.py` (re-dumps the
catalog — forbidden by localization-macos.md; `l10n.py sync-keys` replaces it),
`DockTile.xcodeproj/project.pbxproj.bak` (554 lines, unchanged since 2026-01-30),
`Scripts/setup-tests.sh` *(reviewer reading — read it first)*; delete the untracked
`add_files_to_xcode.py`. Old plan docs that mention `add-string.py` stay (history).

### C3 · Colour helpers that `TilePalette` replaced (audit #15, reviewer reading — re-grep each)
`TintColor`/`PresetColor` `colorTop` / `colorBottom` / `color` (keep `PresetColor.colorBottom`, used at
CustomiseTileView.swift:490), `Color.lighterShade` + `Color.toHex` (ColorExtensions.swift:41-85),
`Managers/AppearanceManager.swift` (`NSColor(hex:)` used only by a test; `Color(_ nsColor:)` only forwards to
`Color(nsColor:)` — rewrite its 4 sites; remove the file's pbxproj entry), the test-only `IconGenerator`
forwarders / `symbol:` overloads / `generatePreview` and `IconDepthMetrics.warningThreshold`, the legacy
`DockTileIconPreview` initialisers used only by `#Preview` and one test. Repoint the tests at `TilePalette`
/ `IconDepthMetrics` / the full init. Estimate ~250 lines.

### C4 · Small duplicates in code this round touches
`brandRatio`'s 0.30/0.035 slope (SymbolPickerGrid.swift:161) repeats the symbol mapping in
IconDepthMetrics — one constant; the brand-glyph view written twice (SymbolPickerGrid.swift:110-122,
DockTileIconPreview.swift:323-337) — one view *(reviewer reading)*; `EmojiPickerGrid` filters each category
twice per render (`categoryHasMatches` + `filteredEmojis`, :42/:50) — compute once into a `let`, as
`SymbolPickerGrid` does.

---

## Group D — small performance (Nice to have)

### D1 · Diagnostics log grows forever for users who never open the main app (audit #17)
"Popover shown …" is logged non-verbose on every open (HelperAppDelegate.swift:327); only a main-app
launch trims the file (`main.swift`). → `verbose: true` (per-click churn, diagnostics.md).

### D2 · Smart Add rewrites its log on every app switch (audit #18)
`recordLaunch` (SmartAddEngine.swift:236-245) → `saveLog()` re-encodes up to 800 events and writes
atomically on the main thread on every activation. → save on a 30 s debounce plus `willTerminate`.
Verify the terminate flush the way architecture.md describes for #30 (no unit test reaches ⌘Q).

### D3 · App Grid desaturation re-creates Core Image work per redraw (audit #19)
`IconGenerator.desaturated(_ cg:)` (IconGenerator.swift:1415-1432) runs a `CIFilter` into a fresh bitmap on
every call; `DockTileIconPreview` calls it per mini per body evaluation under Clear/Tinted (:257). →
cache the desaturated `CGImage` in `TileIconRasterCache` (its key already carries the appearance token).
Per performance-measurement.md: measure a same-session A/B on an optimised build before and after; drop
the change if the difference is inside the noise band.

### D4 · The gear button leaks a cursor push (audit #20)
`NSCursor.pointingHand.push()` on hover (NativePopoverViews.swift:423-429); clicking the gear closes the
popover before the hover ends, so the `pop()` never runs. → `.pointerStyle(.link)` (macOS 15+, matches the
15.0 floor).

---

## Group E — measure first, then decide (owner decision)

Code changes only if the numbers show a problem; record the numbers either way.

### E1 · Popover cells probe Launch Services on every re-render *(reviewer reading)*
Each cell body runs `AppInstallChecker.resolve` + a `contentStamp` stat (NativePopoverViews.swift ~:658,
~:755, ~:1028, ~:1088); arrow keys and right-click re-render the parent, and the closure props stop SwiftUI
skipping cells. **Measure:** optimised build, a 100-app grid tile, `sample` while holding an arrow key
(performance-measurement.md recipe). **Candidate fix:** resolve every item once per open and pass the result
into the cells.

### E2 · A helper may read a stale icon style *(reviewer reading)*
On macOS 26+ nothing in a helper calls `CFPreferencesAppSynchronize` before reading the style for the raster
cache key (AppIconLoader.swift ~:190); IconStyleManager.swift:312-315 (issue #22) says an unsynced read can
return a cached value. **Measure:** a 15-minute probe in a running helper while switching Icon & widget
style by hand, logging the raw value each popover open (icon-style-detection.md process lessons).
**Candidate fix:** synchronize once per open in `FloatingPanel.configurePopoverForPresentation()`.

---

## Won't fix (decided 2026-11-04)

The owner was offered these and ticked none (answer recorded as "Other" with no text; confirm if that was
meant otherwise).

| Item | Why not |
|---|---|
| 11 copies of the `NSBitmapImageRep` setup in `IconGenerator` | Mostly the frozen macOS 15 path, which icon-system.md says gets no further investment; pixel-change risk for no user gain. |
| `SettingsBadgeIcon` repeats the glyph drawing | Deliberate raw-`Color` mirror, kept in lock-step by `BadgeColorMappingTests`. |
| `iconScale` not clamped on decode | The stepper allows only 10–22; only a hand-edited config reaches a bad value. |
| Raster cache keeps replaced bitmaps after an app update | A few KB each; every helper is rebuilt on every Dock Tile release. |

## Follow-up outside this plan
- `testing.md`'s seam list needs entries for round 1's `runRegenerationBatch(current:)` and the new tests.
  `testing.md` and `development.md` hold another session's uncommitted edits, so neither round edits them
  until that work lands.
