"use client";

import * as React from "react";
import Image from "next/image";
import { asset } from "@/lib/assets";

/**
 * Branded load veil — a Dock Tile splash that covers the viewport on the FIRST
 * load of a session and lifts the instant the hero wallpaper has decoded (hard
 * capped so it can never block the page). It exists to hide the one thing the
 * earlier FOUC work didn't: the ~800KB hero wallpaper popping in late, because
 * it loads as a CSS `background-image` (discovered only after first paint). We
 * preload that wallpaper in page.tsx and gate the lift on it here, so the veil
 * pulls away to reveal an already-painted hero instead of a black box that then
 * flashes the wallpaper in.
 *
 * Skipped — with NO flash — for repeat-session loads (pre-paint `data-veil-shown`
 * on <html>, set by the inline script in layout.tsx), reduced motion, and no-JS
 * (<noscript> in layout.tsx). Those are handled in CSS so the decision lands
 * before first paint; this effect re-checks them only to skip a wasted decode.
 */

// The wallpapers the hero actually renders (light/dark Ventura dither). Module
// scope: asset() is pure, so these resolve once to the right dev/R2 URL.
const HERO_LIGHT = asset("/assets/hero-bg.webp");
const HERO_DARK = asset("/assets/hero-bg-dark.webp");

const MIN_VISIBLE_MS = 320; // floor, so a warm cache doesn't blink the veil
const MAX_VISIBLE_MS = 1200; // ceiling — lift regardless; never hold the page
const LIFT_MS = 640; // must match the CSS transition duration below

type Phase = "cover" | "lifting" | "gone";

export function HeroVeil() {
  const [phase, setPhase] = React.useState<Phase>("cover");

  // Decide when to lift: the earlier of "hero wallpaper decoded" and the cap,
  // never sooner than the min floor.
  React.useEffect(() => {
    // Same conditions the CSS skips on — re-checked so we don't fire a pointless
    // wallpaper decode just to lift an already-hidden veil.
    const skip =
      document.documentElement.hasAttribute("data-veil-shown") ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (skip) {
      setPhase("gone");
      return;
    }

    let lifted = false;
    const startedAt = performance.now();
    let capTimer = 0;
    let minTimer = 0;

    const lift = () => {
      if (lifted) return;
      lifted = true;
      window.clearTimeout(capTimer);
      const held = performance.now() - startedAt;
      minTimer = window.setTimeout(
        () => setPhase("lifting"),
        Math.max(0, MIN_VISIBLE_MS - held),
      );
    };

    // Gate on the wallpaper the theme will ACTUALLY show — read the pre-paint
    // `.dark` class next-themes set, so a manual light/dark override still waits
    // for the real image (the media-preload fast-path may have primed the other
    // one). decode() resolves off the shared cache the preload already warmed.
    const probe = new window.Image();
    probe.src = document.documentElement.classList.contains("dark")
      ? HERO_DARK
      : HERO_LIGHT;
    if (typeof probe.decode === "function") {
      probe.decode().then(lift, lift);
    } else {
      probe.onload = lift;
      probe.onerror = lift;
    }
    capTimer = window.setTimeout(lift, MAX_VISIBLE_MS);

    return () => {
      window.clearTimeout(capTimer);
      window.clearTimeout(minTimer);
    };
  }, []);

  // Unmount once the lift finishes. onTransitionEnd is the fast path; the timer
  // is a backstop in case the browser drops the transitionend (e.g. tab hidden).
  React.useEffect(() => {
    if (phase !== "lifting") return;
    const t = window.setTimeout(() => setPhase("gone"), LIFT_MS + 120);
    return () => window.clearTimeout(t);
  }, [phase]);

  if (phase === "gone") return null;

  return (
    <div
      className="hero-veil"
      data-lift={phase === "lifting" ? "" : undefined}
      aria-hidden
      onTransitionEnd={(e) => {
        if (e.target === e.currentTarget && phase === "lifting") setPhase("gone");
      }}
    >
      <div className="hero-veil__inner">
        <Image
          src={asset("/assets/dock-tile-icon-only.svg")}
          alt=""
          width={92}
          height={92}
          priority
          unoptimized
          className="hero-veil__logo"
        />
        <span className="hero-veil__bar" aria-hidden />
      </div>
    </div>
  );
}
