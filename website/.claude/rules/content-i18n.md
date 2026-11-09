# Content, Structure & i18n

## Page structure

- Single-page marketing site: `Hero → CustomTilesStory (id="features") → DetailsSection →
  PowerUserSection → ClosingBand` + Footer. `DetailsSection` ("More than a tile in your Dock", formerly eyebrowed "Hidden in plain
  sight", 2026-11-09): the two BIGGEST features as big cards
  (an interactive tile customiser, the menu bar), then a row of one-line features (Grid or list
  is one) — each claim checked against the app. The power-user bento then holds Smart Add ·
  Dock Lock · Ghost mode (owner picked this combo 2026-11-09 over Smart Add + menu bar as the
  big two). Dock Lock was its own dark full-width section until 2026-11-09, when the owner
  moved it into the bento in place of the right-click card ("Hide or quit, right from the
  tile"), which was cut — it is in git history. The standalone `/features` route was deliberately
  deleted — nav "Features" scrolls to `/#features`. Don't recreate the page.
- Nav order: **Features · Privacy · FAQ** + Download (Download is `md`+ only — see
  design-system.md "Adaptive nav").
- **The hero has no eyebrow** (owner, 2026-11-09): its requirements live in the line under the
  Download button. That line is `DownloadMeta` (in `hero.tsx`, which MacOSFloorGuardTests reads
  for "macOS 15+"): hero = "v2.7.1 · Open source · Apple silicon · macOS 15+"; closing band = "Open source ·
  Apple silicon · macOS 15+" (no version, owner) at 75% white — the hero's 40% vanished on the
  wallpaper's bright middle.
- **The ending says each thing once (owner, 2026-10-30).** `ClosingBand` = "All your apps. One
  tile." + Download (+ its `DownloadMeta` line) + the closing Dock (GitHub · What's new · Contact | Studio — see
  hero-dock-demo.md "Closing Dock"); the shared `Footer` is one line: © Happy Machines Company ·
  theme switcher · **Request a feature · Report a bug** | Privacy · Terms. The two feedback
  links (owner, 2026-11-09: "encourage users to request features or raise a bug") open
  pre-filled GitHub issues from `lib/feedback.ts` — the only source of those URLs; the FAQ's
  "Help shape Dock Tile" cards use the same two. The bug template sends diagnostics to the
  support email, never into the public issue (they list the reporter's tiles and apps). Four
  footer layouts were rejected for repeating links "for the sake of filling up spaces" — don't
  add link columns, taglines or a second Spades mention. Spades Audio and Lango appear only in the Studio popover. Subpages keep their
  `ContactCta` band above the same legal line. The site is published by **Happy Machines
  Company** (`siteConfig.authorName` / `authorUrl`; contact `hello@happymachines.company`).

## Copy rules

- Every user-facing string goes through `lib/i18n.ts`: `marketingBase` inherited by all locales +
  a US override for spelling-sensitive strings only. Prefer **spelling-neutral copy** — it avoids
  overrides entirely (this drove the hero headline choice).
- "Signed & notarized" claims live only on the legal pages, nowhere else.
- **Check every product claim against the app source before it ships** (`DockTile/`, read-only).
  On 2026-10-31 three plausible lines were false: "Drag apps in" (the popover only reorders; adding
  is + Add), App Grid "size and weight" (Symbol only), and "the change applies immediately" (the
  Dock changes on Update). Copy describes the current app — re-read it after each app release.
  **A visitor is a NEW install, so describe a new install's defaults** (2026-11-09: "Turn the menu
  bar icon on in Settings" was false — `MenuBarController.initialEnabled` is ON for new installs,
  OFF only for upgraders). Check the default-seeding code, not just the setting's existence.
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
