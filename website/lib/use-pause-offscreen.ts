"use client";

import * as React from "react";

/**
 * Pauses an element's looping CSS animations while it is off screen: sets `data-offscreen` on it,
 * and globals.css pauses every animation inside. A DOM attribute, not React state, so the mock
 * never re-renders; every loop inside pauses together, so synced loops (the ⌘Tab highlight and its
 * names) stay in step.
 */
export function usePauseOffscreen<T extends HTMLElement>() {
  const ref = React.useRef<T>(null);
  React.useEffect(() => {
    const el = ref.current;
    if (!el || typeof IntersectionObserver === "undefined") return;
    const io = new IntersectionObserver(([e]) => el.toggleAttribute("data-offscreen", !e.isIntersecting));
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return ref;
}
