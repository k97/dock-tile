# Tiles in the menu bar — design

2026-11-21 · owner decisions from the design conversation; mockup canvas
"Tiles in the menu bar" (private artifact), board "Main window — Media set to Menu Bar".

## Intent

Some tiles (e.g. Media) are wanted in the menu bar rather than the Dock. A tile can be in the Dock,
in the menu bar, both, or neither. Dock Tile must not add noise to an already crowded menu bar
(owner: "it's a design choice … not how the Dock behaves, but for the menu bar let's go with this").

## Decisions

- **No new menu bar icons.** A menu bar tile appears inside Dock Tile's existing menu bar menu
  (`TileMenu`, issue #13), as the submenu of apps it already shows for Dock tiles. Each tile owning
  its own status item was considered and rejected for menu bar noise.
- **The per-tile switch is always shown (revised 2026-11-22, 2.8.1).** It reads off while Settings ›
  General › Menu Bar is off, and turning it on turns that setting on. (Shipped in 2.8.0 as "exists only
  while the setting is on".)
- **Two independent switches** in the Tile Detail card: **Show in Dock** (today's Show Tile, renamed)
  and **Show in Menu Bar**, then Show in App Switcher (still greyed unless the tile is in the Dock).
  Prior art: Apple's Control Center settings (macOS 11–12) — "Show in Menu Bar" / "Show in Control
  Center", one checkbox per place.
- **Menu bar menu lists exactly the tiles whose Show in Menu Bar is on**, in sidebar order (today it
  lists Dock-shown tiles). Dock Tile's own Dock menu is unchanged: Dock-shown tiles.
- **Turning the global setting off changes no tile.** Every switch reads off, each tile keeps its
  choice, and turning the setting back on (in General or from any tile) restores the menu as it was. If any tile is in the menu bar but not
  the Dock, turning it off first says so: "<Media> is only in the menu bar. It stays in Dock Tile but
  won't show anywhere until you turn this back on or add it to the Dock." (one alert, names up to 3).

## Behaviour

- `DockTileConfiguration.showInMenuBar: Bool` (schema bump). Missing key decodes to the tile's
  `isVisibleInDock`, so every existing tile's menu entry is exactly what 2.7.x shows. New tile
  (blank, Smart Add, duplicate's own default aside): the Menu Bar setting's value at creation (owner).
- The switch applies at once, through the normal autosave. It is NOT a Dock action: no Dock restart,
  no consent dialog, it never moves `dockSignature` (Update stays quiet), and Revert to Dock Version
  keeps it like bookkeeping (it's not something the Dock shows).
- A menu-only tile needs no helper: the menu is built in the main app from the config and launches
  through `AppLauncher`. Login keeps launching Dock-shown helpers only. Both menus read the live config
  today (`MenuBarController.menuNeedsUpdate`, `AppDelegate.applicationDockMenu`); unchanged here.
- A duplicate starts with Show in Menu Bar off, as it starts out of the Dock: a copy shows nowhere
  until the user picks (my call, matching `duplicate(named:)`'s Dock reset).
- Sidebar: Apple's `menubar.rectangle` symbol after a tile's name while the setting is on and the
  tile is in the menu bar (owner, 2026-11-21).
- (Superseded 2026-11-22: the hero is the card's height, 163 pt.) Hero icon stays 122 pt, top-aligned beside the card, whether the card has 3 rows or 4 (owner,
  2026-11-21: a 163 pt hero needs a 447 pt row, wider than the 420 pt narrowest detail column).
- Action button still driven by Show in Dock alone, with shorter labels (owner): **Add** (was Add to
  Dock), **Remove** (was Remove from Dock), Update and Done unchanged. Its tooltip and accessibility
  label keep the place ("Add to Dock", "Remove from Dock") so Remove is never mistaken for Delete.

## Non-goals

A tile's own menu bar icon; a popover from the menu bar; ordering menu bar tiles separately from
the sidebar; analytics for the per-tile switch (the global `menu_bar` setting event already exists).

## Left to the builder

String keys and translations; exact alert wording within the meaning above; test seams
(`TileMenu.menuTiles`, decode default, Revert bookkeeping, signature exclusion).
