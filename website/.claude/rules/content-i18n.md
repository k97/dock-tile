# Content, Structure & i18n

## Page structure

- Single-page marketing site (owner, 2026-11-21, after a GA read of the redesign):
  `Hero → IntroSection (id="features") → PowerUserSection → CustomTilesStory (id="customise") → DockLockStory →
  HomeFaq → DownloadSection` + Footer.
  - **IntroSection** (2026-11-22) — "Less Dock. ▦ More multitasking.": what Dock Tile is, before what it
    does. A Before / With Dock Tile pair of fixed-size Docks on the hero wallpaper, re-cropped (150%, 60% 75%) and hue-shifted 200° to blues and purples so it reads as its own scene (owner: no section repeats another's background) (18 apps + the
    Finder/Settings bookends → Finder, the four hero tiles, Settings; `ScaleToFit`), then three short
    points (`introPoints`). Nav "Features" lands here.
  - **PowerUserSection** — "Set up for you. ⚡ Out of your way.": Smart Add · Menu bar · Ghost mode
    cards, light · dark · light (owner, 2026-11-22: the middle card is always the dark one; the menu
    bar card took it; Ghost mode's ⌘Tab HUD sits in the same muted well as Smart Add), then the row of four one-liners (Keyboard, Folders, Free and open source, Languages).
  - **CustomTilesStory** — "Pick your apps. Pick a look. ▦ Done." over the window capture with
    its closer-look hotspots; the body names the "Dock Tile companion app". The hero Dock's
    Configure… walks to `#customise`.
  - **DockLockStory** — its own dark inset band ("The Dock 🔒 stays put.") again, the page's one
    problem-led chapter.
  - **HomeFaq** (2026-11-22) — "Questions, ❓ answered.": five questions from `content.faq` picked
    by slug in `TOP_QUESTIONS` (free, macOS version, App Store, what it changes, uninstall; renaming
    one of those questions drops it, with a dev-console warning), then "See all questions" → /faq.
    Card styles are shared with /faq (`components/faq-card.ts`). No FAQPage JSON-LD here —
    that stays on /faq only (seo-geo.md).
  - **DownloadSection** — "Tidy your ▦ Dock today." + Download + `DownloadMeta variant="page"`,
    on the page background (no wallpaper).
  - Cut on 2026-11-21, in git history: "More than a tile in your Dock" (the interactive tile
    customiser + menu bar big cards — it repeated the features section), the "Built for the
    power user" heading, the closing band's wallpaper and its closing Dock, and an `/option-2`
    preview (problem-led cards). The standalone `/features` route was deliberately deleted —
    nav "Features" scrolls to `/#features`. Don't recreate the page.
- Nav order: **Features · Privacy · FAQ** + Download (Download is `md`+ only — see
  design-system.md "Adaptive nav").
- **The hero has no eyebrow** (owner, 2026-11-09): its requirements live in the line under the
  Download button. That line is `DownloadMeta` (in `hero.tsx`, which MacOSFloorGuardTests reads
  for "macOS 15+"): hero = "v2.7.2 · Free & open source · Apple silicon · macOS 15+"; the Download
  section's `page` variant drops the version and uses the muted tokens.
- **Footer (owner, 2026-11-21, the studio's own footer layout)** — on every page, inside a
  signature-dark inset band like the Dock Lock band (2026-11-22; the theme switcher is white-on-dark): the studio mark +
  "Happy Machines Company" + "Products for the everyday." (the studio site's own line), then three
  columns — **Dock Tile** (Features · What's new · FAQ · Download), **Resources** (GitHub ·
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
  sits beside every Download (`ctaMetaOpenSource` = "Free & open source"). US copy says Trash where
  AU/GB says Bin. Positioning, glossary and words to avoid: `.claude/product-marketing-context.md`.
- "Signed & notarized" claims live only on the legal pages, nowhere else.
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
  **No Next.js locale routing, on purpose.**
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
