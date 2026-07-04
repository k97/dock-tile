"use client";

import * as React from "react";
import Image from "next/image";
import {
  Sparkles,
  Wrench,
  MessagesSquare,
  Tv,
  Settings2,
  type LucideIcon,
} from "lucide-react";

/**
 * Interactive simulation of DockTile's core loop: click a Dock tile, the
 * app popover opens above it. Geometry and timing mirror the real app
 * (see .superdesign/refs/product-demo-spec.md):
 * - tiles: squircle, 22.5% radius, top→bottom tint gradient, glyph sheen
 * - popover: 4-col grid, centred title + gear, 11px labels, bottom arrow
 * - motion: 200ms strong ease-out entry from the tile, faster exit
 * The tile data is real — these are actual tiles from a production Mac.
 */

type DemoApp = { name: string; src: string };

type DemoTile = {
  id: string;
  name: string;
  icon: LucideIcon;
  gradient: string; // colorTop → colorBottom, per product palette
  apps: DemoApp[];
  layout?: "grid" | "list"; // per-tile, like the app's layoutMode
};

// Popover widths per product spec: grid = 5-col medium tier, list = medium 240pt
const GRID_WIDTH = 324;
const LIST_WIDTH = 240;
const widthFor = (tile: DemoTile | null) =>
  tile?.layout === "list" ? LIST_WIDTH : GRID_WIDTH;

const TILES: DemoTile[] = [
  {
    id: "ai",
    name: "AI Apps",
    icon: Sparkles,
    gradient: "linear-gradient(to bottom, #FF8EA7, #FF5482)",
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
    icon: Wrench,
    gradient: "linear-gradient(to bottom, #B197FC, #AF52DE)",
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
    icon: MessagesSquare,
    gradient: "linear-gradient(to bottom, #FFD666, #FFB900)",
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
    icon: Tv,
    gradient: "linear-gradient(to bottom, #66E5FF, #00CFFC)",
    layout: "list",
    apps: [
      { name: "Music", src: "/assets/app-icons/music.png" },
      { name: "Podcasts", src: "/assets/app-icons/podcasts.png" },
      { name: "Netflix", src: "/assets/app-icons/netflix.png" },
      { name: "Apple TV", src: "/assets/app-icons/appletv.png" },
    ],
  },
];

