# Revert to Dock Version (2026-11-05)

Branch `feature/revert-to-dock` (worktree `../dock-tile-revert`, cut from `main` 4a955dc). Decisions
agreed with the owner in the 2026-11-05 grilling session (Q1–Q8). One batch, one commit.

**Problem.** Every edit in Tile Detail / Customise autosaves (300 ms) into the shared config — the
"draft" IS the config. An unintended removal or change has no way back: the only record of what the
Dock shows is `DTDockSignature`, a fingerprint, not a copy.

**Decided NOT to do:** auto-revert when Configure Tile is tapped (Q1 — it would discard drafts the user
reopened to finish); a copy held by the running helper (Q2 B) or in the shared config (Q2 C); per-field
revert or a diff view (Q3); undo of a revert (Q5); making migration / self-heal / Popover Apply build
from the copy instead of the draft (Q6 → follow-up issue); any change to the menu bar plan (Q7);
analytics parameters (Q8).

## Facts the plan rests on (checked in code, 2026-11-05)

- Every helper build — Add to Dock, Update, migration, self-heal, Popover Apply — goes through
  `HelperBundleManager.buildAndSwap` (HelperBundleManager.swift ~1913), whose `copy` step runs
  `generateHelperBundle` into the STAGING bundle before `sign` (graphify + read).
- A helper reads its config once at launch (`HelperAppDelegate` L121), so the Dock shows the tile as
  of its last build.
- `DockTileConfiguration` is `Codable, Hashable`; its `init(from:)` decodes tolerantly (missing keys →
  defaults), so a copy written by this build still loads in a later schema.
- `ConfigurationManager` encodes with `.iso8601` dates; `.sortedKeys` + `.prettyPrinted`.
- A tile hidden from the Dock keeps its helper bundle on disk (architecture.md "Never-pinned guard"),
  so a hidden tile can still revert; a never-added draft has no helper, so no copy.
- Tile Detail reads `builtDockSignature` in `updateDockState()` (on appear and after an action) —
  the place to read the copy too. Its name field is a separate `@State tileName`.
- `commitDisplayName(for:)` publishes the STORED name to the sidebar/title band.
- The File menu has no Revert item today (`DockTileApp.commands`); the View menu's inspector item is
  the house `FocusedValue` pattern (`InspectorCommand`).

## The change

1. **Write the copy (HelperBundleManager).** `nonisolated static let dockSnapshotFile =
   "DTDockSnapshot.json"` in `Contents/Resources`. In `buildAndSwap`'s `copy` closure, after
   `generateHelperBundle`, `try Self.writeDockSnapshot(config, inBundle: staged)` — JSON-encode the
   config (same strategies as ConfigurationManager). Before `sign`, so the seal covers it. A write
   failure fails the build like any other copy-step failure (old tile untouched — staged rebuild rule).
2. **Read the copy.** `func dockSnapshot(for config:) -> DockTileConfiguration?` beside
   `builtDockSignature`: `findExistingHelper` → read + decode (a `nonisolated static` decode taking a
   URL, so the test reaches it); nil when no helper, no file (built before this change) or undecodable
   (also a copy from a NEWER build an older one can't read — v1 keys / `IconType` throw: Revert stays
   disabled, acceptable). Gate N9: no `Date` fields, so encoder strategies are irrelevant — plain
   `JSONEncoder`.
3. **Pure seam (ConfigurationModels).** `func revertingContent(to snapshot:) -> DockTileConfiguration`:
   returns `snapshot` with `isVisibleInDock`, `lastDockIndex`, `helperAppVersion`, `bundleIdentifier`
   taken from `self`; returns `self` unchanged when `snapshot.id != id`. Starting FROM the snapshot means
   a future content field reverts by default — only bookkeeping is named (a forgotten new bookkeeping
   field would revert too; less likely, and visible in the test below).
4. **Tile Detail.**
   - `@State dockSnapshot`, set in `updateDockState()`.
   - `canRevert = !isProcessing && !HelperBundleManager.shared.isDockOperationInFlight(bundleId:)
     && dockSnapshot.map { editedConfig.revertingContent(to: $0) != editedConfig } ?? false`
     — full struct equality, so the saved symbol/emoji count (Q4), unlike `contentSignature`; cheap
     (no icon data in `AppItem` since 2026-09). The in-flight term is gate B2: a batch rebuilding this
     tile (launch migration after a Sparkle update, Popover Apply) must not be revertible mid-build.
   - Toolbar: a 4th `ToolbarItem(placement: .primaryAction)` BEFORE the action button, separated by
     the same `ToolbarSpacer(.fixed)` (macOS 26+). Icon-only `.bordered` button,
     `arrow.uturn.backward`, `.help` + accessibility label "Revert to Dock Version", always present,
     `.disabled(!canRevert)` (structure never changes — Tahoe toolbar quirk).
     **Amended in hands-on (owner, 2026-11-05): shown only while `canRevert`, hidden otherwise** —
     same `if` pattern as the inspector toggle; checked by eye, the item appears and goes cleanly.
   - `.help` on a disabled control never fires (development.md) — so the tooltip shows only while
     Revert is enabled. Accepted for a toolbar icon (the accessibility label is always there); check
     hands-on whether the toolbar behaves differently (gate N1).
   - Confirmation `.alert`: title "Revert to Dock Version?", message "Your changes will be replaced by
     the version in the Dock." (gate N7: true whatever built it — Update, migration or Popover Apply),
     buttons Cancel / Revert (destructive).
   - On Revert (gate B2): first call `updateDockState()` again — re-read the copy AND the signature —
     and bail out (no change) if the copy is now nil or already equals the draft; only then
     `editedConfig = editedConfig.revertingContent(to: snapshot)`, `tileName = editedConfig.name`,
     `persistEdits()` now, `appliedContentSignature = contentSignature(of: editedConfig)` (gate N2: so a
     hidden tile's Done isn't left enabled), `configManager.commitDisplayName`,
     `AnalyticsService.shared.log(.tileReverted)`, `DiagnosticsLog` `ui` + a non-verbose `tile` line
     with `diagnosticName`. The `onChange(of: editedConfig)` that follows re-arms the debounce and saves
     the identical config once more 300 ms later — harmless, same as `performDockAction` (gate N3).
   - `.focusedSceneValue(\.revertCommand, RevertCommand(isEnabled: canRevert, revert: { show alert }))`.
