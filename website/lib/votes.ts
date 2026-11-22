// Feature votes ("I want this" raised hands) — server only.
//
// One counter per feature in Upstash Redis, reached over its REST API with plain
// fetch (no SDK). Every tap counts (owner, 2026-11-22: a visitor may vote as often
// as they like), so a vote is a single INCR and nothing about the visitor is stored.
//
// Connected through the Vercel Marketplace (Upstash), which sets KV_REST_API_URL /
// KV_REST_API_TOKEN; plain UPSTASH_REDIS_REST_URL / _TOKEN work too. Without them
// every call returns null and the banner simply shows no number.

/** The features open for a vote. A route param outside this list is rejected. */
export const VOTE_FEATURES = ["popover-widgets"] as const;
export type VoteFeature = (typeof VOTE_FEATURES)[number];

export function isVoteFeature(value: string): value is VoteFeature {
  return (VOTE_FEATURES as readonly string[]).includes(value);
}

const COUNT_KEY = (f: VoteFeature) => `votes:${f}:count`;

function redisConfig(): { url: string; token: string } | null {
  const url = process.env.KV_REST_API_URL ?? process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.KV_REST_API_TOKEN ?? process.env.UPSTASH_REDIS_REST_TOKEN;
  return url && token ? { url, token } : null;
}

/** Runs one Redis command; null when Redis isn't configured or the call fails. */
async function redis(command: (string | number)[]): Promise<unknown | null> {
  const config = redisConfig();
  if (!config) return null;
  try {
    const res = await fetch(config.url, {
      method: "POST",
      headers: { Authorization: `Bearer ${config.token}`, "Content-Type": "application/json" },
      body: JSON.stringify(command),
      cache: "no-store",
    });
    if (!res.ok) return null;
    const { result } = (await res.json()) as { result?: unknown };
    return result ?? null;
  } catch {
    return null;
  }
}

/** The current count, or null when it can't be read. */
export async function getVotes(feature: VoteFeature): Promise<number | null> {
  // INCRBY 0 reads a missing key as 0, so null means only "unreachable" and a Redis
  // outage hides the number instead of caching a false 0 at the CDN.
  const result = await redis(["INCRBY", COUNT_KEY(feature), 0]);
  return result === null ? null : Number(result);
}

/** Adds one vote and returns the new count, or null. */
export async function castVote(feature: VoteFeature): Promise<number | null> {
  const result = await redis(["INCR", COUNT_KEY(feature)]);
  return result === null ? null : Number(result);
}
