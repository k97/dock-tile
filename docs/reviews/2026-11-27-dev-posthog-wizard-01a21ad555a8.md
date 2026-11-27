# --dev review: PR #46 fixes for items 1–3 and 5

Artifact: uncommitted diff on `4b0971e` (branch `posthog/wizard-01a21ad555a8`): `.github/workflows/release.yml`, `DockTile/Managers/AnalyticsService.swift`, `website/app/privacy/privacy-content.tsx`.
Reviewer: independent subagent.

**Correctness of the changed lines**
- **Item 1 (startup crash):** fixed. The trap and its helper are gone, and the merged `guard` returns early when the token or host is missing. Xcode fills an undefined `$(POSTHOG_PROJECT_TOKEN)` in Info.plist with an empty string, so `!projectToken.isEmpty` catches it. Debug builds, helpers and the test host no longer trap.
- **Item 2 (Release sends nothing):** fixed. The shell is valid, and `::error::` plus `exit 1` fails the job. `${{ vars.* }}` also picks up variables set on the `release` environment.
- **Item 3 (two crash reporters):** fixed. `autoCapture = false` is set and the comment explains why.
- **Item 5 (privacy page):** done, but the new text does not match what the SDK sends (finding 1).

**Finding 1**
```
File: DockTile/Managers/AnalyticsService.swift:163-171 (config block) + website/app/privacy/privacy-content.tsx:97-98
Lens: Verification
Guideline: the privacy copy must match what the code sends (request item 5)
Why: PostHogConfig.captureApplicationLifecycleEvents defaults to true, so PostHog also receives Application
     Installed / Updated / Opened / Backgrounded events. They are captured during setup(), before
     applyCollectionState() calls optOut(), so an opted-out user's first launch can send them, in every helper too.
     That breaks "covered by the same toggle".
Suggested action: config.captureApplicationLifecycleEvents = false, plus config.optOut set from shouldCollect before setup.
Verdict: PLAUSIBLE. Read from posthog-ios main, not the version that actually resolves.
```

**Finding 2**
```
File: .github/workflows/release.yml:251-255
Lens: Verification
Why: neither the repo nor the release environment sets POSTHOG_PROJECT_TOKEN or POSTHOG_HOST, so the next tag
     fails at Build Release (after Run Tests and the release approval).
Suggested action: owner sets both repo variables before tagging.
```

**Finding 3**
```
File: website/app/privacy/privacy-content.tsx:167
Lens: Verification
Why: "(US)" is hard-coded, but the region comes from POSTHOG_HOST, which is not set yet.
Suggested action: confirm the host is the US cloud when setting the variable, or change the copy.
```

**Finding 4**
```
File: website/app/privacy/privacy-content.tsx:97
Lens: Verification (accuracy nit)
Why: "The same feature events" overstates it: shouldCaptureWithPostHog sends 18 of 27 events, and
     log_capture_configured fires at every launch.
Suggested action: "Some of the same feature events…"
```

**Finding 5**
```
File: .github/workflows/release.yml:265-266
Lens: Simplicity (nit)
Why: xcodebuild already reads environment variables as build settings, so the overrides repeat env:. Harmless.
Suggested action: none required.
```

| # | Finding | Lens | Blocks push? |
|---|---|---|---|
| 1 | Lifecycle autocapture on; opted-out users can send events before `optOut()` | Verification | Yes |
| 2 | PostHog repo variables not set; next release fails at Build Release | Verification | No (owner action) |
| 3 | "(US)" hard-coded | Verification | No |
| 4 | "The same feature events" overstates | Verification | No (nit) |
| 5 | Values passed twice to xcodebuild | Simplicity | No (nit) |

**Verdict: Trim first.** Fix finding 1, then push and run CI.
