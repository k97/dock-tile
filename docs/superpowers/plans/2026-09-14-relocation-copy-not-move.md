# App Relocation: Copy, Never Move — Implementation Plan

**Goal:** Make "Move to Applications" actually work for users who launch Dock Tile from the mounted DMG — today it fails for every one of them while leaving a working copy in `/Applications` — and stop the retry path from trashing that copy.

**Architecture:** `AppRelocationManager.moveToApplicationsAndRelaunch()` stops calling `FileManager.moveItem` and only ever copies. What to do before and after the copy (hand off to an installed copy, trash a stale one, remove the source, eject a disk image) is decided by a new pure seam `AppRelocation.installPlan(...)` (regression-guard convention, mirrors `classify`), executed by the manager with thin OS probes (`statfs` read-only flag, `hdiutil info` disk-image match, `NSRunningApplication` bundle URL).

**Tech stack:** Swift 6 strict concurrency, AppKit, Foundation `Process`, `statfs(2)`, `hdiutil`, Swift Testing.

**Spec:** the *Findings* section below plus the design approved in chat on 2026-09-14. Prior art with citations: [docs/app-relocation-prior-art.md](../../app-relocation-prior-art.md). Plan gate (`stage-gate --plan`) ran 2026-09-14; its findings are folded in below and marked *(gate)*.

## Global constraints

- macOS 15.0+, Swift 6 strict concurrency. `AppRelocationManager` is `@MainActor`; the seam is `nonisolated static` on the non-isolated `AppRelocation` enum.
- No new app-target files (they do not auto-join the Xcode target) — everything lands in `DockTile/Managers/AppRelocation.swift`. New tests go in the existing `DockTileTests/Unit/Managers/AppRelocationTests.swift`.
- Tests: Swift Testing, module `Dock_Tile`, exact-value assertions (full `InstallPlan` values, never partial labels), `#require` over guarded `#expect`, never `UserDefaults.standard`.
- Analytics: only the already-registered `reason` custom dimension carries new detail (`relocation_move_succeeded` gains `reason: copied | handoff`). No new event names.
- No string changes: the prompt copy still says "Move"; the user-visible behaviour is unchanged except that it now works.
- Verification (CLAUDE.md): `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`, then rebuild signed before launching the dev app.
- The launch nudge is Release-only (`AppEnvironment.isRelease`, untouched), so no dev-app end-to-end exists. Mechanics are verified against a read-only disk image with a scratch Swift harness. A quarantined Release build launched from a DMG runs against production data paths and is NOT part of this plan unless Karthik asks.

## Findings (spec)

### Evidence (GA4, `reason` dimension, 90 days to 2026-09-14)

| Version | started | failed | succeeded | Failure reasons |
|---|---|---|---|---|
| 2.0.1 | 11 | 11 | 0 | 7× "couldn't be copied to Applications because an item with the same name already exists"; 2× "The file 'Dock Tile.app' couldn't be opened because there is no such file"; 1× "could not resolve original bundle path"; 1× "you don't have permission to access Applications" |
| 1.8.5 | 8 | 7 | 1 | `(not set)` — the `reason` dimension was registered after 1.8.5 |

The move code has not changed since the file landed (2026-07-02, before v1.8.5). 2.0.1 is simply the first release where the failures are legible.

### Root cause (reproduced 2026-09-14 with a read-only UDZO image + Swift script)

1. `FileManager.moveItem` across volumes copies the whole bundle to `/Applications`, then tries to delete the source. On a read-only DMG the delete fails, `moveItem` throws Cocoa **642** ("volume is read only"), and the complete copy stays at the destination. Apple documents cross-volume `moveItem` as copy-then-remove with no rollback.
2. The fallback `copyItem` then finds that copy and throws Cocoa **516** ("already exists") — the exact text GA4 recorded.
3. The app reports failure and reveals Finder. The user is told it failed while a working copy exists. On retry the code trashes that copy first and repeats, so it fails deterministically and fills the Trash.
4. Follow-ons: a user who ejects the DMG after a failed attempt and hits the blocking prompt again gets "no such file" (source gone) — and today's code trashes the good `/Applications` copy *before* discovering that.

