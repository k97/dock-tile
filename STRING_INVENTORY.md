# String Inventory for Localization

This document contains all user-facing strings that need localization.

## Localization Strategy
- **Base Language**: en-GB (UK English) - fallback for all non-English languages
- **Variants**: en-US (US English), en-AU (Australian English)
- **Key Differences**: US vs UK/AU spelling (Customize → Customise, Color → Colour)

## String Categories

### 1. App Metadata (InfoPlist.xcstrings)
- App display name: "Dock Tile"
- Bundle name: "Dock Tile"
- Copyright notice

### 2. Menu Items
- "New Dock Tile" (menu item)

### 3. Sidebar
- "Dock Tile" (navigation title)
- "No Tiles" (empty state)
- "Create new tile" (tooltip - enabled state)
- "Edit current tile before creating another" (tooltip - disabled state)
- "Duplicate" (context menu)
- "Delete" (context menu)
- "Detail" (placeholder text)

### 4. Main Configuration View
- "Create Your First Tile" (empty state header)
- "New Tile" (button to create first tile)

### 5. Detail View (DockTileDetailView)

#### Action Buttons
- "Add to Dock" (when not in Dock)
- "Update" (when in Dock and toggle is ON)
- "Remove from Dock" (when in Dock and toggle is OFF)
- "Done" (when not in Dock and toggle is OFF)
- "Customise" (button to open customization view) **UK/AU spelling**
- "Remove" (delete button)

#### Form Fields
- "Tile Name" (label)
- "Show Tile" (toggle label)
- "Layout" (picker label)
- "Grid" (layout option)
- "List" (layout option)
- "Show in App Switcher" (toggle label)

#### Apps Section
- "Selected Items" (section header)
- "Item" (table column header)
- "Kind" (table column header)
- "No items added yet" (empty state)
- "Application" (kind value)
- "Folder" (kind value)

#### File Picker
- "Add" (prompt)
- "Select an application or folder to add" (message)

#### Delete Section
- "Delete Tile" (alert title)
- "Cancel" (alert button)
- "Delete" (alert button)
- "Remove from Dock" (section text)

### 6. Customise View (CustomiseTileView) **UK/AU spelling**

#### Navigation
- "Customise Tile" (navigation title) **UK/AU spelling**
- "Back" (back button label)

#### Colour Section **UK/AU spelling**
- "Colour" (section header) **UK/AU spelling**
- "Choose a background colour for your tile" (subtitle) **UK/AU spelling**

#### Icon Type Picker
- "Symbol" (tab label)
- "Emoji" (tab label)

#### Icon Size Section
- "Tile Icon Size" (label)
- "Adjust the size of your icon within the tile" (subtitle)

#### Icon Section
- "Tile Icon" (label)
- "Search symbols" (search placeholder - when Symbol tab active)
- "Search emojis" (search placeholder - when Emoji tab active)

### 7. Popover Views (Helper App)

#### Empty State
- "No apps configured" (empty state text)
- "Configure to add apps" (empty state subtitle - Grid view only)

#### Context Menu (App Mode Only)
- "Configure..." (menu item to open main app)
- "No apps configured" (disabled menu item when empty)
- "Options" (section divider - List view)
- "Open in Finder" (menu item - List view)

### 8. Error Messages (User-Facing Only)

From HelperBundleManager:
- "Main Dock Tile.app not found" (already in AppStrings)
- "Failed to read Info.plist"
- "Failed to write Info.plist"
- "Failed to copy bundle"
- "Failed to code sign helper bundle"

Note: Debug print() statements should NOT be localized (kept in English for developer logs)

### 9. Helper App Delegate

#### Context Menu
- "Configure..." (menu item)
- "No apps configured" (disabled menu item)

## Spelling Differences Summary

### US English (en-US)
- Customize
- Color
- Favorite
- Center

### UK/AU English (en-GB, en-AU)
- Customise
- Colour
- Favourite
- Centre

## Files to Modify

### New Files
1. `DockTile/Resources/Localizable.xcstrings` (String Catalog)
2. `DockTile/Resources/InfoPlist.xcstrings` (App metadata)

### Modified Files
1. `DockTile/Constants/AppStrings.swift` - Expand with all string keys
2. `DockTile/Views/DockTileConfigurationView.swift` - Replace hardcoded strings
3. `DockTile/Views/DockTileSidebarView.swift` - Replace hardcoded strings
4. `DockTile/Views/DockTileDetailView.swift` - Replace hardcoded strings
5. `DockTile/Views/CustomiseTileView.swift` - Replace hardcoded strings
6. `DockTile/UI/NativePopoverViews.swift` - Replace hardcoded strings
7. `DockTile/App/HelperAppDelegate.swift` - Replace hardcoded strings
8. `DockTile/Managers/HelperBundleManager.swift` - Localize error messages only

## Implementation Notes

1. **String Catalog Approach**: Using `.xcstrings` (Xcode 15+) instead of legacy `.strings` files
2. **Fallback Chain**: Non-English languages → en-GB (UK English)
3. **Debug Logs**: Keep print() statements in English (not user-facing)
4. **Context Menu**: Only appears in App Mode (when `showInAppSwitcher = true`)
5. **Helper Bundles**: Inherit localization from main app (copied during bundle creation)
