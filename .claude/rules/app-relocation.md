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
- **The move**: resolves the un-translocated original (`SecTranslocateCreateOriginalPathForURL`),
  moves it into `/Applications`, clears the quarantine xattr (so the copy isn't re-translocated), and
  relaunches. Falls back to revealing the bundle in Finder if the move can't complete (e.g.
  `/Applications` not writable without admin).

## Related: scoped non-fatal keys

`AnalyticsService.record(_:context:keys:)` attaches its context + keys via
`Crashlytics.record(error:userInfo:)`, **not** global `setCustomValue` — otherwise keys bleed across
concurrent non-fatals (and onto the next crash), misattributing debugging context. (The install-flow
`setBreadcrumb` calls are still global on purpose — they record state-at-crash-time.)
