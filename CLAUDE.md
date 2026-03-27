# Dock Tile

Multi-instance macOS utility (macOS 15.0+) that creates customizable dock tiles via helper bundles. Swift 6, SwiftUI + AppKit hybrid. v1.2.0 released.

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

## Verification

After making changes, run tests before committing:
```bash
xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug \
  -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO
```
