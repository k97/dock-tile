import { useId, type CSSProperties } from "react";

/**
 * Tile glyphs — filled, SF-Symbol-accurate shapes rendered as inline SVG.
 *
 * The real DockTile tiles paint white *filled* SF Symbols; thin outline glyphs
 * read "comicky" and un-Mac. These are Bootstrap Icons (MIT), whose filled
 * silhouettes match the corresponding SF Symbols one-for-one — a single
 * cohesive weight, all filled (except `code`/`globe`, which SF itself draws as
 * line art; and `fire` + `mail`, outline glyphs by the owner's choice). Shared by
 * the hero dock, the closing dock, the Smart-Add showcase and the presets
 * grid so every "designed" app-icon on the site uses one shape + one glyph set.
 * viewBox is 16×16 (unless overridden in GLYPH_DEFS below); fill follows
 * `currentColor`.
 */
export const GLYPH_PATHS = {
  // ≈ SF `sparkles` — curved four-point sparkle stars
  sparkles:
    "M7.657 6.247c.11-.33.576-.33.686 0l.645 1.937a2.89 2.89 0 0 0 1.829 1.828l1.936.645c.33.11.33.576 0 .686l-1.937.645a2.89 2.89 0 0 0-1.828 1.829l-.645 1.936a.361.361 0 0 1-.686 0l-.645-1.937a2.89 2.89 0 0 0-1.828-1.828l-1.937-.645a.361.361 0 0 1 0-.686l1.937-.645a2.89 2.89 0 0 0 1.828-1.828zM3.794 1.148a.217.217 0 0 1 .412 0l.387 1.162c.173.518.579.924 1.097 1.097l1.162.387a.217.217 0 0 1 0 .412l-1.162.387A1.73 1.73 0 0 0 4.593 5.69l-.387 1.162a.217.217 0 0 1-.412 0L3.407 5.69A1.73 1.73 0 0 0 2.31 4.593l-1.162-.387a.217.217 0 0 1 0-.412l1.162-.387A1.73 1.73 0 0 0 3.407 2.31zM10.863.099a.145.145 0 0 1 .274 0l.258.774c.115.346.386.617.732.732l.774.258a.145.145 0 0 1 0 .274l-.774.258a1.16 1.16 0 0 0-.732.732l-.258.774a.145.145 0 0 1-.274 0l-.258-.774a1.16 1.16 0 0 0-.732-.732L9.1 2.137a.145.145 0 0 1 0-.274l.774-.258c.346-.115.617-.386.732-.732z",
  // ≈ SF `wrench.and.screwdriver.fill` — crossed wrench + screwdriver
  tools:
    "M1 0 0 1l2.2 3.081a1 1 0 0 0 .815.419h.07a1 1 0 0 1 .708.293l2.675 2.675-2.617 2.654A3.003 3.003 0 0 0 0 13a3 3 0 1 0 5.878-.851l2.654-2.617.968.968-.305.914a1 1 0 0 0 .242 1.023l3.27 3.27a.997.997 0 0 0 1.414 0l1.586-1.586a.997.997 0 0 0 0-1.414l-3.27-3.27a1 1 0 0 0-1.023-.242L10.5 9.5l-.96-.96 2.68-2.643A3.005 3.005 0 0 0 16 3q0-.405-.102-.777l-2.14 2.141L12 4l-.364-1.757L13.777.102a3 3 0 0 0-3.675 3.68L7.462 6.46 4.793 3.793a1 1 0 0 1-.293-.707v-.071a1 1 0 0 0-.419-.814zm9.646 10.646a.5.5 0 0 1 .708 0l2.914 2.915a.5.5 0 0 1-.707.707l-2.915-2.914a.5.5 0 0 1 0-.708M3 11l.471.242.529.026.287.445.445.287.026.529L5 13l-.242.471-.026.529-.445.287-.287.445-.529.026L3 15l-.471-.242L2 14.732l-.287-.445L1.268 14l-.026-.529L1 13l.242-.471.026-.529.445-.287.287-.445.529-.026z",
  // ≈ SF `tv` — filled screen + stand
  tv: "M2.5 13.5A.5.5 0 0 1 3 13h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5M2 2h12s2 0 2 2v6s0 2-2 2H2s-2 0-2-2V4s0-2 2-2",
  // ≈ SF `play.fill`
  play: "m11.596 8.697-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 0 1 0 1.393",
  // ≈ SF `folder.fill`
  folder:
    "M9.828 3h3.982a2 2 0 0 1 1.992 2.181l-.637 7A2 2 0 0 1 13.174 14H2.825a2 2 0 0 1-1.991-1.819l-.637-7a2 2 0 0 1 .342-1.31L.5 3a2 2 0 0 1 2-2h3.672a2 2 0 0 1 1.414.586l.828.828A2 2 0 0 0 9.828 3m-8.322.12q.322-.119.684-.12h5.396l-.707-.707A1 1 0 0 0 6.172 2H2.5a1 1 0 0 0-1 .981z",
  // ≈ SF `globe` — filled globe (line art in SF; a solid disc reads cleaner at tile size)
  globe:
    "M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0M2.04 4.326c.325 1.329 2.532 2.54 3.717 3.19.48.263.793.434.743.484q-.121.12-.242.234c-.416.396-.787.749-.758 1.266.035.634.618.824 1.214 1.017.577.188 1.168.38 1.286.983.082.417-.075.988-.22 1.52-.215.782-.406 1.48.22 1.48 1.5-.5 3.798-3.186 4-5 .138-1.243-2-2-3.5-2.5-.478-.16-.755.081-.99.284-.172.15-.322.279-.51.216-.445-.148-2.5-2-1.5-2.5.78-.39.952-.171 1.227.182.078.099.163.208.273.318.609.304.662-.132.723-.633.039-.322.081-.671.277-.867.434-.434 1.265-.791 2.028-1.12.712-.306 1.365-.587 1.579-.88A7 7 0 1 1 2.04 4.327Z",
  // ≈ SF `bolt.fill` — Bootstrap `lightning-charge-fill`
  bolt: "M11.251.068a.5.5 0 0 1 .227.58L9.677 6.5H13a.5.5 0 0 1 .364.843l-8 8.5a.5.5 0 0 1-.842-.49L6.323 9.5H3a.5.5 0 0 1-.364-.843l8-8.5a.5.5 0 0 1 .615-.09z",
  // ≈ SF `chevron.left.forwardslash.chevron.right` — the `</>` code glyph
  code: "M10.478 1.647a.5.5 0 1 0-.956-.294l-4 13a.5.5 0 0 0 .956.294zM4.854 4.146a.5.5 0 0 1 0 .708L1.707 8l3.147 3.146a.5.5 0 0 1-.708.708l-3.5-3.5a.5.5 0 0 1 0-.708l3.5-3.5a.5.5 0 0 1 .708 0m6.292 0a.5.5 0 0 0 0 .708L14.293 8l-3.147 3.146a.5.5 0 0 0 .708.708l3.5-3.5a.5.5 0 0 0 0-.708l-3.5-3.5a.5.5 0 0 0-.708 0",
} as const;

