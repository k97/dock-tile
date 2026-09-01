# Icon Rendering — History, Evidence, and Closed Dead Ends

**Folded 2026-09-01** from three working artefacts — `icon-investigation-trail.md`,
`macos-appearance-detection-research.md`, `runtime-icon-packaging-research.md` (all deleted; git
history holds the blow-by-blow). This is the durable record: why the declarative direction was
chosen, what evidence closed each alternative, and the platform facts the frozen pre-Tahoe
fallback rests on. **Operational guidance lives elsewhere**: the
[icon-rendering skill](../.claude/skills/icon-rendering/SKILL.md) (the map),
[.claude/rules/icon-system.md](../.claude/rules/icon-system.md) and
[.claude/rules/icon-style-detection.md](../.claude/rules/icon-style-detection.md) (the rules), and
the [declarative-icons spec](superpowers/specs/2026-09-01-declarative-icons-design.md) (the design).
[analytics-baseline-2026-08.md](analytics-baseline-2026-08.md) stays separate — it is a dated
product measurement, not icon documentation.

## The chain, in brief (2026-08-31 → 2026-09-01)

A GA4 review surfaced `icon_style_changed` firing 1,874 times from 14 users on v1.8.5 (baseline
2–6/user). Investigation found real defects (unknown values collapsing to Default = the amplifier;
the in-place icon swap breaking the bundle seal; two unintended pollers; two dead notification
observers) and rebuilt detection event-driven (5e2ac2e). Then KVO delivery to idle helpers stalled
unexplained — and the question "we ship all four themed icons in every helper; why is this
happening?" reframed the problem from *make detection reliable* to *why does detection exist at
all*. Answer: Dock Tile stores mutable state inside a signed, immutable artifact. A spike proved
the declarative alternative (per-tile compiled `Assets.car`, macOS renders every appearance
itself), unlocked by viraptor/actool — a cleanroom MIT Rust reimplementation of the compiler
everyone said couldn't ship. The detection subsystem is deleted for Tahoe, surviving only as the
quarantined pre-macOS-26 fallback.

## The root constraint (why the old subsystem existed at all)

Every pre-declarative problem was downstream of one property: **mutable state inside a sealed
artifact**. All four appearance variants shipped in every helper; the live icon was selected by
rewriting `AppIcon.icns`. A signed container used as a variable is why the seal broke, why the
Dock/IconServices caches needed explicit invalidation, why Launch Services re-registration existed,
and why appearance had to be *detected* by us rather than by the OS. Apple's model is the inverse —
ship every variant, the system selects, the app never knows — and the compiled `Assets.car` is
exactly that model, made reachable at runtime by a redistributable compiler.

A cross-process "one owner" redesign (main app resolves style, pushes to all tiles) was considered
and REJECTED: each of its four justifications was refuted or absorbed by smaller fixes (helpers
write only their own bundles; re-seal-in-place restores the seal; event-driven detection is the
rate limit; detection got a single owner per process), and its residual benefits were covered by
the launch self-heal.

## Dead ends — closed, with the evidence. Do not reopen without NEW evidence.

| Route | Why it died |
|---|---|
| Stale-CFPreferences-read hypothesis for the oscillation | Documented staleness failure mode is a value that *sticks*, not one that flaps; and the reflexive fix (`CFPreferencesAppSynchronize`) is documented prohibited with `kCFPreferencesAnyApplication` |
| Raw `.icon` document in a bundle at runtime | 4 Info.plist wirings tried; generic placeholder every time — macOS does not consume an uncompiled `.icon` |
| Ship one `.icns`, let Tahoe auto-generate variants | Pinned tile stayed full-colour in a Dark Dock. The HIG's "system generates variants you don't provide" applies to the NEW icon format, not legacy `.icns` apps |
| `NSDockTilePlugIn` | The Dock's plugin host (`dock.extra`) has no `disable-library-validation` and never loads ad-hoc-signed plugins. Fatal regardless of other merits: helpers are generated on user machines and can only ever be ad-hoc |
| "One owner across processes" | See above — justifications refuted/absorbed |
| App Nap as the KVO-stall cause | A/B with `NSAppSleepDisabled`: the nap-disabled helper was the one that stalled |
| Timer-based detection (1 Hz poll) | Across 13 measured transitions, KVO was first or tied every time; the poll never caught a change events missed. Three orders of magnitude faster than the at-most-twice-daily event it watched |

## Platform evidence the frozen pre-Tahoe fallback rests on (verified 2026-08-31, macOS 26.6.2)

- **KVO on `UserDefaults.standard` fires for `AppleIconAppearanceTheme` and `AppleInterfaceStyle`**
  (NSGlobalDomain fall-through keys) in a windowless `.accessory` process — the only channel that
  sees the icon-style key, ≤10 ms end-to-end on real tiles, no activation required (delivery is NOT
  suspended for never-active accessory apps).
- **Only ONE distributed notification exists on macOS 26**: `AppleInterfaceThemeChangedNotification`
  (Light/Dark only). Two observers the codebase once carried do not exist there.
- **Events arrive duplicated** (~100 ms apart) — handlers must be idempotent; work per *resolved
  change*, never per event.
- **Absent key is a legitimate value**: selecting Default deletes `AppleIconAppearanceTheme`.
  Absent → Default; unrecognised → unresolved/no-op. Distinct by design.