export function DockDemo({ className = "" }: { className?: string }) {
  const [openId, setOpenId] = React.useState<string | null>(null);
  const [closing, setClosing] = React.useState(false);
  const [launching, setLaunching] = React.useState<string | null>(null);
  const [focusIndex, setFocusIndex] = React.useState(-1);
  const rootRef = React.useRef<HTMLDivElement>(null);
  const tileRefs = React.useRef<Record<string, HTMLButtonElement | null>>({});
  // Arrow x-position inside the popover (popover body stays centred; only
  // the arrow tracks the clicked tile — the app's anchor-and-hold behaviour).
  // Popover body centres over the clicked tile (clamped to the viewport);
  // the arrow sits at the tile centre — like NSPopover's anchoring.
  const [pos, setPos] = React.useState({ left: 0, arrow: GRID_WIDTH / 2 });

  const openTile = TILES.find((t) => t.id === openId) ?? null;
  const popWidth = widthFor(openTile);

  const measure = React.useCallback(() => {
    if (!openId || !rootRef.current) return;
    const tile = tileRefs.current[openId];
    if (!tile) return;
    const width = widthFor(TILES.find((t) => t.id === openId) ?? null);
    const rootBox = rootRef.current.getBoundingClientRect();
    if (rootBox.width === 0) return; // not laid out yet
    const tileBox = tile.getBoundingClientRect();
    const tileCentre = tileBox.left + tileBox.width / 2 - rootBox.left;
    let left = tileCentre - width / 2;
    // keep the popover on-screen with an 8px gutter
    const minLeft = 8 - rootBox.left;
    const maxLeft = window.innerWidth - 8 - width - rootBox.left;
    left = Math.max(minLeft, Math.min(left, maxLeft));
    setPos({ left, arrow: tileCentre - left });
  }, [openId]);

  // Position on open, and keep it correct as the layout shifts (resize,
  // the hero reveal animation settling, late-loading app icons).
  React.useLayoutEffect(() => {
    measure();
    if (!openId) return;
    window.addEventListener("resize", measure);
    const raf = requestAnimationFrame(measure); // after paint settles
    return () => {
      window.removeEventListener("resize", measure);
      cancelAnimationFrame(raf);
    };
  }, [openId, measure]);

  const close = React.useCallback(() => {
    setClosing(true);
    window.setTimeout(() => {
      setOpenId(null);
      setClosing(false);
      setFocusIndex(-1);
    }, 140);
  }, []);

  // Transient behaviour: outside click and Escape dismiss.
  React.useEffect(() => {
    if (!openId) return;
    const onPointerDown = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) close();
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
  }, [openId, close]);

  const handleTileClick = (id: string) => {
    if (openId === id) {
      close();
    } else {
      setOpenId(id);
      setFocusIndex(-1);
    }
  };

  const handleLaunch = (appName: string) => {
    setLaunching(appName);
    window.setTimeout(() => {
      setLaunching(null);
      close();
    }, 260);
  };

  // Arrow-key navigation inside the open popover (grid: ±1 / ±cols; list: ±1).
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

  return (
    <div ref={rootRef} className={`relative inline-block ${className}`}>
      {/* Popover */}
      {openTile && (
        <div
          role="dialog"
          aria-label={`${openTile.name} apps`}
          onKeyDown={handlePopoverKeys}
          className={`absolute bottom-full z-30 mb-4 rounded-2xl popover-surface ${
            openTile.layout === "list" ? "p-2" : "p-3 pt-0"
          }`}
          style={{
            width: popWidth,
            left: pos.left,
            transformOrigin: `${pos.arrow}px 100%`,
            animation: closing
              ? "dock-pop-out 140ms var(--ease-out-strong) forwards"
              : "dock-pop-in 200ms var(--ease-out-strong)",
          }}
        >
          {openTile.layout === "list" ? (
            <>
              {/* List layout — leading title, rows, divider, utility rows */}
              <p className="px-3 pb-1 pt-1.5 text-[13px] font-semibold text-zinc-800">
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
                      className={`flex min-h-7 items-center gap-2.5 rounded px-3 py-1 text-left outline-none transition-colors duration-150 ${
                        isFocused ? "bg-black/10" : "hover:bg-black/5"
                      }`}
                      style={{
                        animation: `dock-app-in 240ms var(--ease-out-strong) both`,
                        animationDelay: `${i * 30}ms`,
                      }}
                    >
                      <Image
                        src={app.src}
                        alt=""
                        width={24}
                        height={24}
                        priority
                        unoptimized
                        className={`h-6 w-6 transition-transform duration-200 ${
                          isLaunching ? "scale-90" : ""
                        }`}
                        draggable={false}
                      />
                      <span className="truncate text-[13px] text-zinc-800">
                        {app.name}
                      </span>
                    </button>
                  );
                })}
              </div>
              <div className="mx-3 my-1 border-t border-black/10" />
              <button
                type="button"
                onClick={close}
                className="flex w-full items-center gap-2.5 rounded px-3 py-1 text-left text-[13px] text-zinc-700 outline-none transition-colors duration-150 hover:bg-black/5"
              >
                <Settings2 className="h-3 w-4 text-zinc-500" />
                Configure…
              </button>
            </>
          ) : (
            <>
              {/* Grid layout — spacer | centred title | gear header, 36pt */}
              <header className="flex h-9 items-center justify-between px-1">
                <span className="w-7" />
                <span className="text-[13px] font-medium text-zinc-800">
                  {openTile.name}
                </span>
                <button
                  type="button"
                  aria-label="Configure Tile"
                  title="Configure Tile"
                  onClick={close}
                  className="flex h-7 w-7 items-center justify-center rounded-md text-zinc-500 transition-colors hover:bg-black/5"
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
                      className={`group/app flex flex-col items-center gap-1.5 rounded-lg p-1.5 outline-none transition-colors duration-150 ${
                        isFocused ? "bg-black/10" : "hover:bg-black/5"
                      }`}
                      style={{
                        animation: `dock-app-in 240ms var(--ease-out-strong) both`,
                        animationDelay: `${i * 35}ms`,
                      }}
                    >
                      <Image
                        src={app.src}
                        alt=""
                        width={48}
                        height={48}
                        priority
                        unoptimized
                        className={`h-12 w-12 transition-transform duration-200 ${
                          isLaunching ? "scale-90" : ""
                        }`}
                        draggable={false}
                      />
                      <span className="max-w-full truncate text-[11px] leading-none text-zinc-600">
                        {app.name}
                      </span>
                    </button>
                  );
                })}
              </div>
            </>
          )}

          {/* Arrow — wide shallow triangle, like NSPopover's; follows the clicked tile's centre */}
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

      {/* Dock shelf */}
      <div className="flex items-end gap-3 rounded-3xl border border-white/15 bg-white/10 p-3 shadow-2xl backdrop-blur-2xl">
        {TILES.map((tile) => {
          const Icon = tile.icon;
          const isOpen = openId === tile.id;
          return (
            <div key={tile.id} className="flex flex-col items-center gap-1.5">
              <button
                ref={(el) => {
                  tileRefs.current[tile.id] = el;
                }}
                type="button"
                aria-expanded={isOpen}
                aria-label={`Open ${tile.name}`}
                onClick={() => handleTileClick(tile.id)}
                className="squircle pressable relative flex h-14 w-14 items-center justify-center overflow-hidden transition-transform duration-200 ease-(--ease-out-strong) hover:-translate-y-1 hover:scale-105 md:h-16 md:w-16"
                style={{
                  background: tile.gradient,
                  boxShadow:
                    "0 4px 12px rgba(0,0,0,0.25), inset 0 1px 1px rgba(255,255,255,0.3)",
                }}
              >
                {/* surface sheen — white gloss over the top half, per IconDepthMetrics */}
                <span
                  aria-hidden
                  className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/20 to-transparent"
                />
                <Icon
                  className="relative h-7 w-7 text-white md:h-8 md:w-8"
                  strokeWidth={2}
                  style={{ filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.25))" }}
                />
              </button>
              {/* running indicator, macOS-style */}
              <span
                aria-hidden
                className={`h-1 w-1 rounded-full transition-opacity duration-300 ${
                  isOpen ? "bg-white/70 opacity-100" : "opacity-0"
                }`}
              />
            </div>
          );
        })}
      </div>

    </div>
  );
}
