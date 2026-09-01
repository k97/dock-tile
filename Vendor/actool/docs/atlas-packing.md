# Apple actool Atlas Packing - Reverse Engineering Notes

## Overview

Apple's `actool` packs small images into atlas textures to reduce the number
of individual renditions in the CAR file. This document describes the packing
algorithm based on analysis of system actool output.

## Grouping Rules

1. **Format grouping**: Images are grouped by pixel format (BGRA vs GA8)
2. **Scale grouping**: Separate atlas per scale (@1x, @2x)
3. **Icon separation**: App icon images (Part=220) are packed into a separate
   atlas group from regular images (Part=181)
4. **Minimum threshold**: At least 2 images per group to trigger packing.
   Single images are stored inline (layout=12)
5. **Large icon threshold**: App icon images >= 256x256 pixels are stored
   inline, not packed

## Atlas Structure

Each atlas group produces:
- A **PackedAsset** rendition (layout=1004) containing the compressed atlas
  texture. Uses Element=9 (packed asset element), Part=181.
- **PackedImage** references (layout=1003) for each image, containing an
  INLK TLV with position/size in the atlas.

## Packing Algorithm

Column-based bin packing:
- 2px margin on all edges
- 2px gap between images
- Images sorted by height descending, then width descending
- Images stacked vertically in columns
- When image doesn't fit in existing column, start new column

## INLK TLV Format (0x03F2)

```
Offset  Size  Description
0       4     Tag: 'KLNI' (LE uint32 of 'INLK')
4       4     Version: 0
8       4     X offset in atlas (LE uint32)
12      4     Y offset in atlas (LE uint32)
16      4     Width (LE uint32)
20      4     Height (LE uint32)
24+     var   Trailing: stride info + rendition key attributes
```

The trailing bytes contain:
- Stride/bytesPerRow info (varies)
- Rendition key attribute pairs for the PackedAsset (Element=9, Part=181, Scale, etc.)

## Atlas Naming

Format: `ZZZZPackedAsset-{scale}.0.{format_idx}-gamut0`
- scale: 1 for @1x, 2 for @2x
- format_idx: 0 for BGRA, 1 for GA8

## dim1 Mapping

The atlas index lives in the **dim1 key attribute (8)**, NOT the name — the
name's middle field is always `0` (`Atlas::name`), so every atlas of a given
(scale, format) shares a name and is told apart by its dim1 key. dim1 is a
**per-scale counter spanning both formats**: on iina @1x, BGRA atlases get
dim1 0..12 and the GA8 atlases continue at 13..14; @2x, BGRA 0..3 then GA8 4..7.
Packed-image INLK links carry that dim1, so resolution is by key, not name.

## xcassets packing: functional parity, byte geometry is renderer-bound

Our atlas packing is **functionally identical to Apple** — iina compiles to
98 OK / 0 FAILED via `validate_car`, the same as Apple's own `.car`. CUICatalog
resolves each packed sprite from the INLK `(x,y,w,h)` coordinates, which we emit
correctly, so the icons load regardless of how the atlas sheet itself is laid
out.

The atlas **geometry** still differs from Apple byte-for-byte (different sheet
dimensions, sprite-to-atlas assignment, atlas count) and is the proprietary
bin-packer — the same one dropped below for iOS app icons. Apple's packer is
**size-bucketed**: on iina @1x it puts the 128×128 sprites two-to-an-atlas in a
single row (262×132, eleven such atlases for the 22 sprites), packs the 32×32
sprites 21-to-an-atlas in a 5-column grid (172×172), and the 16×16 + leftovers in
a 108×90 sheet; @2x sheets reach 224×224 / 290×138 (wider than our 262 cap). The
max-dimension and bucketing rules don't reduce to a simple cap (172-tall grids
coexist with 132-tall single rows), matching the "wasn't reverse-engineerable
from a 59-config sweep" conclusion below. Since it's byte-only (functional parity
holds), it is intentionally left unmatched — do not retune `pack_images_split`.

---

## iOS app-icon atlas packing (`--platform iphoneos`)

iOS app icons pack into `ZZZZPackedAsset-*-gamut0` atlases like the macOS
sprite path, but with idiom-specific behavior. Implemented in
`packer::group_for_packing`, `compiler.rs`, and `car::make_inlk_tlv`.

### Grouping

- App icons all share the **icon facet identifier**, so the usual "≥2 distinct
  identifiers" rule would leave every icon inline. Instead an iOS icon group
  packs when it holds **≥2 distinct sizes (dim2)**.
- The pack group key includes **idiom**, so Apple's **per-idiom atlases** are
  reproduced (phone / pad / marketing never share an atlas). Idiom is 0 on
  macOS, leaving that grouping unchanged.
