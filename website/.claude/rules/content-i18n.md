# Content, Structure & i18n

## Page structure

- Single-page marketing site (owner, 2026-11-21; story round 2026-11-24, plan
  `docs/superpowers/plans/2026-11-24-website-story-round.md`):
  `Hero → IntroSection (id="features") → CustomTilesStory (id="customise") → PowerUserSection → DockLockStory →
  PrivacySection → DownloadSection` + Footer. How a tile is made comes before the conveniences that
  speed it up (owner, 2026-11-24, swapped Customise and Set up for you).
  - **IntroSection** (2026-11-22) — "Fewer icons. ▦ Same apps." (2026-11-24): what Dock Tile is, before what it
    does. A Before / With Dock Tile pair of fixed-size Docks on the hero wallpaper, re-cropped (150%, 60% 75%) and hue-shifted 200° to blues and purples so it reads as its own scene (owner: no section repeats another's background) (18 apps + the
    Finder/Settings bookends → Finder, the four hero tiles, Settings; `ScaleToFit`), then three short
    points (`introPoints`: Not a Finder folder · Looks like it belongs · Easy to take out). Nav
    "Features" lands here. "Easy to take out" names the Remove button: the Show in Dock switch alone
    never touches the Dock (a plan review caught "turn off Show in Dock and it leaves", 2026-11-24).
  - **CustomTilesStory** — "Pick your apps. Pick a look. Done." over the window capture with
    its closer-look hotspots. The hero Dock's Configure… walks to `#customise`.
  - **PowerUserSection** — "Set up for you. Out of your way.": Smart Add · Menu bar · "Out of
    Command-Tab." (Ghost mode, named in its body) cards, light · dark · light (owner, 2026-11-22: the
    middle card is always the dark one; the menu bar card took it; the ⌘Tab HUD sits in the same
    muted well as Smart Add), then the row of two one-liners (Keyboard, Languages; Folders and Free
    and open source cut 2026-11-24, open source now sits in the line under Download).
  - **DockLockStory** — its own dark inset band ("The Dock stays put.") again, the page's one
    problem-led chapter.
  - **PrivacySection** (owner, 2026-11-24, where the homepage FAQ was: FAQ is in the nav) — "Your
    Mac. Your data.": Never asks who you are (not "no personal data": crash reports can hold a file path with the account name, privacy page) · Stays on your Mac · Anonymous stats you can switch off · Accessibility
    only for Dock Lock, each with an icon like the small-feature row (`privacyIcons`, by position), then "Read the privacy policy" (/privacy, English on both locales) and "See
    all questions" (→ /faq in the page's language). **Analytics is ON by default in the app (opt-out,
    General → Share anonymous usage data): the copy says so and must never imply opt-in.** The
    homepage FAQ section (`HomeFaq`) was deleted with it, in git history. Trade-off accepted: no
    homepage heading names "group apps into folders" any more (/faq keeps the question).
  - **DownloadSection** — "Tidy your ▦ Dock today." + Download + `DownloadMeta variant="page"`,
    on the page background (no wallpaper).
  - **DockLockStory → `/dock-lock`** (owner, 2026-11-23): the band's "How Dock Lock works →" pill
    links to the Dock Lock page in the page's language (`localePath`). The band is a TEASER (owner,
    2026-11-24, "it felt like it was repeating"): title, one-line lead + body, the link, the mock.
    The how (Settings path, per-desk memory) lives only on the page; don't add it back here.
  - Cut on 2026-11-21, in git history: "More than a tile in your Dock" (the interactive tile
    customiser + menu bar big cards — it repeated the features section), the "Built for the
    power user" heading, the closing band's wallpaper and its closing Dock, and an `/option-2`
    preview (problem-led cards). The standalone `/features` route was deliberately deleted —
    nav "Features" scrolls to `/#features`. Don't recreate the page.
