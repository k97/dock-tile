"use client";

import * as React from "react";
import Link from "next/link";
import { useTheme } from "next-themes";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { asset } from "@/lib/assets";
import { trackReleaseNotesClick } from "@/lib/analytics";
import { DockDemo } from "@/components/dock-demo";
import { DownloadActionButton } from "@/components/action-button";

export function Hero() {
  const { content } = useLocale();
  const m = content.marketing;

  // Swap the Ventura dither with the theme: Light in light mode, Dark in dark.
  // Set inline (not via CSS) so it tracks resolvedTheme without a flash. Before
  // mount, resolvedTheme is undefined → default to the light wallpaper.
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);
  const wallpaper =
    mounted && resolvedTheme === "dark"
      ? "/assets/hero-bg-dark.webp"
      : "/assets/hero-bg.webp";

  return (
    <section
      data-nav-tone="dark"
      className="relative mx-3 mt-3 flex min-h-[92vh] flex-col items-center justify-center overflow-hidden rounded-[2.5rem] bg-black px-4 pb-16 pt-28 md:mx-4 md:mt-4"
    >
      {/* Full-bleed macOS wallpaper — Light/Dark Ventura dither by theme */}
      <div
        className="hero-texture"
        style={{ backgroundImage: `url("${asset(wallpaper)}")` }}
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
        <span
          className="reveal mb-3 block text-[12px] font-bold uppercase tracking-[0.2em] text-white/60"
          style={{ "--reveal-delay": "0ms" } as React.CSSProperties}
        >
          {m.heroEyebrow}
        </span>
        <h1
          className="reveal text-4xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl"
          style={{ "--reveal-delay": "80ms" } as React.CSSProperties}
        >
          {m.heroHeadlineA}
          <br />
          <span className="text-white/60 dark:text-white/40">{m.heroHeadlineB}</span>
        </h1>
        <p
          className="reveal mx-auto mt-5 max-w-md text-xl text-white/90"
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
