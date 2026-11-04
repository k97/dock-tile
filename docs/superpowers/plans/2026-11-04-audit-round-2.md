# Audit round 2 (2026-11-04)

Everything from the 2026-11-04 whole-repo audit that round 1 (`2026-11-04-audit-must-fix.md`, items 1–5)
did not cover. The first version of this plan (25 changes) went through the plan gate ("Needs answers") and
then an owner review that cut it to the 12 items below; every other item is under "Not doing", with its
reason. All decisions were made by the owner on 2026-11-04, one question at a time. The trimmed plan's
gate (run 2) found every fact true and asked two blocking questions (how catalog entries leave; when the
list height is pinned); both are answered below, and its text notes are applied.

**Branch:** `fix/audit-must-fix`, the same branch as round 1. Both rounds merge together and ship in one
release. One commit per item. **Code state:** round 1 done at `fd3592b`. Line numbers were read there.

**Verification for every commit:** a build, plus the item's own check below. Before the `--dev` gate: the
full suite on the Default icon style, the l10n commands whenever strings change, a signed rebuild with
`codesign --verify`, and a dev-app relaunch. Then a regression pass over both rounds (CI on macOS 26 and
macOS 15, an independent caller-by-caller review, and the hands-on checks named below), then the
`--release` gate, the merge and the release.

Load assumed: one person, one Mac, ~5–30 tiles; helpers run all day.

---

## A1 · A tile named only with emoji or punctuation (audit #6)

- **Facts:** `sanitizeAppName` (HelperBundleManager.swift:2029-2035) keeps letters, digits, `-`, `_` and
  space. `preferredHelperPath` (:320-331) builds `cleanPath = "\(base).app"` and checks it is free BEFORE
  calling the pure seam `helperFolderName` (:336). So "🚀" → `<support>/.app`, a hidden folder.
  `URL(fileURLWithPath: "/a/.app").pathExtension == ""` (checked), so `findExistingHelper` (:164-179,
  `item.pathExtension == "app"`) never finds it: Update, Delete and self-heal miss the bundle.
  `buildAndSwap` passes the SANITIZED name as `appName` (:1960), so `CFBundleName` is "" (blank in ⌘Tab
  and Force Quit) and "Work & Play" reads "Work  Play".
- **Change:**
  1. In `preferredHelperPath`, fall back BEFORE building `cleanPath`: an empty sanitized name uses
     `config.shortId`. Put the rule in a pure seam (e.g. `helperBaseName(sanitized:shortId:)`), so it is
     testable and the path check and the folder name read the same value.
  2. `findExistingHelper` also accepts a folder named exactly `.app` (the legacy emoji-tile folder), so the
     next rebuild finds it as the tile's existing folder, and `oldFolderToRemove` removes it after the
     swap. The release's version bump rebuilds every pinned tile, so existing users are cleaned up then.
  3. Pass the unsanitized `config.name` as `appName` to `generateHelperBundle`. Check every other reader
     of `appName` there first: the folder already comes from `preferredHelperPath`.
  4. `LoginTileSpawner.helperBundleURL` (:90-104) mirrors the scan but is NOT changed: login-items.md
     keeps it free of `HelperBundleManager`, and the legacy `.app` folder is gone after the release's
     rebuild. Until then an emoji tile's helper is not warmed at login, which is today's behaviour.
- **Behaviour change, stated:** after their next rebuild, existing tiles whose names hold punctuation or
  emoji get their real name as `CFBundleName` / `CFBundleDisplayName`, and so as the Dock tooltip
  (`dockFileLabel`). What ⌘Tab and Force Quit show is not documented
  (docs/dock-tile-display-names.md §3), and Ghost tiles appear in neither, so that is checked by eye, not
  claimed. `dockSignature` already uses `config.name`, so no tile starts reading "Update pending".
- **Verify:**
  - Seam tests: empty → the short id; non-empty → unchanged.
  - A real-filesystem `HelperSwapTests` case (with `realpath()`): a bundle at `<dir>/.app` carrying the
    tile's bundle id is found by the same scan rule (extract the scan's filter as a seam if needed).
  - The unsanitized-name change (step 3) is code-read only: `helperInfoPlist` assigns `appName` as given,
    so a test of it could not fail on the call-site regression (testing.md "A guard must be able to fail").
  - By eye (owner, dev build): App-mode tiles named "🚀" and "Work & Play" show those names in ⌘Tab and
    their Dock tooltip after Update; a "🚀" tile's folder is `<shortId>.app`.
  - Negative control: drop the fallback → the empty case returns ".app".

## A2 · Turning analytics off reaches running helpers (audit #7)

- **Facts:** each process applies consent once, in `configure()` (AnalyticsService.swift:106-124).
  `setConsent` (:128-131) re-applies only in the main app; its one caller is GeneralSettingsView.swift:177.
  A helper started at login keeps Analytics and Crashlytics collection on after the user opts out.
