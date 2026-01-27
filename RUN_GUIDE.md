# How to Run DockTile

## Quick Start

### Option 1: Run from Xcode (Recommended)
```bash
open DockTile.xcodeproj
```
Then press **Cmd+R** in Xcode to run.

### Option 2: Command Line (Build + Launch)
```bash
# Build the app
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug

# Launch the app
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app
```

### Option 3: Direct Launch (After Building Once)
```bash
# Find and launch the built app
open ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/DockTile.app
```

---

## What to Expect (As of 2026-01-26)

### Current Implementation Status
- ✅ **Prompts 1-3**: Foundation + Popover + Visual Design (Complete)
- ✅ **Prompt 4 (Partial)**: Configuration UI - ~70% complete
  - Data models and configuration manager ✅
  - Screen 3: Main configuration window ✅
  - Screen 4: Customise drill-down ✅
  - Context menu support ✅
  - Icon generation ⏳
  - Helper bundle generator ⏳
  - LauncherView integration ⏳

### On Launch (After Xcode Integration)

**⚠️ IMPORTANT**: Before running, you must add the new files to Xcode project:
1. Open `DockTile.xcodeproj` in Xcode
2. Add files from: Models/, Managers/, Extensions/, Views/, Components/ folders
3. Ensure all 11 new files are included in the DockTile target
4. Build (Cmd+B) to verify no errors

**Expected behavior after integration:**

1. **Configuration window appears** (Screen 3)
   - LSUIElement is now `false`, so app shows in Dock normally
   - Window shows sidebar (left) + detail panel (right)
   - Empty state: "No DockTile Selected" with "+ New DockTile" button

2. **Create first configuration**:
   - Click + button in toolbar (or Cmd+N)
   - New "My DockTile" appears in sidebar with mini icon
   - Detail panel shows:
     - 80×80pt icon preview (Medical White aesthetic)
     - "Customise" button
     - Name text field
     - Layout picker (Grid 2×3 / Horizontal 1×6)
     - "Show in Dock" toggle
     - Items list (empty initially)

3. **Customize appearance**:
   - Click "Customise" button
   - Screen 4 slides in from right (0.3s animation)
   - Large 160×160pt icon preview at top
   - Color picker grid (9 colors)
   - Symbol picker button (opens Character Viewer)
   - All changes auto-save immediately

4. **Add apps**:
   - Click "+ Add Item" in detail panel
   - File picker opens to /Applications
   - Select .app bundles (e.g., Xcode, Safari)
   - Apps appear in list with 32×32pt icons

### On Dock Click (Existing Functionality)

- FloatingPanel appears above Dock icon
- Medical White popover with glass effect
- Shows 3×2 grid with placeholder apps:
  - Safari, Xcode, Terminal, Notes, Music, Photos
- Hover effects scale icons to 1.05
- Click logs "🚀 Launching: [app name]"
- Click outside to dismiss

### On Right-Click (New!)

Context menu appears with:
- **"Configure..."** - Opens/focuses main configuration window
- Separator line
- **App list** from current configuration (or "No apps configured")
- Click app name to launch it

---

## Testing Checklist

### Basic Functionality
- [ ] App launches and shows configuration window
- [ ] Can create new DockTile configuration
- [ ] Can edit name and see updates in sidebar
- [ ] Can click "Customise" to open Screen 4
- [ ] Can select colors from color picker grid
- [ ] Can click symbol picker (Character Viewer opens)
- [ ] Can click "Back" to return to Screen 3
- [ ] Can add apps via file picker
- [ ] Can remove apps by hovering and clicking X
- [ ] Can toggle "Show in Dock" switch