- **The Dock Lock page** (`/dock-lock` + `/zh-Hans/dock-lock`, `components/dock-lock-page.tsx`; owner,
  2026-11-23, plan `docs/superpowers/plans/2026-11-23-website-dock-lock-page.md`): answers "the Mac
  Dock keeps moving to my other monitor". **Laid out as a guide, never as homepage sections** (owner,
  2026-11-24: it had reused the homepage's icon row, prose blocks and Download closer). A CENTRED dark
  header on the hero's dark wallpaper hue-shifted to teal (like the intro's blue scene, a colour of its
  own; preloaded, it is the page's largest paint) (eyebrow, h1 "Keep the Dock on one display.", the
  one-line answer, Download `location: "dock_lock_page"` + the proof line "Free & open source · No
  account · macOS 15+ · Apple silicon"), never the homepage band's split text + animation layout. Then,
  from lg up, a sticky "On this page" list (follows the scroll) beside four
  sections: Why the Dock moves (the clickable `DockLockMock`), Fix it with Dock Lock (a replica of the
  app's Settings → Dock Lock pane and its Accessibility primer, labels from `dockLockPane` = the app's
  `settings.dockLock.*` strings, pins ①②③ matching the numbered steps), Without an app (a real
  `<table>`, built-in workaround vs Dock Lock, `dockLockPageCompare`, which took the old four benefits'
  points and states both sides' costs), then its own ten questions (accordion; the old "Good to know"
  facts live in their answers). Ends on a teal strip, "Pin your 🔒 Dock today." + the risk-reversal
  line (`dockLockPageClosingNote`) left and Download right, then the footer. Every claim is the app's own
  (`settings.dockLock.*`, dock-lock.md); macOS behaviour only as the app's messages state it. In the nav
  pill, the homepage band and the footer. Keep/drop at the 2027-03-01 review (Search Console
  impressions for Dock-moving queries); dropping it takes it out of the nav too.
- **Subpages read as guides: `GuideLayout`** (`components/guide-layout.tsx`; owner, 2026-11-24, from
  the Dock Lock page): from lg up, a sticky "On this page" list (`marketing.onThisPage`) that follows
  the scroll (a scroll listener: an IntersectionObserver missed jumps); below lg the content follows
  the header. No Download card beside it (owner, 2026-11-25: the floating nav already has Download).
  Used by /dock-lock, /faq (the four groups + Help shape, anchors in `FAQ_GROUP_IDS`, English
  on both locales) and Privacy / Terms through `LegalShell`, whose list is built from the
  `LegalHeading`s passed straight in (a plain-text heading gets a slug id), so it can't drift. Every
  entry's heading carries `scroll-mt-28`. Not on /release-notes (a timeline, not sections).
