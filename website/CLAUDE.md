# Dock Tile Website

Marketing site for the Dock Tile macOS app — Next.js 16 (App Router), React 19, Tailwind v4
(CSS-first, no config file), shadcn (new-york/lucide), next-themes. Deployed by Vercel from `main`
at **docktile.app** (docktile.rkarthik.co is a redirecting alias that must stay — see SEO rule).

The website is a satellite of the app; the app is the primary product (docs at the repo root).
**Never edit the macOS app from a website session** — `DockTile/`, `*.swift`, the xcodeproj are
off-limits (reading app source for product truth is fine and encouraged). Cloud design tools
(Superdesign etc.) may only ever upload `website/` code, never app source.

## Commands

```bash
npm run dev      # localhost:3010 — local assets (bun dev also works)
npm run dev:r2   # localhost:3010 — assets from the R2 CDN (test the prod path)
npm run lint
npx tsc --noEmit
```

**Dev port is 3010, not 3000** (Cloudflare local-dev is wired to it) — on a port conflict, free 3010, never switch.

## Non-obvious facts

- `lib/config.ts` (version, download URL) is **CI-written on each release** — don't hand-bump it.
- `lib/releases.ts` `getReleases()` fetches the `/release-notes` changelog from **GitHub Releases** (server-side, revalidated hourly) — the source of truth is each GitHub release's notes; there's no static list to maintain. To change what the site shows, edit the release on GitHub.
- All user-facing copy goes through `lib/i18n.ts` (en-AU default) — never hardcode marketing strings.
- Changed a static asset but kept its filename? Bump its `?v=N` query param or caches serve the old file.
- Assets load from an R2 CDN in prod, `public/` in dev — route every `/assets/…` ref through `asset()` (`lib/assets.ts`); see assets-cdn rule. New/changed files must also be uploaded to R2.
- Dead code, imported nowhere: `components/{features,screenshot,support,faq,theme-toggle}.tsx`.

## Rules

- [Design System & Theming](.claude/rules/design-system.md) — tokens, light/dark model, typography, motion, CSS/tooling gotchas
- [Hero & Dock Demo](.claude/rules/hero-dock-demo.md) — wallpaper recipe, demo behaviour contract, app-icon assets, tile glyphs
- [Content, Structure & i18n](.claude/rules/content-i18n.md) — page order, copy rules, locale model, releases page
- [SEO, GEO & Domain](.claude/rules/seo-geo.md) — docktile.app primary + alias rules, per-page metadata/canonical pattern, JSON-LD, crawlability gotchas
- [Assets, CDN & Dev Port](.claude/rules/assets-cdn.md) — `asset()` local/R2 switch, `NEXT_PUBLIC_IMAGE_SOURCE`, remotePatterns, dev port 3010
- [Website Assets](../.claude/rules/website-assets.md) (repo root) — favicon + webp generation, blur placeholders

## Verification

No test suite. After changes:

```bash
npm run lint
npx tsc --noEmit
npm run build
```

Visual checks: never drive the user's own browser — use an isolated Chrome profile; headless
Chrome can't composite `backdrop-filter` (reports `none`). Turbopack hot-reload quirks in dev —
stale `globals.css` (restart `next dev`), and after HMR a `Reveal` scroll-observer can hold a
stale DOM node so a whole section sits at opacity 0. Hard-reload before debugging either as a
code bug.
