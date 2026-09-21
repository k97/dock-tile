// Asset delivery — local files in dev, CDN in production (R2, or S3 for bg/).
//
// Every static file under `public/assets/` is mirrored to a CDN and served from
// it in production, keeping the large webp screenshots and the app-icon set off
// the Vercel origin. Local dev serves the very same files from `public/`, so
// iterating never depends on the network (or an upload).
//
// The switch is `NEXT_PUBLIC_IMAGE_SOURCE`:
//   • `local` (set by `npm run dev`)              → base path is "" → resolves to public/
//   • anything else, INCLUDING UNSET (Vercel)     → the CDN URL
// It is a NEXT_PUBLIC_ var so the value inlines into the client bundle at build.
//
// Two CDNs (same pattern as rkarthik-zehn):
//   • S3 `k97static/docktile/` serves the paths listed in S3_PREFIXES. Its keys
//     drop the `/assets` segment: `/assets/bg/hero-bg.webp` →
//     `https://k97static.s3.ap-southeast-2.amazonaws.com/docktile/bg/hero-bg.webp`.
//   • The R2 bucket serves everything else, `public/assets/` mapped to its root:
//     `/assets/app-icons/claude.png` →
//     `https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev/assets/app-icons/claude.png`.

/** Public R2 bucket that mirrors `public/assets/` at its root. */
const R2_BASE_URL = "https://pub-e2f1ef02cb5d42f780dd344d8d5a1816.r2.dev";

/** S3 prefix that mirrors `public/assets/` (minus the `/assets` segment). */
const S3_BASE_URL = "https://k97static.s3.ap-southeast-2.amazonaws.com/docktile";

/** `/assets/…` subtrees served from S3 in production; everything else is R2. */
const S3_PREFIXES = ["/assets/bg/"];

const useLocal = process.env.NEXT_PUBLIC_IMAGE_SOURCE === "local";

/** The R2 root in prod, "" in dev. (S3-served paths don't use this base.) */
export const ASSET_BASE_URL = useLocal ? "" : R2_BASE_URL;

/**
 * Resolve a root-relative asset path (e.g. `/assets/app-icons/claude.png`,
 * optionally with a `?v=N` cache-buster) to a local public URL in dev or its
 * CDN URL (S3 for `S3_PREFIXES`, else R2) in production. Absolute URLs and
 * data URIs pass through unchanged.
 */
export function asset(path: string): string {
  if (/^(?:[a-z]+:)?\/\//i.test(path) || path.startsWith("data:")) return path;
  const rooted = path.startsWith("/") ? path : `/${path}`;
  if (useLocal) return rooted;
  if (S3_PREFIXES.some((prefix) => rooted.startsWith(prefix))) {
    return `${S3_BASE_URL}${rooted.replace(/^\/assets/, "")}`;
  }
  return `${R2_BASE_URL}${rooted}`;
}
