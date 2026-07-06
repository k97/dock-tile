"use client";

import * as React from "react";
import Image from "next/image";
import { Settings2 } from "lucide-react";
import {
  motion,
  useMotionValue,
  useSpring,
  useTransform,
  type MotionValue,
} from "motion/react";
import { TileGlyph, type GlyphName } from "@/components/tile-glyph";

/**
 * Interactive simulation of DockTile's core loop: a Dock tile is clicked and the
 * app popover pops up out of it.
 *
 * Motion:
 * - Magnification — the macOS Dock scale-under-cursor, done the way the real
 *   thing (and every good web dock) does it: each icon's **width/height** is a
 *   `useSpring` driven by its distance from the cursor's x (`mouseX`). Because
 *   size is a real layout box (not a `transform: scale`), the flex row spreads
 *   and the pill grows to contain every icon — no spill, no manual shift maths,
 *   and the spring physics make it buttery. Icons sit on `items-end`, so growth
 *   rises above the fixed-height shelf, exactly like macOS.
 * - Popover — Apple-style scale-pop from the clicked tile (origin-aware).
 * - Auto-cursor — idle loop: an SVG pointer tweens between tiles driving the
 *   same `mouseX`, presses, and opens each. Hands off to the real pointer the
 *   instant it enters the Dock; resumes after ~2.5s idle. Off under reduced-motion.
 */

type DemoApp = { name: string; src: string };

type DemoTile = {
  id: string;
  name: string;
  glyph: GlyphName;
  gradient: string; // colorTop → colorBottom, per product palette
  apps: DemoApp[];
  layout?: "grid" | "list"; // per-tile, like the app's layoutMode
};

// Popover widths per product spec: grid = 5-col medium tier, list = medium 240pt
const GRID_WIDTH = 324;
const LIST_WIDTH = 240;
const widthFor = (tile: DemoTile | null) =>
  tile?.layout === "list" ? LIST_WIDTH : GRID_WIDTH;

// Dock geometry
const BASE = 60; // resting icon size (px)
const PEAK = 92; // magnified icon size under the cursor (px)
const RADIUS = 150; // px falloff radius of the magnification curve
const SHELF_H = 82; // fixed shelf height (BASE + pt-3 + pb-2.5); icons rise above it
const SPRING = { mass: 0.1, stiffness: 180, damping: 14 }; // buttery follow

