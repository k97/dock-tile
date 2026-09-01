# Icon System

## Two Separate Systems

| | Main App | Helper Tiles — macOS 26+ | Helper Tiles — macOS 15 (legacy fallback) |
|---|---|---|---|
| Source | Icon Composer (`AppIcon.icon/`) | `IconDocumentBuilder` (built `.icon`) → `docktile-actool` | `IconGenerator.swift` |
| Output | `Assets.car` + `AppIcon.icns` (Xcode build) | Per-tile `Assets.car` (compiled) + one fallback `.icns` | 4 style-variant `.icns` |
| Variants | light/dark/tinted PNGs in icon.json | 3 authorable appearances (light/dark/tinted; `clear` derived by the system) via layer swap | 4 baked variants (default/dark/clear/tinted), swapped in place at runtime |

Helper tiles now split by OS version behind one seam, `IconPipeline.isDeclarative`
(`#available(macOS 26, *)`). On Tahoe and later, macOS compiles and renders the tile's own
`.icon` document — nothing about a helper's icon changes after it is signed. On macOS 15 the
legacy 4-variant bake + runtime detection below still runs, frozen and scheduled for deletion
once the floor rises. See
[Icon Style Detection](icon-style-detection.md) for the full pre-Tahoe detection design and
[icon-rendering-history.md](../../docs/icon-rendering-history.md) for how the declarative design
was reached.

## Declarative Pipeline (macOS 26+)

`HelperBundleManager.generateHelperBundle`, on `IconPipeline.isDeclarative`:

1. `IconGenerator.generateGlyphLayerPNG` renders one 1024×1024 transparent-background layer PNG
   per authorable appearance — glyph + shading gradient + contact shadow **only**; no squircle,
   stroke, or sheen, because the system draws the shape and the glass. SF Symbols and the brand
   glyph get three layers (`light` = white, `dark` = the tile's tint lifted via
   `liftedForDarkGlyph`, `tinted` = plain white/mono); emoji get one full-colour layer shared by
   every appearance (emoji cannot be recoloured — V1 below).
2. `IconDocumentBuilder` (pure seam) assembles the `.icon` document: the tile's tint gradient as
   the icon-level JSON `fill` (+ a `dark` background override — near-black for symbol/brand tiles,
   `darkenedForDarkMode(tint)` for emoji), and the glyph layers wired via `hidden-specializations`
   so the right layer shows per appearance (a layer's `fill` never recolours a glyph — the PNGs
   are pre-coloured).
3. `IconCompiler` runs the bundled `docktile-actool` (vendored under `Vendor/actool/`, see its
   `DOCKTILE-README.md`) as a subprocess, then structurally validates the output (`assetutil
   --info` must show all three appearance `IconImageStack` renditions — Aqua, DarkAqua and
   Tintable; "at least one stack" would pass the very appearance-collapse this guards) before
   anything is installed — never trust a compile without checking the renditions; Xcode's own
   `actool` has shipped silent-flattening bugs.
4. `IconGenerator.generateFallbackIcns` bakes one additional `.icns` — the light-appearance
   composition at the same margined geometry — for Launch Services contexts that need a bitmap
   icon and for the customiser preview to match.
5. Both files are copied into the helper's `Contents/Resources/`; `docktile-actool` itself is
   stripped from every helper (unconditionally, on every macOS version — a helper never compiles)
   alongside the main app's `Assets.car`.
6. Ad-hoc sign. **The seal is never broken again** — no detection, no in-place swap, no re-sign;
   macOS's own Liquid Glass pipeline renders every appearance from the compiled catalog.

**V1 (emoji under the system Tinted pass) — answered**: emoji render as a legible monochrome
glass relief under the system's Tinted treatment, because that pass builds relief from the
layer's alpha/shape rather than its luminance — even a flat single-colour emoji (🟥) comes out a
clearly visible raised glass square. The single-layer emoji model was kept; the grayscale
`tinted`-only layer contingency was not needed.

