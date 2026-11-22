# Show in Menu Bar always visible — plan (2.8.1)

Plan gate (fresh reviewer, 2026-11-22): **Ready to build**; findings 1–7 folded in below.

Owner, 2026-11-22: "show the Show in Menu Bar option as turned off [when the global setting is off]; anyone
turning it on also turns on Settings › General › Menu Bar." Recommendation accepted: turning one tile on
brings back every tile whose saved Show in Menu Bar is on (the menu as it was before the icon went off).

## Behaviour

- Tile Detail always shows **Show in Menu Bar** (4-row card; hero always 163 pt).
- It reads ON only when the setting is on AND the tile's `showInMenuBar` is true.
- Turning it ON sets `showInMenuBar = true` and, if the setting is off, turns the setting on through
  the same path General uses. Turning it OFF clears only the tile; never the setting.
- General's toggle, the turn-off alert, new-tile seeding, decode default: unchanged.
- **Consequence the owner accepts:** a tile switch can turn the setting on for an upgrader (seeded OFF).
  From then on Dock Tile stays running with its window closed, starts quietly at login and installs
  updates while idle — the existing menu bar behaviour, reached from a new place.
- The hero is 163 pt for everyone now (the 4-row card), including users with the setting off.

## Root problem to fix first

The icon's side effects live in `GeneralSettingsView`'s `.onChange(of: menuBarEnabled)` (apply the status
item, `.regular` on off, `setting_changed`, diagnostics line). That handler runs only while General is on
screen, so a write from Tile Detail would flip the key and leave no icon.

## Tasks

1. **One writer.** `MenuBarController.setEnabled(_ enabled: Bool, from: String)` (`@MainActor`): writes
   `UserDefaults.standard` `menuBarEnabled`, `apply(enabled:)`, `.regular` when off, logs
   `setting_changed {setting: menu_bar, enabled}` (no new GA4 param) and a diagnostics line naming `from`
   (`general` / `tile`). General's binding and its Turn Off button call it; its `.onChange` is deleted.
   Every `@AppStorage(menuBarEnabled)` reader refreshes from the defaults write. **One exception stays a
   direct write:** first-launch seeding in `AppDelegate.configureAsMainApp` (it calls `apply` itself and
   must not log a `setting_changed` on every first launch).
2. **Tile Detail switch.** Drop `if menuBarEnabled`. Binding: get = pure seam
   `menuBarSwitchIsOn(showInMenuBar:settingOn:)`; set = `session.config.showInMenuBar = v`, then
   `if v && !menuBarEnabled { MenuBarController.shared.setEnabled(true, from: "tile") }`. Hero:
   `heroIconSize(rows: 4)` always (the `menuBarEnabled` branch goes). Save order: the tile flag autosaves
   after 300 ms (⌘Q flushes it), the setting writes at once — only a Force Quit inside 300 ms loses the
   tile flag (icon on, that tile missing, its switch reads off); accepted.
3. **Tests.** `TileDetailMenuBarTests.switchReadsOnOnlyWithTheSetting` (4 cases of the read seam) and
   `switchOnTurnsTheSettingOn` for a second seam `menuBarSwitchEnablesSetting(newValue:settingOn:)`
   (ON while off → true; ON while on, OFF either way → false). The call into the controller is wiring,
   covered by hands-on.
4. **Rules/spec/changelog/comments.** menu-bar.md (switch always shown; one writer + the seeding
   exception; tile turns the setting on), architecture.md hero line (always 163 pt), BOTH spec bullets
   that say the switch hides, and the old words in code comments (`DockTileDetailView.swift:45`,
   `:489-490`, `:559`; General's menuBarRow doc comment). CHANGELOG 2.8.1 + notes (mention the hero).
5. **Verify.** Full suite on Default style, l10n check (no string changes expected), signed rebuild,
   relaunch, owner hands-on: General ON then OFF with General on screen (dev log `Status item added`,
   `Menu bar icon toggled ON (from general)`; icon goes on OFF, Dock icon stays); close the window with
   it on → Dock icon hides; setting off → switch visible and off on every tile; turn one on → icon
   appears, General shows on, previously-saved tiles reappear; window close → Dock icon hides as today.
   Then `stage-gate --dev`, branch CI both legs, release 2.8.1 on owner go.

## Non-goals

A new GA4 param for the source; clearing saved flags while the setting is off; changing General's copy.

## Review focus

- General toggle ON/OFF still applies the icon and Dock-icon policy with General on screen (the moved path).
- Turning a tile on with the window open: the Dock icon stays until the window closes (windowWillClose).
- A tile switched OFF while the setting is off: stays off, setting untouched.
