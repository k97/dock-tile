"use client";

import * as React from "react";
import Image from "next/image";
import { Settings2 } from "lucide-react";
import { MacOSDock, type DockApp } from "@/components/ui/mac-os-dock";
import { TileGlyph, type GlyphName } from "@/components/tile-glyph";
import { DemoCursor, useDockShowcase } from "@/components/dock-showcase";
import { asset } from "@/lib/assets";
import { anchorPopover } from "@/lib/dock-popover";

/**
 * DockTile hero demo — the interactive macOS Dock (magnification, click bounce)
 * is the shadcn.io `MacOSDock` component; this wrapper supplies DockTile's own
 * tiles + system icons and renders the grid/list popover that pops up out of a
 * clicked tile, anchored to that icon (the app's carefully-tuned effect).
 */

// darkSrc: the app's own Dark icon-style rendition, shown in dark theme (CSS swap, right on frame 1).
type DemoApp = { name: string; src: string; darkSrc?: string };

type DemoTile = {
  id: string;
  name: string;
  glyph: GlyphName;
  gradient: string; // colorTop → colorBottom, per product palette
  darkGlyph: string; // lifted tint used as the glyph colour in Dark icon style
  apps: DemoApp[];
  layout?: "grid" | "list"; // per-tile, like the app's layoutMode
};

// DockTile's own Dark icon style (neutral near-black background, tint moves to
// the glyph — see docs/rules/icon-system.md) is the shared `.tile-face` rule in
// globals.css, keyed off the pre-paint `.dark` class so tiles render the right
// theme on the first frame.

// Popover widths per product spec: grid = 5-col medium tier, list = medium 240pt
const GRID_WIDTH = 324;
const LIST_WIDTH = 240;
const widthFor = (tile: DemoTile | null) =>
  tile?.layout === "list" ? LIST_WIDTH : GRID_WIDTH;

const TILES: DemoTile[] = [
  {
    id: "ai",
    name: "AI Apps",
    glyph: "sparkles",
    gradient: "linear-gradient(to bottom, #A78BFF, #7C3AED)",
    darkGlyph: "#A78BFF",
    apps: [
      { name: "Claude", src: "/assets/app-icons/claude.png" },
      { name: "Gemini", src: "/assets/app-icons/gemini.png" },
      { name: "ChatGPT", src: "/assets/app-icons/chatgpt.png" },
      { name: "Granola", src: "/assets/app-icons/granola.png" },
      { name: "superwhisper", src: "/assets/app-icons/superwhisper.png" },
      { name: "Wispr Flow", src: "/assets/app-icons/wispr-flow.png" },
    ],
  },
  {
    id: "dev",
    name: "Dev Apps",
    glyph: "tools",
    gradient: "linear-gradient(to bottom, #4AA8FF, #0A6FE8)",
    darkGlyph: "#4AA8FF",
    apps: [
      { name: "Code", src: "/assets/app-icons/vscode.png" },
      { name: "GitHub", src: "/assets/app-icons/github.png" },
      { name: "Xcode", src: "/assets/app-icons/xcode.png" },
      { name: "Warp", src: "/assets/app-icons/warp.png" },
      { name: "Ghostty", src: "/assets/app-icons/ghostty.png" },
      { name: "Screenshot", src: "/assets/app-icons/screenshot.png" },
    ],
  },
  {
    id: "comms",
    name: "Comms",
    glyph: "chat",
    gradient: "linear-gradient(to bottom, #52DFA8, #10B981)",
    darkGlyph: "#52DFA8",
    apps: [
      { name: "WhatsApp", src: "/assets/app-icons/whatsapp.png" },
      { name: "Slack", src: "/assets/app-icons/slack.png" },
      { name: "Meet", src: "/assets/app-icons/google-meet.png" },
      { name: "Messages", src: "/assets/app-icons/messages.png" },
      { name: "FaceTime", src: "/assets/app-icons/facetime.png" },
      { name: "Teams", src: "/assets/app-icons/msteams.png" },
    ],
  },
  {
    id: "media",
    name: "Media",
    glyph: "tv",
    gradient: "linear-gradient(to bottom, #FF7AAE, #EC3E7C)",
    darkGlyph: "#FF7AAE",
    layout: "list",
    apps: [
      { name: "Music", src: "/assets/app-icons/music.png?v=2", darkSrc: "/assets/app-icons/music-dark.png?v=1" },
      { name: "Podcasts", src: "/assets/app-icons/podcasts.png" },
      { name: "Netflix", src: "/assets/app-icons/netflix.png" },
      { name: "Apple TV", src: "/assets/app-icons/appletv.png" },
    ],
  },
];

