"use client";

import * as React from "react";

/* The idle Dock showcase shared by the hero Dock (dock-demo.tsx) and the
   closing Dock (closing-dock.tsx): a human-like cursor glides to a RANDOM tile
   (never the one just visited), aims, and lands — slower and organic (variable
   travel speed, a short aim, off-centre landings, a click ripple), so the Dock
   reads as operated, not a carousel. It hard-stops the instant the real pointer
   enters / the user clicks (the caller wires `stop` / `resume`; see
   hero-dock-demo.md "Touch resume model"). */

type Rect = { x: number; y: number; w: number; h: number };

export function useDockShowcase({
  rootRef,
  ids,
  enabled,
  land,
  release,
  holdFor = () => 2600,
}: {
  rootRef: React.RefObject<HTMLDivElement | null>;
  /** Tiles the cursor visits — a module constant, so the effect runs once. */
  ids: readonly string[];
  enabled: boolean;
  /** The cursor has landed on `el`. Return true to "click" it (press + ripple). */
  land: (id: string, el: Element) => boolean;
  /** The hold is over: undo what `land` did. Skipped once the user took over. */
  release: () => void;
  holdFor?: (id: string) => number;
}) {
  // moveDur varies per hop; rings are the click ripples.
  const [cursor, setCursor] = React.useState({ x: 0, y: 0, visible: false, pressing: false });
  const [moveDur, setMoveDur] = React.useState(0);
  const [rings, setRings] = React.useState<{ id: number; x: number; y: number }[]>([]);
  const cursorRef = React.useRef<HTMLDivElement>(null);
  // stop = hard-stop (pointer entered / user clicked); resume = re-arm after the
  // pointer has been away a beat. autoDriving marks state the showcase made, so
  // its own timer never undoes a user's popover.
  const stopRef = React.useRef<() => void>(() => {});
  const resumeRef = React.useRef<() => void>(() => {});
  const autoDrivingRef = React.useRef(false);
  // Latest callbacks without restarting the walker on every render.
  const landRef = React.useRef(land);
  const releaseRef = React.useRef(release);
  const holdRef = React.useRef(holdFor);
  React.useEffect(() => {
    landRef.current = land;
    releaseRef.current = release;
    holdRef.current = holdFor;
  });

  // Walk only while the Dock is on screen: the pump drives a mousemove every
  // frame, and off screen nobody sees it (it also kept opening hero popovers).
  const [inView, setInView] = React.useState(false);
  React.useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const io = new IntersectionObserver(([e]) => setInView(e.isIntersecting), { threshold: 0.6 });
    io.observe(root);
    return () => io.disconnect();
  }, [rootRef]);

  React.useEffect(() => {
    if (!enabled || !inView) return;
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
    const undo = () => {
      if (autoDrivingRef.current) {
        releaseRef.current();
        autoDrivingRef.current = false;
      }
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
    let rest: Record<string, Rect> | null = null;
    const measureRest = () => {
      const rb = root.getBoundingClientRect();
      const m: Record<string, Rect> = {};
      for (const id of ids) {
        const r = root.querySelector(`[data-app-id="${id}"]`)?.getBoundingClientRect();
        if (r) m[id] = { x: r.left - rb.left, y: r.top - rb.top, w: r.width, h: r.height };
      }
      return m;
    };

    const step = () => {
      if (!alive || stopped) return;
      if (!rest) rest = measureRest();
      let idx = Math.floor(Math.random() * ids.length);
      if (ids.length > 1 && idx === lastIdx) idx = (idx + 1) % ids.length;
      lastIdx = idx;
      const id = ids[idx];
      const el = root.querySelector(`[data-app-id="${id}"]`);
      const g = rest[id];
      if (!el || !g) {
        after(600, step);
        return;
      }
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
            autoDrivingRef.current = true;
            if (landRef.current(id, el)) {
              setCursor((c) => ({ ...c, pressing: true }));
              const r = ++ring;
              setRings((rs) => [...rs, { id: r, x: cx, y: cy }]);
              after(500, () => setRings((rs) => rs.filter((x) => x.id !== r)));
              after(180, () => setCursor((c) => ({ ...c, pressing: false })));
            }
            // hold, then undo and move on
            after(holdRef.current(id), () => {
              if (!alive || stopped) return;
              undo();
              after(720, step);
            });
          });
        });
      });
    };

    stopRef.current = () => {
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
    resumeRef.current = () => {
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
      undo(); // leaving view mid-hold must not strand a popover the demo opened
      setCursor((c) => ({ ...c, visible: false, pressing: false }));
      stopRef.current = () => {};
      resumeRef.current = () => {};
    };
  }, [enabled, inView, rootRef, ids]);

  const stop = React.useCallback(() => stopRef.current(), []);
  const resume = React.useCallback(() => resumeRef.current(), []);
  return { cursor, moveDur, rings, cursorRef, stop, resume };
}

/* The showcase's click ripples and pointer. Render inside the Dock's
   `relative` root, after the Dock. */
export function DemoCursor({
  cursor,
  moveDur,
  rings,
  cursorRef,
}: Pick<ReturnType<typeof useDockShowcase>, "cursor" | "moveDur" | "rings" | "cursorRef">) {
  return (
    <>
      {/* Click ripples — a ring expands from each auto-click point. */}
      {rings.map((r) => (
        <span key={r.id} aria-hidden className="dock-click-ring" style={{ left: r.x, top: r.y }} />
      ))}

      {/* An SVG pointer whose tip sits at translate(x,y). Human easing on the
          move; scales down briefly on "press". Hidden the moment the real
          pointer takes over. */}
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
        <svg className="dock-cursor__arrow" width="23" height="23" viewBox="0 0 24 24" fill="none" style={{ overflow: "visible" }}>
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
    </>
  );
}