- The synthesized subtype-1792 Plus-phone icon is forced **inline**
  (`subtype != 0 → inline`).

### Idiom must thread through packing (silent-failure gotcha)

`PackedImage.idiom` feeds the **atlas key**, the **packed-ref key**, *and* the
**INLK link attribute 15**. The INLK link names the atlas by its key
attributes; on iOS the atlas key carries idiom (attr 15), so the link must too.
If the INLK omits the idiom attr, CUICatalog cannot resolve a packed image to
its idiom-keyed atlas and `imagesWithName:` silently returns empty even though
every key looks correct. The reference INLK attr stream for a phone atlas is
`[0, (1,9)element, (2,181)part, (12,scale), (15,idiom), 0]`.

### dim1

`dim1` (atlas index) is counted **per (scale, idiom)** — `dim1_by_scale` is
keyed by `(scale, idiom)`. Apple resets it to 0 for the first atlas of each
idiom at a scale, so e.g. scale-2 phone dim1=0, scale-2 pad dim1=0,1. The
`dim1(8)` key column appears when a scale has >1 atlas (the 2nd gets dim1=1).

### Atlas naming

For **imagesets** the name middle field is the dim1 (`ZZZZPackedAsset-{scale}.0.0-gamut0`
for the first atlas) and our output matches Apple. For **app icons** Apple uses
a constant middle of **1** (`ZZZZPackedAsset-{scale}.1.0-gamut0`), decoupled
from the key's dim1 (which is 0/1). We do not yet reproduce this — see below.

## iOS app-icon atlas *geometry* — NOT matched (dropped)

The atlas's internal pixel layout (which icons land in which atlas, at what
x,y, and the resulting dimensions) does **not** byte-match Apple. This is the
only remaining iOS app-icon parity gap and it is **functionally irrelevant**:
CUICatalog reads packed icons via the exact INLK (x,y,w,h) coordinates we
emit, so a different arrangement still resolves (`validate_car` OK). Every
non-atlas rendition, key, multisize and the subtype-1792 synthesis match.

Apple's icon packer is a **shelf+column 2D bin-packer** (margin 2, gap 2,
descending size sort — same *structure* as `packer::pack_shelf_atlas`), but a
59-config controlled sweep (harness `tools/sweep_atlas_geometry.py`, data
`tools/atlas_sweep_dataset.json`, across iphone@2x/@3x and ipad@1x/@2x) could
not reverse its max-dimension / atlas-split heuristics. Every hypothesis is
contradicted by some sample:

- **Variable max width**: an iPad atlas reaches **324** wide (`[167,152]`)
  while a phone atlas caps at **306** (`[180,120]` then wraps).
- **Tie-breaks aren't fixed**: in `[76,40,29,20]` the 3rd image (29) stacks
  under the *shorter* column but the 4th (20) stacks under the *taller* one —
  so neither shortest-column-first nor leftmost-first holds.
- **A scale-dependent close** (`H ≥ ~85×scale`: scale2≈170, scale3≈255) fits
  the *new-shelf* cases (`[40,58,80,152]` H=156 adds a row → ok;
  `[40,58,80,167]` H=171 → splits) but **not** the column-fill cases.
- **Fatal**: `[180,120,87,60]` (iphone@3x) splits the 60 into its own atlas
  even though it fits geometrically as a new column at (91,184) in row 1 —
  exactly mirroring how `[120,80,58,40]` legally places 40 at (62,124). No
  max-dimension, max-area, aspect-ratio, 2-row, dim2-threshold, or home-screen
  rule explains the split here while allowing the scale-2 column fills.

Exact reference atlas layouts for the canonical phone+ipad+marketing fixture
(margin 2, gap 2), as `WxH @ (x,y)`:

- scale1 pad 122×102: 76@(2,2) 40@(80,2) 20@(2,80) 29@(80,44)
- scale2 phone 206×184: 120@(2,2) 80@(124,2) 58@(2,124) 40@(62,124)
- scale2 pad-A 324×170: 167@(2,2) 152@(171,2)  ·  scale2 pad-B 144×126: 80@(2,2) 58@(84,2) 40@(2,84)
- scale3 phone-A 306×272: 180@(2,2) 120@(184,2) 87@(2,184)  ·  scale3 phone-B 64×64: 60@(2,2)

**Conclusion**: a specific CUI bin-packer with internal tie-breaks/close logic
not inferable from black-box output. Left intentionally unmatched. Do **not**
retune the shared `pack_images_split` (it would break imageset parity, which
currently matches the Python reference) — a future attempt needs a dedicated
icon packer and likely the CoreUI source.
