"use client";

import { Clock, Ghost, Lock, ShieldCheck } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackContactClick, trackReleaseNotesClick } from "@/lib/analytics";
import { Reveal } from "@/components/reveal";
import { DownloadActionButton } from "@/components/action-button";
import { TileGlyph } from "@/components/tile-glyph";

/* ------------------------------------------------------------------ */
/* Custom tiles — light story (the "Features" anchor target)           */
/* ------------------------------------------------------------------ */

export function CustomTilesStory() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section
      id="features"
      className="mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32"
    >
      <Reveal>
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-zinc-400">
          {m.tilesEyebrow}
        </span>
        <h2 className="mb-6 text-3xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-4xl">
          {m.tilesTitle}
        </h2>
        <p className="max-w-lg text-lg font-light leading-relaxed text-zinc-500">
          {m.tilesBody}
        </p>
      </Reveal>
      <Reveal delay={120}>
        <div className="relative mx-auto aspect-square w-full max-w-md md:max-w-none">
          <Image
            src="/assets/stage/customise-tile.webp"
            alt={m.tilesCaption}
            fill
            sizes="(max-width: 768px) 100vw, 640px"
            className="object-contain drop-shadow-xl"
          />
        </div>
        <p className="mt-6 text-center text-[11px] font-medium uppercase tracking-wider text-zinc-400">
          {m.tilesCaption}
        </p>
      </Reveal>
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Built for the power user — Grid/List + Smart Add + Ghost, one bento */
/* ------------------------------------------------------------------ */

