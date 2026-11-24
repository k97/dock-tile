import { readFileSync } from "node:fs";
import { join } from "node:path";
import { siteConfig } from "@/lib/config";

/**
 * The newest release's date, from public/appcast.xml (server only, read at build time).
 * CI writes the appcast and lib/config.ts in one commit, so the newest item matches
 * `latestVersion`; if they ever disagree, no date is shown rather than a wrong one.
 * The appcast, not GitHub's API: no network call during the build.
 */
export function latestReleaseDate(): string | undefined {
  try {
    const xml = readFileSync(join(process.cwd(), "public/appcast.xml"), "utf8");
    const item = xml.match(/<item>[\s\S]*?<\/item>/)?.[0] ?? "";
    const version = item.match(/<sparkle:shortVersionString>([^<]+)</)?.[1];
    const date = item.match(/<pubDate>([^<]+)</)?.[1];
    if (version !== siteConfig.latestVersion || !date) return undefined;
    const iso = new Date(date);
    return Number.isNaN(iso.getTime()) ? undefined : iso.toISOString();
  } catch {
    return undefined;
  }
}
