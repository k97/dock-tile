# Audit must-fix round (2026-11-04): items 1–5

Source: the 2026-11-04 whole-repo audit (ponytail-audit, four read-only reviewers, top findings verified
in code). Owner decisions this session: scope = items 1–5 only (6–8 next round); finding 5 = **refuse
to save**; branch `fix/audit-must-fix` in the main checkout, one commit per finding, no push until asked;
the full unit suite may be run (Mac on the Default icon style), then rebuild signed.

Constraint: the main checkout holds another session's UNCOMMITTED edits to `.claude/rules/development.md`
and `.claude/rules/testing.md`. This round never stages, edits or reverts those two files. Rule updates
go to `architecture.md` / `login-items.md` only; the `testing.md` seam-list entry for the changed seam
is reported to the owner as a follow-up instead of edited.

Not doing: items 6–20 of the audit; any refactor; any UI change beyond what each fix needs.

## Commit 1 — a deleted tile is never rebuilt or swapped back in (audit #1)

Facts (read 2026-11-04):
- `ConfigurationManager.deleteConfiguration` (ConfigurationManager.swift:294-334) removes the config and
  saves SYNCHRONOUSLY, then calls `HelperBundleManager.uninstallHelper` in an unstructured `Task`. Two
  callers: Tile Detail's Delete (DockTileDetailView.swift:800) and the sidebar context menu
  (DockTileSidebarView.swift:236). So a refusal inside `uninstallHelper` cannot save the tile — the
  config is already gone; the only safe behaviour is to WAIT.
- `uninstallHelper` (HelperBundleManager.swift:220) checks no in-flight build. `installHelper` and
  `regenerateHelperBundle` hold `buildingBundleIds` for their whole body (`defer`), and the staged swap
  inside them renames the new bundle into the final folder and launches it.
- `HelperMigrationManager.regenerateBatch` (HelperMigrationManager.swift:238) builds every tile from the
  `configs` array captured when the batch began, and after the loop re-seats / expects / relaunches from
  the same stale array. Callers: launch migration, self-heal, Popover Apply (`reapply`).

Changes:
1. `uninstallHelper`: before anything else, wait while
   `isDockOperationInFlight(bundleId: config.bundleIdentifier)` (HelperBundleManager.swift:1683 —
   building ∪ removing ∪ verifying) — `try await Task.sleep(for: .milliseconds(250))` per pass, one
   non-verbose `dock` log line when it starts waiting. Waiting on BUILDS alone left a window (gate run 2,
   F3): a delete during the batch's ~6 s verified restart, with the verify ending inside the uninstall's
   300 ms quit-sleep, let `launchHelperIfExists` relaunch the helper just before its bundle was deleted (a
   running process with no bundle). Holding until verification ends closes it: the batch relaunches
   synchronously right after its verify returns, and the uninstall then quits and deletes. No bound: a
   build always ends (its `defer`), and proceeding early is exactly the orphan.
   Plus `quitHelper` AGAIN after `removeItem` (gate run 3, N1), mirroring the staged rebuild's "quit
   again": it covers a helper the build's `launchNew` started that wasn't yet in `runningApplications`
   when the first quit looked, and a tile dragged off mid-batch (not counted as verifying) relaunched
   during the 300 ms quit-sleep.
2. `runRegenerationBatch(_:current:regenerate:)` gains a REQUIRED `current: (UUID) ->
   DockTileConfiguration?` (no default, so every caller must decide). At each tile's turn it re-reads
   `current(config.id)`: nil → skip (not regenerated, not stamped, `regenerate` not called); else
   `regenerate(latest)`.
3. `regenerateBatch` passes `{ self.configManager.configuration(for: $0) }`, and builds
   `regeneratedConfigs` as `outcome.regeneratedIds.compactMap { configManager.configuration(for: $0) }`
   (fresh values; a tile deleted after its own build drops out of re-seat / expectations / relaunch).

Assumption (checked by the plan gate): `HelperMigrationManager.configManager` is the same
`ConfigurationManager` instance the editor and sidebar mutate (DockTileApp:72, PopoverAppearanceView:416).

