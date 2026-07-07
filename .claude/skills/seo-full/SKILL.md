---
name: seo-full
description: >
  Full SEO + GEO + Fix workflow for web projects. Runs in three sequential phases:
  (1) technical SEO audit — verifiable bugs grouped by severity, including redirect-loop
  and canonical-host integrity checks (static + live redirect-chain trace); (2) GEO review —
  AI citation readiness, schema completeness, entity recognition; (3) implementation —
  applies all findings directly in the codebase with batched commits.
  Use when the user says "SEO audit", "GEO review", "AI search optimisation", "not being
  cited by AI", "fix SEO issues", "improve schema", "technical SEO", "not ranking",
  "redirect loop", "too many redirects", "www vs apex", "canonical host", or
  "apply SEO fixes". Supports scoped runs via flags appended to the invocation:
  --audit (Phase 1 only), --geo (Phase 2 only), --fix (Phase 3 only, requires reports
  in context), --full (all three phases, default).
argument-hint: "[url or project path] [--audit | --geo | --fix | --full]"
---

# /seo-full

Three-phase skill that audits, reviews for AI citation readiness, and then implements
fixes directly in the codebase. Designed for Next.js / TypeScript projects by default;
adapts to the framework and conventions already in the codebase.

---

## Trigger

User runs `/seo-full` or asks for an SEO audit, GEO review, AI search optimisation,
schema improvements, or to apply SEO/GEO fixes from existing reports.

---

## Inputs

Before starting, confirm:

1. **Scope flag** — one of:
   - `--audit` — Phase 1 only (technical SEO, no code changes)
   - `--geo` — Phase 2 only (GEO/AI citation review, no code changes)
   - `--fix` — Phase 3 only (implement fixes from reports already in context)
   - `--full` — all three phases in sequence *(default if no flag given)*

2. **Project path or URL** — local path for source inspection, or live URL for
   production checks. If both are available, prefer source inspection + dev server.

3. **Routes in scope** — default is all routes. User may narrow scope:
   `--routes /,/download,/purchase` restricts to those paths only.

4. **Existing reports** — required only for `--fix`. If reports are attached or
   already in context, proceed. If not, run `--full` instead.

5. **Product marketing context** — check for `.agents/product-marketing.md` or
   `.claude/product-marketing.md`. Read it before asking any clarifying questions;
   only ask for information not already covered.

---

## Phase 1 — Technical SEO Audit (`--audit`)

*Source inspection of metadata, robots, sitemap, structured data, redirects, and
middleware. Primarily source-based — note absence of Search Console / Core Web
Vitals field data in output. The one exception is §1.6: when a live URL is reachable,
trace the real redirect chain — redirect loops and host mismatches are invisible from
source alone because they emerge from the app config and the hosting platform fighting
each other.*

### 1.1 Crawlability & indexation
- `robots.txt` / `robots.ts` — production allows all bots; alpha/staging gated to noindex
- XML sitemap present, accurate, excludes session/thank-you pages
- No accidental noindex on revenue-critical pages
- Googlebot-visible locale URLs (cookie-only i18n means translated content is invisible)

### 1.2 Metadata
- Title tags: unique per page, 50–60 chars, no duplicated brand suffix from template
- Meta descriptions: unique per page, 145–160 chars
- Open Graph + Twitter: per-page blocks with correct `og:url` (not inherited from root layout)
- `alternates.canonical` set on every route
- `metadataBase` configured

### 1.3 Structured data (JSON-LD)
> **Note**: `web_fetch` strips `<script>` tags and cannot detect JS-injected schema.
> Use the browser tool (`document.querySelectorAll('script[type="application/ld+json"]')`),
> Google Rich Results Test, or source inspection of the relevant `page.tsx` files.
> Never report "no schema found" based on a static fetch alone.

- `SoftwareApplication` / `Product` schema: complete (description, url, featureList,
  softwareVersion, downloadUrl, author, publisher, offers)
- `aggregateRating` only present when backed by verifiable on-page review data
- `Organisation` + `WebSite` in root layout
- `FAQPage` on support/FAQ pages
- `BreadcrumbList` on nested routes (e.g. `/support/[slug]`)

### 1.4 On-page
- One `<h1>` per page; logical heading hierarchy
- All images have meaningful `alt` text; decorative images use `alt=""`
- Internal links: no orphan pages (pages in sitemap but unreachable via navigation)
- Legacy URL redirects for any merged or renamed routes

### 1.5 Conversion pages
- Post-purchase / session-specific pages marked `robots: { index: false, follow: true }`
- No double-brand suffix on checkout-adjacent pages

### 1.6 Redirect & canonical-host integrity