- **Change:**
  1. `setConsent` posts a distributed notification after persisting, `deliverImmediately: true` (AppKit
     holds distributed notifications for an inactive app, and helpers are always inactive; the same as
     `TileRebuildSignal`). The name is ONE `static let` used by both the post and the observer, which is
     the structural guarantee that they match.
  2. In helpers only (`AppEnvironment.isHelper`), `configure()` registers an observer that calls
     `applyCollectionState()` on the main actor (`.main` queue + `MainActor.assumeIsolated`, the
     `TileRebuildSignal` pattern).
  3. `consentGranted` reads the shared suite synchronize-first (`CFPreferencesAppSynchronize` on the
     suite), because architecture.md records a cross-process cfprefsd cache split that made a read stale.
- **Accepted:** any local process can post the notification. The worst it can do is make a helper re-read
  the real setting (the same class `TileRebuildSignal` accepts).
- **Verify:** Debug never collects (`isRelease` false), so the end-to-end path cannot run on the dev build,
  and a unit test of the name would be decorative. Hands-on (dev build; `GoogleService-Info.plist` ships in
  Debug, so `configure()` runs): toggle the setting OFF then ON, and see a running dev helper's pid log a
  non-verbose `[analytics] consent re-applied (consent=false)` then `(consent=true)`. Logging `consent`, not
  `collect` (always false in Debug), is what shows the re-read is fresh. The line stays.

## A3 · A long List popover runs off the screen (audit #8)

- **Facts:** the list rows are a plain `VStack` (NativePopoverViews.swift:858-878) with no `ScrollView`;
  `PopoverPanelLayout.listPanelSize` (PopoverAppearance.swift:398-420) has no cap. The grid caps the WHOLE
  panel at `gridScrollCap` 600 (NativePopoverViews.swift:546; PopoverAppearance.swift:319) and scrolls
  inside it (:446). The list pins only its width and takes an intrinsic height (popover-appearance.md).