/**
 * Glyphs that need a non-16×16 viewBox or more than one sub-path (so they can't
 * live in GLYPH_PATHS). Rendered the same way — `currentColor` fill, default
 * (nonzero) fill-rule per path, so exported SF Symbol winding cuts its own holes.
 */
export const GLYPH_DEFS = {
  // SF `bubble.left.and.text.bubble.right.fill` — two overlapping speech
  // bubbles (a plain one behind, a text bubble in front). Reads as "chat /
  // messaging" without looking like the single iMessage bubble. Exact Apple
  // export: left bubble first, then the text bubble on top (whose winding
  // cuts the two text lines as holes).
  chat: {
    viewBox: "0 0 26.5927 22.1044",
    paths: [
      "M21.2836 4.59966L21.2836 5.09453L12.7419 5.09453C10.3067 5.09453 8.8606 6.55979 8.8606 8.96608L8.8606 15.3883C8.8606 16.0539 8.96996 16.6441 9.18289 17.1469L6.23017 19.6872C5.99578 19.8883 5.81843 20.0157 5.59029 20.0157C5.28207 20.0157 5.06722 19.7903 5.06722 19.425L5.06722 16.6653L4.23286 16.6653C1.9301 16.6653 0.512519 15.2465 0.512519 12.9477L0.512519 4.59966C0.512519 2.30784 1.9301 0.886347 4.23286 0.886347L17.5633 0.886347C19.8758 0.886347 21.2836 2.3219 21.2836 4.59966Z",
      "M14.1228 10.9391C13.9196 10.9391 13.7618 10.7829 13.7618 10.5852C13.7618 10.3848 13.9196 10.2242 14.1228 10.2242L21.354 10.2242C21.5544 10.2242 21.7177 10.3848 21.7177 10.5852C21.7177 10.7829 21.5544 10.9391 21.354 10.9391ZM14.1228 14.1926C13.9196 14.1926 13.7618 14.0376 13.7618 13.8372C13.7618 13.6395 13.9196 13.4778 14.1228 13.4778L19.4657 13.4778C19.6634 13.4778 19.8251 13.6395 19.8251 13.8372C19.8251 14.0376 19.6634 14.1926 19.4657 14.1926ZM12.7419 18.3579L17.9493 18.3579L20.9508 20.9329C21.1669 21.1243 21.3415 21.2333 21.5388 21.2333C21.8329 21.2333 22.0169 21.0149 22.0169 20.6946L22.0169 18.3579L22.7184 18.3579C24.6591 18.3579 25.7189 17.3012 25.7189 15.3742L25.7189 8.96608C25.7189 7.03636 24.6591 5.96564 22.7184 5.96564L12.7419 5.96564C10.7942 5.96564 9.73444 7.03636 9.73444 8.96608L9.73444 15.3883C9.73444 17.3251 10.7942 18.3579 12.7419 18.3579Z",
    ],
  },
  // The GitHub mark (black-and-white logo) for the closing Dock's source tile.
  github: {
    viewBox: "0 0 24 24",
    fillRule: "evenodd",
    paths: [
      "M12.026 2c-5.509 0-9.974 4.465-9.974 9.974 0 4.406 2.857 8.145 6.821 9.465.499.09.679-.217.679-.481 0-.237-.008-.865-.011-1.696-2.775.602-3.361-1.338-3.361-1.338-.452-1.152-1.107-1.459-1.107-1.459-.905-.619.069-.605.069-.605 1.002.07 1.527 1.028 1.527 1.028.89 1.524 2.336 1.084 2.902.829.091-.645.351-1.085.635-1.334-2.214-.251-4.542-1.107-4.542-4.93 0-1.087.389-1.979 1.024-2.675-.101-.253-.446-1.268.099-2.64 0 0 .837-.269 2.742 1.021a9.582 9.582 0 0 1 2.496-.336 9.554 9.554 0 0 1 2.496.336c1.906-1.291 2.742-1.021 2.742-1.021.545 1.372.203 2.387.099 2.64.64.696 1.024 1.587 1.024 2.675 0 3.833-2.33 4.675-4.552 4.922.355.308.675.916.675 1.846 0 1.334-.012 2.41-.012 2.737 0 .267.178.577.687.479C19.146 20.115 22 16.379 22 11.974 22 6.465 17.535 2 12.026 2z",
    ],
  },
  // Hugeicons `mail-01` (stroke-rounded) for the closing Dock's Contact tile —
  // chosen by the owner (2026-10-30) because a filled envelope read as Apple
  // Mail; the outline keeps the blue tile without the Mail-app look.
  mail: {
    viewBox: "0 0 24 24",
    stroke: { width: 1.8 },
    paths: [
      "M2 6L8.91302 9.91697C11.4616 11.361 12.5384 11.361 15.087 9.91697L22 6",
      "M2.01577 13.4756C2.08114 16.5412 2.11383 18.0739 3.24496 19.2094C4.37608 20.3448 5.95033 20.3843 9.09883 20.4634C11.0393 20.5122 12.9607 20.5122 14.9012 20.4634C18.0497 20.3843 19.6239 20.3448 20.7551 19.2094C21.8862 18.0739 21.9189 16.5412 21.9842 13.4756C22.0053 12.4899 22.0053 11.5101 21.9842 10.5244C21.9189 7.45886 21.8862 5.92609 20.7551 4.79066C19.6239 3.65523 18.0497 3.61568 14.9012 3.53657C12.9607 3.48781 11.0393 3.48781 9.09882 3.53656C5.95033 3.61566 4.37608 3.65521 3.24495 4.79065C2.11382 5.92608 2.08114 7.45885 2.01576 10.5244C1.99474 11.5101 1.99475 12.4899 2.01577 13.4756Z",
    ],
  },
  // Hugeicons `fire` (stroke-rounded) for the closing Dock's "What's new" tile.
  // `fire` and `mail` are the OUTLINE glyphs in the set — the owner's explicit
  // choice (2026-10-30) over the filled-only rule above.
  fire: {
    viewBox: "0 0 24 24",
    stroke: { width: 1.8 },
    paths: [
      "M13.8561 22C26.0783 19 19.2338 7 10.9227 2C9.9453 5.5 8.47838 6.5 5.54497 10C1.66121 14.6339 3.5895 20 8.96719 22C8.1524 21 6.04958 18.9008 7.5 16C8 15 9 14 8.5 12C9.47778 12.5 11.5 13 12 15.5C12.8148 14.5 13.6604 12.4 12.8783 10C19 14.5 16.5 19 13.8561 22Z",
    ],
  },
} as const;