> **Why this matters**: the single most common pre-deploy catastrophe is an app-level
> host redirect (www↔apex, http↔https, or trailing-slash) that *fights* a redirect the
> hosting platform already performs. The two ping-pong and produce an infinite loop
> (`ERR_TOO_MANY_REDIRECTS`), taking the whole site down. The rule is: **the app should
> not redirect between hosts the platform manages — leave host canonicalisation to the
> platform.** Confirm which direction the platform already redirects *before* proposing
> or adding any host-level redirect.

**Static — inspect every place host/redirect logic can live:**
- Framework redirects/rewrites: `next.config.{js,ts,mjs}` `redirects()` / `rewrites()`,
  Nuxt `routeRules`, SvelteKit hooks, Astro `redirects`, Remix loaders, Gatsby
  `createRedirect`, Angular/Vue router guards
- Edge / server middleware: `middleware.ts`, `_middleware`, Cloudflare Workers,
  Netlify/Lambda edge functions — any code inspecting `req.headers.host` and issuing
  a 3xx to a different host
- Platform config files: `vercel.json` (`redirects`, `cleanUrls`, `trailingSlash`),
  `netlify.toml` + `_redirects`, `_headers`, `.htaccess` (`RewriteRule`/`RewriteCond`),
  nginx `server`/`return 301`, Cloudflare Redirect Rules / Page Rules, `firebase.json`
  `hosting.redirects`
- The canonical host string used by: `metadataBase`, `<link rel="canonical">`,
  the sitemap (`<loc>` URLs), `robots.txt`/`robots.ts` (`Host:` and `Sitemap:` lines),
  and Open Graph `og:url` / `twitter` URLs

**Flag** any app-level www↔apex, http↔https, or trailing-slash redirect as *High* —
these almost always duplicate a platform redirect and risk a loop. Do not silently
assume the direction; report it as needing confirmation of the platform's behaviour.

**Live — when a URL is reachable, trace the real redirect chain.** Test **both** hosts
(apex and www) **and** a deep path (e.g. `/blog`), not just `/` — loops often only
appear on non-root paths:

```bash
for u in https://apex.example https://www.apex.example https://apex.example/blog; do
  echo "== $u"
  curl -sIL --max-redirs 10 "$u" -o /dev/null \
    -w '%{num_redirects} hops → HTTP %{http_code}  final: %{url_effective}\n'
done
```

- A **loop** shows as curl **exit code 47** / "Maximum (10) redirects followed", with two
  hosts alternating in successive `Location:` headers. Report as *Critical* — the site is
  down. (`curl -sIL "$u"` without `-o /dev/null` prints the raw `Location:` chain so you
  can name the two hosts that ping-pong.)
- A **clean** result is 0–2 hops ending in `HTTP 200`.

**Canonical-host consistency (run even when there is no loop).** After following
redirects, the host you actually land on must *exactly* match the host declared in:
`<link rel="canonical">`, the sitemap `<loc>` URLs, `robots.txt` `Host:`/`Sitemap:`, and
`og:url`. Any disagreement (e.g. canonical says apex but you land on www) splits ranking
signals and is a *High* finding even without a loop. Report the exact surface(s) that
disagree and the one-line fix to align them all to the single host you land on.

### Phase 1 output format

For each finding:
```
File: app/page.tsx:37-41
Severity: High | Medium | Low
Root cause: <one sentence>
Impact: <what breaks in search/social/AI>
Fix: <minimal change, file + line>
Est. time: <5 min | 30 min | product decision>
```

Group by severity. End with a prioritised action plan table:

| # | Finding | Severity | Est. time | Blocker? |
|---|---------|----------|-----------|----------|

---

## Phase 2 — GEO Review (`--geo`)

*Generative Engine Optimisation: being cited by ChatGPT, Perplexity, Gemini, Copilot,
Claude in AI-generated answers. Builds on Phase 1 — run Phase 1 first if any schema
gaps are unresolved.*

### 2.1 Bot access
Confirm `robots.txt` / `robots.ts` allows GEO-relevant bots:
`GPTBot`, `PerplexityBot`, `ClaudeBot`, `GoogleExtended`, `Bingbot`

### 2.2 Schema completeness (highest GEO ROI)
- `SoftwareApplication` / `Product` — all fields wired to live data, not hardcoded
- `Organisation` entity (name, url, logo, sameAs social profiles) in root layout
- `WebSite` with SearchAction in root layout
- `FAQPage` on highest-traffic page — stat-dense answers score highest for citation
- `BreadcrumbList` on guide/doc pages
- `VideoObject` for demo or feature videos (if present)

*Schema type priority order for AI citation (per Princeton GEO research):*
1. `FAQPage` — highest citation yield for Q&A-format AI answers
2. Complete `SoftwareApplication` / `Product` — extractable facts for comparison queries
3. `Organisation` — entity recognition ("who makes X")
4. `BreadcrumbList` — navigation context for guide content

### 2.3 Content opportunities
- **Comparison content** — dedicated page or section answering "X vs Y" and
  "[product] alternative" queries. AI engines are frequently asked these;
  a structured comparison table (features + pricing) is high-citation content.
