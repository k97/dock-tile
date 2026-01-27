# DockTile Configurator - Updated Implementation Guide
## Drill-Down Design Pattern

---

## Overview

This implementation follows your updated design with a drill-down pattern for tile customisation, matching screens 3 and 4 from your mockups.

---

## Screen Flow

```
App Launch → Screen 3 (Main Window)
                ↓
         Select DockTile
                ↓
         Click "Customise"
                ↓
   Screen 4 (Customise Tile - Drill-down)
                ↓
         Click "Back"
                ↓
   Return to Screen 3 (with updated icon)
```

---

## File Structure

```
DockTileConfigurator/
├── DockTileConfiguratorApp.swift          # Main app entry
├── Views/
│   ├── DockTileConfigurationView_Updated.swift    # Screen 3: Main window
│   ├── CustomiseTileView.swift                    # Screen 4: Customise (drill-down)
│   └── ItemPickerSheet.swift                      # File picker for adding items
├── Models/
│   └── ConfigurationModels.swift          # Data models
├── Extensions/
│   └── ColorExtensions.swift              # Color hex support
└── Components/
    └── (LauncherView, etc. from previous implementation)
```

---

## Screen 3: Main Window (DockTileConfigurationView_Updated.swift)

### **Layout:**

```
┌─────────────────────────────────────────────────────────┐
│  [+]  DockTile                           [Traffic Lights]│
├──────────────┬──────────────────────────────────────────┤
│              │                                           │
│  [Sidebar]   │  [Detail View or Drill-down]             │
│              │                                           │
│  DockTiles   │  ┌─────────────────┐                     │
│  ┌────────┐  │  │  Icon Preview   │                     │
│  │Search  │  │  │    (80×80pt)    │                     │
│  └────────┘  │  └─────────────────┘                     │
│              │                                           │
│  • My Tile   │  [Customise Button]                      │
│  • Work      │                                           │
│  • Design    │  NAME                                    │
│              │  [Text Field]                            │
│              │                                           │
│              │  LAYOUT                                  │
│              │  [Grid 2×3] [Horizontal 1×6]             │
│              │                                           │
│              │  VISIBILITY                              │
│              │  [ ] Show in Dock                        │
│              │                                           │
│              │  ────────────────────                    │
│              │                                           │
│              │  ITEMS              [+ Add Item]         │
│              │  ┌──────────────────────────────┐        │
│              │  │ [≡] [Icon] Safari        [×] │        │
│              │  │ [≡] [Icon] Mail          [×] │        │
│              │  └──────────────────────────────┘        │
└──────────────┴──────────────────────────────────────────┘
```

### **Key Components:**

**Toolbar:**
- `+` button (top-left) → Creates new DockTile
- Adds to sidebar immediately
- Auto-selects new DockTile

**Detail View:**
- **Icon Preview:** 80×80pt placeholder with gradient
- **Customise Button:** Blue button → Drills down to Screen 4
- **Name Field:** Editable text field for DockTile name
- **Layout Selector:** Grid (2×3) vs Horizontal (1×6) buttons
- **Visibility Toggle:** "Show in Dock" switch
- **Items List:** Scrollable list with add/remove

**Interactions:**
- Select DockTile in sidebar → Shows detail view
- Click "Customise" → Slides to Screen 4
- Click "+ Add Item" → Opens NSOpenPanel
- Toggle "Show in Dock" → Activates/deactivates helper

---

## Screen 4: Customise Tile (CustomiseTileView.swift)

### **Layout:**

