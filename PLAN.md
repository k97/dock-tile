# Plan: Tile Icon Size & Adaptive Guide Overlay

## Overview

Add a "Tile Icon Size" stepper control to CustomiseTileView that allows users to adjust the symbol/emoji size relative to the Apple icon guide circles. Also make the guide overlay adaptive - darker for light backgrounds, lighter for dark backgrounds.

## Current State

### Icon Sizing
- **DockTileIconPreview.swift** uses `size * 0.45` for `symbolSize` (fixed ratio)
- **IconGenerator.swift** uses `size.width * 0.45` for SF Symbols and `size.width * 0.5` for emojis
- The middle guide circle is at `rect.width * 0.25` radius (50% diameter = middle circle)
- Current 0.45 ratio means icons almost touch the middle circle

### Guide Circles (IconGridOverlay.swift)
- Outer circle: `rect.width * 0.40` (80% of half-width)
- Middle circle: `rect.width * 0.25` (50% of half-width) ← **This is our reference**
- Inner circle: `rect.width * 0.10` (20% of half-width)

### Current Guide Color
- Fixed: `Color(hex: "#5DB3F9").opacity(0.6)` (light blue)
- Does not adapt to background color

## Proposed Changes

### 1. Add `iconScale` Field to Configuration

**File:** `DockTile/Models/ConfigurationModels.swift`

Add new field:
```swift
var iconScale: Int  // Percentage scale (10-20), default 14 means 0.45 ratio
```

**File:** `DockTile/Models/ConfigurationSchema.swift`

Add default:
```swift
static let iconScale = 14  // Default icon scale (maps to ~0.45 ratio)
```

### 2. Scale Mapping Formula

The icon size should be relative to the **middle circle** (50% diameter = 0.25 radius × 2 = 0.50 of icon width).

**Scale mapping (10-20 range):**
- Scale 10 = 0.30 ratio (smaller than middle circle)
- Scale 14 = 0.45 ratio (current default, almost fills middle circle)
- Scale 20 = 0.65 ratio (extends toward outer circle)

**Formula:**
```swift
let iconRatio = 0.30 + (CGFloat(iconScale - 10) * 0.035)
// Scale 10 → 0.30
// Scale 14 → 0.30 + (4 * 0.035) = 0.44
// Scale 20 → 0.30 + (10 * 0.035) = 0.65
```

### 3. Update DockTileIconPreview

**File:** `DockTile/Components/DockTileIconPreview.swift`

Add `iconScale` parameter:
```swift
let iconScale: Int  // 10-20 range

private var symbolSize: CGFloat {
    let iconRatio = 0.30 + (CGFloat(iconScale - 10) * 0.035)
    return size * iconRatio
}
```

Update initializers and `fromConfig()` to accept scale.

### 4. Update IconGenerator

**File:** `DockTile/Utilities/IconGenerator.swift`

Add `iconScale` parameter to all generation methods:
```swift
static func generateIcon(
    tintColor: TintColor,
    iconType: IconType,
    iconValue: String,
    iconScale: Int,  // NEW
    size: CGSize
) -> NSImage
```

Update font size calculation to use the same formula.

### 5. Add Stepper to CustomiseTileView

**File:** `DockTile/Views/CustomiseTileView.swift`

Add new section after Tile Icon section:
```swift
// Tile Icon Size Section
private var tileIconSizeSection: some View {
    HStack {
        Text("Tile Icon Size")
            .font(.body)
            .foregroundColor(.primary)

        Spacer()

        Stepper(value: $editedConfig.iconScale, in: 10...20) {
            Text("\(editedConfig.iconScale)")
                .frame(width: 30, alignment: .trailing)
        }
    }
    .frame(height: 40)
}
```

### 6. Adaptive Guide Overlay

**File:** `DockTile/Components/IconGridOverlay.swift`

Add luminance-based color adaptation:
```swift
struct IconGridOverlay: View {
    let size: CGFloat
    let backgroundColor: TintColor  // NEW: to calculate contrast
    let lineWidth: CGFloat

    private var lineColor: Color {
        // Calculate luminance of bottom color (darker in gradient)
        let bottomColor = backgroundColor.colorBottom
        let luminance = bottomColor.luminance

        // For light backgrounds (high luminance): use darker overlay
        // For dark backgrounds (low luminance): use lighter overlay
        if luminance > 0.5 {
            return Color.black.opacity(0.25)  // Darker for light backgrounds
        } else {
            return Color.white.opacity(0.35)  // Lighter for dark backgrounds
        }
    }
}
```

Add Color extension for luminance calculation:
```swift
extension Color {
    var luminance: CGFloat {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return 0.5 }
        // Standard luminance formula: 0.299R + 0.587G + 0.114B
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
    }
}
```

### 7. Update All Call Sites

Files to update:
- `CustomiseTileView.swift` - Pass `editedConfig.iconScale` and `tintColor` to preview and overlay
- `DockTileDetailView.swift` - Pass scale to icon preview
- `DockTileSidebarView.swift` - Pass scale to MiniIconPreview
- `HelperBundleManager.swift` - Pass scale when generating icons

## Implementation Order

1. **ConfigurationModels.swift** - Add `iconScale` field with decoder
2. **ConfigurationSchema.swift** - Add default value
3. **DockTileIconPreview.swift** - Add scale parameter, update size calculation
4. **IconGenerator.swift** - Add scale parameter, update all methods
5. **IconGridOverlay.swift** - Add adaptive color based on background luminance
6. **CustomiseTileView.swift** - Add stepper, pass scale to components
7. **DockTileDetailView.swift** - Pass scale to preview
8. **DockTileSidebarView.swift** - Pass scale to mini preview
9. **HelperBundleManager.swift** - Pass scale when generating .icns

## Testing Checklist

- [ ] Stepper increments/decrements iconScale (10-20 range)
- [ ] Icon preview updates in real-time as scale changes
- [ ] Scale persists to JSON configuration
- [ ] Old configs without iconScale use default (14)
- [ ] Generated .icns respects iconScale
- [ ] Guide overlay is darker on yellow/light backgrounds
- [ ] Guide overlay is lighter on blue/dark backgrounds
- [ ] Scale changes auto-save with debounce
