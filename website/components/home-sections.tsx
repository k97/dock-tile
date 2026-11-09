"use client";

import * as React from "react";
import {
  BatteryFull,
  ChevronRight,
  CircleDashed,
  EyeOff,
  FolderOpen,
  Ghost,
  Keyboard,
  Languages,
  LayoutGrid,
  Lock,
  LockOpen,
  Option,
  Palette,
  PanelTop,
  Power,
  RefreshCw,
  Search,
  Plus,
  SlidersHorizontal,
  ShieldCheck,
  Undo2,
  Wifi,
} from "lucide-react";
import Image from "next/image";
import { useLocale } from "@/components/locale-provider";
import { asset } from "@/lib/assets";
import { Reveal } from "@/components/reveal";
import { CloserLook } from "@/components/closer-look";
import { ICON_CONTENT_RATIO, TileFace } from "@/components/dock-demo";

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

  return (
    <section id="features" data-nav-section="features" className="mx-auto max-w-400 px-6 py-24 md:px-10 md:py-32">
      {/* Stacked, Apple-style: the window is a three-pane app, so it needs the
          full content width to read — text centred above, screenshot below. */}
      <Reveal className="mx-auto mb-14 max-w-180 text-center md:mb-16">
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
          {m.tilesEyebrow}
        </span>
        <h2 className="mb-6 text-3xl font-semibold tracking-[-0.05em] leading-[1.05] text-foreground md:text-4xl">
          {m.tilesTitle}
        </h2>
        <p className="mx-auto max-w-150 text-lg font-light leading-relaxed text-muted-foreground">
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
/* Built for the power user — Grid/List + Smart Add + Ghost, one bento */
/* ------------------------------------------------------------------ */

export function PowerUserSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section data-nav-section="features" className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-32">
      <Reveal className="mb-14 text-center">
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
          {m.powerUserEyebrow}
        </span>
        <h2 className="text-2xl font-semibold tracking-[-0.05em] leading-[1.05] text-foreground md:text-3xl">
          {m.bentoTitle}
        </h2>
      </Reveal>

      {/* 3-across only from xl up. Below that the row collapses to one column so
          each card is wide enough to hold its illustration at a FIXED, roomy
          native size (the Smart Add sheet and the right-click popover never
          reflow per breakpoint — they'd only cramp in a narrow 3-col card). */}
      <div className="grid gap-6 xl:grid-cols-3">
        {/* Smart Add — white card; the "Add a Tile" sheet + on-device note */}
        <Reveal className="mx-auto w-full max-w-md flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-6 xl:max-w-none">
          <div>
            <h3 className="mb-3 text-xl font-bold text-foreground">{m.smartAddTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-muted-foreground">{m.smartAddBody}</p>
          </div>
          <div className="rounded-2xl bg-muted p-5">
            <SmartAddMock />
          </div>
          <div className="mx-auto flex w-fit items-center gap-3">
            <ShieldCheck className="h-5 w-5 shrink-0 text-emerald-500 dark:text-emerald-400" />
            <p className="text-[13px] font-medium text-zinc-600 dark:text-white/80">{m.smartAddPrivacy}</p>
          </div>
        </Reveal>

        {/* Right-click — white card; the popover with an app's item menu */}
        <Reveal delay={80} className="mx-auto w-full max-w-md flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-6 xl:max-w-none">
          <div>
            <h3 className="mb-3 text-xl font-bold text-foreground">{m.itemMenuTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-muted-foreground">{m.itemMenuBody}</p>
          </div>
          <div className="rounded-2xl bg-muted p-5">
            <ItemMenuMock />
          </div>
          {/* Plain icon + text row, the same flush footnote as the Ghost card's. */}
          <div className="mx-auto flex w-fit items-center gap-3">
            <Option className="h-5 w-5 shrink-0 text-emerald-500 dark:text-emerald-400" />
            <p className="text-[13px] font-medium text-zinc-600 dark:text-white/80">{m.itemMenuTip}</p>
          </div>
        </Reveal>

        {/* Ghost Mode — dark card */}
        {/* Ghost card runs a charcoal gradient (lighter than the flat zinc-900
            shells / pure-black CTA) so it reads as its OWN card and separates
            cleanly from the black Final CTA when they stack on mobile. */}
        <Reveal delay={160} className="relative mx-auto flex w-full max-w-md flex-col justify-between gap-8 overflow-hidden rounded-3xl bg-linear-to-b from-zinc-800 to-zinc-900 p-6 text-white xl:max-w-none">
          <div className="grain" />
          <div className="relative">
            <h3 className="mb-3 text-xl font-bold">{m.ghostTitle}</h3>
            <p className="max-w-md text-sm leading-relaxed text-white/60">{m.ghostBody}</p>
          </div>
          {/* Cmd+Tab app switcher — the selection tabs across real apps and
              skips the ghosted Dock Tile slot */}
          <div className="relative flex flex-col items-center gap-4">
            {/* Concentric: the 12px slot radius + the 12px `p-3` inset ⇒ a 24px
                (rounded-3xl) shell. At rounded-2xl the shell's corners were
                tighter than the icon slots tucked into them. */}
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
                  // Every icon renders at the SAME 44px — never resized. Dark
                  // mode swaps in a bespoke dark rendition where one exists
                  // (e.g. Finder) — both render, CSS shows the theme's one so
                  // the first frame is right; otherwise the regular icon shows
                  // unchanged, exactly as macOS leaves most third-party apps
                  // in dark mode.
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
/* Hidden in plain sight — letters.app-style: two big cards + a row    */
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

// Paired with `marketing.details` in lib/i18n.ts by position — reorder both together.
const detailIcons = [Keyboard, FolderOpen, LayoutGrid, Power, Undo2, CircleDashed, Languages, RefreshCw];

const menuRow = "flex h-5.5 items-center gap-2 rounded-md px-2 text-[13px] text-zinc-800 dark:text-zinc-100";
const menuSep = "mx-2 my-1 border-t border-black/10 dark:border-white/10";

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
        <div className="flex h-7 items-center justify-end gap-3.5 rounded-lg bg-white/80 px-2 text-[13px] text-zinc-800 shadow-sm dark:bg-white/10 dark:text-zinc-100">
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
                <div key={t.name} className={`${menuRow} ${t.name === "Dev Apps" ? "bg-black/8 dark:bg-white/12" : ""}`}>
                  <span className="flex h-4 w-4">
                    <TileFace gradient={t.gradient} darkGlyph={t.dark} glyph={t.glyph} shaded />
                  </span>
                  {t.name}
                  <ChevronRight className="ml-auto h-3 w-3 text-zinc-400" />
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

/* A tile's popover with an app's right-click menu (PopoverItemMenu):
   Open · Hide · Quit for a running app. Fixed 330×170 px. */
function ItemMenuMock() {
  return (
    <ScaleToFit>
      <div className="relative h-42.5 w-82.5">
        <div className="popover-surface w-60 rounded-2xl p-3 pt-0">
          <p className="flex h-9 items-center justify-center text-[13px] font-medium text-zinc-800 dark:text-zinc-100">
            Dev Apps
          </p>
          <div className="grid grid-cols-3">
            {devApps.slice(0, 3).map((app) => (
              <span
                key={app.name}
                className={`flex flex-col items-center gap-1.5 rounded-lg p-1.5 ${app.name === "GitHub" ? "bg-black/5 dark:bg-white/10" : ""}`}
              >
                <AppIcon src={app.src} size={48} />
                <span className="text-[11px] leading-none text-zinc-600 dark:text-zinc-300">{app.name}</span>
              </span>
            ))}
          </div>
        </div>
        <div className="popover-surface absolute left-31.5 top-19 w-40 rounded-xl p-1.5">
          <div className={menuRow}>Open</div>
          <div className={menuSep} />
          <div className={menuRow}>Hide</div>
          <div className={`${menuRow} bg-black/8 dark:bg-white/12`}>Quit</div>
        </div>
      </div>
    </ScaleToFit>
  );
}

/* App Grid face (the app's AppsFaceGrid): a 2×2 of the tile's own apps on
   the system-gray plate (light 1.0 → 0.925, dark 0.192 → 0.078), block 80%
   of the shape. Rows are definite 1fr tracks so the %-sized icons can't
   blow their cells up. */
function AppGridFace({ icons }: { icons: readonly string[] }) {
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

/* ---- Interactive customiser: the inspector's Style / Background / Colour
   rows driving a live tile, in the app's own rules: App Grid ignores the
   tint and the background (its plate is the system gray); a Mono symbol
   puts the tint on the glyph. Fixed 500 px wide, zoomed by ScaleToFit. */

const customTints: (Tint & { name: string })[] = [
  { name: "Purple", top: "#A78BFF", bottom: "#7C3AED" },
  { name: "Blue", top: "#4AA8FF", bottom: "#0A6FE8" },
  { name: "Green", top: "#52DFA8", bottom: "#10B981" },
  { name: "Pink", top: "#FF7AAE", bottom: "#EC3E7C" },
  { name: "Orange", top: "#FFB561", bottom: "#F97316" },
  { name: "Graphite", top: "#A1A1AA", bottom: "#52525B" },
];
const aiAppIcons = ["claude", "chatgpt", "gemini", "granola"].map((n) => `/assets/app-icons/${n}.png`);
type FaceStyle = "apps" | "symbol" | "emoji";

function CustomFace({ style, mono, tint, emojiSize }: { style: FaceStyle; mono: boolean; tint: Tint; emojiSize: number }) {
  if (style === "apps") return <AppGridFace icons={aiAppIcons} />;
  if (style === "emoji") return <EmojiFace emoji="✨" tint={tint} mono={mono} fontSize={emojiSize} />;
  return (
    <TileFace
      gradient={mono ? MONO_LIGHT : tintGradient(tint)}
      glyphColor={mono ? tint.bottom : "#ffffff"}
      darkGlyph={tint.top}
      glyph="sparkles"
      shaded
    />
  );
}

const choice =
  "pressable cursor-pointer transition-[background-color,box-shadow] duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500";

function CustomiserDemo({ colourLabel }: { colourLabel: string }) {
  const [style, setStyle] = React.useState<FaceStyle>("symbol");
  const [mono, setMono] = React.useState(false);
  const [tintIndex, setTintIndex] = React.useState(0);
  const tint = customTints[tintIndex];
  const glyphRows = style !== "apps"; // App Grid has no tint or background to pick

  const label = "mb-1.5 text-[11px] font-semibold text-zinc-500 dark:text-zinc-400";
  return (
    <ScaleToFit>
      <div className="flex w-125 items-center gap-6 text-zinc-800 dark:text-zinc-100">
        <div className="flex flex-1 flex-col items-center gap-3">
          <span className="flex h-32 w-32 drop-shadow-[0_2px_6px_rgba(0,0,0,0.25)]">
            <CustomFace style={style} mono={mono} tint={tint} emojiSize={64} />
          </span>
          <p className="text-[13px] font-semibold">AI Apps</p>
        </div>
        <div className="popover-surface flex w-65 flex-col gap-3.5 rounded-2xl p-3.5">
          <div>
            <p className={label}>Style</p>
            <div className="grid grid-cols-3 gap-1.5" role="group" aria-label="Style">
              {(
                [
                  ["apps", "App Grid"],
                  ["symbol", "Symbol"],
                  ["emoji", "Emoji"],
                ] as const
              ).map(([value, name]) => (
                <button
                  key={value}
                  type="button"
                  aria-pressed={style === value}
                  onClick={() => setStyle(value)}
                  className={`${choice} flex flex-col items-center gap-1 rounded-xl py-2 text-[11px] font-medium ${
                    style === value
                      ? "bg-white shadow-sm ring-2 ring-emerald-500 dark:bg-white/12"
                      : "bg-black/4 hover:bg-black/8 dark:bg-white/6 dark:hover:bg-white/10"
                  }`}
                >
                  <span className="flex h-8 w-8">
                    <CustomFace style={value} mono={mono} tint={tint} emojiSize={16} />
                  </span>
                  {name}
                </button>
              ))}
            </div>
          </div>
          <div className={`transition-opacity duration-200 ${glyphRows ? "" : "pointer-events-none opacity-35"}`} aria-disabled={!glyphRows}>
            <p className={label}>Background</p>
            <div className="grid grid-cols-2 gap-1 rounded-lg bg-black/5 p-0.5 dark:bg-white/8" role="group" aria-label="Background">
              {(
                [
                  [false, colourLabel],
                  [true, "Mono"],
                ] as const
              ).map(([value, name]) => (
                <button
                  key={name}
                  type="button"
                  disabled={!glyphRows}
                  aria-pressed={mono === value}
                  onClick={() => setMono(value)}
                  className={`${choice} rounded-md py-1 text-[11px] font-medium ${
                    mono === value ? "bg-white shadow-sm dark:bg-white/15" : "hover:bg-black/5 dark:hover:bg-white/8"
                  }`}
                >
                  {name}
                </button>
              ))}
            </div>
          </div>
          <div className={`transition-opacity duration-200 ${glyphRows ? "" : "pointer-events-none opacity-35"}`} aria-disabled={!glyphRows}>
            <p className={label}>{colourLabel}</p>
            <div className="flex justify-between px-1" role="group" aria-label={colourLabel}>
              {customTints.map((t, i) => (
                <button
                  key={t.name}
                  type="button"
                  disabled={!glyphRows}
                  aria-label={t.name}
                  aria-pressed={tintIndex === i}
                  onClick={() => setTintIndex(i)}
                  className={`${choice} h-5.5 w-5.5 rounded-full ${tintIndex === i ? "ring-2 ring-emerald-500 ring-offset-2 ring-offset-white dark:ring-offset-zinc-800" : ""}`}
                  style={{ background: tintGradient(t) }}
                />
              ))}
            </div>
          </div>
        </div>
      </div>
    </ScaleToFit>
  );
}

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

function DetailCard({
  icon: Icon,
  pill,
  title,
  lead,
  body,
  delay,
  children,
}: {
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
  pill: string;
  title: string;
  lead: string;
  body: string;
  delay: number;
  children: React.ReactNode;
}) {
  return (
    <Reveal delay={delay} className="flex flex-col gap-6 rounded-3xl border border-border bg-card p-6 md:p-8">
      <div>
        <span className="mb-4 inline-flex items-center gap-2 rounded-full border border-border px-3 py-1 text-[13px] font-semibold text-foreground">
          <Icon strokeWidth={1.75} className="h-4 w-4" />
          {pill}
        </span>
        <h3 className="max-w-md text-2xl font-semibold leading-[1.15] tracking-[-0.03em] text-foreground">{title}</h3>
      </div>
      <div className="flex flex-1 items-center justify-center rounded-2xl bg-muted px-5 py-8">{children}</div>
      <p className="max-w-lg text-[15px] leading-relaxed text-muted-foreground">
        <b className="font-semibold text-foreground">{lead}</b> {body}
      </p>
    </Reveal>
  );
}

export function DetailsSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section data-nav-section="features" className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-32">
      <Reveal className="mx-auto mb-14 max-w-180 text-center md:mb-16">
        <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
          {m.detailsEyebrow}
        </span>
        <h2 className="text-3xl font-semibold leading-[1.05] tracking-[-0.05em] text-foreground md:text-4xl">
          {m.detailsTitleA}{" "}
          {/* A tilted tile set into the line, as letters.app sets its logo. */}
          <span className="mx-0.5 inline-flex h-[1.1em] w-[1.1em] -rotate-6 align-[-0.2em] drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)]" aria-hidden>
            <TileFace gradient={menuTiles[0].gradient} darkGlyph={menuTiles[0].dark} glyph="sparkles" shaded />
          </span>{" "}
          {m.detailsTitleB}
        </h2>
      </Reveal>

      <div className="grid gap-6 lg:grid-cols-2">
        <DetailCard icon={Palette} pill={m.customPill} title={m.customTitle} lead={m.customLead} body={m.customBody} delay={0}>
          <CustomiserDemo colourLabel={m.customColour} />
        </DetailCard>
        <DetailCard icon={PanelTop} pill={m.menuBarPill} title={m.menuBarTitle} lead={m.menuBarLead} body={m.menuBarBody} delay={80}>
          <MenuBarMock />
        </DetailCard>
      </div>

      <ul className="mt-14 grid gap-x-8 gap-y-10 px-2 sm:grid-cols-2 md:mt-16 lg:grid-cols-4">
        {m.details.map((d, i) => {
          const Icon = detailIcons[i];
          return (
            <Reveal as="li" key={d.lead} delay={(i % 4) * 60} className="flex flex-col gap-3">
              <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-foreground/6 text-foreground">
                <Icon strokeWidth={1.5} className="h-4.5 w-4.5" />
              </span>
              <p className="text-[15px] leading-relaxed text-muted-foreground">
                <b className="font-semibold text-foreground">{d.lead}</b> {d.body}
              </p>
            </Reveal>
          );
        })}
      </ul>
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
    <section data-nav-tone="dark" data-nav-section="features" className="relative mx-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4">
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
