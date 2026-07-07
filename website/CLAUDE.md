# Dock Tile Website

Marketing site for the Dock Tile macOS app — Next.js 16 (App Router), React 19, Tailwind v4
(CSS-first, no config file), shadcn (new-york/lucide), next-themes. Deployed by Vercel from `main`.

The website is a satellite of the app; the app is the primary product (docs at the repo root).
**Never edit the macOS app from a website session** — `DockTile/`, `*.swift`, the xcodeproj are
off-limits (reading app source for product truth is fine and encouraged). Cloud design tools
(Superdesign etc.) may only ever upload `website/` code, never app source.

## Commands

```bash
npm run dev      # localhost:3000 (bun dev also works)
npm run lint
npx tsc --noEmit
```

## Non-obvious facts

- `lib/config.ts` (version, download URL) is **CI-written on each release** — don't hand-bump it.
- `lib/releases.ts` is static release data CI does **not** update — add an entry at the top when a version ships.
- All user-facing copy goes through `lib/i18n.ts` (en-AU default) — never hardcode marketing strings.
- Changed a static asset but kept its filename? Bump its `?v=N` query param or caches serve the old file.
- Dead code, imported nowhere: `components/{features,screenshot,support,faq,theme-toggle}.tsx`.

## Rules

- [Design System & Theming](.claude/rules/design-system.md) — tokens, light/dark model, typography, motion, CSS/tooling gotchas
- [Hero & Dock Demo](.claude/rules/hero-dock-demo.md) — wallpaper recipe, demo behaviour contract, app-icon assets, tile glyphs
- [Content, Structure & i18n](.claude/rules/content-i18n.md) — page order, copy rules, locale model, releases page
- [Website Assets](../.claude/rules/website-assets.md) (repo root) — favicon + webp generation, blur placeholders

## Verification

No test suite. After changes:

```bash
npm run lint
npx tsc --noEmit
npm run build
```

Visual checks: never drive the user's own browser — use an isolated Chrome profile; headless
Chrome can't composite `backdrop-filter` (reports `none`). Stale `globals.css` in dev = restart
`next dev` (Turbopack hot-reload quirk), not a code bug.
