# Website Assets

Favicons in `website/public/favicon/` and `website/app/favicon.ico` (both must be updated together). Source logo SVG at `website/public/assets/dock-tile-icon-only.svg`. High-res PNG at `website/public/assets/dock-tile-icon-1024.png` — **use this for favicon generation** (ImageMagick cannot rasterize the SVG's gradient fills). Screenshot webp files in `website/public/assets/stage/` — only webp is used in code.

```bash
# Regenerate favicons from 1024px PNG source (requires ImageMagick + Lanczos filter)
magick dock-tile-icon-1024.png -resize 96x96 -filter Lanczos favicon-96x96.png

# Convert stage PNGs to webp
magick input.png -quality 80 output.webp

# Generate blur placeholder base64 for screenshot carousel
magick input.webp -resize 10x7 -quality 20 webp:- | base64
```

Blur placeholders go in `website/components/screenshot.tsx` as `data:image/webp;base64,...` strings.