type GlyphDef = {
  viewBox: string;
  paths: readonly string[];
  fillRule?: "evenodd";
  stroke?: { width: number };
};

export type GlyphName = keyof typeof GLYPH_PATHS | keyof typeof GLYPH_DEFS;

export function TileGlyph({
  name,
  className,
  style,
  shaded = false,
}: {
  name: GlyphName;
  className?: string;
  style?: CSSProperties;
  /** macOS-style glyph shading: full colour at the top easing to 80% at the
   *  bottom (the app bakes the same top→bottom fall-off). Follows `color`. */
  shaded?: boolean;
}) {
  const def = (GLYPH_DEFS as Record<string, GlyphDef>)[name];
  const viewBox = def?.viewBox ?? "0 0 16 16";
  const paths = def?.paths ?? [(GLYPH_PATHS as Record<string, string>)[name]];
  // One id per instance: the gradient's currentColor resolves where the
  // gradient is defined, so a shared id painted every same-named glyph in
  // the FIRST instance's colour (a Mono tint glyph came out white).
  const shadeId = `tile-glyph-shade-${useId().replace(/[^\w-]/g, "")}`;
  const ink = shaded ? `url(#${shadeId})` : "currentColor";
  const paint = def?.stroke
    ? {
        fill: "none",
        stroke: ink,
        strokeWidth: def.stroke.width,
        strokeLinecap: "round" as const,
        strokeLinejoin: "round" as const,
      }
    : { fill: ink };
  return (
    <svg viewBox={viewBox} className={className} style={style} {...paint} aria-hidden>
      {shaded && (
        <defs>
          <linearGradient id={shadeId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="currentColor" />
            <stop offset="1" stopColor="currentColor" stopOpacity="0.8" />
          </linearGradient>
        </defs>
      )}
      {paths.map((d, i) => (
        <path key={i} d={d} fillRule={def?.fillRule} clipRule={def?.fillRule} />
      ))}
    </svg>
  );
}
