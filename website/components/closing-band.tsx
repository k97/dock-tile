"use client";

import * as React from "react";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { DownloadActionButton } from "@/components/action-button";
import { ClosingDock } from "@/components/closing-dock";
import { DownloadMeta } from "@/components/hero";
import { asset } from "@/lib/assets";

/**
 * The homepage's ending: the hero's wallpaper again, the closing headline,
 * Download, and the closing Dock. Signature-dark in both themes.
 *
 * The section itself never clips — only the background layers do — so the
 * Studio popover can open near the band's edge without being cut off.
 */
export function ClosingBand() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section
      data-nav-tone="dark"
      className="relative mx-3 mb-3 flex flex-col items-center rounded-[2.5rem] px-4 pb-8 pt-16 text-center md:mx-4 md:mb-4 md:pt-20"
    >
      <div aria-hidden className="absolute inset-0 overflow-hidden rounded-[inherit] bg-black">
        {/* Same Light/Dark Ventura dither as the hero, picked by `.dark` in CSS */}
        <div
          className="hero-texture"
          style={
            {
              "--hero-bg": `url("${asset("/assets/bg/hero-bg.webp")}")`,
              "--hero-bg-dark": `url("${asset("/assets/bg/hero-bg-dark.webp")}")`,
            } as React.CSSProperties
          }
        />
        <div className="absolute inset-0 bg-linear-to-b from-black/10 via-black/55 to-black/95" />
        <div className="grain" />
      </div>

      <Reveal className="relative z-10 flex flex-col items-center">
        <div className="relative">
          {/* The hero's soft readability blur — lifts the headline off the
              bright top of the wallpaper, edges feathered by a radial mask */}
          <div
            aria-hidden
            className="pointer-events-none absolute -inset-x-8 -inset-y-8 -z-10 rounded-[2.5rem] bg-black/15 backdrop-blur-md mask-[radial-gradient(ellipse_at_center,black_20%,transparent_72%)]"
          />
          <h2 className="text-3xl heading-display text-white md:text-5xl">
            {m.closingTitle}
          </h2>
        </div>
        <div className="mt-8 flex flex-col items-center gap-5">
          <DownloadActionButton tone="light" size="lg" label={m.ctaButton} />
          {/* Open source (GitHub) · Apple silicon · macOS floor */}
          <DownloadMeta variant="closing" />
        </div>

        {/* Popover zone — reserved so the Studio popover (opening upward from
            a magnified tile) clears the Download button. Sized from the
            measured popover height; re-measure if the popover grows. */}
        <div className="mt-52 md:mt-60">
          <ClosingDock />
        </div>
      </Reveal>
    </section>
  );
}
