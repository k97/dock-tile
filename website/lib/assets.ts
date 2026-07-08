// Asset delivery — local files in dev, Cloudflare R2 CDN in production.
//
// Every static file under `public/assets/` is mirrored to an R2 bucket and
// served from its CDN in production, keeping the large webp screenshots and the
// app-icon set off the Vercel origin. Local dev serves the very same files from
// `public/`, so iterating never depends on the network (or an upload).
//
// The switch is `NEXT_PUBLIC_IMAGE_SOURCE`:
//   • `local` (set by `npm run dev`)              → base path is "" → resolves to public/
//   • anything else, INCLUDING UNSET (Vercel)     → the R2 base URL
// It is a NEXT_PUBLIC_ var so the value inlines into the client bundle at build.
//
// Bucket layout: `public/assets/` maps to the bucket root, so a local
// `/assets/app-icons/claude.png` becomes
// `https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev/assets/app-icons/claude.png`.

/** Public R2 bucket that mirrors `public/assets/` at its root. */
const R2_BASE_URL = "https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev";

export const ASSET_BASE_URL =
  process.env.NEXT_PUBLIC_IMAGE_SOURCE === "local" ? "" : R2_BASE_URL;

/**
 * Resolve a root-relative asset path (e.g. `/assets/app-icons/claude.png`,
 * optionally with a `?v=N` cache-buster) to a local public URL in dev or its
 * R2 URL in production. Absolute URLs and data URIs pass through unchanged.
 */
export function asset(path: string): string {
  if (/^(?:[a-z]+:)?\/\//i.test(path) || path.startsWith("data:")) return path;
  return `${ASSET_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}