Plan-gate notes (2026-11-04), resolved:
- **Verify-retry re-pin window (gate F1) — already closed, no change.** The batch's retry re-adds an entry
  through `addToDock(at:)`, which returns when the bundle has no Info.plist (HelperBundleManager+Dock.swift:229),
  so it cannot pin a deleted tile. `uninstallHelper` removes the plist entry and deletes the bundle with no
  `await` between them, so the main-actor retry cannot interleave there either.
- **Behaviour shift (gate F3), stated:** the batch now bakes edits (renames included) saved after the batch
  began, instead of the launch-time snapshot. Same capability, later timing. Target selection (which tiles
  self-heal / Apply rebuild) still uses the start-time list; a tile hidden mid-batch is still rebuilt, as
  before (`refreshDockEntry` only re-seats pinned tiles, so no re-pin).
- **Unbounded wait (gate F4), accepted:** a build ends only when its function returns; a hung `codesign` /
  compile `waitUntilExit` would make the delete wait forever. Proceeding early is the orphan, so the wait
  stays unbounded; a compile timeout is round-2 work (round-2 B5). architecture.md "Deletion" gains
  "first waits for any in-flight Dock operation on the tile (build, removal, verification)".

Verify:
- New tests in `HelperMigrationTriageTests`: (a) a config whose `current` returns nil is neither
  regenerated nor stamped and `regenerate` is never called for it; (b) `regenerate` receives the
  `current` value (a renamed copy), not the input copy. Failing value: without step 2, (a) reports the
  deleted id and (b) sees the old name.
- The three existing `runRegenerationBatch` tests updated to pass `current` over their own inputs; still
  green.
- Step 1 has no unit test (async wait on a private MainActor set); stated as a known gap. Hands-on
  (owner, optional): delete a dev tile from the sidebar while Popover Apply rebuilds it → the dev log shows
  the wait line and no helper for that tile remains running or on disk.

## Commit 2 — an edit can't undo the migration stamp (audit #3)

Facts: `preservingStoredVisibility` (ConfigurationManager.swift:270-279) copies `isVisibleInDock` and
`lastDockIndex` from the stored config, not `helperAppVersion`. The edit session is created when the
window first renders; launch migration stamps `helperAppVersion` in the manager afterwards; the next
debounced save writes the session's old stamp back → next launch rebuilds that tile and restarts the Dock.

