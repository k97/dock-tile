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
   glyph author two layers, `light` (white on Colour / the fitted tone on Mono) and `dark` (the
   `TilePalette` Dark glyph); the tinted appearance reuses the light layer and macOS derives the
   tinted/clear relief from its alpha — see "Tile background (Mono) and tone map"; emoji get one full-colour layer shared by
   every appearance (emoji cannot be recoloured — V1 below).
2. `IconDocumentBuilder` (pure seam) assembles the `.icon` document: the tile's tint gradient as
   the icon-level JSON `fill` (+ a `dark` background override — near-black for symbol/brand tiles,
   `TilePalette` Dark emoji fill for emoji), and the glyph layers wired via `hidden-specializations`
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
canvas), leaving a transparent margin, versus the full-bleed square every tile had before. This
is a visible size change for every existing user (~80% of the old visual size) and lands for
every tile in one Dock restart on the next migration. The legacy macOS 15 bake stayed full-bleed
through 2.0.2 — a macOS 15 user reported the tile ~24% larger than every neighbouring icon
(2026-09-30, measured 114 px vs 90 px) — and now insets by the same seam (see "Shape" below).
`IconDepthMetrics.contentInsetRatio` is the one number the legacy bake, the fallback `.icns` and
the live preview read — see the seam table in
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

## Tile background (Mono) and tone map

Each tile stores ONE colour plus a `background` (`TileBackground`: `.colour` default, `.mono`).
Every role (fill top/bottom, glyph) per background x style x icon type is derived by the pure
`TilePalette.resolve` ([TilePalette.swift](../../DockTile/Utilities/TilePalette.swift); `SRGB`,
`ToneMap`, `TilePalette`); `TintColor`/`IconStyleManager` are thin adapters over it, so the baked
`.icns`, the compiled `.icon` fills and the live preview cannot drift.

- **Mono** = `#FFFFFF -> #EFEFF1` (Default) / `#2C2C2E -> #1C1C1E` (Dark) with the tint as the
  glyph. **Colour** = the tint as the fill, white glyph.
- **Mono follows Light/Dark on macOS 26+ only.** On macOS 15 the legacy path always shows the light
  variant (no icon-style setting exists there), so Customise presents Mono as a white tile with a
  coloured symbol (static hint).
- **The promise: every drawn symbol/fill pair >= 3:1** (`ToneMap.floor` 3.0, searched at
  `searchTarget` 3.1 for 8-bit/gamut headroom) via `ToneMap.fit` (OKLCH lightness search,
  hue-preserving). Each fit tests the pairs the renderer actually draws: Colour clears TWO (white
  vs the fill top, and the white glyph's Default-style SHADED bottom — `glyphBottomDarken` 0.12 —
  vs the fill bottom); Dark symbol fits the dark-shaded glyph (0.10) against `#2C2C2E`; Mono Light
  fits the glyph against `#EFEFF1`. `fillWasDeepened` drives the Customise "Deepened" hint.
- **Measured on the chosen colours BEFORE decorative sheens** (decided 2026-10-13): macOS 26 Dock
  icons carry no baked sheen (the system adds its glass); the macOS 15 bake and the in-app preview
  add a glyph/surface sheen that is decoration, not part of the promise.
- **The target is fixed**: a Dock icon is compiled once and cannot react to Increase Contrast (no
  such icon appearance).
- **Previews are canonical**: the Customise chips and the Tile Detail hero (while the inspector is open) always render Default/Dark via
  `DockTileIconPreview.forcing(_:)` (`displayStyle(forced:raw:colorScheme:)`), whatever the system
  icon style is. Dark only where the icon follows the appearance (macOS 26+): on macOS 15 the open
  hero, like the Mono chip, stays Default in Dark Mode.
- **Fills are P3 JSON fills** (`HelperBundleManager.declarativeFillsP3`), not pixels.
- **Layer model (spike, 2026-10-14)**: a Mono symbol `.icon` keeps the SAME two glyph layers as a
  Colour one; the tinted appearance reuses the (coloured) light layer, and macOS 27 derives a legible
  Tinted/Clear relief from it (verified by eye in Finder). No third layer was needed.
