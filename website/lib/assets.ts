// Asset delivery — local files in dev, the R2 CDN in production.
//
// Every static file under `public/assets/` is mirrored to a CDN and served from
// it in production (except the hero wallpapers, below), keeping the large webp screenshots and the app-icon set off
// the Vercel origin. Local dev serves the very same files from `public/`, so
// iterating never depends on the network (or an upload).
//
// The switch is `NEXT_PUBLIC_IMAGE_SOURCE`:
//   • `local` (set by `npm run dev`)              → base path is "" → resolves to public/
//   • anything else, INCLUDING UNSET (Vercel)     → the CDN URL
// It is a NEXT_PUBLIC_ var so the value inlines into the client bundle at build.
//
// One CDN: the R2 bucket mirrors `public/assets/` at its root —
// `/assets/app-icons/claude.png` →
// `https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev/assets/app-icons/claude.png`.

/** Public R2 bucket that mirrors `public/assets/` at its root. */
const R2_BASE_URL = "https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev";

const useLocal = process.env.NEXT_PUBLIC_IMAGE_SOURCE === "local";

/** The R2 root in prod, "" in dev. */
export const ASSET_BASE_URL = useLocal ? "" : R2_BASE_URL;

// The hero wallpapers are the exception: served by Vercel from this site's own origin (HTTP/2,
// `immutable` for a year via next.config.ts) because they are the homepage's LCP and r2.dev
// sends no cache lifetime (owner, 2026-11-23). Changed the bytes? Bump `?v=`. Every user of the
// wallpaper reads these two, so the preload, the hero, the veil and the intro card stay one fetch.
export const HERO_BG = "/assets/bg/hero-bg.webp?v=1";
export const HERO_BG_DARK = "/assets/bg/hero-bg-dark.webp?v=1";

/**
 * Resolve a root-relative asset path (e.g. `/assets/app-icons/claude.png`,
 * optionally with a `?v=N` cache-buster) to a local public URL in dev or its
 * R2 URL in production. Absolute URLs and data URIs pass through unchanged.
 */
export function asset(path: string): string {
  if (/^(?:[a-z]+:)?\/\//i.test(path) || path.startsWith("data:")) return path;
  const rooted = path.startsWith("/") ? path : `/${path}`;
  return `${ASSET_BASE_URL}${rooted}`;
}
