---
name: icon-rendering
description: Use when changing anything in Dock Tile's icon rendering or helper icon pipeline — IconGenerator, IconDepthMetrics, DockTileIconPreview, IconStyleManager, icon baking/variants, glyph sizing or weights, emoji rendering, the declarative .icon/Assets.car pipeline — or when a tile icon looks wrong in the Dock (stale, missing, oversized, wrong appearance). Read BEFORE planning a change here; this is the map that saves re-deriving the system from ~2,100 lines.
---

# Icon Rendering

Two renderers draw every tile icon — the baked artifact (`IconGenerator`) and the live SwiftUI
preview (`DockTileIconPreview`) — and history's recurring bug class is the two drifting apart.
Every magnitude they share lives in one pure seam, `IconDepthMetrics`. Start every change by
asking: which renderer(s), and does the value belong in the seam?

**Pipeline status (2026-09-01):** the declarative rewrite is designed and approved
([spec](../../../docs/superpowers/specs/2026-09-01-declarative-icons-design.md)) but NOT yet
implemented — until it lands, the legacy path below runs on every macOS version.

## End-to-end flow

**Both paths, stages 1–2 (unchanged):** `CustomiseTileView` edits `DockTileConfiguration`
(`tintColor`, `iconType`, `iconValue`, `iconScale`, `iconWeight`) with `DockTileIconPreview`
live; Add to Dock/Update → `HelperBundleManager.installHelper` → translocation pre-flight →
copy main bundle → `stripMainAppIcons` (Assets.car AND template icns MUST go — the catalog
outranks `CFBundleIconFile`).

**Legacy path (today everywhere; post-rewrite: macOS 15 only, frozen):**
`IconGenerator.generateIcns` bakes 4 style variants (`AppIcon-{default,dark,clear,tinted}.icns`,
10 renditions each) → variant matching `IconStyle.current` copied to `AppIcon.icns` → ad-hoc
sign → `touchBundle` + `LSRegisterURL` → Dock plist write (verify-after-write) → Dock restart.
At runtime `IconStyleManager` (sole detector, KVO-primary, NO timers) detects style changes →
`HelperBundleManager.switchIcon`: `replaceIconAtomically` (staged swap; a failure leaves the old
icon intact) → `resealAfterIconSwap` (codesign, NOT `--deep`) BEFORE `touchBundle`. Launch
self-heal byte-compares via `iconMatchesStyle` (unanswerable → match, never force-rewrite) —
and nothing may follow it with an unconditional switch.

**Declarative path (macOS 26, once implemented):** `IconGenerator` lean entry point renders
per-appearance glyph layer PNGs (glyph + shading + contact shadow ONLY — no squircle/stroke/
sheen; the system draws shape and glass) → `IconDocumentBuilder` (pure seam) emits `.icon`
(background = JSON fill gradient + specializations; glyph appearance = LAYER SWAP via
`hidden-specializations`) → `IconCompiler` runs bundled `docktile-actool` → per-tile
`Assets.car`, structurally validated (layered renditions present) before install → sign once,
**never touched again**: no detection, no swap, no reseal — macOS renders all styles itself.
One availability seam (`IconPipeline.isDeclarative`) at exactly three points: bundle
generation, `IconStyleManager` activation (passive `currentStyle` reads stay — popovers key
third-party icon `.id`s on it), migration/self-heal probes.

## The seams (single sources of truth — never inline-copy their values)

| Seam | Owns | Guarded by |
|---|---|---|
| `IconDepthMetrics` | glyph size ratio + safe-area caps (symbol 0.60 / emoji 0.78 / brand 0.78), stroke, sheens, shadows, `emojiInkFit`, `minDetailSize` gate (22px) | `IconDepthMetricsTests` |
| `IconWeight` dual mappings | `fontWeight` (SwiftUI) and `nsFontWeight` (AppKit) MUST agree; emoji/brand ignore weight | `IconWeightTests` |
| `IconStyle.resolve` | style string → style; absent → Default; unrecognised string OR non-string type → nil = don't act, NEVER Default | `IconStyleResolveTests` |
| `IconGenerator.emojiInkMetrics` + `emojiInkFit` | emoji sized by measured artwork, never font em | `EmojiInkFitRenderTests` |
| `iconMatchesStyle` | launch heal decision | `HelperIconMatchTests` |
| `replaceIconAtomically` | the only way to replace a live `AppIcon.icns` | `IconSwapAtomicityTests` |

## Invariants — each shipped a real bug

- `NSBitmapImageRep` with explicit pixel dims, never `NSImage.lockFocus()` (Retina backing store → wrong pixel counts for `iconutil`).
- Emoji sheen: emoji FIRST, gloss via `.sourceIn` + `.drawsAfterEndLocation` — never gloss-first/`.destinationIn` (CoreText colour glyphs ignore blend modes → inverse mask plate). `EmojiSheenMaskTests`.
- No baked outer tile shadow (the Dock adds one). The glyph *contact* shadow IS baked.
- Custom-colour gradient tops via `lighterShade(by:)`, never `opacity()` (CG gradient gaps).
- Never set `NSApp.applicationIconImage` (Dock size mismatch); never spawn `lsregister` (use `LSRegisterURL`).
- Any in-place regenerate MUST re-seat the Dock entry (`refreshDockEntry`) or the Dock draws its cached old render (1.8.2 regression).
- Rewriting any resource in a signed bundle breaks the seal — re-sign immediately, before `touchBundle`.
- Iconset scratch lives in the temp dir with `defer` cleanup, never inside the bundle.
- Never remove an `AppleIconAppearanceTheme` value mapping without positive observation it isn't written ("absent observation is not observation of absence").
- Unknown `IconWeight`/enum raw values: `Codable` on a String enum THROWS — an old binary reading a config with a new case fails the whole decode. Add tolerant decoding when adding cases (currently unguarded — flagged 2026-09-01).

## Appearance authoring model (.icon → Assets.car) — hard-won, do not re-derive

1. Three authorable appearances: `light` (default), `dark`, `tinted`. **`clear` is NOT authorable** — macOS derives it.
2. The default value belongs IN each specializations list (entry with no `appearance` key); a sibling property is not overridable.
3. Per-appearance artwork is a **layer swap** (`hidden-specializations`) — layer `fill` does NOT recolour a glyph. Pre-colour the PNGs.
4. Never trust a compile by eyeball — validate the car's layered renditions (`assetutil --info`; Xcode itself shipped silent-flattening bugs). Canonical working fixture: `docs/icon-spike-fixtures/devtile-fix.icon`.

## Verifying a change

`xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`
plus render-level guards (`IconGeneratorContentTests`, `EmojiInkFitRenderTests`) and, for
anything user-visible, one manual bake per icon type (symbol / emoji / brand) compared against
the preview, across Style × Light/Dark.

## Deeper docs

- [.claude/rules/icon-system.md](../../rules/icon-system.md) — full generation detail, styles, brand glyph, scale/weight
- [.claude/rules/icon-style-detection.md](../../rules/icon-style-detection.md) — legacy detection design (frozen pre-Tahoe fallback)
- [docs/icon-rendering-history.md](../../../docs/icon-rendering-history.md) — how the declarative direction was reached: dead ends (do not reopen), platform evidence, OSS compiler defects
- [docs/dark-mode-icon-rendering.md](../../../docs/dark-mode-icon-rendering.md) — why the Dark treatment looks as it does
