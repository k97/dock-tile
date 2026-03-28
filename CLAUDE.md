# Dock Tile

Multi-instance macOS utility (macOS 15.0+) that creates customizable dock tiles via helper bundles. Swift 6, SwiftUI + AppKit hybrid. v1.2.1 released.

## Commands

```bash
# Build Debug
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build

# Build Release
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Release build
```

## Dev vs Release Builds

Debug and Release use **separate data paths** to prevent dev data mixing with production:

| | Debug | Release |
|---|---|---|
| Bundle ID suffix | `.dev` | (none) |
| Config file | `com.docktile.dev.configs.json` | `com.docktile.configs.json` |
| Support folder | `DockTile-Dev/` | `DockTile/` |

Controlled via Info.plist variables (`DTEnvironment`, `DTHelperPrefix`, `DTPrefsFilename`, `DTSupportFolder`). Always use Debug configuration for development.

## Rules

- [Architecture](/.claude/rules/architecture.md) — Helper bundles, Ghost/App mode, NSPopover, CFPreferences
- [Development](/.claude/rules/development.md) — Code patterns, schema evolution, shared utilities
- [Testing](/.claude/rules/testing.md) — Swift Testing framework, commands, coverage targets
- [CI & Release](/.claude/rules/ci-release.md) — GitHub Actions, Sparkle updates, code signing
- [Localization](/.claude/rules/localization-macos.md) — String Catalogs, US/UK/AU English
- [Icon System](/.claude/rules/icon-system.md) — Tahoe icon generation, icon styles, Icon Composer

## Website Assets

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

## Verification

After making changes, run tests before committing:
```bash
xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug \
  -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO
```
