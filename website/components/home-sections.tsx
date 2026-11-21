"use client";

import * as React from "react";
import {
  BatteryFull,
  ChevronRight,
  EyeOff,
  FolderOpen,
  Ghost,
  Github,
  Keyboard,
  Languages,
  Lock,
  LockOpen,
  PanelTop,
  Search,
  Plus,
  SlidersHorizontal,
  ShieldCheck,
  Wifi,
} from "lucide-react";
import Image from "next/image";
import { useLocale } from "@/components/locale-provider";
import { asset } from "@/lib/assets";
import { siteConfig } from "@/lib/config";
import { Reveal } from "@/components/reveal";
import { CloserLook } from "@/components/closer-look";
import { ICON_CONTENT_RATIO, TileFace } from "@/components/dock-demo";
import { InlineTile } from "@/components/inline-tile";

/* Uniform scale-to-fit: children render at their fixed natural size; the
   whole block is zoomed (transform scale, aspect ratio locked — like a
   miniature screenshot) to the width on offer, capped at 1:1. The
   illustration itself never restyles or reflows across viewports. */
function ScaleToFit({ children }: { children: React.ReactNode }) {
  const outerRef = React.useRef<HTMLDivElement>(null);
  const innerRef = React.useRef<HTMLDivElement>(null);
  const [fit, setFit] = React.useState<{ scale: number; height: number; left: number } | null>(null);

  React.useLayoutEffect(() => {
    const outer = outerRef.current;
    const inner = innerRef.current;
    if (!outer || !inner) return;
    const measure = () => {
      const scale = Math.min(1, outer.clientWidth / inner.offsetWidth);
      setFit({
        scale,
        height: Math.round(inner.offsetHeight * scale),
        left: Math.max(0, (outer.clientWidth - inner.offsetWidth * scale) / 2),
      });
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(outer);
    return () => ro.disconnect();
  }, []);

  return (
    <div ref={outerRef} className="relative w-full" style={{ height: fit?.height }}>
      <div
        ref={innerRef}
        className={`absolute top-0 w-max ${fit ? "" : "invisible"}`}
        style={fit ? { left: fit.left, transform: `scale(${fit.scale})`, transformOrigin: "top left" } : undefined}
      >
        {children}
      </div>
    </div>
  );
}

// The Smart Add mocks below use the Dock's own `TileFace` (shaded glyph, rim,
// Dark-style plate + glow) and the Dock's lift shadow, so every designed tile
// on the page looks the same as the ones in the hero and closing Docks.

/* Ghost Mode — the Cmd+Tab switcher line-up. The `ghost` slot is where a
   Dock Tile tile would sit; it stays hidden, so the selection skips it.
   Finder and Music ship a bespoke Dark icon-style rendition (`darkSrc`);
   third-party icons without one (Code/Slack) get macOS's generic fallback instead —
   the regular icon inset in a dark box — rather than staying unstyled. */
// Order is load-bearing: the `app-switch-sel` keyframes (globals.css) and the
// name delays in the Ghost card ([0, 4.4, 0, 3.3, 2.2]) index these slots.
const switcherApps = [
  { name: "Finder", src: "/assets/app-icons/finder.png", darkSrc: "/assets/app-icons/finder-dark.png?v=4" },
  { name: "Code", src: "/assets/app-icons/vscode.png" },
  { ghost: true as const },
  { name: "Slack", src: "/assets/app-icons/slack.png" },
  { name: "Music", src: "/assets/app-icons/music.png?v=2", darkSrc: "/assets/app-icons/music-dark.png?v=1" },
];

/* ------------------------------------------------------------------ */
/* Custom tiles — light story (the "Features" anchor target)           */
/* ------------------------------------------------------------------ */

export function CustomTilesStory() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    // Follows the light card section: no top padding, its bottom padding is the gap.
    // `#customise` is where the hero Dock's Configure… walks to.
    <section id="customise" data-nav-section="features" className="mx-auto max-w-400 scroll-mt-28 px-4 pb-24 sm:px-6 md:px-10 md:pb-50">
      {/* Stacked, Apple-style: the window is a three-pane app, so it needs the
          full content width to read — text centred above, screenshot below. */}
      <Reveal className="mx-auto mb-12 max-w-180 text-center md:mb-13">
        <h2 className="mx-auto mb-6 max-w-132 text-section text-foreground">
          {/* The tile is the result of the picking: an App Grid of its own apps.
              nowrap keeps it with "Done." so it never ends a line alone. */}
          {m.tilesTitleA}{" "}
          <span className="whitespace-nowrap">
            <InlineTile tilt="-rotate-6">
              <AppGridFace icons={mediaAppIcons} />
            </InlineTile>{" "}
            {m.tilesTitleB}
          </span>
        </h2>
        <p className="mx-auto max-w-150 text-lead text-muted-foreground">
          {m.tilesBody}
        </p>
      </Reveal>
      <Reveal delay={120}>
        {/* The 2.x window with "take a closer look" hotspots — see closer-look.tsx. */}
        <CloserLook />
      </Reveal>
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Dock Lock — the one problem-led chapter, on its own dark band       */
/* ------------------------------------------------------------------ */

export function DockLockStory() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    // The last band before the Download section, inset like the hero, with a gap below.
    <section data-nav-tone="dark" data-nav-section="features" className="relative mx-3 mb-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4 md:mb-4">
      <div className="grain" />
      <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-950/40" />
      <div className="relative mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
        <Reveal>
          <h2 className="mb-6 max-w-132 text-section text-white">
            {m.dockLockTitleA}{" "}
            <span className="whitespace-nowrap">
              <InlineTile tilt="rotate-6">
                <TileFace gradient="linear-gradient(to bottom, #52DFA8, #10B981)" darkGlyph="#52DFA8" glyph="lock" shaded />
              </InlineTile>{" "}
              {m.dockLockTitleB}
            </span>
          </h2>
          <p className="max-w-lg text-lead text-white/60">{m.dockLockBody}</p>
          <div className="mt-8 flex items-center gap-3">
            <Lock className="h-5 w-5 shrink-0 text-emerald-400" />
            <p className="text-[13px] font-medium text-white/80">{m.dockLockTip}</p>
          </div>
        </Reveal>
        <Reveal delay={120}>
          <DockLockMock dark />
        </Reveal>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ */
/* Set up for you — Smart Add + Menu bar + Ghost, one bento         */
/* ------------------------------------------------------------------ */

const bentoCard = "mx-auto w-full max-w-md flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-6 md:p-10 xl:max-w-none";

export function PowerUserSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    // The first section after the hero (nav "Features" lands here).
    <section id="features" data-nav-section="features" className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-50">
      <Reveal className="mb-12 text-center md:mb-13">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          {/* Orange + bolt: a colour and glyph no hero Dock tile uses. nowrap keeps
              the tile ending line one, so "Out of your way." stands alone. */}
          <span className="whitespace-nowrap">
            {m.cardsTitleA}{" "}
            <InlineTile tilt="rotate-6">
              <TileFace gradient="linear-gradient(to bottom, #FFB547, #F97316)" darkGlyph="#FFB547" glyph="bolt" shaded />
            </InlineTile>
          </span>{" "}
          {m.cardsTitleB}
        </h2>
      </Reveal>

      {/* 3-across only from xl up. Below that the row collapses to one column so
          each card is wide enough to hold its illustration at a FIXED, roomy
          native size (the Smart Add sheet and the menu never reflow per breakpoint). */}
      <div className="grid gap-6 xl:grid-cols-3">
        <Reveal className={bentoCard}>
          <div>
            <h3 className="mb-3 text-title-sm text-foreground">{m.smartAddTitle}</h3>
            <p className="max-w-md text-lead text-muted-foreground">{m.smartAddBody}</p>
          </div>
          <div className="rounded-2xl bg-muted p-5">
            <SmartAddMock />
          </div>
          <Footnote icon={ShieldCheck}>{m.smartAddPrivacy}</Footnote>
        </Reveal>

        {/* The dark Ghost card sits in the middle, between the two light ones (owner, 2026-11-22). */}
        <GhostCard delay={80} className="mx-auto max-w-md xl:max-w-none" />

        <Reveal delay={160} className={bentoCard}>
          <div>
            <h3 className="mb-3 text-title-sm text-foreground">{m.menuBarTitle}</h3>
            <p className="max-w-md text-lead text-muted-foreground">{m.menuBarBody}</p>
          </div>
          <div className="rounded-2xl bg-muted p-5">
            <MenuBarMock />
          </div>
          <Footnote icon={PanelTop}>{m.menuBarLead}</Footnote>
        </Reveal>
      </div>

      <SmallFeatures />
    </section>
  );
}

