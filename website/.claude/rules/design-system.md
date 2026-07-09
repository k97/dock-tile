# Design System & Theming

Visual language: dark editorial shells + light feature sections, glass, grain, **emerald as the
only accent**. Narrative the site sells: "iOS-style folders for the Mac's Dock."

## Tokens

- Dark shells are **pure `#000` with a bottom-heavy gradient — never flat black**; secondary dark
  blocks `#18181B`; light background `#F4F4F5` (zinc-100).
- Grain overlay at 15% on every dark section (prevents banding).
- Radii: 2.5rem on major section wrappers (the site's rhythm — keep it); internal cards 16–24px.
- The power-user bento is 3-across only from `xl`; below that the cards stack in a centred
  `max-w-md` column — a narrow 3-col card can't hold the fixed-size popover showcase
  (see hero-dock-demo.md "Bento popover showcase").
- Neutral chrome uses the shadcn tokens (`bg-background`, `bg-card`, `text-muted-foreground`,
  `border-border`), never literal `bg-white`/`bg-zinc-*`. The tokens are pinned to the exact
  Tailwind zinc oklch values, so the light theme is pixel-identical to the pre-token design.

## Light/dark model (critical)

- `next-themes`, class attribute, system default. The **footer `ThemeSwitcher` must stay** — it
  was dropped once during a consolidation and explicitly demanded back.
- **Signature-dark bands stay dark in BOTH themes** (they simulate macOS chrome or are brand
  moments): hero, Dock Lock story, Final CTA, Ghost Mode card, and the dark page headers on
  FAQ/release-notes/legal. Only neutral surfaces theme-flip.
- **Anything visible at load themes via CSS (`dark:` variants / `.dark` rules), NEVER a
  `mounted && resolvedTheme` guard** (one exception, next bullet) — next-themes sets `.dark` on `<html>` before first paint, so
  CSS-driven theming is right on frame 1; a mounted guard *guarantees* dark-theme visitors watch
  the light variant swap after hydration (the load flash fixed in 2026-07). Patterns: background
  images pass both URLs as CSS vars and `.dark` picks one (`hero.tsx` + `.hero-texture`); `<img>`
  variants dual-render with `dark:hidden` / `hidden dark:block` (lazy `next/image`s only fetch the
  visible one); tile mocks use the shared `.tile-face` rule + `--tile-bg`/`--tile-glyph-dark` vars.
  (The Turbopack stale-`globals.css` quirk is a dev-workflow caveat — restart `next dev` — not a
  reason to theme in JS.)
- **The lone exception: which theme is *selected* (`ThemeSwitcher`'s active pill).** `<html>` only
  ever carries the *resolved* theme (`light`/`dark`), never the fact that the user picked
  `"system"` — so CSS can't express this control's active state and it alone must wait for mount.
  Defer **only the highlight, never the icons**: `const active = mounted ? theme : undefined`.
  Do NOT compare `theme` directly in render — next-themes seeds it from `localStorage` inside its
  lazy `useState` initialiser, i.e. during the FIRST **client** render, while the server rendered
  `undefined`; that mismatches the active button's `className` on every load (shipped in `cd8d437`
  on a wrong premise, fixed 2026-07-09). The whole-component `if (!mounted) return <placeholder/>`
  guard stays banned — that's the empty-circles pop `cd8d437` rightly removed.
- Cards have fixed theme character: the Ghost card is always dark (hardcoded whites are correct);
  the Smart Add card flips, so its colours must be theme-aware (`text-zinc-600 dark:text-white/80`).
  The Ghost card runs a charcoal gradient (`from-zinc-800 to-zinc-900`), NOT flat zinc-900 — flat
  read as one slab with the pure-black Final CTA when stacked on mobile.

## Adaptive nav

The header samples the section under the nav via `elementFromPoint` and flips tone from
`[data-nav-tone]`. **Every dark section must be tagged `data-nav-tone="dark"`**; light is the
untagged default — `"light"` is never set, so don't test for it.

**The Safari-only pill overflow (critical — two guards, keep both).** On every iPhone the nav pill
rendered 24px narrower than its own content and "FAQ" spilled out onto the wallpaper; desktop
Chrome was correct at every window width, so this is invisible without a WebKit check. Two causes
compounded, verified in Playwright WebKit against the real page:

1. **Source**: Tailwind preflight sets `img { max-width: 100% }`. WebKit counts an `<img>` with a
   **percentage** max-width as contributing **0** to its flex container's min-content width (the
   percentage can't resolve against an indefinite size during intrinsic sizing; Chromium falls back
   to the definite `width`). So the logo icon vanished from the pill's min-content: 295.69px in
   WebKit vs 319.69px in Chromium. Guard: **`max-w-none` on the logo `<Image>`**.
