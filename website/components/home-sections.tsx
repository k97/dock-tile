"use client";

import { useMounted } from "@/lib/use-mounted";
import { ArrowUpRight, Clock, EyeOff, Ghost, Lock, LockOpen, ShieldCheck } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useTheme } from "next-themes";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackContactClick, trackExternalLinkClick, trackReleaseNotesClick } from "@/lib/analytics";
import { Reveal } from "@/components/reveal";
import { DownloadActionButton } from "@/components/action-button";
import { TileGlyph } from "@/components/tile-glyph";

/* Native app icons for the Grid/List popover mocks — same assets the
   hero dock demo uses, so the popover previews read as real macOS icons. */
const gridApps = [
  { name: "Claude", src: "/assets/app-icons/claude.png" },
  { name: "Code", src: "/assets/app-icons/vscode.png" },
  { name: "Slack", src: "/assets/app-icons/slack.png" },
  { name: "Music", src: "/assets/app-icons/music.png" },
  { name: "Netflix", src: "/assets/app-icons/netflix.png" },
  { name: "Messages", src: "/assets/app-icons/messages.png" },
];

const listApps = [
  { name: "Music", src: "/assets/app-icons/music.png" },
  { name: "Podcasts", src: "/assets/app-icons/podcasts.png" },
  { name: "Kayo", src: "/assets/app-icons/kayo.png" },
];

// DockTile's own Dark icon style (see docs/rules/icon-system.md — and the
// matching hero dock-demo.tsx): neutral near-black background, tile tint
// moves to the glyph. Kept in sync with dock-demo.tsx's DARK_TILE_BG.
const DARK_TILE_BG = "linear-gradient(to bottom, #3a3a3c, #1c1c1e)";

/* Ghost Mode — the Cmd+Tab switcher line-up. The `ghost` slot is where a
   Dock Tile tile would sit; it stays hidden, so the selection skips it.
   Finder ships a bespoke Dark icon-style rendition (`darkSrc`); third-party
   icons without one (Code/Slack/Music) get macOS's generic fallback instead —
   the regular icon inset in a dark box — rather than staying unstyled. */
const switcherApps = [
  { name: "Finder", src: "/assets/app-icons/finder.png", darkSrc: "/assets/app-icons/finder-dark.png?v=4" },
  { name: "Code", src: "/assets/app-icons/vscode.png" },
  { ghost: true as const },
  { name: "Slack", src: "/assets/app-icons/slack.png" },
  { name: "Music", src: "/assets/app-icons/music.png" },
];

/* ------------------------------------------------------------------ */
/* Custom tiles — light story (the "Features" anchor target)           */
/* ------------------------------------------------------------------ */