/* A card's flush icon + text footnote (no chip background). */
function Footnote({ icon: Icon, children }: { icon: React.ComponentType<{ className?: string }>; children: React.ReactNode }) {
  return (
    <div className="mx-auto flex w-fit items-center gap-3">
      <Icon className="h-5 w-5 shrink-0 text-emerald-500 dark:text-emerald-400" />
      <p className="text-[13px] font-medium text-zinc-600 dark:text-white/80">{children}</p>
    </div>
  );
}

/* Ghost Mode — always a dark card. It runs a charcoal gradient (lighter than
   the flat zinc-900 shells) so it reads as its OWN card. */
function GhostCard({ delay, className = "" }: { delay: number; className?: string }) {
  const { content } = useLocale();
  const m = content.marketing;
  return (
    <Reveal delay={delay} className={`relative flex w-full flex-col justify-between gap-8 overflow-hidden rounded-3xl bg-linear-to-b from-zinc-800 to-zinc-900 p-6 text-white md:p-10 ${className}`}>
      <div className="grain" />
      <div className="relative">
        <h3 className="mb-3 text-title-sm">{m.ghostTitle}</h3>
        <p className="max-w-md text-lead text-white/60">{m.ghostBody}</p>
      </div>
      <AppSwitcherMock />
      {/* `relative` keeps the footnote above the grain overlay. */}
      <div className="relative mx-auto flex w-fit items-center gap-3">
        <EyeOff className="h-5 w-5 shrink-0 text-emerald-400" />
        <p className="text-[13px] font-medium text-white/80">{m.ghostTip}</p>
      </div>
    </Reveal>
  );
}

