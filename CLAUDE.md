# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**DockTile** is a multi-instance macOS utility for macOS 15.0+ (Tahoe) that serves as a minimalist "app container" in the Dock. It enables power users to pin multiple distinct dock tiles (via Helper Bundles), each with independent app lists and custom icons/tints.

**Status**: Core functionality complete and working. Users can create tiles, customize icons, add apps, and use them from the Dock.

## Architecture Principles

### Multi-Instance Architecture
- Users generate unique Helper Bundles to create multiple independent dock tiles
- Each Helper instance maintains its own app list and visual customization
- Configuration shared via `~/Library/Preferences/com.docktile.configs.json`
- Helper bundles stored in `~/Library/Application Support/DockTile/`

### Hybrid UI Framework Strategy
- **SwiftUI**: For declarative UI components and views
- **AppKit (NSPopover)**: For precise Dock-style popovers with vibrancy
- **NSVisualEffectView**: For native vibrancy matching macOS Dock folders
- This hybrid approach balances modern Swift declarative patterns with low-level Dock integration

### Interaction Model
- **Left-click on Dock tile**: Shows NSPopover with app grid/list (native vibrancy)
- **Cmd+Tab**: If "App Switcher" enabled, shows popover with keyboard navigation
- **Right-click**: Shows context menu with app list and "Configure..." option
- **App Switcher toggle**: Uses `LSUIElement` + `setActivationPolicy()` to control Cmd+Tab visibility

## Technical Constraints

| Requirement | Specification |
|-------------|---------------|
| Platform | macOS 15.0+ (Tahoe Ready) |
| Language | Swift 6 (strict concurrency enabled) |
| UI | SwiftUI + AppKit NSPopover |
| Design System | Native vibrancy materials via NSVisualEffectView |
| Typography | System fonts with native macOS styling |
| Performance | <100ms popover appearance |

## Project Structure

```
DockTile/
├── App/
│   ├── main.swift                # Entry point with runtime detection
│   ├── DockTileApp.swift         # Main app SwiftUI App struct
│   ├── AppDelegate.swift         # Main app NSApplicationDelegate
│   └── HelperAppDelegate.swift   # Helper bundle delegate (Dock click handling)
├── Managers/
│   ├── ConfigurationManager.swift # State management with JSON persistence
│   ├── HelperBundleManager.swift  # Helper bundle creation/installation/Dock integration
│   └── DockPlistWatcher.swift     # Monitors Dock plist for manual removals
├── Models/
│   ├── ConfigurationModels.swift  # DockTileConfiguration, AppItem, TintColor, LayoutMode
│   └── ConfigurationSchema.swift  # Centralized defaults (ConfigurationDefaults)
├── UI/
│   ├── FloatingPanel.swift        # NSPopover wrapper with anchor window positioning
│   ├── LauncherView.swift         # Routes to Stack or List view based on layoutMode
│   └── NativePopoverViews.swift   # StackPopoverView (grid), ListPopoverView (menu-style)
├── Views/
│   ├── DockTileConfigurationView.swift  # Main window with sidebar + detail
│   ├── DockTileSidebarView.swift        # Sidebar with tile list
│   ├── DockTileDetailView.swift         # Detail panel (name, visibility, apps table)
│   └── CustomiseTileView.swift          # Icon customization (color + emoji picker)
├── Components/
│   ├── DockTileIconPreview.swift   # Icon preview with gradient background
│   ├── ColourPickerGrid.swift      # Color selection grid (legacy)
│   ├── SymbolPickerGrid.swift      # SF Symbol picker with categories
│   ├── EmojiPickerGrid.swift       # Emoji picker with categories
│   ├── IconGridOverlay.swift       # Apple icon guide grid overlay
│   ├── SymbolPickerButton.swift    # Emoji picker popover (legacy)
│   └── ItemRowView.swift           # Row view for app items
├── Utilities/
│   └── IconGenerator.swift         # Generates .icns files from tint color + emoji
├── Core/
│   └── GhostModeManager.swift      # (Legacy) Ghost mode utilities
├── Extensions/
│   └── ColorExtensions.swift       # Color hex initialization
└── Resources/
    ├── Assets.xcassets             # App icon and assets
    └── Info.plist                  # App configuration
```

