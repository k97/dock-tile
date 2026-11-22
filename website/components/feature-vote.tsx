"use client";

import * as React from "react";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { trackEvent } from "@/lib/analytics";

const FEATURE = "popover-widgets";

/**
 * A small "I want this" banner with a raised hand for the next feature idea (macOS
 * widgets inside a tile's popover). Every tap counts — a visitor may raise their hand
 * as often as they like (owner, 2026-11-22). Without the counter backend
 * (lib/votes.ts) it still records each tap in GA and hides the number.
 */
export function FeatureVote() {
  const { content } = useLocale();
  const m = content.marketing;
  const [count, setCount] = React.useState<number | null>(null);
  const [taps, setTaps] = React.useState(0);

  React.useEffect(() => {
    fetch(`/api/votes/${FEATURE}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((d: { count: number | null } | null) => setCount(d?.count ?? null))
      .catch(() => {});
  }, []);

  const vote = () => {
    setTaps((t) => t + 1);
    setCount((c) => (c === null ? c : c + 1)); // optimistic
    trackEvent("feature_vote", "engagement", FEATURE);
    fetch(`/api/votes/${FEATURE}`, { method: "POST" })
      .then((r) => (r.ok ? r.json() : null))
      .then((d: { count: number | null } | null) => {
        // Concurrent taps can answer out of order; never let the number go backwards.
        const next = d?.count;
        if (next != null) setCount((c) => Math.max(c ?? 0, next));
      })
      .catch(() => {});
  };

  return (
    <section className="mx-auto max-w-400 px-4 pb-24 sm:px-6 md:px-10 md:pb-50">
      <Reveal className="mx-auto flex max-w-3xl flex-col items-center gap-6 rounded-3xl border border-border bg-card p-6 text-center sm:flex-row sm:text-left md:p-8">
        <div className="flex-1">
          <p className="text-title-sm text-foreground">{m.voteTitle}</p>
          <p className="mt-2 text-lead text-muted-foreground">{taps > 0 ? m.voteThanks : m.voteBody}</p>
        </div>
        <button
          type="button"
          onClick={vote}
          aria-label={m.voteButton}
          className="pressable flex h-13 shrink-0 items-center gap-2.5 rounded-full border border-foreground/15 px-5 transition-[background-color,border-color,scale] duration-200 hover:bg-foreground/5 data-[tapped]:border-orange-500/40 data-[tapped]:bg-orange-500/10"
          data-tapped={taps > 0 ? "" : undefined}
        >
          {/* Re-keyed per tap so the pop replays every time. */}
          <span key={taps} aria-hidden className={`text-[22px] leading-none ${taps > 0 ? "vote-pop" : ""}`}>
            🙋
          </span>
          {/* polite: the new count is read out after a vote without stealing focus */}
          <span aria-live="polite" className={`text-lead font-semibold tabular-nums text-foreground ${count === null ? "hidden" : ""}`}>
            {count ?? ""}
          </span>
        </button>
      </Reveal>
    </section>
  );
}
