# Dock Tile

A native macOS utility that lets you create custom Dock tiles to organise and launch your favourite apps & folders with a single click.

![macOS 15.0+](https://img.shields.io/badge/macOS-15.0+-blue.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Overview

DockTile brings the power of custom app launchers to your macOS Dock. Create multiple tiles, each with its own curated list of apps, custom icon, and colour scheme. Click a tile to reveal a beautiful popover with your apps & folders ready to launch.

Think of it as customizable iOS folders for macOS, but better - with native vibrancy effects, SF Symbols, emoji icons, and the polish you'd expect from a first-party macOS app.

## Features

- **Multiple Tiles** - Create as many dock tiles as you need, each completely independent
- **Custom Icons** - Choose from hundreds of SF Symbols or use any emoji as your tile icon
- **Colour Themes** - Pick from 8 preset gradient colours or create your own custom colour
- **Flexible Layouts** - Display apps in a 2x3 grid or horizontal list
- **Native Experience** - Built with SwiftUI and AppKit for an authentic macOS look and feel
- **Dock Integration** - Tiles appear in the Dock just like regular apps
- **App Switcher Support** - Optionally show tiles in Cmd+Tab
- **Folders Support** - Add folders alongside apps for quick access

## Screenshots

*Coming soon*

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dock-tile.git
   cd dock-tile
   ```

2. Build the project:
   ```bash
   xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Release build
   ```

3. Copy the built app to Applications:
   ```bash
   cp -r ~/Library/Developer/Xcode/DerivedData/DockTile-*/Build/Products/Release/DockTile.app /Applications/
   ```

### From Releases

Download the latest `.dmg` from the [Releases](https://github.com/yourusername/dock-tile/releases) page.

## Getting Started

1. **Launch DockTile** - Open the app from your Applications folder
2. **Create a Tile** - Click the "+" button in the sidebar to create a new tile
3. **Customise** - Click "Customise" to choose an icon and color
4. **Add Apps** - Click "+" in the Selected Items section to add apps or folders
5. **Enable** - Toggle "Show Tile" on and click "Done" to add it to your Dock
6. **Use It** - Click your new tile in the Dock to see your apps!

## How It Works

DockTile creates lightweight helper applications for each tile you configure. These helpers:

- Live in `~/Library/Application Support/DockTile/`
- Share configuration via `~/Library/Preferences/com.docktile.configs.json`
- Appear as independent apps in the Dock
- Show a native popover when clicked

This architecture allows each tile to function independently while being managed from a single configuration app.

## Configuration

### Tile Settings

| Setting | Description |
|---------|-------------|
| Tile Name | Display name shown below the Dock icon |
| Show Tile | Toggle visibility in the Dock |
| Layout | Choose between Grid (2x3) or List view |
| Show in App Switcher | Include tile in Cmd+Tab switcher |

### Icon Customisation

- **SF Symbols** - Browse categorised system symbols (General, Development, Media, etc.)
- **Emoji** - Pick from emoji categories (Smileys, Animals, Food, etc.)
- **Colours** - 8 preset gradients or custom hex colour

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Click tile | Open popover |
| Arrow keys | Navigate apps in popover |
| Return | Launch selected app |
| Escape | Close popover |
| Cmd+Tab | Switch to tile (if enabled) |

## Architecture

```
DockTile.app (Main Configuration App)
    │
    ├── Creates and manages tile configurations
    ├── Generates helper app bundles
    └── Provides customisation UI

~/Library/Application Support/DockTile/
    │
    ├── My Tile.app (Helper Bundle 1)
    ├── Dev Tools.app (Helper Bundle 2)
    └── ... (Additional tiles)
```

## Technical Details

- **UI Framework**: SwiftUI + AppKit hybrid for native Dock integration
- **Concurrency**: Swift 6 strict concurrency
- **Popover**: NSPopover with NSVisualEffectView for native vibrancy
- **Icons**: Generated .icns files with gradient backgrounds
- **Persistence**: JSON configuration with automatic Dock plist management

## Troubleshooting

### Tile doesn't appear in the Dock
1. Ensure "Show Tile" is toggled on
2. Click "Done" to apply changes
3. Try toggling "Show Tile" off and on again

### Popover appears in the wrong position
The popover anchors to the Dock edge. If your Dock is on the bottom, left, or right of the screen, the popover will adjust automatically.

### Apps not launching
Ensure the apps remain installed in their original locations. Remove and re-add apps if they've been moved.

## Development

### Building

```bash
# Debug build
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build

# Run tests
xcodebuild test -project DockTile.xcodeproj -scheme DockTile

# Clean
xcodebuild -project DockTile.xcodeproj -scheme DockTile clean
```

### Project Structure

```
DockTile/
├── App/           # Entry points and app delegates
├── Managers/      # Configuration, helper bundles, Dock watching
├── Models/        # Data models and schema
├── UI/            # Popover and launcher views
├── Views/         # Main configuration views
├── Components/    # Reusable UI components
├── Utilities/     # Icon generation
└── Extensions/    # Swift extensions
```

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request



## Acknowledgments

- Built with SwiftUI and AppKit
- Icons powered by SF Symbols
- Inspired by the native macOS Dock experience

---

Made with care for macOS
