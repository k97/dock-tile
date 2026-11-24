# Website discoverability audit (2026-11-23)

Scope agreed in the grilling session: technical SEO, GEO, performance, conversion and copy. Copy and
structure may change; visual style is frozen (visual changes are proposals). Four batches, one commit
each, gated by a fresh reviewer (`stage-gate --dev`), pushed only on the owner's "push".

Baseline commit: `083e274` (live on docktile.app at the start).

## Baseline data

**GA4 (property 522915118, last 28 days):** 116 users, 147 sessions. `download_click` 41 events from
35 users (~30% of users). Channels: Direct 85 · **AI Assistant 25 (all chatgpt.com)** · Organic 23
(Google 19) · Referral 10. 90 days: Direct 312 · AI Assistant 109 · Organic 84. Languages: English 78,
Chinese 19 (16%), French 4, Korean 3, Polish 3. Devices: Mac 78, Windows 20, iOS 10, Linux 4, Android 4.

**Search Console (sc-domain:docktile.app, 2026-08-23 → 11-21):** 75 clicks, 1,936 impressions.
Branded queries carry the clicks ("dock tile" 26 clicks / 186 imp, pos 3.2; "docktile" 9 / 64).
A second cluster of ~370 impressions with **0 clicks** at position ~10: "dock tile extension",
"chatgpt dock tile extension", "what is a dock tile extension mac". It is about macOS's
"Dock Tile Extension Added" notification (an app's Dock tile plug-in), not this app.
Generic category queries ("mac dock folders", "dock organizer") have **no impressions**.
Desktop 72 clicks, mobile 3.

**Lighthouse 13.6, mobile, production, median of 3:** Performance 65 · SEO 100 · Accessibility 100 ·
Best practices 100. LCP **9.6 s** · CLS 0.001 · TBT 24 ms · FCP 1.4 s · page weight 1.99 MB.
LCP element: the hero wallpaper (`div.hero-texture`, 771 KB webp), served from `r2.dev` over
HTTP/1.1 with cache TTL 0; resource load ~4.4 s of the LCP.

## Phase 1 — technical SEO

| # | Finding | Severity | Effort | Status |
|---|---|---|---|---|
| 1 | JSON-LD `featureList` built from unused `content.features`: claims "open them all with one click" (removed from the page on 11-21) | High | 5 min | Fixed, batch 2 |
| 2 | `finder.png` / `settings.png` / `settings-dark.png` downloaded twice (`?v=` keys differ between hero and intro Docks) | Medium | 5 min | Fixed, batch 3 |
| 3 | Hero wallpaper preload lacks `fetchpriority=high` | Medium | 5 min | Fixed, batch 3 |
| 4 | Release notes: versions are not headings (h1 → h3 only) | Medium | 5 min | Fixed, batch 2 |
| 5 | Assets served from `r2.dev`: HTTP/1.1, no cache TTL, rate-limited, Cloudflare says not for production | High | owner, Cloudflare | **Needs owner** |
| 6 | `www.docktile.app` redirects with 307 (temporary), not 308 | Low | owner, Vercel domain setting | **Needs owner** |
| 7 | `docktile.rkarthik.co` serves 200 (full copy) with canonical → docktile.app | Low | — | Accepted: must keep serving the appcast for ≤1.8.8; canonical consolidates |
| 8 | /faq jumps h1 → h3 (Radix accordion headers) | Low | 5 min | Not fixed |
| 9 | Subpage titles 24–26 chars (Release Notes, Privacy, Terms) | Low | 5 min | Not fixed |
| 10 | `/option-2` (cut 11-21) still gets a stray landing; returns 404 | Info | — | Correct as is |

Robots, sitemap, canonicals, OG/meta on all five routes: clean (`audit-meta.mjs`). No missing alt
text (93 images on /). Out of scope: CrUX field data (none at this traffic), backlinks.

## Phase 2 — GEO

Bot access: robots.txt allows all; FAQ answers are in served HTML (forceMount).

**Schema gaps (fixed, batch 2):** WebSite / Organization / SoftwareApplication now joined by `@id`;
the Organization `@id` (`https://happymachines.company/#organization`) matches the studio site's own
graph, which carries the logo. SoftwareApplication gained `isAccessibleForFree` and `license`.
Organization `logo` / `sameAs` warnings remain on this site by design (the studio graph holds them).

**Content opportunities (fixed, batch 2):** four FAQ entries on /faq and in FAQPage JSON-LD:
"What is a Dock tile extension?" (the Search Console cluster), "How do I group apps into folders in
the Mac Dock?", "How is a tile different from a folder in the Dock?", "How do I stop the Dock moving
to my other display?". The last three target queries with no impressions yet.

**Cross-site:** the studio site's own schema names the app "DockTile" (no space) under
"Productivity". The product name has a space and this site says UtilitiesApplication.

**Architecture decisions:** localized crawlable pages, issue #43. Off-site listings, #45. Homebrew
cask, #44.

## Phase 3 — changes

| Batch | Commit | What | Gate |
|---|---|---|---|
| 1 Measurement | `aeb63b2` | `download_click` gains `location` (header / hero / download_section / contact_cta / footer) | Ship, once GA registers `location` |
| 2 SEO / GEO | `a3a2f8b` | 4 FAQ entries, schema fixes, title "iOS-style app folders for your Mac's Dock", release h2s | Trim first → fixed (stale "Add to Dock", unverifiable macOS wording, title) |
| 3 Performance | `730bdc1` | `fetchPriority="high"` on wallpaper preloads; one `?v=` key per icon | Ship |
| 4 Conversion / copy | uncommitted | "Add" button wording (2 places), homepage FAQ leads with the category question, OG card candidate | Owner review on :3010 first |

Verification per batch: `npm run lint`, `npx tsc --noEmit`, `npm run build`; `audit-meta.mjs`
clean on the built homepage; `extract-jsonld.mjs` no errors; `download_click` locations checked at
runtime on 4 of 5 buttons. Not run: Lighthouse "after" (needs the deploy).

## After (production, Lighthouse mobile, median of 3)

| | Baseline | After batches 1–3 | After same-origin wallpaper |
|---|---|---|---|
| Performance | 65 | 66 | 69 |
| LCP | 9.6 s | 8.3 s | 6.6 s |
| CLS | 0.001 | 0.001 | 0.001 |
| TBT | 24 ms | 29 ms | 46 ms |
| Page weight | 1.99 MB | 1.92 MB | 1.89 MB |

Wallpaper live over HTTP/2 with `public, max-age=31536000, immutable`; `www` → 308; new OG card
served with a fresh hash. Batch 4 (`d20a12a`), wallpaper (`bc39220`), rules (`67935c9`) pushed.

## Needs a product decision

- **Wallpaper LCP.** The 771 KB dithered wallpaper is already sized for its display (846 CSS px tall
  on a 3× phone) and does not compress further (AVIF q60 790 KB; lossless 6.5 MB). LCP < 2.5 s on
  Lighthouse mobile is not reachable while it is the LCP image. Options: (a) R2 custom domain with
  long cache headers and HTTP/2/3 (repeat visits, faster transfer; no visual change); (b) a lighter
  first paint (e.g. a small blurred placeholder) with the dither fading in: visual change, needs a
  design look; (c) accept, since buyers are 70%+ desktop Mac.
- **Non-Mac visitors** (Windows 17%, mobile 12%): Download fetches a DMG they cannot open. Option:
  on non-macOS, swap the button for "For Mac: copy the link". New behaviour; not built.
- **OG card.** Current card says "DockTile" (no space) and "Pin · Group · Launch". Candidate from the
  live hero is in the session scratchpad (`og-candidate.jpg`); ships only on a yes.

## Needs real data

- `faq_open` question labels: `event_label` is not a registered GA4 dimension, so which questions
  get opened cannot be read.
- Lighthouse after-run: once batches 1–3 are deployed.