Change: add `result.helperAppVersion = stored.helperAppVersion`; update its doc comment ("bookkeeping
the editor never owns"); update architecture.md "Visibility ownership" sentence ("The auto-save
preserves the stored visibility/`lastDockIndex`" → also `helperAppVersion`).

Verify: new `VisibilityOwnershipTests` case — edited carries `helperAppVersion "2.6.2"`, stored `"2.6.3"`
→ result `"2.6.3"`; a second assertion that stored `nil` wins over an edited value. Failing value:
without the line the result keeps `"2.6.2"`.

## Commit 3 — Update keeps edits made while it runs (audit #2)

Facts: `performDockAction` (DockTileDetailView.swift:642-750) copies `editedConfig` into `configToSave`,
awaits the build + verified Dock restart (seconds; only the action button is disabled), then
`updateConfiguration(configToSave)` and `editedConfig = configToSave; tileName = configToSave.name` —
overwriting any edit saved by the 300 ms debounce meanwhile.

Change: after the action, save
`ConfigurationManager.preservingStoredVisibility(editedConfig, stored: configToSave)` — the latest edits,
with the Dock bookkeeping (`isVisibleInDock`, `lastDockIndex`, and, from commit 2, `helperAppVersion`)
taken from what the action did — and set `editedConfig` / `tileName` from that value. Unchanged on
purpose: analytics, logs and `appliedContentSignature` keep using `configToSave` (what was applied), so a
mid-action edit leaves the editor dirty and Update prominent. Comment at the call site says why the seam
is reused here.

Gate F5, stated: for `.remove` and `.saveOnly`, `configToSave.helperAppVersion` is the session's own
(possibly stale) stamp, not a fresh one. Harmless: both leave the tile hidden, and migration stamps a hidden
tile without rebuilding (`stampOnly`).

Accepted: `commitDisplayName` then commits the latest name, so a rename typed during an Update shows in
the sidebar although the Dock still has the acted name until the next Update. Today that rename is lost
entirely.

Verify: no unit test reaches a view's async action (stated gap). The seam it reuses is covered by
`VisibilityOwnershipTests` (incl. commit 2's new case). Hands-on (owner, optional): press Update on a dev
tile and rename it within the build seconds → after the bar clears, the saved config (`jq '.[].name'
~/Library/Preferences/com.docktile.dev.configs.json`) holds the new name.

## Commit 4 — Start at Login no longer deletes unrelated LaunchAgents (audit #4)

Facts: `LoginItemManager.enable()` calls `cleanupLegacyPerTileAgents()` (LoginItemManager.swift:94,
145-167), which `launchctl bootout`s and deletes every `~/Library/LaunchAgents/<helperPrefix>.*.plist`
except the launcher — `com.docktile.dev.memwatch` matches the dev prefix. Its comment says it cleans
"unreleased work"; `git log -S cleanupLegacyPerTileAgents` shows it arrived in 11b9a05 (2026-06-18,
"login-items WIP") together with the launcher design, so no release ever wrote per-tile agents.

Change: delete the function and its call (also removes a main-thread `waitUntilExit`). Remove any
mention in CODE COMMENTS only — login-items.md:14 ("per-tile agents are noisy/'Unknown'") is the reason
for having one agent and stays.

Verify: `git grep -n "cleanupLegacyPerTileAgents\|per-tile agent" -- DockTile DockTileTests` → nothing;
build green. The toggle is NOT flipped as a check (that would exercise SMAppService on the owner's Mac);
the deletion is the proof. The Release prefix `com.docktile.` matches `com.docktile.dev.memwatch` too, so
this fixes both builds.

## Commit 5 — a config file that can't be read is never overwritten (audit #5)

Facts: `loadConfigurations` (ConfigurationManager.swift:500-513): a `Data(contentsOf:)` failure on an
EXISTING file logs and sets `configurations = []`; the next `saveConfigurations` (any create/edit/delete,
or migration's `saveAllConfigurations`) atomically replaces the file with that empty list. The decode
path already keeps an `.unreadable-<UTC>.json` copy (7e5c78d); the read path cannot copy what it cannot
read.

Owner decisions: refuse to save; and (after the plan gate's F2 — a session that can't save still
lets the user create a tile and press Add to Dock, pinning a helper whose config is never written) the
main app shows ONE alert and QUITS, so no such session exists.

Change:
1. `private(set) var readFailed = false`; the read `catch` sets it, logs non-verbose
   ("FAILED to read configurations — saving is OFF …") and records a `config_read` non-fatal via
   `AnalyticsService.record`. Main app only for the non-fatal (helpers load, never save — same guard
   style as `reportUnreadableConfig`).
2. `saveConfigurations`: `guard !readFailed else { log non-verbose "save REFUSED"; return }` — the
   defence for anything that saves before the alert (init's launch reconcile, a migration).
3. `DockTileApp`'s window `.task`, FIRST thing after the `isRunningTests` guard: if
   `configManager.readFailed`, show an `NSAlert` (warning style) with one button, then
   `NSApp.terminate(nil)`. Before migration, so no batch runs. Copy (owner-approved 2026-11-04 — the
   alert is modal and quitting is its only button, so it must not point at Copy Diagnostics):
   - title: "Dock Tile Can’t Read Your Tiles"
   - message: "Dock Tile couldn’t open its settings file and quit without changing it, so your tiles are
     still in it. Check that you can open %@, then open Dock Tile again." (`%@` = the config file's path,
     `AppEnvironment.preferencesURL.path` — `storageURL` is private; the format placeholder must survive
     every translation — `check` enforces parity)
   - button: "Quit"
4. Three new keys (alert title, alert message, button) — new keys, never reusing `itemMenu.quit`
   (different context). Localization, the repo's route (docs/l10n/README.md:30; `l10n.py` has no machine
   command and non-English catalog entries are never hand-edited): add the three `NSLocalizedString`
   accessors to `AppStrings.swift` → `python3 -I Scripts/l10n/l10n.py sync-keys` → `… export` → fill the
   Translation column of the three new rows in `docs/l10n/{zh-Hans,ja,de,ru,fr}.md`, status `machine`,
   checked against `docs/l10n/GLOSSARY.md` → `… import <lang>` for each of the five → `… check`.
   Without the imports, `LocalizationCatalogTests`' per-language completeness test fails.
5. Testability: `init(storageURL: URL = AppEnvironment.preferencesURL)` (the only new parameter; every
   existing `ConfigurationManager()` call keeps working).

Accepted: Dock Lock is off until a launch reads the file; helpers (which read the same file) show empty
popovers meanwhile — they cannot read it either.

Stated assumptions (gate run 2):
- The alert appears when the main window's `.task` runs. If the app is resident with no window (Dock
  Lock on, window closed), the alert waits until the window opens; meanwhile ⌘N only creates a tile in
  memory, its save is refused, and nothing can pin it (Add to Dock lives in the window). Accepted.
- The relocation nudge and the translation invite are queued with `asyncAfter` on the main queue and can
  open on top of this alert inside its `runModal`. Minor and Release-/language-specific; accepted.
- Nothing saves or touches the Dock before the alert: `init`'s reconcile loops over an empty list, the
  AppDelegate launch path writes neither the config nor the Dock plist, and there is no
  `applicationShouldTerminate` override; the editor's willTerminate flush is never built at zero tiles
  (and the guard refuses it anyway).

Verify: new `ConfigReadFailureTests` (serialized, temp dir resolved with `realpath()`):
- (a) write known bytes, `chmod 000`, `ConfigurationManager(storageURL:)`, `saveAllConfigurations()`,
  `chmod 600`, file bytes == the original. Failing value: without the guard the atomic save replaces it
  with `[]` (the directory is writable, so the rename succeeds) and the bytes differ.
- (b) no file at the path → `saveAllConfigurations()` writes `[]` (a fresh start still saves).
- (c) the unreadable case sets `readFailed == true`; the missing-file case leaves it false.
- Test (a) restores `chmod 600` in a `defer`, so a failing run leaves no unreadable temp file.
- Neither test touches `UserDefaults.standard` (empty config list → `restoreOrAutoSelectConfig` writes
  nothing) nor the Dock (`isRunningTests` guard in init).
- The alert + quit (step 3) has no unit test (view `.task`, NSAlert); stated gap. Hands-on (owner,
  optional): `chmod 000` the DEV config, launch the dev app → the alert shows, Quit quits, the file's
  bytes are unchanged; then `chmod 600` it back.
- `python3 -I -m unittest discover -s Scripts/l10n -p 'test_*.py'` and `python3 -I Scripts/l10n/l10n.py check` green.

## Whole-round verification

1. Build Debug: `xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build`.
2. Targeted: `-only-testing:DockTileTests/HelperMigrationTriageTests`, `…/VisibilityOwnershipTests`,
   `…/ConfigReadFailureTests` — report per-suite executed counts.
3. Full suite (CLAUDE.md command, Default icon style) → `TEST SUCCEEDED`.
4. Negative controls (throwaway local edits, reverted with `git checkout -- <file>` before commit):
   remove commit 2's line → the new VisibilityOwnershipTests case fails; remove commit 5's guard →
   ConfigReadFailureTests (a) fails; replace commit 1's `guard let latest` skip with
`let latest = current(config.id) ?? config` → triage test (a) fails.
5. Rebuild Debug WITHOUT `CODE_SIGNING_ALLOWED=NO`; `codesign --verify` passes.
6. `--dev` stage gate on the branch diff before any push.
