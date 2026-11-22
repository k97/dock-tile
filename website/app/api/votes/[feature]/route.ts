import { castVote, getVotes, isVoteFeature } from "@/lib/votes";

// GET  /api/votes/<feature> → { count } — cached at the CDN for 30 s so reads stay fast.
// POST /api/votes/<feature> → { count } — every tap counts (see lib/votes.ts).

export async function GET(_req: Request, { params }: { params: Promise<{ feature: string }> }) {
  const { feature } = await params;
  if (!isVoteFeature(feature)) return Response.json({ error: "unknown feature" }, { status: 404 });
  return Response.json(
    { count: await getVotes(feature) },
    { headers: { "Cache-Control": "public, s-maxage=30, stale-while-revalidate=300" } },
  );
}

export async function POST(_req: Request, { params }: { params: Promise<{ feature: string }> }) {
  const { feature } = await params;
  if (!isVoteFeature(feature)) return Response.json({ error: "unknown feature" }, { status: 404 });
  return Response.json({ count: await castVote(feature) }, { headers: { "Cache-Control": "no-store" } });
}