### What the field does (see prior-art doc)

LetsMove and Electron's `app.moveToApplicationsFolder()` both `copyItem`, delete the source best-effort, skip the delete entirely on a disk image and instead `hdiutil detach` it after 5 s. If the destination is already running they `open` it and exit; otherwise they trash it. Sparkle refuses to update from a read-only volume (`statfs` + `MNT_RDONLY`).

## Design

### Pure seam — `AppRelocation.installPlan`

```swift
enum InstallPlan: Equatable {
    /// Activate/launch the copy already at the destination and quit — no copy, no trash.
    case handOff
    /// Copy source → destination.
    case copy(trashDestinationFirst: Bool, removeSourceAfter: Bool, detachSourceImage: Bool)
}

nonisolated static func installPlan(
    sourceExists: Bool,
    sourceOnReadOnlyVolume: Bool,
    sourceIsDiskImage: Bool,
    destinationExists: Bool,
    destinationIsRunning: Bool
) -> InstallPlan
```

Rules, in order:
1. `destinationExists && destinationIsRunning` → `.handOff`.
2. `destinationExists && !sourceExists` → `.handOff` (the ejected-DMG retry; never trash the only good copy).
3. Otherwise `.copy(trashDestinationFirst: destinationExists, removeSourceAfter: !sourceOnReadOnlyVolume, detachSourceImage: sourceIsDiskImage)`.

Stated choices *(gate)*:
- **Unresolvable original path** (`resolveOriginalURL() == nil`, 1× in GA4) is fed to the seam as `sourceExists: false`. With an installed copy present that hands off; with none it reports "could not resolve original bundle path" as today. It no longer bypasses the seam.
- **Destination exists, not running, source present → trashed regardless of version.** Opening an old DMG replaces a newer install. Same as LetsMove/Electron; no version compare, on purpose (YAGNI).
- **Removal keyed on read-only, not on disk-image.** A writable (UDRW) image would have its copy removed then be detached; Dock Tile ships UDZO so this never happens. Since removal is `try?`, `removeSourceAfter: false` only spares a doomed syscall — the guard is honest about that; the real fix is that `moveItem` is gone.
- **Writable sources (~/Downloads) give up the atomic same-volume rename** for copy + best-effort remove: one code path, no cross-volume ambiguity. Cost is transient double disk use and, if the remove fails, a leftover duplicate in Downloads while success is still reported (consistent with "a complete copy is success").
- `!sourceExists && !destinationExists` yields `.copy`, which fails with 260 and is reported — nothing to hand off to.

### Runtime (`AppRelocationManager`)

