/**
 * Release history for the /release-notes page.
 *
 * The single source of truth is the project's **GitHub Releases** — `getReleases()`
 * fetches and parses them server-side (revalidated hourly), so shipping a release
 * with curated notes is all it takes; there is no static list to maintain here.
 *
 * Release bodies are authored in AU/GB English; `localiseText()` (in the timeline
 * component) swaps spellings for US visitors rather than duplicating the data.
 */

export type ReleaseGroup = {
  heading: string;
  items: string[];
};

export type Release = {
  version: string;
  date: string;
  intro: string;
  groups: ReleaseGroup[];
};

const REPO = "k97/dock-tile";
const RELEASES_API = `https://api.github.com/repos/${REPO}/releases?per_page=100`;

type GitHubRelease = {
  tag_name: string;
  published_at: string;
  body: string | null;
  draft: boolean;
};

const formatDate = (iso: string): string =>
  new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(iso));

/** Parse a release body — a lead paragraph followed by `### heading` / `- bullet`
 *  groups — into the timeline's shape. The `**Full Changelog**` footer, separators,
 *  and any prose under a heading (legacy boilerplate) are dropped so only the
 *  curated notes render. */
function parseBody(body: string): { intro: string; groups: ReleaseGroup[] } {
  const introLines: string[] = [];
  const groups: ReleaseGroup[] = [];
  let current: ReleaseGroup | null = null;

  for (const raw of body.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith("**Full Changelog**") || line.startsWith("---")) continue;

    const heading = line.match(/^#{2,3}\s+(.*)$/);
    if (heading) {
      current = { heading: heading[1].trim(), items: [] };
      groups.push(current);
      continue;
    }

    const bullet = line.match(/^[-*]\s+(.*)$/);
    if (bullet) {
      current?.items.push(bullet[1].trim());
      continue;
    }

    // Lead paragraph → intro; free text under a heading is ignored.
    if (!current) introLines.push(line);
  }

  return {
    intro: introLines.join(" "),
    groups: groups.filter((group) => group.items.length > 0),
  };
}

/** The project's GitHub Releases as timeline data, newest first. Revalidated
 *  hourly; returns [] if GitHub is unreachable so the page still builds/serves. */
export async function getReleases(): Promise<Release[]> {
  try {
    const res = await fetch(RELEASES_API, {
      headers: {
        Accept: "application/vnd.github+json",
        "User-Agent": "docktile-website",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      next: { revalidate: 3600 },
    });
    if (!res.ok) return [];

    const data = (await res.json()) as GitHubRelease[];
    return data
      .filter((release) => !release.draft)
      .map((release) => ({
        version: release.tag_name.replace(/^v/, ""),
        date: formatDate(release.published_at),
        ...parseBody(release.body ?? ""),
      }));
  } catch {
    return [];
  }
}