/* Cmd+Tab app switcher — the selection tabs across real apps and skips the
   ghosted Dock Tile slot. */
function AppSwitcherMock() {
  return (
    // pt-10 leaves room for the name tooltip that floats above the strip.
    <div className="relative flex flex-col items-center gap-4 pt-10">
      {/* Concentric: the 12px slot radius + the 12px `p-3` inset ⇒ a 24px
          (rounded-3xl) shell. */}
      <div className="relative flex items-center gap-2 rounded-3xl border border-white/10 bg-white/[0.07] p-3 backdrop-blur-xl">
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
            // Every icon renders at the SAME 44px. Dark mode swaps in a bespoke
            // dark rendition where one exists (both render, CSS shows the
            // theme's one so the first frame is right).
            <span key={app.name ?? i} className="relative z-10 flex h-12 w-12 items-center justify-center">
              <Image
                src={asset(app.src)}
                alt={app.name}
                width={44}
                height={44}
                unoptimized
                draggable={false}
                className={`h-11 w-11 drop-shadow-[0_1px_2px_rgba(0,0,0,0.4)] ${app.darkSrc ? "dark:hidden" : ""}`}
              />
              {app.darkSrc && (
                <Image
                  src={asset(app.darkSrc)}
                  alt={app.name}
                  width={44}
                  height={44}
                  unoptimized
                  draggable={false}
                  className="hidden h-11 w-11 drop-shadow-[0_1px_2px_rgba(0,0,0,0.4)] dark:block"
                />
              )}
            </span>
          ),
        )}
        {/* The selected app's name as a macOS tooltip (the Dock's own tooltip style,
            ui/mac-os-dock.tsx) over its slot. Each fades in on the highlight's 5.5 s
            clock (negative delays shift one keyframe to each slot's window);
            reduced motion rests on Finder. */}
        {switcherApps.map((app, i) =>
          app.ghost ? null : (
            <span
              key={`name-${app.name}`}
              aria-hidden
              className={`absolute bottom-full mb-2 -translate-x-1/2 whitespace-nowrap rounded-md border border-white/10 bg-zinc-900/85 px-2 py-1 font-ui text-xs font-medium text-white shadow-md backdrop-blur-sm ${
                i === 0 ? "switch-name-first" : "switch-name opacity-0"
              }`}
              style={{ left: 36 + i * 56, animationDelay: i === 0 ? undefined : `${-[0, 4.4, 0, 3.3, 2.2][i]}s` }}
            >
              {app.name}
            </span>
          ),
        )}
      </div>
      <div className="flex items-center gap-1.5 text-white/40">
        <kbd className="rounded-md border border-white/15 bg-white/5 px-2 py-0.5 text-[11px] font-semibold">⌘</kbd>
        <kbd className="rounded-md border border-white/15 bg-white/5 px-2 py-0.5 text-[11px] font-semibold">⇥</kbd>
      </div>
    </div>
  );
}

