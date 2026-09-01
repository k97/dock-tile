# Declarative Icons — Design

**2026-09-01. Status: IMPLEMENTED** (plan: `docs/superpowers/plans/2026-09-01-declarative-icons.md`,
tasks 1–13, code-complete and reviewed; task 14's documentation pass is this update — its manual
on-Dock appearance matrix and migration rehearsal are the maintainer's own run, not yet performed
as of this writing). Replaced runtime icon-style detection and in-place `.icns` swapping on
macOS 26 (Tahoe) with a per-tile compiled `Assets.car`
that macOS renders itself in every appearance. Feasibility proven in the 2026-09-01 spike; the
evidence, the investigation that led here, and every closed dead end are folded into
[icon-rendering-history.md](../../icon-rendering-history.md). Do not reopen a dead end without
new evidence. The rest of this document is the design as approved; where implementation answered
an open item or diverged, that is recorded in place below rather than rewritten as if it had been
known from the start.

## Decided constraints (inputs to this design, not up for re-litigation)

- Ship a per-tile compiled `Assets.car`; detection, icon swapping, and seal re-signing are deleted
  for Tahoe.
- Compiler: [viraptor/actool](https://github.com/viraptor/actool) (MIT Rust cleanroom). ~1.3 MB on
  the DMG; zero per-helper cost.
- Geometry change accepted: full-bleed 256×256 → Apple's 206×206-with-margin proportions (~80%
  visual size, consistent with other apps). Visible to every existing user.
- macOS 15 keeps the legacy detection path as a fallback behind ONE availability branch, built to
  be **deleted, not untangled**, when the floor rises after macOS 27.
- Release plan: **one release** — 5e2ac2e (event-driven detection) is not shipped interim; it ships
  inside this release as the pre-Tahoe fallback it now is.
- Depth mapping: **lean layers + system glass** (see Authoring below).
- Embedding: **vendored Rust source built in CI to a standalone binary** invoked as a subprocess
  (a statically-linked lib cannot be stripped from helper copies, because helpers copy the main
  executable).

## Architecture

### New units (main-app-only)

