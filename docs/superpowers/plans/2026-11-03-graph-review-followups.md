# Graph-review follow-ups (2026-11-03)

Decisions from the 2026-11-01 grilling session on the graphify knowledge graph, agreed with the owner;
amended 2026-11-04 after the plan gate (verdict "Needs answers", all answered by the owner).
Branch `chore/graph-review-followups`, four commits in this order (each fixes something before the pure
refactor, so the refactor never shares a commit with a behaviour change).

Not doing (decided): splitting `HelperBundleManager` into types, splitting its icon side now,
restructuring `DockTileConfiguration`, any AppKit-import hygiene, round-tripping unreadable tiles.

## Commit 1 — docs: README is the repo's requirements page, FAQ.md goes

1. `git rm FAQ.md`. Stale since 2026-02-02, unreferenced anywhere, and wrong ("macOS 15.0 (Tahoe)",
   line 23). The website FAQ (`website/app/faq/faq-content.tsx`, copy in `website/lib/i18n.ts`) is the
   live one.
2. `README.md` (owner-approved 2026-11-04: factual corrections only, same terse style, no new sections):
   - Requirements: "Apple Silicon or Intel Mac" → Apple silicon only (matches `i18n.ts` "Intel Macs
     aren't supported" and the arm64-only release build); a link to `https://docktile.app/faq`;
   - From Source: add the `./Scripts/build-compiler.sh` prerequisite (Rust toolchain), fix the copy path
     to `Dock Tile.app`;
   - Getting Started: describe today's flow (+ opens Add a Tile / Smart Add, the Customise inspector,
     apps under "In This Tile", Add to Dock);
   - Features: add App Grid, Smart Add, Dock Lock, Start at Login;
   - Troubleshooting: Update rebuilds a tile (not toggling Show Tile).
   Every claim checked against the code or `.claude/rules/` before writing it.
3. `DockTileTests/Unit/App/MacOSFloorGuardTests.swift`, `websiteStatesTheRealFloor`:
   - add `"README.md"` to the arguments;
   - README spells the floor two ways the current regexes miss: `macOS 15.0 (Sequoia) or later` and the
     badge alt text `macOS 15.0+`. Add `/macOS (\d+)\.0 \([A-Za-z ]+\) or later/` and
     `/macOS[ -](\d+)\.0\+/`. Neither matches anything in the four website files (checked by the gate).
   - update the doc comment and test description ("The website states…" → covers README too).
4. Check: `git grep -n "FAQ.md" -- ':!docs/superpowers/plans'` returns nothing.