// Finder/Settings PNGs carry ~9.4% of transparent bleed baked into their
// canvas (measured: 116px of content in a 128px square) — real macOS icon
// art is never full-bleed. Without matching that inset, the custom tile
// squircles rendered noticeably larger than the real icons beside them in
// the Dock. This is the exact same ratio in both themes, on purpose: it's a
// layout fact of the icon art, not a color-mode concern.
export const ICON_CONTENT_RATIO = "90.625%";

/* A DockTile tile face — gradient squircle + glyph, inset to match the real
   Finder/Settings icons' safe area (see ICON_CONTENT_RATIO above).
   Dark icon style (matches the real app): background flattens to a neutral
   near-black, and the tile's own tint moves to the glyph instead. All of the
   theming is CSS (`.tile-face` + `dark:` variants) off the pre-paint `.dark`
   class, so a dark-theme load never flashes the light face. */
export function TileFace({
  gradient,
  darkGlyph,
  glyph,
  glyphColor = "#ffffff",
  glyphSize = "58%",
  shaded = false,
}: {
  gradient: string;
  darkGlyph: string;
  glyph: GlyphName;
  /** Light-theme glyph colour (white by default; dark on a Mono plate). */
  glyphColor?: string;
  /** Glyph box as a share of the tile — padded SVGs need more than 58%. */
  glyphSize?: string;
  /** Top→bottom glyph shading, as the app's own icons bake it. */
  shaded?: boolean;
}) {
  return (
    <div className="relative flex h-full w-full items-center justify-center">
      <div
        // Dark: the glass rim macOS 26 draws — a lit 1px edge at the top, a
        // fainter one at the bottom, a hairline all round (sampled from Mail.app).
        className="tile-face squircle relative flex items-center justify-center overflow-hidden shadow-[inset_0_1px_1px_rgba(255,255,255,0.35),inset_0_-1px_2px_rgba(0,0,0,0.12)] dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.12),inset_0_-1px_0_rgba(255,255,255,0.05),inset_0_0_0_0.5px_rgba(255,255,255,0.06)]"
        style={
          {
            width: ICON_CONTENT_RATIO,
            height: ICON_CONTENT_RATIO,
            "--tile-bg": gradient,
            "--tile-glyph-light": glyphColor,
            "--tile-glyph-dark": darkGlyph,
          } as React.CSSProperties
        }
      >
        {/* top gloss — light theme only; the Dark icon style is matte */}
        <span
          aria-hidden
          className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/25 to-transparent dark:hidden"
        />
        <span className="relative" style={{ width: glyphSize, height: glyphSize }}>
          <TileGlyph
            name={glyph}
            shaded={shaded}
            // Dark: the tinted glyph glows onto the plate instead of casting a
            // shadow, as macOS 26 Dark-style icons do (Mail's envelope, Finder).
            className="h-full w-full text-(--tile-glyph-light) drop-shadow-[0_1px_1.5px_rgba(0,0,0,0.28)] dark:text-(--tile-glyph-dark) dark:drop-shadow-[0_0_5px_color-mix(in_srgb,var(--tile-glyph-dark)_45%,transparent)]"
          />
        </span>
      </div>
    </div>
  );
}

/* Both renditions render; CSS shows the one matching the pre-paint `.dark`
   class, so the right icon is up on the first frame (no post-mount rebuild).
   The hidden twin's extra fetch is a ~6KB PNG — accepted. */
const iconFace = (lightSrc: string, darkSrc: string) => (
  <>
    <Image
      src={asset(lightSrc)}
      alt=""
      fill
      sizes="96px"
      priority
      unoptimized
      draggable={false}
      className="object-contain dark:hidden"
    />
    <Image
      src={asset(darkSrc)}
      alt=""
      fill
      sizes="96px"
      priority
      unoptimized
      draggable={false}
      className="hidden object-contain dark:block"
    />
  </>
);