```
┌─────────────────────────────────────────────────────────┐
│  [< Back]      Customise Tile              [Empty Space]│
├──────────────────────────────────────────────────────────┤
│                                                          │
│                  ┌──────────────────┐                    │
│                  │                  │                    │
│                  │  Large Icon      │                    │
│                  │   (160×160pt)    │                    │
│                  │                  │                    │
│                  └──────────────────┘                    │
│                                                          │
│                    My DockTile                           │
│                  (Name - Read Only)                      │
│                                                          │
│  ────────────────────────────────────────────────────   │
│                                                          │
│  COLOUR                                                  │
│  ○  ●  ●  ●  ●  ●  ●  ●  ●                              │
│  (No colour + 8 tint colours in grid)                   │
│                                                          │
│  SYMBOL                                                  │
│  ┌────────────────────────────────┐                     │
│  │  ●●●                    Emoji ▸│                     │
│  └────────────────────────────────┘                     │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### **Key Components:**

**Header:**
- Back button (< Back) → Returns to Screen 3
- Title: "Customise Tile" (centred)
- Balanced layout with invisible spacer

**Content:**
- **Large Icon:** 160×160pt with live preview
- **Name Display:** Read-only (edit in Screen 3)
- **Colour Picker:** Grid layout, 56×56pt circles
- **Symbol Picker:** Opens macOS emoji picker

**Behaviour:**
- All changes **auto-save** immediately
- No "Done" button needed
- Updates propagate to Screen 3
- Icon preview updates in real-time

---

## Navigation Pattern

### **Drill-Down Transition:**

```swift
@State private var isDrilledDown = false

