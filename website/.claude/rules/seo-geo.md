# SEO, GEO & Domain

## Domain (critical)

- Primary domain is **docktile.app** (trial from 2026-07 for ~a year; may revert to
  docktile.rkarthik.co — the decision point is deliberate, don't "fix" either way).
- `siteConfig.siteUrl` is the single source of truth: metadataBase, canonicals, og:url,
  sitemap, robots and all JSON-LD derive from it — a domain change is a one-line flip + rebuild.
- **Both hosts must serve `/appcast.xml`, forever.** Sparkle's `SUFeedURL` is baked into each app
  build at ship time, so the feed a copy polls is frozen on the day it was built:
  - **≤ 1.8.8** polls `docktile.rkarthik.co/appcast.xml`.
  - **From 2026-08-30 on**, the app-side flip is **done** — `DockTile/Resources/Info.plist` and
    `Scripts/generate-appcast-entry.sh` now say `docktile.app` (both URLs verified 200 that day).
  - So **docktile.rkarthik.co must stay attached in Vercel permanently**, not just for the trial:
    detaching it silently strands every already-shipped copy on its last version, with no error the
    user would ever see. Same in reverse — if the docktile.app trial lapses, the app-side
    `SUFeedURL` has to be flipped back **in a release**, and docktile.app kept attached for the
    builds that shipped with it.
- Machine-read URLs (the appcast) **never carry UTM parameters**; the app's human-facing links
  (About → Website, the studio links) carry `utm_source=docktile-mac`. The **website's** links to
  the studio and its apps go through `withReferral()` (`lib/referral.ts`:
  `utm_source=docktile.app&utm_medium=referral`, the convention happymachines.company uses);
  GitHub, mailto and JSON-LD URLs never carry it.
- **Host redirects belong to Vercel, never next.config/middleware** — an app-level host redirect
  fights the platform's and loops. `www.docktile.app` is a project domain redirecting to the apex
  with **308** (2026-11-23; unattached, Vercel answered 307). Check with the discoverability
  skill's `redirect-trace.sh docktile.app / /faq /appcast.xml`.

## Metadata pattern (every route)

- Every `page.tsx` exports `alternates.canonical` + its own `openGraph`
  (title/description/url/siteName/type).
- **Defining `openGraph` on a page drops the root file-convention og image** — re-add
  `images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }]` explicitly.
- The root `twitter` block is card-type-only **on purpose** — X falls back to each page's
  og:*; re-adding title/description there makes every subpage inherit the homepage's.
- Client pages can't export metadata: split into a server `page.tsx` + `*-content.tsx`
  client component (pattern: `app/faq/`).
- Social card = `app/opengraph-image.jpg` (1200×630) + `.alt.txt`: the live hero (headline, the
  definition line, the Media tile's open panel over the Dock; owner, 2026-11-23 — the old card said
  "DockTile" and "Pin · Group · Launch"). Regenerate from a PRODUCTION build (`next start`; dev
  draws the Next and Agentation badges): a 1200×700 viewport, light theme, the nav pill hidden,
  wait until the showcase has the Media tile's panel open (it walks the tiles in turn; the demo
  cursor on the tile is part of the card), then sharp
  `extract({ left: 16, top: 50, width: 1168, height: 614 }).resize(1200, 630).jpeg({ quality: 85 })`.
  Update `.alt.txt` with it.

## Structured data (`lib/schema.ts` + `components/json-ld.tsx`)

- WebSite (root layout) · SoftwareApplication (homepage) · FAQPage (`/faq`, all Q&As).
  The Chinese test pages (content-i18n.md) carry their own: a Chinese SoftwareApplication
  (`…/zh-Hans#app`, `inLanguage`, `sameAs` the English `…/#app`) on `/zh-Hans`, a Chinese FAQPage on
  `/zh-Hans/faq` only. `/`, `/faq`, `/zh-Hans`, `/zh-Hans/faq` each set `alternates.languages`
  (en, zh-Hans, x-default → English) through `languageAlternates()` in `lib/nav.ts`; keep them
  reciprocal, and add a new Chinese route to the sitemap.
  Every field wires to siteConfig / en-AU i18n (the `/zh-Hans` nodes to the zh content) — never hardcode; `softwareVersion` and
  `downloadUrl` track the CI-written config automatically.
- **No `aggregateRating`** without verifiable on-page review data (rich-results penalty).
  FAQPage stays on the FAQ pages only (`/faq`, `/zh-Hans/faq`) — Google requires the marked-up
  content visible on that page.
- Author/publisher is the **Organization** Happy Machines Company (2026-10-30; was a Person). The
  app's `sameAs` GitHub repo is what disambiguates it from Apple's `NSDockTile` API — keep it.
  Its `@id` is `https://happymachines.company/#organization`, the studio site's own, so engines
  join the two graphs (the logo lives there); the blocks here link by `@id` too.
- **Schema reads the copy the page renders, never a side table (2026-11-23).** `featureList`
  was built from `content.features`, which only dead code rendered (both deleted 2026-11-23), and kept claiming "open them
  all with one click" for weeks after the page dropped it. It now maps the homepage's marketing
  keys; anything schema reads must be visible somewhere on the site.

## Polling production (critical)

- **Poll docktile.app gently: one request per check, 30 s or more apart.** On 2026-11-23 a
  deploy-wait script fetched the homepage plus ~40 JS chunks every 10 s; Vercel's automatic
  mitigation then answered EVERY non-browser client with a 403 challenge
  (`x-vercel-mitigated: challenge`, `retry-after`) for several minutes, crawlers and AI fetchers
  included, though no firewall rule exists. Browsers and `/appcast.xml` stayed fine. Detect a
  deploy by one homepage fetch comparing a string you changed, and run Lighthouse once it is live.

## Reading search data

- GA4 website property **522915118** and Search Console **`sc-domain:docktile.app`** are both
  readable by `ga4-fetch@dock-tile.iam.gserviceaccount.com` (GA4 Editor since 2026-11-23, so it can
  register custom dimensions; Search Console restricted user; the Search Console API is enabled on
  GCP project 465730642539). Token: `gcloud auth print-access-token --account=ga4-fetch@… --scopes=…analytics.readonly,…webmasters.readonly`.
- What the 2026-11-23 read found: ChatGPT sent more sessions than Google; Google clicks are
  branded; "what is a Dock tile extension" (a macOS notification, not this app) had ~370
  impressions and no clicks, hence that FAQ entry. Re-read Search Console before writing an FAQ
  "from real queries". Full baseline: `reports/Website discoverability audit 2026-11.md` (untracked).

## Crawlability (critical)

- FAQ answers must stay in the served HTML: `ui/accordion.tsx` uses `forceMount` +
  `data-[state=closed]:hidden`. AI crawlers (GPTBot/ClaudeBot/PerplexityBot) don't run JS —
  Radix's default unmount made every answer invisible to them. Don't regress.
- `app/robots.ts` (allow-all; `/appcast.xml` disallowed) + `app/sitemap.ts` — new routes
  must be added to the sitemap's route list.
- The client-side locale swap means only en-AU content is crawlable on the English pages (`/zh-Hans*` render Chinese on the server) — deliberate
  (see content-i18n.md), so schema/meta text uses AU spelling.