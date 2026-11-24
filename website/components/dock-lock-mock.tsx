"use client";

import * as React from "react";
import { Lock, LockOpen, LoaderCircle } from "lucide-react";
import { TILES, TileFace } from "@/components/dock-demo";
import { useLocale } from "@/components/locale-provider";
import { ScaleToFit } from "@/components/scale-to-fit";
import { dockGlass, dockLift } from "@/components/ui/mac-os-dock";
import { HERO_BG, HERO_BG_DARK } from "@/lib/assets";
import { usePauseOffscreen } from "@/lib/use-pause-offscreen";

/* Dock Lock: two displays side by side, one wallpaper across both, the Dock (the hero's four tiles)
   at the bottom of the right one. Two modes:
   - The loop (until the first click): the pointer touches the left display's bottom edge and the
     Dock slides down off the right display and up onto the left, as macOS moves it. It goes back,
     Dock Lock turns on (the padlock closes, the right display lights up), and the next touch on the
     left edge is held short: the Dock stays. The `dl-*` keyframes in globals.css move the pointer
     in px, so the box is a fixed 560×250. Base classes are the locked resting state (reduced motion).
   - Click mode (owner, 2026-11-24): each display is a button. Clicking the one that doesn't hold
     the Dock unlocks the badge, spins, moves the Dock across and locks it there. The first click
     starts from wherever the loop was, so nothing jumps.
   Its own file so the /dock-lock page doesn't pull in home-sections.tsx. */

type Side = "left" | "right";
type LockState = "locked" | "open" | "loading";
type State = { dock: Side | null; badge: Side; lock: LockState };

// Badge x (left edge, 44 px wide) under each display's centre: displays are 250 wide, 20 apart, centred in 560
const badgeLeft: Record<Side, number> = { left: 123, right: 393 };
const sky = { borderColor: "rgba(56,189,248,0.5)", backgroundColor: "rgba(56,189,248,0.18)", boxShadow: "0 0 14px rgba(56,189,248,0.35)" };
const emerald = { borderColor: "rgba(52,211,153,0.6)", backgroundColor: "rgba(52,211,153,0.22)", boxShadow: "0 0 14px rgba(52,211,153,0.45)" };
const bezelShadow = "0 10px 24px rgba(0,0,0,0.25)";
const lit = `${bezelShadow}, 0 0 0 2px rgba(52,211,153,0.7), 0 0 22px rgba(52,211,153,0.35)`;
const ease = "[transition-timing-function:var(--ease-in-out-strong)] motion-reduce:transition-none";

/** Where the loop is right now, read from its own clock (8 s; beats as in globals.css). */
function loopState(root: HTMLElement | null): State {
  const anim = root
    ?.getAnimations({ subtree: true })
    .find((a): a is CSSAnimation => a instanceof CSSAnimation && a.animationName === "dl-dock-left");
  const time = anim?.currentTime;
  // No loop (reduced motion): the locked resting state
  const t = typeof time === "number" ? (time % 8000) / 8000 : 0.7;
  return { dock: t > 0.3 && t < 0.515 ? "left" : "right", badge: "right", lock: t > 0.61 && t < 0.935 ? "locked" : "open" };
}

