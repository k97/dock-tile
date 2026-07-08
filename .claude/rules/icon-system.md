# Icon System

## Two Separate Systems

| | Main App | Helper Tiles |
|---|---|---|
| Source | Icon Composer (`AppIcon.icon/`) | `IconGenerator.swift` |
| Output | `Assets.car` + `AppIcon.icns` (Xcode build) | Custom `.icns` (runtime) |
| Variants | light/dark/tinted PNGs in icon.json | 4 style variants per tile |

## Icon Generation (IconGenerator.swift)

**Shape**: Continuous corners (squircle) via `RoundedRectangle(.continuous)`, radius = 22.5% of width.

**Background**: Linear gradient from `TintColor.colorTop` to `colorBottom`.

**Glass effect**: White inner stroke, line width scales proportionally (0.5pt at 160pt). Opacity + width now come from the shared `IconDepthMetrics` seam (see below), not inline constants.

**Content**: SF Symbols (white, `.semibold`) or emojis. Size controlled by `iconScale` (10-20, default 14).

**Output**: All 10 sizes (16, 32, 128, 256, 512 @ 1x and 2x) via `iconutil`.

**Critical gotcha**: Use `NSBitmapImageRep` with explicit pixel dimensions — not `NSImage(size:).lockFocus()` which creates Retina-scaled backing stores that produce wrong pixel counts for `iconutil`.

**No baked-in *tile* shadow** — the Dock adds the outer drop shadow dynamically; baking that would double it. This is distinct from the **inner glyph depth** below, which IS baked (an inner contact shadow + sheen the Dock does not provide).

## Liquid Glass Depth (`IconDepthMetrics`)

Tahoe's real Liquid Glass icons get specular highlights + depth from the system's layered `.icon`
pipeline (Icon Composer). DockTile tiles are generated at runtime (per tint × per style), so they
can't use it — instead they **emulate** the treatment by baking a restrained depth pass. All the
magnitudes live in one pure, value-in/value-out seam,
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

Max ratio: 0.60 of icon size. Stepper capped at 17 (SF Symbols) / 16 (emojis).

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

## Icon Style Manager (macOS Tahoe)

macOS Tahoe has an independent "Icon and widget style" setting (separate from Light/Dark appearance), read from `AppleIconAppearanceTheme` in UserDefaults.

| Style | UserDefaults Value | Design |
|-------|-------------------|--------|
| Default | `nil` | Colorful gradient, white symbol |
| Automatic | `"RegularAutomatic"` | **Follows system appearance** — `.dark` in Dark mode, `.defaultStyle` in Light. This is the Tahoe default; `IconStyle.from()` MUST map it or dark icons never apply in Automatic mode |
| Dark | `"RegularDark"` | **Splits by icon type.** SF Symbol → tile's own tint as the *glyph* (lifted on perceived luminance to a `0.55` floor via `liftedForDarkGlyph`, so deep violet stays visible) on a **neutral near-black** background — HIG-native, and calmer than a stark white glyph. Emoji → darkened shade of the tile's own tint (`darkenedForDarkMode`, hue preserved) with the full-colour emoji (can't be recoloured). See [dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) |
| Clear | `"ClearAutomatic"` | Light gray, dark gray symbol (grayscale only) |
| Tinted | `"TintedAutomatic"` | Medium gray, white symbol (grayscale only) |

`IconStyle.from()` resolves `"RegularAutomatic"`/`"Automatic"` via `systemAppearanceIsDark` (reads `AppleInterfaceStyle` through CFPreferences, no `NSApplication` dependency). Because `IconStyle.current` resolves dynamically, the 2-second poll also catches a Light↔Dark appearance toggle while in Automatic mode (the enum flips, `switchIcon` fires).

- Single `IconStyleManager.shared` with 2-second polling (notifications unreliable)
- All 4 variants generated upfront during `installHelper()` (~200-400ms)
- Style switching is instant file copy, no regeneration
- Reference `iconStyleManager.currentStyle` in view body with `let _ =` to trigger re-renders
- **Dark variant rationale + HIG sources**: [docs/dark-mode-icon-rendering.md](../../docs/dark-mode-icon-rendering.md) (darkened-own-tint background + white symbol, and why)

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
- Safe because `AppIconLoader` never loads helper tile faces — those get their own dark variant
  from `IconGenerator` / `IconStyleManager`, so there's no double-treatment.
- Popover/list views re-render on icon-style changes via their `.id("\(app.id)-\(style)")`
  composites, so the variant tracks Light↔Dark and theme switches live.

## Helper Bundle Icon Priority

macOS loads: `Assets.car` > `CFBundleIconFile`. Helpers **must** have `Assets.car` removed after copying from main app, and `CFBundleIconFile = "AppIcon"` set in Info.plist.

## Custom Colour Gradients

Custom colours use `lighterShade(by:)` (increases brightness) for the top gradient — not `opacity()`, which creates semi-transparent colours that leave gaps in CoreGraphics gradient rendering.

## Runtime Icon Updates

Never set `NSApp.applicationIconImage` at runtime — causes size mismatch in Dock. Use file-based approach: copy icon variant → `touchBundle()` → re-register with Launch Services.

## Cache Clearing

```bash
killall iconservicesd && killall Dock
lsregister -f -R /path/to/DockTile.app
```
