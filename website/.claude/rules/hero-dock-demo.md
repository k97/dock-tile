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
- The wallpaper swaps by theme in CSS: `hero.tsx` passes both dither URLs as custom properties
  (`--hero-bg` / `--hero-bg-dark`) and `.dark .hero-texture` picks the dark one — right on the
  first frame, and only the used image downloads (no mount-guard JS swap). The scrim
  ramps bright-top → `black/95` bottom (wallpaper at full brightness up top, CTA on a settled dark
  base); the headline has its own radial-masked readability blur, independent of the scrim.
- **Load veil** (`components/hero-veil.tsx` + the `<link rel=preload>`s in `app/page.tsx`): the
  wallpaper is a CSS `background-image`, discovered only *after* first paint, so it used to pop in
  late (the residual load flash the theme fixes never touched). Two-part fix. **(1)** A
  theme-matched preload on the homepage — `<link rel="preload" as="image" media="(prefers-color-scheme:…)">`
  so only the shown scheme downloads (React 19 re-emits manually-authored preloads; harmless — both
  copies keep `media`, so it stays **one** fetch per scheme, and `ReactDOM.preload` can't be used
  because it has no `media`). **(2)** A branded splash (`HeroVeil`) — Dock Tile mark on near-black —
  that covers the viewport on the **first load of a session** and lifts the instant the wallpaper
  *decodes* (floor 320ms so a warm cache doesn't blink, hard cap 1.2s so it never blocks). The lift
  is **CSS** (a JS/rAF fade drops frames while the page loads); the JS probe reads the pre-paint
  `.dark` class so a manual theme override waits for the *right* image. Skipped with **NO flash** on
  repeat-session loads (pre-paint `data-veil-shown` on `<html>` via the inline script + sessionStorage
  in `layout.tsx`), reduced motion (CSS `@media`), and no-JS (`<noscript>`) — every skip decided
  *before* first paint, same CSS-first-decision discipline as the theming rule. Don't drop the
  `<noscript>` (no-JS would strand behind an unliftable veil) or the pre-paint script (repeat loads
  would flash the veil).
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
- Widths mirror the product's tiers: grid = 324px (5-col medium), list = 240px (medium list),
  capped at `viewport − 16px` so sub-340px phones keep the 8px gutters. The Media tile is
  list-layout on purpose — the demo must show both layouts.
- **Configure navigates, never dead-ends**: the grid header's gear and the list's "Configure…" row
  close the popover and smooth-scroll to `/#features` (auto under reduced motion) — the site's
  stand-in for the real app's "open the configurator" deep link.
- Tile faces mirror app truth: 22.5% squircle radius, 58% glyph-to-tile ratio, and in dark theme
  the app's Dark icon style (neutral near-black background, the tile's tint moves to the glyph).
- **Auto-showcase**: hard-stops the instant the real pointer enters or the user clicks; resumes
  after ~2.8s away. The cursor glides to each tile's **resting** centre (live rects mid-glide
  chase the magnifying icons), then a two-step live "aim" + ±7px jitter lands the click;
  magnification is driven by synthesising `mousemove` at the fake cursor every frame. Fully
  disabled under reduced motion.
- **Touch resume model (critical — keeps the demo alive on phones)**: hover semantics don't exist
  on touch — a finger's `pointerleave` fires right after every tap-up, so resuming on leave (the
  mouse rule) would let the showcase barge back over a popover the user just opened, and *not*
  resuming would leave the demo dead after the first tap. So resume-on-leave is mouse-only; touch
  re-arms on tap-up / `pointercancel` / outside-tap dismiss / same-tile toggle-close (via
  `lastPointerTypeRef`, since click handlers fire after the pointer events). A tap that OPENS a
  popover survives because `handleAppClick`'s stop cancels the pending resume. `resume` is a no-op
  unless the showcase is stopped — touch fires it liberally, and re-arming a running showcase
  would spawn a second concurrent `step()` walker.
- Finder / System Settings bookend the dock — non-clickable, tooltip only.
- Reopening during the 200ms close animation is safe: the close timer lives in `closeTimerRef`
  and `open()` cancels it (a stale timeout used to shut the new popover the moment it appeared).

## Bento popover showcase (`home-sections.tsx` PopoverShowcase)

The "Grid or list" card's illustration is a **static 1:1 clone of this demo's popovers** — same
markup, same product widths (grid 324 / list 240), interactivity stripped. Keep it in sync when
the demo's popover rendering changes. **Illustrative macOS components never restyle responsively**
(explicit owner mandate): they render at fixed natural size and `ScaleToFit` applies one uniform
`transform: scale()` — an aspect-locked zoom, capped at 1:1 — to fit the card. Never let them
stretch, squish, stack, or swap sizes per breakpoint; hand-drawn "roomy-ish" approximations were
rejected twice before this.

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