// Paired with `marketing.details` in lib/i18n.ts by position — reorder both together.
const detailIcons = [Keyboard, FolderOpen, Github, Languages];

/* Four short items under the bento: the name on its own line, then one muted
   sentence, at the section body size (text-lead). Open source links to the repo. */
function SmallFeatures() {
  const { content } = useLocale();
  return (
    <ul className="mt-14 grid gap-x-8 gap-y-10 px-2 sm:grid-cols-2 md:mt-16 lg:grid-cols-4">
      {content.marketing.details.map((d, i) => {
        const Icon = detailIcons[i];
        return (
          <Reveal as="li" key={d.lead} delay={i * 60} className="flex flex-col">
            <span className="mb-4 flex h-9 w-9 items-center justify-center rounded-xl bg-foreground/6 text-foreground">
              <Icon strokeWidth={1.5} className="h-4.5 w-4.5" />
            </span>
            {Icon === Github ? (
              <a href={siteConfig.githubUrl} target="_blank" rel="noopener noreferrer" className="w-fit text-lead font-medium text-foreground underline decoration-foreground/20 underline-offset-4 transition-colors hover:decoration-foreground">
                {d.lead}
              </a>
            ) : (
              <p className="text-lead font-medium text-foreground">{d.lead}</p>
            )}
            <p className="mt-1 text-lead text-muted-foreground">{d.body}</p>
          </Reveal>
        );
      })}
    </ul>
  );
}

/* ------------------------------------------------------------------ */
/* Card mocks                                                          */
/* ------------------------------------------------------------------ */

// Hero tiles reused so the menu mock lists the same tiles as the Dock above.
const menuTiles = [
  { name: "AI Apps", glyph: "sparkles", gradient: "linear-gradient(to bottom, #A78BFF, #7C3AED)", dark: "#A78BFF" },
  { name: "Dev Apps", glyph: "tools", gradient: "linear-gradient(to bottom, #4AA8FF, #0A6FE8)", dark: "#4AA8FF" },
  { name: "Comms", glyph: "chat", gradient: "linear-gradient(to bottom, #52DFA8, #10B981)", dark: "#52DFA8" },
  { name: "Media", glyph: "tv", gradient: "linear-gradient(to bottom, #FF7AAE, #EC3E7C)", dark: "#FF7AAE" },
] as const;

const devApps = [
  { name: "Code", src: "/assets/app-icons/vscode.png" },
  { name: "GitHub", src: "/assets/app-icons/github.png" },
  { name: "Xcode", src: "/assets/app-icons/xcode.png" },
  { name: "Warp", src: "/assets/app-icons/warp.png" },
];

const menuRow = "flex h-5.5 items-center gap-2 rounded-md px-2 text-[13px] text-zinc-800 dark:text-zinc-100";
const menuSep = "mx-2 my-1 border-t border-black/10 dark:border-white/10";
// A highlighted menu row is the system accent with white text, as on a real Mac.
const menuHighlight = "bg-[#007AFF] text-white! dark:bg-[#0A84FF]";

function AppIcon({ src, size }: { src: string; size: number }) {
  return (
    <Image src={asset(src)} alt="" width={size} height={size} unoptimized draggable={false} style={{ width: size, height: size }} />
  );
}

/* The menu bar icon's menu (TileMenu in the app): tiles with submenus of
   their apps, then Open Dock Tile… / Quit. Fixed 460×196 px, zoomed by
   ScaleToFit like every illustrative macOS component on the page. Status
   items sit right as on a real menu bar, so the submenu opens leftwards. */
