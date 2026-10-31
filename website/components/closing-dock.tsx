"use client";

import * as React from "react";
import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import { MacOSDock, type DockApp } from "@/components/ui/mac-os-dock";
import { ICON_CONTENT_RATIO, TileFace } from "@/components/dock-demo";
import { HmcMark } from "@/components/hmc-mark";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { asset } from "@/lib/assets";
import { anchorPopover } from "@/lib/dock-popover";
import { withReferral } from "@/lib/referral";
import { trackContactClick, trackExternalLinkClick, trackReleaseNotesClick } from "@/lib/analytics";

/**
 * The homepage's closing Dock — GitHub · What's new · Contact | Studio.
 * The Dock itself is the hero's `MacOSDock` (same size, same magnification);
 * the three tiles are real links. The Studio tile is an App Grid of the
 * studio's own apps and opens a list popover whose markup deliberately mirrors
 * the hero's list popover (`dock-demo.tsx`) — keep them in sync.
 */

// The hero's list popover width (240, the product's medium list tier) + 16, so the
// studio row — tile, "happymachines.company" and its ↗ — fits on one line.
const POPOVER_WIDTH = 256;
// The GitHub / fire / mail SVGs carry ~2/24 of built-in padding, so they need a
// larger box than the hero's 58% to fill the tile like a macOS 26 icon glyph.
const GLYPH_SIZE = "70%";
const STUDIO = "studio";

const GITHUB_URL = siteConfig.githubUrl;
const CONTACT_URL = `mailto:${siteConfig.contactEmail}`;
const SPADES_URL = withReferral(siteConfig.spadesAudioUrl);
const LANGO_URL = withReferral(siteConfig.langoUrl);
const STUDIO_URL = withReferral(siteConfig.authorUrl);
const STUDIO_HOST = new URL(siteConfig.authorUrl).host; // "happymachines.company"

const studioIcon = (src: string, className = "") => (
  <Image
    src={asset(src)}
    alt=""
    width={64}
    height={64}
    unoptimized
    draggable={false}
    className={`h-full w-full object-contain ${className}`}
  />
);

// Dual-rendered, CSS picks one: right on the first frame in either theme.
const themedIcon = (light: string, dark: string) => (
  <>
    {studioIcon(light, "dark:hidden")}
    {studioIcon(dark, "hidden dark:block")}
  </>
);

const dockTileIcon = themedIcon("/assets/studio/dock-tile.png", "/assets/studio/dock-tile-dark.png");
const spadesIcon = themedIcon("/assets/studio/spades-audio.png", "/assets/studio/spades-audio-dark.png");
const langoIcon = studioIcon("/assets/studio/lango.png");

/* The studio has no app icon of its own, so its mark sits on a glass tile:
   translucent gradient, lit top edge, hairline rim, top sheen. Sized to the
   Dock Tile icon's visible plate (220 of 256 — measured), not the 232 layout
   box: the white app plates beside it vanish into the white Studio plate, so a
   full-size visible glass square read as the biggest thing in the grid. */
const GLASS_PLATE = "86%";
function HmcGlassTile({ className = "" }: { className?: string }) {
  return (
    <span className={`flex items-center justify-center ${className}`}>
      <span
        className="relative flex items-center justify-center overflow-hidden rounded-[22.5%] bg-linear-to-br from-sky-100 via-slate-200/80 to-slate-400/70 shadow-[inset_0_1px_0_rgba(255,255,255,0.9),inset_0_-1px_1px_rgba(15,23,42,0.12),inset_0_0_0_0.5px_rgba(15,23,42,0.22),0_0.5px_1px_rgba(15,23,42,0.18)] dark:from-white/30 dark:via-white/12 dark:to-white/5 dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.35),inset_0_0_0_0.5px_rgba(255,255,255,0.18),0_0.5px_1px_rgba(0,0,0,0.4)]"
        style={{ width: GLASS_PLATE, height: GLASS_PLATE }}
      >
        {/* specular sheen across the top half — what reads as glass */}
        <span aria-hidden className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/80 to-white/0 dark:from-white/25" />
        <HmcMark className="relative h-[58%] w-[64%] text-slate-700 dark:text-zinc-100" />
      </span>
    </span>
  );
}

