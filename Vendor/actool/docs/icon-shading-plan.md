# Remaining `.icon` shaders — requirements & implementation plan

Status of the IconComposer render pipeline after the position / blend / opacity
/ glass / specular / multi-group work, and what it would take to close the rest.
Grounded in measurements against Apple's output (`tools/extract_pixels`, GA8
decode) **and synthetic controlled fixtures** — copying a bundle and varying one
property at a time, then compiling with `/usr/bin/actool` and measuring the
isolated effect. The render pass lives in `icon_bundle::render_layer_stack` +
`icon_render`; effect parameters are already resolved by `icon_effects`.

## TL;DR (after synthetic-fixture probing)

None of the three remaining shaders meaningfully changes the *static* `.car`
renditions, so none is worth implementing for rendition parity:

| shader | synthetic finding | verdict |
|--------|-------------------|---------|
| per-region glass | ≈2/luma vs input luminance | not a gap |
| lighting (individual/combined) | **byte-identical** output (overlapping glass circles merge to one relief either way) | live-render hint only; we already do the "combined" union |
| blur-material | subtle relief-strength bump, **saturates at value ≈2.0**, ≤9/luma | optional, near noise |

## What's already done

squircle mask · background gradient (+ direction) · drop shadow · multi-layer
compositing in paint order · per-layer affine position (native viewBox size /
aspect) · blend modes · opacity · glass (frosted relief **and** opaque-glossy,
gated by translucency) · specular rim · multi-group per-layer fill palette.

## The hard ceiling (won't change)

Byte-for-byte parity is impossible regardless of shader work: Apple embeds a
fresh **random UUID** in every rendition name (two Apple runs differ), and the
sized pixels are Apple's proprietary CoreSVG+compositor output. The target is
structural + visual closeness. A standing ~6/luma gradient residual also comes
from interpolating in device-RGB rather than Apple's working space.

## Remaining shaders

### 1. Per-region glass detail — **not a real gap (close it as done)**

Hypothesis was that the frosted relief should carry the layer's internal
luminance/edges. Measured on Apple's scrumdinger GA8: within a fixed y-band the
output varies only **≈2 luma** across input luminance 80→240. The relief is
essentially the vertical gradient (already reproduced); the ~5-luma residual is
edge anti-aliasing on the segment boundaries, not a missing shading term.
**Plan: none.** Update the docs to stop calling this an open shader.

### 2. blur-material — **measured: relief-strength, saturates at ≈2, not blur**

Synthetic sweep (copy of the KYALauncher cup, `system-dark` + frosted glass,
`blur-material` swept 0 → 20 against `/usr/bin/actool`):

| value | Δ vs 0 (mean / max luma) | relief edge contrast |
|-------|--------------------------|----------------------|
| 0.0 | 0 / 0 | 1 |
| 0.5 | 0.15 / 4 | 3 |
| 1.0 | 0.27 / 7 | 6 |
| 2.0 | 0.36 / 9 | 7 |
| 5.0, 20.0 | 0.36 / 9 (**identical to 2.0**) | 7 |

Findings, contradicting the earlier "0..1 Gaussian backdrop blur" guess:
* `actool` **accepts values > 1**, but the effect **saturates at ≈2.0** — 5 and
  20 are byte-identical to 2. So the effective range is `[0, ~2]`.
* It is **not** a backdrop Gaussian: a sharp-striped backdrop behind frosted
  glass stays sharp at every value, and the relief edge contrast *increases*
  with the value rather than softening. It reads as a glass relief/refraction
  **strength**, not a radius.
* Peak effect is ≤9/luma — near the noise floor.

*Verdict.* Optional. If implemented, model it as a relief-strength multiplier
(`min(value, 2.0)`) on the frosted relief, **not** a blur, gated on
`blur_material.is_some()`. Low value; skip unless chasing the last few luma.

### 3. lighting (`individual` / `combined`) — **measured: no static effect**

Synthetic test (two overlapping glass circles, opaque *and* frosted variants,
`lighting` = individual vs combined): the two outputs are **byte-identical**
(mean 0 / max 0). The overlapping circles merge into a single relief either way.

*Conclusion.* `lighting` does not change the baked `.car` renditions — Apple
always composites the group as one merged shape (the "combined" union, which is
exactly what we already do). It must be a **live-render hint** (how the specular
responds to device motion / pointer), which doesn't exist in a static rendition.
**Plan: none** — implementing per-layer `individual` lighting would *diverge*
from Apple's static output.

## Refactor note (still worth it, for other reasons)

The remaining group properties that *do* affect static output — `shadow`,
`specular`, `translucency`, and the per-group fills — are today read only from
the **first** group. `render_layer_stack`
currently flattens all groups into one reversed layer list and unions all glass
coverage globally. To honour per-group blur / lighting the stack must be
restructured to **composite group-by-group** (back-to-front): render each
group's layers (with its own glass union, blur, lighting), then composite the
finished group onto the canvas. This is the main cost item (~1 day) and also the
*correct* model for per-group `shadow`/`translucency`/`specular`, which we
currently read only from the first group.

## Recommended order

1. **All three shaders: no implementation needed** — per-region glass is
   negligible, lighting has no static effect, blur-material is ≤9/luma and
   saturates. The synthetic fixtures settled this.
2. **Per-group compositing refactor** (the one valuable item) — *done*.
   - **Structural (CAR):** every group now emits its own IconGroup rendition
     and the iconstack references all groups (back-to-front). Previously only
     `group_facet_names[0]`/`layer_assets[0]` were wired, so a 2nd/3rd group's
     facet had a FACETKEYS entry but no rendition — absent from BITMAPKEYS,
     CUICatalog returned "no images" for it. Fixing this brought Rectangle to
     30/30 renditions and **transmission to 49/49** (both matching Apple's
     rendition count and `validate_car` exactly — 11/15 and 19/32, same facets).
   - **Pixel (render):** frosted glass keeps each layer's colour (gradient ×
     `glass_tint` multiply) **gated on `shadow: layer-color`**; overlapping
     tinted groups stack their multiplies; the drop shadow is resolved from the
     first group that requests one. Reverse-engineered against a synthetic
     two-group overlapping-glass fixture (the gate + stacking were invisible in
     every real fixture). Tint *strength* is renderer-bound and left at full
     multiply (fits the real Rectangle fixture).
3. Only if chasing the last luma: blur-material as a relief-strength multiplier
   (`min(value, 2)`), verified against the synthetic sweep above.

## Honest assessment

Probing with synthetic fixtures resolved the open questions and the answer is
clean: **the remaining "shaders" don't change the static renditions** (lighting
is a live-render hint, per-region glass is ~2 luma, blur-material is ≤9 luma and
saturates at 2). The only static-relevant gap left is per-group property
handling, which is a compositing-structure refactor, not a shader. Nothing here
moves the byte-parity ceiling (impossible: random UUIDs + Apple's rasterizer).
The synthetic-fixture method itself is the reusable takeaway — it converts
"unverifiable" effects into measured ones.
