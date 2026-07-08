"use client";

import * as React from "react";
import { Reveal } from "@/components/reveal";
import { useLocale } from "@/components/locale-provider";
import { localiseText } from "@/lib/i18n";
import type { Release } from "@/lib/releases";

const PAGE_SIZE = 6;

/** Progressive release timeline: shows the latest PAGE_SIZE versions, then
 *  reveals PAGE_SIZE more per "Load more" click. Data is fetched from GitHub
 *  Releases server-side (see `getReleases` in lib/releases). Release copy is
 *  written in AU/GB English; `localiseText` swaps spellings for US visitors
 *  rather than duplicating the dataset. */
export function ReleaseTimeline({ releases }: { releases: Release[] }) {
  const { locale } = useLocale();
  const [visibleCount, setVisibleCount] = React.useState(PAGE_SIZE);
  const visible = releases.slice(0, visibleCount);
  const remaining = releases.length - visibleCount;

  return (
    <div className="relative">
      {/* Vertical line */}
      <div className="absolute bottom-0 left-1.25 top-2 w-px bg-linear-to-b from-white/15 via-white/10 to-transparent" />

      <div className="flex flex-col gap-12">
        {visible.map((release, index) => {
          const isLatest = index === 0;
          return (
            <Reveal
              key={release.version}
              delay={(index % PAGE_SIZE) * 80}
              className="relative pl-10 md:pl-12"
            >
              {/* Timeline node */}
              <span
                className={`absolute left-0 top-7 h-2.75 w-2.75 rounded-full ${
                  isLatest
                    ? "bg-emerald-400 shadow-[0_0_12px_#34D399] ring-4 ring-emerald-400/20"
                    : "bg-white/20"
                }`}
              />

              {/* Glass card */}
              <article
                className={`rounded-3xl border bg-white/5 p-8 backdrop-blur-sm ${
                  isLatest ? "border-emerald-400/20" : "border-white/10"
                }`}
              >
                <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <span className="rounded-full bg-emerald-400 px-3 py-1 text-[11px] font-bold text-emerald-950">
                      v{release.version}
                    </span>
                    {isLatest && (
                      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-400">
                        Latest
                      </span>
                    )}
                  </div>
                  <span className="text-sm tabular-nums text-white/40">
                    {release.date}
                  </span>
                </div>

                <p className="mb-6 text-[15px] font-light leading-relaxed text-white/60">
                  {localiseText(release.intro, locale)}
                </p>

                <div className="flex flex-col gap-6">
                  {release.groups.map((group) => (
                    <section key={group.heading}>
                      <h3 className="mb-3 text-[10px] font-bold uppercase tracking-[0.2em] text-white/80">
                        {localiseText(group.heading, locale)}
                      </h3>
                      <ul className="flex flex-col gap-2.5">
                        {group.items.map((item) => (
                          <li
                            key={item}
                            className="relative pl-5 text-sm font-light leading-relaxed text-white/60"
                          >
                            <span className="absolute left-0 top-2.25 h-1.5 w-1.5 rounded-full bg-emerald-400/40" />
                            {localiseText(item, locale)}
                          </li>
                        ))}
                      </ul>
                    </section>
                  ))}
                </div>
              </article>
            </Reveal>
          );
        })}
      </div>

      {remaining > 0 && (
        <div className="mt-12 flex justify-center">
          <button
            type="button"
            onClick={() => setVisibleCount((count) => count + PAGE_SIZE)}
            className="glass rounded-full px-6 py-2.5 text-[11px] font-bold uppercase tracking-wider text-white/70 transition-colors hover:bg-white/10 hover:text-white"
          >
            Load {Math.min(remaining, PAGE_SIZE)} more{" "}
            <span className="text-white/40">
              · {remaining} older release{remaining === 1 ? "" : "s"}
            </span>
          </button>
        </div>
      )}
    </div>
  );
}
