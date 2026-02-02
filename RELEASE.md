# Release Workflow

This document describes how to work with the Dev and Release versions of Dock Tile.

## Overview

The project supports two separate app variants that can be installed side-by-side:

| Variant | Scheme | Bundle ID | App Name | Config File |
|---------|--------|-----------|----------|-------------|
| **Dev** | `DockTile-Dev` | `com.docktile.dev.app` | Dock Tile Dev | `com.docktile.dev.configs.json` |
| **Release** | `DockTile` | `com.docktile.app` | Dock Tile | `com.docktile.configs.json` |

## Quick Start

### Development (Default)

```bash
# Build and run Dev version
xcodebuild -project DockTile.xcodeproj -scheme DockTile-Dev -configuration Debug build

# Or in Xcode: Select "DockTile-Dev" scheme → Run (⌘R)
```

### Release Testing

```bash
# Build Release version
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Release build

# Or in Xcode: Select "DockTile" scheme → Run (⌘R)
```

## Architecture

### xcconfig Files

Build settings are managed via xcconfig files in `DockTile/Config/`:

| File | Purpose |
|------|---------|
| `Base.xcconfig` | Shared settings (version, deployment target) |
| `Dev.xcconfig` | Dev-specific settings (bundle ID, app name, paths) |
| `Release.xcconfig` | Release-specific settings |

### Runtime Environment

The `AppEnvironment` enum in `DockTile/App/Environment.swift` reads environment-specific values from Info.plist at runtime:

```swift
// Check current environment
if AppEnvironment.isDev {
    print("Running Dev version")
}

// Get environment-specific paths
let configPath = AppEnvironment.preferencesURL  // ~/Library/Preferences/com.docktile[.dev].configs.json
let helperDir = AppEnvironment.supportURL       // ~/Library/Application Support/DockTile[-Dev]/
```

### Data Isolation

Dev and Release versions are completely isolated:

| Component | Dev | Release |
|-----------|-----|---------|
| Preferences | `~/Library/Preferences/com.docktile.dev.configs.json` | `~/Library/Preferences/com.docktile.configs.json` |
| Helper Bundles | `~/Library/Application Support/DockTile-Dev/` | `~/Library/Application Support/DockTile/` |
| Helper Bundle IDs | `com.docktile.dev.<UUID>` | `com.docktile.<UUID>` |

## Schemes

### DockTile-Dev (Development)

- **Configuration**: Debug
- **Bundle ID**: `com.docktile.dev.app`
- **Product Name**: Dock Tile Dev
- **Use Case**: Day-to-day development and testing

### DockTile (Release)

- **Configuration**: Release
- **Bundle ID**: `com.docktile.app`
- **Product Name**: Dock Tile
- **Use Case**: Final testing before distribution, CI/CD builds

## Dev App Icon (Optional)

To visually distinguish the Dev version:

1. Create `DockTile/Resources/AppIcon-Dev.icon/` folder
2. Add Icon Composer format files:
   - `icon.json`
   - `Assets/icon-light.png`
   - `Assets/icon-dark.png`
   - `Assets/icon-tinted.png`
3. Add to Xcode project
4. The Dev.xcconfig already references `AppIcon-Dev`

**Note**: Until you create the dev icon, Dev builds will fall back to the default `AppIcon`.

## Adding New Environment-Specific Settings

1. **Add to xcconfig files** (`Dev.xcconfig` and `Release.xcconfig`):
   ```
   MY_NEW_SETTING = value-for-this-environment
   ```

2. **Add to Info.plist** (if needed at runtime):
   ```xml
   <key>MyNewSetting</key>
   <string>$(MY_NEW_SETTING)</string>
   ```

3. **Add to Environment.swift** (if needed in code):
   ```swift
   static let myNewSetting: String = {
       Bundle.main.infoDictionary?["MyNewSetting"] as? String ?? "default"
   }()
   ```

## CI/CD Considerations

### GitHub Actions

The CI workflow uses the `DockTile` scheme by default. Ensure your workflows specify the correct scheme:

```yaml
# For Dev builds
- run: xcodebuild -scheme DockTile-Dev -configuration Debug build

# For Release builds
- run: xcodebuild -scheme DockTile -configuration Release build
```

### Release Builds

For distribution, always use the `DockTile` scheme with Release configuration:

```bash
./Scripts/build-release.sh --sign --notarize
```

## Troubleshooting

### Wrong Bundle ID

