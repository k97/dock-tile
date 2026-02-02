# DockTile FAQ

Answers to common questions about DockTile, how it works, and why certain things are the way they are.

---

## General

### What is DockTile?

DockTile is a macOS utility that lets you create custom app launchers in your Dock. Think of it like creating your own "folders" in the Dock, but with custom icons and instant access to your favourite apps.

### How does it work?

When you create a tile in DockTile, it generates a small helper app that lives in your Dock. Click the tile to see your apps in a nice popover, then click any app to launch it. It's that simple.

### Is DockTile free?

DockTile is currently in development. Pricing and distribution details will be announced closer to launch.

### What version of macOS do I need?

DockTile requires **macOS 15.0 (Tahoe)** or later.

---

## Tiles & Configuration

### Why do I need to click "Update" after changing settings?

Each tile is actually a small standalone app. When you change settings like the icon, name, or the "Show in App Switcher" option, DockTile needs to regenerate that app with the new configuration. Think of it like saving your changes - the Update button applies them to the actual tile in your Dock.

### Why does the Dock restart when I add or update a tile?

The macOS Dock maintains its own list of apps. To add, remove, or update a tile, DockTile needs to modify this list and then restart the Dock for changes to take effect. This is the standard way apps integrate with the Dock - there's no way around it. The restart is quick (usually under a second) and your other Dock items aren't affected.

### Can I have multiple tiles?

Yes! Create as many tiles as you like. Each one is independent with its own icon, colour, and list of apps. For example, you might have a "Work" tile, a "Creative" tile, and a "Games" tile.

### How do I reorder apps within a tile?

In the DockTile configuration window, you can drag apps up and down in the list using the grip handle on the left side of each row. The order you set here is the order they'll appear in the popover.

### How do I remove an app from a tile?

Select the app(s) you want to remove in the list, then click the minus (-) button at the bottom. You can select multiple apps using Cmd+Click (toggle selection) or Shift+Click (range selection).

### Where can I move my tile in the Dock?

Just drag it! Once a tile is in your Dock, you can drag it left or right to reposition it, just like any other Dock icon. DockTile will remember its position when you update the tile.

---

## The "Show in App Switcher" Toggle

### What does "Show in App Switcher" do?

This toggle controls whether your tile appears in the Cmd+Tab app switcher:

- **OFF (default)**: Your tile is hidden from Cmd+Tab, keeping your app switcher clean
- **ON**: Your tile appears in Cmd+Tab, and you get a right-click context menu

### Why can't I right-click my tile to see a context menu?

If "Show in App Switcher" is turned OFF, right-click menus won't work on your tile. This is a macOS limitation, not a bug.

Here's the technical reason: macOS treats apps differently based on whether they appear in Cmd+Tab. Apps hidden from Cmd+Tab are considered "background utilities" and don't get right-click Dock menus. We can't change this behaviour - it's built into macOS.

**The good news**: You have a choice! If you want the right-click "Configure..." menu, just turn ON "Show in App Switcher" and click Update.

### Why can't I have both - hidden from Cmd+Tab AND a right-click menu?

We wish we could offer this, but macOS doesn't allow it. Apple's system links these two features together:

| Setting | Cmd+Tab | Right-click Menu |
|---------|---------|------------------|
| Show in App Switcher: OFF | Hidden | No menu |
| Show in App Switcher: ON | Visible | Menu works |

We've designed DockTile to give you the choice of which trade-off you prefer. Most users prefer hiding from Cmd+Tab (the default), but power users who want the context menu can enable it.

### If I enable "Show in App Switcher", what appears in Cmd+Tab?

Your tile appears as a regular app with its custom icon. When you Cmd+Tab to it, the popover opens automatically with keyboard navigation enabled - you can use arrow keys to select an app and Enter to launch it.

---

## Icons & Appearance

### Why does my tile icon look different sometimes?

macOS Tahoe introduced a new "Icon and widget style" setting (separate from Light/Dark mode). DockTile respects this setting and automatically adjusts your tile icons to match:

- **Default**: Your chosen colour with a white symbol
- **Dark**: Dark background with your colour as the symbol
- **Clear**: Light gray background (system applies tinting)
- **Tinted**: Medium gray background (system applies accent colour)

You can find this setting in **System Settings → Appearance → Icon and widget style**.

### Can I use any emoji or SF Symbol for my tile?

Yes! DockTile supports:
- **SF Symbols**: Apple's library of thousands of icons (search by name like "folder", "star", "gear")
- **Emojis**: Any emoji from your keyboard

### Why is there a size limit on my icon?

We cap the icon size to stay within Apple's icon safe area guidelines. This ensures your tile icons look consistent with other apps in your Dock and don't get clipped or look out of place.

