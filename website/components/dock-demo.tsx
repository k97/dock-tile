"use client";

import * as React from "react";
import Image from "next/image";
import { Settings2 } from "lucide-react";
import { MacOSDock, type DockApp } from "@/components/ui/mac-os-dock";
import { TileGlyph, type GlyphName } from "@/components/tile-glyph";
import { asset } from "@/lib/assets";

/**
 * DockTile hero demo — the interactive macOS Dock (magnification, click bounce)
 * is the shadcn.io `MacOSDock` component; this wrapper supplies DockTile's own
 * tiles + system icons and renders the grid/list popover that pops up out of a
 * clicked tile, anchored to that icon (the app's carefully-tuned effect).
 */

type DemoApp = { name: string; src: string };

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
      { name: "Music", src: "/assets/app-icons/music.png" },
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
const ICON_CONTENT_RATIO = "90.625%";

/* A DockTile tile face — gradient squircle + glyph, inset to match the real
   Finder/Settings icons' safe area (see ICON_CONTENT_RATIO above).
   Dark icon style (matches the real app): background flattens to a neutral
   near-black, and the tile's own tint moves to the glyph instead. All of the
   theming is CSS (`.tile-face` + `dark:` variants) off the pre-paint `.dark`
   class, so a dark-theme load never flashes the light face. */
