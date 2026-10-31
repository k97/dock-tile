# Content, Structure & i18n

## Page structure

- Single-page marketing site: `Hero → CustomTilesStory (id="features") → DockLockStory →
  PowerUserSection → ClosingBand` + Footer. The standalone `/features` route was deliberately
  deleted — nav "Features" scrolls to `/#features`. Don't recreate the page.
- Nav order: **Features · Privacy · FAQ** + Download (Download is `md`+ only — see
  design-system.md "Adaptive nav").
- **The ending says each thing once (owner, 2026-10-30).** `ClosingBand` = "All your apps. One
  tile." + Download + the closing Dock (GitHub · What's new · Contact | Studio — see
  hero-dock-demo.md "Closing Dock"); the shared `Footer` is only the legal line (© Happy Machines
  Company · Privacy · Terms + theme switcher). Four footer layouts were rejected for repeating
  links "for the sake of filling up spaces" — don't add link columns, taglines or a second
  Spades mention. Spades Audio and Lango appear only in the Studio popover. Subpages keep their
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