5. **File menu.** `RevertCommand` + key next to `InspectorCommand`; `RevertMenuItem` (same shape as
   `InspectorMenuItem`, no shortcut) in `CommandGroup(after: .saveItem)` — never `replacing:`, which
   would take File ▸ Close (⌘W) with it (gate B1).
6. **Analytics.** `case tileReverted = "tile_reverted"` — no parameters; the existing
   `AnalyticsEvent` name test covers it.
7. **Strings.** `AppStrings` keys for the button/menu title, alert title, alert message (the Revert
   button reuses a new `Button.revert`) → `l10n.py sync-keys`, machine pass for zh-Hans/ja/de/ru/fr
   (`needs_review`), `export`, `check`.
8. **Rules.** architecture.md: one paragraph under "Tile Detail action button" (the copy, where it is
   written/read, the seam, deferred Q6 follow-up). testing.md: add the seam to the list.

## Tests (new file `DockTileTests/Unit/Models/DockSnapshotRevertTests.swift`, `struct DockSnapshotRevertTests` — exact name, so `-only-testing:DockTileTests/DockSnapshotRevertTests` runs exactly 4)

- `revertTakesEveryContentFieldFromTheCopy`: a snapshot with every content field non-default and a
  current config differing in every content field and every bookkeeping field → the result's encoded
  JSON equals the snapshot's except the four bookkeeping keys, which equal the current's. Fails if the
  seam copies bookkeeping from the snapshot, or content from the current config.
- `revertIgnoresAnotherTilesCopy`: snapshot with a different `id` → result == current.
- `revertOfAnUnchangedTileIsANoOp`: current == snapshot content → `revertingContent(to:) == current`
  (the `canRevert == false` case).
- `snapshotRoundTripsThroughTheBundleFile`: write via `writeDockSnapshot` into a temp "bundle"
  (`realpath()`d), read back via the same decode the reader uses → equal. (Requires the read's decode to
  be a `nonisolated static` helper taking a URL, so the test does not need `findExistingHelper`.)

Negative control: flip the seam to return `snapshot` unchanged → the first test fails on the
bookkeeping keys; then restore.

## Done means

- Suite green (`-only-testing:DockTileTests`, Default icon style), new suite's 4 tests in the per-test
  lines; `l10n.py check` + the l10n unittest green.
- Signed dev rebuild (`codesign --verify`), hands-on on a dev tile: Update → remove an app + change the
  colour → Revert enables → Revert → alert → apps and colour back, sidebar name right, Update quiet,
  Revert disabled; File ▸ Revert to Dock Version mirrors it; a never-added tile shows Revert disabled;
  `ls` the helper's Resources shows `DTDockSnapshot.json` and `codesign --verify` on the helper passes;
  File ▸ Close (⌘W) still closes the window (B1); with the tile open, rebuild it from outside Tile
  Detail (Popover Settings → Save → Apply), then edit → Revert restores the REBUILT version, not the
  one read on appear (B2); the title band in German at the 700 pt minimum width keeps all four items
  visible (N8).
- `stage-gate --dev` before push; CI on the branch before merge.

## Risks

- **Existing helpers have no copy** until rebuilt: Revert stays disabled for them until their next
  Update or the next version-bump migration. Expected; say so in release notes.
- **A background rebuild publishes the draft** (Q6, unchanged): after migration / Popover Apply the
  draft IS the Dock version, so Revert has nothing to restore. Sparkle installs silently and releases
  are frequent, so the honest promise is "Revert works until the next app update, Popover Apply or
  self-heal" — say it in the release notes (gate N5). Follow-up GitHub issue filed before merge.
- **The popover reads the config at helper launch, not at build** (gate N4): Start at Login relaunches
  every visible helper, so after a reboot a popover can already show a draft; after a Revert a running
  helper keeps showing the draft until it relaunches. Same gap Update's prominence check has today; not
  made worse — Revert restores the BUILD (icon, name, the version Update would re-apply).
- **Merge with `feature/menu-bar-13`** (gate N6): both touch `AppStrings.swift`, the catalog and
  `docs/l10n/*.md`; whichever lands second re-runs `sync-keys` / `export` / `check`.
- **Path-only differences enable Revert**: `scanForMissingApps` heals an `AppItem.lastKnownPath`, which
  makes the draft differ from the copy with no visible change; reverting restores the old path, which
  the next scan heals again. Rare (an app moved); accepted.
- **Copy size**: one tile's config JSON (no icon data since 2026-09) — a few KB per helper.
