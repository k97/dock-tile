"use client";

import * as React from "react";
import {
  ArrowRight,
  BatteryFull,
  ChevronDown,
  ChevronRight,
  EyeOff,
  FolderOpen,
  Ghost,
  Github,
  Keyboard,
  Languages,
  PanelTop,
  Settings2,
  Search,
  Plus,
  SlidersHorizontal,
  ShieldCheck,
  Wifi,
} from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useDisplayName, useLocale } from "@/components/locale-provider";
import { asset, HERO_BG, HERO_BG_DARK } from "@/lib/assets";
import { siteConfig } from "@/lib/config";
import { Reveal } from "@/components/reveal";
import { CloserLook } from "@/components/closer-look";
import { ICON_CONTENT_RATIO, PopoverShape, TILES, TileFace } from "@/components/dock-demo";
import { dockDot, dockGlass, dockLift, dockTooltip } from "@/components/ui/mac-os-dock";
import { InlineTile } from "@/components/inline-tile";
import { ScaleToFit } from "@/components/scale-to-fit";
import { DockLockMock } from "@/components/dock-lock-mock";
import { localePath } from "@/lib/nav";

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
  { name: "Finder", src: "/assets/app-icons/finder.png?v=3", darkSrc: "/assets/app-icons/finder-dark.png?v=4" },
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
  const { locale, content } = useLocale();
  const m = content.marketing;

  return (
    // The last band before the Download section, inset like the hero, with a gap below.
    <section data-nav-tone="dark" data-nav-section="features" className="relative mx-3 mb-3 overflow-hidden rounded-[2.5rem] border border-white/10 bg-zinc-900 md:mx-4 md:mb-4">
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
          <p className="max-w-lg text-lead text-white/60">
            <b className="font-semibold text-white">{m.dockLockLead}</b> {m.dockLockBody}
          </p>
          {/* The Dock Lock page, in this page's language */}
          <Link
            href={localePath(locale, "/dock-lock")}
            className="pressable group mt-10 inline-flex h-13 items-center gap-2 rounded-full border border-white/15 px-6 text-sm font-semibold text-white transition-[background-color,scale] duration-200 hover:bg-white/10"
          >
            {m.dockLockPageLink}
            <ArrowRight className="h-4 w-4 transition-transform duration-200 group-hover:translate-x-0.5" />
          </Link>
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
    // Follows the light intro section: no top padding, its bottom padding is the gap.
    <section data-nav-section="features" className="mx-auto max-w-400 px-4 pb-24 sm:px-6 md:px-10 md:pb-50">
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
      {/* grid-cols-1 (minmax(0, 1fr)): an implicit track grew to a card's min-content and pushed
          the page 14 px wider than a 390 px phone. */}
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
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

        {/* The dark card sits in the middle, between the two light ones (owner, 2026-11-22):
            the menu bar card since the swap; Ghost mode moved right. Charcoal gradient,
            not flat zinc-900, so it reads as its own card. */}
        <Reveal delay={80} className="relative mx-auto flex w-full max-w-md flex-col justify-between gap-8 overflow-hidden rounded-3xl border border-white/10 bg-linear-to-b from-zinc-800 to-zinc-900 p-6 text-white md:p-10 xl:max-w-none">
          <div className="grain" />
          <div className="relative">
            <h3 className="mb-3 text-title-sm">{m.menuBarTitle}</h3>
            <p className="max-w-md text-lead text-white/60">
              <b className="font-semibold text-white">{m.menuBarIntro}</b> {m.menuBarBody}
            </p>
          </div>
          <div className="relative rounded-2xl bg-white/[0.06] p-5">
            <MenuBarMock />
          </div>
          {/* `relative` keeps the footnote above the grain overlay. */}
          <div className="relative mx-auto flex w-fit items-center gap-3">
            <PanelTop className="h-5 w-5 shrink-0 text-emerald-400" />
            <p className="text-[13px] font-medium text-white/80">{m.menuBarLead}</p>
          </div>
        </Reveal>

        <Reveal delay={160} className={bentoCard}>
          <div>
            <h3 className="mb-3 text-title-sm text-foreground">{m.ghostTitle}</h3>
            <p className="max-w-md text-lead text-muted-foreground">{m.ghostBody}</p>
          </div>
          <div className="rounded-2xl bg-muted p-5">
            <AppSwitcherMock />
          </div>
          <Footnote icon={EyeOff}>{m.ghostTip}</Footnote>
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

/* Cmd+Tab app switcher — the selection tabs across real apps and skips the
   ghosted Dock Tile slot. */
function AppSwitcherMock() {
  const name = useDisplayName();
  return (
    // pt-10 leaves room for the name tooltip that floats above the strip.
    <div className="relative flex flex-col items-center gap-4 pt-10">
      {/* Concentric: the 12px slot radius + the 12px `p-3` inset ⇒ a 24px
          (rounded-3xl) shell. */}
      <div className={`relative flex items-center gap-2 rounded-3xl p-3 ${dockGlass}`}>
        {/* moving selection highlight (sits behind the icons) */}
        <span className="app-switch-sel absolute left-3 top-3 h-12 w-12 rounded-xl bg-black/[0.12] dark:bg-white/15" />
        {switcherApps.map((app, i) =>
          app.ghost ? (
            <span
              key="ghost"
              className="relative z-10 flex h-12 w-12 items-center justify-center rounded-xl border border-dashed border-black/20 dark:border-white/20"
            >
              <Ghost strokeWidth={1.5} className="ghost-phase h-6 w-6 text-black/30 dark:text-white/40" />
            </span>
          ) : (
            // Every icon renders at the SAME 44px. Dark mode swaps in a bespoke
            // dark rendition where one exists (both render, CSS shows the
            // theme's one so the first frame is right).
            <span key={app.name ?? i} className="relative z-10 flex h-12 w-12 items-center justify-center">
              <Image
                src={asset(app.src)}
                alt={name(app.name)}
                width={44}
                height={44}
                unoptimized
                draggable={false}
                className={`h-11 w-11 ${dockLift} ${app.darkSrc ? "dark:hidden" : ""}`}
              />
              {app.darkSrc && (
                <Image
                  src={asset(app.darkSrc)}
                  alt={name(app.name)}
                  width={44}
                  height={44}
                  unoptimized
                  draggable={false}
                  className={`hidden h-11 w-11 dark:block ${dockLift}`}
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
              className={`absolute bottom-full mb-2 -translate-x-1/2 whitespace-nowrap ${dockTooltip} ${
                i === 0 ? "switch-name-first" : "switch-name opacity-0"
              }`}
              style={{ left: 36 + i * 56, animationDelay: i === 0 ? undefined : `${-[0, 4.4, 0, 3.3, 2.2][i]}s` }}
            >
              {name(app.name)}
            </span>
          ),
        )}
      </div>
      <div className="flex items-center gap-1.5 text-muted-foreground">
        <kbd className="rounded-md border border-border bg-background px-2 py-0.5 text-[11px] font-semibold">⌘</kbd>
        <kbd className="rounded-md border border-border bg-background px-2 py-0.5 text-[11px] font-semibold">⇥</kbd>
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

function AppIcon({ src, darkSrc, size }: { src: string; darkSrc?: string; size: number }) {
  const icon = (s: string, className?: string) => (
    <Image src={asset(s)} alt="" width={size} height={size} unoptimized draggable={false} className={className} style={{ width: size, height: size }} />
  );
  // The app's own Dark rendition in dark theme, swapped in CSS so it is right on frame 1.
  if (!darkSrc) return icon(src);
  return (
    <>
      {icon(src, "dark:hidden")}
      {icon(darkSrc, "hidden dark:block")}
    </>
  );
}

/* The menu bar icon's menu (TileMenu in the app): tiles with submenus of
   their apps, then Open Dock Tile… / Quit. Fixed 460×196 px, zoomed by
   ScaleToFit like every illustrative macOS component on the page. Status
   items sit right as on a real menu bar, so the submenu opens leftwards. */
function MenuBarMock() {
  const m = useLocale().content.marketing;
  const name = useDisplayName();
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
                  {name(t.name)}
                  <ChevronRight className={`ml-auto h-3 w-3 ${t.name === "Dev Apps" ? "text-white/80" : "text-zinc-400"}`} />
                </div>
              ))}
              <div className={menuSep} />
              <div className={menuRow}>{m.mockOpenDockTile}</div>
              <div className={menuRow}>
                {m.mockQuitDockTile}<span className="ml-auto text-zinc-400">⌘Q</span>
              </div>
            </div>
            <div className="popover-surface absolute -left-43 top-12.25 w-44 rounded-xl p-1.5">
              {devApps.map((app) => (
                <div key={app.name} className={menuRow}>
                  <AppIcon src={app.src} size={16} />
                  {name(app.name)}
                </div>
              ))}
              <div className={menuSep} />
              <div className={menuRow}>{m.mockConfigureTileItem}</div>
            </div>
          </span>
          <Wifi className="h-3.5 w-3.5" />
          <BatteryFull className="h-4 w-4" />
          <Search className="h-3.5 w-3.5" />
          <SlidersHorizontal className="h-3.5 w-3.5" />
          <span className="font-medium">{m.mockClock}</span>
        </div>
      </div>
    </ScaleToFit>
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
    note: "mockMostUsed",
    face: <AppGridFace icons={["messages", "slack", "whatsapp", "google-meet"].map((n) => `/assets/app-icons/${n}.png`)} />,
  },
  {
    name: "Ship",
    note: "mockFiveApps",
    face: <TileFace gradient="linear-gradient(to bottom, #818CF8, #4F46E5)" darkGlyph="#818CF8" glyph="code" shaded />,
  },
  { name: "Watch", note: "mockThreeApps", face: <EmojiFace emoji="🍿" tint={{ top: "#FF7AAE", bottom: "#EC3E7C" }} /> },
] as const;

/* The "Add a Tile" sheet Smart Add opens on +: blank row, the rule, the
   suggestion cards (the privacy note is the card's footnote). 440 px wide. */
function SmartAddMock() {
  const m = useLocale().content.marketing;
  const name = useDisplayName();
  return (
    <ScaleToFit>
      <div className="popover-surface w-110 rounded-2xl p-4 text-zinc-800 dark:text-zinc-100">
        <p className="mb-3 text-center text-[13px] font-semibold">{m.mockAddTile}</p>
        <div className="flex items-center gap-3 rounded-xl bg-black/4 p-2.5 dark:bg-white/6">
          <span className="squircle flex h-9 w-9 items-center justify-center bg-black/6 dark:bg-white/10">
            <Plus className="h-4 w-4 text-zinc-500 dark:text-zinc-400" />
          </span>
          <span>
            <p className="text-[12px] font-semibold">{m.mockBlankTitle}</p>
            <p className="text-[11px] text-zinc-500 dark:text-zinc-400">{m.mockBlankBody}</p>
          </span>
        </div>
        <div className="my-3 flex items-center gap-2 text-[11px] text-zinc-500 dark:text-zinc-400">
          <span className="h-px flex-1 bg-black/10 dark:bg-white/10" />
          {m.mockStartFrom}
          <span className="h-px flex-1 bg-black/10 dark:bg-white/10" />
        </div>
        <div className="grid grid-cols-3 gap-2.5">
          {suggestions.map((s) => (
            <div
              key={s.name}
              className="flex flex-col items-center gap-1 rounded-xl bg-white/70 px-2 pb-2.5 pt-3 ring-1 ring-black/5 dark:bg-white/5 dark:ring-white/10"
            >
              <span className="mb-1 flex h-14 w-14 drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)]">{s.face}</span>
              <p className="text-[12px] font-semibold">{name(s.name)}</p>
              <p className="text-[10px] text-zinc-500 dark:text-zinc-400">{m[s.note]}</p>
            </div>
          ))}
        </div>
      </div>
    </ScaleToFit>
  );
}

/* ------------------------------------------------------------------ */
/* What Dock Tile is — a crowded Dock becomes a few tiles (2026-11-22) */
/* ------------------------------------------------------------------ */

const icon = (n: string) => `/assets/app-icons/${n}`;
// A real-looking crowded Dock: the hero tiles' own apps, laid out flat. Looked up in TILES
// so each icon carries its name (the tooltip) and its Dark rendition.
const tileApps = TILES.flatMap((t) => t.apps);
const crowdedDock = [
  "claude.png", "chatgpt.png", "gemini.png", "granola.png", "vscode.png", "github.png", "xcode.png",
  "warp.png", "messages.png", "slack.png", "whatsapp.png", "google-meet.png", "facetime.png",
  "msteams.png", "appletv.png", "netflix.png", "music.png?v=2", "podcasts.png",
].map((n) => {
  const app = tileApps.find((a) => a.src === icon(n));
  if (!app) throw new Error(`crowdedDock: ${n} is not a tile app`);
  return app;
});

/* One Dock icon as the hero's Dock draws it: the lift, darkening on press, its name on hover. */
function DockIcon({ name, children }: { name: string; children: React.ReactNode }) {
  return (
    <span className="dock-item group relative flex h-10 w-10">
      <span className={`dock-face flex h-full w-full active:brightness-[0.72] ${dockLift}`}>{children}</span>
      {/* The label rides the lift layer, which rises with the magnified icon. Instant, like the hero's. */}
      <span className="dock-lift pointer-events-none absolute inset-0">
        <span
          aria-hidden
          className={`absolute bottom-full left-1/2 z-10 mb-2 -translate-x-1/2 whitespace-nowrap opacity-0 group-hover:opacity-100 ${dockTooltip}`}
        >
          {name}
        </span>
      </span>
    </span>
  );
}

/* Finder / System Settings bookend both Docks, as in the hero; their Dark
   renditions dual-render so the first frame is right in either theme. */
function DockEnd({ name }: { name: "finder" | "settings" }) {
  const display = useDisplayName();
  // Same ?v= keys as the hero Dock (dock-demo.tsx), or the browser downloads each icon twice.
  const light = name === "finder" ? "finder.png?v=3" : "settings.png?v=3";
  const dark = name === "finder" ? "finder-dark.png?v=4" : "settings-dark.png?v=1";
  return (
    <DockIcon name={display(name === "finder" ? "Finder" : "System Settings")}>
      <AppIcon src={icon(light)} darkSrc={icon(dark)} size={40} />
    </DockIcon>
  );
}

/* The hero Dock's magnification (ui/mac-os-dock.tsx) for a fixed-size strip: the same cosine
   window and 1.8x peak, scaled from its 64 px icon to these 40 px ones, and the same per-frame
   easing (0.2 toward the pointer, 0.12 back). The pointer is measured against the strip's own
   box, which never moves, so icons sliding apart can't change what counts as hovered (the CSS
   :hover version flickered on exactly that). Writes styles straight to the DOM each frame, no
   re-render; icons move by transform, the glass by one absolute box's left/right. */
const DOCK_ICON = 40;
const DOCK_GAP = 6;
const DOCK_PAD = 8;
const DOCK_MAX_SCALE = 1.8;
const DOCK_WINDOW = DOCK_ICON * (300 / 64);

function useDockMagnify() {
  const ref = React.useRef<HTMLDivElement>(null);
  React.useEffect(() => {
    const strip = ref.current;
    if (!strip || !window.matchMedia("(hover: hover)").matches) return;
    const items = Array.from(strip.querySelectorAll<HTMLElement>(":scope > .dock-item"));
    const faces = items.map((it) => it.querySelector<HTMLElement>(".dock-face"));
    const lifts = items.map((it) => it.querySelector<HTMLElement>(".dock-lift"));
    const glass = strip.querySelector<HTMLElement>(":scope > .dock-glass");
    const rest = items.map((_, i) => i * (DOCK_ICON + DOCK_GAP) + DOCK_ICON / 2);
    const restTotal = items.length * DOCK_ICON + (items.length - 1) * DOCK_GAP;
    const scales = items.map(() => 1);
    const shifts = items.map(() => 0);
    // Where an open tile's popover sat when it opened: it holds there, as the hero's does,
    // while the Dock keeps magnifying under it.
    const held: ({ x: number; y: number } | undefined)[] = items.map(() => undefined);
    let grow = 0;
    let mouseX: number | null = null;
    let frame = 0;

    const tick = () => {
      const target = rest.map((c) => {
        const d = mouseX === null ? Infinity : Math.abs(c - mouseX);
        if (d > DOCK_WINDOW / 2) return 1;
        return 1 + ((1 + Math.cos((d / (DOCK_WINDOW / 2)) * Math.PI)) / 2) * (DOCK_MAX_SCALE - 1);
      });
      const total = target.reduce((sum, s) => sum + s * DOCK_ICON, 0) + (items.length - 1) * DOCK_GAP;
      const targetGrow = (total - restTotal) / 2;
      const k = mouseX === null ? 0.12 : 0.2;
      let x = 0;
      let moving = Math.abs(targetGrow - grow) > 0.05;
      target.forEach((s, i) => {
        const shift = x + (s * DOCK_ICON) / 2 - targetGrow - rest[i];
        x += s * DOCK_ICON + DOCK_GAP;
        if (items[i].hasAttribute("data-open")) held[i] ??= { x: shifts[i], y: -(scales[i] - 1) * DOCK_ICON };
        else held[i] = undefined;
        scales[i] += (s - scales[i]) * k;
        shifts[i] += (shift - shifts[i]) * k;
        moving ||= Math.abs(s - scales[i]) > 0.002 || Math.abs(shift - shifts[i]) > 0.05;
        items[i].style.translate = `${shifts[i]}px`;
        faces[i]?.style.setProperty("scale", `${scales[i]}`);
        const h = held[i];
        lifts[i]?.style.setProperty(
          "translate",
          h ? `${h.x - shifts[i]}px ${h.y}px` : `0 ${-(scales[i] - 1) * DOCK_ICON}px`,
        );
      });
      grow += (targetGrow - grow) * k;
      if (glass) glass.style.left = glass.style.right = `${-grow}px`;
      // A resting pointer needs no frames once settled; pointermove restarts the loop.
      frame = moving ? requestAnimationFrame(tick) : 0;
    };
    const start = () => {
      if (!frame) frame = requestAnimationFrame(tick);
    };
    const move = (e: PointerEvent) => {
      if (e.pointerType !== "mouse") return;
      const box = strip.getBoundingClientRect();
      // ScaleToFit zooms the whole picture; convert back to the strip's own pixels.
      mouseX = (e.clientX - box.left) / (box.width / strip.offsetWidth) - DOCK_PAD;
      start();
    };
    const leave = () => {
      mouseX = null;
      start();
    };
    strip.addEventListener("pointermove", move);
    strip.addEventListener("pointerleave", leave);
    return () => {
      strip.removeEventListener("pointermove", move);
      strip.removeEventListener("pointerleave", leave);
      cancelAnimationFrame(frame);
    };
  }, []);
  return ref;
}

/* A Dock strip at a fixed natural size (zoomed by ScaleToFit, never reflowed). */
function DockStrip({ children }: { children: React.ReactNode }) {
  const ref = useDockMagnify();
  return (
    <div ref={ref} className="dock-strip relative flex items-center gap-1.5 p-2">
      {/* The glass is a sibling layer, never the icons' parent: a backdrop-filter parent would
          make the hover popovers blur only the strip, never the wallpaper behind. */}
      <span aria-hidden className={`dock-glass absolute inset-0 rounded-2xl ${dockGlass}`} />
      {children}
    </div>
  );
}

/* A Dock tile that opens its popover on click, as the hero's do — the hero's grid or list
   popover, absolutely positioned above the tile so it overlays the picture instead of pushing
   it down. Open state is `data-open` on the tile (BeforeAfterDocks owns it); hover shows the name. */
// The hero popover's per-app entrance (dock-app-in): each app rises 4 px and fades in over
// 240 ms, 30 ms after the one before. The delay applies on open only, so closing is one move.
const appIn =
  "opacity-0 translate-y-1 transition-[opacity,translate] duration-[240ms] ease-(--ease-out-strong) group-data-[open]:opacity-100 group-data-[open]:translate-y-0 group-data-[open]:delay-(--stagger)";
const staggerAt = (i: number) => ({ "--stagger": `${i * 30}ms` }) as React.CSSProperties;

function IntroTile({ tile, open, onToggle }: { tile: (typeof TILES)[number]; open: boolean; onToggle: () => void }) {
  const list = tile.layout === "list";
  const name = useDisplayName();
  const panelRef = React.useRef<HTMLSpanElement>(null);
  const [size, setSize] = React.useState<{ w: number; h: number } | null>(null);

  // offsetWidth/Height ignore the pop-in scale, so this is the panel's resting size.
  React.useLayoutEffect(() => {
    const el = panelRef.current;
    if (el) setSize({ w: el.offsetWidth, h: el.offsetHeight });
  }, []);

  // Opacity sits on each layer, never on a shared parent: a parent below opacity 1 cuts the
  // glass off from the wallpaper, so its blur would vanish while fading in.
  // The hero popover's timing (dock-scale-in / -out): 260 ms in with a small overshoot,
  // 190 ms out. Transitions, not keyframes, so a quick re-click reverses from where it is.
  const timing =
    "duration-[190ms] ease-[cubic-bezier(0.4,0,1,1)] group-data-[open]:duration-[260ms] group-data-[open]:ease-[cubic-bezier(0.34,1.56,0.64,1)]";
  const fade = `opacity-0 transition-opacity group-data-[open]:opacity-100 ${timing}`;

  return (
    <button
      type="button"
      data-intro-tile
      data-open={open || undefined}
      aria-label={name(tile.name)}
      aria-expanded={open}
      onClick={onToggle}
      className="dock-item group relative flex h-10 w-10 cursor-pointer rounded-[22.5%] outline-none focus-visible:ring-2 focus-visible:ring-black/60 dark:focus-visible:ring-white/80"
    >
      {/* Lift, press and magnification on the face only: a filter or scale on the popover's
          parent would break its blur or grow the popover. */}
      <span className={`dock-face flex h-full w-full active:brightness-[0.72] ${dockLift}`}>
        <TileFace gradient={tile.gradient} darkGlyph={tile.darkGlyph} glyph={tile.glyph} shaded />
      </span>
      {/* The open dot under the tile while its popover is up, as on the hero Dock. */}
      <span className={`absolute -bottom-0.5 left-1/2 h-1 w-1 -translate-x-1/2 rounded-full opacity-0 group-data-[open]:opacity-100 ${dockDot}`} />
      {/* The lift layer rises with the magnified tile (useDockMagnify), carrying the name and popover. */}
      <span className="dock-lift pointer-events-none absolute inset-0">
      {/* The name on hover, instant like the hero's; hidden while the popover is up. */}
      <span
        aria-hidden
        className={`absolute bottom-full left-1/2 z-10 mb-2 -translate-x-1/2 whitespace-nowrap opacity-0 group-hover:opacity-100 group-data-[open]:hidden ${dockTooltip}`}
      >
        {name(tile.name)}
      </span>
      <span
        ref={panelRef}
        aria-hidden // illustrative, like every mock on the page; its apps are not interactive
        // Pops up from its arrow tip like the hero's: rises 8 px and scales from 0.86 with a small
        // overshoot; reduced motion only fades.
        className={`pointer-events-none absolute bottom-full left-1/2 z-10 mb-4 block origin-[50%_calc(100%+11px)] -translate-x-1/2 translate-y-2 scale-86 transition-[translate,scale] group-data-[open]:translate-y-0 group-data-[open]:scale-100 motion-reduce:translate-y-0 motion-reduce:scale-100 ${timing} ${
          list ? "w-60" : "w-72"
        }`}
      >
        {size && <PopoverShape w={size.w} h={size.h} className={fade} />}
        <span className={`relative block ${fade} ${list ? "p-1.5" : "px-2 pb-2"}`}>
          {list ? (
            <>
              <span className="block px-3 pb-1 pt-2 text-left text-[13px] font-semibold text-zinc-800 dark:text-zinc-100">{name(tile.name)}</span>
              {tile.apps.map((app, i) => (
                <span key={app.name} className={`flex items-center gap-2.5 px-3 py-1 text-[13px] text-zinc-700 dark:text-zinc-300 ${appIn}`} style={staggerAt(i)}>
                  <AppIcon src={app.src} darkSrc={app.darkSrc} size={24} />
                  {name(app.name)}
                </span>
              ))}
            </>
          ) : (
            <>
              <span className="flex h-9 items-center justify-between px-1">
                <span className="w-7" />
                <span className="text-[13px] font-medium text-zinc-800 dark:text-zinc-100">{name(tile.name)}</span>
                <Settings2 className="mr-2 h-3.5 w-3.5 text-zinc-500 dark:text-zinc-400" />
              </span>
              <span className="grid grid-cols-4 gap-x-1 gap-y-2 px-1">
                {tile.apps.map((app, i) => (
                  <span key={app.name} className={`flex flex-col items-center gap-1.5 p-1.5 ${appIn}`} style={staggerAt(i)}>
                    <AppIcon src={app.src} darkSrc={app.darkSrc} size={48} />
                    <span className="max-w-full truncate text-[11px] leading-none text-zinc-600 dark:text-zinc-300">{name(app.name)}</span>
                  </span>
                ))}
              </span>
            </>
          )}
        </span>
      </span>
      </span>
    </button>
  );
}

function BeforeAfterDocks({ before, after }: { before: string; after: string }) {
  const label = "mb-3 text-[13px] font-medium text-white/85 drop-shadow-[0_1px_2px_rgba(0,0,0,0.4)]";
  // Which tile's popover is open. A click elsewhere or Escape closes it, as on the hero.
  const [openId, setOpenId] = React.useState<string | null>(null);
  const name = useDisplayName();
  React.useEffect(() => {
    if (!openId) return;
    const outside = (e: PointerEvent) => {
      if (!(e.target as Element).closest("[data-intro-tile]")) setOpenId(null);
    };
    const escape = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpenId(null);
    };
    document.addEventListener("pointerdown", outside);
    document.addEventListener("keydown", escape);
    return () => {
      document.removeEventListener("pointerdown", outside);
      document.removeEventListener("keydown", escape);
    };
  }, [openId]);
  return (
    <ScaleToFit>
      <div className="flex w-235 flex-col items-center font-ui">
        <p className={label}>{before}</p>
        <DockStrip>
          <DockEnd name="finder" />
          {crowdedDock.map((app) => (
            <DockIcon key={app.src} name={name(app.name)}>
              <AppIcon src={app.src} darkSrc={app.darkSrc} size={40} />
            </DockIcon>
          ))}
          <DockEnd name="settings" />
        </DockStrip>
        <ChevronDown className="my-6 h-5 w-5 text-white/75" />
        <p className={label}>{after}</p>
        <DockStrip>
          <DockEnd name="finder" />
          {TILES.map((t) => (
            <IntroTile key={t.id} tile={t} open={openId === t.id} onToggle={() => setOpenId(openId === t.id ? null : t.id)} />
          ))}
          <DockEnd name="settings" />
        </DockStrip>
      </div>
    </ScaleToFit>
  );
}