const TILES: DemoTile[] = [
  {
    id: "ai",
    name: "AI Apps",
    glyph: "sparkles",
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
    glyph: "tools",
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
    glyph: "chat",
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
    glyph: "tv",
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

// Order of magnifiable Dock items (the separator is fixed, so it is excluded).
const MAG_KEYS = ["finder", ...TILES.map((t) => t.id), "settings"];

const easeInOutCubic = (t: number) =>
  t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

/* ------------------------------------------------------------------ */
/* One magnifying Dock slot — springs its own size from cursor distance */
/* ------------------------------------------------------------------ */

function MagItem({
  mouseX,
  enabled,
  registerNode,
  title,
  className = "",
  children,
}: {
  mouseX: MotionValue<number>;
  enabled: boolean;
  registerNode: (el: HTMLElement | null) => void;
  title?: string;
  className?: string;
  children: React.ReactNode;
}) {
  const ref = React.useRef<HTMLDivElement>(null);
  const distance = useTransform(mouseX, (x) => {
    const b = ref.current?.getBoundingClientRect();
    return b ? x - (b.x + b.width / 2) : RADIUS + 1;
  });
  const target = useTransform(distance, [-RADIUS, 0, RADIUS], [BASE, PEAK, BASE], {
    clamp: true,
  });
  const size = useSpring(target, SPRING);

  return (
    <motion.div
      ref={(el) => {
        ref.current = el;
        registerNode(el);
      }}
      title={title}
      className={`relative flex items-end justify-center ${className}`}
      style={{ width: enabled ? size : BASE, height: enabled ? size : BASE }}
    >
      {children}
    </motion.div>
  );
}

export function DockDemo({ className = "" }: { className?: string }) {
  const [openId, setOpenId] = React.useState<string | null>(null);
  const [closing, setClosing] = React.useState(false);
  const [launching, setLaunching] = React.useState<string | null>(null);
  const [focusIndex, setFocusIndex] = React.useState(-1);
  const [reduced, setReduced] = React.useState(false);
  const [autoActive, setAutoActive] = React.useState(false);

  const rootRef = React.useRef<HTMLDivElement>(null);
  const rowRef = React.useRef<HTMLDivElement>(null);
  const cursorRef = React.useRef<SVGSVGElement>(null);
  const rippleHostRef = React.useRef<HTMLDivElement>(null);
  // Every magnifiable slot's DOM node, keyed by id — used for popover anchoring
  // and for the auto-demo's rest-position targets.
  const itemNodes = React.useRef<Map<string, HTMLElement>>(new Map());

  // Cursor x that drives magnification (client coords; Infinity = rested).
  const mouseX = useMotionValue(Infinity);

  // Auto-demo control.
  const signalRef = React.useRef<{ cancelled: boolean }>({ cancelled: true });
  const resumeTimer = React.useRef<number | null>(null);
  const reducedRef = React.useRef(false);
  const autoActiveRef = React.useRef(false);
  const openRef = React.useRef<(id: string) => void>(() => {});
  const closeRef = React.useRef<() => void>(() => {});

  // Arrow x-position inside the popover (body centres over the clicked tile,
  // clamped to the viewport; only the arrow tracks the tile — anchor-and-hold).
  const [pos, setPos] = React.useState({ left: 0, arrow: GRID_WIDTH / 2 });

  const openTile = TILES.find((t) => t.id === openId) ?? null;
  const popWidth = widthFor(openTile);

  const registerNode = React.useCallback(
    (key: string) => (el: HTMLElement | null) => {
      if (el) itemNodes.current.set(key, el);
      else itemNodes.current.delete(key);
    },
    [],
  );

  const measure = React.useCallback(() => {
    if (!openId || !rootRef.current) return;
    const node = itemNodes.current.get(openId);
    if (!node) return;
    const width = widthFor(TILES.find((t) => t.id === openId) ?? null);
    const rootBox = rootRef.current.getBoundingClientRect();
    if (rootBox.width === 0) return; // not laid out yet
    const tileBox = node.getBoundingClientRect();
    const tileCentre = tileBox.left + tileBox.width / 2 - rootBox.left;
    let left = tileCentre - width / 2;
    const minLeft = 8 - rootBox.left;
    const maxLeft = window.innerWidth - 8 - width - rootBox.left;
    left = Math.max(minLeft, Math.min(left, maxLeft));
    setPos({ left, arrow: tileCentre - left });
  }, [openId]);

  React.useLayoutEffect(() => {
    measure();
    if (!openId) return;
    window.addEventListener("resize", measure);
    const raf = requestAnimationFrame(measure);
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
    }, 200); // matches the scale-out duration
  }, []);

  const open = React.useCallback((id: string) => {
    setClosing(false); // cancel any in-flight close so we play scale-in, not -out
    setOpenId(id);
    setFocusIndex(-1);
  }, []);

  // Keep stable handles for the demo loop (mounted once).
  React.useEffect(() => {
    openRef.current = open;
    closeRef.current = close;
  }, [open, close]);

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

  // ---- Cursor takeover + auto-demo engine (mounted once) ----
  React.useEffect(() => {
    const root = rootRef.current;
    const row = rowRef.current;
    if (!root || !row) return;

    const prefersReduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    reducedRef.current = prefersReduced;
    setReduced(prefersReduced);

    const restCenterX = new Map<string, number>();
    let rootLeft = 0;
    let dockTop = 0;

    // Measure rest geometry with the Dock at rest (mouseX rested → all base).
    const measureGeom = () => {
      const rootR = root.getBoundingClientRect();
      const rowR = row.getBoundingClientRect();
      rootLeft = rootR.left;
      dockTop = rowR.top - rootR.top;
      itemNodes.current.forEach((el, k) => {
        const b = el.getBoundingClientRect();
        restCenterX.set(k, b.left + b.width / 2);
      });
    };
    measureGeom();

    // ---- Auto-cursor demo (drives the same mouseX as a real pointer) ----
    const placeCursor = (clientX: number) => {
      const el = cursorRef.current;
      if (el)
        el.style.transform = `translate(${(clientX - rootLeft - 4).toFixed(1)}px, ${(dockTop + BASE * 0.5).toFixed(1)}px)`;
    };
    const spawnRipple = (clientX: number) => {
      const host = rippleHostRef.current;
      if (!host) return;
      const ring = document.createElement("span");
      ring.className = "dock-click-ring";
      ring.style.left = `${(clientX - rootLeft).toFixed(1)}px`;
      ring.style.top = `${(dockTop + BASE * 0.42).toFixed(1)}px`;
      host.appendChild(ring);
      window.setTimeout(() => ring.remove(), 520);
    };

    const wait = (ms: number, sig: { cancelled: boolean }) =>
      new Promise<void>((res) => {
        const start = performance.now();
        const tick = () => {
          if (sig.cancelled || performance.now() - start >= ms) return res();
          requestAnimationFrame(tick);
        };
        tick();
      });

    const tweenTo = (to: number, dur: number, sig: { cancelled: boolean }) =>
      new Promise<void>((res) => {
        const cur = mouseX.get();
        const from = Number.isFinite(cur) ? cur : to;
        const start = performance.now();
        const tick = () => {
          if (sig.cancelled) return res();
          const p = Math.min(1, (performance.now() - start) / dur);
          const v = from + (to - from) * easeInOutCubic(p);
          mouseX.set(v);
          placeCursor(v);
          if (p < 1) requestAnimationFrame(tick);
          else res();
        };
        tick();
      });

    const press = async (sig: { cancelled: boolean }, clientX: number) => {
      const el = cursorRef.current;
      if (el) el.dataset.pressing = "true";
      spawnRipple(clientX);
      await wait(150, sig);
      if (el) el.dataset.pressing = "false";
    };

    const runLoop = async (sig: { cancelled: boolean }) => {
      // Enter from the far (Settings) side, so the first travel sweeps the Dock.
      const entry = restCenterX.get("settings") ?? rootLeft + 200;
      mouseX.set(entry);
      placeCursor(entry);
      await wait(650, sig);
      while (!sig.cancelled) {
        for (const t of TILES) {
          const target = restCenterX.get(t.id) ?? entry;
          await tweenTo(target, 760, sig);
          if (sig.cancelled) return;
          await wait(110, sig); // settle before the click
          await press(sig, target);
          if (sig.cancelled) return;
          openRef.current(t.id);
          await wait(1750, sig);
          if (sig.cancelled) return;
          closeRef.current();
          await wait(620, sig);
          if (sig.cancelled) return;
        }
      }
    };

    const startDemo = () => {
      if (reducedRef.current || !signalRef.current.cancelled) return;
      const sig = { cancelled: false };
      signalRef.current = sig;
      autoActiveRef.current = true;
      setAutoActive(true);
      runLoop(sig);
    };
    const stopDemo = () => {
      signalRef.current.cancelled = true;
      autoActiveRef.current = false;
      setAutoActive(false);
      closeRef.current();
    };
    const clearResume = () => {
      if (resumeTimer.current) window.clearTimeout(resumeTimer.current);
      resumeTimer.current = null;
    };
    const scheduleResume = () => {
      clearResume();
      resumeTimer.current = window.setTimeout(() => {
        if (!reducedRef.current) startDemo();
      }, 2500);
    };

    // Real pointer takes over the instant it enters the Dock region.
    const onPointerMove = (e: PointerEvent) => {
      clearResume();
      if (e.pointerType === "touch") {
        if (autoActiveRef.current) stopDemo();
        mouseX.set(Infinity);
        return;
      }
      if (autoActiveRef.current) stopDemo();
      mouseX.set(e.clientX);
    };
    const onPointerLeave = () => {
      mouseX.set(Infinity);
      scheduleResume();
    };
    row.addEventListener("pointermove", onPointerMove);
    row.addEventListener("pointerleave", onPointerLeave);
    const onResize = () => measureGeom();
    window.addEventListener("resize", onResize);

    // Kick off the idle demo shortly after mount (skip under reduced motion).
    const startTimer = window.setTimeout(startDemo, 900);

    return () => {
      signalRef.current.cancelled = true;
      clearResume();
      window.clearTimeout(startTimer);
      row.removeEventListener("pointermove", onPointerMove);
      row.removeEventListener("pointerleave", onPointerLeave);
      window.removeEventListener("resize", onResize);
    };
  }, [mouseX]);

  const handleTileClick = (id: string) => {
    if (openId === id) close();
    else open(id);
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

  // Popover motion — Apple-style scale-pop from the tile by default (subtle
  // overshoot + fade), plain quick fade under reduced motion.
  const animIn = reduced
    ? "dock-pop-in 180ms var(--ease-out-strong)"
    : "dock-scale-in 260ms cubic-bezier(0.22, 1, 0.36, 1)";
  const animOut = reduced
    ? "dock-pop-out 140ms var(--ease-out-strong) forwards"
    : "dock-scale-out 190ms cubic-bezier(0.4, 0, 1, 1) forwards";

  const magEnabled = !reduced;

  return (
    <div ref={rootRef} className={`relative inline-block ${className}`}>
      {/* Popover */}
      {openTile && (
        <div
          role="dialog"
          aria-label={`${openTile.name} apps`}
          onKeyDown={handlePopoverKeys}
          className={`popover-surface absolute bottom-full z-30 mb-4 rounded-2xl ${
            openTile.layout === "list" ? "p-2" : "p-3 pt-0"
          }`}
          style={{
            width: popWidth,
            left: pos.left,
            transformOrigin: `${pos.arrow}px 100%`,
            animation: closing ? animOut : animIn,
          }}
        >
          {openTile.layout === "list" ? (
            <>
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

          {/* Arrow — wide shallow triangle, following the clicked tile's centre */}
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

      {/* Ripple host — click rings are appended here in root coordinates */}
      <div
        ref={rippleHostRef}
        className="pointer-events-none absolute inset-0 z-38"
        aria-hidden
      />

      {/* Auto-demo cursor (hidden until the idle loop runs / on real takeover) */}
      <svg
        ref={cursorRef}
        className="dock-cursor"
        width={25}
        height={29}
        viewBox="0 0 25 29"
        aria-hidden
        style={{ opacity: autoActive ? 1 : 0 }}
      >
        <path
          className="dock-cursor__arrow"
          d="M4 3 L4 23 L9.5 18.2 L12.7 25.6 L16 24.2 L12.9 17.1 L20 17.1 Z"
          fill="#0b0b0f"
          stroke="#ffffff"
          strokeWidth="1.6"
          strokeLinejoin="round"
        />
      </svg>

      {/* Dock shelf — macOS Tahoe "Liquid Glass": translucent, bright specular
          top rim fading to a shaded base, pronounced continuous corners. Fixed
          height so magnified icons rise above it; width grows with the spread. */}
      <div
        ref={rowRef}
        className="dock-shelf relative flex items-end gap-2 px-3"
        style={{ height: SHELF_H }}
      >
        {/* Finder — always first, not clickable */}
        <MagItem
          mouseX={mouseX}
          enabled={magEnabled}
          registerNode={registerNode("finder")}
          title="Finder"
          className="drop-shadow-[0_3px_8px_rgba(0,0,0,0.28)]"
        >
          <Image
            src="/assets/app-icons/finder.png"
            alt=""
            fill
            sizes="92px"
            priority
            unoptimized
            draggable={false}
            className="object-contain"
          />
        </MagItem>

        {/* Interactive DockTile tiles */}
        {TILES.map((tile) => {
          const isOpen = openId === tile.id;
          return (
            <MagItem
              key={tile.id}
              mouseX={mouseX}
              enabled={magEnabled}
              registerNode={registerNode(tile.id)}
              title={tile.name}
              className="drop-shadow-[0_3px_8px_rgba(0,0,0,0.28)]"
            >
              <button
                type="button"
                aria-expanded={isOpen}
                aria-label={`Open ${tile.name}`}
                onClick={() => handleTileClick(tile.id)}
                className="squircle relative flex h-full w-full items-center justify-center overflow-hidden"
                style={{
                  background: tile.gradient,
                  boxShadow:
                    "inset 0 1px 1px rgba(255,255,255,0.35), inset 0 -1px 2px rgba(0,0,0,0.12)",
                }}
              >
                <span
                  aria-hidden
                  className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/25 to-transparent"
                />
                <span className="relative" style={{ width: "44%", height: "44%" }}>
                  <TileGlyph
                    name={tile.glyph}
                    className="h-full w-full text-white drop-shadow-[0_1px_1.5px_rgba(0,0,0,0.28)]"
                  />
                </span>
              </button>
            </MagItem>
          );
        })}

        {/* Separator — macOS Dock hairline divider before System Settings */}
        <span
          aria-hidden
          className="mx-1 self-center rounded-full"
          style={{ width: 1.5, height: 36, background: "rgba(255,255,255,0.18)" }}
        />

        {/* System Settings — last, not clickable */}
        <MagItem
          mouseX={mouseX}
          enabled={magEnabled}
          registerNode={registerNode("settings")}
          title="System Settings"
          className="drop-shadow-[0_3px_8px_rgba(0,0,0,0.28)]"
        >
          <Image
            src="/assets/app-icons/settings.png"
            alt=""
            fill
            sizes="92px"
            priority
            unoptimized
            draggable={false}
            className="object-contain"
          />
        </MagItem>
      </div>
    </div>
  );
}
