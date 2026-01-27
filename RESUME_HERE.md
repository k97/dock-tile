# Resume Development Here

**Last Updated**: 2026-01-28
**Current Status**: ~95% Complete, Helper App Architecture Working

---

## Quick Start Commands

```bash
# Navigate to project
cd /Users/karthik/Projects/dock-tile

# Build the app
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build

# Run the app
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app

# Reset app state (if needed)
rm ~/Library/Preferences/com.docktile.configs.json
rm -rf ~/Library/Application\ Support/DockTile/
```

---

## What's Working

### Core Features (100% Complete)
- Main app launches with configuration window (Screen 3)
- Create/edit/delete tile configurations
- Customise tile appearance (color + emoji) via drill-down (Screen 4)
- Add/remove apps to tiles via file picker
- JSON persistence to `~/Library/Preferences/com.docktile.configs.json`

### Helper App Architecture (95% Complete)
- Custom `main.swift` entry point - bypasses SwiftUI for helpers
- `HelperAppDelegate.swift` - Pure AppKit delegate for helper apps
- Helper bundles created in `~/Library/Application Support/DockTile/`
- Helper apps added to Dock automatically (no manual pinning)
- Popover opens immediately on first dock click
- Native NSPopover appearance (no custom white background)
- Duplicate tile prevention when editing

### Recent Fixes Applied
- **Helper crash fix**: Disabled window restoration (`NSQuitAlwaysKeepsWindows`)
- **Duplicate tiles fix**: Added `isInDock()` check before adding
- **Popover opens on first click**: Show popover in `applicationDidFinishLaunching`
- **Native popover appearance**: Removed custom background from LauncherView

---

## Known Issues / Remaining Tasks

### Testing Needed
- [ ] Verify helper app crash is fixed (was showing "unexpectedly quit while reopening windows")
- [ ] Verify duplicate tiles no longer appear when editing existing tiles
- [ ] Test popover positioning on external monitors

### Minor Polish (Optional)
- [ ] Popover positioning refinement (currently uses fixed dock height of 70pt)
- [ ] First launch experience / onboarding
- [ ] Keyboard shortcuts (Cmd+N for new tile)

---

## Architecture Overview

```
User clicks dock icon -> Which app?
                           |
            +--------------+---------------+
            |                              |
    Main App (com.docktile.app)    Helper (com.docktile.{UUID})
            |                              |
    SwiftUI WindowGroup            Pure AppKit
    DockTileApp.main()             HelperAppDelegate
            |                              |
    Configuration Window           NSPopover with apps
```

### Key Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point - detects helper vs main app |
| `HelperAppDelegate.swift` | Pure AppKit for helper apps |
| `DockTileApp.swift` | SwiftUI app for main app only |
| `HelperBundleManager.swift` | Creates/installs helper bundles |
| `FloatingPanel.swift` | NSPopover wrapper for dock popovers |
| `LauncherView.swift` | SwiftUI grid of apps in popover |

### Helper Bundle Location
```
~/Library/Application Support/DockTile/
├── AI Tile.app
├── Dev Tools.app
└── ...
```

---

## Debugging

### View Console Logs
```bash
# Real-time logs for helper apps
log stream --predicate 'processImagePath CONTAINS "DockTile"' --level debug
```

### Expected logs when helper launches:
```
Starting as helper app (pure AppKit)
Helper app launching...
   Bundle ID: com.docktile.XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
Loaded config: AI Tile with 4 apps
Helper app ready
Showing popover for helper tile
```

### Reset Everything
```bash
# Delete configurations
rm ~/Library/Preferences/com.docktile.configs.json

# Delete helper apps
rm -rf ~/Library/Application\ Support/DockTile/

# Restart Dock to remove stale entries
killall Dock
```

---

## Key Documents

| Document | Purpose |
|----------|---------|
| `IMPLEMENTATION_STATUS.md` | Detailed implementation status |
| `PROGRESS_UPDATE.md` | Comprehensive progress and remaining tasks |
| `CLAUDE.md` | Project guidance for AI assistants |
| `DockTile_Project_Spec.md` | Full specification (138k tokens) |

---

## Success Criteria

The project is feature-complete when:
- [x] User can create multiple DockTile configurations
- [x] User can customize icon (color + emoji) per tile
- [x] User can add/remove/reorder apps in each tile
- [x] Clicking "Done" generates helper bundle and adds to Dock
- [x] Each helper shows custom icon in Dock
- [x] Clicking helper icon shows popover with configured apps
- [x] Clicking app in popover launches that app
- [x] Multiple helpers can coexist
- [x] Popover appears immediately on first click
- [ ] Helper apps don't crash on reopen (testing needed)

**Current Progress**: ~95% complete

---

**Next Priority**: Test the helper app crash fix and duplicate tile fix
