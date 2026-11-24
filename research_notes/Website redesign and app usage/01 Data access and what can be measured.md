# Data access and what can be measured

Pulled 2026-11-21 with the `ga4-fetch` service account, read-only scope (`analytics.readonly`). Scripts and every raw request/response are in `ga-data/` (`q1.json`, `q2.json` = the request bodies; `<name>.json` = request + response; `<name>.tsv` = flat table). The token is not saved there.

## Where the website's GA stream lives: not in 542196919, and not visible to the service account

- `GET analyticsadmin/v1beta/properties/542196919/dataStreams` returns two streams only:
  - `15108725514`, IOS_APP_DATA_STREAM `com.docktile.app` (the macOS app), created 2026-06-18
  - `15225433994`, WEB_DATA_STREAM "dashboard", measurement id `G-HQ9B3CKMKN`, created 2026-07-09 (no site sends to it)
- `GET analyticsadmin/v1beta/accountSummaries` lists account `102059710` with two properties visible to the service account: `542196919` "dock-tile-app" (canEdit) and `526370803` "spades-audio-web".
- `526370803` has one stream, `G-QCKFMP437P` (the Spades Audio site), so the site's `G-PP04F8Z0EP` (`website/lib/analytics.ts`) is not there either.
- **Conclusion:** `G-PP04F8Z0EP` is in a property the service account cannot see: another account, or a property in this account it holds no role on. **No website metric (sessions, homepage views, scroll, `download_click`, source/medium, landing page) could be pulled.** I stopped that branch there, as briefed.

## Website tracking code: no change that would stop events (static read only)

- `website/app/layout.tsx` loads gtag `afterInteractive` and calls `gtag('config', 'G-PP04F8Z0EP')`. The only edits to this file since July are the two font swaps (`93a3295`, `3d778c8`), which change `localFont` and the body class and nothing else (`git show 93a3295 3d778c8 -- website/app/layout.tsx`).
- `website/components/action-button.tsx`: `DownloadActionButton` calls `trackDownloadClick()` (event `download_click`), then navigates to `siteConfig.downloadUrl` (the GitHub DMG). It is used by the hero, header (md+), closing band and `contact-cta` (subpages).
- `website/lib/analytics.ts` is unchanged since July (`git log -- website/lib/analytics.ts`).
- This is not proof that tags fire in production. Only the website property can show that.

## App-side caveats that shape every number

- **Helpers are counted as users.** Every tile is a separate bundle that runs Firebase (`analytics.md`), so each new tile shows up as a new "user", with its own `first_open`. Most of the GA "Active users" headline is helpers: on a typical day about 30 active instances, about 8 of them the main app (`daily_role.tsv`).
- `app_role` (user-scoped) is set in `configure()`, after the automatic `first_open`, so `newUsers` filtered to `app_role = main` is always 0 (`weekly_main_users.tsv`). **The clean install series is `firstSessionDate` with `app_role = main`** (`install_date_main.tsv`). It counts each main-app instance once, on its first-session day. Helpers get the same series under `app_role = helper` (`install_date_helper.tsv`).
- Only Release builds with consent send data. Opted-out users are invisible.
- Property time zone = Australia/Melbourne (in every response's `metadata`), the same zone as the commit timestamps.
- **No data for last year.** `2025-08-01..2025-11-21` returns zero rows (`lastyear.json`), because instrumentation shipped 2026-06-18, so there is no seasonality baseline.
- `firstUserSource/Medium` is `(direct)/(none)` for all 460 new app users (`firstopen_source.tsv`). The app stream carries no acquisition source at all.

## Non-GA signals checked

- GitHub release DMG download counts (`gh api repos/k97/dock-tile/releases`). The appcast enclosure is the same DMG (`website/public/appcast.xml`), so these counts mix Sparkle updates with website downloads. They are cumulative and still growing for old releases. Treat them as a rough cross-check only (see note 02).
- GitHub repo traffic for the last 14 days (`gh api …/traffic/views`, `…/traffic/popular/referrers`) is 0 to 8 views a day, with referrers github.com, Bing and Google at 2 each. The repo is not a meaningful acquisition channel, and its 14-day window cannot reach the Oct 22 start of the surge.
