# Features / 01 for Dock Tile 2.x

Date: 2026-10-31. Status: copy and layout agreed with the owner (grilling session + mockup
https://claude.ai/artifact/XrCpPCjfrFtjqqXHd8DFfA). Scope: `website/` only.

## Why

The homepage's first feature section ("Customised tiles with the simple editor.") was written on
2026-07-06, before 2.0. Its copy and screenshot show the old full-screen Customise page with a back
button. Since then the app shipped: editing inside the real popover (2.0), Mono backgrounds (2.2),
App Grid tile faces (2.4), Customise as an inspector beside the tile (2.5) and App Grid backgrounds
(2.6). Four FAQ / structured-data answers also describe the old app.

## Decisions (owner)

1. **Story**: the hero gives the goals ("Group your apps. Declutter your Dock."); this section gives
   the steps. Lead = editing in the real popover; support = "make it yours".
2. **Copy (en-AU)**
   - Eyebrow: `Features / 01` (unchanged).
   - Headline: **Pick your apps. Pick a look. Done.**
   - Body: **Arrange them right in the popover your tile opens, so what you see is what you get.
     Then show the tile as a grid of its apps, or give it a symbol or an emoji, in colour or mono.**
   - US override: body only, `colour` → `color`. The headline needs none.
   - Every claim is literal: apps are added with **+ Add** (no drag-in from Finder — the popover's
     drop delegate only reorders, verified in `NativePopoverViews.swift`), the look is picked in
     Customise, and Add to Dock is one press.
3. **Layout**: stacked, Apple-style. Eyebrow, headline, body centred above (max ~720 px text block);
   the screenshot below at content width, max 1200 px.
4. **Marks + labels**: two numbered marks on the screenshot, on region corners (never over content):
   **1 Drag to arrange** (top-right corner of the In This Tile popover), **2 Pick a look** (top-left
   corner of the Customise style cards). The labels sit below the image in the site's caption style
   (12 px bold, uppercase, 0.2em tracking, muted); on phones they stack left-aligned. Marks are
   `aria-hidden`; the labels are an `<ol>`.
5. **Screenshot**: the owner's `docs/v2/docktile-2.x-light.png` / `-dark.png` (2288×1744, transparent
   margin + macOS window shadow). Trimmed to the alpha bounds (shadow kept), converted to webp, saved
   as `public/assets/stage/customise-tile-2x.webp` / `customise-tile-2x-dark.webp` (new names: no
   `?v=` needed, R2 never served them). Dual-rendered `dark:hidden` / `hidden dark:block` lazy
   `next/image`s, as today. The window carries its own corners and shadow, so the old rounded frame
   + `image-edge` hairline go — they would draw a box around a floating window.
6. **Same change, FAQ + JSON-LD** (all three locales; US swaps colour → color only):
   - *Can I change a tile's icon…* → "Yes. Select the tile, then click its icon to open Customise
     Tile beside it. Choose App Grid, Symbol or Emoji, a colour or mono background, and the size and
     weight. Click Update to send the new look to your Dock."
   - *Can I reorder apps within a tile?* → "Yes. In In This Tile, drag an app to a new spot. It's the
     same popover your tile opens, so the order you see is the order you get. Click Update to apply
     it in your Dock."
   - *How do I uninstall a tile?* → "Select the tile, turn off Show Tile, then click Remove from
     Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You
     can also drag the tile out of the Dock like any app."
   - `features[]` "Custom tile icons" (feeds `lib/schema.ts` featureList) → "Show a grid of the
     tile's own apps, an SF Symbol or an emoji, on a colour or mono background. On macOS Tahoe,
     tiles follow the Light, Dark, Clear and Tinted icon styles."
   Before writing them, the planner confirms each against the app source (Customise opens from the
   hero icon; the action button reads Remove from Dock for a hidden pinned tile; Delete Tile is the
   trash button).

## Plan-gate corrections (2026-10-31) — these override decision 6 and pin decisions 4–5

Fresh-reviewer gate: Needs answers → resolved here.

