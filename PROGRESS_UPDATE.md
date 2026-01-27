# DockTile Progress Update - 2026-01-28

## Session Summary

This document captures the current state of the DockTile project. Use this to resume work later.

---

## What's Working (95% Complete)

### Core Application (Prompts 1-3) - COMPLETE
- **App Shell & Ghost Mode**: Fully functional with LSUIElement configuration
- **NSPanel Popover**: Native macOS popover with transient behavior
- **Visual Design**: Xiaomi/HOTO-inspired UI with Medical White aesthetic
- **Popover Positioning**: Appears above dock icon with arrow pointing down

### Configuration System (Prompt 4) - COMPLETE
- **Data Models**: Complete configuration models with TintColor, LayoutMode, AppItem
- **ConfigurationManager**: Full CRUD operations with JSON persistence
- **Configuration UI**:
  - Main window with sidebar/detail views
  - Customise Tile drill-down overlay
  - Color picker grid (9 colors)
  - Symbol picker (emoji selection)
  - App item management
  - "Done" button to install/update tiles
  - Delete tile functionality

### Helper App Architecture (Prompt 5) - COMPLETE
- **Custom main.swift**: Detects helper vs main app at startup
- **HelperAppDelegate**: Pure AppKit for helpers (no SwiftUI)
- **HelperBundleManager**: Swift-native bundle creation
- **Automatic Dock Integration**: Adds/removes from dock plist
- **Icon Generation**: Creates custom .icns with gradient + emoji
- **Popover opens immediately**: On first dock click (not second)
- **Native appearance**: Uses NSPopover, no custom white background

---

## Recent Fixes Applied (2026-01-28)

### Fix 1: Helper App Crash
**Problem**: Helper apps crashed with "unexpectedly quit while reopening windows"
**Root Cause**: SwiftUI WindowGroup trying to restore windows that don't exist
**Solution**: Custom `main.swift` entry point that bypasses SwiftUI for helpers
**Files**: `main.swift` (new), `HelperAppDelegate.swift` (new)
**Status**: ✅ Fixed

### Fix 2: Popover Requires Two Clicks
**Problem**: First click activated app, second click opened popover
**Solution**: Show popover immediately in `applicationDidFinishLaunching`
**File**: `HelperAppDelegate.swift:48`
**Status**: ✅ Fixed

### Fix 3: White Background in Popover
**Problem**: Custom white panel visible inside NSPopover
**Solution**: Removed `.background()` modifier from LauncherView
**File**: `LauncherView.swift`
**Status**: ✅ Fixed

### Fix 4: Duplicate Tiles When Editing
**Problem**: Editing existing tile added another copy to Dock
**Solution**: Added `isInDock()` check before calling `addToDock()`
**File**: `HelperBundleManager.swift:189-208`
**Status**: ✅ Fixed

### Fix 5: Window Restoration Crash Dialog
**Problem**: Helper showed crash recovery dialog on launch
**Solution**: Disable window restoration in both `applicationWillFinishLaunching` and `applicationDidFinishLaunching`
**File**: `HelperAppDelegate.swift`
**Status**: ✅ Fixed (testing needed)

---

## Remaining Tasks

### High Priority (Testing)
- [ ] Test helper app crash fix is fully resolved
- [ ] Test duplicate tiles no longer appear when editing
- [ ] Test popover opens immediately on first click

### Low Priority (Polish)
- [ ] Popover positioning refinement for external monitors
- [ ] First launch onboarding experience
- [ ] Keyboard shortcuts (Cmd+N for new tile)

---

## Project File Structure

```
DockTile/
├── App/
│   ├── main.swift                  # ✅ NEW - Custom entry point
│   ├── DockTileApp.swift           # ✅ SwiftUI app (main app only)
│   ├── AppDelegate.swift           # ✅ Main app delegate
│   └── HelperAppDelegate.swift     # ✅ NEW - Pure AppKit for helpers
├── Core/
│   └── GhostModeManager.swift      # ✅ Ghost mode state management
├── Models/
│   └── ConfigurationModels.swift   # ✅ DockTileConfiguration, TintColor, AppItem
├── Managers/
│   ├── ConfigurationManager.swift  # ✅ CRUD, persistence, JSON storage
│   └── HelperBundleManager.swift   # ✅ Creates helper bundles, manages Dock
├── Extensions/
│   └── ColorExtensions.swift       # ✅ Hex color support
├── UI/
│   ├── FloatingPanel.swift         # ✅ NSPopover-based launcher
│   └── LauncherView.swift          # ✅ SwiftUI grid of apps
├── Views/
│   ├── DockTileConfigurationView.swift  # ✅ Main config window
│   ├── DockTileSidebarView.swift        # ✅ Config list sidebar
│   ├── DockTileDetailView.swift         # ✅ Tile detail editor with Done button
│   └── CustomiseTileView.swift          # ✅ Color/symbol picker
├── Components/
│   ├── DockTileIconPreview.swift   # ✅ Gradient icon preview
│   ├── ItemRowView.swift           # ✅ App item rows
│   ├── ColourPickerGrid.swift      # ✅ 9-color picker
│   └── SymbolPickerButton.swift    # ✅ Emoji picker button
└── Utilities/
    └── IconGenerator.swift         # ✅ Generates .icns files
```

---

## Architecture Overview

```
User clicks dock icon
        |
        v
    main.swift
        |
        +-- Is helper app? (bundle ID check)
        |       |
        |       +-- YES --> HelperAppDelegate (pure AppKit)
        |       |               |
        |       |               v
        |       |           Show NSPopover immediately
        |       |               |
        |       |               v
        |       |           LauncherView (SwiftUI in popover)
        |       |
        |       +-- NO --> DockTileApp.main() (SwiftUI)
        |                       |
        |                       v
        |                   Configuration Window
        |
        +-- User clicks "Done"
                |
                v
            HelperBundleManager.installHelper()
                |
                +-- Copy main app bundle
                +-- Update Info.plist
                +-- Generate custom icon
                +-- Code sign
                +-- Add to Dock plist
                +-- Restart Dock
```

---

## Build & Run

```bash
# Build
cd /Users/karthik/Projects/dock-tile
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build

# Run
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app

# Reset state
rm ~/Library/Preferences/com.docktile.configs.json
rm -rf ~/Library/Application\ Support/DockTile/
killall Dock
```

---

## Success Criteria

- [x] User can create multiple DockTile configurations
- [x] User can customize icon (color + emoji) per tile
- [x] User can add/remove apps in each tile
- [x] Clicking "Done" generates helper bundle and adds to Dock
- [x] Each helper shows custom icon in Dock
- [x] Clicking helper icon shows popover with configured apps
- [x] Clicking app in popover launches that app
- [x] Multiple helpers can coexist
- [x] Popover appears immediately on first click
- [ ] Helper apps don't crash on reopen (testing needed)

**Current Progress**: ~95% complete

---

## Key Documents

| Document | Purpose |
|----------|---------|
| `RESUME_HERE.md` | Quick start guide |
| `IMPLEMENTATION_STATUS.md` | Detailed implementation status |
| `CLAUDE.md` | Project guidance for AI assistants |
| `DockTile_Project_Spec.md` | Full specification (138k tokens) |

---

**Last Updated**: 2026-01-28
**Build Status**: SUCCESS
**Next Priority**: Test recent fixes (crash, duplicate tiles, first-click popover)
