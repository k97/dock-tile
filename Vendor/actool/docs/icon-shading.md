# `.icon` shading effects — data model and rendering plan

How macOS-26 IconComposer shades the icon stack (drop shadow, specular, glass,
translucency, blur), what `icon.json` data drives each effect, and how the
CoreGraphics render pass (`icon_render.rs`) should consume it. The *parameters*
are parsed and resolved by `icon_effects.rs`; this doc is the bridge to the
render pass that uses them.

## Where the parameters come from

Every effect is either a plain field or an appearance-keyed
`*-specializations` list (the list supersedes the plain field; a no-appearance
entry is the default/light value and the fallback for any appearance without
its own entry). `icon_effects::resolve_icon_effects(group, appearance)` returns
an `IconEffects` for one of `Light` / `Dark` / `Tinted`:

| Field | icon.json source | Meaning |
|-------|------------------|---------|
| `shadow` (`kind`, `opacity`) | group `shadow` / `shadow-specializations` | drop shadow under the icon |
| `specular` (bool) | group `specular(-specializations)` | bright sheen highlight |
| `translucency` (`enabled`, `value`) | group `translucency(-specializations)` | glass see-through amount |
| `blur_material` (0..1) | group `blur-material(-specializations)` | frosted backdrop behind the layer |
| `lighting` | group `lighting-specializations` | `individual` vs `combined` light model |
| `blend_mode` | group/layer `blend-mode-specializations` | compositing mode (`normal`, `soft-light`, …) |
| per-layer `glass` | layer `glass(-specializations)` | render the layer as glass |
| per-layer `opacity` | layer `opacity-specializations` | layer alpha |

The renderer maps render variants to appearances: variant 0 → `Light`, variant
1 → `Dark` (a future tinted variant → `Tinted`).

## Drop shadow — measured, ready to implement

Measured from Apple's 1024px feishin output (`shadow_geometry` constants):

- **Colour**: `neutral` → black; `layer-color` → tinted by the layer's dominant
  colour; `none` → skip.
- **Blur**: Gaussian, radius ≈ `20/1024` of the canvas edge.
- **Offset**: nudged down ≈ `8/1024` (bottom halo heavier than top).
- **Strength**: peak alpha ≈ `0.17` just outside the squircle edge at
  `opacity = 1`, scaled by `shadow.opacity`; fades to 0 ≈35px out.

Render: before filling the squircle, set
`CGContextSetShadowWithColor(offset, blur, color·alpha)` (or draw a separately
blurred black squircle behind). This is concrete and should land first.

## The glass effects — parameters ready, render is approximate

These are Apple's proprietary "liquid glass" treatment; the exact shader is not
public. The parsed parameters let us approximate:

- **glass** (per layer): when true, the layer is a translucent glass slab.
  Approximate with an edge bevel — a top-light → bottom-dark gradient masked to
  the layer's alpha — plus the translucency below.
- **translucency** (`enabled`, `value`): when enabled, multiply the layer's
  alpha toward `value` so the gradient shows through the glass.
- **blur_material**: Gaussian-blur the backdrop (gradient + lower layers)
  behind a glass layer by a radius scaled by the strength, for the frosted look.
- **specular**: when true, add a soft white highlight (a small top-positioned
  radial/linear white gradient) over the glass. feishin only enables it for the
  `tinted` appearance, so it can't be measured from the light render yet —
  needs a `specular:true` light fixture to pin down position/intensity.
- **lighting** `individual` vs `combined`: whether bevel/specular are computed
  per layer or once for the whole stack. Affects multi-layer icons
  (scrumdinger); single-layer icons are unaffected.
- **blend_mode**: map to CG blend modes (`normal` → Normal, `soft-light` →
  `kCGBlendModeSoftLight`) when compositing each layer.

## Status

`icon_effects.rs` resolves all of the above into typed per-appearance values
(unit-tested against feishin's specialization forms and element-web's plain
fields).

**Drop shadow — implemented.** `icon_render::composite_icon` takes a
`ShadowParams` and casts it from the squircle before clipping (`icon_bundle`
derives it per variant via `shadow_params`). The rendered halo matches Apple's
feishin output within Gaussian tolerance (sides 34/22/14/7 vs Apple
25/18/12/7 at 5px steps; ≈35px reach). `kind: none` skips it; neutral and
layer-color are both approximated as black.