If the app shows the wrong bundle ID:
1. Clean build folder: `xcodebuild clean`
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/DockTile-*`
3. Rebuild with the correct scheme

### Config File Not Found

Helper tiles may fail to load if the config file doesn't exist:
- Dev helpers look for: `com.docktile.dev.configs.json`
- Release helpers look for: `com.docktile.configs.json`

Create at least one tile in the main app to initialize the config file.

### Schemes Not Visible

If schemes don't appear in Xcode:
1. Close Xcode
2. Delete xcuserdata: `rm -rf DockTile.xcodeproj/xcuserdata`
3. Reopen Xcode - shared schemes should appear

## Development Workflow

### Process Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPMENT WORKFLOW                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐
  │  START       │
  │  New Feature │
  └──────┬───────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: DEVELOPMENT (Dev Version)                                              │
│ ─────────────────────────────────────────────────────────────────────────────── │
│                                                                                 │
│  Scheme: DockTile-Dev          Bundle ID: com.docktile.dev.app                 │
│  Config:  Debug                 Data: com.docktile.dev.configs.json            │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Write Code  │───▶│ Build Dev   │───▶│ Run & Test  │───▶│ Unit Tests  │     │
│  │             │    │ ⌘B          │    │ ⌘R          │    │ ⌘U          │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘     │
│                                                                   │            │
│                          ┌────────────────────────────────────────┘            │
│                          │                                                     │
│                          ▼                                                     │
│                    ┌───────────┐   No                                          │
│                    │ Tests     │──────┐                                        │
│                    │ Pass?     │      │                                        │
│                    └─────┬─────┘      │                                        │
│                          │ Yes        │                                        │
│                          ▼            ▼                                        │
│                    ┌───────────┐  ┌───────────┐                                │
│                    │ Commit    │  │ Fix Bugs  │────┐                           │
│                    │ Changes   │  └───────────┘    │                           │
│                    └─────┬─────┘                   │                           │
│                          │         ┌───────────────┘                           │
│                          │         │                                           │
└──────────────────────────┼─────────┼───────────────────────────────────────────┘
                           │         │
                           ▼         │
                     ┌───────────┐   │
                     │ Ready for │   │
                     │ Release?  │───┘ No
                     └─────┬─────┘
                           │ Yes
                           ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: PRE-RELEASE TESTING (Release Version)                                  │
│ ─────────────────────────────────────────────────────────────────────────────── │
│                                                                                 │
│  Scheme: DockTile              Bundle ID: com.docktile.app                     │
│  Config:  Release               Data: com.docktile.configs.json                │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Switch to   │───▶│ Build       │───▶│ Run Tests   │───▶│ Manual QA   │     │
│  │ DockTile    │    │ Release     │    │ (Release)   │    │ Testing     │     │
│  │ Scheme      │    │             │    │             │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘     │
│                                                                   │            │
│                                                                   ▼            │
│                                                             ┌───────────┐      │
│                                                             │ Issues    │      │
│                                                             │ Found?    │      │
│                                                             └─────┬─────┘      │
│                                                                   │            │
└───────────────────────────────────────────────────────────────────┼────────────┘
                           │                                        │
                           │ No                                     │ Yes
                           ▼                                        │
┌─────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: CI/CD PIPELINE                                                         │
│ ─────────────────────────────────────────────────────────────────────────────── │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                         │
│  │ Push to     │───▶│ GitHub      │───▶│ CI Tests    │                         │
│  │ Branch/PR   │    │ Actions     │    │ Pass?       │                         │
│  └─────────────┘    └─────────────┘    └──────┬──────┘                         │
│                                               │                                 │
│                              ┌────────────────┴────────────────┐               │
│                              │ Yes                             │ No            │
│                              ▼                                 ▼               │
│                        ┌───────────┐                    ┌───────────┐          │
│                        │ Merge PR  │                    │ Fix &     │──────────┼──▶ Back to
│                        └─────┬─────┘                    │ Re-push   │          │    Phase 1
│                              │                          └───────────┘          │
│                              ▼                                                 │
│                        ┌───────────┐                                           │
│                        │ Tag       │                                           │
│                        │ Release   │                                           │
│                        │ (v1.x.x)  │                                           │
│                        └─────┬─────┘                                           │
│                              │                                                 │
└──────────────────────────────┼─────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: RELEASE                                                                │
│ ─────────────────────────────────────────────────────────────────────────────── │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Build       │───▶│ Code Sign   │───▶│ Notarize    │───▶│ Create DMG  │     │
│  │ Release     │    │ (Developer  │    │ (Apple)     │    │ Installer   │     │
│  │             │    │  ID)        │    │             │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘     │
│                                                                   │            │
│                                                                   ▼            │
│                                                            ┌───────────┐       │
│                                                            │ GitHub    │       │
│                                                            │ Release   │       │
│                                                            │ Published │       │
│                                                            └───────────┘       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Workflow Commands Summary

| Phase | Action | Command |
|-------|--------|---------|
| **Development** | Build Dev | `xcodebuild -scheme DockTile-Dev -configuration Debug build` |
| | Run Dev | `open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/Dock\ Tile\ Dev.app` |
| | Test Dev | `xcodebuild test -scheme DockTile-Dev -only-testing:DockTileTests` |
| **Pre-Release** | Build Release | `xcodebuild -scheme DockTile -configuration Release build` |
| | Test Release | `xcodebuild test -scheme DockTile -only-testing:DockTileTests` |
| **CI/CD** | Push | `git push origin feature-branch` |
| | Tag Release | `git tag -a v1.0.0 -m "Release 1.0.0" && git push origin v1.0.0` |
| **Release** | Full Build | `./Scripts/build-release.sh --sign --notarize` |

### Data Isolation During Development

```
┌─────────────────────────────────────────────────────────────────┐
│                     YOUR MAC                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────┐   ┌─────────────────────────┐     │
│  │    DEV VERSION          │   │   RELEASE VERSION       │     │
│  │    (Dock Tile Dev)      │   │   (Dock Tile)           │     │
│  ├─────────────────────────┤   ├─────────────────────────┤     │
│  │                         │   │                         │     │
│  │  Bundle ID:             │   │  Bundle ID:             │     │
│  │  com.docktile.dev.app   │   │  com.docktile.app       │     │
│  │                         │   │                         │     │
│  │  Config File:           │   │  Config File:           │     │
│  │  ...dev.configs.json    │   │  ...configs.json        │     │
│  │                         │   │                         │     │
│  │  Helper Bundles:        │   │  Helper Bundles:        │     │
│  │  ~/Library/App Support/ │   │  ~/Library/App Support/ │     │
│  │  DockTile-Dev/          │   │  DockTile/              │     │
│  │                         │   │                         │     │
│  │  ┌─────────────────┐    │   │  ┌─────────────────┐    │     │
│  │  │ Test Tile 1     │    │   │  │ My Apps         │    │     │
│  │  │ com.docktile.   │    │   │  │ com.docktile.   │    │     │
│  │  │ dev.<UUID>      │    │   │  │ <UUID>          │    │     │
│  │  └─────────────────┘    │   │  └─────────────────┘    │     │
│  │  ┌─────────────────┐    │   │  ┌─────────────────┐    │     │
│  │  │ Test Tile 2     │    │   │  │ Work Tools      │    │     │
│  │  │ com.docktile.   │    │   │  │ com.docktile.   │    │     │
│  │  │ dev.<UUID>      │    │   │  │ <UUID>          │    │     │
│  │  └─────────────────┘    │   │  └─────────────────┘    │     │
│  │                         │   │                         │     │
│  └─────────────────────────┘   └─────────────────────────┘     │
│           │                             │                       │
│           │  COMPLETELY ISOLATED        │                       │
│           │  No shared data             │                       │
│           └─────────────────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Testing Localized Versions