export function IntroSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    // The first section after the hero: what Dock Tile is, before what it does.
    <section id="features" data-nav-section="features" className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-50">
      <Reveal className="mb-12 text-center md:mb-13">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          <span className="whitespace-nowrap">
            {m.introTitleA}{" "}
            <InlineTile tilt="-rotate-6">
              <AppGridFace icons={devApps.map((a) => a.src)} />
            </InlineTile>
          </span>{" "}
          {m.introTitleB}
        </h2>
      </Reveal>

      {/* The picture of the idea on a wallpaper that is NOT the hero's (owner, 2026-11-22):
          the same dither file (already cached), cropped to another region and
          hue-shifted, so each section reads as its own scene. */}
      <Reveal className="relative mx-auto max-w-300 overflow-hidden rounded-3xl edge-hairline px-6 py-12 md:px-12 md:py-16">
        <div
          aria-hidden
          className="hero-texture"
          style={
            {
              "--hero-bg": `url("${HERO_BG}")`,
              "--hero-bg-dark": `url("${HERO_BG_DARK}")`,
              backgroundSize: "150%",
              backgroundPosition: "60% 75%",
              filter: "hue-rotate(200deg) saturate(1.1)",
            } as React.CSSProperties
          }
        />
        <div aria-hidden className="absolute inset-0 bg-black/10" />
        <div className="relative">
          <BeforeAfterDocks before={m.introBefore} after={m.introAfter} />
        </div>
      </Reveal>

      <ul className="mx-auto mt-14 grid max-w-300 gap-x-10 gap-y-8 px-2 md:mt-16 md:grid-cols-3">
        {m.introPoints.map((p, i) => (
          <Reveal as="li" key={p.lead} delay={i * 60}>
            <p className="text-lead font-medium text-foreground">{p.lead}</p>
            <p className="mt-1 text-lead text-muted-foreground">{p.body}</p>
          </Reveal>
        ))}
      </ul>
    </section>
  );
}
