"use client";

import * as React from "react";
import {
  BatteryFull,
  Check,
  ChevronRight,
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
  Search,
  Plus,
  SlidersHorizontal,
  ShieldCheck,
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
// Order is load-bearing: the `app-switch-sel` keyframes (globals.css) and the
// name delays in the Ghost card ([0, 4.4, 0, 3.3, 2.2]) index these slots.
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
    <section id="features" data-nav-section="features" className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-50">
      {/* Stacked, Apple-style: the window is a three-pane app, so it needs the
          full content width to read — text centred above, screenshot below. */}
      <Reveal className="mx-auto mb-12 max-w-180 text-center md:mb-13">
        <h2 className="mx-auto mb-6 max-w-132 text-section text-foreground">
          {m.tilesTitle}
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
/* Built for the power user — Grid/List + Smart Add + Ghost, one bento */
/* ------------------------------------------------------------------ */

export function PowerUserSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section data-nav-section="features" className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-50">
      <Reveal className="mb-12 text-center md:mb-13">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          {m.bentoTitle}
        </h2>
      </Reveal>

      {/* 3-across only from xl up. Below that the row collapses to one column so
          each card is wide enough to hold its illustration at a FIXED, roomy
          native size (the Smart Add sheet and the right-click popover never
          reflow per breakpoint — they'd only cramp in a narrow 3-col card). */}
      <div className="grid gap-6 xl:grid-cols-3">
        {/* Smart Add — white card; the "Add a Tile" sheet + on-device note */}
        <Reveal className="mx-auto w-full max-w-md flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-6 md:p-10 xl:max-w-none">
          <div>
            <h3 className="mb-3 text-title-sm text-foreground">{m.smartAddTitle}</h3>
            <p className="max-w-md text-lead text-muted-foreground">{m.smartAddBody}</p>
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
        <Reveal delay={80} className="mx-auto w-full max-w-md flex flex-col justify-between gap-8 rounded-3xl border border-border bg-card p-6 md:p-10 xl:max-w-none">
          <div>
            <h3 className="mb-3 text-title-sm text-foreground">{m.itemMenuTitle}</h3>
            <p className="max-w-md text-lead text-muted-foreground">{m.itemMenuBody}</p>
          </div>
          <ItemMenuMock />
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
        <Reveal delay={160} className="relative mx-auto flex w-full max-w-md flex-col justify-between gap-8 overflow-hidden rounded-3xl bg-linear-to-b from-zinc-800 to-zinc-900 p-6 text-white md:p-10 xl:max-w-none">
          <div className="grain" />
          <div className="relative">
            <h3 className="mb-3 text-title-sm">{m.ghostTitle}</h3>
            <p className="max-w-md text-lead text-white/60">{m.ghostBody}</p>
          </div>
          {/* Cmd+Tab app switcher — the selection tabs across real apps and
              skips the ghosted Dock Tile slot */}
          <div className="relative flex flex-col items-center gap-4">
            {/* Concentric: the 12px slot radius + the 12px `p-3` inset ⇒ a 24px
                (rounded-3xl) shell. At rounded-2xl the shell's corners were
                tighter than the icon slots tucked into them. */}
            <div className="relative flex items-center gap-2 rounded-3xl border border-white/10 bg-white/[0.07] p-3 pb-8 backdrop-blur-xl">
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
              {/* The selected app's name, as macOS's switcher shows it. Each name fades
                  in under its own slot on the highlight's 5.5 s clock (negative delays
                  shift one keyframe to each slot's window); reduced motion rests on Finder. */}
              {switcherApps.map((app, i) =>
                app.ghost ? null : (
                  <span
                    key={`name-${app.name}`}
                    aria-hidden
                    className={`absolute bottom-2.5 -translate-x-1/2 whitespace-nowrap font-ui text-[12px] font-medium text-white/90 ${
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
/* Hidden in plain sight — two big cards + a row of small features    */
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
const detailIcons = [Keyboard, FolderOpen, LayoutGrid, Languages];

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

/* A tile's popover with an app's right-click menu (PopoverItemMenu):
   Open · Hide · Quit for a running app. Fixed 330×170 px. As in macOS,
   holding Option while the pointer is over it turns Quit into Force Quit. */
function ItemMenuMock() {
  const [hover, setHover] = React.useState(false);
  const [option, setOption] = React.useState(false);
  React.useEffect(() => {
    if (!hover) return;
    const sync = (e: KeyboardEvent) => setOption(e.altKey);
    const clear = () => setOption(false); // an Option release can land in another window
    window.addEventListener("keydown", sync);
    window.addEventListener("keyup", sync);
    window.addEventListener("blur", clear);
    return () => {
      window.removeEventListener("keydown", sync);
      window.removeEventListener("keyup", sync);
      window.removeEventListener("blur", clear);
    };
  }, [hover]);
  const forceQuit = hover && option;

  return (
    <div
      className="rounded-2xl bg-muted p-5"
      onPointerEnter={(e) => {
        setHover(true);
        setOption(e.altKey);
      }}
      onPointerMove={(e) => setOption(e.altKey)}
      onPointerLeave={() => setHover(false)}
    >
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
            <div className={`${menuRow} ${menuHighlight}`}>{forceQuit ? "Force Quit" : "Quit"}</div>
          </div>
        </div>
      </ScaleToFit>
    </div>
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

// Selection rings in this mock are macOS's system accent blue (#007AFF, Dark #0A84FF),
// not the site's emerald: it is a Mac inspector, and the app's own selection is blue.
const choice =
  "pressable cursor-pointer transition-[background-color,box-shadow] duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500";

// The idle walk-through: tints, Mono, Emoji, App Grid, back to the start.
const customiserScript: { style: FaceStyle; mono: boolean; tint: number }[] = [
  { style: "symbol", mono: false, tint: 0 },
  { style: "symbol", mono: false, tint: 1 },
  { style: "symbol", mono: false, tint: 2 },
  { style: "symbol", mono: true, tint: 2 },
  { style: "emoji", mono: true, tint: 2 },
  { style: "emoji", mono: false, tint: 3 },
  { style: "apps", mono: false, tint: 3 },
  { style: "symbol", mono: false, tint: 4 },
];

function CustomiserDemo({ colourLabel }: { colourLabel: string }) {
  const [style, setStyle] = React.useState<FaceStyle>("symbol");
  const [mono, setMono] = React.useState(false);
  const [tintIndex, setTintIndex] = React.useState(0);
  const tint = customTints[tintIndex];
  const glyphRows = style !== "apps"; // App Grid has no tint or background to pick

  // Idle walk-through, the Docks' ethos: plays while on screen, pauses on hover,
  // and the first real click, tap or focus hands it over for good — resuming
  // later would overwrite the visitor's own choices. Off under reduced motion.
  const rootRef = React.useRef<HTMLDivElement>(null);
  const stepRef = React.useRef(0);
  const [inView, setInView] = React.useState(false);
  const [hovered, setHovered] = React.useState(false);
  const [handedOver, setHandedOver] = React.useState(false);
  const [reduced, setReduced] = React.useState(true);
  React.useEffect(() => {
    setReduced(window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    const root = rootRef.current;
    if (!root) return;
    const io = new IntersectionObserver(([e]) => setInView(e.isIntersecting), { threshold: 0.6 });
    io.observe(root);
    return () => io.disconnect();
  }, []);
  React.useEffect(() => {
    if (!inView || hovered || handedOver || reduced) return;
    const t = window.setInterval(() => {
      stepRef.current = (stepRef.current + 1) % customiserScript.length;
      const s = customiserScript[stepRef.current];
      setStyle(s.style);
      setMono(s.mono);
      setTintIndex(s.tint);
    }, 1700);
    return () => window.clearInterval(t);
  }, [inView, hovered, handedOver, reduced]);

  const label = "mb-1.5 text-[11px] font-semibold text-zinc-500 dark:text-zinc-400";
  return (
    <ScaleToFit>
      <div
        ref={rootRef}
        className="flex w-125 font-ui items-center gap-6 text-zinc-800 dark:text-zinc-100"
        onPointerEnter={(e) => e.pointerType === "mouse" && setHovered(true)}
        onPointerLeave={() => setHovered(false)}
        onPointerDownCapture={() => setHandedOver(true)}
        onFocusCapture={() => setHandedOver(true)}
      >
        <div className="flex flex-1 flex-col items-center gap-3">
          <span
            // re-keyed per look so each change eases in rather than snapping
            key={`${style}-${mono}-${tintIndex}`}
            className="flex h-32 w-32 drop-shadow-[0_2px_6px_rgba(0,0,0,0.25)]"
            style={reduced ? undefined : { animation: "face-swap 280ms cubic-bezier(0.16, 1, 0.3, 1)" }}
          >
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
              ).map(([value, name]) => {
                const on = style === value;
                return (
                  <button
                    key={value}
                    type="button"
                    aria-pressed={on}
                    onClick={() => setStyle(value)}
                    className={`${choice} relative flex flex-col items-center gap-1 rounded-lg py-2 text-[11px] font-medium ${
                      on
                        ? "bg-white shadow-sm ring-2 ring-[#007AFF] dark:bg-white/12 dark:ring-[#0A84FF]"
                        : "bg-black/4 hover:bg-black/8 dark:bg-white/6 dark:hover:bg-white/10"
                    }`}
                  >
                    <span className="flex h-8 w-8">
                      <CustomFace style={value} mono={mono} tint={tint} emojiSize={16} />
                    </span>
                    {name}
                    {/* the app's selected-card badge: a blue ✓ on the corner */}
                    {on && (
                      <span className="absolute -right-1 -top-1 flex h-4.5 w-4.5 items-center justify-center rounded-full bg-[#007AFF] ring-2 ring-white dark:bg-[#0A84FF] dark:ring-zinc-800">
                        <Check strokeWidth={3.5} className="h-2.5 w-2.5 text-white" />
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>
          <div className={`transition-opacity duration-200 ${glyphRows ? "" : "pointer-events-none opacity-35"}`} aria-disabled={!glyphRows}>
            <p className={label}>Background</p>
            <div className="grid grid-cols-2 gap-1.5" role="group" aria-label="Background">
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
                  className={`${choice} flex items-center gap-2 rounded-sm px-2 py-1.5 text-[11px] font-medium ${
                    mono === value
                      ? "bg-white shadow-sm ring-2 ring-[#007AFF] dark:bg-white/12 dark:ring-[#0A84FF]"
                      : "bg-black/4 hover:bg-black/8 dark:bg-white/6 dark:hover:bg-white/10"
                  }`}
                >
                  <span className="flex h-5 w-5 shrink-0">
                    <CustomFace style={style === "apps" ? "symbol" : style} mono={value} tint={tint} emojiSize={10} />
                  </span>
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
                  className={`${choice} flex h-5.5 w-5.5 items-center justify-center rounded-full`}
                  style={{ background: tintGradient(t) }}
                >
                  {tintIndex === i && <Check strokeWidth={3.5} className="h-3 w-3 text-white" />}
                </button>
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
    <Reveal delay={delay} className="flex flex-col gap-6 rounded-3xl border border-border bg-card p-6 md:p-10">
      <div>
        <span className="mb-5 inline-flex h-8 items-center gap-1.5 rounded-full border border-border pl-3 pr-3.5 text-sm font-semibold text-foreground">
          <Icon strokeWidth={1.75} className="h-4 w-4" />
          {pill}
        </span>
        <h3 className="text-title text-foreground">{title}</h3>
      </div>
      <div className="flex flex-1 items-center justify-center rounded-2xl bg-muted px-5 py-8">{children}</div>
      <p className="max-w-lg text-lead text-muted-foreground">
        <b className="font-semibold text-foreground">{lead}</b> {body}
      </p>
    </Reveal>
  );
}

export function DetailsSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    // Follows the light custom-tiles story: no top padding, its bottom padding is the gap.
    <section data-nav-section="features" className="mx-auto max-w-400 px-4 pb-24 sm:px-6 md:px-10 md:pb-50">
      <Reveal className="mx-auto mb-12 max-w-180 text-center md:mb-13">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          {m.detailsTitleA}{" "}
          {/* A tilted tile set into the line. */}
          {/* overflow-hidden pins the inline-block's baseline to its bottom edge
              (otherwise it is synthesised from the face inside and the tile hung
              12px low), so the offset is exact: -0.19em centres the 1.1em tile on
              Open Runde's cap height, 0.727/2 - 1.1/2. The face is inset, so the
              clip never cuts it; the shadow is a filter on this span, not clipped. */}
          <span className="mx-0.5 inline-block h-[1.1em] w-[1.1em] overflow-hidden -rotate-6 align-[-0.19em] drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)]" aria-hidden>
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
            // Four short items under the big cards: the name on its own line, then
            // one muted sentence, at the section body size (text-lead).
            <Reveal as="li" key={d.lead} delay={i * 60} className="flex flex-col">
              <span className="mb-4 flex h-9 w-9 items-center justify-center rounded-xl bg-foreground/6 text-foreground">
                <Icon strokeWidth={1.5} className="h-4.5 w-4.5" />
              </span>
              <p className="text-lead font-medium text-foreground">{d.lead}</p>
              <p className="mt-1 text-lead text-muted-foreground">{d.body}</p>
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
          <h2 className="mb-6 text-section text-white">
            {m.dockLockTitle}
          </h2>
          <p className="max-w-lg text-lead text-white/60">
            {m.dockLockBody}
          </p>
        </Reveal>
      </div>
    </section>
  );
}
