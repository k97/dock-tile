# `.icon` (IconComposer) CAR parity status

How close our `.icon` output is to `/usr/bin/actool`, what is byte-matched,
and what is fundamentally out of reach. Reference fixtures:
`third_party/element-web/.../icon.icon` (simple `fill: automatic`),
`third_party/scrumdinger_app/.../ScumAppIcon.icon` (keyword
fill-specializations), `third_party/feishin/media/feishin.icon` (custom-
gradient fill-specializations + SVG layer — the richest fixture).

## Byte-for-byte parity is impossible for `.icon`

Apple's actool embeds a **fresh random UUID** in every pre-rendered
rendition name (`feishin128x128_…_<UUID>-<pid>-<hex>.png`). Two consecutive
Apple runs of the *same* bundle differ in raw bytes (verified: file sizes and
per-rendition `SizeOnDisk` are identical between runs, only the name bytes
move). So the achievable target is **structural / functional parity**, not a
byte-identical `.car`.

## What we match (verified against the reference)

* **Rendition-type counts** match exactly. feishin: 8 Color, 14 Icon Image,
  3 IconGroup, 3 IconImageStack, 1 MultiSized, 3 Named Gradient, 2
  PackedImage, 1 Vector — identical multiset to Apple.
* **Color / Gradient palette** is byte-identical, including colorspaces
  (extended-gray=6, gray-gamma-2.2=2, display-p3=3), `f64(f32(round3(v)))`
  component encoding, gradient stop references (with dedup), and gradient
  orientation geometry. See `fill_specializations_assets` in
  `icon_bundle.rs`.
* **Rendition names** use the bundle stem (`feishin16x16_…`), not a literal
  `icon` prefix.
* **SVG layer source** is stored as a `Vector` rendition holding the raw SVG
  (`image.svg`, LAYOUT_PDF), matching Apple — not rasterized to `image.png`.
* **Main facet part** is `PART_ICON` (220), as Apple emits, not
  `PART_ICON_COMPOSER` (245).
* **`imagesWithName:` / `colorWithName:` behaviour** matches Apple's own
  output: feishin reports 12 OK / 2 SKIP via `validate_car` — the same 2
  non-raster facets (the IconGroup and the SVG Vector) that return no bitmaps
  in Apple's `.car` too (SKIP, not a failure — they aren't bitmap-resolvable).

### fill-specializations palette model

Folded in document order: a white anchor `Color-1` (extended-gray `[1,1]`),
then each top-level specialization, then every layer's `fill` and
`fill-specializations`. Each `value`:

* keyword — `system-light` → gray pair `(1.0, 0.925)`; `system-dark` →
  `(0.192, 0.078)`; bare `automatic` resolves by the entry's appearance
  (dark → dark pair, else light). Emits the two gray stops (gray-gamma-2.2)
  and a top→bottom gradient.
* `{linear-gradient: [s0, s1], orientation}` — each stop becomes a Color in
  its declared space; the gradient carries `[start.x, start.y, stop.x,
  stop.y]` from `orientation` (default `[0.5, 0, 0.5, 1]`).
* `{solid: "<spec>"}` — one Color.

Colors dedup by `(colorspace, components)`; gradients by `(geometry, stops)`.
This makes scrumdinger's redundant layer `automatic` collapse to 5 Colors / 2
Gradients, while feishin's distinct layer gradient adds Color-7 + Gradient-3
(its second stop dedups onto Color-2) for 8 Colors / 3 Gradients.

## What we do NOT match — and why (renderer-bound)

These are all the *rendered* outputs of Apple's proprietary IconComposer
renderer. None affect catalog loading; CUICatalog uses the data we emit for
every functional lookup.