- **Stat-dense FAQ** — answers containing specific numbers ("under 0.1% CPU",
  "works on macOS 15+") are cited far more often than qualitative answers.
  Surface the strongest FAQ entries on the homepage via `FAQPage` JSON-LD.
- **Social proof linkage** — testimonials page linked from homepage (orphan pages
  are invisible to both crawlers and AI citation engines).

### 2.4 i18n / hreflang (flag as product decision if applicable)
Cookie-only or session-only locale detection means translated content has no
crawlable URL — flagged as a strategic limitation, not a quick fix.
Options (increasing cost): accept as conversion-only → locale subpaths + hreflang →
full URL-based i18n migration.

### Phase 2 output format

Group findings by:
- **Schema gaps** (with specific fields missing and their GEO value)
- **Content opportunities** (with query examples AI engines receive)
- **Architecture decisions** (items requiring product input, not code changes)

---

## Phase 3 — Fix Implementation (`--fix`)

*Applies all findings from Phase 1 and Phase 2 reports. Requires reports in context.*

### Ground rules
- Match the language, framework, and file conventions already in the codebase
- Australian English spelling for all copy and schema description fields
- Locate exact file + line before every edit
- Minimal change per fix — do not refactor surrounding code
- Leave a brief inline comment where the intent is not obvious
- TypeScript throughout — no `any`, infer types from existing patterns in the file
- Dynamic schema fields wired to existing data sources — never hardcoded values
- **Never add a host-level redirect (www↔apex, http↔https, trailing-slash) without first
  confirming which direction the hosting platform already redirects.** The fix for a
  redirect loop is almost always to *remove* the app-level redirect, not add another.
  When a canonical-host mismatch is the finding, align the canonical/sitemap/robots/OG
  strings to the host the site actually lands on — do not change the redirect to match
  the metadata.

### Batch 1 — Bug fixes (commit after this batch)

Work through all **High** and **Medium** severity findings from the SEO audit in
priority order. For each:
1. State the file + line being edited
2. Apply the minimal fix
3. Confirm the fix addresses the root cause in the report

Typical Batch 1 items (adapt to whatever the reports contain):
- Remove fabricated or unverifiable `aggregateRating`
- Fix duplicated brand suffix in title strings on checkout-adjacent pages
- Add per-page `openGraph` + `twitter` metadata blocks to all subpages
  (each block: reuse the page's existing title/description + correct canonical URL)
- Add `alternates: { canonical: "/<path>" }` to every page's metadata export
- Add `robots: { index: false, follow: true }` to session-specific pages
- Link any orphan pages from an appropriate parent section
- Resolve redirect loops by removing the app-level host redirect that fights the platform
  (see ground rule above); align canonical/sitemap/robots/OG to the single landed-on host

### Batch 2 — Schema + GEO (commit after this batch)

Work through all findings from the GEO review in priority order:
1. Complete any existing incomplete schema blocks — wire dynamic fields to live data
2. Add `Organisation` + `WebSite` schema to the root layout
3. Add `FAQPage` JSON-LD to the highest-traffic page — pull the 4–6 strongest
   entries from the support/FAQ content, prioritising stat-dense answers
4. Add `BreadcrumbList` to nested guide/doc pages
5. Add `VideoObject` markup for any demo videos (if present)

### Do not touch (unless explicitly instructed)
- i18n architecture — product decision, flag and skip
- Copy outside of schema description fields
- Any finding the report marks as "needs product input"

### Phase 3 output format

After completing all fixes, output:

```
## Changes summary

### Batch 1 — Bug fixes
- app/page.tsx — removed fabricated aggregateRating block
- app/purchase/page.tsx — title stripped to "Purchase" (template appends brand)
- ... (one line per file changed)

### Batch 2 — Schema + GEO
- app/layout.tsx — added Organisation + WebSite JSON-LD
- app/page.tsx — added FAQPage JSON-LD (6 entries from support FAQ)
- ... (one line per file changed)

## Skipped / needs product decision
- i18n / hreflang — cookie-only locale detection means translated content
  has no crawlable URL. Options documented in Phase 2 report.
- ... (anything else deferred)

## Needs real data before resolving
- aggregateRating — can be re-added once review data from Polar or a review
  widget is wired to the testimonial count/average.
```

---

## Related skills & attribution

This skill consolidates and extends ideas from the open collections below — full credit to
their authors. See the repo README for links.

- `seo-audit` (coreyhaines31/marketingskills) — traditional SEO audit with keyword research
- `ai-seo` (coreyhaines31/marketingskills) — AI search optimisation depth (AEO, GEO, LLMO)
- `schema` (coreyhaines31/marketingskills) — structured data implementation only
- `seo-geo` (ReScienceLab/opc-skills) — combined SEO + GEO review (audit + GEO, no fix phase)
- `cro` (coreyhaines31/marketingskills) — conversion optimisation for landing pages
