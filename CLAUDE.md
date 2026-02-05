# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Expectations

**After making code changes, always run tests before committing:**
```bash
xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO
```

- Tests must pass before committing changes
- If tests fail, fix the issues before proceeding
- This applies to all code modifications (bug fixes, features, refactoring)

## Project Overview

**Dock Tile** is a multi-instance macOS utility for macOS 15.0+ (Tahoe) that serves as a minimalist "app container" in the Dock. It enables power users to pin multiple distinct dock tiles (via Helper Bundles), each with independent app lists and custom icons/tints.

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

## Dev vs Release Build Separation

**IMPORTANT**: The project uses separate configurations for Development and Release builds to prevent dev/test data from mixing with production user data.

### Build Configurations

| Configuration | Bundle ID Suffix | Config File | Support Folder | Purpose |
|---------------|------------------|-------------|----------------|---------|
| **Debug** | `.dev` | `com.docktile.dev.configs.json` | `DockTile-Dev/` | Local development |
| **Release** | (none) | `com.docktile.configs.json` | `DockTile/` | Production release |

### How It Works

The separation is controlled via Xcode build settings that set Info.plist variables:

| Info.plist Key | Debug Value | Release Value |
|----------------|-------------|---------------|
| `DTEnvironment` | `dev` | `release` |
| `DTHelperPrefix` | `DockTile-Dev` | `DockTile` |
| `DTPrefsFilename` | `com.docktile.dev.configs.json` | `com.docktile.configs.json` |
| `DTSupportFolder` | `DockTile-Dev` | `DockTile` |

### File Locations by Environment

| Item | Debug | Release |
|------|-------|---------|
| Config file | `~/Library/Preferences/com.docktile.dev.configs.json` | `~/Library/Preferences/com.docktile.configs.json` |
| Helper bundles | `~/Library/Application Support/DockTile-Dev/` | `~/Library/Application Support/DockTile/` |
| Helper bundle IDs | `com.docktile.dev.helper.*` | `com.docktile.helper.*` |

### Why This Matters

1. **Development tiles don't appear in production** - Dev helper bundles are completely separate
2. **Safe testing** - You can test destructive operations without affecting real user tiles
3. **Clean releases** - Release builds never see dev configuration data
4. **Parallel usage** - You can run dev and release versions simultaneously

### When Working on Code

- **Always use Debug configuration** for development (`Cmd+R` in Xcode)
- **Release configuration** is only for final testing and CI/CD builds
- If you see tiles/configs from the wrong environment, check which build configuration you're running

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
# Build Debug
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build

# Build Release
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Release build

# Clean build
xcodebuild -project DockTile.xcodeproj -scheme DockTile clean

# Build location
~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app
```

## Testing

### Running Tests Locally

**Quick Start (Xcode):**
1. Open `DockTile.xcodeproj` in Xcode
2. Press **Cmd+U** to run all tests

**Quick Start (Terminal):**
```bash
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -only-testing:DockTileTests
```

### Test Framework

| Purpose | Framework | Notes |
|---------|-----------|-------|
| Unit Tests | **Swift Testing** | Modern `@Test` macro, `#expect` assertions, parallel by default |
| UI Tests | **XCUITest** | Accessibility-based element identification |
| Snapshot Tests | **swift-snapshot-testing** | Visual regression testing (optional dependency) |

### Test Directory Structure

```
DockTileTests/
├── Unit/
│   ├── Constants/
│   │   └── AppStringsTests.swift           # Localization tests (US/UK/AU variants)
│   ├── Models/
│   │   ├── ConfigurationModelsTests.swift
│   │   └── TintColorTests.swift
│   └── Utilities/
│       └── IconGeneratorTests.swift
├── Integration/
│   └── DockRestartConsentTests.swift       # Consent dialog behavior tests
└── Mocks/
    └── (future mock objects)

DockTileUITests/
└── (future UI tests)
```

### Test Commands

```bash
# Run all unit tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -only-testing:DockTileTests

# Run specific test class
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -only-testing:DockTileTests/ConfigurationModelsTests

# Run with coverage
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -enableCodeCoverage YES

# Run UI tests (locally only)
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -only-testing:DockTileUITests

# Generate coverage report
xcrun xccov view --report DerivedData/*/Logs/Test/*.xcresult
```

### Coverage Targets

| Component | Target | Notes |
|-----------|--------|-------|
| Managers | 85-90% | Core business logic |
| Models | 80-90% | Data validation, encoding/decoding |
| Utilities | 90%+ | Pure functions |
| UI Views | 50-60% | Snapshot tests + selective UI tests |
| **Overall** | **75-80%** | Practical target for macOS app |

### Test Setup (Xcode)

Test targets need to be added in Xcode. Run the setup script for instructions:

```bash
./Scripts/setup-tests.sh
```

The script provides step-by-step instructions for:
1. Adding `DockTileTests` unit test target
2. Adding `DockTileUITests` UI test target
3. Moving test files into targets
4. Adding `swift-snapshot-testing` dependency (optional)

### CI Integration

Tests run automatically on every push and PR via GitHub Actions (`.github/workflows/ci.yml`):
- Unit tests run in CI (fast, no system access needed)
- UI tests and integration tests run locally only (require real Dock interaction)

### Release Build Pipeline

The project includes automated scripts for building distributable releases:

```bash
# Full release build (unsigned)
./Scripts/build-release.sh

# Full release build with code signing
./Scripts/build-release.sh --sign

# Full release build with signing + notarization
./Scripts/build-release.sh --sign --notarize

# Create DMG from existing app
./Scripts/create-dmg.sh --app-path /path/to/DockTile.app

# Notarize an existing DMG
./Scripts/notarize.sh --dmg-path ./build/DockTile-1.0.dmg
```

### Build Scripts

| Script | Purpose |
|--------|---------|
| `Scripts/build-release.sh` | Orchestrates full release: build → sign → DMG → notarize |
| `Scripts/create-dmg.sh` | Creates DMG installer from app bundle |
| `Scripts/notarize.sh` | Submits DMG to Apple for notarization |

### CI/CD (GitHub Actions)

The project uses GitHub Actions for continuous integration:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push to main/develop, PRs | Build verification |
| `release.yml` | Tag push (v*) | Build, sign, notarize, release |

**Required GitHub Secrets for Release:**

| Secret | Description |
|--------|-------------|
| `DEVELOPER_ID_APPLICATION_CERTIFICATE` | Base64-encoded .p12 certificate |
| `DEVELOPER_ID_APPLICATION_PASSWORD` | Certificate password |
| `KEYCHAIN_PASSWORD` | Temporary keychain password |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_DEVELOPER_NAME` | Developer name for signing identity |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com |

### Code Signing & Entitlements

**Entitlements File:** `DockTile/DockTile.entitlements`

The app requires specific entitlements for its helper bundle architecture:

| Entitlement | Reason |
|-------------|--------|
| `cs.allow-unsigned-executable-memory` | For ad-hoc signed helper bundles |
| `cs.disable-library-validation` | To load helper bundles |
| `automation.apple-events` | To restart Dock via osascript |

**Manual Code Signing:**
```bash
# Sign with Developer ID
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --entitlements DockTile/DockTile.entitlements \
  /path/to/DockTile.app