### My tile icon looks larger/smaller than other Dock icons - why?

If you notice size differences, try clicking "Update" on your tile. We've carefully matched Apple's icon specifications, but sometimes macOS needs a refresh to display icons correctly.

---

## Storage & Data

### Where are my tiles stored?

Tile apps are stored in:
```
~/Library/Application Support/DockTile/
```

Your configuration (all your tile settings) is stored in:
```
~/Library/Preferences/com.docktile.configs.json
```

### Can I backup my tiles?

Yes! To backup your DockTile setup:

1. Copy the folder: `~/Library/Application Support/DockTile/`
2. Copy the config file: `~/Library/Preferences/com.docktile.configs.json`

To restore, put these files back in the same locations and restart DockTile.

### How do I remove a single tile?

1. Open DockTile
2. Select the tile in the sidebar
3. Scroll down to "Remove from Dock" section
4. Click "Remove"

This removes the tile from your Dock and deletes its helper app. Your configuration for other tiles is not affected.

### How do I completely uninstall DockTile?

To fully remove DockTile and all tiles:

1. **Quit all tiles**: Right-click each tile in the Dock → Quit (or use Activity Monitor)
2. **Delete the main app**: Move DockTile.app to Trash
3. **Delete tile apps**: Remove `~/Library/Application Support/DockTile/`
4. **Delete config**: Remove `~/Library/Preferences/com.docktile.configs.json`
5. **Empty Trash** and restart your Mac (optional but recommended)

---

## Troubleshooting

### My tile isn't responding to clicks

Try these steps:
1. **Restart the tile**: Right-click the tile → Quit, then click it again to relaunch
2. **Update the tile**: Open DockTile, select the tile, click "Update"
3. **Check if it's running**: Look in Activity Monitor for your tile's name

### My tile disappeared from the Dock

If you manually removed a tile from the Dock (by dragging it out), DockTile will detect this and update its configuration. To add it back:
1. Open DockTile
2. Select the tile
3. Turn ON "Show Tile"
4. Click "Add to Dock"

### The popover appears in the wrong position

The popover anchors to your Dock's edge. If your Dock is at the bottom, the popover appears above it. If your Dock is on the left or right, the popover adjusts accordingly. This should happen automatically - if it's not working correctly, try updating the tile.

### Icons look blurry or wrong

1. Click "Update" on the affected tile to regenerate its icon
2. If that doesn't help, try changing the icon style in System Settings → Appearance
3. As a last resort, delete the tile and recreate it

---

## App Store & Distribution

### Is DockTile on the Mac App Store?

No, and it can't be. Here's why:

App Store apps must run in a "sandbox" - a restricted environment that limits what they can do. DockTile needs to:
- Create helper apps (the tiles themselves)
- Add items to your Dock
- Read and modify Dock preferences

None of these are allowed in the sandbox. This isn't a limitation we can work around - it's fundamental to how DockTile works.

### Is DockTile safe to use?

Yes! DockTile:
- **Doesn't access the internet** - no tracking, no analytics, no data collection
- **Only modifies Dock preferences** - it doesn't touch your other apps or system files
- **Is code-signed** - macOS verifies the app hasn't been tampered with
- **Stores data locally** - your configuration never leaves your Mac

### Where can I download DockTile?

DockTile will be available for direct download from our website. Details coming soon!

---

## Technical Details

### Why are tiles separate apps instead of just Dock shortcuts?

Great question! macOS Dock "shortcuts" (like document aliases) don't support:
- Custom click behaviour (showing a popover)
- Dynamic content (your app list)
- Custom icons that respect system appearance settings

By creating small helper apps, we get full control over the experience while still integrating naturally with your Dock.

### Does DockTile use a lot of resources?

No. Each tile is a minimal app that:
- Uses virtually no CPU when idle
- Uses only a few MB of memory
- Has no background processes or timers (except for icon style changes)
- Doesn't access the network

### Can tiles auto-launch when I log in?

The tiles themselves will relaunch automatically because they're in your Dock (macOS handles this). You don't need to add them to Login Items.

However, if you quit a tile manually, it won't relaunch until you click it in the Dock.

---

## Feature Requests

### Can you add [feature X]?

We'd love to hear your ideas! DockTile is actively developed and we're always looking to improve. Reach out via [contact method TBD].

### Why doesn't DockTile do [thing that other app does]?

We've designed DockTile to do one thing really well: give you custom app launchers in your Dock. We intentionally keep it focused and lightweight rather than adding features that would bloat the app or slow it down.

That said, we're always open to suggestions that fit our vision!

---

*Last updated: February 2026*