```bash
# Test UK English on Dev version (safe - won't affect production data)
defaults write com.docktile.dev.app AppleLanguages "(en-GB)"
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/Dock\ Tile\ Dev.app

# Reset to system language
defaults delete com.docktile.dev.app AppleLanguages

# Test UK English on Release version (uses real production data)
defaults write com.docktile.app AppleLanguages "(en-GB)"
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Release/Dock\ Tile.app

# Reset
defaults delete com.docktile.app AppleLanguages
```

### Updating App Icons

After updating icon files in `AppIcon.icon/` or `AppIcon-Dev.icon/`:

```bash
# 1. Clean build
xcodebuild -scheme DockTile-Dev clean   # or DockTile for Release

# 2. Rebuild
xcodebuild -scheme DockTile-Dev -configuration Debug build

# 3. Clear icon cache (if icon doesn't update)
killall iconservicesd && killall Dock

# 4. Run
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/Dock\ Tile\ Dev.app
```

## Migration Notes

### Existing Installations

If you have existing tiles from before the Dev/Release separation:
- Existing configs use the Release paths (`com.docktile.configs.json`)
- Existing helpers have Release bundle IDs (`com.docktile.<UUID>`)
- They will continue to work with the Release scheme
- Dev builds will start fresh with no tiles

### Switching Between Versions

Both versions can run simultaneously with completely separate data. No migration is needed - they operate independently.