2. **Amplifier**: `position:fixed; left:50%; width:auto` is shrink-to-fit against an available width
   of only `100vw − 50vw`, so the used width lands on that too-small min-content. Guard: **centre
   with `inset-x-0 flex justify-center`, NEVER `left-1/2 -translate-x-1/2`.** The full-width strip is
   `pointer-events-none` (so it can't swallow hero clicks), the pill opts back in with
   `pointer-events-auto`, and `px-3` guarantees the gutters.

Either guard alone fixes it; both are kept because each is independently correct. The general lesson:
**any `w-fit`/shrink-to-fit box containing an `<img>` is exposed** — verify layout in WebKit
(`npx playwright install webkit`), not just Chrome.

Below `md` the pill drops **Download** (`max-md:hidden`) and keeps logo + wordmark + the three
text links inline — on a phone nobody installs a macOS app from the nav, and the links are the
contextual actions (the hero + Final CTA still offer Download). No hamburger. The wordmark stays
on mobile (nothing else on a phone names the app) and yields only below 360px
(`min-[360px]:inline`), where the pill would otherwise touch the viewport edges. The pill must
always fit the viewport with side gutters — it was the Download button that made the full link
row overflow phones and forced the (since removed) hamburger.

## Typography

- Headings: **Inter**, 600–700, `tracking -0.05em`, `leading 1.05`. The display font (Special
  Gothic Expanded One) is still loaded in `layout.tsx` but unused in rendered pages — only
  orphaned components reference `font-display`. Haskoy was trialled and reverted (sources in
  `docs/website/haskoy/`) — don't re-suggest it.
- Caption canon: `text-[12px] font-bold uppercase tracking-[0.2em]` at ~60% foreground (the hero
  "For macOS 26+" eyebrow). Reuse it; don't invent new caption styles.
- The heading scale was deliberately stepped down a notch site-wide — don't "fix" headings bigger.

## Motion

- No animation library: vanilla React + rAF + CSS keyframes, **transform/opacity only — never
  animate `width`/`height`/`left`**. (The Dock Lock pill mis-centred for hours because animated
  `left` stacked with transform-based centering — never combine the two.)
- Entry animations: `cubic-bezier(0.16, 1, 0.3, 1)` over 0.8s (the `.reveal` + `--reveal-delay`
  stagger pattern); snappier curves are reserved for interactions (popover, press).
- **Every animation needs a `prefers-reduced-motion` fallback** — a sensible static resting state,
  not just "off".
- The pre-shadcn Motion-based dock demo is preserved on `feature/dock-motion-build`; don't resurrect it.

## CSS / tooling gotchas (each cost real debugging time)

- **Never hand-write `-webkit-` prefixes.** Lightning CSS drops the standard unprefixed property
  when both are present — this silently killed `backdrop-filter` on every glass surface once.
  Let the toolchain prefix.
- Tailwind v4 spellings: `bg-linear-to-b` (not `bg-gradient-to-b`); `gap-*` (not `space-x/y`).
- **Squircles**: `.squircle` is a superellipse SVG mask (radius 22.5% of size, exponent ≈ 5)
  because Safari has no `corner-shape` and plain `border-radius` reads rounder than real macOS
  icons. A CSS mask **clips the element's own `box-shadow`** — shadows go on a wrapper via
  `filter: drop-shadow`.
- Headless Chrome can't composite `backdrop-filter` (always reports `none`) — verify glass in real
  Chrome, in an isolated profile; never drive the user's own browser.