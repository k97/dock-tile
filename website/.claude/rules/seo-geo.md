# SEO, GEO & Domain

## Domain (critical)

- Primary domain is **docktile.app** (trial from 2026-07 for ~a year; may revert to
  docktile.rkarthik.co — the decision point is deliberate, don't "fix" either way).
- `siteConfig.siteUrl` is the single source of truth: metadataBase, canonicals, og:url,
  sitemap, robots and all JSON-LD derive from it — a domain change is a one-line flip + rebuild.
- **docktile.rkarthik.co must stay attached in Vercel** — shipped apps' Sparkle `SUFeedURL`
  is baked to it (app-side follow-up: Info.plist + `Scripts/generate-appcast-entry.sh` still
  reference it). **Host redirects belong to Vercel, never next.config/middleware** — an
  app-level host redirect fights the platform's and loops.

## Metadata pattern (every route)

- Every `page.tsx` exports `alternates.canonical` + its own `openGraph`
  (title/description/url/siteName/type).
- **Defining `openGraph` on a page drops the root file-convention og image** — re-add
  `images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }]` explicitly.
- The root `twitter` block is card-type-only **on purpose** — X falls back to each page's
  og:*; re-adding title/description there makes every subpage inherit the homepage's.
- Client pages can't export metadata: split into a server `page.tsx` + `*-content.tsx`
  client component (pattern: `app/faq/`).
- Social card = `app/opengraph-image.jpg` (1200×630) + `.alt.txt`. Regenerate:
  `magick public/assets/stage/dock-tiles.webp -crop 2048x1078+0+161 +repage -resize 1200x630^ -gravity center -extent 1200x630 -quality 85 app/opengraph-image.jpg`

## Structured data (`lib/schema.ts` + `components/json-ld.tsx`)

- WebSite (root layout) · SoftwareApplication (homepage) · FAQPage (`/faq`, all Q&As).
  Every field wires to siteConfig / en-AU i18n — never hardcode; `softwareVersion` and
  `downloadUrl` track the CI-written config automatically.
- **No `aggregateRating`** without verifiable on-page review data (rich-results penalty).
  FAQPage stays on `/faq` only — Google requires the marked-up content visible on that page.
- Person publisher + `sameAs` GitHub disambiguates the app from Apple's `NSDockTile` API.

## Crawlability (critical)

- FAQ answers must stay in the served HTML: `ui/accordion.tsx` uses `forceMount` +
  `data-[state=closed]:hidden`. AI crawlers (GPTBot/ClaudeBot/PerplexityBot) don't run JS —
  Radix's default unmount made every answer invisible to them. Don't regress.
- `app/robots.ts` (allow-all; `/appcast.xml` disallowed) + `app/sitemap.ts` — new routes
  must be added to the sitemap's route list.
- The client-side locale swap means only en-AU content is crawlable — deliberate
  (see content-i18n.md), so schema/meta text uses AU spelling.