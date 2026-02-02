# DockTile

A native macOS utility that lets you create custom Dock tiles to organise and launch your favourite apps with a single click.

![macOS 15.0+](https://img.shields.io/badge/macOS-15.0+-blue.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)

## Overview

DockTile brings the power of custom app launchers to your macOS Dock. Create multiple tiles, each with its own curated list of apps, custom icon, and colour scheme. Click a tile to reveal a beautiful popover with your apps ready to launch.

Think of it as customisable Dock folders - with native vibrancy effects, SF Symbols, emoji icons, and the polish you'd expect from a first-party macOS app.

## Features

- **Multiple Tiles** - Create as many dock tiles as you need, each completely independent
- **Custom Icons** - Choose from hundreds of SF Symbols or use any emoji as your tile icon
- **Colour Themes** - Pick from 8 preset gradient colours or create your own custom colour
- **Adjustable Icon Size** - Fine-tune the icon size with the built-in scale control
- **Flexible Layouts** - Display apps in a grid or list view
- **Native Experience** - Built with SwiftUI and AppKit for an authentic macOS look and feel
- **Dock Integration** - Tiles appear in the Dock just like regular apps
- **App Switcher Support** - Optionally show tiles in Cmd+Tab

## Screenshots

*Coming soon*

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/k97/dock-tile.git
   cd dock-tile
   ```

2. Open in Xcode and build, or use the command line:
   ```bash
   xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Release build
   ```

3. Copy the built app to Applications:
   ```bash
   cp -r ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Release/DockTile.app /Applications/
   ```

## Getting Started

1. **Launch DockTile** - Open the app from your Applications folder
2. **Create a Tile** - Click the "+" button in the sidebar to create a new tile
3. **Customise** - Click "Customise" to choose an icon and colour
4. **Add Apps** - Click "+" in the Selected Items section to add apps
5. **Add to Dock** - Click "Add to Dock" to pin the tile
6. **Use It** - Click your new tile in the Dock to see your apps!

## How It Works

DockTile creates lightweight helper applications for each tile you configure. These helpers appear as independent apps in the Dock and show a native popover when clicked.

## Tile Settings

| Setting | Description |
|---------|-------------|
| Tile Name | Display name shown below the Dock icon |
| Show Tile | Toggle visibility in the Dock |
| Layout | Choose between Grid or List view |
| Show in App Switcher | Include tile in Cmd+Tab |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Click tile | Open popover |
| Arrow keys | Navigate apps in popover |
| Return | Launch selected app |
| Escape | Close popover |

## Troubleshooting

### Tile doesn't appear in the Dock
1. Ensure "Show Tile" is toggled on
2. Click "Add to Dock" to apply changes
3. Try toggling "Show Tile" off and on again

### Icon not updating
If a tile's icon doesn't update after customisation, toggle "Show Tile" off and on to regenerate the helper bundle.

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

```bash
# Build
xcodebuild -project DockTile.xcodeproj -scheme DockTile build

# Clean
xcodebuild -project DockTile.xcodeproj -scheme DockTile clean
```

## Testing

Run the test suite to verify everything works:

```bash
# Run all unit tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -only-testing:DockTileTests

# Run with code coverage
xcodebuild test -project DockTile.xcodeproj -scheme DockTile \
  -destination 'platform=macOS' -enableCodeCoverage YES
```

Or in Xcode: Press **Cmd+U** to run all tests.

Tests are automatically run on every push via GitHub Actions CI.

---

Made with care for macOS