**Geometry change**: the compiled `.icon` renders at Apple's icon-grid proportions — the icon
shape occupies 206 of a 256-unit canvas (content = `1 − 2 × contentInsetRatio` ≈ 0.805 of
canvas), leaving a transparent margin, versus the legacy path's full-bleed square. This is a
visible size change for every existing user (~80% of the old visual size) and lands for every
tile in one Dock restart on the next migration. `IconDepthMetrics.contentInsetRatio` is the one
number both the fallback `.icns` and the live preview read — see the seam table in
[the icon-rendering skill](../skills/icon-rendering/SKILL.md).

**Migration/self-heal**: `helperIconsComplete` checks for `Assets.car` + the fallback `.icns` on
Tahoe (the 4-variant check stays for macOS 15); a legacy-shaped bundle evaluated under
`declarative: true` reads as incomplete, which is what makes an old helper regenerate to
car-shape on its first post-upgrade launch. `refreshDockEntry` re-seats the Dock entry after
every regenerate, as it already had to for the Dock's icon cache — doubly necessary here since
the entry's icon *source* changes kind (`.icns` → `Assets.car`).

**Not investigated (V2)**: a compiled car from the vendored `docktile-actool` was observed at
~400 KB versus ~1.69 MB from Apple's own `actool` for the same input. The smaller car renders
correctly in every style — not a blocker — but the size discrepancy itself (likely extra
pre-rendered sizes in Apple's output) was never root-caused. Anyone revisiting car size or trying
to explain a rendering difference should treat this as open, not resolved.

## Icon Generation — Legacy Path (`IconGenerator.swift`, macOS 15 fallback)

Frozen: this describes the pre-Tahoe 4-variant bake, unchanged by the declarative rewrite except
where noted. Most of it is shared drawing machinery the declarative path's lean layer renderer
also calls into.

**Shape**: Continuous corners (squircle) via `RoundedRectangle(.continuous)`, radius = 22.5% of width. **Full-bleed** — the legacy bake does not apply the icon-grid margin (`contentInsetRatio`); only the Tahoe fallback `.icns` and the live preview do (both, on every macOS version — see the seam table).

**Background**: Linear gradient from `TintColor.colorTop` to `colorBottom`.

**Glass effect**: White inner stroke, line width scales proportionally (0.5pt at 160pt). Opacity + width now come from the shared `IconDepthMetrics` seam (see below), not inline constants. Legacy-only — the declarative lean layers carry no stroke or sheen at all.

**Content**: SF Symbols (white, `.semibold`) or emojis. Size controlled by `iconScale` (10–19 symbols / 10–22 emoji, default 14). Emoji are **ink-normalised** — see Icon Scale Safe Area below.

**Output**: All 10 sizes (16, 32, 128, 256, 512 @ 1x and 2x) via `iconutil`.

**Critical gotcha**: Use `NSBitmapImageRep` with explicit pixel dimensions — not `NSImage(size:).lockFocus()` which creates Retina-scaled backing stores that produce wrong pixel counts for `iconutil`. Applies equally to the declarative lean-layer renderer and the fallback `.icns`.

**No baked-in *tile* shadow** — the Dock adds the outer drop shadow dynamically; baking that would double it. This is distinct from the **inner glyph depth** below, which IS baked (an inner contact shadow + sheen the Dock does not provide). The declarative lean layers keep the contact shadow and shading gradient but drop the sheen (the system's own glass pass supplies it).

## Liquid Glass Depth (`IconDepthMetrics`)

This section describes the emulated depth pass the **legacy bake and the live preview** use.
On Tahoe, a compiled `.icon` gets its specular highlights from the system's own layered pipeline
instead — the declarative lean layers keep only two of the four effects below (glyph contact
shadow + glyph shading) and drop the surface sheen and glyph specular sheen, because the system
supplies the glass. Historically, Tahoe's real Liquid Glass icons get specular highlights + depth
from the system's layered `.icon` pipeline (Icon Composer); before this rewrite DockTile's tiles
were generated at runtime with no access to it, so the legacy path **emulates** the treatment by
baking a restrained depth pass. All the magnitudes live in one pure, value-in/value-out seam,
[IconDepthMetrics.swift](../../DockTile/Utilities/IconDepthMetrics.swift), consumed by BOTH the baked
renderer (`IconGenerator`) and the live preview (`DockTileIconPreview`) so they cannot drift.

- **Four effects, tuned per style** (Default/Dark full; grayscale Clear/Tinted dialled back so the
  emulated gloss doesn't fight the system's own tinting):
  1. **Surface sheen** — a soft top→transparent white gloss clipped to the squircle
     (`drawSurfaceSheen` / a `LinearGradient` overlay).
  2. **Glyph contact shadow** — a soft black shadow beneath the glyph (baked via
     `CGContext.setShadow`, derived from the composited glyph's alpha; SwiftUI `.shadow` in the
     preview). Emoji get a lighter shadow but — unlike before — in **every** style, not just Dark.
  3. **Glyph shading** — SF Symbols / the brand glyph are filled with a top→bottom gradient
     (foreground → foreground darkened by `glyphBottomDarken`, via `Color/NSColor.darkened(by:)`).
     Emoji are multicolour and never recoloured.
  4. **Glyph specular sheen** (`glyphSheen`) — a white→transparent gloss **clipped to the glyph's
     own shape**, concentrated in the top `heightFraction` (0.53), stacked above the shading fill
     for a Liquid-Glass "lit glass" highlight. Alpha per style for symbols/brand (0.55 Default/Dark,
     0.30 Clear, 0.37 Tinted). **Emoji get it too** — a much gentler `emojiAlpha` (0.18), since the
     sheen is *additive white light, not a recolour*, so it glosses the "sticker" without flattening
     its colour. The top-heavy falloff is what reads as glass rather than a flat glow.
     - Rendering: for **symbols/brand** the baked `.icns` builds the gloss as an `NSImage` masked to
       the glyph alpha (`sheenGlyph`, mirroring `gradientFilledGlyph`'s proven orientation) rather
       than clipping the main context (which would flip vertically); the preview overlays a gradient
       `.mask`ed by a second copy of the glyph. For **emoji** (full-colour) the mask can't key off
       luminance, so the baked path (`emojiSheenImage`) draws the emoji FIRST and paints the gloss
       through its alpha with `.sourceIn` (+ `.drawsAfterEndLocation` so the below-gloss emoji
       pixels erase to transparent); the preview masks with `Text(emoji)`. **Never the reverse
       (gloss first, emoji composited over it with `.destinationIn`)** — CoreText colour-glyph
       drawing does not honour the context blend mode, which produced the INVERSE mask: a
       translucent gloss rectangle (the glyph's typographic box minus the emoji) baked behind
       every emoji tile as a visible plate/bevel. Guarded by `EmojiSheenMaskTests` (pixel-level:
       typographic-box corners must stay transparent).
- **Size gate (`minDetailSize`, critical)**: all depth is suppressed below ~22px so the tiny 16px
  `.icns` renditions stay crisp instead of muddy; medium/large baked variants and every in-app
  preview clear the gate.
- **The seam also owns the two things the renderers used to disagree on**: the glyph **size ratio**
  (`glyphSizeRatio`, with the 0.60 SF-Symbol safe-area cap — the preview's inline copy used to omit
  it) and the glass **stroke width** (`strokeLineWidth`, scaled — the preview used a fixed 0.5).
  `IconGenerator.maxSafeRatio` / `.warningThreshold` / `.isAtSafeAreaLimit` now forward to the seam.
  Guarded by `IconDepthMetricsTests`.
- **Same treatment on non-tile squircles**: `SettingsBadgeIcon` (sidebar Settings rows) reads the
  seam with `.defaultStyle`; the symbol/emoji picker cells get the subtle glyph contact shadow.
- **Existing tiles adopt it** on the next helper re-bake (Update-after-edit, or the version-bump
  migration pipeline) — no schema change, fully backward compatible.

## Icon Scale Safe Area

Stepper runs 10–19 for SF Symbols, 10–22 for emoji. Per-type ceilings in
`IconDepthMetrics.maxSafeRatio(for:)`: SF Symbols 0.60 of icon size; emoji 0.67
(`emojiMaxSafeRatio` — stickers aren't bound by the symbol guide circle, so they run their own
slope from `emojiBaseRatio` (0.35) up to the ceiling at `emojiScaleMax` (22), keeping every step
distinct). The safe-area warning fires at 95% of the type's own ceiling (symbols ≥18, emoji at
22 only). Guarded by `IconDepthMetricsTests`.

**The emoji ceiling is bounded by the squircle's inscribed square, not its side (critical)**:
emoji artwork is ink-normalised to a bounding *box* (see below), and a box only fits inside a
squircle if it fits the squircle's largest centred square — about 0.868 of the shape's side. With
the icon-grid margin (`contentInsetRatio`, the shape itself is ~0.805 of the canvas) the real
limit works out to ≈0.699 of the canvas; measured against the actually-rendered shape it is
0.6875. The ceiling shipped at 0.78 before this was corrected — that number was checked against
the shape's *side* as if it were a square, and at scale 22 a full-cell emoji (🟥, 🧊) put tens of
thousands of opaque pixels outside the tile at the 1024 bake. `emojiMaxSafeRatio` is now 0.67,
under the inscribed-square limit with margin, and every stepper step from 10–22 stays visually
distinct (a straight clamp at the old ceiling would have flattened the top steps together, which
is why the whole curve was rescaled rather than capped).

**Emoji ink normalisation (critical)**: the emoji ratio bounds the **measured artwork**, not
the font em. Apple Color Emoji reports identical glyph bounds for every emoji (the bitmap
cell — `.usesDeviceMetrics` can't see the art), while real artwork fills ~65% (🧊) to ~100%
(🟥) of that cell and can sit off-centre (🍕) — em-sized emoji therefore rendered visibly
different sizes at the same Icon Size and full-cell art crowded the safe area.
`IconGenerator.emojiInkMetrics(for:)` rasterises each emoji once (reference size, alpha-scan,
cached per process) and the pure seam `IconDepthMetrics.emojiInkFit` computes the font size
that makes the artwork's larger dimension hit `ratio × tile`, plus an optical-centring offset
(`emojiMinInkFraction` 0.55 clamps pathological sparse glyphs). BOTH renderers route through
it — `IconGenerator.drawEmoji` and `DockTileIconPreview` (preview flips the offset's y for
SwiftUI) — so every emoji fills the same fraction, is optically centred, and stays inside the
safe area at every step by construction. Guarded by `EmojiInkFitRenderTests` (real drawing
path, pixel-scanned) + the `emojiInkFit` cases in `IconDepthMetricsTests`.

## Icon Weight (v7)

Per-tile SF Symbol stroke weight (`DockTileConfiguration.iconWeight`, default `.medium`). `IconWeight`
(in `ConfigurationModels.swift`) is a **curated** set of 6 — light, regular, medium, semibold, bold,
heavy — dropping the extremes that read poorly at tile size. It exposes both `fontWeight` (SwiftUI,
for `DockTileIconPreview` + `SymbolPickerGrid`) and `nsFontWeight` (AppKit, for the baked `.icns` via
`NSImage.SymbolConfiguration(pointSize:weight:)`). **The two mappings must agree** — guarded by
`IconWeightTests` — or a tile looks one way in the customiser and another in the Dock.

- **Emoji**: weight is **ignored** (emoji are colour glyphs); the Customise UI keeps the picker visible
  but the renderers never apply weight to emoji content. The brand logo (a raster) also ignores it.
- **Whole picker grid** redraws at the selected weight, not just the large preview.
- **Existing tiles**: like any icon change, helpers re-bake at the new weight via the migration
  pipeline on the next version bump (`helperAppVersion` mismatch).

## DockTile Brand Logo

The rising-sun logo is offered as the **first** symbol-picker option (its own "DockTile"
category, pinned ahead of the SF Symbol categories in `SFSymbolCatalog`). It is stored like an
SF Symbol — `iconType = .sfSymbol`, `iconValue = SFSymbolCatalog.brandSymbolName` (`"docktile.logo"`,
a sentinel that is **not** a real system symbol) — but rendered from a bundled template image,
not the system symbol set.

- **Asset**: `Resources/DockTileGlyph.png` — a tintable (`isTemplate`) white-on-transparent raster
  of the brand SVG, with the inner sun scaled up so it nearly kisses the outer ring (the source SVG
  has the sun floating small inside the ring). No asset catalog exists, so it's a loose resource with
  manual `project.pbxproj` entries (mirrors `GoogleService-Info.plist`).
- **Render**: `IconGenerator.drawBrandGlyph` (baked `.icns`) and `DockTileIconPreview` (live preview)
  both special-case the sentinel and draw the tinted glyph; the picker cell renders it via
  `Image(nsImage:).renderingMode(.template)`. Tinted to the appearance-aware foreground like any symbol.
- **Sizing**: logo-only — `SFSymbolCatalog.brandRatio(forScale:)` scales with the Icon Scale stepper
  on a brand curve (~0.55 of the tile at the default scale) but caps at `brandMaxSafeRatio` (0.78),
  its **own** ceiling above the 0.60 SF-Symbol cap, so it can fill more than a symbol yet never
  reach the tile edge. SF Symbols and emojis are unchanged.

## Icon Style Manager (pre-macOS-26 legacy path)

**On macOS 26 and later, none of this runs.** The compiled `Assets.car` renders every style
itself; `IconStyleManager.shouldRunDetection(isDeclarative:)` returns `false` there, so no KVO
observer, no distributed-notification listener, no wake/popover reconcile, and no launch
self-heal byte-compare are ever registered, and `HelperBundleManager.switchIcon` has no reachable
caller. `currentStyle` still gets seeded once from `IconStyle.current` at `init` (a Swift
definite-initialization guarantee, not a test — see [Icon Style
Detection](icon-style-detection.md)) so it stays a valid **passive** read for the few main-app
views and helper popovers that key a `.id` off it, but it is never refreshed afterwards on Tahoe:
if the user changes icon style mid-session, those main-app previews read stale until the next
relaunch or unrelated state change (helper popovers rebuild fresh on every `show()`, so they are
unaffected). This is the frozen fallback everything below describes, and it is what still runs,
unchanged, on macOS 15.

macOS Tahoe has an independent "Icon and widget style" setting (separate from Light/Dark appearance), read from `AppleIconAppearanceTheme` in UserDefaults.

| Style | UserDefaults Value | Design |
|-------|-------------------|--------|
| Default | `nil` | Colorful gradient, white symbol |
| Automatic | `"RegularAutomatic"` | **Follows system appearance** — `.dark` in Dark mode, `.defaultStyle` in Light. This is the Tahoe default; `IconStyle.from()` MUST map it or dark icons never apply in Automatic mode |
| Dark | `"RegularDark"` | **Splits by icon type.** SF Symbol → tile's own tint as the *glyph* (lifted on perceived luminance to a `0.55` floor via `liftedForDarkGlyph`, so deep violet stays visible) on a **neutral near-black** background — HIG-native, and calmer than a stark white glyph. Emoji → darkened shade of the tile's own tint (`darkenedForDarkMode`, hue preserved) with the full-colour emoji (can't be recoloured). See [dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) |
| Clear | `"ClearAutomatic"` | Light gray, dark gray symbol (grayscale only) |
| Tinted | `"TintedAutomatic"` | Medium gray, white symbol (grayscale only) |

`IconStyle.resolve()` maps values via `systemAppearanceIsDark` for the Automatic case (reads `AppleInterfaceStyle` through CFPreferences, no `NSApplication` dependency); an unrecognised value resolves to `nil` (don't act), never Default. **Detection is event-driven with no timer** — see [Icon Style Detection](icon-style-detection.md) for the signal hierarchy, the seal re-signing, the launch self-heal, and the observed value set (this table's values are illustrative, not exhaustive: light/dark spellings like `"ClearLight"` are real too).

- Single `IconStyleManager.shared` is the sole detector per process (KVO-primary, no polling) — pre-macOS-26 only, per above.
- All 4 variants generated upfront during `installHelper()` (~200-400ms) — legacy branch only; the declarative branch compiles one car instead (see Declarative Pipeline above).
- Style switching is a file copy + immediate ad-hoc re-seal (the swap breaks the bundle signature otherwise) — legacy only; nothing ever swaps a file in a declarative helper.
- Reference `iconStyleManager.currentStyle` in view body with `let _ =` to trigger re-renders — this actually tracks live changes only pre-macOS-26; on Tahoe the value is seeded once and won't change mid-session, so this pattern is harmless but inert there.
- **Dark variant rationale + HIG sources**: [docs/dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) (darkened-own-tint background + white symbol, and why) — the same colour choices are reused by the declarative path's `dark` background/glyph layers.

## App Icon Loading

`AppIconLoader` resolves **third-party** app icons (the apps a user adds to a tile — never
DockTile's own helper tile faces) through `NSWorkspace.shared.icon(forFile:)` for **all** apps.
That returns the icon IconServices renders for the Dock / Finder / Mission Control, including
macOS Tahoe's system-generated dark / clear / tinted treatment — even for apps that ship only a
single light `.icns` with no `Assets.car` (e.g. VS Code, most Electron apps).

- **Do NOT** branch on `Assets.car` to load the raw `.icns` directly. That older heuristic
  ("avoid unwanted dark tinting") suppressed the *correct* system treatment, leaving non-Assets.car
  apps stuck on their light icon while the Dock showed them dark. `iconFromAppURL` keeps a direct
  `.icns` read only as a defensive fallback when `NSWorkspace` returns an empty image.
- Safe because `AppIconLoader` never loads helper tile faces — those get their own per-appearance
  treatment from the compiled `Assets.car` on macOS 26+, or from `IconGenerator` / `IconStyleManager`
  on macOS 15, so there's no double-treatment either way.
- Popover/list views re-render on icon-style changes via their `.id("\(app.id)-\(style)")`
  composites, so the variant tracks Light↔Dark and theme switches live.

## Helper Bundle Icon Priority

macOS loads: `Assets.car` > `CFBundleIconFile`. A freshly-copied helper **must** have the
**main app's own** `Assets.car` removed (`stripMainAppIcons`) — otherwise it would override any
custom icon regardless of pipeline. On macOS 15 nothing replaces it: `CFBundleIconFile =
"AppIcon"` stays the only icon source. On macOS 26 the declarative pipeline puts a **new,
per-tile** `Assets.car` back afterwards and additionally sets `CFBundleIconName = "AppIcon"`
alongside `CFBundleIconFile` — the car is deliberate there, not a leftover.

## Custom Colour Gradients

Custom colours use `lighterShade(by:)` (increases brightness) for the top gradient — not `opacity()`, which creates semi-transparent colours that leave gaps in CoreGraphics gradient rendering.

## Runtime Icon Updates

Never set `NSApp.applicationIconImage` at runtime — causes size mismatch in Dock. Use file-based approach: copy icon variant → `touchBundle()` → re-register with Launch Services. This whole gotcha is about the legacy style-swap path; a declarative helper on macOS 26 never updates its icon at runtime at all — there is nothing to swap.

## Cache Clearing

```bash
killall iconservicesd && killall Dock
lsregister -f -R /path/to/DockTile.app
```