- `moveToApplicationsAndRelaunch()`: `source = resolveOriginalURL()` (may be nil). **Every probe runs on the resolved original `source`, never on `Bundle.main.bundleURL`** *(gate)* — under translocation the running URL is itself a read-only mount that no `hdiutil` entry matches. Compute the five inputs, call the seam, execute:
  - `.handOff` → log `relocation_move_succeeded` `reason: handoff`; `handOff(to: destination)`: a **running** installed copy is `activate()`d and this process terminates — never a second instance *(gate)*; a **not-running** one goes through `relaunch(at:)` with `createsNewApplicationInstance = true` on purpose — Launch Services keys on bundle identifier, so `false` while this DMG instance is alive would merely re-activate *this* process and then we'd quit, leaving nothing running. *(Implemented this way, superseding the gate-time "flag false" wording.)*
  - `.copy` → one `do/catch` around **both** `trashItem(destination)` (throws when `/Applications` isn't user-writable — the 1× permission case) and `copyItem(source → destination)` *(gate)*; a throw → `reportMoveFailure` + `revealInFinder(source)`. On success: `clearQuarantine(destination)`; if `removeSourceAfter` then `try? removeItem(source)`; log `relocation_move_succeeded` `reason: copied`; if `detachSourceImage` spawn `detachLater(mountPoint)`; `relaunch(at: destination)`.
- `detachLater(mountPoint)`: `Process` running `/bin/sh -c 'sleep 5; /usr/bin/hdiutil detach "$0"' <mountPoint>` — the mount point is a **positional argument, never string-interpolated** (DMG mount points contain spaces) *(gate)*. Not waited on; best-effort — if the old process is still alive at 5 s, `detach` fails and the image stays mounted, which is acceptable.
- Probes (thin, untested by design): `isReadOnlyVolume(url)` = `statfs` + `MNT_RDONLY`; `diskImageMountPoint(for url)` = `statfs` (`f_mntfromname` via `withUnsafePointer` + `String(cString:)`, skip `MNT_ROOTFS`) matched against `hdiutil info -plist` `images[].system-entities[].dev-entry`, returning `f_mntonname`; `isRunning(at url)` = `NSRunningApplication.runningApplications(withBundleIdentifier:)` whose `bundleURL?.standardizedFileURL == url.standardizedFileURL`, excluding `ProcessInfo.processInfo.processIdentifier`.
- `moveItem` is deleted from the file. That guarantee is structural; the rule file says why so nobody "optimises" it back (including the same-volume rename).

### Tests (`AppRelocationTests.swift`, new suite "AppRelocation.installPlan")

Full-value expectations *(gate)*. Each names the regression it guards:
- read-only disk-image source, empty destination → `.copy(trashDestinationFirst: false, removeSourceAfter: false, detachSourceImage: true)` — the DMG case: no removal attempt, eject after.
- writable Downloads source, empty destination → `.copy(trashDestinationFirst: false, removeSourceAfter: true, detachSourceImage: false)`.
- destination exists and running → `.handOff` (never trash a running app), regardless of source state.
- destination exists, source missing → `.handOff` (the "no such file" retry no longer trashes the good copy).
- destination exists, not running, source present → `.copy(trashDestinationFirst: true, removeSourceAfter: true, detachSourceImage: false)`.
- source missing, no destination → `.copy(trashDestinationFirst: false, removeSourceAfter: true, detachSourceImage: false)` (fails loudly downstream, by design).

## Tasks

- [x] **Task 1 — seam + tests (TDD).** Add the failing `installPlan` suite → verify: the suite fails to compile/passes red. Add the seam → verify: `xcodebuild test … -only-testing:DockTileTests/AppRelocationInstallPlanTests` passes. *(Done 2026-09-14: red = "type 'AppRelocation' has no member 'installPlan'"; green = 6/6 + the 9 existing.)*
- [x] **Task 2 — runtime.** Rewrite `moveToApplicationsAndRelaunch()` around the plan; add `handOff(to:)`, `detachLater`, the three probes; delete the `moveItem` call. → verify: Debug build succeeds; `grep -n "\.moveItem(" DockTile/Managers/AppRelocation.swift` is empty (doc comments still name it on purpose). *(Done: BUILD SUCCEEDED; no call remains.)*
- [x] **Task 3 — mechanics harness (throwaway, scratchpad).** *(Run by Karthik 2026-09-14 12:00Z. (b) PASS: `statfs` device `/dev/disk7s1` matched `hdiutil info -plist` `images[].system-entities[].dev-entry`, mount point `/Volumes/RelocTest`. (c) PASS: the positional-arg `sh` spawned from a harness that exited immediately ejected the image — `mount | grep RelocTest` empty 7 s later. (a) inconclusive in that run only because the destination's parent directory was missing (Cocoa 4); the copy phase from the read-only image was already proven by the 2026-09-14 `moveItem` reproduction, which landed the complete bundle before failing on the source delete.)* Against a read-only UDZO image: (a) `copyItem` succeeds with no removal; (b) `hdiutil info -plist` key names (`images[].system-entities[].dev-entry`, `mount-point`) match the `statfs` device on this Mac *(gate: unverified until run)*; (c) a harness that spawns the positional-arg `sh` and **exits immediately** leaves the volume unmounted ~6 s later *(gate)*. → verify: the harness prints each check's result.
- [x] **Task 4 — docs.** *(Done.)* Update `.claude/rules/app-relocation.md` "The move" paragraph → copy-not-move, the seam, why `moveItem` (including the same-volume rename) is banned. Link the prior-art doc. → verify: read the diff.
- [ ] **Task 5 — verify + gate.** Full unit-test run (CLAUDE.md command), signed rebuild + `codesign --verify`, `stage-gate --dev`. Commit only when Karthik says.