// Dock line-up: Finder · the four tiles · System Settings. Static — every
// face carries both its Light and Dark icon-style renditions (see
// docs/rules/icon-system.md) and CSS picks per theme.
const APPS: DockApp[] = [
  // Finder/Settings PNGs are cropped to their solid squircle (full-bleed), so the
  // visible icon fills the box at the same 64px the tile squircles do — the raw
  // macOS icons bake ~8% shadow/keyline padding that shrank them otherwise. ?v=3
  // busts any cache of the earlier padded versions.
  {
    id: "finder",
    name: "Finder",
    content: iconFace("/assets/app-icons/finder.png?v=3", "/assets/app-icons/finder-dark.png?v=4"),
  },
  ...TILES.map((t) => ({ id: t.id, name: t.name, content: <TileFace gradient={t.gradient} darkGlyph={t.darkGlyph} glyph={t.glyph} shaded /> })),
  {
    id: "settings",
    name: "System Settings",
    content: iconFace("/assets/app-icons/settings.png?v=3", "/assets/app-icons/settings-dark.png?v=1"),
  },
];

const TILE_ID_LIST = TILES.map((t) => t.id);
const TILE_IDS = new Set(TILE_ID_LIST);

export function DockDemo({ className = "" }: { className?: string }) {
  const [openId, setOpenId] = React.useState<string | null>(null);
  const [closing, setClosing] = React.useState(false);
  const [launching, setLaunching] = React.useState<string | null>(null);
  const [focusIndex, setFocusIndex] = React.useState(-1);
  const [reduced, setReduced] = React.useState(false);
  const [pos, setPos] = React.useState({
    left: 0,
    arrow: GRID_WIDTH / 2,
    bottom: 0,
    width: GRID_WIDTH,
  });

  const rootRef = React.useRef<HTMLDivElement>(null);
  // Pointer type of the interaction in flight — click handlers fire after the
  // pointer events and need it to decide the touch-only resume paths.
  const lastPointerTypeRef = React.useRef("mouse");

  const openTile = TILES.find((t) => t.id === openId) ?? null;

  // Anchor a tile's popover to its icon (centre over the icon; clamp to viewport;
  // sit just above the icon's top — holds even while the icon is magnified).
  // Width rides in `pos` because narrow phones clamp it below the product tier.
  const anchor = React.useCallback((id: string, rect: DOMRect | null) => {
    const root = rootRef.current;
    const tile = TILES.find((t) => t.id === id);
    if (!root || !rect || !tile) return false;
    const rootBox = root.getBoundingClientRect();
    if (rootBox.width === 0) return false;
    setPos(
      anchorPopover({
        iconRect: rect,
        rootRect: rootBox,
        width: widthFor(tile),
        viewportWidth: window.innerWidth,
      }),
    );
    return true;
  }, []);

  // Pending close-animation timer. open() must cancel it: a reopen during the
  // 200ms scale-out otherwise hits the stale timeout, which shuts the NEW
  // popover the moment it appears.
  const closeTimerRef = React.useRef(0);

  const open = React.useCallback(
    (id: string, rect: DOMRect | null) => {
      if (!anchor(id, rect)) return;
      if (closeTimerRef.current) {
        window.clearTimeout(closeTimerRef.current);
        closeTimerRef.current = 0;
      }
      setClosing(false);
      setOpenId(id);
      setFocusIndex(-1);
    },
    [anchor],
  );

  const close = React.useCallback(() => {
    setClosing(true);
    if (closeTimerRef.current) window.clearTimeout(closeTimerRef.current);
    closeTimerRef.current = window.setTimeout(() => {
      closeTimerRef.current = 0;
      setOpenId(null);
      setClosing(false);
      setFocusIndex(-1);
    }, 200); // matches the scale-out duration
  }, []);

  // Configure (the gear in the grid header / the "Configure…" list row) stands
  // in for the real app's deep link into Tile Detail: on the site it walks you
  // to the first feature story instead.
  const configure = React.useCallback(() => {
    close();
    document
      .getElementById("features")
      ?.scrollIntoView({ behavior: reduced ? "auto" : "smooth", block: "start" });
  }, [close, reduced]);

  // Idle auto-showcase (dock-showcase.tsx): the cursor clicks a random tile and
  // holds its popover a beat before moving on.
  const { stop: stopAuto, resume: resumeAuto, ...demo } = useDockShowcase({
    rootRef,
    ids: TILE_ID_LIST,
    enabled: !reduced,
    land: (id, el) => {
      // Re-read the tile rect NOW (not the ~1s-old one from step start): the
      // anchor pairs it with a fresh rootBox, so any scroll/layout shift during
      // the cursor's travel would otherwise fling the popover off-dock.
      open(id, el.getBoundingClientRect());
      return true;
    },
    release: close,
  });

  // Reduced-motion probe.
  React.useEffect(() => {
    setReduced(window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  }, []);

  // Outside-click + Escape dismiss. A touch dismiss also re-arms the showcase:
  // unlike a mouse, a finger is never "hovering" the demo afterwards, so
  // pointerleave will never fire to do it.
  React.useEffect(() => {
    if (!openId) return;
    const onPointerDown = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) {
        close();
        if (e.pointerType !== "mouse") resumeAuto();
      }
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [openId, close, resumeAuto]);

  const handleAppClick = (id: string, rect: DOMRect | null) => {
    if (!TILE_IDS.has(id)) return; // Finder / Settings: tooltip only, no popover
    stopAuto(); // hard-stop the showcase so clicks never conflict
    if (openId === id) {
      close();
      // Toggle-close by touch: stopAuto just swallowed the tap-up's pending
      // resume, and no pointerleave is coming — re-arm here or the showcase
      // stays dead for good.
      if (lastPointerTypeRef.current !== "mouse") resumeAuto();
    } else {
      open(id, rect);
    }
  };

  const handleLaunch = (appName: string) => {
    setLaunching(appName);
    window.setTimeout(() => {
      setLaunching(null);
      close();
    }, 260);
  };

  const handlePopoverKeys = (e: React.KeyboardEvent) => {
    if (!openTile) return;
    const cols = openTile.layout === "list" ? 1 : 4;
    const count = openTile.apps.length;
    let next = focusIndex;
    if (e.key === "ArrowRight") next = Math.min(count - 1, focusIndex + 1);
    else if (e.key === "ArrowLeft") next = Math.max(0, focusIndex - 1);
    else if (e.key === "ArrowDown") next = Math.min(count - 1, focusIndex + cols);
    else if (e.key === "ArrowUp") next = Math.max(0, focusIndex - cols);
    else if (e.key === "Enter" && focusIndex >= 0) {
      handleLaunch(openTile.apps[focusIndex].name);
      return;
    } else return;
    e.preventDefault();
    setFocusIndex(next < 0 ? 0 : next);
  };

  // Popover motion — Apple-style scale-pop from the tile (subtle overshoot +
  // fade), plain quick fade under reduced motion.
  const animIn = reduced
    ? "dock-pop-in 180ms var(--ease-out-strong)"
    : "dock-scale-in 260ms cubic-bezier(0.22, 1, 0.36, 1)";
  const animOut = reduced
    ? "dock-pop-out 140ms var(--ease-out-strong) forwards"
    : "dock-scale-out 190ms cubic-bezier(0.4, 0, 1, 1) forwards";

  return (
    <div
      ref={rootRef}
      className={`relative inline-block ${className}`}
      // Any pointer coming in hard-stops the showcase. Resuming is per-type:
      // a mouse resumes when it LEAVES (hover semantics); touch has no hover —
      // its pointerleave fires right after every tap-up, which would let the
      // showcase barge back while the user reads the popover they just opened.
      // Touch instead resumes on tap-up / cancelled tap (scroll), and open()
      // via handleAppClick stop-cancels the pending resume when a tap opened a
      // popover, so it stays up until the user dismisses it.
      onPointerDownCapture={(e) => {
        lastPointerTypeRef.current = e.pointerType;
      }}
      onPointerEnter={() => stopAuto()}
      onPointerLeave={(e) => {
        if (e.pointerType === "mouse") resumeAuto();
      }}
      onPointerUp={(e) => {
        if (e.pointerType !== "mouse") resumeAuto();
      }}
      onPointerCancel={(e) => {
        if (e.pointerType !== "mouse") resumeAuto();
      }}
    >
      {/* Popover — anchored above the clicked tile */}
      {openTile && (
        <div
          role="dialog"
          aria-label={`${openTile.name} apps`}
          onKeyDown={handlePopoverKeys}
          className={`popover-surface absolute z-30 rounded-2xl ${
            openTile.layout === "list" ? "p-2" : "p-3 pt-0"
          }`}
          style={{
            width: pos.width,
            left: pos.left,
            bottom: pos.bottom,
            transformOrigin: `${pos.arrow}px 100%`,
            animation: closing ? animOut : animIn,
          }}
        >
          {openTile.layout === "list" ? (
            <>
              <p className="px-3 pb-1 pt-1.5 text-[13px] font-semibold text-zinc-800 dark:text-zinc-100">
                {openTile.name}
              </p>
              <div className="flex flex-col">
                {openTile.apps.map((app, i) => {
                  const isFocused = i === focusIndex;
                  const isLaunching = launching === app.name;
                  return (
                    <button
                      key={app.name}
                      type="button"
                      onClick={() => handleLaunch(app.name)}
                      onFocus={() => setFocusIndex(i)}
                      className={`flex min-h-7 items-center gap-2.5 rounded px-3 py-1 text-left outline-none transition-colors duration-150 [&:active_img]:brightness-[0.72] ${
                        isFocused ? "bg-black/10 dark:bg-white/15" : "hover:bg-black/5 dark:hover:bg-white/10"
                      }`}
                      style={{
                        animation: `dock-app-in 240ms var(--ease-out-strong) both`,
                        animationDelay: `${i * 30}ms`,
                      }}
                    >
                      {(app.darkSrc ? [app.src, app.darkSrc] : [app.src]).map((src, v) => (
                        <Image
                          key={src}
                          src={asset(src)}
                          alt=""
                          width={24}
                          height={24}
                          priority
                          unoptimized
                          className={`h-6 w-6 transition-transform duration-200 ${isLaunching ? "scale-90" : ""} ${
                            app.darkSrc ? (v === 0 ? "dark:hidden" : "hidden dark:block") : ""
                          }`}
                          draggable={false}
                        />
                      ))}
                      <span className="truncate text-[13px] text-zinc-800 dark:text-zinc-100">
                        {app.name}
                      </span>
                    </button>
                  );
                })}
              </div>
              <div className="mx-3 my-1 border-t border-black/10 dark:border-white/10" />
              <button
                type="button"
                onClick={configure}
                className="flex w-full items-center gap-2.5 rounded px-3 py-1 text-left text-[13px] text-zinc-700 outline-none transition-colors duration-150 hover:bg-black/5 dark:text-zinc-300 dark:hover:bg-white/10"
              >
                <Settings2 className="h-3 w-4 text-zinc-500 dark:text-zinc-400" />
                Configure…
              </button>
            </>
          ) : (
            <>
              <header className="flex h-9 items-center justify-between px-1">
                <span className="w-7" />
                <span className="text-[13px] font-medium text-zinc-800 dark:text-zinc-100">
                  {openTile.name}
                </span>
                <button
                  type="button"
                  aria-label="Configure Tile"
                  title="Configure Tile"
                  onClick={configure}
                  className="flex h-7 w-7 items-center justify-center rounded-md text-zinc-500 transition-colors hover:bg-black/5 dark:text-zinc-400 dark:hover:bg-white/10"
                >
                  <Settings2 className="h-3.5 w-3.5" />
                </button>
              </header>

              <div className="grid grid-cols-4 gap-x-1 gap-y-3 px-1 pb-1 pt-1">
                {openTile.apps.map((app, i) => {
                  const isFocused = i === focusIndex;
                  const isLaunching = launching === app.name;
                  return (
                    <button
                      key={app.name}
                      type="button"
                      onClick={() => handleLaunch(app.name)}
                      onFocus={() => setFocusIndex(i)}
                      className={`group/app flex flex-col items-center gap-1.5 rounded-lg p-1.5 outline-none transition-colors duration-150 [&:active_img]:brightness-[0.72] ${
                        isFocused ? "bg-black/10 dark:bg-white/15" : "hover:bg-black/5 dark:hover:bg-white/10"
                      }`}
                      style={{
                        animation: `dock-app-in 240ms var(--ease-out-strong) both`,
                        animationDelay: `${i * 35}ms`,
                      }}
                    >
                      {(app.darkSrc ? [app.src, app.darkSrc] : [app.src]).map((src, v) => (
                        <Image
                          key={src}
                          src={asset(src)}
                          alt=""
                          width={48}
                          height={48}
                          priority
                          unoptimized
                          className={`h-12 w-12 transition-transform duration-200 ${isLaunching ? "scale-90" : ""} ${
                            app.darkSrc ? (v === 0 ? "dark:hidden" : "hidden dark:block") : ""
                          }`}
                          draggable={false}
                        />
                      ))}
                      <span className="max-w-full truncate text-[11px] leading-none text-zinc-600 dark:text-zinc-300">
                        {app.name}
                      </span>
                    </button>
                  );
                })}
              </div>
            </>
          )}

          {/* Arrow — wide shallow triangle, at the clicked tile's centre */}
          <span
            aria-hidden
            className="popover-surface absolute top-full h-2.5 w-6 border-0! shadow-none!"
            style={{
              left: pos.arrow - 12,
              marginTop: -1,
              clipPath: "polygon(0 0, 100% 0, 50% 100%)",
            }}
          />
        </div>
      )}

      <MacOSDock apps={APPS} onAppClick={handleAppClick} openApps={[]} />

      <DemoCursor {...demo} />
    </div>
  );
}