# Verify signature
codesign --verify --deep --strict /path/to/DockTile.app
```

### Creating a Release

1. **Update version** in Xcode (Marketing Version + Build Number)
2. **Commit changes** and push to main
3. **Create and push tag:**
   ```bash
   git tag -a v1.0.0 -m "Release 1.0.0"
   git push origin v1.0.0
   ```
4. GitHub Actions will automatically build, sign, notarize, and create a release

**Manual Release:**
```bash
./Scripts/build-release.sh --sign --notarize
# Output: ./build/DockTile-1.0.dmg (signed and notarized)
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

### Current Configuration Fields (v5)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| id | UUID | Generated | Unique identifier |
| name | String | "New Tile" | Display name |
| tintColor | TintColor | .gray | Icon background gradient color (preset or custom hex) |
| symbolEmoji | String | "⭐" | Legacy field for icon (deprecated) |
| iconType | IconType | .sfSymbol | Type of icon: .sfSymbol or .emoji |
| iconValue | String | "star.fill" | SF Symbol name or emoji character |
| iconScale | Int | 14 | (v4) Icon size scale (10-20 range) |
| layoutMode | LayoutMode | .grid | Stack (grid) or List |
| appItems | [AppItem] | [] | Apps in the tile |
| isVisibleInDock | Bool | true | Show helper in Dock (enabled by default) |
| showInAppSwitcher | Bool | false | (v2) Show in Cmd+Tab |
| bundleIdentifier | String | Generated | Helper bundle ID |
| lastDockIndex | Int? | nil | (v5) Saved Dock position for show/hide restoration |

## Localization

### Supported Locales

| Locale | Code | Notes |
|--------|------|-------|
| UK English | `en-GB` | Base/fallback language for all non-English locales |
| US English | `en-US` | American spelling (Customize, Color) |
| AU English | `en-AU` | Australian spelling (same as UK: Customise, Colour) |

### Architecture

- **Format**: String Catalogs (`.xcstrings`) - Xcode 15+ format
- **Base Language**: en-GB (UK English)
- **Fallback Strategy**: All non-English languages fall back to en-GB
- **Files**:
  - `DockTile/Resources/Localizable.xcstrings` - Main app strings
  - `DockTile/Resources/InfoPlist.xcstrings` - App metadata (CFBundleDisplayName, copyright)
  - `DockTile/Constants/AppStrings.swift` - Centralized string accessors

### Key Spelling Differences

| Category | US English (en-US) | UK/AU English (en-GB, en-AU) |
|----------|-------------------|------------------------------|
| Customize button | "Customize" | "Customise" |
| Color picker | "Color" | "Colour" |
| Navigation title | "Customize Tile" | "Customise Tile" |
| Subtitle | "Choose a background color" | "Choose a background colour" |

### Usage in Code

All user-facing strings use the `AppStrings` enum:

```swift
// ✅ Correct
Button(AppStrings.Button.customise) { ... }
Text(AppStrings.Label.colour)

// ❌ Wrong - Do not use hardcoded strings
Button("Customise") { ... }
Text("Colour")
```

**AppStrings Categories**:
- `AppStrings.Button.*` - Button labels
- `AppStrings.Label.*` - Form labels
- `AppStrings.Menu.*` - Menu items
- `AppStrings.Navigation.*` - Navigation titles
- `AppStrings.Section.*` - Section headers
- `AppStrings.Empty.*` - Empty state messages
- `AppStrings.Error.*` - User-facing error messages
- `AppStrings.Log.*` - Debug logs (NOT localized - always English)

### Testing Localization

**Manual Testing**:
```bash
# Test UK English
defaults write com.docktile.DockTile AppleLanguages "(en-GB)"
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app

# Test US English
defaults write com.docktile.DockTile AppleLanguages "(en-US)"
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app

# Test AU English
defaults write com.docktile.DockTile AppleLanguages "(en-AU)"
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app

# Reset to system language
defaults delete com.docktile.DockTile AppleLanguages
```

**Unit Tests**:
- `DockTileTests/Unit/Constants/AppStringsTests.swift`
- Tests all string keys return non-empty values
- Tests locale-specific spelling (US vs UK/AU)
- Tests fallback behavior for non-English locales

### Adding New Strings

1. **Add to Localizable.xcstrings**:
   - Open `DockTile/Resources/Localizable.xcstrings` in Xcode
   - Add new key with translations for en-GB, en-US, en-AU
   - Use clear, descriptive keys (e.g., `button.save`, `label.userName`)

2. **Add to AppStrings.swift**:
   ```swift
   enum AppStrings {
       enum Button {
           static let save = NSLocalizedString(
               "button.save",
               value: "Save",  // UK English value
               comment: "Save button label"
           )
       }
   }
   ```

3. **Use in code**:
   ```swift
   Button(AppStrings.Button.save) { ... }
   ```

4. **Add test**:
   ```swift
   @Test("Save button string exists")
   func saveButtonExists() {
       #expect(!AppStrings.Button.save.isEmpty)
   }
   ```

### Adding New Languages

To add German, French, Spanish, etc.:

1. Open `Localizable.xcstrings` in Xcode
2. Click "+" → Add Language → Select language
3. Translate all strings to new language
4. Test with: `defaults write com.docktile.DockTile AppleLanguages "(de)"`

The infrastructure supports unlimited languages - just add translations to the String Catalog.

### User Consent for Dock Modifications

**Consent Dialog**: Before any Dock-modifying action (add, update, show, hide, remove), the app shows a one-time consent dialog:

| Element | Content |
|---------|---------|
| Title | "Dock Restart Required" |
| Message | "Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected." |
| Checkbox | "Don't show this again" |
| Buttons | "Confirm" (primary) / "Cancel" (secondary) |
| Icon | ⚠️ Warning icon (NSAlert.Style.warning) |

**Behavior**:
- Shows on first Dock-modifying action (if user has not checked "Don't show this again")
- Covers ALL Dock actions: add, update, show tile, hide tile, remove tile
- After user checks box + clicks Confirm, never shows again
- Clicking Cancel aborts the action (no Dock modification)
- Preference stored in `UserDefaults.standard.bool(forKey: "hasAcknowledgedDockRestart")`

