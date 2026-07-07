# Hero & Dock Demo

The hero IS the product demo: a dithered macOS wallpaper, an interactive Dock of custom tiles,
and the popover. Everything mirrors the real app — values were extracted from the Swift codebase,
not invented. Product-truth spec of record: `.superdesign/refs/product-demo-spec.md`.

## Hero art

- Background = a **Ventura wallpaper turned into an ordered-dither halftone**, generated
  programmatically (no hand-made asset):
  `magick docs/website/13-Ventura-Light.jpg -resize 520x520^ -gravity center -extent 520x520 -modulate 108 -ordered-dither o4x4,6 -scale 400% hero-bg.webp`
  Dark mode runs `13-Ventura-Dark.jpg` through the **same recipe** so it reads as a recolour, not
  a different image. Sources stay untouched in `docs/website/`; the ~800KB webp is accepted
  (halftone detail compresses poorly).
- The wallpaper swaps by theme inline in `hero.tsx` (`resolvedTheme` + mount guard). The scrim
  ramps bright-top → `black/95` bottom (wallpaper at full brightness up top, CTA on a settled dark
  base); the headline has its own radial-masked readability blur, independent of the scrim.
- Headline: `heroHeadlineA` white + `heroHeadlineB` at `white/40` — the same dimmed-second-line
  treatment as the FAQ header ("Questions, / answered."); keep the two consistent. The copy
  ("Group your apps. / Declutter your Dock.") was chosen spelling-neutral so it needs no US override.

## Dock demo contract (`dock-demo.tsx` + `ui/mac-os-dock.tsx`)

The dock itself (magnification, tooltips) is the vendored shadcn.io `MacOSDock` (registry needs a
token URL: `npx shadcn@latest add "https://www.shadcn.io/r/mac-os-dock.json?token=…"`). The
wrapper owns everything DockTile-specific. Behaviour rules — each was hard-won, don't regress:

- **The popover anchors to the clicked icon** (the app's signature interaction): body centred over
  the tile, clamped to an 8px viewport gutter, arrow at the icon centre; scale-pop from the arrow
  origin (`dock-scale-in/out`); starts **closed**; no dock-icon bounce.
- Widths mirror the product's tiers: grid = 324px (5-col medium), list = 240px (medium list). The
  Media tile is list-layout on purpose — the demo must show both layouts.
- Tile faces mirror app truth: 22.5% squircle radius, 58% glyph-to-tile ratio, and in dark theme
  the app's Dark icon style (neutral near-black background, the tile's tint moves to the glyph).
- **Auto-showcase**: hard-stops the instant the real pointer enters or the user clicks; resumes
  after ~2.8s away. The cursor glides to each tile's **resting** centre (live rects mid-glide
  chase the magnifying icons), then a two-step live "aim" + ±7px jitter lands the click;
  magnification is driven by synthesising `mousemove` at the fake cursor every frame. Fully
  disabled under reduced motion.
- Finder / System Settings bookend the dock — non-clickable, tooltip only.
- Known bug (fix pending): rapidly reopening during the close animation hits `close()`'s stale
  timeout and shuts the new popover. Fix: keep the timer in a `closeTimer` ref, clear it in both
  `open()` and `close()`.

## App-icon assets (`public/assets/app-icons/`)

- Real icons extracted from installed apps (Swift `NSWorkspace` script → 128px PNG; `sips` for
  `.icns`). Lowercase-hyphen names; `-dark` suffix only where macOS ships a dark rendition
  (finder, settings — official dark Finder source: `docs/website/Finder_Dark_macOS_27_icon-*.icns`).
- **The size-parity law (the most recurring bug):** every icon must hold ~90.6% content on its
  canvas (116×116 in 128px) — real macOS icon art always carries ~9% transparent bleed. Full-bleed
  icons render visibly oversized next to their neighbours; custom tile faces are inset to
  `ICON_CONTENT_RATIO` (90.625%) for the same reason, in both themes. Normalise any new icon
  (trim → re-pad) before committing.
- Served `unoptimized` + `priority` via `next/image` — the optimizer once cached a broken
  extraction as stale webp, and 6KB icons gain nothing from it.
- Icons without a dark variant keep the same file at constant size in dark mode (macOS's own
  fallback); never shrink them.
- Third-party icons are trademark use (normal for launcher sites); each swaps out in one line of `TILES`.

## Tile glyphs (`tile-glyph.tsx`)

Filled Bootstrap Icons (MIT) matching each tile's real SF Symbol — outline glyphs read "comicky"
and un-Mac. One shared set for every designed icon on the site (hero dock, Smart Add, presets).
Multi-path or non-16×16 glyphs go in `GLYPH_DEFS` (e.g. the two-bubble chat symbol).