## Build & Development Commands

```bash
# Build the project
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build

# Run tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile

# Clean build
xcodebuild -project DockTile.xcodeproj -scheme DockTile clean

# Build location
~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app
```

## Configuration Schema & Backward Compatibility

### Adding New Fields

When adding new properties to `DockTileConfiguration`:

1. **Add the field** to the struct with a default in the init
2. **Add default** in `ConfigurationDefaults` (in `ConfigurationSchema.swift`)
3. **Add to CodingKeys** enum
4. **Use `decodeIfPresent`** in the custom decoder with the default

Example:
```swift
// In DockTileConfiguration:
var newFeature: Bool

// In ConfigurationDefaults:
static let newFeature = false

// In CodingKeys:
case newFeature

// In init(from decoder:):
newFeature = try container.decodeIfPresent(Bool.self, forKey: .newFeature)
    ?? ConfigurationDefaults.newFeature
```

This approach handles 95% of schema changes. Old configs missing new fields will use defaults automatically.

### Current Configuration Fields (v2)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| id | UUID | Generated | Unique identifier |
| name | String | "My DockTile" | Display name |
| tintColor | TintColor | .blue | Icon background gradient color (preset or custom hex) |
| symbolEmoji | String | "⭐" | Legacy field for icon (deprecated) |
| iconType | IconType | .sfSymbol | Type of icon: .sfSymbol or .emoji |
| iconValue | String | "star.fill" | SF Symbol name or emoji character |
| layoutMode | LayoutMode | .grid2x3 | Stack (grid) or List |
| appItems | [AppItem] | [] | Apps in the tile |
| isVisibleInDock | Bool | false | Show helper in Dock |
| showInAppSwitcher | Bool | false | (v2) Show in Cmd+Tab |
| bundleIdentifier | String | Generated | Helper bundle ID |

## Key Implementation Details

### Helper Bundle Lifecycle

1. **Creation** (`HelperBundleManager.installHelper`):
   - Copies main DockTile.app as template
   - Updates Info.plist with unique bundle ID and name
   - Sets `LSUIElement = true` (hides from Cmd+Tab by default)
   - Generates custom `.icns` icon via `IconGenerator`
   - Code signs with ad-hoc signature
   - Adds to Dock plist and restarts Dock
   - Launches helper app

2. **Runtime** (`HelperAppDelegate`):
   - Reads `showInAppSwitcher` from config in `applicationWillFinishLaunching`
   - Calls `setActivationPolicy(.regular)` if should appear in Cmd+Tab
   - Shows NSPopover on dock icon click
   - Supports keyboard navigation when activated via Cmd+Tab

3. **Deletion** (`HelperBundleManager.uninstallHelper`):
   - Quits running helper
   - Removes from Dock plist
   - Deletes helper bundle
   - Restarts Dock

### App Switcher (Cmd+Tab) Visibility

The `showInAppSwitcher` toggle controls whether a tile appears in Cmd+Tab:

- **Info.plist**: `LSUIElement = true` makes app NOT appear in Cmd+Tab by default
- **Runtime**: `NSApp.setActivationPolicy(.regular)` overrides to show in Cmd+Tab
- **Why this order**: macOS ignores `setActivationPolicy(.accessory)` if `LSUIElement` is not set

### NSPopover Implementation

`FloatingPanel.swift` manages the Dock-style popover:
- Creates invisible anchor window at Dock icon position
- Uses NSPopover with `.maxY` edge (arrow points down)
- `NSVisualEffectView` with `.popover` material for native vibrancy
- Keyboard navigation via `KeyboardCaptureView` (custom NSView)
- Dismisses on click outside or Escape key