**Implementation**:
- Dialog created using native `NSAlert` with `NSButton` checkbox accessory
- Uses macOS default left-aligned layout for icon, title, message, and checkbox
- Shown modally via `alert.runModal()` in `DockTileDetailView.showDockRestartConsentAlert()`
- Alert presentation deferred with `DispatchQueue.main.async` to avoid SwiftUI transaction warnings
- Checked via `handleDockAction()` → checks UserDefaults → shows dialog or proceeds directly
- On Confirm: saves checkbox state to UserDefaults if checked, then calls `performDockAction()`
- On Cancel: dismisses dialog, no action taken

**Localization**:
- All strings in `AppStrings.Alert.*` and `AppStrings.Button.confirm`
- No spelling differences between US/UK/AU variants
- Test coverage in `AppStringsTests.swift`

**Testing**:
- Unit tests: `AppStringsTests.swift` - verifies all alert strings exist
- Integration tests: `DockRestartConsentTests.swift` - tests consent flow and UserDefaults persistence
- Manual testing: Reset preference with `defaults delete com.docktile.DockTile hasAcknowledgedDockRestart`

## Key Implementation Details

### Helper Bundle Lifecycle

1. **Creation** (`HelperBundleManager.installHelper`):
   - Copies main DockTile.app as template
   - **Removes `Assets.car`** to prevent main app icon from overriding custom icons
   - Updates Info.plist with unique bundle ID and name
   - **Conditionally sets `LSUIElement`** based on `showInAppSwitcher` config:
     - `showInAppSwitcher = false` → `LSUIElement = true` (Ghost Mode)
     - `showInAppSwitcher = true` → LSUIElement removed (App Mode)
   - Generates custom `.icns` icon via `IconGenerator` (all 4 style variants)
   - Code signs with ad-hoc signature
   - Saves original Dock position (if updating existing tile)
   - Adds to Dock plist at original position (or end if new)
   - Restarts Dock and launches helper app

2. **Runtime** (`HelperAppDelegate`):
   - Reads `showInAppSwitcher` from config in `applicationWillFinishLaunching`
   - **Sets activation policy based on mode**:
     - Ghost Mode → `.accessory` (hidden from Cmd+Tab)
     - App Mode → `.regular` (visible in Cmd+Tab, context menu works)
   - Shows NSPopover on dock icon click
   - Supports keyboard navigation when activated via Cmd+Tab (App Mode only)

3. **Deletion** (`HelperBundleManager.uninstallHelper`):
   - Quits running helper
   - Removes from Dock plist
   - Deletes helper bundle
   - Restarts Dock

### Helper Mode Architecture (Ghost Mode vs App Mode)

The `showInAppSwitcher` toggle controls helper tile behavior through a dual-mode architecture:

| Mode | `showInAppSwitcher` | `LSUIElement` | Activation Policy | Cmd+Tab | Context Menu |
|------|---------------------|---------------|-------------------|---------|--------------|
| **Ghost Mode** | `false` (default) | `true` | `.accessory` | ❌ Hidden | ❌ Won't work |
| **App Mode** | `true` | Not set | `.regular` | ✅ Visible | ✅ Works |

**Why Two Modes?**

macOS has a fundamental architectural constraint: there's no supported way to have a Dock icon while hiding from Cmd+Tab AND having `applicationDockMenu` work. This is an OS-level limitation, not a bug.

- `LSUIElement = true` hides the app from Cmd+Tab but also makes the Dock treat it as a "shortcut" rather than a "running app", preventing `applicationDockMenu` from being called
- `LSUIElement = false` (or not set) allows full Dock integration including context menus, but the app will appear in Cmd+Tab

**Implementation:**

1. **Bundle Generation** (`HelperBundleManager.updateInfoPlist`):
   - If `showInAppSwitcher = false`: Sets `LSUIElement = true` in Info.plist
   - If `showInAppSwitcher = true`: Removes `LSUIElement` from Info.plist

2. **Runtime** (`HelperAppDelegate.applicationWillFinishLaunching`):
   - Reads `showInAppSwitcher` from config
   - Sets `.accessory` policy for Ghost Mode, `.regular` for App Mode

**Trade-offs:**

| Feature | Ghost Mode | App Mode |
|---------|------------|----------|
| Dock icon | ✅ Visible | ✅ Visible |
| Left-click popover | ✅ Works | ✅ Works |
| Hidden from Cmd+Tab | ✅ Yes | ❌ No |
| Right-click context menu | ❌ No | ✅ Yes |
| "Configure..." option | ❌ No | ✅ Yes |

**User Guidance:**
- Users who want minimal UI footprint should use Ghost Mode (default)
- Users who want right-click context menu should enable "Show in App Switcher"

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

## CI/CD Configuration

### GitHub Actions Path Filtering

The CI workflow uses `paths-ignore` to skip builds when only non-code files change:

```yaml
on:
  push:
    branches: [main, develop]
    paths-ignore:
      - 'website/**'
      - 'vercel.json'
      - '*.md'
  pull_request:
    branches: [main]
    paths-ignore:
      - 'website/**'
      - 'vercel.json'
      - '*.md'
```

**Behavior:**
- ✅ Xcode/Swift changes → CI runs
- ⏭️  Website/docs only → CI skips
- ✅ Mixed changes → CI runs

### Vercel Ignore Build Step

The Vercel deployment uses `ignoreCommand` to skip builds when only Xcode files change:

**Configuration** (`vercel.json`):
```json
{
  "ignoreCommand": "git diff HEAD^ HEAD --quiet . ':(exclude)website/**' ':(exclude)vercel.json'"
}
```

**Behavior:**
- ⏭️  Xcode/Swift changes only → Vercel skips
- ✅ Website changes → Vercel builds
- ✅ Mixed changes → Vercel builds

**How it works:**
- `git diff --quiet` returns exit code 0 if no changes (skip build)
- `:(exclude)` syntax excludes website paths from diff
- If only website files changed, diff finds changes → exit 1 → build proceeds

