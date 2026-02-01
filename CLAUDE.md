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
│   ├── IconStyleManager.swift     # Observes macOS icon style (Default/Dark/Clear/Tinted)
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
│   ├── SymbolPickerGrid.swift      # SF Symbol picker with categories
│   ├── EmojiPickerGrid.swift       # Emoji picker with categories
│   ├── IconGridOverlay.swift       # Apple icon guide grid overlay
│   └── ItemRowView.swift           # Row view for app items
├── Utilities/
│   └── IconGenerator.swift         # Generates .icns files from tint color + emoji
├── Extensions/
│   └── ColorExtensions.swift       # Color hex initialization
└── Resources/
    ├── AppIcon.icon/               # Main app icon (Icon Composer format)
    │   ├── icon.json               # Icon configuration with layers
    │   ├── icon-light.png          # Light mode variant
    │   ├── icon-dark.png           # Dark mode variant
    │   └── icon-tinted.png         # Tinted mode variant
    ├── Assets.xcassets             # Other assets (compiled includes AppIcon)
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

### Current Configuration Fields (v4)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| id | UUID | Generated | Unique identifier |
| name | String | "New Tile" | Display name |
| tintColor | TintColor | .gray | Icon background gradient color (preset or custom hex) |
| symbolEmoji | String | "⭐" | Legacy field for icon (deprecated) |
| iconType | IconType | .sfSymbol | Type of icon: .sfSymbol or .emoji |
| iconValue | String | "star.fill" | SF Symbol name or emoji character |
| iconScale | Int | 14 | (v4) Icon size scale (10-20 range) |
| layoutMode | LayoutMode | .grid2x3 | Stack (grid) or List |
| appItems | [AppItem] | [] | Apps in the tile |
| isVisibleInDock | Bool | true | Show helper in Dock (enabled by default) |
| showInAppSwitcher | Bool | false | (v2) Show in Cmd+Tab |
| bundleIdentifier | String | Generated | Helper bundle ID |

## Key Implementation Details

### Helper Bundle Lifecycle

1. **Creation** (`HelperBundleManager.installHelper`):
   - Copies main DockTile.app as template
   - **Removes `Assets.car`** to prevent main app icon from overriding custom icons
   - Updates Info.plist with unique bundle ID and name
   - Sets `LSUIElement = true` (hides from Cmd+Tab by default)
   - Generates custom `.icns` icon via `IconGenerator` (all 4 style variants)
   - Code signs with ad-hoc signature
   - Saves original Dock position (if updating existing tile)
   - Adds to Dock plist at original position (or end if new)
   - Restarts Dock and launches helper app

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

`FloatingPanel.swift` manages the Dock-style popover with dynamic Dock-anchored positioning:

**Dock Position Detection:**
- Compares `NSScreen.main.frame` vs `visibleFrame` to detect Dock position (bottom/left/right)
- The side with the largest gap between frame and visibleFrame indicates Dock location

**Hard Edge Anchoring (visibleFrame boundary):**
- **Bottom Dock**: Anchor Y = `visibleFrame.minY`, mouse used only for X-axis
- **Left Dock**: Anchor X = `visibleFrame.minX`, mouse used only for Y-axis
- **Right Dock**: Anchor X = `visibleFrame.maxX`, mouse used only for Y-axis
- This ensures popover always anchors flush to the Dock edge, regardless of click depth

**Preferred Edge Selection:**
- Bottom Dock: `.minY` (arrow points down toward Dock)
- Left Dock: `.minX` (arrow points left toward Dock)
- Right Dock: `.maxX` (arrow points right toward Dock)

**Additional Features:**
- `NSVisualEffectView` with `.popover` material for native vibrancy
- Keyboard navigation via `KeyboardCaptureView` (custom NSView)
- Dismisses on click outside or Escape key
- Safeguard fallback if `visibleFrame` unavailable

### Icon Generation (Tahoe Native Design)

`IconGenerator.swift` creates macOS `.icns` files following Tahoe design guidelines:

**Shape & Background:**
- Uses true continuous corners (squircle) via SwiftUI's `RoundedRectangle(.continuous)` path extraction
- Corner radius = 22.5% of icon width (matches native macOS icons)
- Linear gradient from `TintColor.colorTop` to `TintColor.colorBottom`

**Beveled Glass Effect:**
- White inner stroke at 50% opacity
- Line width scales proportionally (0.5pt at 160pt, minimum 0.5pt for visibility)

**Icon Content:**
- SF Symbols: Rendered in white with `.medium` weight, no text shadow
- Emojis: Rendered using system font at calculated size
- Size controlled by `iconScale` (10-20 range, default 14)

