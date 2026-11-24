# Website: a Dock Lock page (`/dock-lock`)

> **Superseded where it differs (2026-11-24):** what shipped is described in `website/.claude/rules/content-i18n.md` (layout, nav, Chinese pages, heading tiles, privacy copy). This plan is the record of the decision, not the current spec.

Owner decision 2026-11-23 ("build the Dock Lock page"), from the discoverability pass's Q7 option B:
a page that answers "the Mac Dock keeps moving to my other monitor" and offers Dock Lock as the fix.

## Owner answers to the plan gate (2026-11-23) — these override the sections below

1. **Translate it too:** `/dock-lock` (English) AND `/zh-Hans/dock-lock` (Chinese, machine-first like
   the zh test). Strings go in `marketingBase` + `marketingZh` (so `satisfies` and `check:zh` cover
   them) with rows in `docs/l10n/website-zh-Hans.md`. The band link and footer link appear on both
   languages and point at the same-language page (`localePath`). `hreflang` en / zh-Hans / x-default
   on both Dock Lock pages; both in the sitemap.
2. **FAQ:** three questions on the page only, worded distinctly from the `/faq` entry ("Can I keep
   the Dock on one screen without an app?", "Does it work with a Dock on the left or right?", "Is
   Dock Lock free?"), with their own FAQPage markup (per language). The `/faq` "stop the Dock
   moving" entry stays the single marked-up instance of that question. Rule text: FAQPage on the FAQ
   pages and the Dock Lock pages, each marking up only Q&As visible there and not repeated elsewhere;
   FAQ rich results only show for gov/health sites since 2023, so the markup is for AI answer engines.
   The FAQ's "stop the Dock moving" answer does NOT get a link (answers render as plain text).
3. **Title:** "Stop the Mac Dock jumping to your other monitor" (H1 stays "Keep the Dock on one
   display."); Chinese equivalent in `zhPageMeta`.
4. **Keep/drop (2027-03-01 review):** keep if Search Console shows impressions for Dock-moving
   queries on `/dock-lock` (or `/zh-Hans/dock-lock`); if none, fold it back into the FAQ and remove the
   page. Downloads from the page are reported, not the bar. After deploy: request indexing of both
   URLs in Search Console (owner, one click each).

**Gate fixes (accepted):** "Why" no longer says "no built-in setting" — it says there is no setting to
choose WHICH display gets the Dock while each display has its own Spaces. "Good to know" adds Dock
Lock's own costs from the app: it reserves a few pixels at that edge on your other displays
(`settings.dockLock.note`), does nothing with a single display, and Dock Tile must stay running for
the lock to hold. The "main display = the one with the menu bar in Displays → Arrange" claim is
dropped unless verified on a Mac. The meta line under the hero Download reads "Free, comes with Dock
Tile". `DockLockMock` moves out of `home-sections.tsx` into its own component file (like
`InlineTile`) so the page doesn't pull the homepage module. Measurement scripts are at
`~/.claude/skills/discoverability/scripts/`.

## Why a page (not only the FAQ entry)

The homepage is about tiles, so it cannot rank or be cited for the Dock-moving problem; the FAQ entry
added on 2026-11-23 answers it in one paragraph. Search Console shows no impressions for the problem
today (the site does not rank for it), so this is a bet. Measure it like the Chinese test: GA4 users
and `download_click` with `location = "dock_lock_page"` on `/dock-lock`, Search Console queries for
the page, read at the 2026-12-07 review (indexing only) and the 2027-03-01 review.

## Page (English only; spelling-neutral; every string in `lib/i18n.ts`)

1. **Hero (dark band, like the homepage's Dock Lock band):** eyebrow "Dock Lock", h1 "Keep the Dock
   on one display.", one-line answer ("On a Mac with more than one display, the Dock jumps to whichever
   screen you push the pointer against. Dock Lock keeps it on the display you choose."), Download
   (`location: "dock_lock_page"`) + `DownloadMeta` ("Free & open source"), and the existing
   two-display `DockLockMock` animation reused as the visual.
2. **Why the Dock moves** (answer first, 2–3 sentences): with "Displays have separate Spaces" on,
   macOS moves the Dock to a display when you push the pointer to that display's bottom (or side) edge;
   there is no built-in setting to pin it.
3. **Fix it with Dock Lock** — three steps (Settings → Dock Lock → turn on Lock Dock to one display;
   allow Accessibility when macOS asks; pick a display under Keep Dock on), then "remembers a display
   for each set of screens you use".
4. **Without an app** (honest alternative, the citable part): turn off "Displays have separate
   Spaces" (System Settings → Desktop & Dock, then log out) and macOS keeps the Dock on the main
   display only, at the cost of Spaces per display; the main display is the one with the menu bar in
   Displays → Arrange.
5. **Good to know:** Dock Lock needs "Displays have separate Spaces" on to move the Dock to a display
   that isn't the main one; macOS can't put the Dock on a display whose Dock edge is fully covered by
   another display (e.g. two equal displays stacked) — shift one in Displays → Arrange; Dock Lock
   asks for Accessibility only when you turn it on; it comes free with Dock Tile.
6. **Short FAQ (3–4):** "Why does my Dock keep moving to my other monitor?", "Can I keep the Dock on
   one screen without an app?", "Does Dock Lock work with a side Dock?" (left/right: yes, it reads the
   Dock's orientation), "Is Dock Lock free?". Rendered with the site's FAQ card style; FAQPage JSON-LD
   on this page too (rule change: "FAQ pages only" becomes "/faq, /zh-Hans/faq and /dock-lock", each
   showing its marked-up Q&As).
7. **Closing CTA:** the existing `ContactCta`-style Download section ("Tidy your Dock today" is
   tile-specific — use a Dock Lock line, e.g. "Pin your Dock today.").

Every product claim checked against the app (AppStrings.swift `settings.dockLock.*`,
`.claude/rules/dock-lock.md`); macOS behaviour claims limited to what the app's own messages state.

## Wiring

- `app/dock-lock/page.tsx` (server, metadata: title "Keep the Mac Dock on one display — Dock Lock",
  description, canonical, openGraph with the explicit og image, `alternates.languages` not needed —
  English only), sitemap entry, SoftwareApplication is NOT repeated (one app node, on `/`); the page's
  FAQPage only.
- Links in: the homepage Dock Lock band gets a "How Dock Lock works →" link; the FAQ's Dock-moving
  answer links to the page; footer "Dock Tile" column gets "Dock Lock". Not in the nav pill (WebKit
  width risk, design-system.md).
- `DownloadLocation` gains `"dock_lock_page"` (registered `location` dimension covers it).
- Chinese: none (out of the zh test's scope); the zh pages don't link to it.

## Checks

lint, tsc, build, `check:zh` (English strings added to `marketingBase` need no zh row unless shown on
zh pages — confirm the check's key set; add rows only if required); `audit-meta.mjs` +
`extract-jsonld.mjs` on the built `/dock-lock`; 390 px scrollWidth; no hydration errors; English
homepage text unchanged except the new link; owner looks on the dev server before commit; fresh
`stage-gate --dev`; push on "push".