### Visual Design
- [ ] All text is off-black (#1D1D1F)
- [ ] Backgrounds use Medical White (#F5F5F7)
- [ ] Icons have gradient backgrounds (top → bottom)
- [ ] Corner radius is continuous (24pt for icons)
- [ ] Hover effects work smoothly
- [ ] Transitions animate with spring (0.3s, 0.7 damping)

### Data Persistence
- [ ] Create config, quit app, relaunch - config persists
- [ ] Edit name, quit app, relaunch - name persists
- [ ] Add apps, quit app, relaunch - apps persist
- [ ] Change color, quit app, relaunch - color persists
- [ ] Check `~/Library/Preferences/com.docktile.configs.json` file exists

### Context Menu
- [ ] Right-click Dock icon shows menu
- [ ] "Configure..." option works
- [ ] App list shows added apps
- [ ] Clicking app from menu launches it

---

## Debugging Tips

### View Console Logs
```bash
# Real-time logs
log stream --predicate 'process == "DockTile"' --level debug

# Or view in Console.app
open -a Console
# Filter for "DockTile"
```

**Expected logs on launch:**
```
🚀 DockTile launching...
   Bundle ID: com.docktile (or similar)
   Is Helper: false
✓ Main app configured (normal mode)
✓ DockTile ready
📦 ConfigurationManager initialized
   Storage: /Users/.../Library/Preferences/com.docktile.configs.json
   Loaded 0 configuration(s)
```

### Check if App is Running
```bash
ps aux | grep -i docktile | grep -v grep
```

### Kill the App
```bash
killall DockTile
```

### View Build Location
```bash
ls -la ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Debug/
```

### Check Configuration File
```bash
# View saved configurations
cat ~/Library/Preferences/com.docktile.configs.json | python3 -m json.tool

# Delete configurations (reset)
rm ~/Library/Preferences/com.docktile.configs.json
```

---

## Troubleshooting

### "App quit unexpectedly"
- Check Console.app for crash logs
- Verify all new files are added to Xcode target
- Rebuild: `xcodebuild clean build`
- Ensure Swift 6 concurrency settings are correct

### "Configuration window doesn't appear"
- Verify Info.plist has `LSUIElement = false`
- Check bundle identifier is "com.docktile" (not a helper)
- View logs for "Is Helper: false" message
- Try: `defaults delete com.docktile` and relaunch

### "Can't add files to Xcode project"
1. In Xcode, right-click DockTile group
2. Select "Add Files to DockTile..."
3. Navigate to Models/, Managers/, Views/, Components/, Extensions/
4. Select all new .swift files
5. Ensure "DockTile" target is checked
6. Click "Add"

### "Build fails with missing symbols"
- All new files must be in the same target
- Check Build Phases → Compile Sources includes all .swift files
- Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)

### "Color picker doesn't show colors"
- Verify ColorExtensions.swift is compiled
- Check ConfigurationModels.swift defines TintColor.colorTop/colorBottom
- Rebuild project

### "Character Viewer doesn't open"
- `NSApp.orderFrontCharacterPalette(nil)` requires user interaction
- Check button action is connected
- Try System Settings → Keyboard → Enable emoji/symbols viewer

---

## What's NOT Working Yet

These features are pending completion:

- ⏳ **Icon Generation**: Cannot generate .icns files yet
- ⏳ **Helper Bundle Generation**: Cannot create DockTile-Dev.app yet
- ⏳ **LauncherView Integration**: Still uses placeholder apps (not reading from ConfigurationManager)
- ⏳ **Multi-Instance**: Cannot test multiple dock tiles yet

---

## Next Steps After Running

Once you verify the app launches successfully:

1. **Test all Screen 3 functionality**
   - Create/edit/delete configurations
   - Add/remove apps
   - Change layouts

2. **Test Screen 4 drill-down**
   - Customize colors
   - Pick symbols
   - Verify live preview updates

3. **Verify data persistence**
   - Create config
   - Quit app
   - Relaunch
   - Check config still exists

4. **Ready for remaining phases**:
   - Phase 4: Icon generation
   - Phase 6: Helper bundle generator
   - LauncherView update to read from ConfigurationManager

---

**Current Status**: Awaiting Xcode project integration
**Last Updated**: 2026-01-26
**Build Status**: ⚠️ Pending (need to add new files)
**Architecture**: Single-app with multi-instance helper design