**What's NOT Baked In (Dock Adds Dynamically):**
- Drop shadow
- Hover/press effects
- Reflection

**Output:**
- Creates iconset with all required sizes (16, 32, 128, 256, 512 @ 1x and 2x)
- Uses `iconutil` to convert iconset to `.icns`

**Preview Consistency:**
- `DockTileIconPreview` uses identical rendering (same shape, gradient, stroke)
- No shadows in preview = what you see is what the icon file contains

### Dock Plist Watcher

`DockPlistWatcher.swift` monitors `com.apple.dock.plist`:
- Detects when user manually removes tile from Dock
- Syncs `isVisibleInDock` state in configuration
- Uses `DispatchSource.makeFileSystemObjectSource` for efficient watching

### Icon Style Manager (macOS Tahoe)

`IconStyleManager.swift` manages the macOS "Icon and widget style" setting (separate from Light/Dark appearance):

**Icon Styles:**
- `.defaultStyle` - Standard icons (key not set in UserDefaults)
- `.dark` - Dark tinted icons (`RegularDark` value)
- `.clear` - Clear/transparent style
- `.tinted` - Accent color tinted

**Architecture:**
- Single `IconStyleManager.shared` instance as source of truth
- Uses `@ObservedObject` pattern for SwiftUI views
- 2-second polling timer (reliable fallback since notifications are unreliable)
- Posts `.iconStyleDidChange` notification for non-SwiftUI components

**Usage in Views:**
```swift
@ObservedObject private var iconStyleManager = IconStyleManager.shared

var body: some View {
    // Reference currentStyle to trigger re-renders
    let _ = iconStyleManager.currentStyle
    // ... view content
}
```

**App Icon Loading Strategy:**
- Apps WITH `Assets.car` (Claude, ChatGPT, system apps): Use `NSWorkspace.shared.icon(forFile:)` which respects icon style
- Apps WITHOUT `Assets.car` (Ollama, etc.): Load `.icns` directly from bundle to avoid unwanted dark tinting

**Detection:**
```swift
func appHasAssetCatalog(atPath path: String) -> Bool {
    let assetCatalogURL = URL(fileURLWithPath: path)
        .appendingPathComponent("Contents/Resources/Assets.car")
    return FileManager.default.fileExists(atPath: assetCatalogURL.path)
}
```

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
| Form group background | `.quaternarySystemFill` | - |
| Form row separators | `.quinaryLabel` | - |
| Studio canvas/preview area | - | `.underWindowBackground` |
| Separator lines | `.separatorColor` | - |
| Secondary labels | `.secondaryLabelColor` | - |
| Table even rows | `.alternatingContentBackgroundColors[1]` | - |
| Subtle button background | `Color.black.opacity(0.05)` | - |

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

### Main App Icon via Icon Composer (2026-02)
- **Tool**: Apple's Icon Composer for macOS Tahoe icons with appearance variants
- **Location**: `DockTile/Resources/AppIcon.icon/` folder containing:
  - `icon.json` - Icon configuration with layers and appearance mapping
  - `icon-light.png` - Light mode variant (1024×1024)
  - `icon-dark.png` - Dark mode variant (1024×1024)
  - `icon-tinted.png` - Tinted mode variant (1024×1024)
- **Xcode Integration**:
  - Added `AppIcon.icon` to project.pbxproj as `folder.icon` type
  - Added `CFBundleIconName = "AppIcon"` to Info.plist
  - Xcode compiles to `Assets.car` + `AppIcon.icns` during build
- **Two Separate Icon Systems**:
  - **Main app**: Icon Composer → Assets.car (appearance-aware, compiled by Xcode)
  - **Helper tiles**: IconGenerator.swift → custom .icns files (generated at runtime)
