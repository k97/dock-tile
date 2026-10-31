# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.6.3] - 2026-10-31

### Added

- **tiles:** Show progress on a tile while Dock Tile updates it: the tile darkens and a bar fills along its bottom, and clicks on it are ignored until it is done. It appears from the first update after 2.6.3, because the tiles this update replaces were built before it existed ([a829ebf](https://github.com/k97/dock-tile/commit/a829ebf), [9e78441](https://github.com/k97/dock-tile/commit/9e78441))

### Changed

- **tiles:** While its progress bar shows, a tile hidden from ⌘Tab appears there for those few seconds and its Dock right-click menu offers Quit, which closes only that tile ([9e78441](https://github.com/k97/dock-tile/commit/9e78441))

### Fixed

- **tiles:** Keep a tile working while Dock Tile updates it. The new version is built beside the old one and swapped in only once it is complete, so a tile no longer goes unresponsive mid-update, and choosing Force Quit on it can no longer quit Dock Tile itself ([f7ccd92](https://github.com/k97/dock-tile/commit/f7ccd92), [dcd6c81](https://github.com/k97/dock-tile/commit/dcd6c81))
- **tiles:** Leave the old tile exactly as it was, still working, when an update of it fails ([f7ccd92](https://github.com/k97/dock-tile/commit/f7ccd92), [487c775](https://github.com/k97/dock-tile/commit/487c775))

## [2.6.2] - 2026-10-30

### Changed

- **dock:** Say so ("The Dock didn't keep this change. Try again.") when the Dock does not keep a change, instead of failing silently
- **dock:** Restart the Dock in a way that cannot lose Dock Tile's changes. One side effect: Dock icons rearranged in the second before pressing Update may not be kept

### Fixed

- **tiles:** Fix renaming a tile and pressing Update leaving a broken tile in the Dock that points at its old name
- **dock:** Fix Dock changes made a few seconds after another Dock restart (for example just after launch or an update) being undone by the Dock
- **tiles:** Repair tiles left broken in the Dock by an earlier version the next time Dock Tile opens
- **tiles:** Fix a tile being briefly marked hidden while it is added or updated
- **dock:** Start the Dock again if it does not come back after Dock Tile restarts it
- **migration:** Fix reopening the Dock Tile window during a tile update starting a second round of updates

## [2.6.1] - 2026-10-28

No changes to the app itself.

### Security

- **release:** Sign every update in a protected release pipeline, and check its update signature against the key installed copies trust before it is published ([1f31912](https://github.com/k97/dock-tile/commit/1f31912), [04df39f](https://github.com/k97/dock-tile/commit/04df39f))

## [2.6.0] - 2026-10-28

### Added

- **app-grid:** Choose a background for each App Grid tile — Follow System, Dark Grey, Light or a custom colour — in Customise Tile. The custom colour shows in the Dock as the colour you pick. Contributed by 3ueg ([#32](https://github.com/k97/dock-tile/pull/32), [1b16382](https://github.com/k97/dock-tile/commit/1b16382), [faf56a6](https://github.com/k97/dock-tile/commit/faf56a6), [0e34515](https://github.com/k97/dock-tile/commit/0e34515))

## [2.5.1] - 2026-10-23

### Changed

- **configure:** Open Customise Tile when you press a tile's Configure button in its Dock popover or choose Configure… from its Dock menu, so you land ready to edit that tile ([0e7d61d](https://github.com/k97/dock-tile/commit/0e7d61d))

### Fixed

- **configure:** Fix a tile's Configure button leaving Dock Tile on a Settings pane instead of showing that tile ([#31](https://github.com/k97/dock-tile/issues/31), [0e7d61d](https://github.com/k97/dock-tile/commit/0e7d61d))
- **tiles:** Fix the last change to a tile being lost when you quit Dock Tile straight after making it ([#30](https://github.com/k97/dock-tile/issues/30), [9913e3b](https://github.com/k97/dock-tile/commit/9913e3b))

## [2.5.0] - 2026-10-22

Customise Tile now opens beside Tile Detail instead of replacing it, so every change shows on the
tile as you make it.

### Added

- **customise:** Open Customise Tile as an inspector beside Tile Detail, on the same glass as the sidebar, as in Xcode. Toggle it from the toolbar, by clicking the tile's icon, or with View › Show Inspector (⌥⌘I) ([afb06dc](https://github.com/k97/dock-tile/commit/afb06dc), [8c8e624](https://github.com/k97/dock-tile/commit/8c8e624), [216f3f0](https://github.com/k97/dock-tile/commit/216f3f0), [0625114](https://github.com/k97/dock-tile/commit/0625114))
- **smart-add:** Offer one App Grid, one Symbol and one Emoji tile among the Add a Tile suggestions, in a random order each time ([69dda28](https://github.com/k97/dock-tile/commit/69dda28))
- **tiles:** Start each new blank tile on a random symbol and a random emoji instead of the same ones every time ([f1755a1](https://github.com/k97/dock-tile/commit/f1755a1))

### Changed

- **app-grid:** Place a single app in the top-left cell of a 2 × 2 grid, like two to four apps, instead of filling the tile ([fdbacdd](https://github.com/k97/dock-tile/commit/fdbacdd))
- **app-grid:** Show an empty 2 × 2 grid on an App Grid tile with no apps, in the app and in the Dock, instead of the tile's symbol ([0204d55](https://github.com/k97/dock-tile/commit/0204d55))
- **tile-detail:** Highlight Update only while the Dock icon is behind your edits ([076dba0](https://github.com/k97/dock-tile/commit/076dba0))
- **ui:** Give tile icons throughout the app a subtle App Store-style edge and shadow ([001d3ab](https://github.com/k97/dock-tile/commit/001d3ab), [f9c5f02](https://github.com/k97/dock-tile/commit/f9c5f02))
- **customise:** Use the system search field for symbols and emoji, and remove the Icon Weight info button ([0625114](https://github.com/k97/dock-tile/commit/0625114), [8dcf7ca](https://github.com/k97/dock-tile/commit/8dcf7ca))
- **popover:** Run the Popover settings preview edge to edge, and show Save in grey while there is nothing to save ([65fc1eb](https://github.com/k97/dock-tile/commit/65fc1eb))
- **window:** Let the main window narrow to 700 points, or 960 with Customise Tile open ([b1140c5](https://github.com/k97/dock-tile/commit/b1140c5))
- **performance:** Switch between tiles and Settings panes without the inspector animating closed and open, and read the login item status off the main thread ([d514d27](https://github.com/k97/dock-tile/commit/d514d27))

## [2.4.0] - 2026-10-19

Existing tiles keep their symbol or emoji. App Grid is the starting look for new tiles, and any
tile can switch to it in Customise Tile.

### Added

- **tiles:** Add the App Grid tile face: the Dock icon shows the tile's own apps in a folder-style grid on the system glass, like an iOS folder. One app fills the tile, two to four sit in a 2 × 2 grid, and five or more in a 3 × 3 grid of the first nine installed apps ([1473405](https://github.com/k97/dock-tile/commit/1473405))
- **tiles:** Show each app in an App Grid tile the way macOS draws that app in the current icon style (Default, Dark, Clear or Tinted), instead of its colour icon in every style ([bc53fb7](https://github.com/k97/dock-tile/commit/bc53fb7))
- **customise:** Redesign Customise Tile as a large preview beside an inspector, with an App Grid / Symbol / Emoji style picker whose options follow the chosen style ([be80f55](https://github.com/k97/dock-tile/commit/be80f55))
- **customise:** Keep the Symbol and Emoji styles' settings separate: each remembers its own symbol or emoji, icon size, Colour or Mono background and colour, so switching between them no longer resets your choices ([fa7b988](https://github.com/k97/dock-tile/commit/fa7b988))
- **window:** Make the main window resizable between 782 and 1200 points wide ([1452c9c](https://github.com/k97/dock-tile/commit/1452c9c))

### Fixed

- **tiles:** Fix tiles in the sidebar and on Tile Detail looking different from the Dock under the Clear icon style; they now show the Dock's own rendering once the tile is updated ([bc53fb7](https://github.com/k97/dock-tile/commit/bc53fb7))
- **icons:** Fix an app installed as a link, such as Safari on macOS 27, drawing its icon with an alias arrow ([cabb11b](https://github.com/k97/dock-tile/commit/cabb11b))
- **login:** Fix the app carrying the development build's login item alongside its own; each build now ships only its own ([ee67b4c](https://github.com/k97/dock-tile/commit/ee67b4c))
- **localization:** Fix the wording of the Japanese Smart Add banner and the Russian Dock Lock note ([ee67b4c](https://github.com/k97/dock-tile/commit/ee67b4c))

## [2.3.1] - 2026-10-18

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.3.1).

## [2.3.0] - 2026-10-18

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.3.0).

## [2.2.2] - 2026-10-17

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.2.2).

## [2.2.1] - 2026-10-17

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.2.1).

## [2.2.0] - 2026-10-14

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.2.0).

## [2.1.0] - 2026-10-13

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.1.0).

## [2.0.3] - 2026-10-03

See the [GitHub release](https://github.com/k97/dock-tile/releases/tag/v2.0.3).

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

[Unreleased]: https://github.com/k97/dock-tile/compare/v2.6.3...HEAD
[2.6.3]: https://github.com/k97/dock-tile/compare/v2.6.2...v2.6.3
[2.6.2]: https://github.com/k97/dock-tile/compare/v2.6.1...v2.6.2
[2.6.1]: https://github.com/k97/dock-tile/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/k97/dock-tile/compare/v2.5.1...v2.6.0
[2.5.1]: https://github.com/k97/dock-tile/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/k97/dock-tile/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/k97/dock-tile/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/k97/dock-tile/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/k97/dock-tile/compare/v2.2.2...v2.3.0
[2.2.2]: https://github.com/k97/dock-tile/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/k97/dock-tile/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/k97/dock-tile/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/k97/dock-tile/compare/v2.0.3...v2.1.0
[2.0.3]: https://github.com/k97/dock-tile/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/k97/dock-tile/compare/v2.0.1...v2.0.2