- **The value space is undocumented and larger than the Settings UI suggests**: `ClearLight`,
  `ClearDark`, `TintedDark` observed being written for the light/dark Clear/Tinted options.
  They were once removed as "guesses" on an incomplete capture, silently ignoring three live user
  selections. **An absent observation is not an observation of absence** — only a positive
  observation justifies removing a mapping. Observed set: `IconStyleResolveTests`.
- **No spontaneous oscillation was ever observed at the OS level** — every detected change in ~3 h
  of instrumented running corresponded to a deliberate user action. The production oscillation was
  our amplifier (unknown → Default), not the OS flapping.
- **`codesign --verify` is a free diagnostic**: it fails with "file modified: AppIcon.icns" iff the
  tile has swapped its icon since sealing. A helper killed mid-swap keeps a broken seal (the icon
  self-heal fixes the icon, not the seal; the next regeneration heals both).
- **Known accepted defect**: KVO delivery to an *idle* helper can go silent while the OS provably
  still emits (never root-caused; not App Nap). Under the declarative design this is pre-Tahoe-only
  and receives no further investment.

## The spike (2026-09-01) — what was proven

- **A compiled `Assets.car` in an ad-hoc-signed, never-launched bundle renders and live-restyles
  correctly in the Dock** across Default/Dark/Clear/Tinted × Light/Dark. Zero app-side code.
- **[viraptor/actool](https://github.com/viraptor/actool)** (MIT cleanroom Rust, built on Timac's
  car-format research) compiles a `.icon` on any Mac. Rendition structure identical to Apple's;
  pixel-identical output on Dock-Tile-shaped icons (one glyph layer on a tint gradient). Divergence
  (~6%) appears only with `blur-material`/`specular`/`translucency` features Dock Tile doesn't use.
- **Dock Tile's designed appearance treatments survive** — the near-black + tinted-glyph Dark
  variant was reproduced exactly via the authoring model below.
- **Cost**: binary 4.0 MB raw / 3.1 MB stripped / ~1.3 MB compressed (DMG 6.2 → ~7.5 MB). Zero per
  helper (stripped like `Assets.car`). Apple's car was 1.69 MB vs OSS 400 KB for identical input —
  unexplained (likely extra pre-rendered sizes); the smaller car renders correctly everywhere.

## The appearance authoring model (hard-won — do not re-derive)

1. **Three authorable appearances**: `light` (the default), `dark`, `tinted`. **`clear` is NOT
   authorable** — macOS derives it as a glass pass over what you supply.
2. **The default value belongs IN the specializations list** as the entry with no `appearance`
   key. A sibling property (`"hidden": true`) is NOT overridable by a specialization — this cost
   two failed attempts.
3. **Per-appearance artwork is a LAYER SWAP** via `hidden-specializations`. Per-layer `fill` does
   NOT recolour a glyph in either compiler — pre-colour the PNGs.
4. Icon-level `fill` + `fill-specializations` control the background per appearance.

Canonical working fixture: [icon-spike-fixtures/](icon-spike-fixtures/README.md) —
`devtile-fix.icon` (Dev Tile's real config, all three appearances, workaround applied).

## OSS compiler defects (root-caused / characterised 2026-09-01)

- **Defect 1 — top-level `fill` dropped when `fill-specializations` present. ROOT-CAUSED.**
  `fill_specializations_assets()` (`src/icon_bundle.rs`) never reads the top-level `fill`, and
  `resolve_background_fills()` assigns positionally, so every appearance shifts down one slot.
  **Workaround (no code change)**: emit the default fill as the first no-appearance entry inside
  `fill-specializations`, keeping the top-level `fill` for Apple's compiler. Verified correct.
- **Defect 2 — layer stack picks the wrong appearance. CHARACTERISED, NOT ROOT-CAUSED. BLOCKS
  SHIP.** With defect 1 worked around, backgrounds are right but the glyph renders the dark
  variant in Default. Apple's compiler is correct on identical input, so the authoring is right
  and the fault is the OSS tool's — suspected in `collect_stack_layers`/primary-variant
  assignment not resolving `hidden-specializations`. Related signal: OSS emits 14 `Icon Image` +
  2 `PackedImage` renditions vs Apple's 7 + 1. Reproduction is minutes with the fixtures.
  The declarative plan budgets this fix first; PR upstream after.
- Upstream has no LICENSE file despite `license = "MIT"` in Cargo.toml — worth an upstream issue
  when the defect-2 PR goes up.

## Method lessons (they generalise; the mistakes don't)

- **Run an independent control** when investigating appearance behaviour: a standalone probe
  logging every channel with timestamps, alongside whatever is being judged. Two wrong conclusions
  in one day ("helpers inflate GA4 users", "oscillation reproduced") were overturned by the
  probe's record of what the OS actually emitted. The app's own logs show what the app did, never
  whether the input was real.
- **Put an expensive subsystem's existence on trial, not just its bugs.** A full day hardened
  detection before anyone asked whether it should exist; the winning alternative was already in
  our own notes, filed as background.
- **Rationale docs are not decision records.** A doc defending *which* dark treatment to render
  was mistaken for a decision to *have* one; the subsystem entered as a bug fix whose framing
  pre-assumed it. First-time decisions deserve to be put to the maintainer as such.