- **Verify icon styles by eye in Finder/Dock**: whether `NSWorkspace.icon(forFile:)` follows the
  system icon style is inconsistent — a CLI script did NOT on macOS 27 (issue #22), yet one DID
  (Clear Dark) on 2026-10-19, and a long-running app process can lag a style change. For a specific
  style use `AppIconStyleRenderer` (named style), never a public render. `AppleIconAppearanceTheme`
  IS written on macOS 27 with the documented values (an
  earlier note here said it was absent; issue #22 measured it).
- **Not adopted for glyph tiles**: Apple's `system-light`/`system-dark` fills — their values are
  unpublished, so the 3:1 contrast promise cannot be computed against them. The Apps face DOES use
  them (see the "Apps tile face" section).
- Existing Colour tiles change look on update (saturated gradient start; sub-3:1 colours deepen).

## Apps tile face (`iconFace`, v10)

A tile can show its OWN apps as a folder-style mini grid on system glass (or its own plate, v12) instead of a glyph. Choosing
it is the Style picker in Customise (App Grid / Symbol / Emoji).

- **Model**: `DockTileConfiguration.iconFace` (`IconFace`: `.glyph` / `.apps`), a separate field, not an
  `IconType` case, so the glyph fields (`iconType`, `iconValue`, scale, weight, tint) are retained and
  switching back loses nothing. **Two defaults on purpose**: a stored config missing the key loads as
  `.glyph` (existing tiles must not change on upgrade); `ConfigurationDefaults.iconFace` is `.apps` for
  NEW tiles. Unknown values decode to `.glyph`. `iconSignature` is unchanged for glyph tiles; an Apps
  tile appends the face plus the first nine item identities (`AppsFaceGrid.maxItems`). Guarded by
  `IconFaceTests`.
- **Seam `AppsFaceGrid`** ([IconDepthMetrics.swift](../../DockTile/Utilities/IconDepthMetrics.swift)):
  two grids only: 1-4 items = 2x2 (a single item sits in the top-left cell, the rest empty glass —
  owner, 2026-10-22; it was one centred 0.60 icon, "Fills the Tile"), 5+ = 3x3 (nine max). Block 0.80, gap 0.035 of
  the shape (cells 0.3825 / 0.243; was 0.70 / 0.047 until 2026-10-19, when the 3x3 read small and
  crowded to the centre in the Dock). App icons carry the icon-grid margin, so their draw box is the cell divided by 0.805
  (`appIconContentRatio`); folders are fitted to the cell. Contact shadow 0.35 black, offset 6 and blur
  12 at 1024, gated by `minDetailSize`. Material = the plate (`AppsFaceGrid.fillColors`, below); under
  Follow System the system grays, top then bottom: light 1.0 -> 0.925, dark 0.192 -> 0.078. Clear and
  Tinted desaturate the minis. `TilePalette` is NOT consulted (the face ignores the Symbol/Emoji tint).
- **Plate = per-tile App Grid background (v12, PR #32 by 3ueg)**: `appsBackground` (`AppsGridBackground`:
  Follow System / Dark Grey / Light / Custom; unknown values and missing keys decode to Follow System) +
  `appsBackgroundColor` (sRGB hex, kept while another plate is picked). **Follow System must bake
  byte-for-byte what tiles baked before v12 (critical)**: its `iconSignature` string is unchanged (so no
  helper reads stale), and the empty-slot tone per compiled layer comes from the pure seam
  `AppsFaceGrid.layerOnDarkGlass(slot:background:customHex:)` — the tinted slot is ALWAYS dark glass
  (it holds the Clear Dark renders and the system remaps its fill). The PR first mapped that slot to
  the light grays, which would have flipped every empty Follow System grid under Clear/Tinted on the
  next migration with no Update prompt; `AppsBackgroundTests.layerTones` pins all 3 slots × 4 plates.
  A fixed plate is the same in every slot while the minis still follow the system style (Dark-style
  minis on a Light plate under Dark). `usesDarkPlate` = white contrasts better than black (relative
  luminance ~0.179). The renderers take the plate with NO default parameter, so a new bake path that
  forgets it is a compile error.
- **macOS renders an `.icon` fill lighter than its stops (measured 2026-10-28)**: IconServices draws a
  fill's stop components as if they were Generic RGB (gamma 1.8) — `srgb:` #224466 renders #2B5678,
  the `display-p3:` equivalent the same, and Apple's `actool` output renders identically to the
  vendored compiler's (so it is the system, not our compiler). The Custom plate pre-compensates
  (`IconDocumentBuilder.renderCompensatedStop`, pinned by `compiledCustomPlate`). **Glyph tiles do
  not**: their P3 fills render lighter in the Dock than the in-app preview, and the 3:1 promise is
  computed on the unlightened colours. Open as issue #33; changing it moves every existing tile's Dock look.
- **Four renderers, one seam**: the compiled car (`IconDocumentBuilder.appsFaceIconJSON`, one grid
  layer PER APPEARANCE SLOT from `IconGenerator.generateAppsLayerPNG` on the plate's fill (the
  `system-light` / `system-dark` fills under Follow System, Dark Grey and Light; a flat gradient for Custom) — see "One grid per style" below; the dark appearance is decided as
  `system-dark`, tinted reuses `system-light`; each grid spans
  the WHOLE 1024 canvas — in an `.icon` the canvas is the tile and the system adds the icon-grid
  margin itself, so insetting the layer too shrank every mini by 0.805 in the Dock, found against
  TinyFolder 2026-10-19, pinned by `AppsFaceRenderTests`); the fallback `.icns`
  (`generateAppsFallbackIcns`) and the macOS 15 four-variant bake (`generateAppsIcns`), both on the
  inset squircle with the plate; and the live preview (`DockTileIconPreview.appsFaceBody`, full
  frame, minis from `TileIconRasterCache`). Proven document shape (fixture):
  `docs/icon-spike-fixtures/appgrid-systemfill.icon`.
- **Explicit flat keys (critical)**: the `.icon` writes `specular` off, `translucency` off, `shadow`
  none and layer `glass` false. Apple's `actool` defaults them to specular on, translucency 0.3 and
  shadow 0.5, which wash out real app icons. The vendored compiler parses the keys but does not need
  them; spelling them out makes the document mean the same under both.
- **Selection is installed-only, one predicate**: `AppInstallChecker.isInstalled` feeds the bake, the
  preview AND the Customise Apps card (Shown "N of N"), so the card, the hero and the Dock icon cannot
  disagree. Items in tile order via `AppsFaceGrid.select`; a missing item is skipped and the next
  installed one takes its cell; zero installed -> the **empty 2x2**: four quiet slots in the cells
  (`AppsFaceGrid.emptySlotFill`, black 7% on light glass / white 10% on dark, continuous 22.5% corners,
  no stroke or shadow) in the preview, the cards and every Dock bake — an App Grid never shows the
  tile's symbol (owner, 2026-10-22; it used to bake the glyph face). The card reads "0 of 0" / "-".
  **The Dock look is unverified by eye**: the tinted slot (Clear and Tinted styles) bakes the
  dark-glass tone (white 10%) on a `system-light` fill the system then remaps, so check an empty and
  a one-app App Grid in the Dock under Default, Dark and Clear Dark before claiming it.
  `DockTileIconPreview.appsFaceItems` is optional: nil draws the glyph face, `[]` the empty grid. The bake logs skipped items on the non-verbose `tile` category.
- **Mini icons**: `AppIconLoader.iconFromAppURL` resolves symlinks first (a symlinked app, e.g. Safari
  on macOS 27, otherwise draws the alias badge). The desaturated minis are rasterised at the draw-box
  PIXEL size (rendering at the image's point size picked a low-res rep and blurred them).
- **Staleness**: the face re-bakes only on Update and on the version-bump migration. An app's own icon
  redesign, a Finder-pasted icon, or a later install/uninstall stays stale in the Dock until then — but
  since 2026-11-10 it lights Update: every build stamps `DTAppIconsSignature` (each drawn app's bundle
  modification time, the raster cache's key) and Tile Detail compares it on appear
  (`HelperBundleManager.appIconsSignature`, `AppIconsSignatureTests`). An in-place app update that
  leaves the bundle folder's time alone goes unnoticed by this AND by the preview cache.
- **One grid per style (critical, 2026-10-19)**: the `.icon` carries three grids, Default renders
  (light slot), Dark renders (dark slot) and Clear DARK renders (tinted slot), each app drawn by
  `AppIconStyleRenderer` (in `AppIconLoader.swift`). With ONE colour grid shared by every slot, the
  system's clear filter turned VS Code's white plate into a bright square under Clear Dark while the
  Dock drew VS Code's own dark clear icon; Dark reused the colour minis too. Facts it rests on:
  - Apple's `ictool` (inside Xcode's Icon Composer.app): Clear Light, Clear Dark, Tinted Light and
    Tinted Dark ALL draw from the tinted slot, brightness-remapped. Clear Dark renders there matched
    the apps' own icons best across the four (Clear Light renders were too pale in the dark styles,
    colour renders gave the bright-plate bug). The light styles are approximations: one slot, four styles.
  - `NSWorkspace.icon(forFile:)` returns only the CURRENT system style (`.aqua` and `.darkAqua`
    drawing both gave Clear Dark under Clear Dark), so a bake froze whatever style was active.
  - Private IconServices renders a named style: `ISBundleIcon initWithBundleURL:` +
    `ISImageDescriptor initWithSize:scale:` with `appearance` (0 light, 1 dark) and
    `appearanceVariant` (0 normal, 2 tinted — needs the system tint colour, unexposed — 3 clear),
    then `prepareImageForDescriptor:` (without it an unrendered style comes back as a dashed
    placeholder) and `CGImageForImageDescriptor:`. Same icon-grid margin as the public render;
    backing may be larger than requested; 9 apps × 3 styles render in ~80 ms. Measured on macOS 27
    only — `AppIconStyleRendererTests` fail (never skip) on the macos-26 CI leg if it differs there.
  - Every private call is runtime-resolved and `responds(to:)`-guarded (never `setValue(_:forKey:)` —
    an ObjC exception is uncatchable). Any miss → that mini uses the public icon, logged once per bake
    on `tile`. Folders always use the public icon (IconServices draws them alike in every style).
  - **An app with a Finder custom icon uses the public icon (2026-11-10).** `ISBundleIcon initWithBundleURL:`
    draws the bundle's OWN icon and ignores a pasted ("Get Info") icon, which Finder, the Dock and the
    preview all show: a Chrome web app with a pasted icon baked as its old one. Signal = the `Icon\r`
    file at the bundle's top level (`hasFinderCustomIcon`); `URLResourceKey.customIconKey` read nil there.
    What ships: the public render in the style the system is in AT BAKE TIME, in all three slots (the
    tinted slot gets a colour image the system remaps). Default, Dark and Clear Dark: unverified in the
    Dock (the owner checks it on the release build after 2.7.2).
  - The fallback `.icns` uses the Default renders, so a bake during Clear still gets a Default fallback.
  - `docktile-actool` honours a tinted-only `hidden-specializations` entry (Tintable stack shows only
    that layer — pinned end-to-end by `IconCompilerTests`). The three-way hiding is built in
    `appsFaceIconJSON`, NOT through `LayerSpec.Exclusive`, so glyph documents are unchanged.
  - **Verified by eye in the Dock under Clear Dark only (2026-10-19).** Default, Dark, Clear Light and
    Tinted Light/Dark after the three-grid change are unverified in the Dock (only `ictool`
    renders); check each by eye before claiming them.

## Icon Generation — Legacy Path (`IconGenerator.swift`, macOS 15 fallback)

Frozen: this describes the pre-Tahoe 4-variant bake, unchanged by the declarative rewrite except
where noted. Most of it is shared drawing machinery the declarative path's lean layer renderer
also calls into.

**Shape**: Continuous corners (squircle) via `RoundedRectangle(.continuous)`, radius = 22.5% of the shape's width. **On the icon grid, like the Tahoe fallback `.icns`** — the shape is inset by `IconDepthMetrics.contentInsetRatio` on a cleared canvas, and the glyph stays measured against the FULL canvas (so the two bakes place it identically). It shipped **full-bleed** through 2.0.2: the Dock scales every icon to one tile size, so a macOS 15 tile drew ~24% larger than every neighbour (feedback 2026-09-30). Guarded by `LegacyIcnsMarginTests` — mid-edge transparent in all four styles, opaque extent equal to a real system icon's (Finder at 1024 px), max-scale glyphs inside the inset shape. The live preview deliberately does NOT inset (a UI slot has no neighbours — see the seam table).

**Background**: Linear gradient between the tile's two fill stops, from `TilePalette.resolve`.

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
  Callers read `IconDepthMetrics` directly (the `IconGenerator` forwarders were deleted 2026-11-04).
  Guarded by `IconDepthMetricsTests`.
- **Same treatment on non-tile squircles**: `SettingsBadgeIcon` (sidebar Settings rows) follows
  the LIVE icon style like the tile icons beside it — `IconStyle.forDisplay` +
  `TintColor.badgeColors(for:tint:)`, a raw-`Color` mirror of `colors(for:iconType:)` kept in
  lock-step by `BadgeColorMappingTests` (it pinned `.defaultStyle` until 2026-09-07, leaving
  colourful badges beside dark-styled tiles); the symbol/emoji picker cells get the subtle glyph
  contact shadow.
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
caller. Views no longer read `currentStyle` for display: they combine the published raw token
with their own environment via `IconStyle.forDisplay(raw: iconStyleManager.rawStyle,
colorScheme:)` (the 2026-09-02 appearance-environment rewrite). `rawStyle` is kept live in the
MAIN APP by a display-only KVO observer (`startDisplayObservation()` — read-only, republishes the
token, never rewrites an icon, so the detection quarantine is untouched) plus a
`didBecomeActiveNotification` refresh as sleep recovery, **plus a 2 s poll while the app is visible**
(`displayPollAction` / `displayPollInterval`, stopped on `didChangeOcclusionStateNotification`; each
read synchronizes first). The poll is required: on macOS 27 no notification is posted for an Icon &
widget style change (NSWorkspace's undeclared icon-appearance notification and
`AppleInterfaceThemeChangedNotification` both stayed silent over 9 real changes) and the KVO reached
the app 1.4 s to 8 min late or not at all, while a bare CLI process got it in ~100 ms (measured
2026-10-15, issue #22; the key itself is written promptly with the documented values). Helpers seed it once at launch (their
popover content rebuilds on every `show()`). `currentStyle` itself is still seeded once at `init`
(a Swift definite-initialization guarantee — see [Icon Style
Detection](icon-style-detection.md)) and on Tahoe never changes afterwards — it is
legacy-detection state, not a display source. This is the frozen fallback everything below
describes, and it is what still runs, unchanged, on macOS 15.

macOS Tahoe has an independent "Icon and widget style" setting (separate from Light/Dark appearance), read from `AppleIconAppearanceTheme` in UserDefaults.

| Style | UserDefaults Value | Design |
|-------|-------------------|--------|
| Default | `nil` | Colorful gradient, white symbol |
| Automatic | `"RegularAutomatic"` | **Follows system appearance** — `.dark` in Dark mode, `.defaultStyle` in Light. This is the Tahoe default; `IconStyle.from()` MUST map it or dark icons never apply in Automatic mode |
| Dark | `"RegularDark"` | **Splits by icon type.** SF Symbol → tile's own tint as the *glyph* (fitted by `TilePalette` so its shaded bottom clears 3:1 against `#2C2C2E`, so deep violet stays visible) on a **neutral near-black** background — HIG-native, and calmer than a stark white glyph. Colour emoji → brightness-capped shade of the tile's own tint (`SRGB.cappingBrightness` 0.22 top / 0.13 bottom, hue preserved) with the full-colour emoji (can't be recoloured); Mono emoji take the neutral near-black. See [dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) |
| Clear | `"ClearAutomatic"` | Light gray, dark gray symbol (grayscale only) |
| Tinted | `"TintedAutomatic"` | Medium gray, white symbol (grayscale only) |

`IconStyle.resolve()` maps values via `systemAppearanceIsDark` for the Automatic case (reads `AppleInterfaceStyle` through CFPreferences, no `NSApplication` dependency); an unrecognised value resolves to `nil` (don't act), never Default. **Detection is event-driven with no timer** — see [Icon Style Detection](icon-style-detection.md) for the signal hierarchy, the seal re-signing, the launch self-heal, and the observed value set (this table's values are illustrative, not exhaustive: light/dark spellings like `"ClearLight"` are real too).

- Single `IconStyleManager.shared` is the sole detector per process (KVO-primary, no polling) — pre-macOS-26 only, per above.
- All 4 variants generated upfront during `installHelper()` (~200-400ms) — legacy branch only; the declarative branch compiles one car instead (see Declarative Pipeline above).
- Style switching is a file copy + immediate ad-hoc re-seal (the swap breaks the bundle signature otherwise) — legacy only; nothing ever swaps a file in a declarative helper.
- For view re-renders, key off `IconStyle.forDisplay(raw: iconStyleManager.rawStyle, colorScheme:)` — live on every macOS version (observer-fed on Tahoe, detection-fed pre-26). Do NOT reference `currentStyle` in view bodies: it is legacy-detection state, frozen after init on Tahoe.
- **Dark variant rationale + HIG sources**: [docs/dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) (darkened-own-tint background + white symbol, and why) — the same colour choices are reused by the declarative path's `dark` background/glyph layers. The colour roles now come from `TilePalette` (Colour emoji keeps the darkened own tint; symbols use the 3:1-fitted glyph on near-black; Mono uses near-black for every icon type).

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
- **Popover cells draw a cached bitmap, never the IconServices `NSImage` (critical)**:
  `TileIconRasterCache` holds rasterised `CGImage`s for the process lifetime, keyed by item, pixel
  size, appearance token (icon style + Light/Dark + the stored style value — Tinted Light and
  Tinted Dark are one `IconStyle` but different system renders, issue #22) and the app bundle's
  modification time, and is
  prewarmed at helper launch. Drawing the `NSImage` directly makes SwiftUI trigger a synchronous
  XPC render per icon; `iconservicesagent` evicts within minutes, so every first open after idle
  paid ~3.5 ms per app on the main thread (201 ms on a 10-app Release tile). Guarded by
  `TileIconRasterCacheTests`.

## Tinted and Clear tile face in the app (`TileFace`, issue #22)

macOS draws the Tinted style in a colour no public API exposes (it is NOT `controlAccentColor`:
measured cyan beside a blue accent), so `DockTileIconPreview` can only show a grey stand-in. Clear is
the same case (the system's light/dark glass with every layer remapped; an App Grid tile read as a
white plate in the app beside dark glass in the Dock, 2026-10-19). The
sidebar row and the Tile Detail hero use `TileFace`, which under Tinted or Clear shows the icon macOS
renders for the tile's helper (`NSWorkspace.icon(forFile:)`, enlarged by the icon-grid margin so
the shape fills the slot) — but only when `TileFace.showsSystemIcon` holds: the helper's
Info.plist `DTIconSignature` (stamped by `helperInfoPlist` from `DockTileConfiguration.iconSignature`)
equals the tile's current one. Edits not yet applied with Update, never-added tiles and helpers
built before the stamp all keep our drawing. Default and Dark keep our drawing (it matches the
system there). The helper lookup scans the helper folder, so it runs under Tinted and Clear only. Customise
and Smart Add keep `DockTileIconPreview` (canonical / not-yet-built previews).

## Helper Bundle Icon Priority

macOS loads: `Assets.car` > `CFBundleIconFile`. A freshly-copied helper **must** have the
**main app's own** `Assets.car` removed (`stripMainAppIcons`) — otherwise it would override any
custom icon regardless of pipeline. On macOS 15 nothing replaces it: `CFBundleIconFile =
"AppIcon"` stays the only icon source. On macOS 26 the declarative pipeline puts a **new,
per-tile** `Assets.car` back afterwards and additionally sets `CFBundleIconName = "AppIcon"`
alongside `CFBundleIconFile` — the car is deliberate there, not a leftover.

## Custom Colour Gradients

Custom colours use `SRGB.lighterShade(by:)` (`TilePalette`, increases brightness) for the top gradient — not `opacity()`, which creates semi-transparent colours that leave gaps in CoreGraphics gradient rendering.

## Runtime Icon Updates

Never set `NSApp.applicationIconImage` at runtime — causes size mismatch in Dock. Use file-based approach: copy icon variant → `touchBundle()` → re-register with Launch Services. This whole gotcha is about the legacy style-swap path; a declarative helper on macOS 26 never updates its icon at runtime at all — there is nothing to swap.

## Cache Clearing

```bash
killall iconservicesd && killall Dock
lsregister -f -R /path/to/DockTile.app
```