export function PowerUserSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section className="mx-auto max-w-400 px-6 py-24 md:px-10 md:py-32">
      <Reveal className="mb-14 text-center">
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-zinc-400">
          {m.powerUserEyebrow}
        </span>
        <h2 className="text-2xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-3xl">
          {m.bentoTitle}
        </h2>
      </Reveal>

      <div className="grid gap-6 md:grid-cols-3">
        {/* Grid or List — white card */}
        <Reveal className="flex flex-col justify-between gap-8 rounded-3xl border border-zinc-200 bg-white p-8">
          <div>
            <h3 className="mb-3 text-xl font-bold text-zinc-900">{m.popoverTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-zinc-500">{m.popoverBody}</p>
          </div>
          {/* grid + list popover mocks — native app icons, like the dock demo */}
          <div className="flex flex-col gap-3 rounded-2xl bg-zinc-100 p-4 sm:flex-row">
            <div className="popover-surface flex-1 rounded-2xl p-3">
              <p className="pb-2 pt-1 text-center text-[13px] font-medium text-zinc-800">Grid</p>
              <div className="grid grid-cols-3 gap-2">
                {gridApps.map((app) => (
                  <span key={app.name} className="flex aspect-square items-center justify-center">
                    <Image
                      src={app.src}
                      alt={app.name}
                      width={40}
                      height={40}
                      unoptimized
                      draggable={false}
                      className="h-9 w-9"
                    />
                  </span>
                ))}
              </div>
            </div>
            <div className="popover-surface flex-1 rounded-2xl p-3">
              <p className="pb-2 pt-1 text-[13px] font-semibold text-zinc-800">List</p>
              <div className="flex flex-col gap-1">
                {listApps.map((app) => (
                  <span key={app.name} className="flex items-center gap-2 rounded px-2 py-1.5 text-[13px] text-zinc-700 odd:bg-black/5">
                    <Image
                      src={app.src}
                      alt=""
                      width={20}
                      height={20}
                      unoptimized
                      draggable={false}
                      className="h-5 w-5"
                    />
                    {app.name}
                  </span>
                ))}
              </div>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            {["Popover size", "Tile size", "Spacing", "Labels", "Hover highlight", "Animation"].map((chip) => (
              <span key={chip} className="rounded-full bg-zinc-100 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                {chip}
              </span>
            ))}
          </div>
        </Reveal>

        {/* Smart Add — white card */}
        <Reveal delay={80} className="flex flex-col justify-between gap-8 rounded-3xl border border-zinc-200 bg-white p-8">
          <div>
            <h3 className="mb-3 text-xl font-bold text-zinc-900">{m.smartAddTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-zinc-500">{m.smartAddBody}</p>
          </div>
          {/* suggestion mock */}
          <div className="relative flex items-center justify-center rounded-2xl bg-zinc-100 p-6">
            <div className="grid w-full grid-cols-2 gap-3">
              <div className="flex items-center gap-3 rounded-2xl border border-zinc-200 bg-white p-3 shadow-sm">
                <span
                  className="squircle flex h-10 w-10 items-center justify-center"
                  style={{ background: "linear-gradient(to bottom, #FF8EA7, #FF5482)" }}
                >
                  <TileGlyph name="sparkles" className="h-4 w-4 text-white" />
                </span>
                <span>
                  <p className="text-xs font-bold text-zinc-900">AI Apps</p>
                  <p className="text-[10px] text-zinc-400">6 apps</p>
                </span>
              </div>
              <div className="flex translate-y-4 items-center gap-3 rounded-2xl border border-zinc-200 bg-white p-3 shadow-sm">
                <span
                  className="squircle flex h-10 w-10 items-center justify-center"
                  style={{ background: "linear-gradient(to bottom, #6BCF7F, #34C759)" }}
                >
                  <TileGlyph name="chat" className="h-4 w-4 text-white" />
                </span>
                <span>
                  <p className="text-xs font-bold text-zinc-900">Chat</p>
                  <p className="text-[10px] text-zinc-400">4 apps</p>
                </span>
              </div>
            </div>
            <span className="animate-bounce-subtle absolute top-1/2 left-1/2 flex -translate-x-1/2 -translate-y-1/2 items-center gap-1.5 rounded-full bg-emerald-400 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-emerald-950">
              <Clock className="h-3 w-3" />
              Most used this week
            </span>
          </div>
          <div className="flex w-fit items-center gap-3 rounded-2xl bg-zinc-900 px-4 py-3">
            <ShieldCheck className="h-5 w-5 text-emerald-400" />
            <p className="text-[13px] font-medium text-white/80">{m.smartAddPrivacy}</p>
          </div>
        </Reveal>

        {/* Ghost Mode — dark card */}
        <Reveal delay={160} className="relative flex flex-col justify-between overflow-hidden rounded-3xl bg-zinc-900 p-8 text-white">
          <div className="grain" />
          <div className="relative">
            <h3 className="mb-3 text-xl font-bold">{m.ghostTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-white/60">{m.ghostBody}</p>
          </div>
          <Ghost className="relative mx-auto h-24 w-24 text-white/10" />
        </Reveal>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Dock Lock — dark story                                              */
/* ------------------------------------------------------------------ */

export function DockLockStory() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section data-nav-tone="dark" className="relative mx-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4">
      <div className="grain" />
      <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-950/40" />
      <div className="relative mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
        <Reveal className="order-2 md:order-1">
          <div className="relative flex h-64 items-center justify-center gap-6 rounded-2xl border border-white/5 bg-zinc-950 px-6 md:gap-8">
            {/* display without the Dock */}
            <div className="flex h-32 w-full max-w-48 items-end justify-center rounded-lg border border-white/10 bg-zinc-900 pb-2">
              <span className="h-4 w-1/2 rounded-full bg-white/10 opacity-40" />
            </div>
            {/* anchor display, Dock locked */}
            <div className="flex h-32 w-full max-w-48 items-end justify-center rounded-lg border border-emerald-400/30 bg-zinc-900 pb-2">
              <span className="flex h-4 w-1/2 items-center justify-center rounded-full border border-emerald-400/50 bg-emerald-400/20">
                <Lock className="h-2 w-2 text-emerald-400" />
              </span>
            </div>
            <span className="glass absolute top-6 left-1/2 -translate-x-1/2 rounded-xl px-4 py-2 text-[10px] font-bold uppercase tracking-widest text-white">
              Dock Lock active
            </span>
          </div>
        </Reveal>
        <Reveal delay={120} className="order-1 md:order-2">
          <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-white/30">
            {m.dockLockEyebrow}
          </span>
          <h2 className="mb-6 text-3xl font-semibold tracking-[-0.05em] leading-[1.05] text-white md:text-4xl">
            {m.dockLockTitle}
          </h2>
          <p className="max-w-lg text-lg font-light leading-relaxed text-white/60">
            {m.dockLockBody}
          </p>
        </Reveal>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Final CTA — dark band                                               */
/* ------------------------------------------------------------------ */

export function FinalCta() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section data-nav-tone="dark" className="relative mx-3 mb-3 flex flex-col items-center justify-center overflow-hidden rounded-[2.5rem] bg-black px-6 py-24 text-center md:mx-4 md:mb-4 md:py-32">
      <div className="grain" />
      <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
      <Reveal className="relative z-10">
        <h2 className="mb-12 text-3xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl">
          {m.ctaTitle}
        </h2>
        <div className="flex justify-center">
          <DownloadActionButton tone="light" size="lg" label={m.ctaButton} />
        </div>
        <div className="mt-8 flex items-center justify-center gap-4 text-xs font-medium text-white/40">
          <span>{m.ctaMetaFree}</span>
          <span className="h-1 w-1 rounded-full bg-white/20" />
          <Link
            href="/release-notes"
            onClick={trackReleaseNotesClick}
            className="underline decoration-white/20 underline-offset-4 transition-colors duration-300 hover:text-white"
          >
            v{siteConfig.latestVersion}
          </Link>
          <span className="h-1 w-1 rounded-full bg-white/20" />
          <span>macOS 26+</span>
        </div>
        <p className="mt-6 text-sm text-white/50">
          {content.supportText}{" "}
          <a
            href={`mailto:${siteConfig.contactEmail}`}
            onClick={trackContactClick}
            className="font-medium text-white/80 underline decoration-white/30 underline-offset-4 transition-colors duration-300 hover:text-emerald-400 hover:decoration-emerald-400/50"
          >
            {content.supportLink}
          </a>
        </p>
      </Reveal>
    </section>
  );
}