- **Icon FAQ (all locales)**: App Grid has no colour/mono, size or weight (`CustomiseTileView.swift:133,139`),
  and Update only exists for a tile already in the Dock. New text: "Yes. Select the tile and click
  its icon to open Customise Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji
  and its background. If the tile is already in your Dock, click Update to apply the new look."
  en-US: "Customize Tile" (the app's own US string).
- **Reorder FAQ**: "Click Update to apply it in your Dock." → "If the tile is already in your Dock,
  click Update to apply it."
- **`features[]` Custom tile icons**: "Show a grid of the tile's own apps, or an SF Symbol or emoji
  on a colour or mono background. On macOS Tahoe and later, tiles follow the Light, Dark, Clear and
  Tinted icon styles." (en-US: color.)
- **Screenshot geometry**: both PNGs cropped to ONE box (left 9, top 9, 2269×1725 — the union of the
  two alpha bounds) by `sharp` (`extract`, webp q85 / alphaQuality 90), so light and dark align. The
  wrapper is `aspect-[2269/1725]`; marks are % of that box: **1** at (70.7%, 33.7%) — the top-right
  corner of the outer In This Tile canvas; **2** at (73.6%, 11.4%) — the top-left corner of the
  style cards. Marks are fixed 24 px (20 px below `sm`), `aria-hidden`. `sizes` becomes
  `(max-width: 1248px) 100vw, 1200px`.
- **Keys**: delete `tilesCaption` (base + US). New: `tilesAlt` "Dock Tile editing a tile: its
  popover in the middle, Customise Tile on the right." (US: Customize), `tilesMarkArrange` "Drag to
  arrange", `tilesMarkLook` "Pick a look" (base only). The eyebrow keeps its 10 px size, like every
  other section eyebrow on the page.
- **Runnable checks**: in an isolated Chrome (Playwright/WebKit is unavailable in this environment
  — ruling recorded 2026-10-30), at 375/768/1440 in both themes: `document.documentElement.scrollWidth
  <= innerWidth`, and each mark's centre within 2 px of its % of the image box. en-US: emulate the
  locale and read the FAQ answers. R2: `curl -sI` content-length equals the local byte count.
- Accepted: at 375 px the screenshot's text is not legible (the labels carry it); the "create a new
  tile" FAQ stays as is.

## Revision: take a closer look (owner, 2026-10-31) — replaces the static marks + labels

The owner asked what the inert 1/2 did and pitched Apple's HomeView "Take a closer look". Prototyped
B (spotlight) vs C (magnifier); owner chose **B**. `components/closer-look.tsx`:

- Four + hotspots on region corners (never over content) + a matching pill row under the window:
  **In This Tile** · **Style** · **Background** · **Your tile**. Picking one keeps that region at full
  brightness (a pre-clipped copy of the screenshot, faded in), fades the rest of the window to 30% /
  35% dark, pushes in 6% about the region's centre (md+ only) and shows a card beside it (below it on
  phones). ↑/↓ step, Esc / ✕ close and return focus to the pill. Real buttons with `aria-expanded`.
- No real zoom: the screenshot is a 2× capture, so >1.1× softens its text on Retina.
- Transform/opacity only (design rule): the clip is static per region, the push-in is a
  translate+scale (a changing transform-origin would jump), the card moves by `translate`.
- Card copy (en-AU; US swaps "Colour" → "Color" in Background): In This Tile — "Drag apps into order,
  or hover to remove one. It's the same popover your tile opens." · Style — "App Grid shows the
  tile's own apps. Or pick a symbol or an emoji." · Background — "Colour fills the tile. Mono keeps
  it white in Light Mode and black in Dark Mode." · Your tile — "Every change shows on the tile as you
  make it."
- Removed keys: `tilesMarkArrange`, `tilesMarkLook`.
- **Images re-encoded losslessly (owner: "too pixelated")**: the owner re-captured both themes; the
  webp files are now lossless with the PNGs' Display P3 profile kept (0 visible pixels differ from
  the PNG crop) and served `unoptimized`. Light 359,104 B, dark 305,806 B. The crop box is unchanged
  (9, 9, 2269×1725), so the hotspot percentages still hold.

## Out of scope

The other homepage sections, the bento chips, the hero. Retiring the old `customise-tile*.webp`
files (left in place; nothing references them after this change — delete in a follow-up).

## Done when

- `/` shows the new section in both themes at 375, 768, 1440 px; marks land on their corners at
  every width; nothing overflows.
- FAQ page and JSON-LD show the new text; en-US shows "color".
- `npx tsc --noEmit`, `npm run lint`, `npm run build` pass.
- The two webp files are uploaded to R2 at `assets/stage/…` and return 200 at their local byte
  size before the push (owner uploads; agent verifies).
