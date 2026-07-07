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
- **Theme-dependent assets swap via inline style off `resolvedTheme` (with a mounted guard), NOT
  `.dark` CSS rules** — Turbopack doesn't reliably hot-reload `globals.css`, and the guard avoids
  a hydration flash. Pattern lives in `hero.tsx`.
- Cards have fixed theme character: the Ghost card is always dark (hardcoded whites are correct);
  the Smart Add card flips, so its colours must be theme-aware (`text-zinc-600 dark:text-white/80`).
  The Ghost card runs a charcoal gradient (`from-zinc-800 to-zinc-900`), NOT flat zinc-900 — flat
  read as one slab with the pure-black Final CTA when stacked on mobile.

## Adaptive nav

The header samples the section under the nav via `elementFromPoint` and flips tone from
`[data-nav-tone]`. **Every dark section must be tagged `data-nav-tone="dark"`**; light is the
untagged default — `"light"` is never set, so don't test for it.

Below `md` the three text links collapse behind a hamburger (tone-matched glass dropdown in
`header.tsx`); the pill keeps logo + Download only. The pill must fit the viewport with side
gutters — the full link row overflowed both edges on phones.

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