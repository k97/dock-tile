# Tile Rebuild Swap + Progress Bar (2.6.3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild a tile's helper in a hidden staging folder while the old helper keeps running, swap it in with one atomic rename, and let the running helper show a style-C progress bar on its Dock tile (clicks ignored) while that happens.

**Architecture:** One injected-step sequence (`runStagedRebuild`) replaces the in-place build shared by `installHelper` and `regenerateHelperBundle`: build at `<support>/.staging/<bundleId>.app`, quit the old helper, `renamex_np(RENAME_SWAP)` into place, register, launch. The main app posts stage signals as a distributed notification keyed by the tile's bundle id; the helper's `TileRebuildPresenter` draws the bar into `NSApp.dockTile`, switching a Ghost helper to `.regular` while the bar shows (the spike showed `.accessory` cannot draw). Update no longer removes the Dock entry before building; it re-seats it after the swap, as the batch already does.

**Tech Stack:** Swift 6, AppKit (`NSDockTile`, `DistributedNotificationCenter`), Darwin (`renamex_np`, `open(O_EXLOCK)`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-30-tile-rebuild-progress-design.md` (its spike section is the evidence for the `.regular` switch). Spike source: `docs/superpowers/spikes/2026-10-31-ghost-bar/`.

## Global Constraints

- macOS 15.0 floor, Swift 6 strict concurrency, Apple silicon. No new dependencies.
- Work happens in the worktree `/Users/karthik/Work/Products/Docktile/dock-tile-263`, branch `fix/tile-rebuild-swap`. It needs `./Scripts/build-compiler.sh` once (the actool binary is per clone). Delete its `DockTile-<hash>` DerivedData when the worktree is removed (driving-the-dev-build.md).
- A tile folder in the support directory must never, at any instant, carry the main app's bundle id: only the staging copy does, and only before `updateInfoPlist`.
- Never `LSRegisterURL` a staging path. Register only the final path (`touchBundle`).
- Keep: stamp-on-success, the in-process `buildingBundleIds` lock, `verifyCanGenerateBundles`, re-seat before the one verified Dock restart per batch, write-then-SIGKILL.
- No new user-visible strings (the bar has no text). Errors reuse `HelperBundleError`: cross-process lock held → `.bundleBuildInProgress`; swap failure → `.bundleCopyFailed`.
- Logs: stage lines `verbose: true`; the swap result and every failure non-verbose, tiles named by `config.diagnosticName`.
- No periodic timer in a helper while no bar shows (icon-style-detection.md "no timer", the spin watchdog's history). Timers exist only while the bar animates or shows.
- Swift 6 isolation: parse a notification with the nonisolated `TileRebuildSignal.stage(from:)` inside the observer closure, then hop with `MainActor.assumeIsolated` (main queue); never send a `Notification` across.
- New app-target file needs `project.pbxproj` entries (PBXBuildFile, PBXFileReference, the `UI` group's children, the DockTile Sources phase). Test files auto-join.
- Tests: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO` on the Default icon style; rebuild signed before launching the dev app afterwards.

## Facts this plan rests on (checked 2026-10-31)

- **Nothing depends on Update's early Dock removal**: the watcher's in-flight skip keys on `buildingBundleIds`, held for all of `installHelper`; `lastDockIndex` is written only in `performDockAction` after `installHelper` returns (DockTileDetailView.swift:676); `originalDockIndex` is read before any change.
- **`.staging` is invisible to every support-folder scan**: they list top-level `*.app` only (HelperBundleManager.swift:248, :554; LoginTileSpawner.swift:97).
- **RENAME_SWAP needs APFS.** The support folder lives in `~/Library` on the boot volume, which is APFS on every supported Mac (macOS 10.13+ converts SSD boot volumes; macOS 15 cannot boot from HFS+). No fallback; a failure throws `.bundleCopyFailed` and leaves the old tile (Task 2).
- **Launching the new helper before the Dock restart is safe**: a SIGKILLed Dock does not kill running apps, and the persistent entry already exists at the same path (Update) or is added before the restart (first install). Today's "launch after restart" only existed because the old flow had quit the helper and removed its entry.
- **The signal is spoofable** by any local process (freezes a tile's clicks for at most 30 s). Accepted; documented in Task 6.
- **The bar draws the helper's `NSApp.applicationIconImage`**, which already carries the icon-grid margin, so it is drawn at full bounds (no second inset). It is likely the Default-style render: under Dark/Clear/Tinted the bar shows the Default icon darkened for a few seconds. Accepted unless the Task 6 hands-on under Dark and Clear looks wrong, which goes to the owner.

## Review Focus

1. **A Dock click in the gap between the old helper exiting and the swap** relaunches the OLD bundle from the tile path. Expected: exactly one helper afterwards, running the NEW code. Pinned by `runStagedRebuild`'s "quit again after the swap, then launch" order test (Task 3) and the Task 6 incident re-run.
2. **The main app dies mid-build.** Expected: the old tile keeps working, the bar clears and Ghost mode returns within 30 s, and the staging leftover is removed on the next launch. Pinned by `RebuildBarState` expiry tests (Task 1), `removeStaleStaging` tests (Task 2) and the Task 6 kill check.
3. **Rename + Update.** Expected: the new bundle lands at the new folder, the old folder is deleted, and a path spelled with or without a trailing slash never deletes the new bundle. Pinned by `oldFolderToRemove` tests (Task 2) and the Task 6 hands-on.
4. **The popover is open, or ⌘Tab activates an App-mode tile, while the bar shows.** Expected: the popover closes at `begin`; nothing opens until the bar ends. Pinned by `ignoresInteraction` tests (Task 1) and the Task 6 hands-on.
5. **A build step throws.** Expected: bar cleared at once, Ghost restored, old helper untouched and answering clicks, staging removed. Pinned by `runStagedRebuild` failure tests (Task 3) and the Task 6 failure experiment.

---

### Task 0: Same `.regular` behaviour on macOS 15 and 26 (CI, throwaway branch) — FIRST

The spike proved the switch only on macOS 27. It runs first so a failure is known before any bar code is built. **Ask the owner before pushing.**

- [ ] **Step 1:** On `spike/rebuild-bar-ci` from `fix/tile-rebuild-swap`, add a dispatch-only job to `ci.yml` (`macos-15` and `macos-26`, every `uses:` pinned to a full commit SHA with the version as a trailing comment, per ci-release.md). It runs `docs/superpowers/spikes/2026-10-31-ghost-bar/build.sh`, pins the app with `dock.swift pin`, and runs `run.sh` once with `mode.txt = accessory` and once with `switch`, then uploads the captures and `spike.log`. Reuse `dock-kill-check`'s CI-only refusal so the scripts never rewrite a local Dock.
- [ ] **Step 2:** `gh workflow run ci.yml --ref spike/rebuild-bar-ci`, download the artifacts. **Pass, per runner** (the spike's own evidence form): the five `accessory` captures are byte-identical (`md5`); in `switch` mode the `1-early`, `2-mid` and `3-late` captures all differ from `0-before`, and `4-after` equals `0-before`; the log has `switch → accessory ok=true policy=1`.
- [ ] **Step 3:** Record the per-runner result in the spec's spike section, commit on `fix/tile-rebuild-swap`, and delete the throwaway branch locally and on origin. **If either runner fails:** stop and tell the owner. Per the spec, 2.6.3 then ships the swap alone: Tasks 1–3 and 6 still land (signals simply have no observer), Task 4 is skipped.

### Task 1: Progress protocol, bar state and the tile view

**Files:**
- Create: `DockTile/UI/TileRebuildBar.swift` (+ `project.pbxproj` entries)
- Test: `DockTileTests/Unit/UI/TileRebuildBarTests.swift`

**Interfaces:**
- Produces:
  - `enum TileRebuildStage: String, Sendable { case begin, copied, iconsBuilt, signed, ready, cancelled }`
  - `enum TileRebuildSignal` with `static let name = Notification.Name("com.docktile.tileRebuild")`, `static let stageKey = "stage"`, `nonisolated static func fraction(for: TileRebuildStage) -> Double?`, `nonisolated static func userInfo(_: TileRebuildStage) -> [String: String]`, `nonisolated static func stage(from: [AnyHashable: Any]?) -> TileRebuildStage?`
  - `struct RebuildBarState: Equatable, Sendable { var target: Double?; var lastSignalAt: CFAbsoluteTime; static let idle; static let timeout: CFAbsoluteTime = 30; var isShowing: Bool; var ignoresInteraction: Bool; func applying(_: TileRebuildStage, now: CFAbsoluteTime) -> RebuildBarState; func isExpired(now: CFAbsoluteTime) -> Bool; nonisolated static func eased(from: Double, to: Double, dt: Double, reduceMotion: Bool) -> Double }`
  - `final class RebuildTileView: NSView { init(icon: NSImage); var progress: Double; nonisolated static func barRect(in bounds: NSRect) -> NSRect; nonisolated static func shapeRect(in bounds: NSRect) -> NSRect }`
  - `@MainActor final class TileRebuildPresenter { init(bundleId: String, hidePopover: @escaping @MainActor () -> Void); func start(); var ignoresInteraction: Bool { get } }`

- [ ] **Step 1: Write the failing tests** (`TileRebuildBarTests`)
  - `fractionsRiseThroughTheStages`: `fraction(for:)` is `0.05, 0.30, 0.65, 0.90, 1.0` for `begin…ready`, `nil` for `cancelled`.
  - `signalRoundTrips`: `stage(from: userInfo(.signed)) == .signed`; `stage(from: nil) == nil`; `stage(from: ["stage": "bogus"]) == nil`.
  - `barNeverMovesBackwards`: `idle.applying(.signed, now: 1).applying(.copied, now: 2)` has `target == 0.90` and `lastSignalAt == 2`.
  - `cancelledClearsTheBar`: `.applying(.cancelled, now:) == .idle` from any showing state; `isShowing == false`, `ignoresInteraction == false`.
  - `showingIgnoresInteraction`: `idle.applying(.begin, now: 0).ignoresInteraction == true`.
  - `expiresAfterThirtySecondsOfSilence`: showing with `lastSignalAt 100` → `isExpired(now: 129.9) == false`, `isExpired(now: 130.1) == true`; `idle.isExpired(now: 1e9) == false`.
  - `easingReachesTheTargetExactly`: starting at `0.05`, repeatedly `eased(…, to: 0.30, dt: 1.0/20, reduceMotion: false)`: every value is `≤ 0.30`, and the value `== 0.30` exactly within 20 steps (fails on an asymptote that never lands, which would keep the animation timer alive). `reduceMotion: true` returns `0.30` in one step.
  - `viewDrawsTheBarToItsProgress`: source icon = 128×128 solid red with a 3 px solid green border at its outer edge; draw `RebuildTileView` at `progress = 0.5` into a 128×128 `NSBitmapImageRep` (`cacheDisplay`). Sample points come from `barRect(in:)` / `shapeRect(in:)`:
    - on the bar's centre line at 30% of its width: near-white (all channels > 0.9); at 80%: not (green < 0.5);
    - the shape's centre: darker than the source (red < 0.7);
    - pixel (1, 64): green (> 0.8) — the icon is drawn at full bounds and only the shape is darkened (fails on a double icon-grid inset, which leaves it transparent).

- [ ] **Step 2: Run them to verify they fail** — `-only-testing:DockTileTests/TileRebuildBarTests` → build failure (types missing).

- [ ] **Step 3: Implement** in `DockTile/UI/TileRebuildBar.swift`:
  - `applying`: `cancelled` → `.idle`; else `target = max(target ?? 0, fraction)`, `lastSignalAt = now`.
  - `eased`: `reduceMotion` → `to`; else `next = from + (to - from) * min(1, dt / 0.12)`; if `abs(to - next) < 0.005` return `to` (the snap that guarantees landing), never past `to`.
  - `RebuildTileView.draw`: the icon at full bounds; `shapeRect` = bounds inset by `IconDepthMetrics.contentInsetRatio` on each side; a `black 0.45` fill over that shape (continuous corners, radius 22.5% of its side); then a track (`black 0.35`) and a white fill, both capsules. `barRect` = the shape inset 14% from its sides, 9% of its height tall, 12% above its bottom (the spike's geometry).
  - `TileRebuildPresenter` (all state on the main actor; see the isolation constraint):
    - `start()` observes `TileRebuildSignal.name` on `DistributedNotificationCenter.default()`, `object: bundleId`, main queue. No timer runs.
    - First stage that makes the state show: `hidePopover()`; remember `NSApp.activationPolicy()` and switch `.accessory` → `.regular`; `NSApp.dockTile.contentView = RebuildTileView(icon: NSApp.applicationIconImage)`.
    - Each signal: update the state; (re)schedule ONE expiry `DispatchWorkItem` at `timeout` (cancel the previous one); start a 20 Hz animation `Timer` if none runs. Each tick: `eased(…, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)`, `view.needsDisplay = true`, `dockTile.display()`; invalidate the timer when displayed == target.
    - Clear (on `cancelled` or expiry): invalidate the timer, cancel the work item, `contentView = nil`, `display()`, restore the remembered policy, log non-verbose `"Rebuild bar cleared (cancelled|timed out)"`. A stage after a clear starts the bar again (a stage slower than 30 s just blinks it; accepted).
    - Log each stage `verbose: true`.

- [ ] **Step 4: Run to verify they pass** — `TEST SUCCEEDED`, 8 tests in the suite.

- [ ] **Step 5: Commit** — `feat(helper): tile rebuild bar state, signal and drawing`.

### Task 2: Staging path, atomic swap, the lock, and which old folder to delete

**Files:**
- Modify: `DockTile/Managers/HelperBundleManager.swift` (new `// MARK: - Staged rebuild (2.6.3)` section beside `regenerateHelperBundle`)
- Test: `DockTileTests/Unit/Managers/HelperSwapTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated static func stagingDirectory(helperDirectory: URL) -> URL` → `helperDirectory/.staging`
  - `nonisolated static func stagingBundleURL(helperDirectory: URL, bundleId: String) -> URL` → `.staging/<bundleId>.app`
  - `nonisolated static func swapIntoPlace(staged: URL, final: URL) throws`
  - `nonisolated static func oldFolderToRemove(existing: URL?, final: URL) -> URL?`
  - `final class TileBuildLock: @unchecked Sendable { nonisolated static func acquire(bundleId: String, stagingDirectory: URL) -> TileBuildLock?; func release() }` (released in `deinit` too)
  - `nonisolated static func removeStaleStaging(stagingDirectory: URL) -> [String]`

- [ ] **Step 1: Write the failing tests** (`HelperSwapTests`, `.serialized`; each test makes its own temp dir resolved with `realpath()` and removes it in `defer`; bundles are plain directories holding a `marker` file).
  - `stagingIsHiddenAndBesideTheTiles`: `stagingBundleURL(helperDirectory: /x, bundleId: "com.docktile.dev.A")` is `/x/.staging/com.docktile.dev.A.app`; its parent's name starts with `.`.
  - `swapIntoPlaceExchangesAnExistingBundle`: `final/marker = "old"`, `staged/marker = "new"` → `final/marker == "new"`, `staged` no longer exists.
  - `swapIntoPlaceIntoEmptyPath`: no `final` → `final/marker == "new"`, `staged` gone.
  - `swapKeepsTheOldBundleWhenStagingIsMissing`: `final/marker = "old"`, no `staged` → throws `HelperBundleError.bundleCopyFailed`; `final/marker == "old"`.
  - `oldFolderIsKeptWhenItIsTheSamePath`: `existing = URL(fileURLWithPath: "/x/A.app/")` (trailing slash, as `contentsOfDirectory` may spell it), `final = /x/A.app` → `nil`; same with the slashes reversed → `nil`; `existing = nil` → `nil`.
  - `oldFolderIsRemovedAfterARename`: `existing = /x/Old.app`, `final = /x/New.app` → `/x/Old.app`.
  - `secondLockForTheSameTileIsRefused`: `acquire(A)` non-nil, a second `acquire(A)` nil, `acquire(B)` non-nil; after the first's `release()`, `acquire(A)` non-nil. (flock locks on separate `open()`s conflict within one process, so this exercises the cross-process rule.)
  - `staleStagingIsRemovedOnlyWhenUnlocked`: staging holds `A.app` and `B.app`; hold B's lock → `removeStaleStaging` returns `["A.app"]`, `A.app` gone, `B.app` present.

- [ ] **Step 2: Run to verify they fail** — `-only-testing:DockTileTests/HelperSwapTests` → build failure.

- [ ] **Step 3: Implement.**
  - `swapIntoPlace`: `staged` must exist, else throw. `final` absent → `rename(2)`. Present → `renamex_np(staged, final, RENAME_SWAP)` (if `RENAME_SWAP` is not visible to Swift, `UInt32(0x00000002)` from `<stdio.h>`, with a comment), then remove the old bundle now at `staged`. Non-zero return: log `errno` non-verbose, throw `.bundleCopyFailed`; `final` is untouched on every failure.
  - `oldFolderToRemove`: compare `standardizedFileURL.path` with any trailing `/` trimmed; equal or `existing == nil` → `nil`.
  - `TileBuildLock.acquire`: create the staging directory; `open("<bundleId>.lock", O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK, 0o644)`; `-1` → `nil`. The fd closes on `release()`/`deinit`; the kernel drops it if the process dies.
  - `removeStaleStaging`: for each `*.app` in the directory, try its tile's lock; remove only when acquired.

- [ ] **Step 4: Run to verify they pass** — 8 tests, `TEST SUCCEEDED`.

- [ ] **Step 5: Commit** — `feat(helper): staged bundle path, atomic swap, per-tile build lock`.

### Task 3: The staged-rebuild sequence and every rebuild path

**Files:**
- Modify: `DockTile/Managers/HelperBundleManager.swift` (`installHelper` 96–240, `regenerateHelperBundle` 2206–2248, `launchHelperIfExists` 2262)
- Modify: `DockTile/Managers/HelperMigrationManager.swift` (`regenerateBatch` 238–298, `runRegenerationBatch` 314–335)
- Modify: `DockTile/App/DockTileApp.swift` (launch maintenance `.task`, before `migrateIfNeeded` at 68)
- Test: `DockTileTests/Unit/Managers/StagedRebuildTests.swift` (new), `DockTileTests/Unit/Managers/HelperMigrationTriageTests.swift` (86–121)

**Interfaces:**
- Consumes: Task 1 `TileRebuildStage`; Task 2 `stagingBundleURL`, `swapIntoPlace`, `oldFolderToRemove`, `TileBuildLock`, `removeStaleStaging`.
- Produces:
  - `struct StagedRebuildSteps` — closures, each `async throws` unless noted: `acquireLock() -> Bool` (sync), `post(TileRebuildStage)` (sync), `copy()`, `buildIcons()`, `sign()`, `quitOld()` (async), `swap()`, `removeOldFolder()`, `removeStaged()` (sync), `register()` (sync), `launchNew()` (sync), `launchExisting()` (sync).
  - `static func runStagedRebuild(_ steps: StagedRebuildSteps) async throws` on `HelperBundleManager`.
  - `private func buildAndSwap(for config: DockTileConfiguration) async throws -> URL` (builds the real steps, calls `runStagedRebuild`, returns the final helper path).
  - `func postRebuild(_ stage: TileRebuildStage, bundleId: String)`; `func removeStaleStaging()` (instance wrapper, logs what it removed).
  - `static func runRegenerationBatch(_ configs: [DockTileConfiguration], regenerate: (DockTileConfiguration) async throws -> Void) async -> BatchOutcome` (the `quit:` parameter is gone).

- [ ] **Step 1: Write the failing tests.**
  - `StagedRebuildTests` with a recording `StagedRebuildSteps` (each closure appends its name, `post` appends `"post:<stage>"`):
    - `happyPathOrder`: the record is exactly `acquireLock, post:begin, copy, post:copied, buildIcons, post:iconsBuilt, sign, post:signed, post:ready, quitOld, swap, removeOldFolder, register, quitOld, launchNew`.
    - `lockHeldRefusesWithoutTouchingAnything`: `acquireLock` returns false → throws `.bundleBuildInProgress`; the record is just `acquireLock`.
    - `buildFailureCancelsAndKeepsTheOldTile` (parameterised over `copy`, `buildIcons`, `sign` throwing): the record ends `…, post:cancelled, removeStaged`; it never contains `quitOld`, `swap` or `launchNew`; the error is rethrown.
    - `swapFailureRelaunchesTheOldTile`: `swap` throws → the record ends `…, quitOld, swap, removeStaged, launchExisting`; no `removeOldFolder`, `register` or `launchNew`; rethrown.
  - `HelperMigrationTriageTests`: drop `quit:` from the three `runRegenerationBatch` calls, delete `var quitOrder` (line 86) and its assertion (99–100). Keep every stamp/regenerated assertion.

- [ ] **Step 2: Run to verify they fail** — `-only-testing:DockTileTests/StagedRebuildTests -only-testing:DockTileTests/HelperMigrationTriageTests` → build failure.

- [ ] **Step 3: Implement `runStagedRebuild`** to exactly the order the tests pin, and `buildAndSwap` with the real steps:
  - `acquireLock` → `TileBuildLock.acquire` (held until `buildAndSwap` returns).
  - `copy` → remove any leftover at the staging URL, then `generateHelperBundle(…, helperPath: staged)`; `buildIcons` → `installTileIcons(at: staged)`; `sign` → `codesignHelper(at: staged)`.
  - `quitOld` → `quitHelperAndWait(bundleId:)`.
  - `final = preferredHelperPath(for:)` and `old = oldFolderToRemove(existing: findExistingHelper(…), final:)` are both computed BEFORE `swap`; `swap` → `swapIntoPlace(staged:final:)`; `removeOldFolder` → remove `old` if non-nil.
  - `register` → `touchBundle(at: final)`; `launchNew` → `launchHelper(at: final)`; `launchExisting` → `launchHelper(at: findExistingHelper(…) ?? final)` if a bundle is there.
  - `post` → `postRebuild`: `DistributedNotificationCenter.default().postNotificationName(TileRebuildSignal.name, object: bundleId, userInfo: TileRebuildSignal.userInfo(stage), deliverImmediately: true)`. A helper that is not running or predates 2.6.3 has no observer (owner: build silently, launch nothing for the bar).
  - Log non-verbose `"Swapped \(config.diagnosticName) into place"` and every failure.

- [ ] **Step 4: Rewire the callers.**
  - `installHelper`: keep the in-process lock, translocation check, breadcrumbs and the `originalDockIndex` read. Delete the early `removeFromDock`, the quit-and-wait block, the rename cleanup, old steps 1–4 and the post-restart launch (step 9); call `buildAndSwap`. Then `wasInDock ? refreshDockEntry(for:) : addToDock(at: final, atIndex: originalDockIndex)`, then the unchanged `restartDockAndVerify` and `dockChangeNotKept` throw. The doc comment says the old bundle stays whole until the swap.
  - `regenerateHelperBundle`: in-process lock + translocation check + `buildAndSwap`; doc comment "Rebuild in staging and swap, WITHOUT Dock operations".
  - `launchHelperIfExists`: skip when `isHelperRunning` (an `openApplication` on a running helper can deliver a reopen, which opens its popover).
  - `regenerateBatch`: pass only `regenerate:`. Re-seat, `batchExpectations`, the single restart and the relaunch loop stay.
  - Launch `.task`: `HelperBundleManager.shared.removeStaleStaging()` first inside the `beginLaunchMaintenance()` branch (already skipped under tests).
  - Grep the old descriptions and fix stale comments: `rg -n "in-place|in place|Remove from Dock FIRST|auto-relaunch" DockTile/Managers DockTile/App`.

- [ ] **Step 5: Run the full suite** (Global Constraints command) → `TEST SUCCEEDED`; report per-suite counts for `StagedRebuildTests`, `HelperMigrationTriageTests`, `HelperSwapTests`, `TileRebuildBarTests`.

- [ ] **Step 6: Commit** — `fix(helper): build tiles in staging and swap atomically (no dead or half-built tile)`.

### Task 4: The helper shows the bar and ignores clicks (skip if Task 0 failed)

**Files:**
- Modify: `DockTile/App/HelperAppDelegate.swift` (`applicationDidFinishLaunching` 113, `applicationDidBecomeActive` 198, `applicationShouldHandleReopen` 237, `applicationDockMenu` 321)

**Interfaces:**
- Consumes: Task 1 `TileRebuildPresenter`.

- [ ] **Step 1: Wire it.** A stored `rebuildPresenter`, created in `applicationDidFinishLaunching` with `bundleId: currentBundleId` and `hidePopover: { [weak self] in self?.hidePopover() }`, then `start()`.
  - `applicationShouldHandleReopen`: right after the `ui` log, if `rebuildPresenter.ignoresInteraction`, log verbose `"Dock click ignored — tile is rebuilding"` and `return true`.
  - `applicationDidBecomeActive`: return early while `ignoresInteraction` (App-mode ⌘Tab).
  - `applicationDockMenu`: return `nil` while `ignoresInteraction` (no Configure… mid-rebuild; the Dock's own items remain).

- [ ] **Step 2: Build and test** — `xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build` → `BUILD SUCCEEDED`, then the full suite.

- [ ] **Step 3: Commit** — `feat(helper): show the rebuild bar on the tile and ignore clicks while it shows`.

### Task 5: Hands-on with the dev build (owner present)

Evidence is the dev log (`[main …]` / `[helper:…]` lines), read before relaunching the main app. Ask the owner before any AX driving or Dock-restarting step.

- [ ] **Step 1: Rebuild signed** (no `CODE_SIGNING_ALLOWED=NO`); `codesign --verify` the dev product; relaunch the dev app.
- [ ] **Step 2: The incident, re-run.** With dev tiles built by this branch running, bump `MARKETING_VERSION` in the worktree's `Base.xcconfig` by a patch (uncommitted), rebuild signed, relaunch. During the migration batch: click a tile, then right-click it.
  - Pass: the right-click menu names the tile (never Dock Tile); a Force Quit there (owner's choice to try) kills only that tile and Dock Tile keeps running; afterwards one helper pid per tile (`pgrep -fl`); `lsregister -dump | grep -B2 -A2 <tile bundle id>` lists only the final path (no `.staging`); `DockTile-Dev/.staging` holds no `*.app`.
  - During it, a polling script (`for f in DockTile-Dev/*.app; do /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$f/Contents/Info.plist"; done` every 0.2 s, in a scratch script) never prints the main app's id `com.docktile.dev.app`.
  - `git checkout DockTile/Config/Base.xcconfig` afterwards.
- [ ] **Step 3: Update and Apply.**
  - Ghost tile **Update**: the bar fills; clicks during it log "Dock click ignored"; afterwards one helper, new code (`nm` on its dylib for `TileRebuildPresenter`), Ghost restored, one Dock restart.
  - App-mode tile **Update** with its popover open: popover closes at the start; ⌘Tab during the bar opens nothing.
  - Rename + **Update**: only the new folder exists; the log has the verified-Dock line; the Dock plist re-read ~10 s after the restart still points at the new folder.
  - **Settings → Popover → Save → Apply** with two tiles: each bar clears at its own swap; clicking the first tile while the second builds opens the NEW helper's popover; one Dock restart at the end.
  - Brand-new tile **Add to Dock**: no bar, pinned at the end, as before.
  - Repeat one Ghost Update under the Dark and Clear icon styles: the owner judges the darkened icon under the bar.
- [ ] **Step 4: Failure and death.**
  - Uncommitted experiment build that throws in `sign`: bar clears at once, Ghost restored, the old helper still opens its popover, no `.staging/*.app`. `git checkout` the experiment away.
  - `kill -9` the dev main app during an Update's bar: the tile clears within 30 s and opens its popover on click; relaunching removes the `.staging` leftover (log line).

### Task 6: Docs, gates, release

- [ ] **Step 1: Docs.** architecture.md: the rebuild is staged + swapped; Update re-seats instead of removing first; the progress protocol (spoofable, 30 s cap); the Ghost `.regular` switch and its side effects. testing.md seam list: `TileRebuildSignal`, `RebuildBarState` (incl. `eased` landing exactly), `RebuildTileView.barRect`/`shapeRect`, `swapIntoPlace`, `oldFolderToRemove`, `TileBuildLock`, `removeStaleStaging`, `runStagedRebuild`.
- [ ] **Step 2:** Commit docs. Then `stage-gate --dev` (fresh reviewer), CI on the branch (`gh workflow run ci.yml --ref fix/tile-rebuild-swap`, macOS 15 leg included), and the ci-release.md steps (`2.6.3`, build number, CLAUDE.md header) only on the owner's go.
