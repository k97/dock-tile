# Icon Style Detection (event-driven, no timer)

How helpers learn the Tahoe icon style changed. Redesigned 2026-08-31; full evidence trail in
[docs/macos-appearance-detection-research.md](../../docs/macos-appearance-detection-research.md).

## Ownership & signals

- **`IconStyleManager` is the sole detector per process** (critical). `HelperAppDelegate` only
  reacts via `.iconStyleDidChange`. The old design had both detecting independently — that is how
  the codebase silently grew two pollers (1s + 2s) nobody intended.
- **No timer.** Primary: `UserDefaults` KVO on `AppleIconAppearanceTheme` + `AppleInterfaceStyle`
  (the only documented cross-process settings signal; verified to fire for NSGlobalDomain
  fall-through keys in a windowless `.accessory` process, ≤10 ms end-to-end on real tiles).
  Secondary: `AppleInterfaceThemeChangedNotification`, `.deliverImmediately` — the ONLY
  distributed name that exists on macOS 26; the two others we once observed are dead. Recovery:
  `reconcile(reason:)` on `NSWorkspace.didWakeNotification` and on popover show — discrete
  events, not polls. **Do not reintroduce a timer without new evidence**; the 1 Hz poll was three
  orders of magnitude faster than the at-most-twice-daily change it watched for, and was never
  first in 13/13 measured transitions.
- **Never-fired self-test**: a change first found by a reconcile when no event was ever received
  logs once per process — event-path death must be loud, not a silent degrade.

## Resolving the value (critical)

- `IconStyle.resolve(...) → IconStyle?`: **absent key → `.defaultStyle`** (documented: Default
  deletes the key); **unrecognised string → `nil` = don't act**. `from(...)` (= `resolve ?? 
  .defaultStyle`) is ONLY for seeding an initial style. Collapsing unknown into Default was the
  amplifier bug: one anomalous read = two style changes + two icon rewrites.
- **The value space is undocumented — "absent observation is not observation of absence"
  (critical).** `ClearLight`/`ClearDark`/`TintedDark` were removed as "guesses" after a capture
  that only clicked the `*Automatic` options, then observed for real the same day; three live user
  selections were silently ignored in between. Never REMOVE a mapping without a positive
  observation that the value is not written. Observed set + mappings live in
  `IconStyleResolveTests` ("Every value macOS 26 was observed to write").

## Applying it (seal integrity)

- **Rewriting `AppIcon.icns` in a signed bundle breaks its seal** — verified (`codesign --verify`:
  "file modified: AppIcon.icns"). `switchIcon` re-seals immediately (`codesign --force --sign -`,
  deliberately NOT `--deep`: only an outer resource changed; nested frameworks keep valid seals)
  BEFORE `touchBundle`, so Launch Services indexes the sealed state. Known gap: a helper killed
  mid-swap keeps a broken seal until next regeneration; Copy Diagnostics lists per-tile seal state.
- **Launch self-heal**: `HelperBundleManager.iconMatchesStyle` (nonisolated seam,
  `HelperIconMatchTests`) byte-compares the live icon to the resolved style's variant at launch —
  covers changes missed while the helper wasn't running AND events missed while it was.
  Unanswerable comparison → treat as match (never force a rewrite on missing data).
- Launch Services re-registration uses public `LSRegisterURL(url, true)` — never spawn
  `lsregister` (Apple DTS: debugging-only, not API; and `-R` walked the bundled frameworks on
  every flip).

## Investigating appearance behaviour (process lesson)

Run an independent control alongside whatever is being judged — a standalone probe logging every
channel with timestamps. Two wrong conclusions in one day ("helpers inflate GA4 users",
"oscillation reproduced") were both overturned by comparing against the probe's record of what the
OS actually emitted at the same millisecond. Dock Tile's own logs show what the app did, never
whether the input was real.
