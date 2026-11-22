# Menu Bar Tiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tile can be listed in Dock Tile's menu bar menu independently of the Dock, through a per-tile "Show in Menu Bar" switch that exists only while the Menu Bar setting is on.

**Architecture:** One new config field, `showInMenuBar` (schema v13), owned by the editor like any content field but kept out of everything the helper shows (`dockSignature`, `contentSignature`, Revert). `TileMenu` filters by place: the menu bar menu lists `showInMenuBar` tiles, Dock Tile's own Dock menu keeps listing `isVisibleInDock` tiles. No helper, Dock or login change.

**Tech Stack:** Swift 6, SwiftUI + AppKit, Swift Testing (`DockTileTests`, module `Dock_Tile`), String Catalog via `Scripts/l10n/l10n.py`.

**Spec:** `docs/superpowers/specs/2026-11-21-menu-bar-tiles-design.md`

## Global Constraints

- Work in a NEW worktree, mandatory (another session has uncommitted website edits here): `git worktree add ../dock-tile-menubar-tiles -b feature/menu-bar-tiles main`, copy `Vendor/actool/target/release/docktile-actool` in, and commit this plan and its spec there as the first commit.
- "Menu-only" (the turn-off alert) means the stored flags `showInMenuBar && !isVisibleInDock`; a never-added draft counts too (accepted: `isVisibleInDock` is intent, not proof of a pin).
- Old configs must load unchanged: a missing `showInMenuBar` key decodes to that tile's `isVisibleInDock` (development.md "Schema Evolution").
- `isVisibleInDock` ownership is untouched (architecture.md "Visibility ownership"); `showInMenuBar` saves through the normal autosave and is never written by `performDockAction` or `preservingStoredVisibility`.
- The switch never restarts the Dock, never shows the Dock-restart consent, never moves `dockSignature`.
- Every new or changed string goes through `AppStrings` + `l10n.py` (sync-keys → export → machine fill de/fr/ja/ru/zh-Hans → import → check). Apple's term for "menu bar" per language from the system loctables, as for "Dock" in `docs/l10n/GLOSSARY.md`.
- Strings, verbatim (en-GB source): `label.showTile` value **"Show in Dock"**; `label.showInMenuBar` **"Show in Menu Bar"**; `label.inMenuBar` **"In the menu bar"** (sidebar glyph accessibility); `label.appSwitcherNeedsShowTile` value **"Turn on Show in Dock first — this only applies while the tile is in the Dock."**; `settings.menuBar.toggleDescription` value **"Lists the tiles you choose and their apps. Turn on Show in Menu Bar in a tile to add it."**; `alert.menuBarOff.title` **"Turn Off the Menu Bar Icon?"**; `alert.menuBarOff.messageOne` **"%@ is only in the menu bar. It stays in Dock Tile but won’t show anywhere until you turn this back on or add it to the Dock."**; `alert.menuBarOff.messageMany` **"These tiles are only in the menu bar: %@. They stay in Dock Tile but won’t show anywhere until you turn this back on or add them to the Dock."** (`%@` = up to three names joined by `ListFormatter`, then `alert.menuBarOff.more` **"%lld more"** as the last list element, phrased per language so any count reads right); `button.turnOff` **"Turn Off"**.
- Action button titles get NEW keys with a Dock-context comment (my call: reusing `button.remove` reads "Удалить" = Delete in Russian, beside the trash button; `button.add`'s comment is the file picker): `button.dockAdd` **"Add"**, `button.dockRemove` **"Remove"** ("take the tile out of the Dock — not delete it"). Update and Done keep their keys. `.help` and accessibility label keep the place: `button.addToDock` for a new install, `button.removeFromDock` for a removal.
- Never write `UserDefaults.standard` in tests (testing.md); pass the menu bar setting in as a value.

## Review Focus

1. **Upgrade with no key:** a 2.7.x config lists exactly the same tiles in the menu bar menu after update (Task 1 `decodesMissingKeyFromDockVisibility`, Task 2 `menuBarListsWhatTheDockDidBeforeUpgrade`).
2. **Setting off, then on:** no tile's `showInMenuBar` changes; the switch row hides and comes back with the same value (Task 5 `turningOffChangesNoTile` — the binding only flips the setting).
3. **Menu bar on, every tile switched off:** the menu shows only Open Dock Tile… and Quit, with no leading separator (Task 2 `noMenuBarTilesLeavesNoRows`; existing `if !menu.items.isEmpty` guard).
4. **Tile removed from the Dock while in the menu bar:** stays in the menu bar menu after Remove (Task 2 `menuBarIgnoresDockVisibility`).
5. **Several menu-only tiles when turning the setting off:** the alert names three, then "and N more" (Task 5 `messageNamesThreeThenCounts`).

---

### Task 1: `showInMenuBar` in the model (schema v13)

**Files:**
- Modify: `DockTile/Models/ConfigurationModels.swift` (stored property after `isVisibleInDock`; `init` param; `init(from:)`; `CodingKeys` "v13"; `revertingContent(to:)`; `duplicate(named:)`)
- Modify: `DockTile/Models/ConfigurationSchema.swift` (`static let showInMenuBar = false  // v13`)
- Test: `DockTileTests/Unit/Models/ShowInMenuBarTests.swift` (new), `DockTileTests/Unit/Models/DockTileDuplicateTests.swift`

**Interfaces:**
- Produces: `var showInMenuBar: Bool`; `init(…, isVisibleInDock:, showInMenuBar: Bool = ConfigurationDefaults.showInMenuBar, showInAppSwitcher:, …)`.

- [ ] **Step 1: Write the failing tests** in `ShowInMenuBarTests` (`@Suite("Show in Menu Bar field")`):
  - `decodesMissingKeyFromDockVisibility`: encode a config, delete `"showInMenuBar"` from the JSON object, set `isVisibleInDock` true → decodes `showInMenuBar == true`; with `isVisibleInDock` false → `false`.
  - `roundTrips`: `showInMenuBar = true, isVisibleInDock = false` survives encode/decode.
  - `notPartOfWhatTheHelperShows`: flipping it leaves `dockSignature` and `DockTileDetailView.contentSignature(of:)` equal.
  - `revertKeepsLiveValue`: live `true`, snapshot `false` → `live.revertingContent(to: snapshot).showInMenuBar == true`.
  - `duplicateStartsOff`: source `true` → `duplicate(named:).showInMenuBar == false`.
  - In `DockTileDuplicateTests`: add `"showInMenuBar"` to the not-shared keys list and set it `true` in the sample.
  - In `DockSnapshotRevertTests` (`:18-20`): add `"showInMenuBar"` to `bookkeepingKeys`, with different values in the snapshot and draft fixtures.
  - In `VisibilityOwnershipTests`: `editedMenuBarSurvivesStoredVisibility` — `preservingStoredVisibility(edited: showInMenuBar=true, isVisibleInDock=true; stored: showInMenuBar=false, isVisibleInDock=false)` → `showInMenuBar == true`, `isVisibleInDock == false`.
- [ ] **Step 2: Run, expect FAIL** (no member `showInMenuBar`):
  `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/ShowInMenuBarTests -only-testing:DockTileTests/DockTileDuplicateTests -only-testing:DockTileTests/DockSnapshotRevertTests -only-testing:DockTileTests/VisibilityOwnershipTests CODE_SIGNING_ALLOWED=NO`
- [ ] **Step 3: Implement.** Decode: `showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? isVisibleInDock` (after `isVisibleInDock` is decoded). `revertingContent`: `reverted.showInMenuBar = showInMenuBar` beside the other bookkeeping, and say so in its doc comment. `duplicate`: pass `showInMenuBar: false`. Do NOT add it to `dockSignature` or `contentSignature`.
- [ ] **Step 4: Run, expect PASS** (same command; print `passed on|failed on` lines and count).
- [ ] **Step 5: Commit** `feat(tiles): showInMenuBar field, decoded from Dock visibility (schema v13)`.

### Task 2: Menus list tiles by place

**Files:**
- Modify: `DockTile/UI/TileMenu.swift` (`menuTiles`, `tileItems`)
- Modify: `DockTile/App/MenuBarController.swift:88`, `DockTile/App/AppDelegate.swift:410`
- Test: `DockTileTests/Unit/UI/TileMenuTests.swift`

**Interfaces:**
- Consumes: `showInMenuBar` (Task 1).
- Produces: `enum TileMenu.Place { case dock, menuBar }`; `nonisolated static func menuTiles(_ configs: [DockTileConfiguration], in place: Place) -> [DockTileConfiguration]`; `static func tileItems(for:in:target:launch:configure:)`.

- [ ] **Step 1: Failing tests** (update existing `menuTiles` calls to `in: .dock`):
  - `menuBarIgnoresDockVisibility`: tiles A(dock on, bar on), B(dock off, bar on), C(dock on, bar off) → `.menuBar` = [A, B], `.dock` = [A, C], sidebar order kept.
  - `noMenuBarTilesLeavesNoRows`: all `showInMenuBar = false` → `.menuBar` is empty.
  - `menuBarListsWhatTheDockDidBeforeUpgrade`: configs decoded from JSON without the key, a MIX of Dock-visible and hidden tiles → `.menuBar` == `.dock` and neither is all of them.
- [ ] **Step 2: Run, expect FAIL** (`-only-testing:DockTileTests/TileMenuTests`).
- [ ] **Step 3: Implement** `menuTiles(_:in:)` (`.dock` → `isVisibleInDock`, `.menuBar` → `showInMenuBar`), thread `place` through `tileItems`; MenuBarController passes `.menuBar`, `applicationDockMenu` passes `.dock`. Update the doc comments that say "shown in the Dock".
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(menu): menu bar menu lists Show in Menu Bar tiles; Dock menu unchanged`.

### Task 3: Strings and translations

**Files:**
- Modify: `DockTile/Constants/AppStrings.swift` (`Label.showTile` value, `Label.appSwitcherNeedsShowTile` value, `Settings.menuBarToggleDescription` value, new `Label.showInMenuBar`, `Label.inMenuBar`, `Alert.menuBarOffTitle`, `Alert.menuBarOffMessageOne(_ name: String) -> String`, `Alert.menuBarOffMessageMany(_ list: String) -> String`, `Alert.menuBarOffMore(_ count: Int) -> String`, `Button.turnOff`, `Button.dockAdd`, `Button.dockRemove`)
- Modify: `DockTile/Resources/Localizable.xcstrings`, `docs/l10n/{de,fr,ja,ru,zh-Hans}.md`
- Test: `DockTileTests/Unit/Constants/AppStringsTests.swift`

- [ ] **Step 1: Failing test** `menuBarTileStringsExist`: each new accessor non-empty; `Label.showTile == "Show in Dock"` (English host).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** with the exact values in Global Constraints (three-argument `NSLocalizedString`; translator comments say "menu bar" is Apple's term). Changed English values: edit `AppStrings.swift` AND the en-GB/en-AU/en-US catalog values in place (localization-macos.md). Then `python3 -I Scripts/l10n/l10n.py sync-keys`, `export`, machine-fill the 13 rows per language (Apple's own "menu bar" / "Dock" terms; `button.dockRemove` must NOT reuse the language's word for Delete — ru "Убрать", de "Entfernen" is fine since Delete is "Löschen"; fr U+00A0 before `:` `?` and inside « »), `import <lang>` ×5.
- [ ] **Step 4: Verify** `python3 -I Scripts/l10n/l10n.py check` → "review sheets consistent with the catalog"; `python3 -I -m unittest discover -s Scripts/l10n -p 'test_*.py'` → OK; `-only-testing:DockTileTests/AppStringsTests -only-testing:DockTileTests/LocalizationCatalogTests` PASS.
- [ ] **Step 5: Commit** `feat(l10n): strings for menu bar tiles; Show Tile reads Show in Dock`.

### Task 4: Tile Detail switch and button titles

**Files:**
- Modify: `DockTile/Views/DockTileDetailView.swift` (Show in Menu Bar row between Show in Dock and App Switcher, only while the setting is on; hero stays `heroIconSize` 122 pt, top-aligned — the HStack's `alignment: .top`, no size change; `actionButtonText` via a seam; `.help` + `.accessibilityLabel` on the action button)
- Modify: `DockTile/Managers/ConfigurationManager.swift` (`createConfiguration`, `createConfiguration(from:)`)
- Test: `DockTileTests/Unit/Views/TileDetailMenuBarTests.swift` (new), `DockTileTests/Unit/Managers/ConfigurationManagerTests.swift`

**Interfaces:**
- Consumes: Task 1 field, Task 3 strings.
- Produces: `nonisolated static func actionTitle(_ action: DockAction, isCurrentlyInDock: Bool) -> String`; `nonisolated static func actionHelp(_ action: DockAction, isCurrentlyInDock: Bool) -> String?`; `func createConfiguration(menuBarEnabled: Bool = MenuBarController.isEnabled)` and `createConfiguration(from:menuBarEnabled: Bool = MenuBarController.isEnabled)`.

- [ ] **Step 1: Failing tests** (`TileDetailMenuBarTests`):
  - `buttonTitlesAreShort`: `.install` not in Dock → `AppStrings.Button.dockAdd`; in Dock → `.update`; `.remove` → `AppStrings.Button.dockRemove`; `.saveOnly` → `.done`.
  - `helpKeepsThePlace`: `.install` not in Dock → `AppStrings.Button.addToDock`; `.remove` → `AppStrings.Button.removeFromDock`; others nil.
  - In `ConfigurationManagerTests` (its existing live-manager pattern with cleanup): `newTileFollowsTheMenuBarSetting` — `createConfiguration(menuBarEnabled: true).showInMenuBar == true`, `false` → `false`; same for `createConfiguration(from:menuBarEnabled:)`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Read the setting with `@AppStorage(UserDefaultsKeys.menuBarEnabled) private var menuBarEnabled = false` (same as GeneralSettingsView). `heroIconSize` is unchanged (122 pt); make sure the hero/card HStack aligns `.top` so the 4-row card grows downward. Update the `heroIconSize` doc comment and architecture.md's "Hero" line: the hero matches the card's height only with 3 rows. The new row is a plain `formRow` with `Toggle("", isOn: $session.config.showInMenuBar).tileSwitch()` and `AppStrings.Label.showInMenuBar`; it saves through the existing debounce (no `onChange` side effects, no consent). The hero row width stays 406 pt, so `MainWindowWidthTests` is unaffected.
- [ ] **Step 4: Run, expect PASS** (`-only-testing:DockTileTests/TileDetailMenuBarTests -only-testing:DockTileTests/ConfigurationManagerTests -only-testing:DockTileTests/DockActionResolutionTests -only-testing:DockTileTests/MainWindowWidthTests`).
- [ ] **Step 5: Commit** `feat(tiles): Show in Menu Bar switch in Tile Detail; Add/Remove titles`.

### Task 5: Sidebar mark and the turn-off confirmation

**Files:**
- Modify: `DockTile/Views/DockTileSidebarView.swift` (`ConfigurationRow`: trailing `Image(systemName: "menubar.rectangle")`, secondary style, `accessibilityLabel(AppStrings.Label.inMenuBar)`, only while the setting is on and `config.showInMenuBar`)
- Modify: `DockTile/Views/GeneralSettingsView.swift` (`menuBarRow` binding: turning OFF with menu-only tiles sets `@State pendingMenuBarOff` and shows the alert instead of flipping; Turn Off flips it and runs the existing `onChange` path; Cancel leaves it on)
- Test: `DockTileTests/Unit/Views/MenuBarOffAlertTests.swift` (new)

**Interfaces:**
- Produces: `nonisolated static func menuOnlyTileNames(_ configs: [DockTileConfiguration]) -> [String]` (sidebar order; `showInMenuBar && !isVisibleInDock`); `nonisolated static func menuBarOffMessage(names: [String]) -> String?` (nil for empty).

- [ ] **Step 1: Failing tests:**
  - `listsOnlyMenuOnlyTiles`: A(bar, dock), B(bar, no dock), C(no bar, no dock) → ["B"].
  - `noAlertWithoutMenuOnlyTiles`: `menuBarOffMessage(names: []) == nil`.
  - `messageNamesThreeThenCounts`: 1 name → `AppStrings.Alert.menuBarOffMessageOne("Media")`; 5 names → `menuBarOffMessageMany(list)` where `list` contains the first three names and `AppStrings.Alert.menuBarOffMore(2)`, and not the 4th or 5th name.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Join with `ListFormatter.localizedString(byJoining:)` (it uses 、 for zh/ja); more than three → first three plus `menuBarOffMore(n - 3)` as the last element. Symbol literal (if the spec's mark is an SF Symbol) is swept by `SystemSymbolNameTests`.
- [ ] **Step 4: Run, expect PASS** (`-only-testing:DockTileTests/MenuBarOffAlertTests -only-testing:DockTileTests/SystemSymbolNameTests`).
- [ ] **Step 5: Commit** `feat(menu): sidebar menu bar mark; confirm turning the icon off with menu-only tiles`.

### Task 6: Rules, full verification, hands-on

**Files:**
- Modify: `.claude/rules/menu-bar.md` (menu lists `showInMenuBar` tiles; the switch, its gate, the turn-off alert), `.claude/rules/architecture.md` (Tile Detail rows + hero; `showInMenuBar` is editor-owned, outside `dockSignature`/Revert; the "Menu bar / Dock Tile's Dock menu must read tiles through `dockVersion`" line rewritten to what the code does: both menus read the live config — a menu-only tile has no helper copy), `.claude/rules/testing.md` (seams: `TileMenu.menuTiles(_:in:)`, `actionTitle`/`actionHelp`, `menuOnlyTileNames`/`menuBarOffMessage`, decode default)

- [ ] **Step 1:** Grep the old behaviour's words and fix every hit: `grep -rn "Show Tile\|shown in the Dock\|isVisibleInDock ones\|Add to Dock\|tiles in your Dock" DockTile DockTileTests .claude/rules` (known: `TileMenuTests.swift:31`, `SmartAddEngineTests.swift:332,348`, `ConfigurationManager.swift:185-188` doc comment). `website/lib/i18n.ts` also says "Show Tile": leave it, note it for a website session.
- [ ] **Step 2: Full suite on the Default icon style:** the CLAUDE.md `xcodebuild test … -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO` → `** TEST SUCCEEDED **`, zero `failed on`; plus both l10n commands.
- [ ] **Step 3:** Rebuild signed (no `CODE_SIGNING_ALLOWED=NO`), `codesign --verify` the dev product, relaunch it.
- [ ] **Step 4: Hands-on with the owner** (dev build): setting off → card has 3 rows, no switch; on → 4 rows, hero still 122 pt and top-aligned; a tile with Dock off + Menu Bar on appears in the menu bar menu only; Remove keeps it there; turning the setting off shows the alert naming it, Cancel keeps it on, Turn Off then On gives the same menu and the same switch values; German and Russian UI fit the card and the button; the toolbar "Add" beside In This Tile's "+ Add" reads clearly.
- [ ] **Step 5: Commit** `docs(rules): menu bar tiles`.
- [ ] **Step 6:** `stage-gate --dev` with a fresh reviewer, then push the branch and `gh workflow run ci.yml --ref feature/menu-bar-tiles`; require both legs green (macOS 15: `N passed, 0 failed`) before merging.