- **Cache Clearing** (if icon doesn't update):
  ```bash
  killall iconservicesd && killall Dock
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R /path/to/DockTile.app
  ```

### Helper Bundle Assets.car Removal Fix (2026-02)
- **Problem**: Newly created helper tiles showed the main DockTile app icon instead of their custom configured icon
- **Root Cause**: When helper bundles are created by copying the main app, `Assets.car` is included. macOS prioritizes asset catalogs over `CFBundleIconFile`, so the main app's icon was displayed.
- **Fix**: In `HelperBundleManager.swift`, after copying the bundle, remove `Assets.car`:
  ```swift
  // Remove Assets.car to prevent macOS from using the main app's icons
  let assetsCarPath = helperPath.appendingPathComponent("Contents/Resources/Assets.car")
  try? FileManager.default.removeItem(at: assetsCarPath)
  ```
- **macOS Icon Priority** (highest to lowest):
  1. `Assets.car` (asset catalog)
  2. `CFBundleIconFile` pointing to `.icns`
- **Result**: Helper tiles now correctly display their custom generated icons

### Custom Color Gradient Fill Fix (2026-02)
- **Problem**: Custom colors from the color picker (not presets) showed a visible gap/stroke around icon edges
- **Root Cause**: Custom color top gradient used `opacity(0.8)` / `withAlphaComponent(0.8)`, creating semi-transparent colors. CoreGraphics gradient rendering doesn't fully fill the clipped path with semi-transparent colors.
- **Why Presets Worked**: Preset colors have two distinct fully-opaque hex values (`colorTop` and `colorBottom`)
- **Fix**: Created `lighterShade(by:)` method that increases brightness instead of using opacity:
  ```swift
  // In ColorExtensions.swift and AppearanceManager.swift
  func lighterShade(by amount: CGFloat) -> Color/NSColor {
      // Convert to HSB, increase brightness, decrease saturation slightly
      let newBrightness = min(1.0, brightness + amount)
      let newSaturation = max(0.0, saturation - (amount * 0.3))
      // Return new fully-opaque color
  }
  ```
- **Files Modified**:
  - `ColorExtensions.swift` - Added `lighterShade(by:)` to SwiftUI Color
  - `AppearanceManager.swift` - Added `lighterShade(by:)` to NSColor, updated `nsColorTop`
  - `ConfigurationModels.swift` - Updated `colorTop` computed property for custom colors

### Dock Position Preservation on Update (2026-02)
- **Problem**: When updating an existing tile already in the Dock, it would move to the end instead of staying in its original position
- **Root Cause**: `addToDock()` always appended to the end of the `persistent-apps` array
- **Fix**: Save the original Dock index before removal, then insert at that index when re-adding:
  ```swift
  // In HelperBundleManager.swift

  // New method to find current Dock position
  func findDockIndex(bundleId: String) -> Int? {
      // Iterate persistent-apps, find matching bundle-identifier, return index
  }

  // Updated addToDock with optional index parameter
  func addToDock(at appPath: URL, atIndex: Int? = nil) {
      // If index provided and valid, insert at that position
      // Otherwise append to end
  }

  // In installHelper:
  let originalDockIndex = wasInDock ? findDockIndex(bundleId: config.bundleIdentifier) : nil
  // ... remove, regenerate, re-sign ...
  addToDock(at: helperPath, atIndex: originalDockIndex)
  ```
- **Result**: Tiles maintain their Dock position when updated

### CFPreferences API for Dock Integration (2026-02)
- **Problem**: Toggling "Show Tile" OFF then back ON didn't reliably add the tile back to Dock (required 2-3 attempts)
- **Root Cause**: Direct plist file writing bypassed the `cfprefsd` cache, causing sync issues
- **Research**: Investigated industry-standard tools (dockutil) and found they use CFPreferences API
- **Solution**: Refactored all Dock plist operations in `HelperBundleManager.swift` to use CFPreferences API

**Key API Calls:**
```swift
// Read from Dock preferences (reads from cfprefsd cache)
CFPreferencesCopyAppValue("persistent-apps" as CFString, "com.apple.dock" as CFString)

// Write to Dock preferences (writes directly to cfprefsd)
CFPreferencesSetAppValue("persistent-apps" as CFString, updatedApps as CFArray, "com.apple.dock" as CFString)

// Sync changes to disk
CFPreferencesAppSynchronize("com.apple.dock" as CFString)
```

**Methods Updated:**
| Method | Purpose |
|--------|---------|
| `addToDock(at:)` | Adds tiles to Dock |
| `removeFromDock(at:)` | Removes tiles by path |
| `removeFromDock(bundleId:)` | Removes tiles by bundle ID |
| `removeFromDockPlist(bundleId:)` | Removes tiles during uninstall |
| `isInDock(at:)` | Checks if app is in Dock by path |
| `findInDock(bundleId:)` | Finds Dock entry by bundle ID |

**Benefits:**
- ✅ No privacy prompts (unlike `defaults import` shell command)
- ✅ Reliable sync with cfprefsd cache
- ✅ Industry-standard approach (same as dockutil)
- ✅ No shell commands required

**Removed:**
- `syncPreferences()` method - no longer needed since CFPreferences handles sync internally

**Race Condition Prevention:**
- Added `installingBundleIds` Set to prevent double-installation
- Added `removingBundleIds` Set to prevent double-removal

### macOS Tahoe Icon Style Support (2026-02)
- **Discovery**: macOS Tahoe has TWO independent appearance settings:
  - **Appearance** (Light/Dark/Auto) - controls window chrome
  - **Icon and widget style** (Default/Dark/Clear/Tinted) - controls icon rendering
- **New File**: `IconStyleManager.swift` - Observes icon style changes via `AppleIconAppearanceTheme` UserDefaults key
- **IconStyle enum**: `.defaultStyle`, `.dark`, `.clear`, `.tinted`
- **Known UserDefaults values** (`AppleIconAppearanceTheme` key):
  - `nil` (not set) = Default (colorful)
  - `"RegularDark"` = Dark
  - `"ClearAutomatic"` = Clear
  - `"TintedAutomatic"` = Tinted
- **Architecture**: Single `IconStyleManager.shared` as source of truth with `@ObservedObject` pattern
- **Polling**: 2-second poll timer (reliable fallback since distributed notifications are unreliable)
- **Updates**:
  - `DockTileIconPreview.swift` - Uses `IconStyle` for real-time preview updates
  - `IconGenerator.swift` - Generates icons using `IconStyle` parameter
  - `HelperBundleManager.swift` - Generates `AppIcon-default.icns` and `AppIcon-dark.icns`
  - `HelperAppDelegate.swift` - Observes `AppleIconAppearanceTheme` and switches dock icons
  - `NativePopoverViews.swift` - Popover icons respond to icon style changes
  - `DockTileDetailView.swift` - Selected Items table (`AppIconView`) responds to icon style
  - `ItemRowView.swift` - App rows respond to icon style changes
- **App Icon Loading**: Smart detection based on Asset Catalog presence:
  - Apps WITH `Assets.car`: Use `NSWorkspace.shared.icon(forFile:)` for style-aware icons
  - Apps WITHOUT `Assets.car` (e.g., Ollama): Load `.icns` directly to avoid unwanted dark tinting
- **View Re-render Pattern**: Reference `iconStyleManager.currentStyle` in view body with `let _ =` to trigger re-renders
- **Documentation**: See `ICON_STYLE_ARCHITECTURE.md` for full details
- **Implementation Status** (All 4 styles fully supported):
  | Style | Icon Generated | Switching | Visual Design |
  |-------|---------------|-----------|---------------|
  | Default | ✅ `AppIcon-default.icns` | ✅ Works | Colorful gradient background, white symbol |
  | Dark | ✅ `AppIcon-dark.icns` | ✅ Works | Dark gray (#2C2C2E → #1C1C1E), tint-colored symbol |
  | Clear | ✅ `AppIcon-clear.icns` | ✅ Works | Light gray (#F0F0F2 → #E0E0E4), dark gray symbol (#6E6E73) |
  | Tinted | ✅ `AppIcon-tinted.icns` | ✅ Works | Medium gray (#8E8E93 → #636366), white symbol |
- **Apple HIG Compliance**: Clear and Tinted use **grayscale only** (no user color). macOS applies system tinting on top, ensuring icons blend with other Dock icons.
- **Icon Generation**: All 4 variants generated upfront during `installHelper()` (~200-400ms total)
- **Icon Switching**: Instant file copy when system icon style changes (no regeneration needed)
- **Backward Compatibility**: `switchIcon()` has fallback chain for old bundles missing new icon files

### Auto-Save Draft Mode & Add Button Control (2026-01)
- **Auto-Save**: All edits in DockTileDetailView and CustomiseTileView now save immediately as drafts
  - Changes persist to `com.docktile.configs.json` on every edit
  - "Add to Dock" button only handles installing/uninstalling the helper bundle to the Dock
  - Tiles remain as drafts until user explicitly adds them to Dock
- **Add Button Disable**: Apple Notes-style prevention of empty tile spam
  - `+` button in sidebar is disabled until user makes any change to the new tile
  - `selectedConfigHasBeenEdited` flag tracks if the current tile has been modified
  - `isCreatingNewConfig` flag prevents race condition in `selectedConfigId` didSet
  - `hasAppearedOnce` flag in detail view prevents `.onChange` from triggering on initial load
- **Button Rename**: "Done" button renamed to "Add to Dock" for clarity
- **Default Values**: New tiles use gray color and "New Tile" as default name
- **Sidebar Cleanup**: Removed app count subtitle and status dots for cleaner appearance

### Popover Positioning Fix (2026-01)
- **Problem**: Popover would "float" mid-air if user clicked near the top of the Dock icon
- **Root cause**: Anchor window position used mouse Y coordinate, which varied based on click location
- **Fix**: Implemented "hard edge" anchoring using `visibleFrame` boundary:
  - Anchor strictly to `visibleFrame.minY/minX/maxX` depending on Dock position
  - Mouse coordinate only used for the axis parallel to the Dock
  - Removed `getDockThickness()` in favor of direct `visibleFrame` usage
- **Result**: Popover now always appears flush against the Dock edge, matching native Applications folder behavior

### Default Visibility Change (2026-01)
- **Change**: New tiles now have `isVisibleInDock = true` by default
- **Reason**: Better UX - clicking "Done" immediately installs the tile to Dock
- **Location**: `ConfigurationDefaults.isVisibleInDock` in `ConfigurationSchema.swift`

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

### Form Group Styling System (2026-01)
- **Design**: Unified form group styling matching Figma specs across all views
- **Background**: `NSColor.quaternarySystemFill` via `NSViewRepresentable` (Figma's `FillsOpaqueQuaternary`)
- **Separators**: `NSColor.quinaryLabel` for 1pt dividers between rows
- **Layout**: `cornerRadius(12)`, `.padding(.horizontal, 10)`, row height 40pt
- **Components**:
  - `FormGroupBackground` in DockTileDetailView
  - `FormGroupBackgroundView` in CustomiseTileView
  - `formRow()` helper for consistent row layout with separators

### SubtleButton Component (2026-01)
- **Purpose**: Reusable secondary action button with subtle background
- **Styling**: 12pt font, 24pt height, 5% black opacity background, 6pt corner radius
- **Usage**:
  ```swift
  SubtleButton(title: "Customise", width: 118, action: onCustomise)
  SubtleButton(title: "Remove", textColor: .red, action: { ... })
  ```
- **Location**: `DockTileDetailView.swift` (private struct)

### Detail View Hero Section Redesign (2026-01)
- **Icon Container**: 118×118pt with cornerRadius(24), gradient fill, beveled glass stroke
- **Form Group**: Custom rows with 40pt height, quinaryLabel separators
- **Buttons**: Done uses `.bordered` style (Liquid Glass secondary), Customise/Remove use SubtleButton

### Delete Section Redesign (2026-01)
- **Text**: "Remove from Dock" with subtitle explaining action
- **Layout**: Form group style with 42pt height
- **Button**: SubtleButton with red text color

### Table View Styling (2026-01)
- **Background**: `quaternarySystemFill` for odd rows, `alternatingContentBackgroundColors[1]` for even rows
- **Layout**: Custom `NativeAppsTableView` using VStack + ForEach for natural content growth
- **Header/Footer**: Uses even row color for visual consistency

### Icon Scale Feature (2026-01)
- **Added**: `iconScale` field to `DockTileConfiguration` (v4 schema)
- **Range**: 10-20, default 14
- **Formula**: Base ratio = 0.30 + ((iconScale - 10) * 0.035), emoji gets +5% offset
- **UI**: Stepper control in CustomiseTileView inspector card
- **Adaptive Guide Overlay**: Guide circles adjust color based on background luminance (darker for light backgrounds, lighter for dark)

### Search in Symbol/Emoji Pickers (2026-01)
- **Added**: Search field above the picker grids in CustomiseTileView
- **Symbol Search**: Filters by symbol name (e.g., "star", "folder")
- **Emoji Search**: Filters by emoji keywords from lookup table
- **Shared State**: Single `searchText` binding passed to both pickers

### SwiftUI View Identity Fix (2026-01)
- **Problem**: Editing one tile config was corrupting all tiles (stale `@State` in reused views)
- **Root Cause**: SwiftUI view reuse - when switching tiles, `@State editedConfig` wasn't reinitializing
- **Fix**: Added `.id(selectedConfig.id)` to both `DockTileDetailView` and `CustomiseTileView` in parent
- **Result**: Views are now recreated when switching tiles, ensuring fresh state

### Helper Bundle Stale Process Fix (2026-01)
- **Problem**: After clicking "Add to Dock", helper showed old configuration data
- **Root Cause**: Old helper process was still running (macOS process caching + soft terminate failure)
- **Fixes**:
  - Changed `app.terminate()` to `app.forceTerminate()` for immediate process kill
  - Remove from Dock FIRST before quitting/regenerating (prevents Dock auto-relaunch race)
  - Increased wait timeout and added verification logging
  - Post-Dock restart check to ensure fresh process is running

### Icon Preview Tap to Customise (2026-01)
- **Added**: Tap gesture on 118×118 icon preview in DockTileDetailView
- **Action**: Triggers `onCustomise()` to navigate to CustomiseTileView
- **UX**: Same behavior as clicking the "Customise" button below

### Pointer Cursor on Interactive Elements (2026-01)
- **Added**: Pointing hand cursor on hover for:
  - Icon preview in DockTileDetailView (118×118)
  - SubtleButton components ("Customise", "Remove")
- **Implementation**: `.onHover` with `NSCursor.pointingHand.push()/pop()`

### Native Icon Design (Tahoe Guidelines) (2026-01)
- **Goal**: Preview shows exactly what the icon file looks like; Dock adds shadows dynamically
- **IconGenerator Updates**:
  - Uses true continuous corners (squircle) via SwiftUI's `RoundedRectangle(.continuous)` path extraction
  - Added beveled glass effect (white 50% opacity inner stroke, 0.5pt scaled proportionally)
  - Removed: Drop shadow (Dock adds this), text shadow on SF Symbols
- **DockTileIconPreview Updates**:
  - Removed `.shadow()` modifier - preview now matches icon file exactly
  - Removed text shadow from SF Symbols
  - Kept: Gradient fill, beveled inner stroke, squircle shape
- **DockTileDetailView Updates**:
  - Hero section icon preview no longer has drop shadow
  - Icon content (SF Symbols) no longer has text shadow
- **Design Rationale**:
  - Native macOS icons don't have baked-in shadows - the Dock adds these dynamically
  - Baking shadows would cause "doubled" shadow effect when icon is in Dock
  - Inner stroke (beveled glass) is a Tahoe design element that should be baked in

### CFBundleIconFile Fix (2026-01)
- **Problem**: Custom icons not showing in Dock - tiles displayed default macOS app icon
- **Root Cause**: `CFBundleIconFile` key was missing from helper bundle's Info.plist
- **Fix**: Added `plist["CFBundleIconFile"] = "AppIcon"` in `updateInfoPlist()` in HelperBundleManager.swift
- **Result**: macOS now correctly loads the generated AppIcon.icns from Contents/Resources/

### Dynamic Action Button & Dock Removal Fix (2026-01)
- **Problem 1**: Toggle "Show Tile" OFF + click button → tile still in Dock
- **Problem 2**: Manual remove from Dock → Toggle ON → tile not added back
- **Root Cause**:
  - `uninstallHelper` only called if `helperExists()` returned true
  - Dock plist removal depended on bundle file existing
- **Fixes**:
  - Added `isCurrentlyInDock` state to track actual Dock presence
  - Dynamic button text based on state:
    - "Add to Dock" - toggle ON, not in Dock
    - "Update" - toggle ON, already in Dock
    - "Remove from Dock" - toggle OFF, in Dock
    - "Done" - toggle OFF, not in Dock
  - New `removeFromDock(for:)` method that removes from Dock plist without requiring bundle
  - `updateDockState()` called on appear and toggle change
- **Location**: `DockTileDetailView.swift`, `HelperBundleManager.swift`

### Icon Properties Sync Fix (2026-01)
- **Problem**: Icon scale changes in CustomiseTileView not reflected when adding to Dock
- **Root Cause**: `DockTileDetailView.editedConfig` wasn't syncing icon-related properties from `configManager`
- **Fix**: Extended `.onChange(of: configManager.configurations)` handler to sync:
  - `iconType`, `iconValue`, `iconScale`, `tintColor`, `symbolEmoji`
- **Result**: Changes made in CustomiseTileView now correctly apply when clicking "Add to Dock"

### Icon Cache Refresh (2026-01)
- **Problem**: macOS Dock showing stale cached icons after regeneration
- **Fix**: Added `touchBundle(at:)` method in `HelperBundleManager`:
  - Touches bundle to update modification date
  - Re-registers with Launch Services via `lsregister -f -R`
- **Called**: After code signing, before adding to Dock
- **Manual Cache Clear** (if needed):
  ```bash
  rm -rf /var/folders/*/*/com.apple.iconservices*
  killall Dock
  killall Finder
  ```

### Sidebar Icon Preview Unified (2026-01)
- **Change**: Replaced custom `MiniIconPreview` with `DockTileIconPreview.fromConfig(config, size: 24)`
- **Benefit**: Sidebar now uses the same icon rendering as all other previews
- **Behavior**: Icon scales proportionally based on `iconScale` setting within 24×24pt container
- **Location**: `DockTileSidebarView.swift`

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
Toggle "Show Tile" off and back on, then click the action button

### Clear icon cache (if Dock shows stale icons)
```bash
# Clear macOS icon services cache
rm -rf /var/folders/*/*/com.apple.iconservices*

# Restart Dock and Finder
killall Dock
killall Finder
```

### Verify generated icon
```bash
# Extract iconset from helper bundle
iconutil -c iconset "$HOME/Library/Application Support/DockTile/[TileName].app/Contents/Resources/AppIcon.icns" -o /tmp/icon_check.iconset

# Open to inspect
open /tmp/icon_check.iconset/icon_512x512.png
```

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
│       │   ├── Toolbar
│       │   │   └── Dynamic action button (.bordered style - text varies: Add/Update/Remove/Done)
│       │   ├── heroSection (HStack)
│       │   │   ├── Left column (VStack)
│       │   │   │   ├── Icon container (118×118pt, cornerRadius 24, tappable → customise)
│       │   │   │   └── SubtleButton "Customise" (width: 118, pointer cursor)
│       │   │   └── Right column: Form Group (FormGroupBackground)
│       │   │       ├── formRow: Tile Name
│       │   │       ├── formRow: Show Tile (Toggle)
│       │   │       ├── formRow: Layout (Picker)
│       │   │       └── formRow: Show in App Switcher (Toggle)
│       │   ├── appsTableSection
│       │   │   └── NativeAppsTableView (VStack + ForEach)
│       │   │       ├── Header row (evenRowColor)
│       │   │       ├── Item rows (alternating odd/even colors)
│       │   │       └── Footer toolbar (+/- buttons)
│       │   └── deleteSection (FormGroupBackground)
│       │       ├── Text: "Remove from Dock" + subtitle
│       │       └── SubtleButton "Remove" (textColor: .red, pointer cursor)
│       │
│       └── CustomiseTileView (Screen 4 - drill-down)
│           ├── studioCanvas (QuaternaryFillView background)
│           │   ├── DockTileIconPreview (160×160pt)
│           │   ├── IconGridOverlay (adaptive color based on luminance)
│           │   └── Tile name
│           └── inspectorCard (FormGroupBackgroundView)
│               ├── colourSection (preset swatches + custom picker)
│               ├── Separator (quinaryLabel)
│               ├── tileIconSizeSection (Stepper 10-20)
│               ├── Separator (quinaryLabel)
│               └── tileIconSection
│                   ├── segmentedPicker (Symbol/Emoji tabs)
│                   ├── SearchField (filters symbols/emojis)
│                   └── ScrollView (height: 320)
│                       ├── SymbolPickerGrid (when .symbol)
│                       └── EmojiPickerGrid (when .emoji)
```

## Release Roadmap (v1.0)

### Phase 1: UI Polish

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 1 | **Sidebar Cleanup** | ✅ Done | High | Apple Notes style - clean List with icon + name |
| 2 | **Icon Preview → Dock Icon** | ✅ Done | High | Squircle shape, beveled glass stroke, Tahoe-native design |
| 3 | **Main App Icon** | ✅ Done | High | Icon Composer with light/dark/tinted variants via AppIcon.icon |

### Phase 2: Distribution

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 4 | **Build Pipeline (CI/CD)** | 🔲 Pending | High | No .github/workflows, no Fastlane, no build scripts |
| 5 | **DMG Installer** | 🔲 Pending | High | No DMG scripts exist yet |
| 6 | **Code Signing & Notarization** | 🔲 Pending | High | No entitlements file, no signing scripts |

### Phase 3: User Experience

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 7 | **Onboarding Flow** | 🔲 Pending | Medium | Bartender/Alcove/Klack-style onboarding (no permissions needed - CFPreferences approach) |
| 7b | **Clear/Tinted Mode Hint** | 🔲 Deferred | Low | Show subtitle in CustomiseTileView colour section explaining "Dock applies system tint" when in Clear/Tinted mode. Needs careful layout to not break inspector card. |

### Phase 4: App Store & Marketing

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 8 | **App Store Review** | ✅ Assessed | Medium | Not viable - sandbox restrictions block helper bundle creation |
| 9 | **Alternative Distribution** | 🔲 Pending | Low | Direct download recommended; SetApp as secondary |
| 10 | **ProductHunt Launch** | 🔲 Pending | Low | Marketing page and launch strategy |

---

### Task Details

#### 3. Main App Icon
**Goal**: Create a memorable app icon for DockTile.app itself
- Should convey "dock" + "customization" concept
- Options: Multiple colored tiles, dock with star, stacked tiles
- Use the same design language as tile icons (gradients, rounded corners)
- Generate all required sizes for macOS (16, 32, 128, 256, 512 @ 1x and 2x)

#### 4. Build Pipeline (GitHub Actions)
**Goal**: Automated builds producing signed DMG files
```yaml
# Suggested workflow:
# 1. Trigger: Push to main or tag creation
# 2. Build: xcodebuild archive
# 3. Sign: codesign with Developer ID certificate
# 4. Notarize: xcrun notarytool
# 5. Package: create-dmg or dmgbuild
# 6. Release: Upload to GitHub Releases
```

**Requirements**:
- Apple Developer ID Application certificate (for signing)
- Apple Developer ID Installer certificate (for pkg, if needed)
- App-specific password for notarization
- GitHub secrets for credentials

#### 5. DMG Installer (SF Symbols Style)
**Goal**: Beautiful installer experience
- Background image showing app icon and Applications folder
- Arrow indicating drag-to-install
- Properly sized window (600×400 typical)
- Tools: `create-dmg` (npm) or `dmgbuild` (Python)

Example with create-dmg:
```bash
create-dmg \
  --volname "DockTile" \
  --volicon "DockTile.icns" \
  --background "installer-bg.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "DockTile.app" 150 185 \
  --hide-extension "DockTile.app" \
  --app-drop-link 450 185 \
  "DockTile.dmg" \
  "build/"
```

#### 6. Code Signing & Notarization
**Requirements for distribution outside App Store**:
- Developer ID Application certificate
- Hardened Runtime enabled
- Notarization with Apple

```bash
# Sign
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  DockTile.app

# Notarize
xcrun notarytool submit DockTile.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# Staple
xcrun stapler staple DockTile.dmg
```

#### 7. Onboarding Flow (Optional - No Permissions Required)
**Goal**: Bartender/Alcove/Klack-style onboarding that educates users about the app

**Note**: Since migrating to CFPreferences API (2026-02), **no permissions are required**. The onboarding is now purely educational and optional.

**Design Inspiration**:
- **Bartender 5/6**: Clean cards with illustrations
- **Alcove**: Friendly illustrations explaining features
- **Klack**: Step-by-step wizard showing capabilities

**Onboarding Flow** (1-2 screens):
```
Screen 1: Welcome + How It Works
├── App icon + "Welcome to DockTile"
├── Brief tagline: "Create custom app launchers for your Dock"
├── Illustration/visual showing Dock with custom tiles
├── 2-3 bullet points explaining the concept:
│   • "Group your favorite apps into custom tiles"
│   • "One click to launch multiple apps"
│   • "Customize with colors and icons"
└── "Get Started" button → dismisses onboarding
```

**Technical Implementation**:
- Use SwiftUI with simple state-driven view
- Store onboarding completion in `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")`
- Show on first launch only (check in `AppDelegate` or main view)
- Single screen is sufficient since no permissions needed

**UI Components**:
- `OnboardingView.swift` - Welcome screen with feature highlights

**Assets Needed**:
- Welcome illustration (optional, can use SF Symbols)

#### 8. App Store Review
**Potential Issues**:
1. **Sandbox**: App Store apps must be sandboxed
   - ❌ Writing to `~/Library/Application Support/` may be restricted
   - ❌ Modifying Dock plist requires permissions
   - ❌ Launching other apps may be restricted
2. **Private APIs**: None used currently (good)
3. **Entitlements needed**:
   - `com.apple.security.app-sandbox`
   - `com.apple.security.files.user-selected.read-write`
   - `com.apple.security.automation.apple-events` (for Dock restart)

**Verdict**: App Store distribution is **unlikely** due to:
- Creating and installing helper bundles
- Modifying system Dock preferences
- Apps like this typically distributed via direct download

#### 9. Alternative Distribution Options
| Option | Pros | Cons |
|--------|------|------|
| **Direct Download** | Full control, no fees | Need to handle payments, hosting |
| **SetApp** | Subscription model, good exposure | Revenue share, approval process |
| **Gumroad** | Easy payments, good for indie | 5-10% fees |
| **Paddle** | Professional, handles taxes | Integration work |

#### 10. ProductHunt Launch
**Preparation**:
- Create compelling tagline
- Record demo GIF/video
- Prepare screenshots
- Write description highlighting use cases
- Schedule for Tuesday-Thursday (best days)

---

### Implementation Order (Remaining)

```
Phase 1: UI Polish (remaining)
└── Task 3: Main app icon

Phase 2: Distribution Setup
├── Task 4: GitHub Actions pipeline
├── Task 5: DMG installer
└── Task 6: Code signing (requires Apple Developer account)

Phase 3: User Experience
└── Task 7: Onboarding Flow (optional)
    ├── No permissions required (CFPreferences API handles Dock integration)
    ├── Purely educational - explains app concept
    └── Design: Bartender/Alcove/Klack style

Phase 4: Marketing & Launch
└── Task 9-10: Distribution & marketing
```