**References:**
- [Vercel Ignore Build Step Guide](https://vercel.com/kb/guide/how-do-i-use-the-ignored-build-step-field-on-vercel)
- [GitHub Actions Path Filtering](https://github.com/orgs/community/discussions/164673)

### macOS 26 Beta Runners

Both CI and release workflows use `macos-26` beta runners to match local development:

```yaml
runs-on: macos-26  # ARM64 only, beta status
```

**Benefits:**
- ✅ Same SDK as local (macOS 26.2)
- ✅ Access to macOS 26+ APIs (`.buttonSizing`, etc.)
- ✅ Xcode 26.2 available

**Trade-offs:**
- ⚠️  Beta status: "as-is" with no SLA
- ⚠️  ARM64 only (matches target anyway)

**Reference:** [macOS 26 Beta Announcement](https://github.blog/changelog/2025-09-11-actions-macos-26-image-now-in-public-preview/)

---

## Recent Changes

### Documentation Cleanup (2026-02)
- **Cleanup**: Removed "Missing Configure... Context Menu" from Known Issues
- **Reason**: Not a bug - this is the designed trade-off in Ghost Mode vs App Mode architecture
- **Context Menu Behavior**:
  - Ghost Mode (`showInAppSwitcher = false`, default): No context menu, hidden from Cmd+Tab
  - App Mode (`showInAppSwitcher = true`): Full context menu with "Configure..." option, visible in Cmd+Tab
- **User Choice**: Users can toggle between modes based on their preference
- **Removed Task 7**: Onboarding Flow - not needed since no permissions required
- **Updated Task 12**: Landing Page Website now "In Progress" with Next.js deployment
- **Files Modified**: `CLAUDE.md` - Updated Known Issues, Release Roadmap, and Task Details

### CI/CD Infrastructure Updates (2026-02)
- **Feature**: Configured intelligent build skipping for CI and Vercel
- **GitHub Actions**: Already had `paths-ignore` for website/docs (no changes needed)
- **Vercel**: Added `ignoreCommand` using official recommended pattern
  - Uses `git diff --quiet` with `:(exclude)` syntax
  - Skips builds when only Xcode files changed
  - Works within Vercel's 10-commit shallow clone limitation
- **macOS 26 Runners**: Updated workflows to use `macos-26` beta runners
  - Matches local development environment (macOS 26.2, Xcode 26.2)
  - Enables macOS 26+ APIs like `.buttonSizing(.flexible)`
- **Files Created/Modified**:
  - `vercel.json` - Added ignore command with best-practice pattern
  - `.github/workflows/ci.yml` - Updated to `macos-26` runners
  - `.github/workflows/release.yml` - Updated to `macos-26` runners

### Test Infrastructure Fixes (2026-02)
- **Feature**: Fixed all remaining test failures to enable CI/CD integration
- **Consent Dialog Tests**: Fixed race condition in `DockRestartConsentTests`
  - Added `.serialized` trait to prevent parallel execution conflicts
  - Tests validate UserDefaults persistence of `hasAcknowledgedDockRestart` flag
- **Localization Tests**: Fixed `AppStringsTests` to work with String Catalogs
  - Created `localizedString(for:locale:)` helper that parses `.xcstrings` JSON directly
  - Replaced `withLocale` approach (doesn't work with NSLocalizedString caching)
  - Updated all 7 test functions: US/UK/AU spelling variants
  - Tests verify "Customize" vs "Customise" and "Color" vs "Colour"
- **TintColor Tests**: Fixed `TintColorTests` after `.yellow` color removal
  - Updated expected count from 8 to 7 preset colors
  - Removed `.yellow` from switch statements in icon name tests
- **Module Import Fixes**: Updated all test files to use correct module name `Dock_Tile`
- **Files Modified**:
  - `DockTileTests/Integration/DockRestartConsentTests.swift` - Added `.serialized`
  - `DockTileTests/Unit/Constants/AppStringsTests.swift` - New JSON parsing helper
  - `DockTileTests/Unit/Models/TintColorTests.swift` - Updated color count
  - `DockTileTests/Unit/Models/ConfigurationModelsTests.swift` - Removed `.yellow`
  - `DockTileTests/Unit/Utilities/IconGeneratorTests.swift` - Removed `.yellow`
- **Testing**:
  - All unit tests: ✅ PASS (Cmd+U in Xcode)
  - Terminal tests: ✅ PASS (`xcodebuild test`)
  - Ready for CI/CD integration
- **Infrastructure**: Tests now fully compatible with String Catalogs (.xcstrings) format

### English Localization Support (US, UK, AU) (2026-02)
- **Feature**: Implemented comprehensive localization infrastructure for English language variants
- **Scope**: Added support for US English (en-US), UK English (en-GB), and Australian English (en-AU)
- **Approach**: String Catalogs (`.xcstrings`) with en-GB as base language
- **Key Spelling Differences**:
  - **US**: Customize, Color
  - **UK/AU**: Customise, Colour
- **Fallback Strategy**:
  - Non-English languages (French, German, etc.) → en-GB (UK English)
  - US users → en-US (US spelling)
  - UK/AU users → en-GB/en-AU (UK spelling)
- **Files Created**:
  - `DockTile/Resources/Localizable.xcstrings` - Main app strings
  - `DockTile/Resources/InfoPlist.xcstrings` - App metadata (bundle name, copyright)
  - `DockTileTests/Unit/Constants/AppStringsTests.swift` - Localization unit tests
  - `STRING_INVENTORY.md` - Complete string inventory documentation
- **Files Modified**:
  - `DockTile/Constants/AppStrings.swift` - Expanded with all localization keys organized by category (Buttons, Labels, Menu, Navigation, etc.)
  - All View files (`DockTileConfigurationView`, `DockTileSidebarView`, `DockTileDetailView`, `CustomiseTileView`) - Replaced hardcoded strings with `AppStrings` references
  - All UI components (`NativePopoverViews.swift`) - Replaced hardcoded strings
  - `HelperAppDelegate.swift` - Context menu strings localized
  - `HelperBundleManager.swift` - User-facing error messages localized
- **Testing**:
  - Debug build: ✅ SUCCESS
  - Release build: ✅ SUCCESS
  - Unit tests: Created (pending Xcode project integration)
- **Helper Bundles**: Automatically inherit localization from main app (no special handling needed)
- **Future Expansion**: Infrastructure supports adding more languages (German, French, Spanish, Japanese, Chinese)

### macOS 26+ Flexible Button Sizing (2026-02)
- **Feature**: Segmented picker now uses flexible button sizing on macOS 26+
- **Implementation**: Option 3 approach with separate computed properties and `@available` checks
  ```swift
  @available(macOS 26.0, *)
  private var pickerWithFlexibleSizing: some View {
      Picker(...).buttonSizing(.flexible)
  }

  private var pickerWithStandardSizing: some View {
      Picker(...)  // macOS 15-25
  }

  @ViewBuilder
  private var segmentedPicker: some View {
      if #available(macOS 26.0, *) {
          pickerWithFlexibleSizing
      } else {
          pickerWithStandardSizing
      }
  }
  ```
- **Why This Works**:
  - `@available` annotation tells compiler to skip API validation on older targets
  - Separate properties avoid SwiftUI type system conflicts
  - Runtime check ensures correct version is used
- **Enabled By**: CI now uses `macos-26` runners with SDK 26.2
- **Benefits**:
  - macOS 26+ users: Full-width segmented control buttons in CustomiseTileView
  - macOS 15-25 users: Standard sizing (works perfectly)
  - No functionality lost on older OS versions
- **Location**: `DockTile/Views/CustomiseTileView.swift` (segmented picker for Symbol/Emoji tabs)

### Helper Mode Architecture: Ghost Mode vs App Mode (2026-02)
- **Feature**: Restored the "Show in App Switcher" toggle functionality with a dual-mode architecture
- **Problem**: Previous fix for context menu broke the ghost mode feature - tiles always appeared in Cmd+Tab
- **Root Cause**: macOS has a fundamental constraint - you can't have Dock icon + hidden from Cmd+Tab + working context menu. You must choose between:
  - Ghost Mode: Hidden from Cmd+Tab, but no context menu
  - App Mode: Visible in Cmd+Tab, with working context menu
- **Solution**: Implemented dual-mode architecture based on `showInAppSwitcher` toggle:

  | Mode | `showInAppSwitcher` | `LSUIElement` | Policy | Cmd+Tab | Context Menu |
  |------|---------------------|---------------|--------|---------|--------------|
  | Ghost | `false` (default) | `true` | `.accessory` | ❌ | ❌ |
  | App | `true` | Not set | `.regular` | ✅ | ✅ |

- **Implementation**:
  - `HelperBundleManager.updateInfoPlist()`: Conditionally sets `LSUIElement` based on config
  - `HelperAppDelegate.applicationWillFinishLaunching()`: Sets activation policy based on config
- **Files Modified**:
  - `HelperBundleManager.swift` - Added `showInAppSwitcher` parameter to bundle generation
  - `HelperAppDelegate.swift` - Reads config and sets appropriate activation policy
  - `CLAUDE.md` - Added Helper Mode Architecture documentation
- **User Impact**: Users can now choose their preferred trade-off:
  - Default (Ghost Mode): Minimal UI footprint, hidden from Cmd+Tab
  - App Mode: Full Dock integration with right-click "Configure..." menu

### Icon Generation Pixel Dimensions Fix (2026-02)
- **Problem**: Generated .icns files were missing 16x16 and 128x128 sizes, causing helper tile icons to appear larger in the Dock compared to native macOS apps
- **Root Cause**: `NSImage(size:)` with `lockFocus()` creates a backing store at the display's scale factor (2x on Retina). A 16pt icon became 32 pixels, which `iconutil` couldn't recognize as a valid 16x16 icon and excluded it.
- **Investigation**: Compared extracted iconsets between DockTile's icons and native Safari/Calculator apps - Safari had `ic04` (16x16) and `ic07` (128x128) type codes while DockTile only had larger sizes.
- **Fix**: Replaced `NSImage(size:).lockFocus()` approach with explicit `NSBitmapImageRep` creation:
  ```swift
  // Create bitmap representation with exact pixel dimensions
  guard let bitmapRep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixelWidth,  // Exact pixel count, not points
      pixelsHigh: pixelHeight,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
  ) else { ... }

  // Create graphics context from bitmap
  guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else { ... }
  NSGraphicsContext.current = graphicsContext
  // ... draw into context ...
  ```
- **Files Modified**: `IconGenerator.swift` - `generateIcon()` function
- **Result**: Generated .icns files now include all 10 required sizes (16, 32, 128, 256, 512 @ 1x and 2x), matching native macOS app icons

### Context Menu Fix for Helper Tiles (2026-02)
- **Problem**: Right-clicking on helper tiles in Dock didn't show the "Configure..." context menu
- **Root Cause**: `LSUIElement=true` in Info.plist causes the Dock to treat the app as a "shortcut" rather than a "running app", preventing `applicationDockMenu(_:)` from being called
- **Initial Fix**: Removed `LSUIElement` and always used `.regular` policy
- **Limitation**: This broke ghost mode - tiles always appeared in Cmd+Tab
- **Final Solution**: See "Helper Mode Architecture" above - implemented dual-mode system where users choose between ghost mode (no context menu) and app mode (with context menu)

### Running App Icon Size Fix (2026-02)
- **Problem**: Helper tile icons appeared larger in the Dock when the app was running vs when quit
- **Root Cause**: `HelperBundleManager.switchIcon()` was calling `NSApp.applicationIconImage = iconImage` to update the icon at runtime. Setting the icon programmatically causes macOS to render it differently (larger) than the static bundle icon.
- **Investigation**: Other native apps (Notes, Safari, Finder) never change size because they don't set `applicationIconImage` at runtime - they rely entirely on the static `.icns` file in their bundle.
- **Fix**: Removed `NSApp.applicationIconImage` assignment. The icon switching still works via file-based approach:
  1. Copy the correct icon variant to `AppIcon.icns`
  2. Call `touchBundle()` to update modification date
  3. Re-register with Launch Services
  4. macOS picks up the new icon from the file system
- **Files Modified**: `HelperBundleManager.swift` - Removed `applicationIconImage` assignment in `switchIcon()`
- **Result**: Helper tile icons now maintain consistent size whether running or not

### Icon Safe Area Limits (2026-02)
- **Feature**: Added hard cap on icon size to prevent icons from exceeding Apple's icon safe area guidelines
- **Implementation**:
  - Added `maxSafeRatio` (0.60) and `warningThreshold` (0.57) constants to `IconGenerator`
  - Stepper in CustomiseTileView is now capped at max 17 for SF Symbols, 16 for Emojis
  - Removed warning text since stepper is now capped
- **Files Modified**:
  - `IconGenerator.swift` - Added safe area constants and `isAtSafeAreaLimit()` method
  - `CustomiseTileView.swift` - Capped stepper and updated row styling to 52pt height

### SwiftUI State Update Warnings Fix (2026-02)
- **Problem**: Console warnings "Publishing changes from within view updates is not allowed"
- **Root Cause**: Calling `configManager.markSelectedConfigAsEdited()` directly inside `.onChange` modifiers
- **Fix**: Wrapped state updates in `DispatchQueue.main.async { }` to defer them outside the view update cycle
- **Files Modified**:
  - `CustomiseTileView.swift` - Wrapped `markSelectedConfigAsEdited()` call
  - `DockTileDetailView.swift` - Wrapped `markSelectedConfigAsEdited()` and config sync updates

### Dock Position Preservation for Show/Hide Toggle (2026-02)
- **Problem**: When user toggles "Show Tile" OFF then back ON, the tile would appear at the end of the Dock instead of its original position
- **Root Cause**: `removeFromDock(for:)` was not saving the Dock position before removal. When the user re-enabled the tile, `installHelper` couldn't restore the position because it was lost.
- **Fix**: Added `lastDockIndex` field (v5) to `DockTileConfiguration` to persist Dock position:
  - When hiding: `removeFromDock(for:)` saves the current Dock index and returns it
  - `DockTileDetailView` saves the returned position to `config.lastDockIndex`
  - When showing: `installHelper` uses `config.lastDockIndex` if not currently in Dock
  - After successful install: `lastDockIndex` is cleared (position is now live in Dock)
- **Files Modified**:
  - `ConfigurationModels.swift` - Added `lastDockIndex: Int?` field (v5)
  - `HelperBundleManager.swift` - `removeFromDock(for:)` now returns saved position; `installHelper` uses `config.lastDockIndex` as fallback
  - `DockTileDetailView.swift` - `handleDockAction()` saves/clears `lastDockIndex`
- **Result**: Tiles maintain their Dock position across show/hide toggles

### Phase 1b Features Complete (2026-02)

**1b.1: Drag to Reorder Apps**
- Added drag handle (grip lines icon) to each row in `NativeAppsTableView`
- Implemented `onDrag`/`onDrop` with custom `AppItemDropDelegate`
- Order persists to config via existing auto-save mechanism
- Popover displays apps in saved order

**1b.2: Multi-select & Remove Apps**
- **Cmd+Click**: Toggle individual row selection (non-contiguous)
- **Shift+Click**: Range selection from last clicked to current row
- **Escape key**: Clears multi-selection (when 2+ items selected)
  - Implemented via `NSEvent.addLocalMonitorForEvents` with `kVK_Escape` from `Carbon.HIToolbox`
- **"-" button**: Disabled when `selectedAppIDs.isEmpty`
- Files: `DockTileDetailView.swift` - `NativeAppsTableView`, `AppItemDropDelegate`

**1b.3: Dynamic Grid Popover Width**
- Simplified `LayoutMode` enum: removed `.grid2x3`, `.grid3x3`, `.grid4x4`, `.horizontal1x6`
- Now only `.grid` (dynamic) and `.list` (menu-style)
- Backward compatibility decoder maps old values to new enum
- Dynamic column calculation in `StackPopoverView`:
  | App Count | Columns |
  |-----------|---------|
  | 1-4       | 2       |
  | 5-6       | 3       |
  | 7-8       | 4       |
  | 9-10      | 5       |
  | 11-12     | 6       |
  | 13+       | 7 (max) |
- Popover width calculated dynamically: `(itemWidth × cols) + (spacing × (cols-1)) + (padding × 2)`
- Files: `ConfigurationModels.swift`, `NativePopoverViews.swift`, `FloatingPanel.swift`, `LauncherView.swift`, `DockTileDetailView.swift`

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

## Known Issues / TODO

**No critical bugs or regressions at this time.** ✅

All core functionality is working as designed. See Release Roadmap below for remaining tasks.

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

### Phase 1b: Feature Enhancements

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 1b.1 | **Drag to Reorder Apps** | ✅ Done | High | Drag rows in Selected Items table to reorder; order persists to config and popover |
| 1b.2 | **Multi-select & Remove Apps** | ✅ Done | High | Cmd+Click for toggle, Shift+Click for range; Escape clears; "-" removes all selected |
| 1b.3 | **Dynamic Grid Popover Width** | ✅ Done | High | Grid columns auto-adjust: 2 cols (1-4 apps) → 7 cols max (13+ apps) |

### Phase 2: Distribution

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 4 | **Build Pipeline (CI/CD)** | ✅ Done | High | GitHub Actions workflows: `ci.yml` (builds on push/PR), `release.yml` (builds/signs/notarizes on tag) |
| 5 | **DMG Installer** | ✅ Done | High | `Scripts/create-dmg.sh` creates DMG with Applications symlink |
| 6 | **Code Signing & Notarization** | ✅ Done | High | `DockTile.entitlements` + `Scripts/notarize.sh` + `Scripts/build-release.sh` |

### Phase 3: User Experience

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 7b | **Clear/Tinted Mode Hint** | 🔲 Deferred | Low | Show subtitle in CustomiseTileView colour section explaining "Dock applies system tint" when in Clear/Tinted mode. Needs careful layout to not break inspector card. |
| 11 | **Localization (English Variants)** | ✅ Done | Medium | US (en), UK (en-GB), AU (en-AU) English. String Catalogs (.xcstrings) with UK fallback for non-English locales. |

### Phase 4: App Store & Marketing

| # | Task | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 8 | **App Store Review** | ✅ Assessed | Medium | Not viable - sandbox restrictions block helper bundle creation |
| 9 | **Alternative Distribution** | 🔲 Pending | Low | Setup direct download mechanism via GitHub Releases |
| 10 | **ProductHunt Launch** | 🔲 Pending | Low | Marketing page and launch strategy |
| 12 | **Landing Page Website** | 🟡 In Progress | Medium | Next.js site deployed to Vercel. **TODO**: Switch from "Coming Soon" to "Download" button, hook up release downloads |

---

### Task Details

#### 3. Main App Icon
**Goal**: Create a memorable app icon for DockTile.app itself
- Should convey "dock" + "customization" concept
- Options: Multiple colored tiles, dock with star, stacked tiles
- Use the same design language as tile icons (gradients, rounded corners)
- Generate all required sizes for macOS (16, 32, 128, 256, 512 @ 1x and 2x)

#### 4. Build Pipeline (GitHub Actions) ✅ COMPLETE
**Implementation**: `.github/workflows/ci.yml` and `.github/workflows/release.yml`

**CI Workflow** (`ci.yml`):
- Triggers on push to main/develop and PRs
- Builds Debug and Release configurations
- Verifies app bundle structure
- Uploads build artifact

**Release Workflow** (`release.yml`):
- Triggers on tag push (v*)
- Imports signing certificate from GitHub Secrets
- Builds with Developer ID signing
- Creates DMG installer
- Notarizes with Apple
- Creates GitHub Release with DMG and checksum

**Required GitHub Secrets**:
- `DEVELOPER_ID_APPLICATION_CERTIFICATE` - Base64-encoded .p12
- `DEVELOPER_ID_APPLICATION_PASSWORD` - Certificate password
- `KEYCHAIN_PASSWORD` - Temporary keychain password
- `APPLE_TEAM_ID` - Team ID
- `APPLE_DEVELOPER_NAME` - Developer name
- `APPLE_ID` - Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD` - App-specific password

#### 5. DMG Installer ✅ COMPLETE
**Implementation**: `Scripts/create-dmg.sh`

Features:
- Auto-detects app from DerivedData or custom path
- Creates DMG with Applications symlink
- Generates SHA-256 checksum
- Outputs to `./build/` directory

Usage:
```bash
./Scripts/create-dmg.sh --app-path /path/to/DockTile.app --version 1.0
```

**Future Enhancement**: Add background image and prettier layout using `create-dmg` npm package.

#### 6. Code Signing & Notarization ✅ COMPLETE
**Implementation**:
- `DockTile/DockTile.entitlements` - Hardened runtime entitlements
- `Scripts/notarize.sh` - Notarization script
- `Scripts/build-release.sh` - Full release orchestration

**Entitlements** (required for helper bundle architecture):
- `cs.allow-unsigned-executable-memory`
- `cs.disable-library-validation`
- `automation.apple-events`

**Usage**:
```bash
# Full release build with signing and notarization
./Scripts/build-release.sh --sign --notarize

# Or step by step:
./Scripts/create-dmg.sh --app-path ./build/Build/Products/Release/DockTile.app
./Scripts/notarize.sh --dmg-path ./build/DockTile-1.0.dmg
```

#### 1b.1 Drag to Reorder Apps
**Goal**: Allow users to drag rows in the Selected Items table to reorder apps

**Behavior**:
- User can drag rows up/down to reorder apps in `NativeAppsTableView`
- New order persists to config JSON on save (via existing auto-save mechanism)
- Popover displays apps in the saved order (reads from `appItems` array)

**Implementation**:
```swift
// In NativeAppsTableView:
// 1. Add .onMove modifier to ForEach
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    // ... row content
}
.onMove { from, to in
    items.move(fromOffsets: from, toOffset: to)
}

// 2. Add drag indicator (grip lines) to each row
// 3. May need to wrap in List for native drag support, or use custom drag gesture
```

**Files to Modify**:
- `DockTileDetailView.swift` - `NativeAppsTableView` struct

**Considerations**:
- SwiftUI's `.onMove` works best with `List`, but current impl uses `VStack + ForEach`
- Option A: Convert to `List` with custom styling to match current design
- Option B: Use `DragGesture` with manual reordering logic
- Option C: Use `onDrag`/`onDrop` modifiers for more control

---

#### 1b.2 Multi-select & Remove Apps
**Goal**: Allow selecting multiple apps and removing them at once

**Behavior**:
- **Cmd+Click**: Toggle individual row selection (non-contiguous)
- **Shift+Click**: Range selection (from last selected to clicked row)
- **"-" button**: Removes all selected apps at once
- **"-" button disabled** when no apps are selected

**Implementation**:
```swift
// In NativeAppsTableView:
// 1. Track last clicked index for Shift+Click range selection
@State private var lastClickedIndex: Int? = nil

// 2. Update onTapGesture to handle modifiers
.onTapGesture {
    // Check for modifier keys using NSEvent
    let modifiers = NSEvent.modifierFlags

    if modifiers.contains(.command) {
        // Cmd+Click: Toggle selection
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
        lastClickedIndex = index
    } else if modifiers.contains(.shift), let lastIndex = lastClickedIndex {
        // Shift+Click: Range selection
        let range = min(lastIndex, index)...max(lastIndex, index)
        for i in range {
            selection.insert(items[i].id)
        }
    } else {
        // Regular click: Single selection
        selection = [item.id]
        lastClickedIndex = index
    }
}

// 3. In DockTileDetailView, update "-" button:
Button(action: removeSelectedApp) { ... }
    .disabled(selectedAppIDs.isEmpty)  // Changed from: selectedAppIDs.isEmpty && editedConfig.appItems.isEmpty
```

**Files to Modify**:
- `DockTileDetailView.swift` - `NativeAppsTableView` and `-` button logic

---

#### 1b.3 Dynamic Grid Popover Width
**Goal**: Auto-adjust grid columns based on app count

**Column Rules**:
| App Count | Columns |
|-----------|---------|
| 1-4 apps  | 2 cols  |
| 5-6 apps  | 3 cols  |
| 7-8 apps  | 4 cols  |
| 9-10 apps | 5 cols  |
| 11-12 apps| 6 cols  |
| 13+ apps  | 7 cols (max) |

**Breaking Changes**:
- Remove fixed grid options (`.grid2x3`, etc.) from `LayoutMode`
- Simplify `LayoutMode` to just `.grid` and `.list`
- Backward compatibility: Old configs with `.grid2x3`, `.horizontal1x6` migrate to `.grid`/`.list`

**Implementation**:
```swift
// 1. Update LayoutMode enum in ConfigurationModels.swift:
enum LayoutMode: String, Codable, Hashable {
    case grid = "grid"      // Dynamic grid (replaces grid2x3, grid3x3, etc.)
    case list = "list"      // List view (replaces horizontal1x6)

    // Backward compatibility decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "grid", "grid2x3", "grid3x3", "grid4x4":
            self = .grid
        case "list", "horizontal1x6":
            self = .list
        default:
            self = .grid
        }
    }
}

// 2. Update StackPopoverView in NativePopoverViews.swift:
private var columnCount: Int {
    let count = apps.count
    switch count {
    case 0...4: return 2
    case 5...6: return 3
    case 7...8: return 4
    case 9...10: return 5
    case 11...12: return 6
    default: return 7  // 13+ apps
    }
}

private var columns: [GridItem] {
    Array(repeating: GridItem(.fixed(100), spacing: 8), count: columnCount)
}

private var popoverWidth: CGFloat {
    // Calculate based on column count: (100 * cols) + (8 * (cols-1)) + (16 * 2 padding)
    CGFloat(100 * columnCount + 8 * (columnCount - 1) + 32)
}

// 3. Update Layout picker in DockTileDetailView.swift:
Picker("", selection: $editedConfig.layoutMode) {
    Text("Grid").tag(LayoutMode.grid)
    Text("List").tag(LayoutMode.list)
}
```

**Files to Modify**:
- `ConfigurationModels.swift` - `LayoutMode` enum
- `ConfigurationSchema.swift` - Default layout mode
- `NativePopoverViews.swift` - `StackPopoverView` dynamic columns
- `DockTileDetailView.swift` - Layout picker options

---

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

#### 9. Alternative Distribution
**Goal**: Setup direct download distribution via GitHub Releases

**Approach**: Free, open-source distribution model
- Host releases on GitHub Releases
- DMG installer already configured via `Scripts/create-dmg.sh`
- Code signing and notarization pipeline ready
- No payment processing needed (free app)

**Implementation**:
1. Tag release (e.g., `v1.0.0`)
2. GitHub Actions automatically builds, signs, notarizes, and creates release
3. Users download DMG from GitHub Releases page
4. Website links directly to latest release

**Future Options** (if needed):
- Gumroad for paid upgrades/donations
- Paddle for professional payment handling

#### 10. ProductHunt Launch
**Preparation**:
- Create compelling tagline
- Record demo GIF/video
- Prepare screenshots
- Write description highlighting use cases
- Schedule for Tuesday-Thursday (best days)

#### 12. Landing Page Website
**Goal**: Create a minimalist landing page for DockTile

**Current Status**: ✅ **Deployed to Vercel** at `docktile.rkarthik.co` with "Coming Soon" state

**Tech Stack**:
- **Next.js 15** with TypeScript
- **Tailwind CSS** with dark mode support
- **shadcn/ui** components
- Hosted on **Vercel** (free tier)
- Custom domain: `docktile.rkarthik.co`

**Page Sections** (Complete):
1. ✅ **Hero**: App icon with 3D tilt effect + tagline + "Coming Soon" button
2. ✅ **Screenshot**: Placeholder for app screenshot
3. ✅ **FAQ**: Collapsible sections with common questions
4. ✅ **Support**: Contact information
5. ✅ **Footer**: Privacy policy link, creator credit

**TODO - Launch Preparation**:
1. **Switch "Coming Soon" to "Download" button**:
   - In `website/components/hero.tsx`:
     - Comment out lines 81-87 (Coming Soon button)
     - Uncomment lines 89-96 (Download button)
   - Update download URL in `website/lib/config.ts` to point to GitHub release

2. **Hook up Release Notes**:
   - Option A: Link to GitHub Releases page
   - Option B: Create `/releases` page in Next.js site
   - Add "Release Notes" link in footer or hero section

3. **Update System Requirements**:
   - Change "Coming Q1 2026 · Requires macOS 26 or later" to actual release date
   - Confirm minimum macOS version (currently set to macOS 26, but app works on macOS 15+)

4. **Add App Screenshots**:
   - Replace placeholder in `website/components/screenshot.tsx`
   - Provide high-quality screenshots of:
     - Main configuration window
     - Dock with custom tiles
     - Popover with app grid

**Vercel Configuration**:
- Root-level `vercel.json` configured with `ignoreCommand` for monorepo
- Automatic deployments on push to main/develop
- Custom domain configured

**Analytics**:
- Download click tracking implemented
- Release notes click tracking implemented
- Uses `trackDownloadClick()` and `trackReleaseNotesClick()` in `website/lib/analytics.ts`

#### 11. Localization (English Variants)
**Goal**: Support US, UK, and AU English localizations

**Target Locales**:
| Locale | Code | Notes |
|--------|------|-------|
| US English | `en` | Base/development language (already exists) |
| UK English | `en-GB` | British spelling: "Customise", "Colour" |
| AU English | `en-AU` | Australian spelling (same as UK) |

**Infrastructure (Already in Place)**:
- `AppStrings.swift` with `NSLocalizedString` wrappers
- All user-visible strings centralized with localization keys

**Files to Create**:
```
DockTile/Resources/
├── en.lproj/
│   ├── Localizable.strings      # App strings (base)
│   └── InfoPlist.strings        # Info.plist strings (base)
├── en-GB.lproj/
│   ├── Localizable.strings      # UK English translations
│   └── InfoPlist.strings
└── en-AU.lproj/
    ├── Localizable.strings      # AU English translations
    └── InfoPlist.strings
```

**String Differences (UK/AU vs US)**:
| Key | US English | UK/AU English |
|-----|------------|---------------|
| Customise button | "Customize" | "Customise" |
| Colour section | "Color" | "Colour" |
| Any "...ize" words | "-ize" suffix | "-ise" suffix |
| Any "...or" words | "-or" suffix | "-our" suffix |

**Implementation Steps**:
1. **Export Base Strings**: Use `genstrings` or Xcode's export feature
   ```bash
   find DockTile -name "*.swift" -exec genstrings -o DockTile/Resources/en.lproj {} +
   ```

2. **Create Localizable.strings** (en.lproj - base):
   ```
   /* App display name */
   "app.name" = "Dock Tile";

   /* Menu item to create a new tile */
   "menu.newTile" = "New Dock Tile";

   /* Navigation title for sidebar */
   "sidebar.title" = "Dock Tile";
   ```

3. **Create UK/AU Variants**: Copy base and update spellings
   ```
   /* Customize button becomes Customise */
   "button.customize" = "Customise";

   /* Color picker becomes Colour */
   "label.color" = "Colour";
   ```

4. **Update Xcode Project**:
   - Add `.lproj` folders to project
   - Enable localization in project settings
   - Set "Use Base Internationalization" = YES

5. **Update AppStrings.swift** (if needed):
   - Ensure all keys match `.strings` files
   - Add any missing `NSLocalizedString` calls

**Testing**:
```bash
# Test UK English
defaults write com.docktile.app AppleLanguages "(en-GB)"
open "/path/to/Dock Tile.app"

# Reset to system language
defaults delete com.docktile.app AppleLanguages
```

**Xcode 15+ Alternative**: Consider using **String Catalogs** (`.xcstrings`) instead of `.strings` files:
- Single file for all localizations
- Better diffing and merge conflict resolution
- Visual editor in Xcode
- Automatic extraction of strings

**Future Expansion**:
Once English variants are complete, the infrastructure supports adding:
- German (de)
- French (fr)
- Spanish (es)
- Japanese (ja)
- Simplified Chinese (zh-Hans)

---

### Implementation Order (Remaining)

```
Phase 1b: Feature Enhancements ✅ COMPLETE
├── Task 1b.1: Drag to Reorder Apps ✅
├── Task 1b.2: Multi-select & Remove Apps ✅ (includes Escape key to clear)
└── Task 1b.3: Dynamic Grid Popover Width ✅

Bug Fixes (CURRENT)
└── Fix: "Configure..." context menu missing from helper tile right-click
    ├── Should show context menu with app list + "Configure..." option
    ├── "Configure..." should open main DockTile.app with tile selected
    └── Location: HelperAppDelegate.swift

Phase 2: Distribution Setup ✅ COMPLETE
├── Task 4: GitHub Actions pipeline ✅
│   ├── .github/workflows/ci.yml (build on push/PR)
│   └── .github/workflows/release.yml (sign/notarize on tag)
├── Task 5: DMG installer ✅
│   └── Scripts/create-dmg.sh
└── Task 6: Code signing ✅
    ├── DockTile/DockTile.entitlements
    ├── Scripts/notarize.sh
    └── Scripts/build-release.sh

Phase 3: User Experience
└── Task 7: Onboarding Flow (optional)
    ├── No permissions required (CFPreferences API handles Dock integration)
    ├── Purely educational - explains app concept
    └── Design: Bartender/Alcove/Klack style

Phase 4: Marketing & Launch
├── Task 12: Landing Page Website
│   ├── Static HTML/CSS in /website folder
│   ├── Hosted on Vercel at docktile.rkarthik.co
│   ├── Sections: Hero, Features, Screenshot, FAQ, Support, Footer
│   └── Contact via mailto: link (repo is private)
└── Task 9-10: Distribution & marketing

Phase 5: Localization
└── Task 11: English Variants (US, UK, AU)
    ├── Leverage existing AppStrings.swift infrastructure
    ├── Create en.lproj, en-GB.lproj, en-AU.lproj folders
    ├── Spelling differences: -ize → -ise, -or → -our
    └── Consider String Catalogs (.xcstrings) for Xcode 15+
```
