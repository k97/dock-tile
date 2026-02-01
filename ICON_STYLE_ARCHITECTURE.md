# Icon Style Architecture for macOS Tahoe

## Overview

macOS Tahoe has **two independent appearance settings** that control different aspects of the UI:

### 1. Appearance (Window Chrome)
- **Location**: System Settings → Appearance → Appearance
- **Options**: Auto, Light, Dark
- **Affects**: Window backgrounds, text colors, control styling
- **UserDefaults key**: `AppleInterfaceStyle` ("Dark" or not set for Light)
- **Managed by**: `AppearanceManager.swift` (unchanged)

### 2. Icon and Widget Style (Icons)
- **Location**: System Settings → Appearance → Icon and widget style
- **Options**: Default, Dark, Clear, Tinted
- **Affects**: App icons in Dock, Finder, Launchpad
- **UserDefaults key**: `AppleIconAppearanceTheme`
- **Managed by**: `IconStyleManager.swift` (new)

**Important**: These two settings are **completely independent**! A user can have:
- Light appearance + Dark icon style
- Dark appearance + Default icon style
- Any combination

## Implementation Status

### ✅ Completed

1. **IconStyleManager.swift** (NEW)
   - `IconStyle` enum with cases: `.defaultStyle`, `.dark`, `.clear`, `.tinted`
   - Reads from `AppleIconAppearanceTheme` UserDefaults key via CFPreferences
   - Observes distributed notifications for style changes
   - Includes polling timer as reliable fallback (1-2 second interval)
   - `TintColor.colors(for: IconStyle)` extension for style-aware color generation

2. **DockTileIconPreview.swift** (UPDATED)
   - Now uses `IconStyle` instead of `AppearanceMode`
   - `IconStyleObserverView` (NSViewRepresentable) for real-time style updates
   - Preview updates automatically when icon style changes

3. **IconGenerator.swift** (UPDATED)
   - All methods now use `IconStyle` parameter
   - Generates style-aware icons with appropriate colors

4. **HelperBundleManager.swift** (UPDATED)
   - Generates `AppIcon-default.icns` and `AppIcon-dark.icns`
   - `switchIcon(for:to:)` now takes `IconStyle` parameter
   - Backward compatibility with old `AppIcon-light.icns` naming

5. **HelperAppDelegate.swift** (UPDATED)
   - Observes icon style changes (not appearance)
   - Polls for `AppleIconAppearanceTheme` changes
   - Switches dock icon based on icon style

### Known UserDefaults Values

| Icon Style | `AppleIconAppearanceTheme` Value |
|------------|----------------------------------|
| Default    | Key not set (nil)                |
| Dark       | `RegularDark`                    |
| Clear      | TBD (guessing `RegularClear`)    |
| Tinted     | TBD (guessing `RegularTinted`)   |

## Rendering Styles

### Default Style
- **Background**: Tint color gradient (colorTop → colorBottom)
- **SF Symbol**: White with medium weight
- **Emoji**: Full color, no shadow

### Dark Style
- **Background**: Dark gray gradient (#2C2C2E → #1C1C1E)
- **SF Symbol**: Tint color with medium weight
- **Emoji**: Full color with subtle shadow

### Clear Style (Placeholder)
- **Background**: Semi-transparent gray (#E8E8ED @ 80%)
- **SF Symbol**: Tint color at 70% opacity
- **Emoji**: Full color

### Tinted Style (Placeholder)
- **Background**: Muted tint color gradient (60% opacity)
- **SF Symbol**: White
- **Emoji**: Full color

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        System Settings                               │
│  ┌─────────────────────┐    ┌────────────────────────────────────┐  │
│  │ Appearance          │    │ Icon and Widget Style              │  │
│  │ (Light/Dark/Auto)   │    │ (Default/Dark/Clear/Tinted)        │  │
│  │                     │    │                                    │  │
│  │ AppleInterfaceStyle │    │ AppleIconAppearanceTheme           │  │
│  └──────────┬──────────┘    └──────────────────┬─────────────────┘  │
└─────────────│───────────────────────────────────│────────────────────┘
              │                                   │
              ▼                                   ▼
    ┌──────────────────┐              ┌──────────────────────┐
    │ AppearanceManager│              │   IconStyleManager   │
    │ (unchanged)      │              │   (NEW)              │
    │                  │              │                      │
    │ - Window chrome  │              │ - Icon rendering     │
    │ - Text colors    │              │ - Dock icons         │
    │ - Backgrounds    │              │ - Preview icons      │
    └──────────────────┘              └──────────┬───────────┘
                                                 │
                                                 ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                         Icon Rendering                          │
    │  ┌───────────────────┐  ┌───────────────────┐  ┌─────────────┐ │
    │  │ DockTileIconPreview│  │   IconGenerator   │  │ Helper Dock │ │
    │  │ (SwiftUI)         │  │   (.icns files)   │  │   Icon      │ │
    │  │                   │  │                   │  │             │ │
    │  │ Real-time preview │  │ AppIcon-default   │  │ Runtime     │ │
    │  │ in app UI         │  │ AppIcon-dark      │  │ switching   │ │
    │  └───────────────────┘  └───────────────────┘  └─────────────┘ │
    └─────────────────────────────────────────────────────────────────┘
```

## Debugging

### Check current icon style
```bash
# Read the icon style setting
defaults read -g AppleIconAppearanceTheme
# Returns: RegularDark (for Dark), or "does not exist" for Default
```

### Monitor icon style changes
```bash
# In one terminal, monitor the key
while true; do
    defaults read -g AppleIconAppearanceTheme 2>/dev/null || echo "Default"
    sleep 1
done

# In another terminal, change the setting in System Settings
```

### Test icon switching
1. Open DockTile app with a tile added to Dock
2. Change System Settings → Appearance → Icon and widget style
3. Preview should update within 1-2 seconds
4. Dock icon should switch (may need Dock restart for full effect)

## Future Work

1. **Discover Clear/Tinted values**: Test with these styles enabled to find the exact UserDefaults values
2. **True Clear style**: Implement hierarchical SF Symbol rendering (`.symbolRenderingMode(.hierarchical)`)
3. **True Tinted style**: Read wallpaper dominant color and derive icon colors
4. **Notification optimization**: Find the exact notification name for icon style changes to reduce polling