/* The Studio tile's face: the app's App Grid (1–4 items → 2×2) on the glass
   plate — studio mark first, then its three apps. The plate is inset like
   every tile face; its grid uses definite 1fr tracks so the cells (and the
   percentage-sized mark inside the first one) always resolve to the plate's
   size, and the whole face scales with the Dock's magnification. */
function StudioFace() {
  return (
    <div className="relative flex h-full w-full items-center justify-center">
      <div
        className="squircle grid grid-cols-2 grid-rows-2 gap-[6%] bg-linear-to-b from-white to-[#ececee] p-[13%] shadow-[inset_0_1px_1px_rgba(255,255,255,0.6),inset_0_-1px_2px_rgba(0,0,0,0.1)] dark:from-[#232323] dark:to-[#0f0f10] dark:shadow-[inset_0_1px_0_rgba(255,255,255,0.12),inset_0_-1px_0_rgba(255,255,255,0.05),inset_0_0_0_0.5px_rgba(255,255,255,0.06)]"
        style={{ width: ICON_CONTENT_RATIO, height: ICON_CONTENT_RATIO }}
      >
        <HmcGlassTile className="min-h-0 min-w-0" />
        <span className="min-h-0 min-w-0">{dockTileIcon}</span>
        <span className="min-h-0 min-w-0">{spadesIcon}</span>
        <span className="min-h-0 min-w-0">{langoIcon}</span>
      </div>
    </div>
  );
}

const external = (text: React.ReactNode) => (
  <span className="flex items-center gap-1">
    {text}
    <ArrowUpRight aria-hidden className="h-3 w-3 opacity-70" />
  </span>
);