function TileFace({ tile }: { tile: DemoTile }) {
  return (
    <div className="relative flex h-full w-full items-center justify-center">
      <div
        className="tile-face squircle relative flex items-center justify-center overflow-hidden shadow-[inset_0_1px_1px_rgba(255,255,255,0.35),inset_0_-1px_2px_rgba(0,0,0,0.12)] dark:shadow-[inset_0_1px_1px_rgba(255,255,255,0.12),inset_0_-1px_2px_rgba(0,0,0,0.4)]"
        style={
          {
            width: ICON_CONTENT_RATIO,
            height: ICON_CONTENT_RATIO,
            "--tile-bg": tile.gradient,
            "--tile-glyph-dark": tile.darkGlyph,
          } as React.CSSProperties
        }
      >
        {/* top gloss — light theme only; the Dark icon style is matte */}
        <span
          aria-hidden
          className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/25 to-transparent dark:hidden"
        />
        <span className="relative" style={{ width: "58%", height: "58%" }}>
          <TileGlyph
            name={tile.glyph}
            className="h-full w-full text-white drop-shadow-[0_1px_1.5px_rgba(0,0,0,0.28)] dark:text-(--tile-glyph-dark)"
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
  ...TILES.map((t) => ({ id: t.id, name: t.name, content: <TileFace tile={t} /> })),
  {
    id: "settings",
    name: "System Settings",
    content: iconFace("/assets/app-icons/settings.png?v=3", "/assets/app-icons/settings-dark.png?v=1"),
  },
];

const TILE_IDS = new Set(TILES.map((t) => t.id));

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

  // Auto-demo cursor (idle showcase): a human-like pointer that glides between
  // tiles and clicks. moveDur varies per hop; rings are the click ripples.
  const [cursor, setCursor] = React.useState({ x: 0, y: 0, visible: false, pressing: false });
  const [moveDur, setMoveDur] = React.useState(0);
  const [rings, setRings] = React.useState<{ id: number; x: number; y: number }[]>([]);

  const rootRef = React.useRef<HTMLDivElement>(null);
  const cursorRef = React.useRef<HTMLDivElement>(null);
  // Auto-showcase control. stop = hard-stop (pointer entered / user clicked);
  // resume = re-arm after the pointer has been away a beat. autoDriving marks a
  // popover the showcase opened, so its own timer never closes a user's popover.
  const stopAutoRef = React.useRef<() => void>(() => {});
  const resumeAutoRef = React.useRef<() => void>(() => {});
  const autoDrivingRef = React.useRef(false);
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
    // Product-tier width, capped so the popover keeps its 8px gutters even on
    // viewports narrower than the grid tier (320px phones).
    const width = Math.min(widthFor(tile), window.innerWidth - 16);
    const centre = rect.left + rect.width / 2 - rootBox.left;
    let left = centre - width / 2;
    const minLeft = 8 - rootBox.left;
    const maxLeft = window.innerWidth - 8 - width - rootBox.left;
    left = Math.max(minLeft, Math.min(left, maxLeft));
    const bottom = rootBox.bottom - rect.top + 14; // 14px gap above the icon
    setPos({ left, arrow: centre - left, bottom, width });
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
        if (e.pointerType !== "mouse") resumeAutoRef.current();
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
  }, [openId, close]);

  // Idle auto-showcase — a human-like cursor glides across the Dock, clicks a
  // RANDOM tile (never the one just visited) and holds its popover a beat before
  // moving on. Slower + organic (variable travel speed, a short "aim" pause,
  // off-centre landings, a click ripple) so the hero reads as operated, not a
  // carousel. Hard-stops the instant the real pointer enters / the user clicks;
  // re-arms after the pointer has been away ~2.8s.
  React.useEffect(() => {
    if (reduced) return;
    const root = rootRef.current;
    if (!root) return;

    let alive = true;
    let stopped = false;
    let lastIdx = -1;
    let ring = 0;
    let resumeTimer = 0;
    let raf = 0; // magnification pump handle
    let shown = false; // is the demo cursor currently on screen?
    const timers = new Set<number>();

    const after = (ms: number, fn: () => void) => {
      const t = window.setTimeout(() => {
        timers.delete(t);
        fn();
      }, ms);
      timers.add(t);
      return t;
    };
    const clearAll = () => {
      timers.forEach((t) => window.clearTimeout(t));
      timers.clear();
    };

    // Drive the Dock's REAL magnification from the demo cursor: every frame,
    // synthesise the very mousemove the Dock already listens for at the cursor's
    // live position, so icons balloon under it exactly as under a real pointer.
    // (A real mouse entering fires its own mousemove + the pointerenter that stops
    // the showcase, so it seamlessly takes over.)
    const dockEl = () =>
      root.querySelector("[data-app-id]")?.parentElement?.parentElement as HTMLElement | undefined;
    const pump = () => {
      if (!alive || stopped) return;
      if (shown && cursorRef.current) {
        const cb = cursorRef.current.getBoundingClientRect();
        dockEl()?.dispatchEvent(
          new MouseEvent("mousemove", { clientX: cb.left, clientY: cb.top, bubbles: true }),
        );
      }
      raf = window.requestAnimationFrame(pump);
    };

    // Park the pointer mid-Dock (hidden) so its first move glides in, not from 0,0.
    const rb0 = root.getBoundingClientRect();
    setMoveDur(0);
    setCursor({ x: rb0.width / 2, y: rb0.height / 2, visible: false, pressing: false });

    // Cursor targets = each tile's RESTING centre, captured once while the Dock is
    // idle. A live rect read mid-demo returns the MAGNIFIED position (the pump is
    // inflating icons under the cursor), which would walk the target off-tile and
    // magnify a neighbour. Resting coords keep magnification locked on the tile.
    let rest: Record<string, { x: number; y: number; w: number; h: number }> | null = null;
    const measureRest = () => {
      const rb = root.getBoundingClientRect();
      const m: Record<string, { x: number; y: number; w: number; h: number }> = {};
      for (const t of TILES) {
        const r = root.querySelector(`[data-app-id="${t.id}"]`)?.getBoundingClientRect();
        if (r) m[t.id] = { x: r.left - rb.left, y: r.top - rb.top, w: r.width, h: r.height };
      }
      return m;
    };

    const step = () => {
      if (!alive || stopped) return;
      if (!rest) rest = measureRest();
      let idx = Math.floor(Math.random() * TILES.length);
      if (TILES.length > 1 && idx === lastIdx) idx = (idx + 1) % TILES.length;
      lastIdx = idx;
      const tile = TILES[idx];
      const el = root.querySelector(`[data-app-id="${tile.id}"]`);
      const g = rest[tile.id];
      if (!el || !g) {
        after(600, step);
        return;
      }
      // glide to the centre of the tile's RESTING footprint — resting coords
      // keep magnification locked on-tile during travel (a live rect mid-glide
      // would chase the inflating icons and magnify a neighbour).
      const tx = g.x + g.w * 0.5;
      const ty = g.y + g.h * 0.5;

      const glideDur = 780 + Math.random() * 440; // variable travel speed
      setMoveDur(glideDur);
      setCursor((c) => ({ ...c, x: tx, y: ty, visible: true, pressing: false }));
      shown = true;

      after(glideDur + 80, () => {
        if (!alive || stopped) return;
        // Two-step "aim": the tile is now MAGNIFIED under the cursor — icons
        // grow upward from the Dock baseline and get pushed sideways by
        // inflating neighbours, so the resting centre sits at the magnified
        // icon's bottom-left. Each step re-reads the live rect and moves onto
        // its true centre; the move itself shifts the magnification field (and
        // the icon with it), so a second, shorter correction mops up that
        // feedback — the ballistic-move-plus-micro-correction of a real hand.
        // The final landing adds ±7px of jitter so clicks scatter organically
        // instead of machining the same pixel.
        const liveCentre = () => {
          const rb = root.getBoundingClientRect();
          const r = el.getBoundingClientRect();
          return { x: r.left - rb.left + r.width * 0.5, y: r.top - rb.top + r.height * 0.5 };
        };
        const aim = liveCentre();
        setMoveDur(170);
        setCursor((c) => ({ ...c, x: aim.x, y: aim.y }));
        after(230, () => {
          if (!alive || stopped) return;
          const centre = liveCentre();
          const jitter = () => (Math.random() - 0.5) * 14; // ±7px
          const cx = centre.x + jitter();
          const cy = centre.y + jitter();
          setMoveDur(90);
          setCursor((c) => ({ ...c, x: cx, y: cy }));
          after(140, () => {
            if (!alive || stopped) return;
            setCursor((c) => ({ ...c, pressing: true }));
            const id = ++ring;
            setRings((rs) => [...rs, { id, x: cx, y: cy }]);
            after(500, () => setRings((rs) => rs.filter((x) => x.id !== id)));
            after(180, () => setCursor((c) => ({ ...c, pressing: false })));
            autoDrivingRef.current = true;
            // Re-read the tile rect NOW (not the ~1s-old one from step start):
            // the anchor pairs it with a fresh rootBox, so any scroll/layout
            // shift during the cursor's travel would otherwise fling the
            // popover off-dock.
            open(tile.id, el.getBoundingClientRect());
            // hold the popover, then close and move on
            after(2600, () => {
              if (!alive || stopped) return;
              if (autoDrivingRef.current) {
                close();
                autoDrivingRef.current = false;
              }
              after(720, step);
            });
          });
        });
      });
    };

    stopAutoRef.current = () => {
      stopped = true;
      shown = false;
      autoDrivingRef.current = false;
      clearAll();
      if (raf) window.cancelAnimationFrame(raf);
      raf = 0;
      if (resumeTimer) window.clearTimeout(resumeTimer);
      resumeTimer = 0;
      setCursor((c) => ({ ...c, visible: false, pressing: false }));
    };
    resumeAutoRef.current = () => {
      // Only a stopped showcase may re-arm — touch fires resume liberally
      // (every tap-up, every outside dismiss), and re-arming a RUNNING
      // showcase would spawn a second concurrent step() walker.
      if (!stopped) return;
      if (resumeTimer) window.clearTimeout(resumeTimer);
      resumeTimer = window.setTimeout(() => {
        stopped = false;
        raf = window.requestAnimationFrame(pump);
        step();
      }, 2800);
    };

    raf = window.requestAnimationFrame(pump);
    after(1400, step);
    return () => {
      alive = false;
      clearAll();
      if (raf) window.cancelAnimationFrame(raf);
      if (resumeTimer) window.clearTimeout(resumeTimer);
      stopAutoRef.current = () => {};
      resumeAutoRef.current = () => {};
    };
  }, [reduced, open, close]);

  const handleAppClick = (id: string, rect: DOMRect | null) => {
    if (!TILE_IDS.has(id)) return; // Finder / Settings: tooltip only, no popover
    stopAutoRef.current(); // hard-stop the showcase so clicks never conflict
    if (openId === id) {
      close();
      // Toggle-close by touch: stopAuto just swallowed the tap-up's pending
      // resume, and no pointerleave is coming — re-arm here or the showcase
      // stays dead for good.
      if (lastPointerTypeRef.current !== "mouse") resumeAutoRef.current();
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
      onPointerEnter={() => stopAutoRef.current()}
      onPointerLeave={(e) => {
        if (e.pointerType === "mouse") resumeAutoRef.current();
      }}
      onPointerUp={(e) => {
        if (e.pointerType !== "mouse") resumeAutoRef.current();
      }}
      onPointerCancel={(e) => {
        if (e.pointerType !== "mouse") resumeAutoRef.current();
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
                      className={`flex min-h-7 items-center gap-2.5 rounded px-3 py-1 text-left outline-none transition-colors duration-150 ${
                        isFocused ? "bg-black/10 dark:bg-white/15" : "hover:bg-black/5 dark:hover:bg-white/10"
                      }`}
                      style={{
                        animation: `dock-app-in 240ms var(--ease-out-strong) both`,
                        animationDelay: `${i * 30}ms`,
                      }}
                    >
                      <Image
                        src={asset(app.src)}
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
                      className={`group/app flex flex-col items-center gap-1.5 rounded-lg p-1.5 outline-none transition-colors duration-150 ${
                        isFocused ? "bg-black/10 dark:bg-white/15" : "hover:bg-black/5 dark:hover:bg-white/10"
                      }`}
                      style={{
                        animation: `dock-app-in 240ms var(--ease-out-strong) both`,
                        animationDelay: `${i * 35}ms`,
                      }}
                    >
                      <Image
                        src={asset(app.src)}
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

      {/* Idle-demo click ripples — a ring expands from each auto-click point. */}
      {rings.map((r) => (
        <span key={r.id} aria-hidden className="dock-click-ring" style={{ left: r.x, top: r.y }} />
      ))}

      {/* Idle-demo cursor — an SVG pointer whose tip sits at translate(x,y).
          Human easing on the move; scales down briefly on "press". Hidden the
          moment the real pointer takes over. */}
      <div
        ref={cursorRef}
        aria-hidden
        className="dock-cursor"
        data-pressing={cursor.pressing ? "true" : "false"}
        style={{
          transform: `translate(${cursor.x}px, ${cursor.y}px)`,
          transition: `transform ${moveDur}ms cubic-bezier(0.42, 0.02, 0.16, 1), opacity 320ms ease`,
          opacity: cursor.visible ? 1 : 0,
        }}
      >
        <svg
          className="dock-cursor__arrow"
          width="23"
          height="23"
          viewBox="0 0 24 24"
          fill="none"
          style={{ overflow: "visible" }}
        >
          {/* Classic macOS arrow — white fill, crisp dark keyline, tip at the SVG
              origin so translate(x,y) lands the tip exactly on the click point. */}
          <path
            d="M0 0 L0 16.6 L4.05 12.75 L6.65 18.95 L8.95 17.9 L6.35 11.85 L11.9 11.85 Z"
            fill="#ffffff"
            stroke="#131316"
            strokeWidth="1.3"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        </svg>
      </div>
    </div>
  );
}
