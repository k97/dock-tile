"use client";

import * as React from "react";
import Link from "next/link";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { HERO_BG, HERO_BG_DARK } from "@/lib/assets";
import { trackReleaseNotesClick } from "@/lib/analytics";
import { DockDemo } from "@/components/dock-demo";
import { DownloadActionButton } from "@/components/action-button";

export function Hero({ released }: { released?: string }) {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section
      data-nav-tone="dark"
      className="relative mx-3 mt-3 flex min-h-[92vh] flex-col items-center justify-center overflow-hidden rounded-[2.5rem] bg-black edge-hairline px-4 pb-16 pt-28 md:mx-4 md:mt-4"
    >
      {/* Full-bleed macOS wallpaper — Light/Dark Ventura dither by theme.
          Both URLs ride as CSS vars; `.dark .hero-texture` picks the dark one,
          so the first frame is already correct (no post-hydration swap). */}
      <div
        className="hero-texture"
        style={
          {
            "--hero-bg": `url("${HERO_BG}")`,
            "--hero-bg-dark": `url("${HERO_BG_DARK}")`,
          } as React.CSSProperties
        }
        aria-hidden
      />
      {/* Bright-to-dark scrim — wallpaper at full brightness up top, ramping
          to a deep dark at the bottom so the CTA/meta read and it settles down */}
      <div className="absolute inset-0 bg-linear-to-b from-transparent from-0% via-black/30 via-55% to-black/95 to-92%" />
      <div className="grain" />
      {/* Headline */}
      <div className="relative z-10 text-center">
        {/* Soft readability blur — lifts the copy off the wallpaper, edges
            feathered by a radial mask so there's no hard boxy edge */}
        <div
          aria-hidden
          className="pointer-events-none absolute -inset-x-8 -inset-y-8 -z-10 rounded-[2.5rem] bg-black/15 backdrop-blur-md mask-[radial-gradient(ellipse_at_center,black_20%,transparent_72%)]"
        />
        <h1
          className="reveal text-4xl heading-display text-white md:text-5xl"
          style={{ "--reveal-delay": "80ms" } as React.CSSProperties}
        >
          {m.heroHeadlineA}
          <br />
          <span className="text-white/60 dark:text-white/40">{m.heroHeadlineB}</span>
        </h1>
        <p
          className="reveal mx-auto mt-5 max-w-md text-xl tracking-[-0.01em] text-white/90"
          style={{ "--reveal-delay": "160ms" } as React.CSSProperties}
        >
          {m.heroSub}
        </p>
      </div>

      {/* Popover zone — reserved so the open popover clears the headline. Extra
          top margin drops the Dock lower, giving the popover room to genie up. */}
      <div
        className="reveal relative z-20 mt-64 flex flex-col items-center md:mt-72"
        style={{ "--reveal-delay": "280ms" } as React.CSSProperties}
      >
        <DockDemo />
      </div>

      {/* CTA + meta */}
      <div
        id="hero-cta"
        className="reveal relative z-10 mt-12 flex flex-col items-center gap-5"
        style={{ "--reveal-delay": "440ms" } as React.CSSProperties}
      >
        <DownloadActionButton tone="light" location="hero" size="lg" label={content.downloadButton} />
        <DownloadMeta released={released} />
      </div>
    </section>
  );
}

/* The lines under a Download button, shared by the hero and the Download section;
   they live here because MacOSFloorGuardTests reads this file for "macOS 15+".
   Proof that the app is maintained: Version · Updated <date> (→ What's new) · Notarized by Apple ·
   Free and open source (→ GitHub); then the requirements, quieter. `released` is the newest
   release's ISO date (lib/latest-release.ts, read at build); without it the date is left out.
   `page`: theme-aware tones on the page background. */
export function DownloadMeta({ variant = "hero", released }: { variant?: "hero" | "page"; released?: string }) {
  const { locale, content } = useLocale();
  const m = content.marketing;
  const page = variant === "page";
  const dot = <span className={`h-1 w-1 rounded-full ${page ? "bg-foreground/20" : "bg-white/20"}`} />;
  const link = `hit-area underline underline-offset-4 transition-colors ${
    page ? "decoration-foreground/20 hover:text-foreground" : "decoration-white/20 hover:text-white"
  }`;
  // UTC: the appcast date is UTC, so a visitor west of it never sees the day before
  const date = released
    ? new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", timeZone: "UTC" }).format(new Date(released))
    : undefined;
  // The Chinese copy puts no space between Chinese and Latin words (the app's style)
  const sp = locale === "zh-Hans" ? "" : " ";
  // wraps (centred) on the narrowest phones
  const row = "flex flex-wrap items-center justify-center gap-x-3 gap-y-1";
  return (
    <div className={`flex flex-col items-center gap-2.5 text-xs font-medium ${page ? "text-muted-foreground" : "text-white/40"}`}>
      <p className={row}>
        <span>
          {m.proofVersion}
          {sp}
          {siteConfig.latestVersion}
        </span>
        {date && (
          <>
            {dot}
            <Link href="/release-notes" onClick={trackReleaseNotesClick} className={link}>
              {m.proofUpdated}
              {sp}
              {date}
            </Link>
          </>
        )}
        {dot}
        <span>{m.proofNotarized}</span>
        {dot}
        <a href={siteConfig.githubUrl} target="_blank" rel="noopener noreferrer" className={link}>
          {m.proofOpenSource}
        </a>
      </p>
      <p className={row}>
        <span>{m.ctaMetaAppleSilicon}</span>
        {dot}
        <span>macOS 15+</span>
      </p>
    </div>
  );
}