Verify: suite green; **negative control** — on a throwaway local edit set README's `15.0 (Sequoia)` to
`14.0 (Sonoma)`, run `-only-testing:DockTileTests/MacOSFloorGuardTests`, require exactly one failure
naming README.md and macOS 14, then `git checkout README.md` (after README's real edits are committed).

## Commit 2 — one helper-detection rule

Facts: three copies of "am I a helper?" — `AppEnvironment.isHelper`, `main.swift`'s `isHelperApp()`,
and `AppDelegate`'s private `isHelperApp`. The `AppDelegate` copy compares `Bundle.main.bundleIdentifier`
with `AppEnvironment.mainAppBundleId`, which IS `Bundle.main.bundleIdentifier`, so it is always false;
`AppDelegate` never runs in a helper (`main.swift` installs `HelperAppDelegate`), so its 9
`if isHelperApp` branches are unreachable.

1. `Environment.swift`: extract the rule as `nonisolated static func isHelper(bundleId: String) -> Bool`
   (same body), `isHelper = isHelper(bundleId: mainAppBundleId)`. Rewrite its "Mirrors the detection in
   `main.swift`" comment (that copy goes). Fix `mainAppBundleId`'s doc comment: it is THIS process's
   bundle id (a helper's own id inside a helper). No rename.
2. `main.swift`: delete the private `isHelperApp()`; branch on `AppEnvironment.isHelper`.
3. `AppDelegate.swift`: delete `currentBundleId`, `isHelperApp` and every `if isHelperApp` branch
   (~113–136, 297, 361, 372, 475, 568), keeping the main-app half of each verbatim; update the `print`s at
   ~111 and ~370 that interpolate `isHelperApp`. Then delete what that orphans (grep each callee to zero
   callers first): `configureAsHelper` (~123), `togglePopover` / `showPopover` / `hidePopover` (~389–422),
   the `floatingPanel` property (~14), `launchMainApp` (~485), `findDockTileInDerivedData` (~524 —
   `HelperAppDelegate` keeps its own). Grep afterwards: `isHelperApp` → zero hits in `DockTile/`.
4. New test `DockTileTests/Unit/App/HelperDetectionTests.swift`: `isHelper(bundleId:)` is false for
   `com.docktile.app`, `com.docktile.dev.app`, `com.docktile`; true for `com.docktile.<UUID>` and
   `com.docktile.dev.<UUID>`; false for `com.example.app`.
   Guard check: a bare `hasPrefix("com.docktile.")` rule fails the dev-main case.

## Commit 3 — a bad config never empties the app

Facts: `ConfigurationManager.loadConfigurations()` decodes the whole array; one bad tile →
`configurations = []` → the next `saveConfigurations()` (atomic whole-array write) overwrites every
tile. No backup exists. `LoginTileSpawner.loadVisibleConfigs()` and
`HelperAppDelegate.showInAppSwitcher(inConfigAt:)` decode the same way (read-only); they adopt the seam
too, so one bad tile no longer stops the login spawner launching any tile or sends every helper to
Ghost mode.

1. Pure seam beside the model in `ConfigurationModels.swift`:
   `nonisolated static func decodeTolerantly(_ data: Data, using decoder: JSONDecoder) -> TolerantDecode`
   with `tiles`, `skipped: Int`, `firstError: Error?` and `wholeFileUnreadable: Bool`. Each element is
   decoded on its own (a wrapper element that catches its own error), keeping the first element error.
   ANY top-level failure (not an array, truncated JSON) → no tiles, `wholeFileUnreadable`, that error.
2. `ConfigurationManager.loadConfigurations()`, when `skipped > 0` or `wholeFileUnreadable`, main app
   only (`!AppEnvironment.isHelper`) for everything below:
   - FIRST copy the raw file to `<storage stem>.unreadable-<ISO8601 basic>.json` beside it, unless the
     newest existing `.unreadable-*` copy is byte-identical (skip then). A copy failure is logged, never
     thrown;
   - log non-verbose (`config`: counts, error, copy file name) and
     `AnalyticsService.shared.record(firstError, context: "config_decode", keys: ["skipped": …, "whole": …])`;
   - `configurations = tiles` in every process (empty when the whole file is unreadable).
3. `LoginTileSpawner` and `HelperAppDelegate` use the seam (tiles only); no copy, no log, no non-fatal.
4. ~~`symbolEmoji` → `decodeIfPresent`~~ — DROPPED 2026-11-04 (owner): the existing contract guard
   `missingRequiredFieldThrows` keeps every v1 key required on purpose (a tile missing `symbolEmoji` and
   `iconValue` would load as an SF Symbol named "⭐" and draw nothing). With per-tile decoding such a
   tile now costs only itself; the test case below pins that instead.
5. Tests `DockTileTests/Unit/Models/ConfigDecodeToleranceTests.swift` (seam only, no file system, no
   `UserDefaults.standard`). Fixtures must REALLY fail: `LayoutMode`, `TileBackground`, `IconFace` and
   `AppsGridBackground` decode unknown values tolerantly; `IconType` and required v1 keys do not.
   - 3 good tiles → 3 tiles, 0 skipped, `firstError` nil;
   - good, bad (no `id` key), good → the two good tiles in order, skipped 1, `firstError` non-nil;
   - good, unknown enum (`"iconType": "widget"`), good → 2 tiles, skipped 1;
   - a tile with no `symbolEmoji` key → that tile skipped, the other loads;
   - `{"not": "an array"}` and truncated JSON → `wholeFileUnreadable`, 0 tiles.
   Guard check: revert the seam body to `decoder.decode([DockTileConfiguration].self …)` locally once —
   cases 2 and 3 must fail (0 tiles instead of 2) — then restore.

Hand verification (dev build only, never the release config): quit the dev app, back up
`~/Library/Preferences/com.docktile.dev.configs.json`, change one tile's `iconType` to `"widget"`, launch
the signed dev build: the other tiles appear; one `.unreadable-…json` exists and equals the edited file
byte-for-byte; the dev log has the `config` line. Relaunch once: no second copy. **Quit the dev app**,
restore the backup, delete the copy.

## Commit 4 — HelperBundleManager+Dock.swift (pure move)

1. New `DockTile/Managers/HelperBundleManager+Dock.swift` (+ `project.pbxproj`: file ref, build file,
   Managers group, Sources phase) holding `extension HelperBundleManager { … }` with the members of
   `// MARK: - Dock Plist Operations (CFPreferences API)` and `// MARK: - Dock entry identity (2.6.2)`
   (currently lines 1373–1832), moved verbatim, **except these five, which stay in
   `HelperBundleManager.swift`** (owner, 2026-11-04): `removeFromDockPlist` (private; called from both
   sides), `refreshDockEntry` and `removeFromDock(at:)` (they call the two privates), `restartDock`
   (private, the raw unverified restart — kept out of other files' reach) and `dockRestartArguments`
   (beside `restartDock`). Header comment: those five and the verified restart stay in the main file
   because they touch private members.
2. **No visibility change**: `git diff` shows zero `private` → `internal`/`fileprivate` edits. Nothing
   that moves calls a main-file private (checked by the gate; re-check while moving).
3. Isolation: extension members inherit the class's `@MainActor`; `nonisolated static` seams keep their
   annotation. Record the Debug build's warning count BEFORE the move; after it, the count is equal.
4. `ci-release.md`, at the macOS-floor deletion trigger (the `MacOSFloorGuardTests` paragraph): "When the
   legacy icon path is deleted, move the declarative icon install out of `HelperBundleManager.swift` into
   `+Icons.swift` (deferred 2026-11-03: until then the section mixes frozen legacy code and needs
   `private` widened)."
5. Grep `HelperBundleManager.swift` in `.claude/` and `docs/`; fix any file/line claim the move breaks.

Verify: the moved lines are byte-identical (`git diff --color-moved=zebra` shows them as moved, not
edited); warning count unchanged; suite green.

## Done means

- Every commit: `xcodebuild test … -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO` green, per-suite
  counts reported for new/changed suites; host on the Default icon style.
- Then a signed Debug rebuild (`codesign --verify` passes) and a relaunch of the dev app.
- `stage-gate --dev` on the branch diff before push; push the branch and
  `gh workflow run ci.yml --ref chore/graph-review-followups` (both macOS legs) before merging.
- No release is cut by this plan.

## Risks

- Commit 3 changes load behaviour for every user, but only on a decode FAILURE path, which today wipes
  data; the success path decodes the same elements in the same order. No format change, so a config
  written by this build still loads in older builds.
- Commit 2 deletes code in `AppDelegate`; mitigated by the always-false proof, reading each branch, and a
  hands-on smoke of the signed dev app (launch, Dock-icon reopen, a deep link).
- Commit 4's pbxproj edit is hand-written; a wrong entry fails the build loudly.
