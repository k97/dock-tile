# App Relocation (move to /Applications)

Detects when the main app is running from a location it **cannot copy itself from** to build helper
tiles, and guides the user to move it to `/Applications`. Motivated by a Crashlytics non-fatal:
`regenerateHelperBundle` → `NSFileReadNoSuchFileError` (Cocoa 260 / POSIX 2) from a user running
`~/Downloads/Dock Tile.app`. A **global app feature**, Release-only.

## Why it breaks

Helper tiles are created by copying the **running** main-app bundle as a template
(`HelperBundleManager.generateHelperBundle` copies `Bundle.main.bundlePath`). When a quarantined app
is launched from `~/Downloads`, macOS Gatekeeper **App Translocation** runs it from a randomized,
read-only shadow mount — copying that bundle then fails deep inside FileManager with an opaque
Cocoa 260. Every helper op (add / update / "apply Popover Appearance to running tiles" / migration)
is exposed. The fix keeps the app OUT of that state.

## Pure decision seam (`AppRelocation`)

Regression-guarded `nonisolated`/plain-value functions (mirrors `resolveDockVisibility`), unit-tested
without Security.framework / FileManager / NSAlert — guarded by `AppRelocationTests`:

- `classify(bundlePath:isTranslocated:applicationsDirectories:)` → `.applications` / `.translocated`
  / `.elsewhere`. Translocation always wins; else a bundle under `/Applications` or `~/Applications`
  is `.applications`; else `.elsewhere` (Downloads, Desktop, a DMG). Prefix match is slash-terminated
  so `/ApplicationsOld` is **not** a false positive.
- `blocksBundleGeneration(_:)` → **only** `.translocated`. This is the case that actually fails the
  self-copy, so it is the hard pre-flight guard.
- `requiresRelocation(_:)` → anything but `.applications` (translocated = broken now, elsewhere =
  about to break) — drives the proactive nudge.

## Runtime manager (`AppRelocationManager`)

`@MainActor` singleton wrapping the OS bits. The `SecTranslocate*` C functions are public but **not
surfaced by Swift's `Security` overlay**, so they are resolved at runtime via `dlsym` (RTLD_DEFAULT);
absent symbols degrade to "not translocated".

- **`verifyCanGenerateBundles()` (hard guard, critical)**: called at the top of
  `HelperBundleManager.installHelper` **and** `regenerateHelperBundle`; throws
  `HelperBundleError.appTranslocated` instead of letting the silent copy failure surface as a bare
  non-fatal. A DerivedData dev build is `.elsewhere` (never `.translocated`), so this guard never
  trips in dev.
- **Loud failure paths (critical — no silent non-fatal)**: `HelperMigrationManager.reapply`
  pre-checks `canGenerateBundles` and shows `presentBlockingPrompt()` instead of running the batch
  that would swallow per-tile copy errors; `DockTileDetailView.performDockAction` catches
  `.appTranslocated` and does the same. The blocking prompt is **not** suppressible — a broken
  location must keep asking until the app is moved.
- **Launch nudge is Release-only (critical)**: `checkOnLaunch()` (from `AppDelegate.configureAsMainApp`,
  deferred so a window exists) early-returns unless `AppEnvironment.isRelease`. **Dev builds run from
  DerivedData by design** — nudging them to `/Applications` would break the dev/release data
  separation. Also main-app only (`AppEnvironment.isHelper` guard) and suppressible via
  `UserDefaultsKeys.relocationPromptSuppressed` ("Don't ask again").
- **The move is a COPY, never `FileManager.moveItem` (critical)**: resolves the un-translocated
  original (`SecTranslocateCreateOriginalPathForURL`), **copies** it into `/Applications`, clears
  the quarantine xattr (so the copy isn't re-translocated), removes the source best-effort, ejects
  a source DMG after the relaunch, and relaunches. `moveItem` across volumes is copy-then-delete-
  source: from the read-only release DMG the delete failed (Cocoa 642) *after* the copy had landed,
  the `copyItem` fallback then hit 516 "already exists", the user was told the move failed with a
  working copy in `/Applications`, and every retry trashed it — GA4 for 2.0.1: **11 of 11 attempts
  failed**, since the file's first commit. Do not bring `moveItem` back for the same-volume
  (`~/Downloads`) rename either: one code path, no cross-volume ambiguity; the cost is a transient
  duplicate, which "a complete copy is success" accepts. What happens around the copy is the pure
  seam `AppRelocation.installPlan(sourceExists:sourceOnReadOnlyVolume:sourceIsDiskImage:
  destinationExists:destinationIsRunning:)` (guarded by `AppRelocationTests`): a **running**
  installed copy is handed off to (activated, then this process quits — never a second instance,
  both would write the Dock plist); an installed copy with a **missing source** (the ejected-DMG
  retry) is launched instead of trashed; a stale not-running copy is trashed first, with no version
  compare (same as LetsMove/Electron); source removal is skipped on a read-only volume; a disk
  image (`statfs` device matched against `hdiutil info -plist`, so a read-only USB stick is never
  ejected) is detached by a spawned `sh` after 5 s, the mount point passed as a positional argument
  because DMG mount points contain spaces. Every probe runs on the resolved original, never
  `Bundle.main.bundleURL` (under translocation that is itself a read-only mount). Falls back to
  revealing the bundle in Finder if trash or copy throws (e.g. `/Applications` not writable without
  admin). Prior art with citations: [docs/app-relocation-prior-art.md](../../docs/app-relocation-prior-art.md).

## Related: scoped non-fatal keys

`AnalyticsService.record(_:context:keys:)` attaches its context + keys via
`Crashlytics.record(error:userInfo:)`, **not** global `setCustomValue` — otherwise keys bleed across
concurrent non-fatals (and onto the next crash), misattributing debugging context. (The install-flow
`setBreadcrumb` calls are still global on purpose — they record state-at-crash-time.)