- **`IconDocumentBuilder`** — pure seam, regression-guard convention (`nonisolated static`, plain
  values in, values out). Takes tile identity values (tint, icon type/value, scale, weight) plus
  pre-rendered layer PNG data and emits the `.icon` bundle (`icon.json` + `Assets/*.png`) into a
  temp directory. Encodes the authoring rules as code:
  - three authorable appearances: `light` (default), `dark`, `tinted`; `clear` is not authorable
    (macOS derives it);
  - the default value belongs IN each specializations list as the entry with no `appearance` key;
  - per-appearance artwork is a LAYER SWAP via `hidden-specializations`, never a per-layer `fill`
    recolour (layer fill does not recolour a glyph in either compiler);
  - OSS defect-1 workaround: the top-level `fill` is also emitted as the first no-appearance entry
    in `fill-specializations` (harmless for Apple's compiler).
  Unit-tested by asserting JSON shape directly — no compiler, no filesystem beyond the temp dir.
- **`IconCompiler`** — thin wrapper invoking the bundled `docktile-actool` as a subprocess:
  `.icon` directory in → `Assets.car` out. Validates output **structurally** before anything is
  installed: car exists, non-empty, contains the layered renditions (`IconImageStack`/`IconGroup`/
  gradient) — the Xcode-flattening-bug lesson is never trust a compile without checking the
  renditions. Failure throws; install paths surface it loudly (same posture as
  `HelperBundleError.appTranslocated`), never a silent bad icon.

### Pipeline (`generateHelperBundle`, Tahoe path)

After copying the template and `stripMainAppIcons`:

1. Render lean layer PNGs via `IconGenerator`'s new lean entry point (see Authoring).
2. `IconDocumentBuilder` → `.icon` in temp.
3. `IconCompiler` → per-tile `Assets.car`, placed in the helper's `Contents/Resources/`.
4. Generate ONE fallback `.icns` (existing `generateIcns`, light composition, margin geometry).
5. `updateInfoPlist` sets `CFBundleIconName` alongside `CFBundleIconFile`.
6. Ad-hoc sign. The seal is never broken afterwards — nothing about the icon changes at runtime.

Compilation happens only at tile create/edit/update (install/regenerate flows). No cache layer, no
new lifecycle. The compile step is wrapped in `DiagnosticsLog.measure()`.

### Compiler placement & stripping

`docktile-actool` lives at `Contents/Resources/docktile-actool` in the main app, signed and
notarized with the app like any bundled executable. Helper generation deletes it from the copy
exactly as `stripMainAppIcons` deletes the main app's `Assets.car` — per-helper disk cost zero.

### The one availability branch

A single seam — `IconPipeline.isDeclarative` (`#available(macOS 26, *)` in one place) — consulted
at exactly three activation points:

1. **`HelperBundleManager` icon generation**: declarative pipeline vs legacy 4-variant + detection
   layout. Legacy code verbatim, untouched.
2. **`IconStyleManager`**: `startObserving()`, reconciles, and the launch self-heal byte-compare
   become no-ops on Tahoe. The manager stays compiled and `currentStyle` stays *readable*
   everywhere — helper popovers key third-party app icon `.id`s on it, and the popover rebuilds on
   every `show()`, so a passive read suffices on Tahoe. All event machinery (KVO, distributed
   notification, wake reconcile) activates only pre-26.
3. **Migration/self-heal health probes**: `helperIconsComplete` checks `Assets.car` + fallback
   `.icns` on Tahoe; the 4 variants pre-26.

Post-macOS-27 floor rise: delete the `else` branches at those three points, the legacy variant
generation, and the detection machinery. A deletion, not an untangling.

Note (recorded, not re-litigated): on macOS 15 `AppleIconAppearanceTheme` does not exist, so
detection there always resolves Default and never fires — the fallback is today's behaviour
preserved verbatim, which is why quarantining it untouched is cheap.

## Authoring model (lean layers + system glass)

- **Background = JSON, not pixels.** Icon-level `fill` = tint gradient (`colorTop` → `colorBottom`).
  `fill-specializations`: no-appearance default entry first (defect-1 workaround), then `dark` →
  the designed dark background (near-black for symbols/brand; `darkenedForDarkMode(tint)` for
  emoji). The baked squircle path, glass stroke, and surface sheen are **gone from the artwork** —
  the system draws the shape and the glass.
- **Glyph = pre-coloured layer PNGs**, swapped per appearance via `hidden-specializations`:
  - **SF Symbol / brand glyph** — three layers: `light` = white glyph with glyph shading gradient +
    contact shadow (the two glyph-intrinsic effects that survive); `dark` = `liftedForDarkGlyph`
    tint-coloured glyph, same treatment; `tinted` = plain white/mono glyph (the system tints what
    we supply). The brand glyph rides the identical path — it already tints like a symbol.
  - **Emoji** — one full-colour layer shared by `light` and `dark` (emoji cannot be recoloured; the
    dark treatment lives entirely in the background fill spec — today's model, preserved), lighter
    contact shadow baked. `tinted` initially gets the same PNG — **verification item V1** below.
- **Geometry**: layer PNGs rendered at ~1024 px to Apple's icon-grid proportions (206/256 content
  area with margin). `emojiInkFit`,
  `glyphSizeRatio` caps, and `IconWeight` carry over — same ratios, new canvas.
- **No format-native effect groups** (`specular`/`translucency`/`blur-material`): OSS-compiler
  parity is proven pixel-identical only without them, and the system pass supplies the glass.

### `IconGenerator` / `IconDepthMetrics`

No deletion — the legacy path uses all of it verbatim. The Tahoe path calls a new lean render entry
point (glyph + shading + contact shadow; no stroke/sheen/squircle background) reusing the existing
drawing internals. `IconDepthMetrics` remains the single source of magnitudes for what survives.

### Preview fidelity (accepted compromise)

`DockTileIconPreview` cannot reproduce the system's live glass pass — nothing public renders a car
the way the Dock does. The preview shows the light-appearance composition (fill gradient + lean
glyph layer, margin geometry) with the existing subtle sheen kept as a glass approximation. The
preview is a close likeness; the Dock is the truth. The fallback `.icns` uses the same light
composition, so Launch Services contexts and the preview agree.

## Compiler vendoring, defect 2, CI

- **Vendoring**: viraptor/actool source pinned in-repo under `Vendor/actool/`, MIT notice
  preserved (upstream has no LICENSE file — file the upstream issue). `Scripts/build-compiler.sh`
  runs `cargo build --release`, strips, and drops `docktile-actool` into the app's Resources via an
  Xcode build phase.
- **Defect 2 is the first implementation task and the ship gate.** The layer stack picks the wrong
  appearance (glyph renders the dark variant in Default) — characterised, not root-caused; suspect
  `icon_bundle.rs` `collect_stack_layers`/primary-variant assignment not resolving
  `hidden-specializations` (the 14-vs-7 rendition-count anomaly points the same way). Method:
  fixture-driven Rust tests using
  [docs/icon-spike-fixtures/devtile-fix.icon](../../icon-spike-fixtures/README.md), Apple's actool
  output as the dev-time oracle (this Mac has Xcode; users never need it). Fixed means: correct
  glyph per appearance across all four styles, rendition counts matching Apple's. Nothing visual is
  built on top until this passes. PR upstream afterwards.
- **Defect 1** (top-level `fill` dropped) is already root-caused with a no-code-change authoring
  workaround; `IconDocumentBuilder` bakes the workaround, so fixing it upstream is optional.
- **CI**: `ci.yml` + `release.yml` gain a Rust toolchain step with cargo caching (mirrors the
  SwiftPM cache-and-retry pattern). The Rust fixture tests run in CI with the compiler build.
- **DMG cost**: ~1.3 MB (+21%) — accepted.

## Migration & rollout

Rides the existing pipeline unchanged: version bump → `helperAppVersion` mismatch →
`classifyForMigration` → `regenerateBatch` (now emitting declarative bundles on Tahoe) →
`refreshDockEntry` re-seat per tile (already mandatory for the Dock icon cache; doubly so here, the
entry's icon source changes kind) → single Dock restart.

- An old helper launching before migration (login items) is old binary + old bundle: its detection
  works against its own 4 variants, harmless, converges on the next main-app launch.
- Self-heal (`classifyHelperHealth`) probes car presence on Tahoe via the updated
  `helperIconsComplete`.
- The geometry change lands for all tiles in one Dock restart — consistent, not tile-by-tile.
- One release; 5e2ac2e ships inside it as the pre-Tahoe fallback. Its KVO-stall defect becomes
  pre-Tahoe-only and receives no further investment.

## Verification

- **Unit (Swift Testing)**: `IconDocumentBuilder` JSON-shape tests (specialization lists,
  workaround entry, layer references per icon type); Tahoe-shaped cases for
  `classifyForMigration`/`classifyHelperHealth`/`helperIconsComplete`.
- **Rust**: defect-2 fixture tests, run in CI.
- **Integration (local)**: compile the fixture tile; `assetutil --info` asserts the layered
  renditions — the same structural validation `IconCompiler` performs in production, exercised as
  a test.
- **Manual matrix (local, pre-ship)**: a real tile of each icon type (symbol, emoji, brand) across
  Style Default/Dark/Clear/Tinted × Light/Dark, app never launched, seal verified clean throughout.
- **Post-ship (GA4, vs [analytics-baseline-2026-08.md](../../analytics-baseline-2026-08.md))**:
  `icon_style_changed` collapses toward zero on Tahoe for versions ≥ this release. Measured with
  the Sparkle-lag expectation (86/119 on 1.8.5; weeks, not days). The custom dimensions registered
  2026-09-01 make per-style breakdowns readable from day one; forward-only.

### Open verification items (checked during implementation, each with a fallback)

- **V1 — emoji under the system tinted pass. ANSWERED.** Checked via Icon Composer's own
  appearance preview on a docktile-actool-compiled emoji `.icon` (not a Dock pin — production
  helpers were running at the time and pinning would have made them rewrite and re-seal their own
  bundles). Emoji render as a legible monochrome glass relief under the system's Tinted pass,
  because that pass builds relief from the layer's alpha/shape rather than its luminance — even
  the worst case (🟥, flat single-colour art with no internal luminance) comes out a clearly
  visible raised glass square. The single-layer emoji model was kept as designed; the
  grayscale-`tinted`-layer fallback below was **not** needed.
- **V2 — car size discrepancy. NOT INVESTIGATED — left open, not resolved.** Apple 1.69 MB vs OSS
  400 KB for identical input was observed during the spike. The smaller car renders correctly in
  every style that was checked, so it was not a ship blocker, but the discrepancy itself (likely
  extra pre-rendered sizes in Apple's output, per the spike's guess) was never root-caused during
  implementation — this was explicitly out of scope for the docs-only task that closed out the
  branch. Anyone later trying to explain a rendering or size difference against Apple's own
  compiler should treat this as an open question, not something already answered.

## Absorbed defect: Dock tile size flap (reported 2026-09-01)

Pre-spike prod builds sometimes draw 1–2 tiles visibly larger than neighbouring Dock icons —
random onset, self-heals sometimes, always healed by Update (which re-seats the Dock entry).
Evidence gathered read-only on the live prod install: every helper's `.icns` rep table is
canonical and identical (correct pixel counts, 72 dpi), so the artwork is constant; 4 of 5 prod
helpers carry broken seals from the 1.8.8 swap-without-reseal path. Localisation: the flap is in
the Dock/IconServices render cache — Tahoe scales legacy full-bleed `.icns` art into its icon grid
on some render generations and draws it raw full-bleed on others; the prod swap path (in-place
file swap + `touchBundle` + re-registration) keeps invalidating exactly those cache paths.

- **Structural fix, not a targeted one**: the declarative path deletes both triggers on Tahoe (no
  runtime swap/re-registration ever; native format at native grid geometry, so no legacy treatment
  to apply-or-skip). The flap is Tahoe-specific, so the macOS 15 legacy path does not carry it.
- **Diagnostics (capture-at-incident)**: the Dock's drawn size is not observable via any API, so
  Copy Diagnostics gains a per-pinned-helper **icon inventory** — live icon byte-match against
  variants (legacy path), rep-table summary, seal state, mtimes, and car rendition summary
  (declarative path). One Copy Diagnostics press while a flap is visible becomes evidence.
- **Verification**: post-ship, any recurrence report goes through the icon inventory; if the class
  survives the rewrite on Tahoe, the cache-generation hypothesis is wrong and it gets a fresh
  systematic-debugging pass with the inventory as the instrument.

## Risks

- **Apple changes the `.car` format or `icon.json` schema silently** (both undocumented). Same
  class of risk as the Dock plist, which the project already carries; the vendored compiler +
  fixtures make a break loud in CI rather than silent in the field.
- **Upstream is one author, 7 stars.** Vendoring pins it; the Swift-port exit (spike §5e option 3)
  remains available if upstream goes stale — the Timac article is the map.
- **Defect 2 turns out deeper than it looks.** It is sequenced first precisely so this is learned
  in week one; the design does not otherwise depend on how it is fixed.

## Sequencing (process, agreed 2026-09-01)

Spec approval → the icon-rendering documentation task
([2026-09-01-icon-rendering-documentation-todo.md](../plans/2026-09-01-icon-rendering-documentation-todo.md):
focused code review → systematic debugging of findings → repo skill in `.claude/skills/`, then fold
the three working docs into one durable doc) → implementation plan (writing-plans) → stage-gate
`--plan` → implementation. The skill guides the rewrite instead of documenting it afterwards.