* **Pre-rendered sized renditions** (Icon Image 16…1024) and the
  **ZZZZPackedAsset atlases**. Apple composites the full icon stack
  (gradients + layer + shadow + blur + specular + translucency) at each size.
  We reproduce the bulk of this (see "Styling pipeline" below): the layer over
  the background gradient, clipped to the macOS squircle, rendered with Apple's
  own CoreSVG + CoreGraphics. After the squircle/relief/lighting work the
  per-rendition luma diff on the variant GA8/BGRA composites (decoded directly,
  `tools/compare_variant_renditions.py`) is **feishin ≈1.3–1.4, element-web ≈1.3,
  scrumdinger ≈4.5** at 256/512/1024 px (overall 1.5 / 2.6 / 3.0 incl. the
  128 pt). The remaining residual is now narrow and well-located:
  - **A thin antialiased boundary ring** (~±2/luma, within ~1 px of the squircle
    edge): for feishin/element-web the *interior* is ≈0.4 — essentially exact —
    and the whole residual is this ring. It is Apple's true squircle being a
    hair fuller at the corners than a pure n=5 superellipse (the corner AA fringe
    has higher coverage), i.e. sub-pixel rasterizer-level difference.
  - **The 128 pt (256 px) rendition** is the outlier in every fixture (5–8 vs
    ~1.4): Apple draws the icon **1 px larger at this one smallest size** (opaque
    at x=24, margin 24, vs our consistent 25), producing a one-column-wide edge
    error. The rule behind that 1 px enlargement isn't derivable from a single
    size, so it's left unmatched (functionally irrelevant — CUICatalog uses the
    stored pixels).
  - **scrumdinger's frosted-glass layer body** (≈3.7 interior): the proprietary
    part — see the "Variant-axis" note below.
  Same class as the dropped iOS app-icon atlas geometry (`atlas-packing.md`).
* **IconGroup CSI geometry** (TLV `0x03F4`). Apple stores the group's
  *computed* bounding box (e.g. feishin `[off 106,62, size 890,890]`) derived
  from the group `position.scale` (2.2) and the layer's scale/translation; we
  emit a placeholder. TLV `0x03FC` additionally embeds the child layer's
  facet-name string (`feishin_Assets/feishin`) where we store a numeric id.
  Both require the IconComposer layout engine. The IconGroup facet is
  non-functional in Apple's own `.car` (fails `imagesWithName:`), so this is
  cosmetic.

## Styling pipeline (`icon_render.rs`)

What `/usr/bin/actool` bakes into each non-variant sized rendition, recovered
by rendering Apple's `.car` through CUICatalog (`tools/extract_pixels`):

1. **Squircle clip** — a **superellipse** `|x/a|ⁿ+|y/a|ⁿ=1` with `n=5.0`,
   inset `100/1024` of the canvas (`build_squircle_path`, a densely-sampled
   polygon CGPath). Fitted against Apple's `.car` alpha mask: n=5 matches to ≈2
   px, vs ≈7 px for the best circular-arc rounded rect, which cut the corners
   ~8-12 px too deep (a bright corner ring in the variant GA8 diff). The edge
   glass-tile lighting uses the **same** superellipse distance field
   (`squircle_sdf`), so its inner-edge highlight tracks the corners — a
   rounded-rect SDF mis-placed it ~10 px at the corners (±30/luma).
2. **Background** — for a gradient/automatic fill, the icon's light gradient
   (`Gradient-1`), its two stop colors and `orientation` from the palette. For a
   `solid` fill, the **flat solid colour** (`Color-2`): Apple's light rendition
   paints that, not `Gradient-1` (which for a solid fill is the *dark-mode*
   background `0.192→0.078`). `resolve_background_fills` returns the solid colour
   as the light fill — without it tagspaces rendered a black background (mean
   diff vs Apple dropped from ~full-scale to **1.8** once fixed).
3. **Layer** — drawn on top, clipped to the same squircle, placed at a fixed
   `824/1024` of its viewBox (centred, aspect-preserved, group/layer
   `position.scale`·translation composed). Verified pixel-exact via the marker
   sweep (`tools/probe_layer_placement.py`); see `icon-shading.md`.

