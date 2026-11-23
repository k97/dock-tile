# Dock Tile Website

Marketing site for the Dock Tile macOS app — Next.js 16 (App Router), React 19, Tailwind v4
(CSS-first, no config file), shadcn (new-york/lucide), next-themes. Deployed by Vercel from `main`
at **docktile.app** (docktile.rkarthik.co must stay attached permanently — apps shipped up to
1.8.8 poll it for Sparkle updates; see SEO rule).

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
- Assets load from the R2 CDN in prod (one bucket — never S3), `public/` in dev — route every `/assets/…` ref through `asset()` (`lib/assets.ts`), except the hero wallpapers (`HERO_BG`, same origin); see assets-cdn rule. New/changed files must also be uploaded to R2.
- **Never name a design reference** (a site or app the look was taken from) in code, rules or commit messages — state the value and its reason; see development.md "Never store the name of a reference". That includes a quoted owner remark: a verbatim quote put one in a rule on 2026-11-22 (a diff review caught it) — paraphrase the reason.
- **Another session may push to `main` (an app release) while you work.** `git fetch` before pushing. If the rebase is blocked by untracked files origin now tracks, compare `git hash-object <file>` with `git rev-parse origin/main:<file>`: identical means set them aside and rebase.
- The Agentation toolbar (`components/dev-agentation.tsx`, devDependency) renders only under
  `next dev` and is never fetched in production. Licence: PolyForm Shield (non-compete); keep it a
  dev tool.
- **Vercel builds only when the NEWEST commit of a push touches `website/`** (`vercel.json`
  `ignoreCommand` diffs `HEAD^ HEAD`). Push a website commit with a docs or app commit on top and the
  site never deploys: put the website commit last (2026-11-21).
- **No Prettier here.** There is no config; `npx prettier --write` turned one edit into an
  800-line reformat of `home-sections.tsx` (2026-11-21). Edit by hand; `npm run lint` is the check.
- **The app's `MacOSFloorGuardTests` reads `lib/i18n.ts`, `lib/schema.ts`, `lib/config.ts` and
  `components/hero.tsx`**: after a copy edit each must still state the floor ("for macOS 15+",
  "macOS 15+", "runs on macOS 15"). Website pushes skip app CI, so a break shows up later.
- **A rule edited in the same change as a rename or move goes stale.** On 2026-11-23 a rule cited
  two helpers the same diff had merged away (a diff review caught it). Before pushing, grep every
  symbol a changed rule names.
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
Chrome can't composite `backdrop-filter` (reports `none`). That excuses a missing blur, not an
odd shape: a band beside a popover arrow was written off as headless on 2026-11-23 and was real. What works: the chrome-devtools MCP's
`new_page` with an `isolatedContext`; `<html>` scrolls smoothly, so jump with
`scrollTo({behavior:"instant"})`; flip theme by toggling `.dark` on `<html>`. Script can't
trigger `:hover`: to inspect a hover-only layer, clone its children into a `position:fixed`
overlay at `scale(5)` (page zoom doesn't reach `ScaleToFit` mocks — they rescale themselves). Turbopack hot-reload quirks in dev —
stale `globals.css` (restart `next dev`), and after HMR a `Reveal` scroll-observer can hold a
stale DOM node so a whole section sits at opacity 0. Hard-reload before debugging either as a
code bug.
