"use client";

import * as React from "react";
import Image from "next/image";
import { useLocale } from "@/components/locale-provider";
import { asset } from "@/lib/assets";

/**
 * Features / 01's "take a closer look": the 2.x window screenshot with + hotspots
 * (and a matching pill row). Picking one keeps that region at full brightness,
 * fades the rest of the window back, pushes in a little and shows a short card
 * beside it — Apple's HomeView pattern, without a zoom that would soften the 2×
 * capture's text. Everything animates on transform/opacity only: each region is
 * its own pre-clipped copy of the screenshot, faded in, never a moving clip-path.
 */

const LIGHT = "/assets/stage/customise-tile-2x.webp";
const DARK = "/assets/stage/customise-tile-2x-dark.webp";
// Push-in while a region is open; small enough that the 2× capture stays crisp.
const PUSH = 1.06;
const GAP = 18;

type Box = readonly [x0: number, y0: number, x1: number, y1: number];

// Regions as fractions of the cropped screenshot (2269×1725, light and dark
// cropped to the same box). `dot` is where the + sits — a region corner,
// never over content.
const REGIONS: readonly { box: Box; dot: readonly [number, number] }[] = [
  { box: [0.264, 0.29, 0.707, 0.636], dot: [0.707, 0.337] }, // In This Tile
  { box: [0.736, 0.113, 0.944, 0.202], dot: [0.736, 0.114] }, // Style
  { box: [0.736, 0.22, 0.944, 0.326], dot: [0.944, 0.22] }, // Background
  { box: [0.264, 0.123, 0.371, 0.263], dot: [0.371, 0.123] }, // Your tile
];

const clip = ([x0, y0, x1, y1]: Box) =>
  `inset(${y0 * 100}% ${(1 - x1) * 100}% ${(1 - y1) * 100}% ${x0 * 100}% round 14px)`;

function Plus() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={3} strokeLinecap="round" aria-hidden className="h-full w-full">
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

function Chevron({ up }: { up?: boolean }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" aria-hidden className="h-3.5 w-3.5">
      <path d={up ? "M6 15l6-6 6 6" : "M6 9l6 6 6-6"} />
    </svg>
  );
}

function CardButton({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="pressable flex h-7.5 w-7.5 cursor-pointer items-center justify-center rounded-full bg-foreground/8 text-foreground transition-colors duration-150 hover:bg-foreground/12 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500"
    >
      {children}
    </button>
  );
}

/** The screenshot pair; CSS shows the theme's one (first frame already right).
 *  Lossless webp served as-is (`unoptimized`): the optimizer's quality-75
 *  re-encode left blocky artifacts around the window's small UI text. */
function Screenshot({ alt, className = "", style }: { alt: string; className?: string; style?: React.CSSProperties }) {
  return (
    <>
      <Image src={asset(LIGHT)} alt={alt} fill unoptimized className={`object-contain dark:hidden ${className}`} style={style} />
      <Image src={asset(DARK)} alt={alt} fill unoptimized className={`hidden object-contain dark:block ${className}`} style={style} />
    </>
  );
}

