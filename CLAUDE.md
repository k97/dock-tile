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
│   ├── SymbolPickerGrid.swift      # SF Symbol picker with categories
│   ├── EmojiPickerGrid.swift       # Emoji picker with categories
│   ├── IconGridOverlay.swift       # Apple icon guide grid overlay
│   └── ItemRowView.swift           # Row view for app items
├── Utilities/
│   └── IconGenerator.swift         # Generates .icns files from tint color + emoji
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
| isVisibleInDock | Bool | true | Show helper in Dock (enabled by default) |
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
│       │   ├── Toolbar
│       │   │   └── Done button (.bordered style - Liquid Glass secondary)
│       │   ├── heroSection (HStack)
│       │   │   ├── Left column (VStack)
│       │   │   │   ├── Icon container (118×118pt, cornerRadius 24)
│       │   │   │   └── SubtleButton "Customise" (width: 118)
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
│       │       └── SubtleButton "Remove" (textColor: .red)
│       │
│       └── CustomiseTileView (Screen 4 - drill-down)
│           ├── studioCanvas (QuaternaryFillView background)
│           │   ├── DockTileIconPreview (160×160pt)
│           │   ├── IconGridOverlay
│           │   └── Tile name
│           └── inspectorCard (FormGroupBackgroundView)
│               ├── colourSection (preset swatches + custom picker)
│               ├── Separator (quinaryLabel)
│               └── tileIconSection
│                   ├── segmentedPicker (Symbol/Emoji tabs)
│                   └── ScrollView (height: 320)
│                       ├── SymbolPickerGrid (when .symbol)
│                       └── EmojiPickerGrid (when .emoji)
```

## Reference Documents

- **Full Specification**: `DockTile_Project_Spec.md` (comprehensive design document)
- This file is authoritative for all architectural and design decisions

---

## Release Roadmap (v1.0)

### Phase 1: UI Polish

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 1 | **Sidebar Cleanup** | ✅ Done | High | Already Apple Notes style - clean List with icon + name, status dot |
| 2 | **Icon Preview → Dock Icon** | ✅ Done | High | IconGenerator and DockTileIconPreview use matching rendering (95% consistent) |
| 3 | **Main App Icon** | ⚠️ Partial | High | Build settings configured but Assets.xcassets missing - uses default icon |

### Phase 2: Distribution

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 4 | **Build Pipeline (CI/CD)** | 🔲 Pending | High | No .github/workflows, no Fastlane, no build scripts |
| 5 | **DMG Installer** | 🔲 Pending | High | No DMG scripts exist yet |
| 6 | **Code Signing & Notarization** | 🔲 Pending | High | No entitlements file, no signing scripts |

### Phase 3: User Experience

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 7 | **Onboarding Screen** | 🔲 Pending | Medium | Welcome flow explaining the app (optional but nice) |

### Phase 4: App Store & Marketing

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 8 | **App Store Review** | ✅ Assessed | Medium | Not viable - sandbox restrictions block helper bundle creation |
| 9 | **Alternative Distribution** | 🔲 Pending | Low | Direct download recommended; SetApp as secondary |
| 10 | **ProductHunt Launch** | 🔲 Pending | Low | Marketing page and launch strategy |

---

### Task Details

#### 1. Sidebar Cleanup (Apple Notes Style)
**Goal**: Create a lightweight, clean sidebar like Apple Notes
- Remove green "active" dot indicator
- Simplify row layout (icon + name only, minimal chrome)
- Use native `.sidebar` list style
- Consider removing app count subtitle
- Lighter visual weight overall

#### 2. Icon Preview → Dock Icon
**Goal**: Ensure the icon you see in the customization view is exactly what appears in the Dock
- `IconGenerator.swift` already generates `.icns` files
- Verify the rendering matches `DockTileIconPreview` exactly
- Both should use same gradient, corner radius, and symbol rendering

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

#### 7. Onboarding Screen (Optional)
**Goal**: Welcome new users and explain the concept
- Page 1: "Create custom Dock tiles"
- Page 2: "Add your favorite apps"
- Page 3: "Click to launch"
- Use SwiftUI `TabView` with `.tabViewStyle(.page)`

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

### Implementation Order (Recommended)

```
Week 1: UI Polish
├── Task 1: Sidebar cleanup
├── Task 2: Icon rendering consistency
└── Task 3: Main app icon

Week 2: Distribution Setup
├── Task 4: GitHub Actions pipeline
├── Task 5: DMG installer
└── Task 6: Code signing (requires Apple Developer account)

Week 3: Polish & Launch
├── Task 7: Onboarding (if time permits)
├── Task 8: Final App Store assessment
└── Task 9-10: Distribution & marketing decisions
```
