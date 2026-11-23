# Assets, CDN & Dev Port

## Asset delivery (local dev vs CDN in prod)

Static files under `public/assets/` are mirrored to **one** CDN — a **Cloudflare R2 bucket** —
and served from there in production; local dev serves the same files from `public/`. The switch
is the pure seam `lib/assets.ts`:

- `asset(path)` maps a root-relative `/assets/...` path (optionally with a `?v=N` cache-buster) to
  a local URL in dev or its CDN URL in prod. Absolute URLs / `data:` URIs pass through untouched.
- Gate: `NEXT_PUBLIC_IMAGE_SOURCE`. `local` → base `""` (public/). Anything else **including unset
  (how Vercel builds run)** → the CDN base URL. It's `NEXT_PUBLIC_` so the value inlines client-side.
- **R2 bucket layout = root** (the bucket is shared with the portfolio, whose videos sit at root
  too): `public/assets/foo.png` → `https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev/assets/foo.png`.

**Always route new asset references through `asset("/assets/…")`** — never hardcode a bare
`/assets/...` into an `<Image>`/`url()` again, or it won't switch to R2 in prod. Keep the
root-relative path in the data arrays; wrap it at the render site (`src={asset(app.src)}`).

- **Files stay in `public/assets/` regardless** — dev needs them, and same-origin URLs
  (`lib/schema.ts` JSON-LD `screenshot`, `app/opengraph-image.jpg`, favicons) must remain crawlable;
  those deliberately do **not** go through `asset()`.
- `next.config.ts` whitelists the R2 host in `images.remotePatterns` (required for optimized
  `<Image>` from R2). Remote **SVGs** go through `<Image … unoptimized>` (the two brand SVGs) to
  skip the optimizer's SVG policy.
- **Adding/changing an asset**: drop it in `public/assets/`, then upload the file to the R2 bucket
  at the matching key (e.g. `assets/…`) or prod 404s. Kept a filename but changed the bytes? Bump
  its `?v=N` (R2 caches hard).
- **One exception: the two hero wallpapers come from this site's own origin** (owner, 2026-11-23),
  as `HERO_BG` / `HERO_BG_DARK` in `lib/assets.ts`, never through `asset()`. They are the
  homepage's LCP image (771 KB), and r2.dev serves them over HTTP/1.1 with no cache lifetime
  (Lighthouse mobile LCP 9.6 s); Vercel serves HTTP/2, and `next.config.ts` gives `/assets/bg/*` a
  one-year `immutable` Cache-Control, so **changed bytes need a `?v=` bump** there. An R2 custom
  domain would have needed docktile.app's DNS moved to Cloudflare (it is on Vercel's). The R2
  copies of `bg/` are now unused. Every other asset stays on R2.
- **R2 only — never split assets across buckets again** (owner, 2026-10-31: "let's load it from
  one place"). The hero wallpapers sat in S3 (`k97static/docktile/bg/`, 2026-09-21 → 10-31) and
  the next upload went to the wrong bucket. Before calling an upload done, fetch each CDN URL and
  compare its byte size with the local file: on 2026-10-30 the studio icons were believed
  uploaded and every one 404'd.

## Dev port is 3010 (not 3000) — do not change

`npm run dev` / `dev:r2` and `npm start` all bind **:3010**. Cloudflare's local-dev testing is
configured for that exact port, so whenever a port conflict or "which port?" comes up, the answer
is **3010** — free the port, don't switch to another. (`dev` = local assets; `dev:r2` = exercise
the R2 path locally before shipping.)
