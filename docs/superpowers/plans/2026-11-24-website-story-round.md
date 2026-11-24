# Website story round (2026-11-24)

> **Superseded where it differs (2026-11-24):** what shipped is described in `website/.claude/rules/content-i18n.md` (layout, nav, Chinese pages, heading tiles, privacy copy). This plan is the record of the decision, not the current spec.

Decided with the owner in a grilling session after the product-story audit (Q1–Q8, all "A").
Website only (`website/`, `docs/l10n/website-zh-Hans.md`); no app files. Ships as the SECOND commit,
after the Dock Lock page commit; one `stage-gate --dev` over both; push only on the owner's "push".

## 1. Proof line under Download (Q1)

`DownloadMeta` (components/hero.tsx; hero + Download section, homepage only) becomes two lines:

- Proof: `Version 2.8.1 · Updated 23 Nov · Notarized by Apple · Open source on GitHub`.
  "Updated …" links to `/release-notes` (keeps `trackReleaseNotesClick`), "Open source on GitHub"
  to the repo. No star or download counts.
- Requirements, quieter: `Apple silicon · macOS 15+` (the literal stays in hero.tsx for
  `MacOSFloorGuardTests`).
- Version: `siteConfig.latestVersion` (CI-written). Date: the newest `<pubDate>` in
  `public/appcast.xml`, read at build time in a server helper (`lib/latest-release.ts`, fs) and
  passed as a prop HomePage → Hero / DownloadSection → DownloadMeta. Shown only when the appcast's
  newest `shortVersionString` equals `latestVersion` (CI writes both in one commit), else the date is
  omitted. Formatted per locale (`Intl.DateTimeFormat`, day + short month, UTC).
- Both variants show it (the page variant dropped the version before; Q1 supersedes that).
- New keys: `proofVersion`, `proofUpdated`, `proofNotarized`, `proofOpenSource` (+ zh).

## 2. Homepage order (Q2) and privacy section (Q3)