### Icon Generation

`IconGenerator.swift` creates macOS `.icns` files:
- Generates gradient background from `TintColor`
- Draws emoji symbol centered on gradient
- Creates iconset with all required sizes (16, 32, 128, 256, 512 @ 1x and 2x)
- Uses `iconutil` to convert iconset to `.icns`

### Dock Plist Watcher

`DockPlistWatcher.swift` monitors `com.apple.dock.plist`:
- Detects when user manually removes tile from Dock
- Syncs `isVisibleInDock` state in configuration
- Uses `DispatchSource.makeFileSystemObjectSource` for efficient watching

### Native macOS Color Patterns

SwiftUI's `Color(nsColor:)` initializer doesn't reliably bridge AppKit colors. Use `NSViewRepresentable` instead:

```swift
// ❌ Unreliable - may not render correctly
.background(Color(nsColor: .windowBackgroundColor))

// ✅ Reliable - uses AppKit layer directly
private struct WindowBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
}

// Usage
.background(WindowBackgroundView())
```

For vibrancy effects, use `NSVisualEffectView`:

```swift
private struct QuaternaryFillView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
```

**Common Native Colors:**
| Purpose | NSColor | Material |
|---------|---------|----------|
| Window background | `.windowBackgroundColor` | - |
| Card/control background | `.controlBackgroundColor` | - |
| Studio canvas/preview area | - | `.underWindowBackground` |
| Separator lines | `.separatorColor` | - |
| Secondary labels | `.secondaryLabelColor` | - |

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Main DockTile.app                        │
│  ┌──────────────────┐    ┌───────────────────────────────────┐ │
│  │ ConfigurationUI  │───▶│     ConfigurationManager          │ │
│  │ (SwiftUI Views)  │    │  • Loads/saves JSON config        │ │
│  └──────────────────┘    │  • Manages DockTileConfiguration  │ │
│                          │  • Starts DockPlistWatcher        │ │
│                          └──────────────┬────────────────────┘ │
│                                         │                       │
│  ┌──────────────────────────────────────▼────────────────────┐ │
│  │                  HelperBundleManager                      │ │
│  │  • Creates helper .app bundles                            │ │
│  │  • Generates icons (IconGenerator)                        │ │
│  │  • Manages Dock plist entries                             │ │
│  │  • Code signs helpers                                     │ │
│  └──────────────────────────────────────┬────────────────────┘ │
└─────────────────────────────────────────│───────────────────────┘
                                          │
                    ┌─────────────────────▼─────────────────────┐
                    │     ~/Library/Application Support/        │
                    │              DockTile/                     │
                    │  ┌─────────────────────────────────────┐  │
                    │  │  My DockTile.app (Helper Bundle)    │  │
                    │  │  • HelperAppDelegate                │  │
                    │  │  • Reads shared config JSON         │  │
                    │  │  • Shows NSPopover on click         │  │
                    │  │  • LSUIElement=true by default      │  │
                    │  └─────────────────────────────────────┘  │
                    │  ┌─────────────────────────────────────┐  │
                    │  │  Another Tile.app (Helper Bundle)   │  │
                    │  └─────────────────────────────────────┘  │
                    └───────────────────────────────────────────┘
                                          │
                    ┌─────────────────────▼─────────────────────┐
                    │     ~/Library/Preferences/                │
                    │     com.docktile.configs.json             │
                    │  • Shared configuration for all tiles     │
                    │  • Read by main app and all helpers       │
                    └───────────────────────────────────────────┘