function Display({
  side,
  label,
  glow,
  onPick,
  children,
}: {
  side: Side;
  label: string;
  /** null: the loop's CSS draws the glow (right display only) */
  glow: boolean | null;
  onPick: (side: Side) => void;
  children: React.ReactNode;
}) {
  // While the loop runs, the right display's glow is the `dl-anchor` keyframes' job
  const loopAnchor = glow === null && side === "right";
  let boxShadow: string | undefined = bezelShadow;
  if (loopAnchor) boxShadow = undefined;
  else if (glow) boxShadow = lit;

  return (
    <div className="flex flex-col items-center">
      {/* bezel = the button; the anchor's lights up while Dock Lock is on */}
      <button
        type="button"
        aria-label={label}
        aria-pressed={glow ?? side === "right"}
        onClick={() => onPick(side)}
        className={`pressable cursor-pointer rounded-[11px] border border-white/10 bg-zinc-950 p-[5px] transition-[box-shadow,border-color,scale] duration-500 hover:border-white/35 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-400 ${ease} ${loopAnchor ? "dl-anchor" : ""}`}
        style={{ boxShadow }}
      >
        <span aria-hidden className="relative block h-37.5 w-60 overflow-hidden rounded-[6px] bg-zinc-800">
          {/* One wallpaper across both displays: each shows its half */}
          <span
            className="hero-texture"
            style={
              {
                "--hero-bg": `url("${HERO_BG}")`,
                "--hero-bg-dark": `url("${HERO_BG_DARK}")`,
                backgroundSize: "200% auto",
                backgroundPosition: side === "left" ? "0% 55%" : "100% 55%",
              } as React.CSSProperties
            }
          />
          {/* menu bar */}
          <span className="absolute inset-x-0 top-0 flex h-2.5 items-center justify-between bg-white/40 px-1.5 backdrop-blur-sm dark:bg-black/30">
            <span className="flex items-center gap-1">
              <span className="h-1.5 w-1.5 rounded-full bg-black/60 dark:bg-white/70" />
              <span className="h-1 w-3 rounded-full bg-black/40 dark:bg-white/50" />
              <span className="h-1 w-2 rounded-full bg-black/30 dark:bg-white/40" />
              <span className="h-1 w-2.5 rounded-full bg-black/30 dark:bg-white/40" />
            </span>
            <span className="flex items-center gap-1">
              <span className="h-1 w-2 rounded-full bg-black/30 dark:bg-white/40" />
              <span className="h-1 w-4 rounded-full bg-black/40 dark:bg-white/50" />
            </span>
          </span>
          {children}
        </span>
      </button>
      {/* stand */}
      <div aria-hidden className="h-5 w-9 bg-linear-to-b from-zinc-400 to-zinc-300 [clip-path:polygon(12%_0,88%_0,100%_100%,0_100%)]" />
      <div aria-hidden className="h-1.5 w-24 rounded-full bg-zinc-300 shadow-[0_2px_4px_rgba(0,0,0,0.2)]" />
    </div>
  );
}

/** `shown`: null while the loop drives it (its CSS class), else whether it's on this display. */
function MiniDock({ loopClass, shown }: { loopClass: string; shown: boolean | null }) {
  return (
    <span className="absolute inset-x-0 bottom-1 flex justify-center">
      <span
        className={`flex gap-1 rounded-[9px] p-1 ${dockGlass} ${shown === null ? loopClass : `transition-transform duration-450 ${ease}`}`}
        style={shown === null ? undefined : { transform: shown ? "translateY(0)" : "translateY(140%)" }}
      >
        {TILES.map((t) => (
          <span key={t.id} className={`h-5 w-5 ${dockLift}`}>
            <TileFace gradient={t.gradient} darkGlyph={t.darkGlyph} glyph={t.glyph} shaded />
          </span>
        ))}
      </span>
    </span>
  );
}