**Glass — implemented (approximate).** `icon_bundle::render_layer_stack`
composites *all* a group's layers (previously only the first was used) into one
premultiplied-first BGRA, which the compositor draws over the gradient. A layer
is glass if it opts in, or if the group is a *glass context* (translucency/blur
enabled, or a sibling is glass) and it hasn't opted out with `glass: false`.

Frosted glass keeps its colour **only when the group's shadow kind is
`layer-color`** — that flag is what tells Apple the slab is "coloured glass". A
synthetic two-group fixture pinned this down: flipping a glass group's shadow
from `layer-color` to `none`/`neutral` strips the slab to a neutral grey relief
(scrumdinger's groups are `neutral`, which is why its frost reads near-white;
Rectangle's Overlay is `layer-color`, so its blue survives). The earlier
"unconditional multiply" was wrong for non-`layer-color` glass.

A *tinted* frosted layer (`layer-color`) darkens the background **subtractively**
by `D·(1 − colour)` per channel — `out_c = bg_c − D·(1 − colour_c)` — not a
multiply. A solid-slab probe (`tools/probe_glass_tint.py`: a full-canvas
solid-colour glass slab over a flat solid background, swept) measured
**`D = 63.5/255 ≈ 0.249`, constant** across background (0.3–0.9), colour,
channel, vertical position, and *every* translucency value > 0 (the value only
gates the tint on/off — 0 is opaque). It's accumulated per pixel into `glass_sub`
(coverage-weighted) and baked opaque over the gradient. Overlapping tinted groups
**stack the subtraction additively** — the dark-purple overlap Apple emits where
a blue and a red glass group cross (`[81,50,84]`, predicted `[83,45,83]`). An
untinted frosted layer instead contributes the faint vertical relief darkening
(≈`bg`), and an icon with no top-level gradient (scrumdinger's `fill: None`)
hits the neutral-relief fallback byte-identically.

**Raised glass relief — implemented as a soft edge blur.** An edge-profile probe
(`tools/probe_glass_relief.py`: a glass circle over a flat background, scanned
across its edge) showed the "raised glass" look is **not** an emboss/bevel — the
transition is monotonic with no bright/dark rim. It is a Gaussian feather of the
glass contribution, **σ ≈ 19 px at 1024, size-independent** (R=320 and R=160
both gave a ~48 px 10→90 % edge). `render_layer_stack` builds the glass result
into its own buffer and blurs it (a three-box separable approximation in
premultiplied space, σ scaled to the rendition) before compositing — our edge
width lands 49 px vs Apple's 48. This softens Rectangle's blue/grey divider and
scrumdinger's ghostly timer to match Apple.

**Opaque-glass `specular` is a static no-op — removed.** A probe over a glass
shape showed `specular: true` and `false` produce byte-identical renditions (it
only affects live device-motion sheen, like `lighting`). The old `apply_specular`
added a bright top-edge rim that Apple does not — it was actively wrong (KYA's
cup gained a bright band). Removing it dropped KYA's mean diff 15.1→9.0; the cup
keeps its `GLASS_FLOOR` lift (`#000000`→45, matching Apple) and is otherwise flat.
The bottom-right dark rim seen on opaque glass is the group's `shadow:
layer-color` (a per-layer drop shadow), not specular.

**Icon-frame glass-tile lighting — implemented (`icon_render::apply_icon_lighting`).**
Apple lights the icon tile with a soft white light along the inner squircle
edge. A flat-fill probe (`tools/probe_icon_lighting.py`) showed **all four edges
brighten** (no darkening — the earlier "bottom shading" was KYA's cup/shadow),
as an **additive light in linear space** that is ≈constant across fills:
top/left L0 ≈ 0.34, bottom/right ≈ 0.23 (light from top-left), with a linear
falloff to 0 over ~16 px. `apply_icon_lighting` post-processes the composited
icon: for interior pixels within the edge band it adds `L0·(1−d/16.5)` of white
in linear space, where `L0 = 0.286 + 0.083·dir` and `dir = (−nx−ny)/√2` from the
squircle SDF's outward normal. Our edge profile matches Apple's (top
+57/+43/+27 vs +58/+44/+29; bottom +42/+33/+22 vs +41/+31/+22), taking
element-web to ≈0.5/luma and tagspaces to ≈1.6.

**Per-layer drop shadow — implemented.** A glass layer with `shadow:
layer-color`/`neutral` casts a soft offset-down shadow on the background (KYA's
cup, Rectangle's Overlay). Measured (`tools/probe_layer_shadow.py`) as a
subtractive `(1−colour)` darkening — same form as the glass tint — peak ≈
0.49·opacity (`layer-color`; ~0.10 for `neutral`), offset down ~12 px, blurred
σ ≈ 17 px. `render_layer_stack` accumulates `shadow_dark[c] += strength·(1−col)·
cov` per shadow-casting layer, offsets the buffer down, blurs it (three-box),
and subtracts it from the background on pixels no layer covers. Matches Apple's
profile (below −43/−38/−30/−20/−10 vs −45/−40/−32/−21/−11); KYA 9.1→7.3.

This replaced an earlier coincidental full-multiply (`k=1`) that only fit
Rectangle's dark background. The subtractive `D` reproduces Apple's tint at any
background automatically: Rectangle's right-mid lands `[15,66,103]` vs Apple
`[7,67,104]` (was `[0,54,97]`). The blue Overlay went from a near-uniform grey
(mean diff 16.3) to a recognisable blue right-half over a grey left-half (≈12).

**Background gradient — geometry, not colour space.** A black→white probe
(`tools/probe_gradient_space.py`) showed Apple interpolates the gradient in the
same component-linear space we do (midpoint 127 vs our 128; the suspected
"device-RGB vs Apple's space" was a misdiagnosis). The residual was that Apple
**insets the gradient axis by `LAYER_BASE_SCALE` about the centre** — a default
top→bottom gradient spans canvas y ≈ [181,843] (span 662 = 824·`LAYER_BASE_SCALE`),
the same content box layers occupy, not the full squircle. `resolve_gradient_fill`
now applies that inset, dropping the black→white probe from 14→2/luma and
element-web to ≈0.8/luma mean. The remaining gradient residual is a thin (~30 px)
bright highlight at the squircle's very top edge.

**Layer placement (`LAYER_BASE_SCALE`) is verified correct** — not a gap. A
marker-based sweep (`tools/probe_layer_placement.py`: 5 coloured squares at
known viewBox fractions, compiled with `/usr/bin/actool`, centroids measured
across format/glass/scale/translation/viewBox-size/aspect) shows Apple places a
layer at a **fixed `824/1024` of the layer's own viewBox**, centred, aspect
preserved, with group and layer `position.scale` multiplying and
`translation-in-points` applied in that scaled space — exactly
`render_layer_stack`'s `scale = base·gscale·lscale`, `tx = base·(gscale·ltx +
gtx)`. Confirmed: 512² viewBox → 413 px, 1024² → 824 px, wide/tall preserve
aspect. element-web matches Apple's layer extent to the pixel and tagspaces'
positioned logo (scale 1.15 + translation) lands exactly. The earlier "Apple's
glass fills the squircle / we inset" note was a measurement artifact: a bluish
background gradient inflated a colour-threshold bbox.

The glass darkening is **only ≈3%** — recovered by decoding Apple's scrumdinger
GA8 and dividing the layer-region luma by the local background: out/bg ≈0.975
(top) → 0.965 (bottom). The pronounced top-light → bottom-dark relief the eye
sees is **almost entirely the background gradient** (252→236) showing through
the nearly-clear glass, not the glass itself. The earlier 7–11% overlay was far
too strong and flattened that gradient. With the subtle overlay the layer region
grades 245→230 vs Apple's 246→229 (mean ≈5 luma over the shape). The residual is
Apple's faint per-region (luminance-dependent) detail.

This only works because the background gradient renders the right way up:
`resolve_gradient_fill` anchors the *first* stop to the top edge regardless of
how the stored geometry orders its endpoints (feishin's `[0.5,1]→[0.5,0.3]` is
unchanged; scrumdinger/automatic `[0.5,0]→[0.5,1]` was rendering upside down).
element-web (non-glass) keeps full colour; only its frame flips white-to-top.

**Layer order / native size.** Layers paint back-to-front (icon.json lists them
front-to-back, so `collect_stack_layers` reverses), and each is rendered at its
**native viewBox size and aspect** scaled by base·group·layer, not stretched to
a square — so transmission's non-1024 parts (HandleShaft 256×410, Handle
782×284, Plate 868×869, …) keep their proportions and stack in the right order.
Together these turn transmission from a scrambled mess into a recognisable
red-capsule-on-striped-plate (mean diff ≈26, capsule area within 4% of Apple).

**Layer position — implemented.** `render_layer_stack` places each layer with
its resolved affine transform instead of drawing it 1:1. A `scale = 1` layer is
drawn into the icon content area (824/1024 of the canvas — `LAYER_BASE_SCALE`);
`position.scale` multiplies it and `translation-in-points` (in that same scaled
space) shifts it, with the group's `position` composed over the layer's
(`scale = base·gscale·lscale`, `tx = base·(gscale·ltx + gtx)`). Reverse-
engineered against tagspaces (a non-glass positioned layer): with the base scale
our layer lands at 1.004× Apple's size, centre within ~1px (mean ≈6 luma over
the icon). element-web (no position) now insets its layer to y[182,922] like
Apple instead of filling the canvas.

**Blend modes + opacity — implemented.** Each non-glass layer composites with
its resolved blend mode (`composite_blend`, the W3C separable blends: normal,
multiply, screen, overlay, soft-light, hard-light, darken, lighten) and its
opacity scales the source alpha. Because blend modes differ between appearances
(scrumdinger/transmission use `soft-light`/`overlay` only in dark), the stack is
rendered **per appearance** — the primary variant uses the light stack, the
alternate the dark one. Glass layers ignore blend/opacity (they become relief).

**Translucency gates the glass mode.** A glass layer is *frosted* (the faint
see-through relief) only when translucency is **enabled** (scrumdinger). With
translucency **disabled** it is **opaque** glass: the layer keeps its colour,
with blacks lifted toward a grey floor ≈45/255 — the glass material
(KeepingYouAwake's cup: `#000000` source → 45, matching Apple). The group's
`specular` flag adds **no** static treatment (see the no-op note above), so the
opaque layer is otherwise flat — Apple's cup is uniform 45 in its body with no
rim.

> SVG layers are scaled to fit their target size. `svg_raster::rasterize_svg`
> used to draw the SVG at its intrinsic size and only apply an integer scale, so
> a 1024-pt layer asked for at the 824-px content size was *clipped* to its
> top-left corner — the KYA cup landed oversized and offset. It now scales the
> SVG by `target / native` (a no-op, hence byte-identical, when they already
> match, as in the xcassets path). Mean diff over the KYA icon dropped 48 → 15.

**Per-group drop shadow — implemented.** The icon's single drop shadow is now
resolved from the *first group that requests one* (`build_icon_car`:
`find(|s| s.kind != None)`), not just `groups.first()`. Rectangle's back group
(Dots) is `shadow: none` and would suppress the front group's (Overlay)
`layer-color` shadow; Apple bakes that shadow (bottom margin ≈25k px vs ≈15k
top — asymmetric, heavier below). Single-group icons, transmission
(group 0 already `layer-color`) and ding_icon (`neutral`) are unaffected, so the
19/32 transmission parity is preserved.

**Blur-material / lighting — not rendered; per-region glass detail — measured
negligible.** Parameters are resolved. Decoding Apple's scrumdinger GA8 shows
the glass relief depends on input luminance by only ≈2/luma within a fixed
y-band, so "per-region glass detail" is not a real gap — the residual is
edge anti-aliasing. blur-material and lighting are group properties with no
fixture that exercises them measurably (smooth backdrops / blank-layer feishin),
and need a per-group compositing refactor first. Full analysis + implementation
plan in `docs/icon-shading-plan.md`.

**Per-layer fill gradients (multi-group palette).** A multi-group icon's layers
can each declare their own `fill-specializations` linear-gradients (transmission's
ArrowLines / OuterEdge, Rectangle's Dots). These are now folded into the
Color/Gradient palette via `append_layer_fills`, in document order, per
appearance. Crucially the dedup scope differs by fill kind: a layer **solid**
deduplicates against the whole palette (recipe-scraper's solid collapses onto
its base gradient stop), but a **gradient-stop / keyword** colour deduplicates
only against fold colours, not the hardcoded base — so Apple keeps transmission's
`Color-12` (0.078) distinct from the automatic-gradient's `Color-4` (also 0.078).
transmission's catalog now matches Apple's exactly (12 Colors / 6 Gradients,
`validate_car` 19 OK / 32 — identical), as does Rectangle (7 / 3, 11 OK / 15).