We render all three with the **same Apple rasterizers** the system actool uses
— CoreSVG for the layer (`svg_raster.rs`), CoreGraphics for the gradient/mask
(`icon_render.rs`) — so a gradient-only icon matches Apple to ≈4/channel. With
an opaque layer the gradient + mask are correct but the layer differs by the
glass shading (≈30/channel average; the shape and gradient are right). Before
this, sized renditions were the raw layer on a full square; now non-variant
`.icon` bundles render as proper macOS squircle icons.

Now reproduced — the icon-frame **glass-tile lighting**: a soft white light
along the inner squircle edge, brightest top-left, fading inward ~16 px.
Measured (`tools/probe_icon_lighting.py`, flat fills) as an additive light in
*linear* space (≈constant across fills; all four edges brighten — the earlier
"bottom darkening" was KYA's cup/shadow, not the frame). `apply_icon_lighting`
reproduces Apple's edge profile (ours top +57/+43/+27 vs Apple +58/+44/+29),
taking element-web to ≈0.5/luma. **Opaque-glass `specular` is a static no-op** (a
probe showed `true`/`false` byte-identical — a live-render hint like `lighting`),
so the old `apply_specular` bright rim was wrong and removed. The frosted-glass
tint (subtractive `D·(1−colour)`), the "raised glass" σ≈19 px edge blur, and the
fixed `824/1024` layer/gradient placement are all reproduced; see
`icon-shading.md`.

Now reproduced — the **per-layer drop shadow**: a glass layer with
`shadow: layer-color`/`neutral` casts a soft offset-down shadow on the
background (KYA's cup, Rectangle's Overlay). Measured
(`tools/probe_layer_shadow.py`) as a subtractive `(1−colour)` darkening (same
form as the glass tint), peak ≈ 0.49·opacity (`layer-color`; ~0.10 for
`neutral`), offset down ~12 px and blurred σ ≈ 17 px. `render_layer_stack`
accumulates it per layer, offsets + blurs, and subtracts it from the background
under the layers; our profile matches Apple's (below −43/−38/−30/−20/−10 vs
−45/−40/−32/−21/−11; above −14/−10/−6 vs −13/−9/−5). KYA's mean diff dropped
9.1→7.3.

The **icon-frame margin drop shadow** is now cast **always**, at constant
strength, independent of the group `shadow` kind — Apple's halo is identical for
`shadow: none` (element-web), absent (feishin), and `layer-color` (KYA), all
≈ bottom α 37. Previously we gated it on the group shadow, so element-web and
feishin had no margin shadow at all. Tuned to Apple's α profile (top 16/11/6,
bottom 37/31/22/12 at 4/8/14/22 px; ours top 14/9/5, bottom 37/32/23/12).
(Variant-axis icons like feishin bake it into the GA8; CUICatalog's recompose
differs — a separate documented limitation.)
The background gradient now matches to ≈1/luma: a black→white probe
(`tools/probe_gradient_space.py`) showed Apple interpolates in the **same**
component-linear space we do — the old "device-RGB vs Apple's space" residual was
a misdiagnosis. The real difference was **geometry**: Apple insets the gradient
axis by `LAYER_BASE_SCALE` about the centre (so a default top→bottom gradient
spans canvas y ≈ [181,843], not the full squircle), the same content box layers
use. With that inset element-web drops to ≈0.8/luma mean. The only gradient
residual left is a thin (~30 px) bright highlight at the squircle's very top
edge, not yet reproduced.