export function CloserLook() {
  const { content } = useLocale();
  const m = content.marketing;
  const items = [
    { label: m.tilesSpotPopover, body: m.tilesSpotPopoverBody },
    { label: m.tilesSpotStyle, body: m.tilesSpotStyleBody },
    { label: m.tilesSpotBackground, body: m.tilesSpotBackgroundBody },
    { label: m.tilesSpotTile, body: m.tilesSpotTileBody },
  ];

  const [active, setActive] = React.useState(-1);
  const [wide, setWide] = React.useState(false);
  const [cardAt, setCardAt] = React.useState({ x: 0, y: 0 });
  // The card glides between regions, but its first placement after opening
  // lands in place — otherwise it would slide in from the top-left corner.
  const [cardGlides, setCardGlides] = React.useState(false);
  const stageRef = React.useRef<HTMLDivElement>(null);
  const cardRef = React.useRef<HTMLDivElement>(null);
  const pillRefs = React.useRef<(HTMLButtonElement | null)[]>([]);
  const cardId = React.useId();

  // Beside-the-region card + push-in only from md up; phones get the card
  // below the screenshot and no push.
  React.useEffect(() => {
    const mq = window.matchMedia("(min-width: 768px)");
    const sync = () => setWide(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  const open = active >= 0;
  const k = open && wide ? PUSH : 1;

  // Place the card beside the region, on the side with more room, following
  // the push-in (scale about the region's centre).
  const place = React.useCallback(() => {
    const stage = stageRef.current, card = cardRef.current;
    if (!stage || !card || active < 0 || !wide) return;
    const [x0, y0, x1, y1] = REGIONS[active].box;
    const W = stage.offsetWidth, H = stage.offsetHeight;
    const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    const sx = (v: number) => (cx + (v - cx) * PUSH) * W;
    const sy = (v: number) => (cy + (v - cy) * PUSH) * H;
    const cw = card.offsetWidth, ch = card.offsetHeight;
    const x = W - sx(x1) >= sx(x0) ? sx(x1) + GAP : sx(x0) - GAP - cw;
    setCardAt({ x: Math.max(0, Math.min(W - cw, x)), y: Math.max(0, Math.min(H - ch, sy(y0))) });
    requestAnimationFrame(() => setCardGlides(true));
  }, [active, wide]);

  React.useLayoutEffect(place, [place]);
  React.useEffect(() => {
    const stage = stageRef.current;
    if (!stage) return;
    const ro = new ResizeObserver(place);
    ro.observe(stage);
    return () => ro.disconnect();
  }, [place]);

  const close = () => {
    const was = active;
    setActive(-1);
    setCardGlides(false);
    if (was >= 0) pillRefs.current[was]?.focus({ preventScroll: true });
  };
  const toggle = (i: number) => (active === i ? close() : setActive(i));
  const step = (d: number) => setActive((i) => (i + d + items.length) % items.length);

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (!open) return;
    if (e.key === "Escape") close();
    else if (e.key === "ArrowDown" || e.key === "ArrowRight") { e.preventDefault(); step(1); }
    else if (e.key === "ArrowUp" || e.key === "ArrowLeft") { e.preventDefault(); step(-1); }
  };

  // Scale about the region's centre, expressed as translate + scale from the
  // top-left so moving between regions animates smoothly (a changing
  // transform-origin would jump).
  const pushStyle = (() => {
    if (k === 1) return undefined;
    const [x0, y0, x1, y1] = REGIONS[active].box;
    const tx = (1 - k) * ((x0 + x1) / 2) * 100, ty = (1 - k) * ((y0 + y1) / 2) * 100;
    return { transform: `translate(${tx}%, ${ty}%) scale(${k})` };
  })();

  const card = open ? (
    <div
      ref={cardRef}
      id={cardId}
      role="region"
      aria-label={items[active].label}
      aria-live="polite"
      className={`z-10 rounded-[20px] bg-card px-5 pb-4 pt-4.5 shadow-[0_20px_50px_rgba(0,0,0,0.22)] ring-1 ring-border md:absolute md:left-0 md:top-0 md:w-75 ${cardGlides ? "md:transition-transform md:duration-500 md:ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none" : ""}`}
      style={wide ? { transform: `translate(${cardAt.x}px, ${cardAt.y}px)` } : undefined}
    >
      <p className="text-[15px] leading-relaxed text-muted-foreground">
        <b className="font-semibold text-foreground">{items[active].label}.</b> {items[active].body}
      </p>
      <div className="mt-3 flex justify-end gap-1.5">
        <CardButton label={m.tilesSpotPrevious} onClick={() => step(-1)}>
          <Chevron up />
        </CardButton>
        <CardButton label={m.tilesSpotNext} onClick={() => step(1)}>
          <Chevron />
        </CardButton>
        <CardButton label={m.tilesSpotClose} onClick={close}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.5} strokeLinecap="round" aria-hidden className="h-3.5 w-3.5">
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </CardButton>
      </div>
    </div>
  ) : null;

  return (
    <figure className="mx-auto max-w-300" onKeyDown={onKeyDown}>
      <div className="relative">
        <div ref={stageRef} className="relative aspect-2269/1725 w-full">
          <div
            className="absolute inset-0 origin-top-left transition-transform duration-600 ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none"
            style={pushStyle}
          >
            {/* Base window: fades back while a region is open. */}
            <Screenshot
              alt={m.tilesAlt}
              className={`transition-opacity duration-500 motion-reduce:transition-none ${open ? "opacity-30 dark:opacity-35" : ""}`}
            />
            {/* One pre-clipped bright copy per region; only the open one shows. */}
            {REGIONS.map((r, i) => (
              <div
                key={i}
                aria-hidden
                className={`pointer-events-none absolute inset-0 transition-opacity duration-300 motion-reduce:transition-none ${active === i ? "opacity-100" : "opacity-0"}`}
              >
                <Screenshot alt="" style={{ clipPath: clip(r.box) }} />
              </div>
            ))}
            {REGIONS.map((r, i) => (
              <button
                key={i}
                type="button"
                aria-label={items[i].label}
                aria-expanded={active === i}
                aria-controls={active === i ? cardId : undefined}
                tabIndex={open && active !== i ? -1 : undefined}
                onClick={() => toggle(i)}
                className={`absolute flex h-5 w-5 -translate-x-1/2 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full bg-foreground p-1.25 text-background shadow-md ring-2 ring-foreground/15 transition-[opacity,scale] duration-300 hover:scale-108 focus-visible:outline-2 focus-visible:outline-offset-3 focus-visible:outline-blue-500 motion-reduce:transition-none sm:h-7 sm:w-7 sm:p-1.75 sm:ring-4 ${open && active !== i ? "pointer-events-none opacity-0" : ""}`}
                style={{ left: `${r.dot[0] * 100}%`, top: `${r.dot[1] * 100}%` }}
              >
                <span className={`block h-full w-full transition-transform duration-300 motion-reduce:transition-none ${active === i ? "rotate-45" : ""}`}>
                  <Plus />
                </span>
              </button>
            ))}
          </div>
        </div>
        {wide && card}
      </div>
      {!wide && card && <div className="mt-5">{card}</div>}

      <figcaption>
        <ul className="mt-8 flex flex-wrap justify-center gap-2.5">
          {items.map((it, i) => (
            <li key={it.label}>
              <button
                ref={(el) => {
                  pillRefs.current[i] = el;
                }}
                type="button"
                aria-expanded={active === i}
                aria-controls={active === i ? cardId : undefined}
                onClick={() => toggle(i)}
                className={`pressable flex cursor-pointer items-center gap-2.5 rounded-full py-2.5 pl-3 pr-4.5 text-[15px] font-semibold transition-colors duration-200 focus-visible:outline-2 focus-visible:outline-offset-3 focus-visible:outline-blue-500 ${
                  active === i ? "bg-foreground text-background" : "bg-foreground/6 text-foreground hover:bg-foreground/10"
                }`}
              >
                <span className="flex h-5.5 w-5.5 items-center justify-center rounded-full p-1.25 ring-[1.5px] ring-current ring-inset">
                  <span className={`block h-full w-full transition-transform duration-300 motion-reduce:transition-none ${active === i ? "rotate-45" : ""}`}>
                    <Plus />
                  </span>
                </span>
                {it.label}
              </button>
            </li>
          ))}
        </ul>
      </figcaption>
    </figure>
  );
}
