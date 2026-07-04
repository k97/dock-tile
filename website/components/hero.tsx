"use client";

import * as React from "react";
import Link from "next/link";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackReleaseNotesClick } from "@/lib/analytics";
import { DockDemo } from "@/components/dock-demo";
import { DownloadActionButton } from "@/components/action-button";

export function Hero() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section className="relative mx-3 mt-3 flex min-h-[92vh] flex-col items-center justify-center overflow-hidden rounded-[2.5rem] bg-black px-4 pb-16 pt-28 md:mx-4 md:mt-4">
      {/* Golden Gate aurora — blurred gradient motion behind everything */}
      <div className="aurora" aria-hidden>
        <div className="aurora__blob aurora__blob--orange" />
        <div className="aurora__blob aurora__blob--amber" />
        <div className="aurora__blob aurora__blob--magenta" />
        <div className="aurora__blob aurora__blob--indigo" />
      </div>
      {/* bottom-heavy gradient — dark backgrounds are never flat */}
      <div className="absolute inset-0 bg-linear-to-b from-transparent via-zinc-950/20 to-zinc-950/80" />
      <div className="grain" />
      {/* Headline */}
      <div className="relative z-10 text-center">
        <span
          className="reveal mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-400"
          style={{ "--reveal-delay": "0ms" } as React.CSSProperties}
        >
          {m.heroEyebrow}
        </span>
        <h1
          className="reveal text-5xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-7xl"
          style={{ "--reveal-delay": "80ms" } as React.CSSProperties}
        >
          {m.heroHeadlineA}
          <br />
          {m.heroHeadlineB}
        </h1>
        <p
          className="reveal mx-auto mt-6 max-w-md text-lg font-light text-white/60"
          style={{ "--reveal-delay": "160ms" } as React.CSSProperties}
        >
          {m.heroSub}
        </p>
      </div>

      {/* Popover zone — reserved so the open popover clears the headline */}
      <div
        className="reveal relative z-20 mt-56 flex flex-col items-center md:mt-64"
        style={{ "--reveal-delay": "280ms" } as React.CSSProperties}
      >
        <DockDemo />
      </div>

      {/* Interactive hint */}
      <div
        className="reveal relative z-10 mt-10 flex items-center gap-3 rounded-full glass px-4 py-2"
        style={{ "--reveal-delay": "400ms" } as React.CSSProperties}
      >
        <span className="h-2 w-2 animate-pulse rounded-full bg-emerald-400 shadow-[0_0_8px_#34D399]" />
        <span className="text-xs font-medium uppercase tracking-wide text-white/60">
          {m.tryIt}
        </span>
      </div>

      {/* CTA + meta */}
      <div
        id="hero-cta"
        className="reveal relative z-10 mt-10 flex flex-col items-center gap-5"
        style={{ "--reveal-delay": "500ms" } as React.CSSProperties}
      >
        <DownloadActionButton tone="light" size="lg" label={content.downloadButton} />
        <p className="flex items-center gap-3 text-xs font-medium text-white/40">
          <Link
            href="/release-notes"
            onClick={trackReleaseNotesClick}
            className="underline decoration-white/20 underline-offset-4 transition-colors hover:text-white"
          >
            v{siteConfig.latestVersion}
          </Link>
          <span className="h-1 w-1 rounded-full bg-white/20" />
          <a
            href={siteConfig.githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="transition-colors hover:text-white"
          >
            GitHub
          </a>
          <span className="h-1 w-1 rounded-full bg-white/20" />
          <span>macOS 26+</span>
        </p>
      </div>
    </section>
  );
}