A custom gradient's `orientation` sets only the **direction**, not the span:
Apple always draws the gradient across the full inset content box. feishin's
`orientation` y-range is `1.0→0.3` (literal span 0.7), but its rendered gradient
covers the whole box exactly like scrumdinger's `0→1`. Using the literal 0.7 span
made ours too steep (slope ≈64 vs Apple's ≈48 gray/yfrac) and clip to white — off
by up to 8.7/luma on the background strip. `resolve_gradient_fill` now anchors the
endpoints to the box extremes (top→bottom) regardless of the orientation
magnitudes, dropping feishin's background gradient to ≈0.1/luma. Default-`[0,1]`
gradients (scrumdinger/element-web) are unchanged.

### When the variant axis is emitted

Apple emits the light+dark appearance axis (the alternate renditions + atlas
keyed on **attr 24 = 1**) iff the icon is **single-group** *and* declares any
`appearance: dark` specialization — at the top level **or** nested in a
group/layer (`json_has_dark_appearance`). Verified across six fixtures:

| fixture | groups | has dark | Apple attr 24 |
|---|---|---|---|
| feishin, scrumdinger | 1 | yes (top-level) | `[0,1]` |
| KeepingYouAwake | 1 | yes (layer fill) | `[0,1]` |
| element-web | 1 | no | absent |
| Rectangle | 2 | no (tinted only) | absent |
| transmission | 3 | yes | absent |

So gating on a top-level `fill-specializations` block alone was wrong twice
over: it dropped KYA's whole dark variant (dark lives in a layer fill, no
top-level block), and would wrongly add one to a multi-group icon. **Multi-group
icons never carry the axis** even with dark content — their per-group stacks are
recomposed live. A **`tinted`** appearance never triggers it: Apple stores no
tinted variant at all (attr 24 stays `[0,1]` even for a synthetic *top-level*
`appearance: tinted` fill-spec) — tint mode is a live system recolour of the
light/dark layers. Our output matches Apple's attr-24 presence and rendition
count on all six.

**Variant-axis bundles** store two grayscale variants. The two are
**different in kind** — decoded directly with
`tools/compare_variant_renditions.py`:
- **Primary → GA8 = the light composite** (gradient + content, opaque). Matches
  Apple to ≈1.4/luma (feishin) — interior ≈0.4, residual is the boundary AA ring.
  scrumdinger is ≈4.5: its `system-light` background gradient is byte-close
  (≈0.1/luma on the background strip) but its **frosted layer body** carries a
  ≈3.7 interior residual. Apple's frosted glass darkens the layer body by a
  *flat* ≈12.7/255 (≈5.1%) below the local background, top to bottom
  (`GLASS_RELIEF_STRENGTH`; the old `0.025+0.012·y` ramp was a misfit). The
  residual is that Apple's material **flattens the layer's internal structure**
  into a uniform tint, while our relief still shows some of it — the stopwatch's
  dark stem (top, over-darkened) and a bright see-through "bowl" at an inner
  layer boundary (bottom). That flattening is the renderer-bound part; a probe
  (`tools/layer_body`) confirms Apple's darkening is constant where ours ramps
  ±12.
- **Alternate → GA16 = a flat dark *tint***, not a dark composite: a
  semi-transparent near-white squircle (premult gray ≈59, α ≈60) over the icon's
  black drop shadow, which CUICatalog overlays on the light icon for dark mode.
  The tint is constant (same on both fixtures — `system-dark`). We build it in
  `build_dark_variant_tint`; the stored GA16 now matches Apple to **≈0.7/luma**
  (was ≈26 when we wrongly baked an opaque dark composite).

Both use the **`KCBC` compression** (chunked-LZFSE, `height/3` rows per chunk) —
matching Apple: GA8/GA16 are KCBC (not deepmap2), so a variant icon's `.car`
carries the same codec selection as Apple's (feishin 0 dmp2 / 38 KCBC,
scrumdinger 3 dmp2 — its BGRA renditions — like Apple). deepmap2 is used only for
BGRA renditions, as Apple does. With both the codec and the dark-variant model
now matching, CUICatalog's recompose follows the stored content.

## Reproduce

```
./target/debug/actool --compile out --platform macosx \
  --minimum-deployment-target 11.0 --app-icon feishin \
  --output-partial-info-plist out/p.plist third_party/feishin/media/feishin.icon
/usr/bin/actool --compile ref  --platform macosx \
  --minimum-deployment-target 11.0 --app-icon feishin \
  --output-partial-info-plist ref/p.plist third_party/feishin/media/feishin.icon
python3 tools/compare_car.py out/Assets.car ref/Assets.car   # structural diff
./tools/validate_car out/Assets.car                          # 12 OK / 2 SKIP
```
