# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.2] - 2026-09-21

Your existing tiles are rebuilt automatically the first time 2.0.2 launches, with one Dock restart,
so every fix below reaches them without any action from you.

### Changed

- **popover:** Open large tiles about a third faster and with consistent timing, by keeping app icons cached in the tile instead of asking macOS for them on every click ([5cd4aff](https://github.com/k97/dock-tile/commit/5cd4aff))
- **app:** Keep the main window responsive while a tile is being added or updated; icon compilation and code signing no longer freeze it for about a second per tile ([3274278](https://github.com/k97/dock-tile/commit/3274278))
- **settings:** Shrink the settings file from megabytes to kilobytes by no longer storing a copy of every app's icon; older files still load and slim down on their next save ([ea75c54](https://github.com/k97/dock-tile/commit/ea75c54))
- **window:** Fade a soft scrim in under the title band while scrolling, so content no longer collides with the pane title ([d770f77](https://github.com/k97/dock-tile/commit/d770f77))

### Fixed

- **install:** Fix "Move to Applications" failing for every install from the disk image; the app is now copied into place, the disk image is ejected afterwards, and an already-installed copy is reused instead of trashed ([49f82b6](https://github.com/k97/dock-tile/commit/49f82b6))
- **popover:** Fix a tile's memory growing by 3–5 MB on every click and never coming back, caused by a macOS 26 Liquid Glass leak that Dock Tile triggered by creating a new popover each time ([962bf44](https://github.com/k97/dock-tile/commit/962bf44))
- **dock:** Fix the app no longer noticing a tile dragged out of the Dock after the first Dock change of a session, which left the tile marked visible with nothing pinned ([e3c491e](https://github.com/k97/dock-tile/commit/e3c491e))
- **popover:** Fix the Animation "None" setting and the system Reduce Motion preference being ignored when a popover appears ([6dcc142](https://github.com/k97/dock-tile/commit/6dcc142))
- **popover:** Fix a click listener being left running after a popover closed by clicking elsewhere, which woke the tile on every click anywhere on the Mac ([6dcc142](https://github.com/k97/dock-tile/commit/6dcc142))
- **popover:** Fix app icons staying in the old appearance after changing macOS's "Icon and widget style" while a tile is running ([6ba1d46](https://github.com/k97/dock-tile/commit/6ba1d46))
- **tiles:** Fix a tile being corrupted if Update was pressed while the app was rebuilding that tile in the background ([eaa93c6](https://github.com/k97/dock-tile/commit/eaa93c6))
- **dock:** Fix hiding a tile during a background rebuild marking it hidden while it stayed in the Dock; the action now reports that the tile is busy ([a635f3a](https://github.com/k97/dock-tile/commit/a635f3a))
- **customise:** Fix dragging in the colour picker queuing a full settings save for every movement, which made the drag stutter ([d203c1e](https://github.com/k97/dock-tile/commit/d203c1e))
- **customise:** Fix Customise overwriting a tile's Dock visibility with the value from when the editor was opened ([eaa93c6](https://github.com/k97/dock-tile/commit/eaa93c6))
- **diagnostics:** Fix multi-line entries in Copy Diagnostics surviving the one-hour trim forever ([1e5a6a9](https://github.com/k97/dock-tile/commit/1e5a6a9))

[Unreleased]: https://github.com/k97/dock-tile/compare/v2.0.2...HEAD
[2.0.2]: https://github.com/k97/dock-tile/compare/v2.0.1...v2.0.2