function MenuBarMock() {
  return (
    <ScaleToFit>
      <div className="h-49 w-115">
        <div className="flex h-7 font-ui items-center justify-end gap-3.5 rounded-lg bg-white/80 px-2 text-[13px] text-zinc-800 shadow-sm dark:bg-white/10 dark:text-zinc-100">
          <span className="relative flex h-5.5 items-center rounded-md bg-black/10 px-1.5 dark:bg-white/15">
            <Image
              src={asset("/assets/dock-tile-icon-only.svg")}
              alt=""
              width={18}
              height={18}
              unoptimized
              className="h-4.5 w-4.5 brightness-0 dark:invert"
            />
            {/* Hung from the status item: the menu's left edge under the item, the
                submenu's first row level with "Dev Apps", overlapping the menu by 4px. */}
            <div className="popover-surface absolute left-0 top-6.75 w-52 rounded-xl p-1.5">
              {menuTiles.map((t) => (
                <div key={t.name} className={`${menuRow} ${t.name === "Dev Apps" ? menuHighlight : ""}`}>
                  <span className="flex h-4 w-4">
                    <TileFace gradient={t.gradient} darkGlyph={t.dark} glyph={t.glyph} shaded />
                  </span>
                  {t.name}
                  <ChevronRight className={`ml-auto h-3 w-3 ${t.name === "Dev Apps" ? "text-white/80" : "text-zinc-400"}`} />
                </div>
              ))}
              <div className={menuSep} />
              <div className={menuRow}>Open Dock Tile…</div>
              <div className={menuRow}>
                Quit Dock Tile<span className="ml-auto text-zinc-400">⌘Q</span>
              </div>
            </div>
            <div className="popover-surface absolute -left-43 top-12.25 w-44 rounded-xl p-1.5">
              {devApps.map((app) => (
                <div key={app.name} className={menuRow}>
                  <AppIcon src={app.src} size={16} />
                  {app.name}
                </div>
              ))}
              <div className={menuSep} />
              <div className={menuRow}>Configure Tile…</div>
            </div>
          </span>
          <Wifi className="h-3.5 w-3.5" />
          <BatteryFull className="h-4 w-4" />
          <Search className="h-3.5 w-3.5" />
          <SlidersHorizontal className="h-3.5 w-3.5" />
          <span className="font-medium">Mon 9:41</span>
        </div>
      </div>
    </ScaleToFit>
  );
}

/* Dock Lock: two displays; the Dock (pill) roams between them (blue,
   unlocked), then locks onto the anchor and turns green. Fixed 330×170 px
   so the pill's 25% / 75% keyframe positions land on each screen's centre.
   Base classes are the locked resting state (reduced motion). */
function DockLockMock({ dark = false }: { dark?: boolean }) {
  return (
    // `dark`: on the always-dark Dock Lock band, a near-black well instead of the muted one.
    <div className={dark ? "rounded-2xl border border-white/5 bg-zinc-950 p-8" : "rounded-2xl bg-muted p-5"}>
      <ScaleToFit>
        <div className="relative grid h-42.5 w-82.5 grid-cols-2 items-center">
          <div className="px-3">
            <div className="h-32 rounded-lg border border-white/10 bg-zinc-900" />
          </div>
          <div className="px-3">
            <div className="dock-lock-anchor h-32 rounded-lg border border-emerald-400/30 bg-zinc-900" />
          </div>
          <span className="dock-lock-pill absolute bottom-9.25 left-[calc(75%-40px)] flex h-6 w-20 items-center justify-center rounded-full border border-emerald-400/60 bg-emerald-400/25 shadow-[0_0_14px_rgba(52,211,153,0.45)]">
            <LockOpen className="dock-lock-open h-3.5 w-3.5 text-sky-300" />
            <Lock className="dock-lock-closed absolute h-3.5 w-3.5 text-emerald-300" />
          </span>
        </div>
      </ScaleToFit>
    </div>
  );
}

/* App Grid face (the app's AppsFaceGrid): a 2×2 of the tile's own apps on
   the system-gray plate (light 1.0 → 0.925, dark 0.192 → 0.078), block 80%
   of the shape. Rows are definite 1fr tracks so the %-sized icons can't
   blow their cells up. */
export function AppGridFace({ icons }: { icons: readonly string[] }) {
  return (
    <div className="flex h-full w-full items-center justify-center">
      <div
        className="squircle grid grid-cols-2 grid-rows-2 gap-[3.5%] bg-linear-to-b from-white to-[#ECECEC] p-[10%] dark:from-[#313131] dark:to-[#141414]"
        style={{ width: ICON_CONTENT_RATIO, height: ICON_CONTENT_RATIO }}
      >
        {icons.map((src) => (
          <Image key={src} src={asset(src)} alt="" width={24} height={24} unoptimized draggable={false} className="h-full w-full" />
        ))}
      </div>
    </div>
  );
}

/* The tint at a fixed HSB brightness, hue and saturation kept — the app's
   Dark-style plate for a Colour emoji tile (SRGB.cappingBrightness). */
function capBrightness(hex: string, v: number) {
  const n = parseInt(hex.slice(1), 16);
  const rgb = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  const k = (v * 255) / (Math.max(...rgb) || 1);
  return "#" + rgb.map((c) => Math.round(c * k).toString(16).padStart(2, "0")).join("");
}