ZStack {
    if isDrilledDown {
        CustomiseTileView(...)
            .transition(.move(edge: .trailing))
    } else {
        DockTileDetailView(...)
    }
}
.animation(.easeInOut(duration: 0.3), value: isDrilledDown)
```

**Flow:**
1. User clicks "Customise" → `isDrilledDown = true`
2. Screen 4 slides in from right
3. User customises tile → Changes auto-save
4. User clicks "< Back" → `isDrilledDown = false`
5. Screen 3 slides back from left

---

## Auto-Save Implementation

### **Pattern:**

Every component that modifies the config uses this pattern:

```swift
Button(action: {
    var updated = config
    updated.tintColor = newColor
    configManager.updateConfiguration(updated)
}) {
    // Button content
}
```

**What Auto-Saves:**
- ✅ Colour changes (Screen 4)
- ✅ Symbol changes (Screen 4)
- ✅ Layout changes (Screen 3)
- ✅ Name changes (Screen 3)
- ✅ Item additions/removals (Screen 3)
- ✅ Visibility toggle (Screen 3)

**How It Works:**
1. User makes change
2. Updated config sent to `configManager.updateConfiguration()`
3. Config saved to UserDefaults
4. Published change triggers UI update
5. Icon preview refreshes automatically

---

## Components Breakdown

### **Screen 3 Components:**

**DockTileIconPlaceholder:**
- Size: 80×80pt
- Corner radius: 18pt
- Gradient with tint colour
- Symbol: 32pt font
- Shadow: 6pt radius, 3pt offset

**Name Editor:**
- TextField with 15pt font
- Background: #000000 at 4% opacity
- 8pt corner radius
- Auto-saves on change

**Layout Picker:**
- Two buttons: Grid (2×3) and Horizontal (1×6)
- 130pt / 150pt wide, 40pt tall
- Icons + text labels
- Selected: Blue background with white text
- Unselected: Light grey background
- Auto-saves on selection

**Items List:**
- ItemRow: 52pt tall
- Drag handle icon
- 32×32pt app icon
- Remove button (16pt circle)
- Hover state for remove button

### **Screen 4 Components:**

**DockTileIconPreview:**
- Size: 160×160pt
- Corner radius: 36pt
- Larger symbol: 64pt font
- Enhanced shadow: 12pt radius, 6pt offset

**ColourPickerGrid:**
- Adaptive grid layout
- Circles: 56×56pt
- Selected: White stroke + outer glow (68×68pt)
- Spacing: 16pt

**SymbolPickerButton:**
- Height: 56pt
- Current symbol: 32pt
- Opens macOS emoji picker
- Light grey background

---

## Right-Click Context Menu (Screen 2)

### **Implementation:**

Add to `ConfigurationRow` in sidebar:

```swift
.contextMenu {
    Button("Configure") {
        // Select and drill down
        configManager.selectedConfigId = config.id
        isDrilledDown = true
    }
    
    Divider()
    
    Button("Duplicate") {
        configManager.duplicateConfiguration(config)
    }
    
    Divider()
    
    Button("Delete", role: .destructive) {
        configManager.deleteConfiguration(config.id)
    }
}
```

**Menu Items:**
- Configure → Opens Screen 4
- Duplicate → Creates copy
- Delete → Removes DockTile

---

## Launcher Popup (Screen 1)

### **Positioning:**

The launcher popup appears **above the Dock icon** when clicked.

**Implementation in DockTileHelperApp.swift:**

```swift
func showLauncher(at dockIconFrame: NSRect) {
    let popover = NSPopover()
    popover.contentViewController = NSHostingController(
        rootView: LauncherView(config: config)
    )
    
    // Calculate position above Dock icon
    let popoverPoint = NSPoint(
        x: dockIconFrame.midX,
        y: dockIconFrame.maxY + 10
    )
    
    // Show with arrow pointing down to Dock icon
    popover.show(
        relativeTo: dockIconFrame,
        of: dockIconView,
        preferredEdge: .maxY
    )
}
```

**Behaviour:**
- Click DockTile icon → Popup appears above
- Shows grid of apps (2×3 or 1×6)
- Click app → Launches app
- Click outside → Popup dismisses

---

## Testing Flow

### **Complete User Journey:**

1. **Launch App** → Screen 3 shows empty sidebar
2. **Click +** → New DockTile added to sidebar
3. **Select DockTile** → Detail view shows icon placeholder
4. **Click "Customise"** → Drills down to Screen 4
5. **Pick Colour** → Icon preview updates
6. **Choose Symbol** → Emoji picker opens
7. **Select Layout** → Grid/Horizontal changes
8. **Click "< Back"** → Returns to Screen 3
9. **Edit Name** → Type new name
10. **Click "+ Add Item"** → File picker opens
11. **Select App** → App added to list
12. **Toggle "Show in Dock"** → Helper launches
13. **Click Dock Icon** → Launcher popup appears

---

## Key Differences from Previous Design

| Aspect | Previous (v5) | Updated (Your Design) |
|--------|---------------|----------------------|
| Add button | Sidebar bottom | Toolbar header |
| Customisation | Inline in detail | Drill-down to Screen 4 |
| Icon size | 100×100pt (one size) | 80×80pt + 160×160pt |
| Name editing | Detail view | Screen 3 only |
| Layout picker | Detail view | Screen 3 only |
| Items visibility | Always visible | Only in Screen 3 |
| Appearance settings | Detail view | Screen 4 (colour, symbol) |
| Navigation | Single view | Back button navigation |
| Save behaviour | Same (auto-save) | Same (auto-save) |

---

## Files to Update

### **Replace:**
- `DockTileConfigurationView.swift` → `DockTileConfigurationView_Updated.swift`

### **Add:**
- `CustomiseTileView.swift` (new)

### **Keep:**
- `ConfigurationModels.swift`
- `ColorExtensions.swift`
- `ItemPickerSheet.swift`
- `DockTileConfiguratorApp.swift`

### **Update App File:**

```swift
// In DockTileConfiguratorApp.swift
WindowGroup {
    DockTileConfigurationView()  // Uses updated version
        .frame(minWidth: 1000, minHeight: 700)
}
```

---

## Summary

Your updated design provides:

✅ **Cleaner main window** with toolbar + button  
✅ **Focused customisation** in drill-down view (colour + symbol)  
✅ **Better separation** of concerns:
   - Screen 3: Name, layout, visibility, items
   - Screen 4: Visual appearance (colour, symbol)
✅ **Native navigation** with back button  
✅ **Larger preview** in customise view (160×160pt)  
✅ **Auto-save** throughout both screens  
✅ **Simple flow** that's easy to understand  

The code is ready to drop into Xcode and build! 🚀