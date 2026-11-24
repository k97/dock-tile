import type * as React from "react";

/* A tilted tile set into a section heading's line.
   overflow-hidden pins the inline-block's baseline to its bottom edge
   (otherwise it is synthesised from the face inside and the tile hung
   12px low), so the offset is exact: -0.19em centres the 1.1em tile on
   Allo's cap height, 0.728/2 - 1.1/2. The face is inset, so the
   clip never cuts it; the shadow is a filter on this span, not clipped. */
export function InlineTile({ tilt, children }: { tilt: "rotate-6" | "-rotate-6"; children: React.ReactNode }) {
  return (
    <span className={`mx-0.5 inline-block h-[1.1em] w-[1.1em] overflow-hidden ${tilt} align-[-0.19em] drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)]`} aria-hidden>
      {children}
    </span>
  );
}

/** The space either side of a heading tile. None in Chinese, which puts no spaces between words,
    so the heading's text (what crawlers and screen readers get; the tile is aria-hidden) reads
    "程序坞不再乱跑。", never "程序坞 不再乱跑。". */
export const tileGap = (locale: string) => (locale === "zh-Hans" ? "" : " ");
