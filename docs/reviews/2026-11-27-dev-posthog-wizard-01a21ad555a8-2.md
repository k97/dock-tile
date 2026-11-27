# --dev review: PR #46 fixes for items 4 and 6

Artifact: uncommitted diff on `ffd16c3` (branch `posthog/wizard-01a21ad555a8`): `.gitignore`, `Package.resolved`, `UserDefaultsKeys.swift`, `AnalyticsService.swift`, `AnalyticsServiceTests.swift`.
Reviewer: independent subagent.

**Correctness, checked against posthog-ios 3.98.2**
- **One ID across processes:** yes. PostHog stores its data per bundle ID, so each helper starts empty, and on first use `PostHogStorageManager.getAnonymousId()` calls the hook and saves the shared UUID. `getDistinctId()` falls back to the anonymous ID without `identify`, and the app never calls `identify`, `alias` or `reset`. The device ID derives from the anonymous ID too.
- **Swift 6 isolation:** the `nonisolated` factory is the right call. posthog-ios is `swift-tools-version:5.3`, so the hook is called under `anonLock` on any thread, and a closure formed in the `@MainActor` method could carry a main-actor check at runtime. The closure only captures a `Sendable` UUID.
- **Two processes starting at once:** acknowledged with a `shortcut:` comment. The main app starts first on a new install and after a Sparkle update.
- **Already-stored IDs (note):** a process whose PostHog storage already holds an ID never asks the hook. That only affects test machines, because PR #46 is unreleased.

**Finding 1**
```
File: DockTile/Managers/AnalyticsService.swift:198-201, DockTileTests/Unit/Managers/AnalyticsServiceTests.swift:88-95
Lens: Simplicity / Verification
Guideline: testing.md "A guard must be able to fail"; no seam for one trivial call site
Why: resolveAnonymousId is UUID(uuidString:) behind a seam that exists only for its test, and the test still passes
     if config.getAnonymousId stops being set or the ID is read from the wrong domain.
Suggested action: inline it and drop the test, or write a test against PostHogStorageManager that can fail.
```

**Finding 2**
```
File: whole diff
Lens: Verification
Why: no build or test has run yet (CI is the plan), and Debug builds carry no token, so nothing shows one ID
     across processes in a real build.
Suggested action: require both CI legs green before merging; before release, check a token-bearing build by hand.
```

| # | Finding | Lens | Blocks push? |
|---|---|---|---|
| 1 | `resolveAnonymousId` seam and test pin a trivial parse, not the wiring | Simplicity / Verification | No |
| 2 | Tests not run yet; no token-bearing check of one ID | Verification | No (blocks merge until CI is green) |

**Verdict: Ship.**