- **Change (owner decisions: the grid's whole-panel cap; pin only past it):** `listPanelSize` stays
  uncapped, like `gridPanelSize` (the grid caps in the view, `min(totalHeight, gridScrollCap)`, :546). A new
  pure seam returns the rows' scroll height: `nil` when the uncapped panel estimate is ≤ `gridScrollCap`
  (the list keeps today's intrinsic `VStack`, unchanged), else `gridScrollCap` minus header, utility rows
  and outer padding. Only past the cap do the app rows go into a `ScrollView` framed to that height, with
  the header and the utility rows outside it, always visible. The estimate over-reserves on purpose
  (~24 pt utility rows), so pinning every list from it would show slack or clipping on every list tile;
  past the cap the slack only shortens the scroll area. Edit mode never scrolls (same as the grid,
  :540-546).
- **Comments and rules that become false** (fix them in this commit): NativePopoverViews.swift:901-902, the
  `listPanelSize` doc comment, popover-appearance.md ("the list pins only its width"). testing.md's
  `listPanelSize` entry joins the testing.md follow-up below.
- **Not in scope:** keeping the arrow-key selection in view while scrolling. The grid doesn't do it
  either; it is filed as a follow-up issue (owner decision).
- **Verify:**
  - The rows seam: 3 apps → `nil`; 40 apps → exactly `gridScrollCap` minus the chrome (a literal computed
    from the layout constants in the test); edit mode → `nil`.
  - Negative control: make the seam always return `nil` → the 40-app case fails.
  - No existing `listPanelSize` / `PopoverPreviewCanvas` test changes: none reaches 600 pt.
  - By eye (owner, dev build): a 30-app list tile scrolls, with the header and gear row visible.

## A4 · Hiding one tile can unpin another broken tile (audit #9)

- **Facts:** `removeFromDockPlist` (HelperBundleManager.swift:1401) matches its own entry by
  `tile-data.bundle-identifier` first (:1416); `addToDock` always writes that key (+Dock.swift ~:409). Then
  a sweep (:1444-1451) drops ANY entry whose path contains "DockTile" and whose Info.plist is missing:
  another tile's pinned-but-missing bundle, which is the case self-heal repairs. It also runs inside
  `refreshDockEntry` (:1492), so a batch re-seat can delete other tiles' broken entries.
- **Change:** delete the sweep, and fix the comment at :245 ("also sweeps stale entries").
- **Trade-off, stated:** an orphan entry whose tile no longer exists in the config is no longer cleared by
  any Hide or Delete. Self-heal only walks configured tiles, so such an entry stays until the user removes
  it from the Dock by hand.
- **Verify:** build + full suite; grep that nothing depends on it.

## A5 · The Dock right-click menus can't open folders (audit #10)

- **Facts:** both menus store `appItem.bundleIdentifier` and resolve it with `urlForApplication`:
  HelperAppDelegate.swift:376 + :498-520 (the App-mode tile menu; it logs `appLaunchedFromTile`
  `source: "context_menu"` itself) and AppDelegate.swift:355 + :379-394 (the main app's Dock menu; logs
  nothing). A folder's id is `folder.<hash>`, so clicking it does nothing. Web apps sharing a bundle id open
  whichever copy Launch Services picks.
- **Change:** both set `representedObject = appItem` and call `AppLauncher.launch(item, source:)`, with
  `"context_menu"` (unchanged) and `"main_dock_menu"`. The helper handler's own log line goes, because
  `AppLauncher.launch` logs (AppLauncher.swift:17). Owner decision: the main-app path now produces
  `app_launched_from_tile` with `source: "main_dock_menu"`; `source` is an existing parameter. Add
  `main_dock_menu` to the `source` values listed in `AppLauncher.launch`'s doc comment.
- **Verify:** build + full suite. By eye (owner): an App-mode tile's Dock menu opens a folder, and the main
  app's Dock menu opens an app.

## A7 · A custom tile colour is saved in the wrong colour space (audit #12)

- **Facts:** `Color.toHexString` (CustomiseTileView.swift:806-819) converts through `.deviceRGB` and
  truncates; its one caller is the colour panel (:506). Every reader treats the hex as sRGB. The same file
  already converts correctly at :403-407 (sRGB, clamped, rounded).
- **Change:** make that correct conversion one function (e.g. `static func srgbHex(_ color: Color) ->
  String?`), used by both call sites; delete `toHexString`.
- **Verify:** a test with a pinned literal: `#5F00FF` round-trips unchanged, and a fixed Display P3 colour
  gives a hex literal written into the test. Negative control: the old deviceRGB path gives a different
  hex for that P3 colour.

## C1 · Dead code (audit #13; every symbol grepped across DockTile/, DockTileTests/, DockTileUITests/, Scripts/)

Delete:
- `ConfigurationManager.addAppItem` / `removeAppItem` / `reorderAppItems` (:367-410) and `stopDockWatcher`
  (:814)
- `LauncherView.DesignTokens`
- `HelperBundleManager.removeFromDock(at:)` (:1498)
- `isInDock(at:)` (+Dock.swift:35), together with its `HelperBundleLifecycleTests` call
- `HelperBundleError.mainAppNotFound`: also `AppStrings.Error.mainAppNotFound`, its `AppStringsTests` case
  and its `HelperBuildExclusionTests` entry
- `appSwitcherChanged` in `performDockAction`: the `let` (:654), its `if` + print (:719), and
  `originalConfig` plus the comment above it (:650-653), which only that `let` used
- the one-argument `IconStyle.from(preferencesValue:)` / `.resolve(preferencesValue:)`
  (IconStyleManager.swift:81-89)
- `ListMenuRow.hasSubmenu`, its chevron branch and the `hasSubmenu:` arguments (NativePopoverViews.swift:889,
  :896)
- the analytics events `tileShown` / `tintColorChanged` / `layoutModeChanged`
- the AppStrings keys `popoverLayout` / `dockLockAccessibilityGranted` / `settingsSectionHeader`
- **Catalog entries stay (owner decision 2026-11-04):** `l10n.py` has no remove command, hand edits other
  than English values are forbidden, and the tests require only code keys ⊆ catalog. The four entries
  (these three plus `error.mainAppNotFound`) stay as unused rows, ship as a few bytes and break nothing.

Also fix every comment or rule that names a deleted symbol (coding-guardrails: grep the words): the header
comment in `HelperBundleManager+Dock.swift` (:9), and architecture.md's "Reliable reads", which lists
`isInDock`.

Verify: build, the full suite, `l10n.py check` + the l10n unit tests, and a grep of each deleted name that
returns nothing.

## C2 · Stray files (audit #14)

`git rm` all five, nothing references any of them:
- `Scripts/generate_helper.sh`
- `Scripts/add-string.py` (re-dumps the catalog, which localization-macos.md forbids)
- `DockTile.xcodeproj/project.pbxproj.bak`
- `add_files_to_xcode.py` (tracked since the initial commit)
- `Scripts/setup-tests.sh` (prints instructions, no callers)

Old plan docs that mention `add-string.py` stay; they are history.

Verify: `git grep` for each name returns only those plan docs; build.

## C3 · Colour helpers that `TilePalette` replaced (audit #15)

Re-grep each before deleting; anything with a production caller stays:
- `TintColor`/`PresetColor` `colorTop` / `colorBottom` / `color` (keep `PresetColor.colorBottom`, used at
  CustomiseTileView.swift:490)
- `Color.lighterShade` + `Color.toHex` (ColorExtensions.swift:41-85)
- `Managers/AppearanceManager.swift`: `NSColor(hex:)` is used only by GlyphLayerRenderTests:84;
  `Color(_ nsColor:)` only forwards to `Color(nsColor:)`. Rewrite its call sites, fix the file header that
  calls the code "live", and remove the file's pbxproj entry
- the test-only `IconGenerator` forwarders / `symbol:` overloads / `generatePreview`
- the `static let IconDepthMetrics.warningThreshold` (:75). NOT `warningThreshold(for:)` (:79), which is
  live
- the legacy `DockTileIconPreview` initialisers used only by `#Preview` and one test

Repoint the tests at `TilePalette` / `IconDepthMetrics` / the full init. Tests to delete or rewrite (gate
read): ColorExtensionsTests.swift:138-260 (`toHex`, `lighterShade`), TintColorTests,
ConfigurationModelsTests.swift:599-611, TilePaletteTests.swift:139-141 (preset `colorTop`),
IconGeneratorTests.swift:79, IconDepthMetricsTests.swift:86.

Comments and rules that name a deleted symbol (grep the words): TilePalette.swift:47
(`Color.lighterShade`), icon-system.md:233 (`colorTop`/`colorBottom`), :292 (the
`IconGenerator.warningThreshold` forwarder) and :468 ("Custom Colour Gradients"),
IconPreviewGeometryTests.swift:274.

Verify: build, the full suite, and a grep of each deleted name.

## D1 · Diagnostics log grows forever for users who never open the main app (audit #17)

"Popover shown …" is logged non-verbose on every open (HelperAppDelegate.swift:327); only a main-app
launch trims the file.

Change: `verbose: true`. It is per-click churn (diagnostics.md). memwatch parses "✔ Show popover", not
this line.

Verify: build; code-read only.

## D4 · The gear button leaks a cursor push (audit #20)

`NSCursor.pointingHand.push()` on hover (NativePopoverViews.swift:423-429): clicking the gear closes the
popover before the hover ends, so the `pop()` never runs.

Change: `.pointerStyle(.link)`, which is macOS 15+ and fits the 15.0 floor.

Verify: build. By eye (owner): after clicking the gear, the cursor is an arrow again.

## B5-min · iconutil reads stderr after waiting

`IconGenerator.swift:888-905` reads its stderr pipe only after `waitUntilExit`, the pipe-order pattern
development.md forbids (harmless while stderr is small).

Change: read stderr to EOF before `waitUntilExit`. Nothing else: the error keeps its shape (putting the
text in it would change `IconGeneratorError.icnsConversionFailed` and its tests, IconGeneratorTests.swift:440,
for no user gain).

Verify: build; the legacy-path tests in the full suite.

---

## Not doing (owner decisions, 2026-11-04)

| Item | Why not |
|---|---|
| A6 watcher re-arm after the Dock plist is deleted | Only after a manual `defaults delete com.apple.dock`; heals on relaunch; the retry needs pending/stopped flags (gate F4). |
| B1 a failed bundle delete skips the restart | Needs `removeItem` to fail on our own folder; never seen. |
| B2 a batch restarts with nothing to check | Popover Apply with no pinned tile; rare, and the restart is harmless. |
| B3 two same-named tiles built at once | Needs two tiles renamed to one name and built concurrently; never seen. |
| B4 re-seat picking a stale renamed copy | Only after a failed old-folder delete. |
| B5 watchdog for hung build tools | No hang ever seen; round 1 accepted the risk. Revisit if a stuck build appears in a diagnostics report. |
| B6 Start-at-Login reconcile off the main thread | ~20 ms once per launch; moving it can race a toggle. |
| B7 one hex parser | Only a hand-edited config reaches the bad input. |
| C4 small duplicates | In code this round does not touch. |
| D2 Smart Add writes on every app switch | A small cost; performance-measurement.md wants a number first. |
| D3 App Grid desaturation per redraw | The same; measure first. |
| E1 per-cell Launch Services probes, E2 a stale icon-style read in helpers | Measure only if a symptom is reported. |
| Arrow-key selection scrolling into view | Separate follow-up issue (shared by the grid and the list). |
| 11 copies of the bitmap setup in `IconGenerator` | Mostly the frozen macOS 15 path; pixel risk for no user gain. |
| `SettingsBadgeIcon` repeats the glyph drawing | A deliberate mirror, kept in lock-step by `BadgeColorMappingTests`. |
| `iconScale` not clamped on decode | The stepper allows only 10–22. |
| The raster cache keeps replaced bitmaps | A few KB each; every helper is rebuilt each release. |

## Follow-ups outside this plan

- `testing.md` (seam list: `runRegenerationBatch(current:)`, `ConfigReadFailureTests`, round 2's new seams)
  and `development.md` (read failure vs decode failure) hold another session's uncommitted edits. Update
  them once that work lands.
- File the arrow-key scroll-into-view issue.
