# Content, Structure & i18n

## Page structure

- Single-page marketing site: `Hero → CustomTilesStory (id="features") → DockLockStory →
  PowerUserSection → FinalCta` + Footer. The standalone `/features` route was deliberately
  deleted — nav "Features" scrolls to `/#features`. Don't recreate the page.
- Nav order: **Features · Privacy · FAQ** + Download (Download is `md`+ only — see
  design-system.md "Adaptive nav").
- `FinalCta` owns the contextual extras: the quiet support "Get in touch" line, version links to
  `/release-notes` (not GitHub), "Open source" linking to the repo, and the Spades Audio
  cross-promo pill (formal voice: "Also available: Spades Audio — per-app volume control").

## Copy rules

- Every user-facing string goes through `lib/i18n.ts`: `marketingBase` inherited by all locales +
  a US override for spelling-sensitive strings only. Prefer **spelling-neutral copy** — it avoids
  overrides entirely (this drove the hero headline choice).
- "Signed & notarized" claims live only on the legal pages, nowhere else.
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