export function DockLockMock({ dark = false }: { dark?: boolean }) {
  const { content } = useLocale();
  const m = content.marketing;
  const ref = usePauseOffscreen<HTMLDivElement>(); // the loop's 8 s cycle
  const [state, setState] = React.useState<State | null>(null); // null = the loop
  const timers = React.useRef<number[]>([]);
  const busy = React.useRef(false);
  React.useEffect(() => () => timers.current.forEach(clearTimeout), []);

  const pick = (target: Side) => {
    if (busy.current) return;
    const from = state ?? loopState(ref.current);
    setState(from);
    if (from.dock === target && from.badge === target && from.lock === "locked") return;
    busy.current = true;
    // unlock → spin → Dock down off one display, up onto the other → lock
    const steps: [number, Partial<State>][] = [];
    let at = 0;
    if (from.lock === "locked") {
      steps.push([at, { lock: "open" }]);
      at += 350;
    }
    steps.push([at, { lock: "loading" }]);
    at += 650;
    if (from.dock !== target) {
      steps.push([at, { dock: null, badge: target }]);
      at += 450;
      steps.push([at, { dock: target }]);
      at += 500;
    } else {
      steps.push([at, { badge: target }]);
      at += 450;
    }
    steps.push([at, { lock: "locked" }]);
    let cur = from;
    for (const [delay, patch] of steps) {
      timers.current.push(
        window.setTimeout(() => {
          cur = { ...cur, ...patch };
          setState(cur);
          if (patch.lock === "locked") busy.current = false;
        }, delay + 16),
      );
    }
  };

  // -300 on the near-black well; on the light one -600, -300 in the dark theme (whole class names: Tailwind scans literals)
  const skyTone = dark ? "text-sky-300" : "text-sky-600 dark:text-sky-300";
  const emeraldTone = dark ? "text-emerald-300" : "text-emerald-600 dark:text-emerald-300";
  const glow = (side: Side) => (state ? state.badge === side && state.lock === "locked" : null);

  return (
    // `dark`: on an always-dark band, a near-black well instead of the muted one.
    <div ref={ref} className={dark ? "rounded-2xl border border-white/5 bg-zinc-950 p-6 md:p-8" : "rounded-2xl bg-foreground/4 p-5 md:p-8"}>
      <ScaleToFit>
        <div className="relative h-62.5 w-140 pt-3">
          <div className="flex justify-center gap-5">
            <Display side="left" label={m.dockLockMockLeft} glow={glow("left")} onPick={pick}>
              <MiniDock loopClass="dl-dock-left" shown={state ? state.dock === "left" : null} />
            </Display>
            <Display side="right" label={m.dockLockMockRight} glow={glow("right")} onPick={pick}>
              <MiniDock loopClass="dl-dock-right" shown={state ? state.dock === "right" : null} />
            </Display>
          </div>
          {/* Dock Lock's state, under the display it holds the Dock on */}
          <span
            aria-hidden
            className={`absolute top-55 flex h-7 w-11 items-center justify-center rounded-full border ${state ? `transition-[left,background-color,border-color,box-shadow] duration-500 ${ease}` : "dl-badge"}`}
            style={state ? { left: badgeLeft[state.badge], ...(state.lock === "locked" ? emerald : sky) } : { left: badgeLeft.right }}
          >
            <LockOpen
              className={`h-3.5 w-3.5 ${skyTone} ${state ? "transition-opacity duration-200" : "dl-open"}`}
              style={state ? { opacity: state.lock === "open" ? 1 : 0 } : undefined}
            />
            <Lock
              className={`absolute h-3.5 w-3.5 ${emeraldTone} ${state ? "transition-opacity duration-200" : "dl-closed"}`}
              style={state ? { opacity: state.lock === "locked" ? 1 : 0 } : undefined}
            />
            {state?.lock === "loading" && (
              <LoaderCircle className={`absolute h-3.5 w-3.5 animate-spin motion-reduce:animate-none ${skyTone}`} />
            )}
          </span>
          {/* the loop's pointer: a macOS arrow, tip at the element's top-left corner. Gone once the
              visitor clicks: their own pointer is the one moving the Dock then. */}
          {!state && (
            <svg aria-hidden className="dl-pointer pointer-events-none absolute top-0 left-0 h-4.5 w-3.5 drop-shadow-[0_1px_1px_rgba(0,0,0,0.35)]" viewBox="0 0 14 18">
              <path d="M1 1v14.5l3.6-3.4 2.4 5.4 2.3-1-2.4-5.3h5z" fill="#000" stroke="#fff" strokeWidth="1.2" strokeLinejoin="round" />
            </svg>
          )}
        </div>
      </ScaleToFit>
      {/* Says the displays are buttons */}
      <p className={`mt-3 text-center text-[13px] ${dark ? "text-white/50" : "text-muted-foreground"}`}>{m.dockLockMockHint}</p>
    </div>
  );
}
