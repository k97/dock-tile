# Dock Tile v1.0.0

> Create custom app launcher tiles for your macOS Dock

**Dock Tile** is a lightweight macOS utility that lets you create multiple custom tiles in your Dock, each containing a curated set of apps. Think of it as customizable Dock folders with instant access.

---

## Features

### Multi-Tile Architecture
- Create unlimited independent tiles, each with its own app collection
- Tiles persist across restarts and stay exactly where you place them in the Dock
- Each tile maintains separate configuration and visual identity

### Custom Icons
- **8 preset gradient colors** - Blue, Purple, Pink, Red, Orange, Yellow, Green, Gray
- **Custom colors** - Pick any color with the system color picker
- **SF Symbols** - 2,400+ system icons organized by category
- **Emoji support** - Full emoji picker with search
- **Adjustable icon size** - Fine-tune icon scale (10-20 range)
- **macOS Tahoe native design** - Squircle shape with beveled glass effect

### Flexible Layouts
- **Grid view** - Dynamic columns (2-7) based on app count
- **List view** - Menu-style vertical list

### Native Experience
- **Dock-anchored popover** - Appears flush against Dock edge
- **Native vibrancy** - Uses `NSVisualEffectView` for authentic macOS look
- **<100ms popover appearance** - Instant response on click
- **Keyboard navigation** - Arrow keys + Enter when in App Switcher mode

### macOS Integration
- **App Switcher toggle** - Choose Ghost Mode (hidden from Cmd+Tab) or App Mode (visible with context menu)
- **Icon style support** - Automatically adapts to Default, Dark, Clear, and Tinted icon modes
- **Dock position preservation** - Tiles maintain position when toggled on/off

---

## Installation

1. Download `DockTile-1.0.0.dmg`
2. Open the DMG and drag **Dock Tile** to Applications
3. Launch Dock Tile from Applications
4. Click **+** to create your first tile

---

## System Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

---

## Verification

Verify the download integrity:

```bash
shasum -a 256 -c DockTile-1.0.0.dmg.sha256
```

---

## What's Next

See the [roadmap](https://github.com/user/dock-tile#roadmap) for planned features including:
- Onboarding flow
- Localization (UK/AU English)

---

## Feedback

Found a bug or have a feature request? [Open an issue](https://github.com/user/dock-tile/issues/new).

---

Built with Swift 6 and SwiftUI for macOS Tahoe.
