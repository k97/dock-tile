"use client";

import {
  AlertCircle,
  Clock,
  Ghost,
  Lock,
  MessageSquare,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import Link from "next/link";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackContactClick, trackReleaseNotesClick } from "@/lib/analytics";
import { Reveal } from "@/components/reveal";
import { DownloadActionButton } from "@/components/action-button";

/* ------------------------------------------------------------------ */
/* Smart Add — light story                                             */
/* ------------------------------------------------------------------ */

export function SmartAddStory() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section className="mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
      <Reveal>
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-zinc-400">
          {m.smartAddEyebrow}
        </span>
        <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-5xl">
          {m.smartAddTitle}
        </h2>
        <p className="mb-8 max-w-lg text-lg font-light leading-relaxed text-zinc-500">
          {m.smartAddBody}
        </p>
        <div className="flex w-fit items-center gap-3 rounded-2xl bg-zinc-900 px-4 py-3">
          <ShieldCheck className="h-5 w-5 text-emerald-400" />
          <p className="text-[13px] font-medium text-white/80">{m.smartAddPrivacy}</p>
        </div>
      </Reveal>

      <Reveal delay={120}>
        <div className="relative flex aspect-[4/3] items-center justify-center rounded-[2.5rem] bg-zinc-100 p-8 md:p-12">
          <div className="grid w-full grid-cols-2 gap-4">
            <div className="flex items-center gap-4 rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm">
              <span
                className="squircle flex h-12 w-12 items-center justify-center"
                style={{ background: "linear-gradient(to bottom, #FF8EA7, #FF5482)" }}
              >
                <Sparkles className="h-5 w-5 text-white" />
              </span>
              <span>
                <p className="text-sm font-bold text-zinc-900">AI Apps</p>
                <p className="text-[10px] text-zinc-400">6 suggestions</p>
              </span>
            </div>
            <div className="flex translate-y-8 items-center gap-4 rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm">
              <span
                className="squircle flex h-12 w-12 items-center justify-center"
                style={{ background: "linear-gradient(to bottom, #6BCF7F, #34C759)" }}
              >
                <MessageSquare className="h-5 w-5 text-white" />
              </span>
              <span>
                <p className="text-sm font-bold text-zinc-900">Chat</p>
                <p className="text-[10px] text-zinc-400">4 suggestions</p>
              </span>
            </div>
          </div>
          <span className="animate-bounce-subtle absolute top-1/2 left-1/2 flex -translate-x-1/2 -translate-y-1/2 items-center gap-1.5 rounded-full bg-emerald-400 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-emerald-950">
            <Clock className="h-3 w-3" />
            Most used this week
          </span>
        </div>
      </Reveal>
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
    <section className="relative mx-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4">
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
          <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl">
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
/* Bento — power-user features                                         */
/* ------------------------------------------------------------------ */

const TILE_STYLES = [
  // The same tile in the four Tahoe icon styles, per the app's palette
  { label: "Default", background: "linear-gradient(to bottom, #FF8EA7, #FF5482)" },
  { label: "Dark", background: "linear-gradient(to bottom, #2C2C2E, #1C1C1E)" },
  { label: "Clear", background: "linear-gradient(to bottom, #F0F0F2, #E0E0E4)" },
  { label: "Tinted", background: "linear-gradient(to bottom, #8E8E93, #636366)" },
];

export function BentoGrid() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section className="mx-auto max-w-400 px-6 py-24 md:px-10 md:py-32">
      <Reveal className="mb-16 text-center">
        <h2 className="text-3xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-4xl">
          {m.bentoTitle}
        </h2>
      </Reveal>
      <div className="grid gap-6 md:grid-cols-3">
        <Reveal className="group relative flex h-80 flex-col justify-between overflow-hidden rounded-3xl border border-zinc-200 bg-white p-8 md:col-span-2">
          <div>
            <h3 className="mb-2 text-xl font-bold text-zinc-900">Tahoe icon styles</h3>
            <p className="max-w-md text-sm text-zinc-500">
              Every tile is baked in four variants — Default, Dark, Clear and Tinted —
              and follows the system&rsquo;s icon appearance automatically.
            </p>
          </div>
          <div className="flex gap-4 pt-8 transition-transform duration-500 ease-(--ease-out-strong) md:translate-y-4 md:group-hover:translate-y-0">
            {TILE_STYLES.map((s) => (
              <div key={s.label} className="flex flex-col items-center gap-2">
                <span
                  className="squircle relative h-20 w-20 overflow-hidden md:h-24 md:w-24"
                  style={{ background: s.background }}
                >
                  <span className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/15 to-transparent" />
                  <Sparkles
                    className={`absolute top-1/2 left-1/2 h-8 w-8 -translate-x-1/2 -translate-y-1/2 ${
                      s.label === "Dark"
                        ? "text-[#FF7A9C]"
                        : s.label === "Clear"
                          ? "text-[#6E6E73]"
                          : "text-white"
                    }`}
                  />
                </span>
                <span className="text-[10px] font-medium text-zinc-400">{s.label}</span>
              </div>
            ))}
          </div>
        </Reveal>

        <Reveal delay={80} className="relative flex h-80 flex-col justify-between overflow-hidden rounded-3xl bg-zinc-900 p-8 text-white">
          <div className="grain" />
          <div className="relative">
            <h3 className="mb-2 text-xl font-bold">Ghost Mode</h3>
            <p className="text-sm text-white/60">
              Tiles stay out of Cmd-Tab and the App Switcher by default. In the Dock
              when you need them, invisible when you don&rsquo;t.
            </p>
          </div>
          <Ghost className="relative mx-auto h-20 w-20 text-white/10" />
        </Reveal>

        <Reveal className="flex h-80 flex-col justify-between rounded-3xl border border-zinc-200 bg-white p-8">
          <div>
            <h3 className="mb-2 text-xl font-bold text-zinc-900">Missing-app detection</h3>
            <p className="text-sm text-zinc-500">
              Uninstalled an app? Its tile entry is flagged instead of silently
              breaking — remove it or keep it, your call.
            </p>
          </div>
          <div className="flex items-center gap-2 font-bold text-rose-500">
            <AlertCircle className="h-4 w-4" />
            <span className="text-xs uppercase tracking-wider">Not installed</span>
          </div>
        </Reveal>

        <Reveal delay={80} className="flex h-80 flex-col justify-between rounded-3xl bg-zinc-100 p-8 md:col-span-2">
          <div className="flex items-start justify-between gap-6">
            <div className="max-w-xs">
              <h3 className="mb-2 text-xl font-bold text-zinc-900">Start at login</h3>
              <p className="text-sm text-zinc-500">
                Keep your tiles ready in the Dock so they respond instantly after you
                restart your Mac.
              </p>
            </div>
            <div className="h-8 w-14 shrink-0 rounded-full bg-emerald-400 p-1">
              <span className="block h-6 w-6 translate-x-6 rounded-full bg-white shadow-sm" />
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            {["Signed", "Notarized", "Sparkle auto-updates"].map((chip) => (
              <span
                key={chip}
                className="rounded-full border border-zinc-200 bg-white px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-zinc-400"
              >
                {chip}
              </span>
            ))}
          </div>
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
    <section className="relative mx-3 mb-3 flex flex-col items-center justify-center overflow-hidden rounded-[2.5rem] bg-black px-6 py-24 text-center md:mx-4 md:mb-4 md:py-32">
      <div className="grain" />
      <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
      <Reveal className="relative z-10">
        <h2 className="mb-12 text-4xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-6xl">
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