Hero → Intro → Customise (`CustomTilesStory`) → Set up for you (`PowerUserSection`) → Dock Lock →
**Privacy** → Download → Footer. `HomeFaq` is removed from the homepage and `home-faq.tsx` deleted
(its heading keys stay: /faq's h1 uses them; `homeFaqMore` is reused).

Re-check spacing after the swap (design-system.md: two light sections back to back, second takes no
top padding; `#customise` keeps `scroll-mt-28`). `#features` anchor stays on Intro.

New `PrivacySection` (home-sections.tsx), light, no heading tile:
- Heading "Your Mac. Your data."
- Four points, the intro-points pattern (name line + one muted sentence):
  - No account — download and start; no sign-up, no email.
  - Stays on your Mac — tiles and Smart Add's suggestions are worked out on the Mac and never leave it.
  - Anonymous stats you can switch off — usage stats and crash reports, on by default, off in
    Settings → General ("Share anonymous usage data"). Honest about the default.
  - Accessibility only for Dock Lock — macOS asks only when Dock Lock is turned on.
- Links: "Read the privacy policy" (/privacy, English on both locales) and "See all questions"
  (localePath /faq).
- Smart Add card keeps "Learned on your Mac. Never leaves your device."

## 3. Copy rewrites (Q4), English + zh + review-sheet rows

1. Intro heading → "Fewer icons." ▦ "Same apps."
2. Intro point 1 → "Not a Finder folder" / "A Dock folder shows files. A tile is its own app: it sits
   among your apps and opens them in a panel."
3. Intro point 2 unchanged.
4. Intro point 3 → "Easy to take out" / "Turn off Show in Dock and the tile leaves your Dock. It stays
   in Dock Tile for later."
5. Customise body → "Arrange a tile's apps in the same panel it opens from the Dock. Then pick its
   icon: its own apps, a symbol or an emoji, on colour or a plain background." (US: color)
6. Ghost card title → "Out of Command-Tab."; body names Ghost mode.
7. Details row → Keyboard friendly · In your language only (Folders and Open source cut; open source
   now sits in the proof line).

`schema.ts featureList` reads these keys: re-check it still reads visible copy.

## 4. /faq groups (Q5)

Same page, small group headings, order:
1. Getting started: macOS version · App Store · free · group apps into folders · tile vs Dock folder ·
   create a tile · how many tiles
2. Using tiles: change icon · reorder apps · folders in a tile · Grid vs List · right-click (reworded
   "Why doesn't right-clicking a tile show a menu?", slug unchanged) · sync · back up
3. Dock Lock and displays: stop the Dock moving · what is a Dock tile extension
4. Your Mac and removing it: what it changes · uninstall a tile · uninstall Dock Tile

Slug → group map in faq-content.tsx; labels in i18n (+ zh). Every answer stays in the served HTML
(forceMount), slugs and hash deep links unchanged, FAQPage markup unchanged.

## 5. Motion (Q6)

- Pause every infinite CSS loop while off screen: a `usePauseOffscreen` ref hook sets
  `data-offscreen` on the element (IntersectionObserver, DOM attribute, no React state), and CSS
  `[data-offscreen], [data-offscreen] * { animation-play-state: paused }`. On: `DockLockMock` root,
  `AppSwitcherMock` root, `CloserLook` root (hotspot pulse). The ⌘Tab highlight and its names pause
  together, so they stay in sync.
- No fade-in on body text: remove `Reveal` from intro points, details row, the Dock Lock band's body
  (heading keeps it), Customise body (heading keeps it), Dock Lock page benefits / prose / its FAQ
  items, /faq items. Headings, visuals and cards keep theirs.
- Collapse scene: later round, not this one.

## 6. Heading tiles (Q7)

Homepage keeps `InlineTile` in Intro and Download only; Customise, Set up for you and the Dock Lock
band lose theirs (headings become plain strings; merge the A/B keys where the split only existed for
the tile). Dock Lock page closer and ContactCta keep theirs. Update design-system.md's tile list.

**Reversed on the dev server, same day (owner):** the tiles are the brand's look, so Customise, Set
up for you and the Dock Lock band have them again, as on production, with the A/B keys restored.
Every heading tile now joins its halves with `tileGap(locale)` (no space in Chinese), the fix for
the stray spaces the merged keys had worked around.

## 7. Rules and verification

- Update content-i18n.md (page order, privacy section, FAQ groups, details row), design-system.md
  (heading tiles, motion pause, small-features row), hero-dock-demo.md if it names moved things.
  Grep every symbol the changed rules name.
- `npm run lint`, `npx tsc --noEmit`, `npm run build`, `npm run check:zh`.
- App guard: `MacOSFloorGuardTests` strings ("macOS 15+" in hero.tsx / i18n.ts) still present.
- Dev server :3010, isolated Chrome: `/`, `/zh-Hans`, `/faq`, `/zh-Hans/faq`, `/dock-lock`, light +
  dark, 390 px (no horizontal scroll), loops paused off screen (`data-offscreen`).

## Plan gate (2026-11-24): Needs answers → answered

- "Free" stays beside Download (owner): proof line = `Version 2.8.1 · Updated 23 Nov · Notarized by
  Apple · Free and open source` (the last item links to GitHub).
- Intro point 3 (owner): "Easy to take out" / "Switch off Show in Dock and press Remove. The tile
  leaves your Dock and stays in Dock Tile for later." (the switch alone never touches the Dock).
- Rules: content-i18n.md's "Signed & notarized only on legal pages" becomes "Notarized by Apple in the
  Download proof line only"; record that dropping HomeFaq drops the homepage heading that named
  "group apps into folders" (accepted trade-off; /faq keeps the question).
- Commit split: the Dock Lock work was staged in full before the first edit, so the unstaged diff is
  this round only.
- Details row: `detailIcons` → `[Keyboard, Languages]`, grid `sm:grid-cols-2` only.
- Ghost body: "Ghost mode keeps tiles out of the app switcher (Command-Tab), so it lists only the apps
  you're actually using."
- Date source: the appcast, not `lib/releases.ts` (no network call at build; same CI commit as config).
- Checks added: built HTML contains "Updated 23 Nov" (and 11月23日 on /zh-Hans); built /faq holds 19
  answers and FAQPage `mainEntity` 19; `/faq#is-dock-tile-free` opens; `scrollWidth === clientWidth`
  at 390 px on /, /zh-Hans, /faq, /zh-Hans/faq, /dock-lock; `MacOSFloorGuardTests` run.

## Out of scope (named, not done)

Collapse scene; a Chinese privacy policy; the unused `aurora-*` keyframes in globals.css; Dock Lock
page's own meta line.
