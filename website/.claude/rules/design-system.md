# Design System & Theming

Visual language: dark editorial shells + light feature sections, glass, grain, **emerald as the
only accent**. Narrative the site sells: "iOS-style folders for the Mac's Dock." **Exception:
macOS mocks use the Mac's system accent blue** for their selection (#007AFF, Dark #0A84FF) — a
Mac inspector selecting in emerald reads as fake (owner, 2026-11-09, the customiser card).

## Tokens

- Dark shells are **pure `#000` with a bottom-heavy gradient — never flat black**; secondary dark
  blocks `#18181B`; light background `#F4F4F5` (zinc-100).
- Grain overlay at 15% on every dark section (prevents banding).
- Radii: 2.5rem on major section wrappers (the site's rhythm — keep it); internal cards 16–24px.
  shadcn remaps the radius names: `rounded-sm` 6 px, `md` 8, `lg` 10 (not Tailwind v4's 4/6/8).
  macOS mocks copy the app's proportions — the customiser's Background cards `rounded-sm` (6 px on
  32 px), Style cards `rounded-lg` (10 px on 69 px); `rounded-lg` on the short Background card
  read far rounder than the app (owner, 2026-11-09).
- **One spacing rhythm, letters.app-style (measured side by side 2026-11-09):** 200px
  (`md:py-50`; 96 px on phones) from a section's last content to the next heading, everywhere —
  128 px read cramped once the type grew to letters' 44 / 18 px (owner, 2026-11-09); section headings
  `text-section` (see Typography); heading → cards 52 px (`mb-12 md:mb-13`, letters' value);
  card padding 40 px (`p-6 md:p-10`); big-card pill: 14 px semibold, `h-8 pl-3 pr-3.5 gap-1.5`,
  16 px icon, `mb-5` = 20 px to the title (letters' 18 px pill read too loud — owner 2026-11-09,
  "reduce the font size of tags"); gutters
  `px-4 sm:px-6 md:px-10`. Deliberate differences: our cards are white with a hairline on the
  zinc-100 page (theirs: flat #F5F5F5 cards on white, borderless white pills) — the pill keeps
  its border because it sits on white.
  Two light sections back to back: the second takes no top padding (the first's bottom is the
  gap). Re-measure after moving sections — the swap that put two light sections together left a
  160px gap.
- The power-user bento is 3-across only from `xl`; below that the cards stack in a centred
  `max-w-md` column — a narrow 3-col card can't hold the fixed-size mocks
  (see hero-dock-demo.md "Card mocks").
- Neutral chrome uses the shadcn tokens (`bg-background`, `bg-card`, `text-muted-foreground`,
  `border-border`), never literal `bg-white`/`bg-zinc-*`. The tokens are pinned to the exact
  Tailwind zinc oklch values, so the light theme is pixel-identical to the pre-token design.

## Light/dark model (critical)

- `next-themes`, class attribute, system default. The **footer `ThemeSwitcher` must stay** — it
  was dropped once during a consolidation and explicitly demanded back.
- **Signature-dark bands stay dark in BOTH themes** (they simulate macOS chrome or are brand
  moments): hero, Dock Lock story, the closing band, Ghost Mode card, and the dark page headers on
  FAQ/release-notes/legal. Only neutral surfaces theme-flip.
- **Anything visible at load themes via CSS (`dark:` variants / `.dark` rules), NEVER a
  `mounted && resolvedTheme` guard** (one exception, next bullet) — next-themes sets `.dark` on `<html>` before first paint, so
  CSS-driven theming is right on frame 1; a mounted guard *guarantees* dark-theme visitors watch
  the light variant swap after hydration (the load flash fixed in 2026-07). Patterns: background
  images pass both URLs as CSS vars and `.dark` picks one (`hero.tsx` + `.hero-texture`); `<img>`
  variants dual-render with `dark:hidden` / `hidden dark:block` (lazy `next/image`s only fetch the
  visible one); tile mocks use the shared `.tile-face` rule + `--tile-bg`/`--tile-glyph-dark` vars.
  The dark plate (`#232323 → #0f0f10`), `TileFace`'s dark rim (lit 1px top edge, fainter bottom,
  0.5px hairline) and the dark glyph glow (`drop-shadow` in the glyph's own colour) are sampled
  from macOS 26's Dark-style render of Mail.app (2026-10-30, owner: "look at the icons on my
  Dock") — the real helpers get them from the system's glass pass. Re-sample on a new macOS.
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
  **Its light-theme tray is `bg-foreground/6` + `border-foreground/10` with a `bg-card` selected
  pill** (2026-10-30): light `--muted` and `--background` both equal the page's zinc-100, so the
  token-default tray and pill were invisible ("barely noticeable" — owner). Dark keeps `muted`.
- Cards have fixed theme character: the Ghost card is always dark (hardcoded whites are correct);
  the Smart Add card flips, so its colours must be theme-aware (`text-zinc-600 dark:text-white/80`).
  The Ghost card runs a charcoal gradient (`from-zinc-800 to-zinc-900`), NOT flat zinc-900 — flat
  read as one slab with the pure-black Final CTA that used to follow it on mobile (since
  2026-10-30 the closing band, on the hero's wallpaper).

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

**Current link = one rule for nav AND footer (`lib/nav.ts`, 2026-10-31).** `usePathname()` never
includes the `#hash`, so the old `pathname.startsWith("/#features")` left Features dead forever,
and the footer had no current state at all. Route links use `isActiveRoute` (exact or a `/`
sub-path); section links (Features) are current on `/` while a `data-nav-section="features"`
section crosses 40% of the viewport, read by the header's existing scroll sampler (no second
listener). Tagged: the custom-tiles story, Dock Lock, the power-user cards, the details section — never the
hero or the closing band. Current links carry `aria-current` ("page" / "location").

**The pill's ends are concentric.** The Download button sits 7px from the pill's edge on every
side, so the logo's hover pill does too (`px-1.5` on the pill, `pl-1.5` in the logo link → icon
13px from the side, top and bottom alike). It was 13px / 17px on the left, which read as lopsided.

Below `md` the pill drops **Download** (`max-md:hidden`) and keeps logo + wordmark + the three
text links inline — on a phone nobody installs a macOS app from the nav, and the links are the
contextual actions (the hero + the closing band still offer Download). No hamburger. The wordmark stays
on mobile (nothing else on a phone names the app) and yields only below 360px
(`min-[360px]:inline`), where the pill would otherwise touch the viewport edges. The pill must
always fit the viewport with side gutters — it was the Download button that made the full link
row overflow phones and forced the (since removed) hamburger.

**The logo always lands on the hero (2026-10-30).** In Next a `<Link href="/">` on `/` is a no-op,
and from another page it navigates but keeps the old scroll offset (/faq at 600px landed 600px down
the homepage). So the logo scrolls to top itself on `/` (dropping `#features`) and, from elsewhere,
sets a ref that an effect on `pathname` consumes once `/` renders — logo clicks only, so
Back/Forward still restore their position.

## Typography

- **All text: Open Runde, as letters.app** (owner, 2026-11-09: headings first, then "our font
  treatment doesn't look the same" — letters sets its BODY in Open Runde too). OFL-1.1, licence
  beside the files. `app/fonts/open-runde/` holds LATIN SUBSETS of Regular / Medium / Semibold /
  Bold (~28 KB each; full files are 160 KB each — re-subset with fontTools `pyftsubset
  --layout-features='*'`, keeping ⌘ ⌥ ⇥ and typographic punctuation), loaded by `next/font/local`
  as `--font-open-runde` and set as `--font-sans`. It has no Light weight: never use
  `font-light` (it silently renders Regular). **macOS mocks stay Inter** (SF's stand-in; rounded
  reads un-Mac): `.popover-surface` sets it in CSS, other mock surfaces take `font-ui`. In custom
  CSS reference the next/font variable (`var(--font-inter)`), never a token from `@theme
  inline`, which is not emitted as a CSS variable (the headings silently stayed Inter once).
  The display font (Special Gothic Expanded One) is still loaded but unused; Haskoy was
  trialled and reverted — don't re-suggest it.
- **Type scale tokens (globals.css `@theme`, measured from letters.app — every value matches):**
  `text-section` (section h2: fluid 32→44 px, 1.1, −0.04em, 600; centred ones also `mx-auto
  max-w-132` so they wrap as a balanced two-line block), `text-title` (big-card title 28 px,
  1.2, medium), `text-title-sm` (bento title 22 px medium), `text-lead` (every section and card
  body: 18 px / 1.4 / −0.01em, Regular; a bold lead-in is `font-semibold text-foreground`).
  A 16 px body with titles 2 px smaller was tried and reverted the same day (owner, 2026-11-09).
  **The row of small features** under the big cards: FOUR items (Keyboard, Folders, Grid or
  list, Languages — the obvious ones were cut: login, updates, revert, missing apps), each a
  `text-lead` medium name on its own line + one `text-lead` muted sentence, 36 px icon chip.
  Eight 18 px bold run-ins read "busy" and "shouty"; with four items and the name on its own
  line the full size reads fine (owner, 2026-11-09). Copy: titles keep their voice, slogans
  toned down ~15% — a full flattening to plain nouns went "too far".
  Light-theme `--muted-foreground` is letters' body grey #60606C (oklch 0.493 0.019 285.7,
  6.2:1 on white). Use the token, never restate size/leading/tracking. Card titles carry no
  `max-w-*`: a capped title broke into an awkward two lines in a card wide enough for one. **Never name a text token after a colour token** — `text-card`
  collided with shadcn's `--color-card` and rendered the title in the card's own white.
  **Display headings** (hero h1, closing band, FAQ / Release Notes / legal h1s) use the
  `heading-display` utility — letters' h1 treatment (600, −0.04em) but line-height **1.05**, not
  its 0.9 — and keep their own sizes (owner: "footer and hero are okay"). 0.9 works at letters'
  80 px; at our 48 px the hero's lines overlapped ("apps." descender 1.5 px into "Declutter"'s
  caps, measured with canvas glyph bounds); 1.05 leaves ~6 px (owner, 2026-11-09). The utility
  sets `--tw-leading` as well: `text-5xl` applies its line-height through that variable and
  otherwise wins (it came out 1.0).
- **The homepage has NO eyebrows, hero included** (owner, 2026-11-09: "its not of any use" —
  the "Features / 01"-style labels went, then the hero's requirements line, which the
  `DownloadMeta` line under the Download button already states; don't re-add one). Eyebrows
  survive only on the dark subpage headers (FAQ, Release Notes, Privacy, Terms). Their style: written case, `text-[14px] font-semibold
  tracking-[0.01em] text-white/75` — the tracked all-caps version "screams AI touch", 0.2em
  tracking read "too scattered" in lower case, and 12px was too small. Tracked caps
  (`uppercase tracking-[0.2em]`) remain only on small badges and labels inside components
  (release-timeline "Latest", group headings).
- Section headings were raised to letters.app's 44 px on 2026-11-09 (owner asked for its
  section-heading style; this supersedes the older "stepped down a notch" note). Don't change the
  scale ad hoc — change the token.
- **Closer-look hotspots pulse** (`.hotspot-pulse`, owner 2026-11-09): a copy of the outer ring
  grows to 1.7× and fades over 2.8 s, staggered 0.7 s per marker; off while a card is open and
  under reduced motion.

## Motion

- No animation library: vanilla React + rAF + CSS keyframes, **transform/opacity only — never
  animate `width`/`height`/`left`**. (The Dock Lock pill mis-centred for hours because animated
  `left` stacked with transform-based centering — never combine the two.)
- Entry animations: `cubic-bezier(0.16, 1, 0.3, 1)` over 0.8s (the `.reveal` + `--reveal-delay`
  stagger pattern); snappier curves are reserved for interactions (popover, press).
- **Every animation needs a `prefers-reduced-motion` fallback** — a sensible static resting state,
  not just "off".
- The pre-shadcn Motion-based dock demo is preserved on `feature/dock-motion-build`; don't resurrect it.
- **Never `transition: all`** — name the properties. Icon state swaps (e.g. the Download button's
  ready → downloading → downloaded glyph) keep every glyph mounted and absolutely stacked, and
  cross-fade `scale 0.25→1` / `opacity 0→1` / `blur 4px→0` on `cubic-bezier(0.2, 0, 0, 1)`;
  unmounting the old glyph gives an enter with no exit.

## Shared polish primitives (globals.css)

Two unlayered helpers, used instead of re-deriving them per component:

- **`.pressable`** — `:active { scale: 0.96 }`, and **nothing else**. It deliberately declares no
  `transition`: the rule is *unlayered*, so a `transition` shorthand here **silently beats and
  erases** any `transition-colors`/`transition-transform` utility on the same element (unlayered CSS
  outranks every `@layer`). That bug shipped: the download button's `hover:scale-105` snapped with no
  animation and the Contact-support hover fill never faded. The transition belongs to the call site.
  Press uses the **`scale` property, not `transform`** — Tailwind v4 emits `scale:` for `scale-*`, so
  `transition: transform` doesn't cover it, and `scale` composes with a hover `scale-105`.
- **`.hit-area`** — a pseudo-element that grows a small control to the 40px minimum target with **zero
  layout change** (critical for the nav pill, whose min-content width is a WebKit landmine). It only
  expands vertically and stays inside the control's own horizontal edges, so adjacent targets
  (nav links, the 28px theme-switcher segments, footer links) can never overlap.

**App screenshots are window captures, not framed crops (2026-10-31).** The custom-tiles story shows the
window with its own corners and shadow on transparency (cropped to the alpha bounds, light and dark
to ONE shared box so overlaid marks align) — no frame, no hairline; a box would cage a floating
window. Its "take a closer look" hotspots (`closer-look.tsx`, Apple HomeView pattern) spotlight a
region instead of zooming: the capture is only 2×, so a real zoom softens its text on Retina.
**Encode UI screenshots losslessly and serve them as-is (2026-10-31, owner: "too pixelated")**:
`sharp(...).extract(box).keepIccProfile().webp({ lossless: true })`, the buffer written straight to
disk (re-wrapping it in `sharp(buf).toFile()` silently re-encodes it lossy and drops the profile),
and `<Image unoptimized>` — the optimizer's q75 re-encode blurred the small UI text. Keep the
capture's ICC profile: macOS screenshots are Display P3, and converting to sRGB shifted saturated
colours. Verify by decoding and diffing visible pixels against the PNG (expect 0). ~0.3 MB each. The old `.image-edge` hairline was retired with the last framed screenshot. If a framed one
returns: pure `black/10` / `white/10` outline, never `border-border` — the tinted zinc picks up the
colour beneath it and reads as dirt along the edge.

Headings get `text-wrap: balance` and body copy `text-wrap: pretty` from the base layer — don't
re-apply per component unless overriding.

## CSS / tooling gotchas (each cost real debugging time)

- **An icon set inline in a heading needs `inline-block overflow-hidden`** to centre by
  `vertical-align`: without `overflow`, the box's baseline is synthesised from its content (a
  flex face with an SVG) and the "More than" tile hung 12 px low. With it, the baseline is the
  bottom edge and `align-[(cap/2 − size/2)]` is exact (−0.19em for a 1.1em tile on Open Runde's
  0.727em cap height). Verify with a baseline probe + canvas `actualBoundingBoxAscent`, not by eye.
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