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
  fights the platform's and loops.

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
  Every field wires to siteConfig / en-AU i18n — never hardcode; `softwareVersion` and
  `downloadUrl` track the CI-written config automatically.
- **No `aggregateRating`** without verifiable on-page review data (rich-results penalty).
  FAQPage stays on `/faq` only — Google requires the marked-up content visible on that page.
- Author/publisher is the **Organization** Happy Machines Company (2026-10-30; was a Person). The
  app's `sameAs` GitHub repo is what disambiguates it from Apple's `NSDockTile` API — keep it.

## Crawlability (critical)

- FAQ answers must stay in the served HTML: `ui/accordion.tsx` uses `forceMount` +
  `data-[state=closed]:hidden`. AI crawlers (GPTBot/ClaudeBot/PerplexityBot) don't run JS —
  Radix's default unmount made every answer invisible to them. Don't regress.
- `app/robots.ts` (allow-all; `/appcast.xml` disallowed) + `app/sitemap.ts` — new routes
  must be added to the sitemap's route list.
- The client-side locale swap means only en-AU content is crawlable — deliberate
  (see content-i18n.md), so schema/meta text uses AU spelling.