```

## Recent Changes

### App Switcher Toggle Fix (2026-01)
- **Problem**: Toggle had no effect - tiles always appeared in Cmd+Tab
- **Root cause**: Without `LSUIElement` in Info.plist, macOS defaults to `.regular` policy and ignores `setActivationPolicy(.accessory)`
- **Fix**: Set `LSUIElement = true` in helper Info.plist, then call `setActivationPolicy(.regular)` only when `showInAppSwitcher = true`

### Icon Generation Fix (2026-01)
- **Problem**: `iconutil` failing with "icnsConversionFailed"
- **Root cause**: Iconset filenames were incorrect
- **Fix**: Use standard macOS iconset naming: `icon_NxN.png` and `icon_NxN@2x.png`

### CustomiseTileView Redesign (2026-01)
- **Design**: "Studio Canvas" layout with hero preview header and inspector card
- **Features**:
  - Large 160×160pt icon preview with Apple icon guide grid overlay
  - Color picker strip with 8 preset colors + custom color picker (NSColorPanel)
  - Segmented control for SF Symbol / Emoji tabs
  - Categorized symbol and emoji grids with scrolling
- **Native Colors** (AppKit bridged via NSViewRepresentable):
  - Studio Canvas: `NSVisualEffectView` with `.underWindowBackground` material
  - Inspector Card: `NSColor.controlBackgroundColor` via layer
  - Window Background: `NSColor.windowBackgroundColor` via layer
- **macOS 26 Support**: Uses `.buttonSizing(.flexible)` for full-width segmented control with fallback for earlier versions

### Icon Type System (2026-01)
- **Added**: `IconType` enum (`.sfSymbol`, `.emoji`) and `iconValue` field
- **Purpose**: Separate SF Symbols from emojis for proper rendering
- **Backward Compatibility**: `symbolEmoji` field kept for migration
- **IconGenerator**: Updated to handle both SF Symbols (rendered as white on gradient) and emojis

## Performance Targets

1. Popover appears in <100ms (measured from click event to window visible)
2. Zero flicker when toggling visibility modes
3. Helper instances maintain completely independent state
4. Keyboard navigation responsive when activated via Cmd+Tab

## Debugging Tips

### Check helper logs
```bash
# Launch helper and capture output
"/Users/karthik/Library/Application Support/DockTile/My DockTile.app/Contents/MacOS/DockTile" 2>&1
```

### Check saved configuration
```bash
cat ~/Library/Preferences/com.docktile.configs.json | python3 -m json.tool
```

### Check helper Info.plist
```bash
cat "/Users/karthik/Library/Application Support/DockTile/My DockTile.app/Contents/Info.plist"
```

### Force reinstall helper
Toggle "Show Tile" off and back on, then click "Done"

## UI Component Hierarchy

```
DockTileConfigurationView (Main Window)
├── NavigationSplitView
│   ├── DockTileSidebarView (Sidebar)
│   │   ├── ConfigurationRow (per tile)
│   │   │   └── MiniIconPreview (24×24pt)
│   │   └── Add/Delete buttons
│   │
│   └── Detail Area (ZStack for drill-down)
│       ├── DockTileDetailView (Screen 3)
│       │   ├── heroSection
│       │   │   ├── DockTileIconPreview (96×96pt)
│       │   │   ├── Customise button → drills to CustomiseTileView
│       │   │   └── Form (Name, Show Tile, Layout, App Switcher)
│       │   ├── appsTableSection (NativeAppsTableView)
│       │   └── deleteSection
│       │
│       └── CustomiseTileView (Screen 4 - drill-down)
│           ├── studioCanvas (QuaternaryFillView background)
│           │   ├── DockTileIconPreview (160×160pt)
│           │   ├── IconGridOverlay
│           │   └── Tile name
│           └── inspectorCard (ControlBackgroundView background)
│               ├── colourSection (preset swatches + custom picker)
│               └── tileIconSection
│                   ├── segmentedPicker (Symbol/Emoji tabs)
│                   └── ScrollView
│                       ├── SymbolPickerGrid (when .symbol)
│                       └── EmojiPickerGrid (when .emoji)
```

## Reference Documents

- **Full Specification**: `DockTile_Project_Spec.md` (comprehensive design document)
- This file is authoritative for all architectural and design decisions