type Tint = { top: string; bottom: string };
const MONO_LIGHT = "linear-gradient(to bottom, #FFFFFF, #EFEFF1)";
const MONO_DARK = "linear-gradient(to bottom, #2C2C2E, #1C1C1E)";
const tintGradient = (t: Tint) => `linear-gradient(to bottom, ${t.top}, ${t.bottom})`;

/* Emoji face. Light: the tint (Colour) or white (Mono). Dark: the tint
   capped to 0.22 → 0.13 brightness (Colour) or near-black (Mono). Both
   backgrounds ride CSS variables so the theme switch is pure CSS. */
function EmojiFace({ emoji, tint, mono = false, fontSize = 28 }: { emoji: string; tint: Tint; mono?: boolean; fontSize?: number }) {
  const dark = `linear-gradient(to bottom, ${capBrightness(tint.bottom, 0.22)}, ${capBrightness(tint.bottom, 0.13)})`;
  return (
    <div className="flex h-full w-full items-center justify-center">
      <div
        className="squircle flex items-center justify-center leading-none [background:var(--face-light)] dark:[background:var(--face-dark)]"
        style={
          {
            width: ICON_CONTENT_RATIO,
            height: ICON_CONTENT_RATIO,
            fontSize,
            "--face-light": mono ? MONO_LIGHT : tintGradient(tint),
            "--face-dark": mono ? MONO_DARK : dark,
          } as React.CSSProperties
        }
      >
        {emoji}
      </div>
    </div>
  );
}

const mediaAppIcons = ["appletv.png", "netflix.png", "music.png?v=2", "podcasts.png"].map((n) => `/assets/app-icons/${n}`);
export const aiAppIcons = ["claude", "chatgpt", "gemini", "granola"].map((n) => `/assets/app-icons/${n}.png`);

// One card per design, as the app deals them: App Grid, Symbol, Emoji.
const suggestions = [
  {
    name: "Chat",
    note: "Most used this week",
    face: <AppGridFace icons={["messages", "slack", "whatsapp", "google-meet"].map((n) => `/assets/app-icons/${n}.png`)} />,
  },
  {
    name: "Ship",
    note: "5 apps",
    face: <TileFace gradient="linear-gradient(to bottom, #818CF8, #4F46E5)" darkGlyph="#818CF8" glyph="code" shaded />,
  },
  { name: "Watch", note: "3 apps", face: <EmojiFace emoji="🍿" tint={{ top: "#FF7AAE", bottom: "#EC3E7C" }} /> },
];

/* The "Add a Tile" sheet Smart Add opens on +: blank row, the rule, the
   suggestion cards (the privacy note is the card's footnote). 440 px wide. */
function SmartAddMock() {
  return (
    <ScaleToFit>
      <div className="popover-surface w-110 rounded-2xl p-4 text-zinc-800 dark:text-zinc-100">
        <p className="mb-3 text-center text-[13px] font-semibold">Add a Tile</p>
        <div className="flex items-center gap-3 rounded-xl bg-black/4 p-2.5 dark:bg-white/6">
          <span className="squircle flex h-9 w-9 items-center justify-center bg-black/6 dark:bg-white/10">
            <Plus className="h-4 w-4 text-zinc-500 dark:text-zinc-400" />
          </span>
          <span>
            <p className="text-[12px] font-semibold">Create a blank tile</p>
            <p className="text-[11px] text-zinc-500 dark:text-zinc-400">Name it, pick an icon and add apps yourself.</p>
          </span>
        </div>
        <div className="my-3 flex items-center gap-2 text-[11px] text-zinc-500 dark:text-zinc-400">
          <span className="h-px flex-1 bg-black/10 dark:bg-white/10" />
          or start from what you use
          <span className="h-px flex-1 bg-black/10 dark:bg-white/10" />
        </div>
        <div className="grid grid-cols-3 gap-2.5">
          {suggestions.map((s) => (
            <div
              key={s.name}
              className="flex flex-col items-center gap-1 rounded-xl bg-white/70 px-2 pb-2.5 pt-3 ring-1 ring-black/5 dark:bg-white/5 dark:ring-white/10"
            >
              <span className="mb-1 flex h-14 w-14 drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)]">{s.face}</span>
              <p className="text-[12px] font-semibold">{s.name}</p>
              <p className="text-[10px] text-zinc-500 dark:text-zinc-400">{s.note}</p>
            </div>
          ))}
        </div>
      </div>
    </ScaleToFit>
  );
}