export function ClosingDock() {
  const { content } = useLocale();
  const m = content.marketing;

  const [open, setOpen] = React.useState(false);
  const [closing, setClosing] = React.useState(false);
  const [reduced, setReduced] = React.useState(false);
  const [pos, setPos] = React.useState({ left: 0, arrow: POPOVER_WIDTH / 2, bottom: 0, width: POPOVER_WIDTH });

  const rootRef = React.useRef<HTMLDivElement>(null);
  const popoverRef = React.useRef<HTMLDivElement>(null);
  const closeTimerRef = React.useRef(0);
  // Was the last interaction a key press? A keyboard open moves focus into the
  // popover and a keyboard close hands it back to the Studio tile.
  const viaKeyboardRef = React.useRef(false);

  React.useEffect(() => {
    setReduced(window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  }, []);

  const close = React.useCallback(() => {
    setClosing(true);
    if (closeTimerRef.current) window.clearTimeout(closeTimerRef.current);
    closeTimerRef.current = window.setTimeout(() => {
      closeTimerRef.current = 0;
      setOpen(false);
      setClosing(false);
      if (viaKeyboardRef.current) {
        rootRef.current?.querySelector<HTMLElement>(`[data-app-id="${STUDIO}"]`)?.focus();
      }
    }, 200); // matches the scale-out duration
  }, []);

  const openAt = (rect: DOMRect | null) => {
    const root = rootRef.current;
    if (!root || !rect) return;
    setPos(
      anchorPopover({
        iconRect: rect,
        rootRect: root.getBoundingClientRect(),
        width: POPOVER_WIDTH,
        viewportWidth: window.innerWidth,
      }),
    );
    // A reopen during the 200ms scale-out must cancel the pending close, or
    // the stale timer shuts the new popover the moment it appears.
    if (closeTimerRef.current) {
      window.clearTimeout(closeTimerRef.current);
      closeTimerRef.current = 0;
    }
    setClosing(false);
    setOpen(true);
  };

  // Outside pointer + Escape dismiss.
  React.useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) {
        viaKeyboardRef.current = false;
        close();
      }
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        viaKeyboardRef.current = true;
        close();
      }
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open, close]);

  // Keyboard open → focus the first link, so Tab continues through the rows.
  React.useEffect(() => {
    if (open && !closing && viaKeyboardRef.current) {
      popoverRef.current?.querySelector<HTMLElement>("a")?.focus();
    }
  }, [open, closing]);

  const handleAppClick = (id: string, rect: DOMRect | null) => {
    if (id === "github") trackExternalLinkClick(GITHUB_URL, "closing_dock");
    else if (id === "whats-new") trackReleaseNotesClick();
    else if (id === "contact") trackContactClick();
    else if (id === STUDIO) {
      if (open && !closing) close();
      else openAt(rect);
    }
  };

  // Memoised: MacOSDock resets its layout whenever `apps` changes identity.
  const apps = React.useMemo<DockApp[]>(() => [
    {
      id: "github",
      name: m.closingGithubTip,
      href: GITHUB_URL,
      external: true,
      tooltip: external(m.closingGithubTip),
      label: external(m.closingGithubLabel),
      content: (
        // The app's Mono plate (#FFFFFF → #EFEFF1) with the mark as the ink —
        // how a GitHub tile looks on macOS 26.
        <TileFace
          gradient="linear-gradient(to bottom, #FFFFFF, #EFEFF1)"
          glyphColor="#1f2328"
          darkGlyph="#ffffff"
          glyph="github"
          glyphSize={GLYPH_SIZE}
          shaded
        />
      ),
    },
    {
      id: "whats-new",
      name: `${m.closingWhatsNewTip} ${siteConfig.latestVersion}`,
      href: "/release-notes",
      label: m.closingWhatsNewLabel,
      content: (
        <TileFace
          gradient="linear-gradient(to bottom, #FDBA74, #EA580C)"
          darkGlyph="#FB923C"
          glyph="fire"
          glyphSize={GLYPH_SIZE}
          shaded
        />
      ),
    },
    {
      id: "contact",
      name: m.closingContactTip,
      href: CONTACT_URL,
      tooltip: external(m.closingContactTip),
      label: external(m.closingContactLabel),
      content: (
        <TileFace
          gradient="linear-gradient(to bottom, #4AA8FF, #0A6FE8)"
          darkGlyph="#4AA8FF"
          glyph="mail"
          glyphSize={GLYPH_SIZE}
          shaded
        />
      ),
    },
    { id: "divider", name: "", kind: "divider" },
    {
      id: STUDIO,
      name: siteConfig.authorName,
      label: m.closingStudioLabel,
      content: <StudioFace />,
    },
  ], [m]);

  const animIn = reduced
    ? "dock-pop-in 180ms var(--ease-out-strong)"
    : "dock-scale-in 260ms cubic-bezier(0.22, 1, 0.36, 1)";
  const animOut = reduced
    ? "dock-pop-out 140ms var(--ease-out-strong) forwards"
    : "dock-scale-out 190ms cubic-bezier(0.4, 0, 1, 1) forwards";

  // The hero's list popover, exactly (dock-demo.tsx): rows, hover, stagger and the
  // divider before the studio row — plus a "You're here" caption on Dock Tile and
  // a ↗ on the external app rows (owner). "Early access" rides in Lango's tooltip.
  const row =
    "flex min-h-7 items-center gap-2.5 rounded px-3 py-1 text-left outline-none transition-colors duration-150 hover:bg-black/5 focus-visible:bg-black/10 dark:hover:bg-white/10 dark:focus-visible:bg-white/15";
  const label = "truncate text-[13px] text-zinc-800 dark:text-zinc-100";
  const stagger = (i: number): React.CSSProperties | undefined =>
    reduced ? undefined : { animation: "dock-app-in 240ms var(--ease-out-strong) both", animationDelay: `${i * 30}ms` };
  const hint = <span className="sr-only"> {m.opensInNewTab}</span>;
  // One aligned right-hand ↗ column for the external app rows.
  const rowArrow = <ArrowUpRight aria-hidden className="ml-auto h-3 w-3 shrink-0 text-zinc-500 dark:text-zinc-400" />;

  // Dock Tile: back to the hero at the top of this page. Never hand focus back
  // to the Studio tile on the way (that would scroll back down).
  const goHome = (e: React.MouseEvent) => {
    e.preventDefault();
    viaKeyboardRef.current = false;
    close();
    if (window.location.hash) history.replaceState(null, "", "/");
    window.scrollTo({ top: 0, behavior: reduced ? "auto" : "smooth" });
    (document.activeElement as HTMLElement | null)?.blur();
  };

  return (
    <div
      ref={rootRef}
      className="relative inline-block"
      onPointerDownCapture={() => {
        viaKeyboardRef.current = false;
      }}
      onKeyDownCapture={(e) => {
        if (e.key === "Enter" || e.key === " ") viaKeyboardRef.current = true;
      }}
    >
      <MacOSDock apps={apps} onAppClick={handleAppClick} externalHint={m.opensInNewTab} />

      {/* Studio popover — after the Dock in the DOM so Tab flows from the
          Studio tile into its links. */}
      {open && (
        <div
          ref={popoverRef}
          role="dialog"
          aria-label={siteConfig.authorName}
          className="popover-surface absolute z-30 rounded-2xl p-2"
          style={{
            width: pos.width,
            left: pos.left,
            bottom: pos.bottom,
            transformOrigin: `${pos.arrow}px 100%`,
            animation: closing ? animOut : animIn,
          }}
        >
          {/* text-left: the closing band centres its text, the hero's context doesn't */}
          <p className="px-3 pb-1 pt-1.5 text-left text-[13px] font-semibold text-zinc-800 dark:text-zinc-100">
            {siteConfig.authorName}
          </p>
          <div className="flex flex-col">
            <Link href="/" onClick={goHome} aria-current="page" className={row} style={stagger(0)}>
              <span className="h-6 w-6 shrink-0">{dockTileIcon}</span>
              <span className={label}>{siteConfig.appName}</span>
              <span className="shrink-0 text-[11px] text-zinc-500 dark:text-zinc-400">{m.studioHere}</span>
            </Link>
            <a
              href={SPADES_URL}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => trackExternalLinkClick(SPADES_URL, "studio_popover")}
              className={row}
              style={stagger(1)}
            >
              <span className="h-6 w-6 shrink-0">{spadesIcon}</span>
              <span className={label}>{siteConfig.spadesAudioName}</span>
              {hint}
              {rowArrow}
            </a>
            <a
              href={LANGO_URL}
              target="_blank"
              rel="noopener noreferrer"
              title={m.studioEarlyAccess}
              onClick={() => trackExternalLinkClick(LANGO_URL, "studio_popover")}
              className={row}
              style={stagger(2)}
            >
              <span className="h-6 w-6 shrink-0">{langoIcon}</span>
              <span className={label}>{siteConfig.langoName}</span>
              <span className="sr-only"> — {m.studioEarlyAccess}</span>
              {hint}
              {rowArrow}
            </a>
          </div>
          <div className="mx-3 my-1 border-t border-black/10 dark:border-white/10" />
          <a
            href={STUDIO_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackExternalLinkClick(STUDIO_URL, "studio_popover")}
            className={row}
            style={stagger(3)}
          >
            <HmcGlassTile className="h-6 w-6 shrink-0" />
            <span className={label}>{STUDIO_HOST}</span>
            {hint}
            {rowArrow}
          </a>

          {/* Arrow — wide shallow triangle, at the Studio tile's centre */}
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
    </div>
  );
}
