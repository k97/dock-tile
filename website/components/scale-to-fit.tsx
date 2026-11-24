"use client";

import * as React from "react";

/* Uniform scale-to-fit: children render at their fixed natural size; the
   whole block is zoomed (transform scale, aspect ratio locked — like a
   miniature screenshot) to the width on offer, capped at 1:1. The
   illustration itself never restyles or reflows across viewports. */
export function ScaleToFit({ children }: { children: React.ReactNode }) {
  const outerRef = React.useRef<HTMLDivElement>(null);
  const innerRef = React.useRef<HTMLDivElement>(null);
  const [fit, setFit] = React.useState<{ scale: number; height: number; left: number } | null>(null);

  React.useLayoutEffect(() => {
    const outer = outerRef.current;
    const inner = innerRef.current;
    if (!outer || !inner) return;
    const measure = () => {
      const scale = Math.min(1, outer.clientWidth / inner.offsetWidth);
      setFit({
        scale,
        height: Math.round(inner.offsetHeight * scale),
        left: Math.max(0, (outer.clientWidth - inner.offsetWidth * scale) / 2),
      });
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(outer);
    return () => ro.disconnect();
  }, []);

  return (
    <div ref={outerRef} className="relative w-full" style={{ height: fit?.height }}>
      <div
        ref={innerRef}
        className={`absolute top-0 w-max ${fit ? "" : "invisible"}`}
        style={fit ? { left: fit.left, transform: `scale(${fit.scale})`, transformOrigin: "top left" } : undefined}
      >
        {children}
      </div>
    </div>
  );
}