export function CustomTilesStory() {
  const { content } = useLocale();
  const m = content.marketing;
  const { resolvedTheme } = useTheme();
  const mounted = useMounted();

  // Two screenshots of the same window (light + dark Customise Tile), swapped
  // by the site's own theme rather than the OS-follow used elsewhere in this
  // file — this is a real screenshot, not a mock, so it must match exactly.
  const screenshotSrc =
    mounted && resolvedTheme === "dark"
      ? "/assets/stage/customise-tile-dark.webp"
      : "/assets/stage/customise-tile.webp";

  return (
    <section
      id="features"
      className="mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32"
    >
      <Reveal>
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
          {m.tilesEyebrow}
        </span>
        <h2 className="mb-6 text-3xl font-semibold tracking-[-0.05em] leading-[1.05] text-foreground md:text-4xl">
          {m.tilesTitle}
        </h2>
        <p className="max-w-lg text-lg font-light leading-relaxed text-muted-foreground">
          {m.tilesBody}
        </p>
      </Reveal>
      <Reveal delay={120}>
        <div className="relative mx-auto aspect-2048/1374 w-full max-w-md overflow-hidden rounded-3xl border border-border shadow-xl md:max-w-none">
          <Image
            src={screenshotSrc}
            alt={m.tilesCaption}
            fill
            sizes="(max-width: 768px) 100vw, 640px"
            className="object-contain"
          />
        </div>
        <p className="mt-6 text-center text-[11px] font-medium uppercase tracking-wider text-muted-foreground">
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
  const { resolvedTheme } = useTheme();
  const mounted = useMounted();
  const isDarkSite = mounted && resolvedTheme === "dark";

  return (
    <section className="mx-auto max-w-400 px-6 py-24 md:px-10 md:py-32">
      <Reveal className="mb-14 text-center">
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
          {m.powerUserEyebrow}
        </span>
        <h2 className="text-2xl font-semibold tracking-[-0.05em] leading-[1.05] text-foreground md:text-3xl">
          {m.bentoTitle}
        </h2>
      </Reveal>

      <div className="grid gap-6 md:grid-cols-3">
        {/* Grid or List — white card */}
        <Reveal className="flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-8">
          <div>
            <h3 className="mb-3 text-xl font-bold text-foreground">{m.popoverTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-muted-foreground">{m.popoverBody}</p>
          </div>
          {/* grid + list popover mocks — native app icons, like the dock demo.
              No tray wrapper: the popover-surface shadows breathe on the card
              and the card stays shorter (drives the whole bento row height). */}
          <div className="flex flex-col gap-4 sm:flex-row">
            <div className="popover-surface flex-1 rounded-2xl p-3">
              <p className="pb-2 pt-1 text-center text-[13px] font-medium text-zinc-800 dark:text-zinc-100">Grid</p>
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
              <p className="pb-2 pt-1 text-[13px] font-semibold text-zinc-800 dark:text-zinc-100">List</p>
              <div className="flex flex-col gap-1">
                {listApps.map((app) => (
                  <span key={app.name} className="flex items-center gap-2 rounded px-2 py-1.5 text-[13px] text-zinc-700 dark:text-zinc-300">
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
              <span key={chip} className="rounded-full bg-muted px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
                {chip}
              </span>
            ))}
          </div>
        </Reveal>

        {/* Smart Add — white card */}
        <Reveal delay={80} className="flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-8">
          <div>
            <h3 className="mb-3 text-xl font-bold text-foreground">{m.smartAddTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-muted-foreground">{m.smartAddBody}</p>
          </div>
          {/* suggestion mock */}
          <div className="flex flex-col items-center gap-4 rounded-2xl bg-muted p-6">
            <div className="grid w-full grid-cols-2 gap-3">
              <div className="flex items-center gap-3 rounded-2xl border border-border bg-card p-3 shadow-sm">
                <span
                  className="squircle flex h-10 w-10 min-w-10 items-center justify-center"
                  style={{ background: isDarkSite ? DARK_TILE_BG : "linear-gradient(to bottom, #A78BFF, #7C3AED)" }}
                >
                  <TileGlyph
                    name="sparkles"
                    className="h-6 w-6"
                    style={{ color: isDarkSite ? "#A78BFF" : "white" }}
                  />
                </span>
                <span>
                  <p className="text-xs font-bold text-foreground">AI Apps</p>
                  <p className="text-[10px] text-muted-foreground">6 apps</p>
                </span>
              </div>
              <div className="flex items-center gap-3 rounded-2xl border border-border bg-card p-3 shadow-sm">
                <span
                  className="squircle flex h-10 w-10 min-w-10 items-center justify-center"
                  style={{ background: isDarkSite ? DARK_TILE_BG : "linear-gradient(to bottom, #52DFA8, #10B981)" }}
                >
                  <TileGlyph
                    name="chat"
                    className="h-6 w-6"
                    style={{ color: isDarkSite ? "#52DFA8" : "white" }}
                  />
                </span>
                <span>
                  <p className="text-xs font-bold text-foreground">Chat</p>
                  <p className="text-[10px] text-muted-foreground">4 apps</p>
                </span>
              </div>
            </div>
            <span className="animate-bounce-subtle flex items-center gap-1.5 rounded-full bg-sky-300 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-sky-950">
              <Clock className="h-3 w-3" />
              Most used this week
            </span>
          </div>
          {/* Plain icon + text row — same flush treatment as the Ghost card's
              tip so the two footnotes align identically. The Smart Add card
              follows the theme (white in light mode), so colours are
              theme-aware where the always-dark Ghost card hardcodes white. */}
          <div className="mx-auto flex w-fit items-center gap-3">
            <ShieldCheck className="h-5 w-5 shrink-0 text-emerald-500 dark:text-emerald-400" />
            <p className="text-[13px] font-medium text-zinc-600 dark:text-white/80">{m.smartAddPrivacy}</p>
          </div>
        </Reveal>

        {/* Ghost Mode — dark card */}
        <Reveal delay={160} className="relative flex flex-col justify-between gap-8 overflow-hidden rounded-3xl bg-zinc-900 p-8 text-white">
          <div className="grain" />
          <div className="relative">
            <h3 className="mb-3 text-xl font-bold">{m.ghostTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-white/60">{m.ghostBody}</p>
          </div>
          {/* Cmd+Tab app switcher — the selection tabs across real apps and
              skips the ghosted Dock Tile slot */}
          <div className="relative flex flex-col items-center gap-4">
            <div className="relative flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.07] p-3 backdrop-blur-xl">
              {/* moving selection highlight (sits behind the icons) */}
              <span className="app-switch-sel absolute left-3 top-3 h-12 w-12 rounded-xl bg-white/15 ring-1 ring-white/25" />
              {switcherApps.map((app, i) =>
                app.ghost ? (
                  <span
                    key="ghost"
                    className="relative z-10 flex h-12 w-12 items-center justify-center rounded-xl border border-dashed border-white/20"
                  >
                    <Ghost strokeWidth={1.5} className="ghost-phase h-6 w-6 text-white/40" />
                  </span>
                ) : (
                  // Every icon renders at the SAME 44px — never resized. Dark
                  // mode swaps in a bespoke dark rendition where one exists
                  // (e.g. Finder); otherwise the regular icon shows unchanged,
                  // exactly as macOS leaves most third-party apps in dark mode.
                  <span key={app.name ?? i} className="relative z-10 flex h-12 w-12 items-center justify-center">
                    <Image
                      src={isDarkSite && app.darkSrc ? app.darkSrc : app.src}
                      alt={app.name}
                      width={44}
                      height={44}
                      unoptimized
                      draggable={false}
                      className="h-11 w-11"
                    />
                  </span>
                ),
              )}
            </div>
            <div className="flex items-center gap-1.5 text-white/40">
              <kbd className="rounded-md border border-white/15 bg-white/5 px-2 py-0.5 text-[11px] font-semibold">⌘</kbd>
              <kbd className="rounded-md border border-white/15 bg-white/5 px-2 py-0.5 text-[11px] font-semibold">⇥</kbd>
            </div>
          </div>
          {/* Plain icon + text row (no chip background), matching how the Smart
              Add privacy note reads. `relative` keeps it above the grain overlay. */}
          <div className="relative mx-auto flex w-fit items-center gap-3">
            <EyeOff className="h-5 w-5 shrink-0 text-emerald-400" />
            <p className="text-[13px] font-medium text-white/80">{m.ghostTip}</p>
          </div>
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
          <div className="relative flex h-64 items-center justify-center rounded-2xl border border-white/5 bg-zinc-950 px-6">
            {/* bounded track = the pill's positioning context. Two equal grid
                columns with symmetric padding put each screen's centre exactly
                at 25% / 75%, so the Dock locks dead-centre at any width. */}
            <div className="relative grid w-full max-w-sm grid-cols-2 items-center">
              {/* non-anchor display */}
              <div className="px-3">
                <div className="h-32 rounded-lg border border-white/10 bg-zinc-900" />
              </div>
              {/* anchor display — frame tints blue while unlocked, green once locked */}
              <div className="px-3">
                <div className="dock-lock-anchor h-32 rounded-lg border border-emerald-400/30 bg-zinc-900" />
              </div>

              {/* the Dock — roams between screens (blue, unlocked), then locks
                  onto the anchor and turns green. Base classes are the green
                  locked resting state (used when motion is reduced). */}
              <span className="dock-lock-pill absolute bottom-4 left-[calc(75%-40px)] flex h-6 w-20 items-center justify-center rounded-full border border-emerald-400/60 bg-emerald-400/25 shadow-[0_0_14px_rgba(52,211,153,0.45)]">
                <LockOpen className="dock-lock-open h-3.5 w-3.5 text-sky-300" />
                <Lock className="dock-lock-closed absolute h-3.5 w-3.5 text-emerald-300" />
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
          <a
            href={siteConfig.githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackExternalLinkClick(siteConfig.githubUrl, "final_cta")}
            className="underline decoration-white/20 underline-offset-4 transition-colors duration-300 hover:text-white"
          >
            {m.ctaMetaOpenSource}
          </a>
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

        {/* Spades Audio — cross-promo, inline pill */}
        <a
          href={siteConfig.spadesAudioUrl}
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => trackExternalLinkClick(siteConfig.spadesAudioUrl, "spades_audio_promo_inline")}
          className="group glass mt-10 inline-flex items-center gap-3 rounded-full px-4 py-2 text-xs text-white/60 transition-colors duration-300 hover:text-white"
        >
          <Image
            src="/assets/spades-audio-icon.svg"
            alt=""
            width={20}
            height={20}
            className="h-5 w-5 rounded-full"
          />
          <span>
            <span className="text-white/40">{m.spadesLead}</span>{" "}
            <span className="font-medium">{m.spadesButton}</span>
          </span>
          <ArrowUpRight className="h-3.5 w-3.5 transition-transform duration-300 group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
        </a>
      </Reveal>
    </section>
  );
}