- Nav order: **Features · Dock Lock · FAQ** + Download (Download is `md`+ only — see
  design-system.md "Adaptive nav"). Dock Lock replaced Privacy on 2026-11-24 (owner: Privacy was
  filler; it stays in the footer's Company column). The pill fits at 320 / 360 / 390 px in both
  languages (Chromium, 14 px a side at 360 in English); not re-measured in WebKit.
- **The hero has no eyebrow** (owner, 2026-11-09): its requirements live in the lines under the
  Download button, `DownloadMeta` (in `hero.tsx`, which MacOSFloorGuardTests reads for "macOS 15+").
  Two lines (owner, 2026-11-24, proof that the app is maintained, never star or download counts):
  "Version 2.8.1 · Updated 23 Nov (→ /release-notes) · Notarized by Apple · Free and open source
  (→ GitHub)", then "Apple silicon · macOS 15+". The date is the newest appcast item's `pubDate`
  (`lib/latest-release.ts`, read at build, passed down from `HomePage`), shown only when that
  item's version equals `siteConfig.latestVersion`; CI writes both in one commit. Both the hero and
  the Download section's `page` variant (muted tokens) show it.
- **Footer (owner, 2026-11-21, the studio's own footer layout)** — on every page, inside a
  signature-dark inset band like the Dock Lock band (2026-11-22; the theme switcher is white-on-dark): the studio mark +
  "Happy Machines Company" + "Products for the everyday." (the studio site's own line), then three
  columns — **Dock Tile** (Features · Dock Lock · What's new · FAQ · Download), **Resources** (GitHub ·
  Request a feature · Report a bug · Contact), **Company** (About · Spades Audio · Privacy ·
  Terms) — then "© YYYY, Made with 🧡 for macOS" (lucide `Heart`, orange fill, accessible name
  "love") + the theme switcher. External links carry ↗ (+ "opens in a new tab" for screen
  readers); the mailto Contact carries ↗ without it. Lango was removed until it has a site.
  The two feedback links open pre-filled GitHub issues from `lib/feedback.ts` — the only source
  of those URLs; the FAQ's "Help shape Dock Tile" cards use the same two. The bug template sends
  diagnostics to the support email, never into the public issue (they list the reporter's
  tiles and apps). Subpages end on `ContactCta` above the footer: since 2026-11-22 it is styled
  like the homepage's Download section (page background, centred `text-section` heading with the
  green chat tile, the page's own line, Contact support + Download), keeping each page's title
  and line ("Questions?", "Still stuck?", "Spotted a bug?"). The site is published
  by **Happy Machines Company** (`siteConfig.authorName` / `authorUrl`; contact
  `hello@happymachines.company`).

## Copy rules

- Every user-facing string goes through `lib/i18n.ts`: `marketingBase` inherited by all locales +
  a US override for spelling-sensitive strings only. Prefer **spelling-neutral copy** — it avoids
  overrides entirely (this drove the hero headline choice).
- **One category, plain words (copy review, 2026-11-21).** Dock Tile is "folders for the Mac's
  Dock" — never a "launcher" or an icon maker — in the title (`siteConfig.tagline`), meta /
  JSON-LD description, hero and FAQ. The hero defines a tile ("Put a group of apps behind one
  Dock icon. Click it and they pop up…"); never claim "one click" to launch (it is two: the tile,
  then the app). Homepage prose says "pops up" / "panel", not "popover"; "a plain background", not
  "Mono"; **Command-Tab** (Apple's spelling), not Cmd-Tab / Cmd+Tab; **Ghost mode** (lower-case m;
  a site-only name — the app's toggle is Show in App Switcher, so always explain it). "Free"
  sits beside every Download (`proofOpenSource` "Free and open source" on the homepage,
  `ctaMetaOpenSource` "Free & open source" on the Dock Lock page; a plan review caught the round
  that would have dropped it from the homepage, 2026-11-24). US copy says Trash where
  AU/GB says Bin. Positioning, glossary and words to avoid: `.claude/product-marketing-context.md`.
- **Download on a device that can't run the app copies the link instead (owner, 2026-11-23)**: ~29%
  of visitors were Windows, iPhone, Android or Linux and got a DMG they could not open.
  `DownloadActionButton` reads "Copy link for your Mac" (nav pill: "Copy link") and copies
  `siteConfig.siteUrl` (no clipboard → shows the address). Decided after mount by the pure
  `isNonMacDevice(userAgent)` (an iPad in desktop mode says "Macintosh" and stays a Mac; any
  `bot|crawl|spider` UA is never non-Mac, because Googlebot's smartphone crawler runs JS with an
  Android UA), so the served HTML and every crawler keep Download. Event `copy_link_click`, same
  `location` values; from 2026-11-23 `download_click` drops by the non-Mac share (a step, not a fall).
- "Notarized by Apple" appears only in the homepage's line under Download (owner, 2026-11-24, as
  proof the app is maintained; every release DMG is notarized by `release.yml`) and on the legal
  pages. Nowhere else.
- **/faq is grouped** (owner, 2026-11-24): Getting started · Using tiles · Dock Lock and displays ·
  Your Mac and removing it, headings from `marketing.faqGroups`, questions by slug in `FAQ_GROUPS`
  (`app/faq/faq-content.tsx`; a question in no group is not shown, with a dev-console warning). One
  accordion across the groups; slugs, hash links and the FAQPage markup (all 19, `content.faq` order)
  are unchanged.
- **Check every product claim against the app source before it ships** (`DockTile/`, read-only).
  On 2026-10-31 three plausible lines were false: "Drag apps in" (the popover only reorders; adding
  is + Add), App Grid "size and weight" (Symbol only), and "the change applies immediately" (the
  Dock changes on Update). Copy describes the current app — re-read it after each app release.
  **A visitor is a NEW install, so describe a new install's defaults** (2026-11-09: "Turn the menu
  bar icon on in Settings" was false — `MenuBarController.initialEnabled` is ON for new installs,
  OFF only for upgraders). Check the default-seeding code, not just the setting's existence.
  **What happens once the app is gone is a claim too** (2026-11-21): the uninstall answer said
  deleting only Dock Tile leaves "?" tiles in the Dock — false, each tile is its own app copy and
  keeps working (architecture.md "Multi-Instance Model"). A diff review caught it before push.
- **Invisible characters in copy (U+00A0 binding "a tile", etc.): check bytes with `od -c`**,
  never `cat -v` or grep output — in a UTF-8 terminal both print U+00A0 as a plain space. On
  2026-11-09 a diff review flagged a real non-breaking space as missing and a `sed` "fix" then
  matched nothing; `od` showed `302 240`, so the guard was there all along.
- **Privacy and Terms were re-verified against the app source on 2026-11-09** — re-check them
  after any release touching analytics/Crashlytics keys, Smart Add, diagnostics, permissions
  (login items, Accessibility), updates or the licence. Found stale that day: Terms forbade
  redistributing/modifying the app though it is MIT; Privacy listed an unused "Automation"
  permission, omitted Smart Add's on-device history (kept even with suggestions off), the
  diagnostics log, Dock Lock's Accessibility access, the daily auto-update check, and the
  website's own Google Analytics cookies.
- The Privacy page is honesty-first about analytics: optional anonymous Firebase Analytics +
  Crashlytics, never sold/shared, opt-out via the app's real toggle ("Share anonymous usage data",
  Settings → General). Never reintroduce "collects nothing" claims.

## Locale model (deliberate — don't "fix")

- `en-AU` (default) / `en-GB` / `en-US`. SSR always renders AU; `locale-provider.tsx` reads
  `navigator.language` after mount and swaps to US content when the browser says so.
  **No Next.js locale routing, on purpose** — with one exception below.
- **Simplified Chinese test (owner, 2026-11-23, issue #43 option B):** `/zh-Hans`,
  `/zh-Hans/faq` and `/zh-Hans/dock-lock` only (`ZH_PAGES` in `lib/nav.ts`), decided by the ROUTE (`localeForPath`; `LocaleProvider` is route-aware, so the
  server renders Chinese), never by the browser (`detectLocale` never returns zh-Hans). Other pages
  stay English. Plan, baseline and keep/drop rule: docs/superpowers/plans/2026-11-23-website-zh-hans-test.md;
  reviews scheduled 2026-12-07 and 2027-03-01.
  - Every string goes through `lib/i18n.ts` (`marketingZh`, the zh FAQ, `zhPageMeta`); names shown in
    the mocks (tile names, Apple apps) go through `useDisplayName()` with the `names` map, data and
    comparisons stay English. Mock UI labels reuse the app's own zh-Hans strings
    (`Localizable.xcstrings`); terms from docs/l10n/GLOSSARY.md.
  - **Changing English copy:** update `docs/l10n/website-zh-Hans.md` (English | Chinese | status)
    and the Chinese in `i18n.ts`; `npm run check:zh` fails when an English string no longer matches
    the sheet. Machine-first, all `needs_review` until a native reviewer passes.
  - FAQ entries carry an explicit `slug` (the old English slugify, kept identical so links survive);
    Chinese questions reuse the English slug.
  - `hero.tsx` keeps the literal `macOS 15+` (MacOSFloorGuardTests); the guard's regexes are English,
    so check macOS versions in Chinese copy by hand.
- Seeing "organized" on an AU Mac is usually NOT a bug — macOS browsers commonly report `en-US`.
- Release notes localise UK→US through the `localiseText()` word-map in `i18n.ts` rather than
  duplicated datasets.

## Releases page

- `lib/releases.ts` `getReleases()` fetches the changelog from **GitHub Releases** server-side
  (ISR, revalidated hourly); the timeline shows 6 entries and loads 6 more per click. **The source
  of truth is each GitHub release's notes — nothing to hand-maintain.** New releases and note edits
  appear automatically; to change what the site shows, edit the release on GitHub. Bodies are parsed
  as a lead paragraph + `### heading` / `- bullet` groups (author them in AU/GB spelling so
  `localiseText` can swap US spellings).
