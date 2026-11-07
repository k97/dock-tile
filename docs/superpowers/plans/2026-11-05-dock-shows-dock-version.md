# Plan — the Dock shows the Dock version (2026-11-05)

Branch `fix/dock-shows-dock-version` from main (`7d6422d`), worktree `../dock-tile-revert`.
Follows [Revert to Dock Version](2026-11-05-revert-to-dock.md). Decisions Q1–Q4 agreed with the owner.

## Goal

Outside the editor, a tile always shows what the user last pressed Update / Add to Dock on: Dock
icon, popover, and (when #13 meets this) the menu bar list. Draft edits stay in the main window until
Update or Revert.

## Facts (read from the code)

- **Leak 1, background rebuilds.** Launch migration (`HelperMigrationManager.swift:114`), self-heal
  (`:203`) and Popover Apply (`reapply`, `:231`) all go through `regenerateBatch`, whose
  `runRegenerationBatch(current:)` re-reads each tile at its turn from
  `configManager.configuration(for:)` (`:245`) — the LIVE config, draft included.
  `regenerateHelperBundle(for:)` builds only from its argument (`buildAndSwap(for: config)`).
- **Leak 2, helper launch.** A helper builds a `ConfigurationManager()` at launch
  (`HelperAppDelegate.swift:121`) and every read (`getCurrentConfiguration`, `:509` — popover `:309`,
  Dock menu `:362`, App-mode `:213`, icon prewarm `:146`) comes from the shared config file, so any
  relaunch (login spawn, reboot, quit + click, a rebuild's relaunch) shows the draft's apps/layout.
  The early Ghost/App read is `readShowInAppSwitcherFromDisk` (`:515`), also the shared file.
- **No rename trap.** After the batch, re-seat + expectations use `helperPath(for: live)`, which
  resolves by bundle id first (`HelperBundleManager.swift:323`), so a draft rename never points the
  Dock at a missing folder. Building from the copy keeps the copy's folder name.
- `installHelper` (Add to Dock / Update) builds from the editor's config — the explicit publish,
  unchanged (one caller, `DockTileDetailView:729`).
- **Mid-batch Update** is refused for a tile the batch is building (`canBeginBundleBuild` + the
  per-tile `TileBuildLock`); an Update that finishes before the tile's turn is picked up, because
  `current:` reads the copy AT that turn.
- **No loop**: migration keys on `helperAppVersion` (stamped on live), self-heal on bundle/icons/
  baked version/Dock entry — never on content. A copy-built `DTDockSignature` keeps Update accent
  while a draft differs (intended).
- **Two live-config writers outside the editor** (gate finding A): `scanForMissingApps` heals an
  item's `lastKnownPath` (`ConfigurationManager:394`), and the missing-app alert's Remove
  (`removeMissingApps`, `:426`) deletes items across tiles.

## Decision Q5 (owner, after the plan gate)

- **Path heal = bookkeeping.** `revertingContent(to:)` keeps each item's LIVE `lastKnownPath`
  (matched by `AppItem.id`). A healed path reaches the Dock at once, never makes an untouched tile
  look edited (no spurious Revert), and Revert never undoes it.
- **Alert Remove = an edit**, like removing in the editor: Update goes accent, the Dock keeps the
  "Not installed" placeholder until Update, Revert can bring the apps back. No silent rebuild.

## The change

1. **One pure seam** in `ConfigurationModels.swift`, beside `revertingContent(to:)`:
   ```swift
   /// What the Dock shows for a tile: content from the helper's sealed copy, bookkeeping from the
   /// live config. nil live → nil (a deleted tile is never rebuilt or shown); no copy → live.
   static func dockVersion(live: DockTileConfiguration?, snapshot: DockTileConfiguration?) -> DockTileConfiguration?
   ```
   `guard let live else { nil }; guard let snapshot else { live }; return live.revertingContent(to: snapshot)`
   (another tile's copy → live, via `revertingContent`'s id guard).
2. **Rebuilds** — `regenerateBatch`'s `current:` becomes
   `dockVersion(live: configManager.configuration(for: id), snapshot: helperManager.builtState(for: live).snapshot)`.
   Log non-verbose `migration` once per tile when the copy is missing ("built from the live config —
   no Dock copy yet"). Stamping, re-seat and relaunch keep reading the live config (bookkeeping).
1b. **`revertingContent(to:)`** keeps live `lastKnownPath` per item id (Q5); covers Revert, rebuilds
   and helpers at once.
3. **Helpers** — read `HelperBundleManager.readDockSnapshot(inBundle: Bundle.main.bundleURL)` ONCE in
   `applicationWillFinishLaunching` (BEFORE the Ghost/App decision at `:104`) into a stored property; `getCurrentConfiguration()` returns
   `dockVersion(live: configManager.configuration(forBundleId:), snapshot:)`; the early Ghost/App read
   uses the copy's `showInAppSwitcher` when present, else the disk lookup. Log once at launch when no
   copy ("popover follows the live config").
4. **#13 (`feature/menu-bar-13`)** — not on main yet. Whichever branch merges second routes
   `TileMenu`'s INPUT (Dock Tile's Dock menu AND the menu bar list) through `dockVersion` (snapshot via
   `builtState`; never-added drafts → live). Cost: `builtState` scans the support folder per tile, so
   read once per menu open and measure. #13 also rewrites `HelperAppDelegate`'s Dock menu (`:362`) —
   expect a merge conflict with step 3. If this lands first: tell the owner / the #13 session.
5. **Rules + old wording** (grep the words, coding-guardrails): architecture.md "A helper reads its
   config once at launch" (:232) and the Revert paragraph's limit (:249–251) → the one-time
   first-migration limit; `runRegenerationBatch` doc comment (`HelperMigrationManager:322–324`,
   "an edited one rebuilt from the copy taken when the batch began"); `HelperMigrationTriageTests.
   editedMidBatchUsesCurrent` comment (the seam still takes `current:` — the test stays, only words);
   testing.md "an edited one built from its current config"; `dockSignature` doc comment
   (`ConfigurationModels:71`). testing.md: add `dockVersion`.

## Tests

- `DockVersionTests` (new, `DockTileTests/Unit/Models/`):
  - deleted tile: `dockVersion(live: nil, snapshot: copy) == nil`;
  - no copy: returns `live` exactly;
  - with copy: `appItems`/`name`/`iconValue`/`layoutMode` from the copy, `lastDockIndex`/
    `isVisibleInDock`/`helperAppVersion`/`bundleIdentifier` from live (fixture values all distinct);
  - another tile's copy: returns `live`.
- Negative control: make the seam `return live` → the with-copy test must fail; restore.
- `revertingContent`: a snapshot item whose live twin has a different `lastKnownPath` comes back with
  the LIVE path; an item only in the snapshot keeps its own (`DockSnapshotRevertTests`, extended — its
  "every content field from the copy" test must then exclude `appItems[].lastKnownPath` explicitly).
- The two call sites are MainActor glue no unit test reaches: reverting `current:` to live would pass
  CI. Accepted; hands-on 1–2 are the guard.

## Done means

- New suite N/N passed, negative control fails as expected, full `DockTileTests` TEST SUCCEEDED,
  l10n untouched (no strings). Signed rebuild, `codesign --verify` on the app.
- Hands-on (dev build, a pinned tile that was Updated on this build so it has a copy):
  1. Remove an app in the editor (don't Update). Popover ▸ Save ▸ Apply. The Dock popover still lists
     the app; Update still accent; Revert still offered.
  2. Same draft; quit the helper (Force Quit or `kill`), click the tile. Popover shows the Dock version.
  3. Update → popover now drops the app.
  4. No-copy fallback: back up a second dev helper, delete its `DTDockSnapshot.json`, relaunch it and
     run Popover Apply → exactly one helper "no Dock copy" line and one `migration` line for that
     tile; restore from the backup afterwards (or just Update it, which writes a fresh copy).
- `stage-gate --dev` (fresh reviewer), CI green on the branch, then fast-forward main.

## Risks / accepted

- First migration after this ships builds from the live config once (no copies yet), then sealed.
- **Hands-on 4 (no-copy fallback) not run** — accepted by the dev gate: only `noCopyFallsBackToLive`
  covers it; the glue is the old code path (`?? readShowInAppSwitcherFromDisk()`, live in `current:`).
  Hands-on 1 used a rename ("DevX") instead of an app removal — the same content path.
- A copy from an older schema decodes tolerantly (missing keys → loader defaults, same as configs).
- Helpers now ignore later edits to the shared config until rebuilt — intended (that IS the goal);
  bookkeeping a helper might need live (none found in `HelperAppDelegate`) still comes from live.
