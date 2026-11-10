# Dock Tile — Deutsch (de)

How to review: [docs/l10n/README.md](README.md). Edit the **Translation** column, set
**Status** to `reviewed` for every row you checked (changed or not), then "Propose changes".
Status values: `machine` (not yet checked by a person), `reviewed`, `todo` (no translation yet).
Keep `%@`-style placeholders exactly as they are. `\n` means a line break, `\|` a pipe.

| Key | English | Translation | Status | Context |
|---|---|---|---|---|
| `alert.applyPopover.message` | Dock Tile will rebuild your pinned tiles with the new popover look and briefly restart the Dock. Your other Dock items won't be affected. | Dock Tile erstellt deine Kacheln im Dock mit dem neuen Popover-Design neu und startet das Dock kurz neu. Deine anderen Objekte im Dock bleiben unverändert. | machine | Confirmation message warning the Dock will restart when applying popover settings |
| `alert.applyPopover.title` | Apply to your Dock tiles? | Auf deine Kacheln im Dock anwenden? | machine | Confirmation title before rebuilding tiles to apply popover appearance settings |
| `alert.configUnreadable.message` | Your tiles haven't been changed. Dock Tile couldn't open its settings file and will quit. Check that you can open %@, then open Dock Tile again. | Deine Kacheln wurden nicht geändert. Dock Tile konnte seine Einstellungsdatei nicht öffnen und wird beendet. Prüfe, ob du %@ öffnen kannst, und öffne Dock Tile dann erneut. | machine | Launch alert message when the tile settings file can't be read; %@ = the file's full path. The app quits when the alert closes. |
| `alert.configUnreadable.quit` | Quit | Beenden | machine | Only button of the can't-read-tiles launch alert; quits Dock Tile |
| `alert.configUnreadable.title` | Dock Tile Can't Read Your Tiles | Dock Tile kann deine Kacheln nicht lesen | machine | Launch alert title: the tile settings file exists but could not be opened; the app quits after it |
| `alert.deleteTile.message` | This will permanently delete the tile and remove it from the dock. | Die Kachel wird endgültig gelöscht und aus dem Dock entfernt. | machine | Delete-tile confirmation message |
| `alert.missingApps.message` | Some apps in your tiles can't be found on this Mac. Remove them from your tiles? | Einige Apps in deinen Kacheln wurden auf diesem Mac nicht gefunden. Aus deinen Kacheln entfernen? | machine | Alert message offering to remove uninstalled apps from tiles |
| `alert.missingApps.title` | Some apps are no longer installed | Einige Apps sind nicht mehr installiert | machine | Alert title when apps referenced by tiles can't be found on disk |
| `alert.missingAppsScan.foundMessage` | These apps can't be found on this Mac: | Diese Apps wurden auf diesem Mac nicht gefunden: | machine | Intro line of the manual scan results dialog; a list of tiles/apps follows |
| `alert.missingAppsScan.noneMessage` | Every app in your tiles is currently installed. | Alle Apps in deinen Kacheln sind installiert. | machine | Message of the manual scan dialog when nothing is missing |
| `alert.missingAppsScan.noneTitle` | No Missing Apps | Keine fehlenden Apps | machine | Title of the manual scan dialog when every tile app is installed |
| `alert.relocate.blockingMessage` | Dock Tile can't create or update this tile because it's running from a temporary, read-only location. This happens when the app is launched from Downloads. Move Dock Tile to your Applications folder and try again. | Dock Tile kann diese Kachel nicht erstellen oder aktualisieren, weil die App von einem temporären, schreibgeschützten Ort aus ausgeführt wird. Das passiert, wenn sie aus dem Ordner „Downloads“ geöffnet wird. Verschiebe Dock Tile in deinen Ordner „Programme“ und versuche es erneut. | machine | Message shown when a tile action is blocked because the app is translocated |
| `alert.relocate.checkbox` | Don't ask again | Nicht erneut fragen | machine | Checkbox to suppress future move-to-Applications nudges |
| `alert.relocate.message` | Dock Tile is running from outside your Applications folder. macOS may run it from a temporary, read-only location, which can stop new tiles from being created. Move it to Applications to make sure everything works. | Dock Tile wird außerhalb deines Ordners „Programme“ ausgeführt. macOS führt die App dann möglicherweise von einem temporären, schreibgeschützten Ort aus, wodurch keine neuen Kacheln erstellt werden können. Verschiebe sie in den Ordner „Programme“, damit alles funktioniert. | machine | Message of the launch-time nudge to move the app to Applications |
| `alert.relocate.title` | Move Dock Tile to Applications? | Dock Tile in den Ordner „Programme“ verschieben? | machine | Title of the prompt asking the user to move the app into the Applications folder |
| `alert.restartDock.checkbox` | Don't show this again | Nicht mehr anzeigen | machine | Checkbox label to suppress future Dock restart alerts |
| `alert.restartDock.message` | Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected. | Dock Tile startet das Dock neu, um Änderungen anzuwenden. Das passiert jedes Mal, wenn du Kacheln hinzufügst, aktualisierst oder entfernst. Deine aktuellen Objekte im Dock bleiben unverändert. | machine | Alert message explaining Dock restart |
| `alert.restartDock.title` | Dock Restart Required | Neustart des Docks erforderlich | machine | Alert title when Dock restart is required |
| `alert.revertToDock.message` | Your changes will be replaced by the version in the Dock. | Deine Änderungen werden durch die Version im Dock ersetzt. | machine | Revert to Dock Version confirmation message: the tile's unapplied edits are discarded and the version its Dock icon was built from comes back |
| `app.name` | Dock Tile | Dock Tile | machine | App display name |
| `button.add` | Add | Hinzufügen | machine | Add button label in file picker |
| `button.addToDock` | Add to Dock | Zum Dock hinzufügen | machine | Button to add tile to Dock |
| `button.applyToTiles` | Apply | Anwenden | machine | Confirm button that rebuilds tiles to apply popover settings |
| `button.back` | Back | Zurück | machine | Back button label |
| `button.cancel` | Cancel | Abbrechen | machine | Cancel button in alerts |
| `button.checkForUpdates` | Check for Updates… | Nach Updates suchen … | machine | Button that triggers a manual Sparkle update check |
| `button.checkNow` | Check Now | Jetzt suchen | machine | Settings → Software Update: button that triggers a manual Sparkle update check |
| `button.confirm` | Confirm | Bestätigen | machine | Confirm button for alert dialogs |
| `button.createNewTile` | Create New Tile | Neue Kachel erstellen | machine | Smart Add sheet — neutral button that starts a blank tile instead of a suggestion |
| `button.delete` | Delete | Löschen | machine | Delete button |
| `button.done` | Done | Fertig | machine | Done button |
| `button.duplicate` | Duplicate | Duplizieren | machine | Duplicate button in context menu |
| `button.keep` | Keep | Behalten | machine | Button to keep uninstalled apps in tiles (dismiss the removal prompt) |
| `button.moveToApplications` | Move to Applications | In „Programme“ verschieben | machine | Button that moves the app into the Applications folder |
| `button.newTile` | New Tile | Neue Kachel | machine | Button to create first tile on empty state |
| `button.notNow` | Not Now | Später | machine | Dismiss button for the non-blocking move-to-Applications nudge |
| `button.openAccessibilitySettings` | Open Accessibility Settings… | „Bedienungshilfen“ öffnen … | machine | Button that opens the Accessibility pane in System Settings (Reduce Motion) |
| `button.openLoginItems` | Open Login Items Settings… | „Anmeldeobjekte“ öffnen … | machine | Button that opens System Settings Login Items for approval |
| `button.remove` | Remove | Entfernen | machine | Remove button |
| `button.removeAll` | Remove All | Alle entfernen | machine | Button to remove all missing apps from tiles at once |
| `button.removeFromDock` | Remove from Dock | Aus dem Dock entfernen | machine | Button to remove tile from Dock |
| `button.resetToDefaults` | Reset to Defaults | Standardwerte wiederherstellen | machine | Button that restores popover appearance settings to their defaults |
| `button.revert` | Revert | Zurücksetzen | machine | Confirm button of the Revert to Dock Version alert |
| `button.reviewInTiles` | Review in Tiles | In Kacheln prüfen | machine | Button that navigates to the first tile containing a missing app |
| `button.save` | Save | Sichern | machine | Primary toolbar button that commits the popover appearance settings |
| `button.saving` | Applying… | Wird angewendet … | machine | Loading label on the Save button while applying settings to Dock tiles |
| `button.scanForMissingApps` | Scan | Prüfen | machine | Settings button that scans tiles for moved/uninstalled apps |
| `button.update` | Update | Aktualisieren | machine | Update button when tile is already in Dock |
| `button.useThisTile` | Use This Tile | Kachel verwenden | machine | Smart Add sheet — button that creates a pre-filled tile from a suggestion |
| `emojiCategory.activity` | Activity | Aktivität | machine | Emoji picker: section header |
| `emojiCategory.animalsNature` | Animals & Nature | Tiere & Natur | machine | Emoji picker: section header |
| `emojiCategory.foodDrink` | Food & Drink | Essen & Trinken | machine | Emoji picker: section header |
| `emojiCategory.objects` | Objects | Objekte | machine | Emoji picker: section header |
| `emojiCategory.people` | People | Personen | machine | Emoji picker: section header |
| `emojiCategory.symbols` | Symbols | Symbole | machine | Emoji picker: section header |
| `emojiCategory.travelPlaces` | Travel & Places | Reisen & Orte | machine | Emoji picker: section header |
| `empty.createFirstTile` | Create Your First Tile | Erstelle deine erste Kachel | machine | Header text for empty state |
| `empty.detail` | Detail | Details | machine | Placeholder text in detail view |
| `empty.noApps` | No apps configured | Keine Apps konfiguriert | machine | Empty state text when no apps configured |
| `empty.noTiles` | No Tiles | Keine Kacheln | machine | Empty state text in sidebar |
| `error.appTranslocated` | Dock Tile is running from a temporary, read-only location and can't create tiles. Move it to your Applications folder and try again. | Dock Tile wird von einem temporären, schreibgeschützten Ort aus ausgeführt und kann keine Kacheln erstellen. Verschiebe die App in deinen Ordner „Programme“ und versuche es erneut. | machine | Error when the app is translocated and cannot generate helper bundles |
| `error.bundleBuildInProgress` | This tile is already being rebuilt. Wait for that to finish, then try again. | Diese Kachel wird bereits neu erstellt. Warte, bis der Vorgang abgeschlossen ist, und versuche es dann erneut. | machine | Error when a second build is requested for a tile whose helper bundle is already being built |
| `error.dockChangeNotKept` | The Dock didn't keep this change. Try again. | Das Dock hat diese Änderung nicht übernommen. Versuche es erneut. | machine | Error when Dock Tile wrote a change to the Dock (add, update or hide a tile) but the Dock did not keep it, even after one retry |
| `error.failedToCodeSign` | Failed to code sign helper bundle | Das Hilfs-Bundle konnte nicht signiert werden | machine | Error when code signing fails |
| `error.failedToCopyBundle` | Failed to copy bundle | Das Bundle konnte nicht kopiert werden | machine | Error when bundle copy fails |
| `error.failedToReadInfoPlist` | Failed to read Info.plist | Info.plist konnte nicht gelesen werden | machine | Error when Info.plist cannot be read |
| `error.failedToWriteInfoPlist` | Failed to write Info.plist | Info.plist konnte nicht geschrieben werden | machine | Error when Info.plist cannot be written |
| `error.mainAppNotFound` | Main Dock Tile.app not found | Haupt-App „Dock Tile.app“ nicht gefunden | machine | Error when main app bundle cannot be found |
| `filePicker.message` | Select one or more applications or folders to add | Wähle eine oder mehrere Apps oder Ordner zum Hinzufügen aus | machine | Message in file picker dialog |
| `iconWeight.bold` | Bold | Fett | machine | Customise: icon weight picker option |
| `iconWeight.heavy` | Heavy | Sehr fett | machine | Customise: icon weight picker option |
| `iconWeight.light` | Light | Leicht | machine | Customise: icon weight picker option |
| `iconWeight.medium` | Medium | Medium | machine | Customise: icon weight picker option |
| `iconWeight.regular` | Regular | Regular | machine | Customise: icon weight picker option |
| `iconWeight.semibold` | Semibold | Halbfett | machine | Customise: icon weight picker option |
| `label.apps.arrangement` | Arrangement | Anordnung | machine | Customise Tile: Apps card row — the grid the face uses |
| `label.apps.arrangement.threeByThree` | 3 × 3 | 3 × 3 | machine | Customise Tile: Arrangement value for 5 or more apps |
| `label.apps.arrangement.twoByTwo` | 2 × 2 | 2 × 2 | machine | Customise Tile: Arrangement value for 2–4 apps |
| `label.apps.glass` | A glass folder that follows Light and Dark Mode. | Ein Glasordner, der sich an „Hell“ und „Dunkel“ anpasst. | machine | Customise Tile: fixed sentence after the Apps caption (decided 2026-10-19: the dark appearance is system-dark) |
| `label.apps.header` | Apps | Apps | machine | Customise Tile: group header above the Apps card |
| `label.apps.note.all` | Shows all %lld apps, in tile order. | Zeigt alle %lld Apps in der Reihenfolge der Kachel. | machine | Customise Tile: Apps caption, 2–9 apps; %lld = app count |
| `label.apps.note.firstNine` | Shows the first 9 of %lld apps, in tile order. | Zeigt die ersten 9 von %lld Apps in der Reihenfolge der Kachel. | machine | Customise Tile: Apps caption, more than nine apps; %lld = app count |
| `label.apps.note.none` | No apps yet — use Add under In This Tile. | Noch keine Apps – füge welche mit „Hinzufügen“ unter „In dieser Kachel“ hinzu. | machine | Customise Tile: Apps caption when the tile has no apps (builder copy, not in the handoff) |
| `label.apps.note.one` | Shows the only app in this tile. | Zeigt die einzige App dieser Kachel. | machine | Customise Tile: Apps caption, one app |
| `label.apps.shown` | Shown | Angezeigt | machine | Customise Tile: Apps card row — how many apps the face shows |
| `label.apps.shownValue` | %1$lld of %2$lld | %1$lld von %2$lld | machine | Customise Tile: Apps card Shown value, e.g. 9 of 12; %1$lld = shown, %2$lld = total (positional so a language may reorder them) |
| `label.appsBackground` | Dock Icon Background | Dock-Symbolhintergrund | machine | App Grid inspector section for per-tile plate settings |
| `label.appsBackground.automatic` | Follow System | Systemeinstellung folgen | machine | App Grid background follows the macOS icon appearance |
| `label.appsBackground.charcoal` | Dark Grey | Dunkelgrau | machine | Fixed dark background for an App Grid icon |
| `label.appsBackground.custom` | Custom Colour | Eigene Farbe | machine | Native colour picker for an App Grid icon background |
| `label.appsBackground.hint` | Applies to this tile only. | Gilt nur für diese Kachel. | machine | Caption under the App Grid background menu: the choice affects only this tile |
| `label.appsBackground.light` | Light | Hell | machine | Fixed light background for an App Grid icon |
| `label.appsFace.accessibility` | Apps face: showing %lld of this tile's apps | App-Ansicht: zeigt %lld Apps dieser Kachel | machine | VoiceOver label for a tile preview showing the Apps face; %lld = number of app icons shown |
| `label.background` | Background | Hintergrund | machine | Customise Tile: background row label |
| `label.background.colour` | Colour | Farbe | machine | Customise Tile: Colour background chip |
| `label.background.colour.accessibility` | Colour, filled with your colour | Farbe, mit deiner Farbe gefüllt | machine | VoiceOver label for the Colour chip |
| `label.background.hint.colour` | Filled with your colour | Mit deiner Farbe gefüllt | machine | Customise Tile: hint under Background when Colour |
| `label.background.hint.emojiColours` | Emoji keep their own colours. | Emoji behalten ihre eigenen Farben. | machine | Customise Tile: appended to the Background caption for an Emoji tile |
| `label.background.hint.mono` | White in Light Mode, black in Dark Mode | Weiß bei „Hell“, schwarz bei „Dunkel“ | machine | Customise Tile: hint under Background when Mono |
| `label.background.hint.mono.static` | White tile with a coloured symbol | Weiße Kachel mit farbigem Symbol | machine | Customise Tile: hint under Background when Mono on macOS 15 (static white tile) |
| `label.background.mono` | Mono | Mono | machine | Customise Tile: Mono background chip |
| `label.background.mono.accessibility` | Mono, white in Light Mode and black in Dark Mode | Mono, weiß bei „Hell“ und schwarz bei „Dunkel“ | machine | VoiceOver label for the Mono chip |
| `label.background.mono.static.accessibility` | Mono, a white tile with a coloured symbol | Mono, eine weiße Kachel mit farbigem Symbol | machine | VoiceOver label for the Mono chip on macOS 15 |
| `label.colour` | Colour | Farbe | machine | Label for colour picker section |
| `label.colour.hint.deepened` | Deepened slightly so the symbol stays clear | Leicht abgedunkelt, damit das Symbol gut erkennbar bleibt | machine | Customise Tile: colour hint when the fill was darkened for contrast |
| `label.colour.hint.emoji` | Emoji keep their own colours | Emoji behalten ihre eigenen Farben | machine | Customise Tile: colour hint, Mono emoji tile (row disabled) |
| `label.colour.hint.fills` | Fills the tile | Füllt die Kachel | machine | Customise Tile: colour hint, Colour tile |
| `label.colour.hint.tints` | Tints the symbol | Färbt das Symbol | machine | Customise Tile: Colour card caption for a Mono tile |
| `label.colour.hint.toned` | Toned for Light and Dark | Abgestimmt auf „Hell“ und „Dunkel“ | machine | Customise Tile: colour hint, Mono tile |
| `label.colour.hint.toned.static` | Toned to stay clear on white | Abgestimmt für gute Erkennbarkeit auf Weiß | machine | Customise Tile: colour hint, Mono tile on macOS 15 |
| `label.iconSize` | Icon Size | Symbolgröße | machine | Compact label for the icon size stepper (side-by-side with icon weight) |
| `label.iconWeight` | Icon Weight | Strichstärke | machine | Label for the SF Symbol weight picker |
| `label.missingAppsScan` | Missing Apps | Fehlende Apps | machine | Settings row title for the missing-app scan |
| `label.missingAppsScanDescription` | Check your tiles for apps that have been moved or uninstalled. | Prüfe deine Kacheln auf Apps, die verschoben oder deinstalliert wurden. | machine | Settings row description for the missing-app scan |
| `label.notInstalled` | Not installed | Nicht installiert | machine | Badge/kind text shown for an app whose bundle is no longer on disk |
| `label.popover.animation` | Animation | Animation | machine | Label for the popover animation segmented control |
| `label.popover.highlightOnHover` | Highlight on Hover | Beim Überfahren hervorheben | machine | Toggle label — show a background fill on the hovered item |
| `label.popover.layout` | Layout | Layout | machine | Label for the Grid/List preview toggle in popover settings |
| `label.popover.listAlwaysLabelled` | List view always shows labels | Die Liste zeigt immer Beschriftungen | machine | Hint shown beside the disabled Show Labels control when previewing List |
| `label.popover.showLabels` | Show Labels | Beschriftungen zeigen | machine | Toggle label — show app names under grid icons |
| `label.popover.size` | Popover Size | Popover-Größe | machine | Label for the popover size segmented control |
| `label.popover.spacing` | Spacing | Abstand | machine | Label for the popover item spacing segmented control |
| `label.popover.tileSize` | Tile Size | Kachelgröße | machine | Label for the icon/cell size control inside the popover |
| `label.shareAnalytics` | Share anonymous usage data | Anonyme Nutzungsdaten teilen | machine | Label for the analytics opt-out toggle in Settings |
| `label.shareAnalyticsDescription` | Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected. | Hilf mit, Dock Tile zu verbessern, indem du anonyme Nutzungsdaten und Absturzberichte sendest. Es werden keine persönlichen Daten erfasst. | machine | Explanation under the analytics toggle |
| `label.addAppsAndFolders` | Add Apps & Folders | Apps & Ordner hinzufügen | machine | Tooltip on the Add button in Tile Detail's In This Tile section |
| `label.appSwitcherNeedsShowTile` | Turn on Show Tile first — this only applies while the tile is in the Dock. | Aktiviere zuerst „Kachel zeigen“ – diese Option gilt nur, solange die Kachel im Dock ist. | machine | Tooltip on the disabled Show in App Switcher toggle when the tile is hidden |
| `label.showInAppSwitcher` | Show in App Switcher | Im App-Umschalter zeigen | machine | Label for app switcher toggle |
| `label.showTile` | Show Tile | Kachel zeigen | machine | Label for show tile toggle |
| `label.softwareUpdate` | Software Update | Softwareupdate | machine | Title of the software-update row in General settings |
| `label.softwareUpdateDescription` | You’re using version %@. Dock Tile checks for updates automatically. | Du verwendest Version %@. Dock Tile sucht automatisch nach Updates. | machine | Description under the software-update row; %@ is the current version |
| `label.startAtLogin` | Start tiles at login | Kacheln bei der Anmeldung starten | machine | Label for the start-at-login toggle in Settings |
| `label.startAtLoginDescription` | Keep your tiles ready in the Dock so they respond instantly after you restart your Mac. | Halte deine Kacheln im Dock bereit, damit sie nach einem Neustart deines Mac sofort reagieren. | machine | Explanation under the start-at-login toggle |
| `label.style.appPreview` | App Grid | App-Raster | machine | Customise Tile: Style picker card for the Apps face |
| `label.symbolColour` | Symbol Colour | Symbolfarbe | machine | Customise Tile: colour row label for a Mono tile |
| `label.tileColour` | Tile Colour | Kachelfarbe | machine | Customise Tile: Colour card header for a Colour tile |
| `label.tileIcon` | Tile Icon | Kachelsymbol | machine | Label for tile icon section |
| `label.tileIconSize` | Tile Icon Size | Größe des Kachelsymbols | machine | Label for tile icon size |
| `label.tileName` | Tile Name | Kachelname | machine | Label for tile name field |
| `layout.grid` | Grid | Raster | machine | Grid layout option |
| `layout.list` | List | Liste | machine | List layout option |
| `itemMenu.forceQuit` | Force Quit | Sofort beenden | machine | Popover item context menu: force quit (shown while Option is held) |
| `itemMenu.getInfo` | Get Info | Informationen | machine | Popover item context menu: open Finder's Get Info window |
| `itemMenu.hide` | Hide | Ausblenden | machine | Popover item context menu: hide the running app |
| `itemMenu.open` | Open | Öffnen | machine | Popover item context menu: open the app or folder |
| `itemMenu.quickLook` | Quick Look | Schnellansicht | machine | Popover item context menu: preview the item with Quick Look |
| `itemMenu.quit` | Quit | Beenden | machine | Popover item context menu: quit the running app |
| `itemMenu.share` | Share… | Teilen … | machine | Popover item context menu: open the share sheet for a folder |
| `itemMenu.showInFinder` | Show in Finder | Im Finder anzeigen | machine | Popover item context menu: reveal the item in Finder |
| `menu.configure` | Configure... | Konfigurieren … | machine | Menu item to configure tile (opens main app) |
| `menu.configureTile` | Configure Tile | Kachel konfigurieren | machine | Tooltip for gear icon in popover |
| `menu.configureTileItem` | Configure Tile… | Kachel konfigurieren … | machine | Tile submenu item in the menu bar and Dock menus: opens that tile in Dock Tile's window |
| `menu.copyDiagnostics` | Copy Diagnostics | Diagnose kopieren | machine | File menu item that copies recent diagnostic logs to the clipboard |
| `menu.hideInspector` | Hide Inspector | Inspektor ausblenden | machine | View menu item (Hide Inspector, ⌥⌘I) that closes the Customise Tile inspector |
| `menu.newTile` | New Tile | Neue Kachel | machine | Menu item to create a new tile |
| `menu.noAppsConfigured` | No apps configured | Keine Apps konfiguriert | machine | Dock menu: disabled row when the tile has no apps |
| `menu.noConfiguration` | No configuration | Keine Konfiguration | machine | Dock menu: disabled row when the tile's config cannot be found |
| `menu.openDockTile` | Open Dock Tile… | Dock Tile öffnen … | machine | Menu bar and Dock menu item that opens Dock Tile's main window |
| `menu.openInFinder` | Open in Finder | Im Finder öffnen | machine | Menu item to open in Finder |
| `menu.options` | Options | Optionen | machine | Section divider in menu |
| `menu.quitDockTile` | Quit Dock Tile | Dock Tile beenden | machine | Menu bar icon's menu: quits Dock Tile (tiles already in the Dock keep working) |
| `menu.settings` | Settings… | Einstellungen … | machine | App menu item that opens the inline Settings pane (⌘,) |
| `menu.showInspector` | Show Inspector | Inspektor einblenden | machine | View menu item (Show Inspector, ⌥⌘I) that opens the Customise Tile inspector |
| `popover.option.animation.default` | Default | Standard | machine | Animation tier — default |
| `popover.option.animation.fast` | Fast | Schnell | machine | Animation tier — fast |
| `popover.option.animation.none` | None | Keine | machine | Animation tier — none |
| `popover.option.comfortable` | Comfortable | Komfortabel | machine | Spacing tier — comfortable |
| `popover.option.compact` | Compact | Kompakt | machine | Spacing tier — compact |
| `popover.option.large` | Large | Groß | machine | Size tier — large |
| `popover.option.medium` | Medium | Mittel | machine | Size tier — medium |
| `popover.option.small` | Small | Klein | machine | Size tier — small |
| `popover.option.spacious` | Spacious | Großzügig | machine | Spacing tier — spacious |
| `search.emojis` | Search emojis | Emoji suchen | machine | Search placeholder for emojis |
| `search.symbols` | Search symbols | Symbole suchen | machine | Search placeholder for symbols |
| `settings.dockLock` | Dock Lock | Dock-Sperre | machine | Section header for the Dock Lock feature in Settings |
| `settings.dockLock.accessibilityGranted` | Accessibility access granted | Zugriff auf Bedienungshilfen erteilt | machine | Status shown when Accessibility permission is granted |
| `settings.dockLock.accessibilityNeeded` | Accessibility access required | Zugriff auf Bedienungshilfen erforderlich | machine | Status shown when Accessibility permission is missing |
| `settings.dockLock.accessibilityNeededDetail` | Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings. | Dock Tile benötigt Zugriff auf Bedienungshilfen, um das Dock an seinem Platz zu halten. Aktiviere Dock Tile in den Systemeinstellungen. | machine | Explanation of why Accessibility access is needed |
| `settings.dockLock.anchor` | Keep Dock on | Dock fixieren auf | machine | Label for the anchor display picker |
| `settings.dockLock.defaultDisplay` | Default (follow macOS) | Standard (macOS-Verhalten) | machine | First option in the anchor picker — no lock, macOS default behaviour |
| `settings.dockLock.description` | Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose. | Verhindert, dass das Dock bei mehreren Bildschirmen zwischen ihnen springt. Es bleibt auf dem Bildschirm, den du auswählst. | machine | Explanation under the Dock Lock toggle |
| `settings.dockLock.edgeCovered` | Another display touches the whole Dock edge of %@, so macOS can't move the Dock there. Shift one display in System Settings so part of that edge is free, or pick another display. | Ein anderer Bildschirm grenzt an den ganzen Dock-Rand von %@, daher kann macOS das Dock nicht dorthin bewegen. Verschiebe in den Systemeinstellungen einen Bildschirm, sodass ein Teil dieses Rands frei ist, oder wähle einen anderen Bildschirm. | machine | Shown when another display is arranged along the entire edge where the Dock sits (e.g. two equal displays stacked), which macOS never lets the Dock move onto |
| `settings.dockLock.lockedTo` | Dock is locked to %@ | Dock ist auf %@ fixiert | machine | Indicator confirming the display the Dock is pinned to |
| `settings.dockLock.mainDisplay` | Main | Hauptbildschirm | machine | Suffix marking the main display in the anchor picker |
| `settings.dockLock.moveFailed` | Couldn't move the Dock to %@. Try again in a moment. | Das Dock konnte nicht auf %@ bewegt werden. Versuche es gleich noch einmal. | machine | Error shown when the Dock could not be relocated; a Try Again button follows |
| `settings.dockLock.moving` | Moving Dock to %@… | Dock wird auf %@ bewegt … | machine | Progress message shown while the Dock is being relocated |
| `settings.dockLock.note` | Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays. | Funktioniert mit dem Dock unten, links oder rechts. Ist es auf einem Bildschirm fixiert, werden auf deinen anderen Bildschirmen an diesem Rand ein paar Pixel reserviert. | machine | Footnote describing Dock Lock behaviour and trade-off |
| `settings.dockLock.openSettings` | Open System Settings… | Systemeinstellungen öffnen … | machine | Button that opens the Accessibility pane in System Settings |
| `settings.dockLock.perSetupNote` | Each set of connected displays remembers its own choice. | Jede Kombination angeschlossener Bildschirme merkt sich ihre eigene Auswahl. | machine | Footnote under the Dock Lock display picker: the chosen display is remembered separately for each combination of connected displays (home, work…) |
| `settings.dockLock.primer.body` | Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens. | Die Dock-Sperre hält das Dock auf dem Bildschirm, den du auswählst. Dazu benötigt Dock Tile Zugriff auf Bedienungshilfen, damit macOS das Dock nicht auf deine anderen Bildschirme verschiebt. | machine | Explanation in the permission primer |
| `settings.dockLock.primer.continue` | Continue | Fortfahren | machine | Primary button in the permission primer that triggers the macOS dialog |
| `settings.dockLock.primer.notNow` | Not Now | Später | machine | Secondary button in the permission primer that cancels enabling Dock Lock |
| `settings.dockLock.primer.reassurance` | Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time. | Als Nächstes bittet dich macOS, Dock Tile in den Systemeinstellungen zu aktivieren. Du kannst das jederzeit wieder deaktivieren. | machine | Reassurance line in the permission primer about what happens next |
| `settings.dockLock.primer.title` | Allow Accessibility Access | Zugriff auf Bedienungshilfen erlauben | machine | Title of the permission primer shown before requesting Accessibility |
| `settings.dockLock.retry` | Try Again | Erneut versuchen | machine | Button to retry a failed Dock relocation |
| `settings.dockLock.singleDisplay` | Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it. | Schließe einen zweiten Bildschirm an, um die Dock-Sperre zu verwenden. Mit nur einem Bildschirm bleibt das Dock genau dort, wo macOS es platziert. | machine | Note shown when only one display is connected |
| `settings.dockLock.spacesShared` | macOS keeps the Dock on the main display while “Displays have separate Spaces” is off, so it can't move to %@. Turn that option on in System Settings, then log out and back in. | Solange „Monitore verwenden verschiedene Spaces“ deaktiviert ist, behält macOS das Dock auf dem Hauptbildschirm, daher kann es nicht auf %@ wechseln. Aktiviere diese Option in den Systemeinstellungen und melde dich dann ab und wieder an. | machine | Shown when the macOS option “Displays have separate Spaces” (Desktop & Dock settings) is off; use Apple's own name for that option in your language |
| `settings.dockLock.toggle` | Lock Dock to one display | Dock auf einem Bildschirm fixieren | machine | Label for the Dock Lock enable toggle |
| `settings.general` | General | Allgemein | machine | Title of the General settings pane |
| `settings.login.registrationFailed` | Couldn’t turn this on — macOS refused the registration. %@ | Konnte nicht aktiviert werden – macOS hat die Registrierung abgelehnt. %@ | machine | Shown under the Start tiles at login toggle when SMAppService registration failed; %@ is the system error |
| `settings.login.requiresApproval` | Approve Dock Tile in Login Items to finish enabling this. | Erlaube Dock Tile unter „Anmeldeobjekte“, um die Aktivierung abzuschließen. | machine | Shown when macOS is holding the login item for user approval |
| `settings.menuBar` | Menu Bar | Menüleiste | machine | General: section holding the menu bar icon toggle |
| `settings.menuBar.toggle` | Show Dock Tile in the menu bar | Dock Tile in der Menüleiste anzeigen | machine | General: toggle that adds Dock Tile's icon to the menu bar, listing the tiles and their apps |
| `settings.menuBar.toggleDescription` | Lists the tiles in your Dock and their apps. Dock Tile keeps running in the background while this is on. | Listet die Kacheln in deinem Dock und ihre Apps auf. Solange dies aktiv ist, läuft Dock Tile im Hintergrund weiter. | machine | General: caption under the menu bar icon toggle |
| `settings.popover` | Popover | Popover | machine | Section header and pane title for popover appearance settings |
| `settings.popover.configure` | Configure | Konfigurieren | machine | Label for the Grid/List panel switcher in popover settings |
| `settings.popover.configure.subtitle` | Each layout's settings are saved independently | Die Einstellungen jedes Layouts werden separat gesichert | machine | Subtitle explaining that Grid and List popover settings are stored separately |
| `settings.popover.footer` | These settings apply to every tile's popover. List view always shows labels. Animation follows your system Reduce Motion setting. | Diese Einstellungen gelten für das Popover jeder Kachel. Die Liste zeigt immer Beschriftungen. Die Animation folgt deiner Systemeinstellung „Bewegung reduzieren“. | machine | Explanatory footer under the popover settings form |
| `settings.popover.reduceMotion` | Animation is off because Reduce Motion is on in System Settings. | Die Animation ist aus, weil „Bewegung reduzieren“ in den Systemeinstellungen aktiviert ist. | machine | Caption shown under Animation when the system Reduce Motion setting forces it off |
| `settings.popover.section.tiles` | Tiles | Kacheln | machine | Section header for the per-item controls inside the popover settings |
| `sidebar.section.settings` | Settings | Einstellungen | machine | Sidebar section header for the inline app settings panes |
| `sidebar.section.tiles` | Tiles | Kacheln | machine | Sidebar section header for the list of dock tiles |
| `sidebar.title` | Dock Tile | Dock Tile | machine | Navigation title for sidebar |
| `smartAdd.identity.browse` | Browse | Surfen | machine | Smart Add: suggested tile name for browsers |
| `smartAdd.identity.chat` | Chat | Chatten | machine | Smart Add: suggested tile name for social apps |
| `smartAdd.identity.ship` | Ship | Entwickeln | machine | Smart Add: suggested tile name for developer tools |
| `smartAdd.identity.together` | Together | Zusammen | machine | Smart Add: suggested tile name for apps opened together |
| `smartAdd.identity.watch` | Watch | Schauen | machine | Smart Add: suggested tile name for video apps |
| `smartAdd.identity.work` | Work | Arbeiten | machine | Smart Add: suggested tile name for productivity apps |
| `smartAdd.privacyFootnote` | Learned on your Mac. Never leaves your device. | Auf deinem Mac ermittelt. Verlässt nie dein Gerät. | machine | Footer note stating Smart Add suggestions are computed on-device only |
| `smartAdd.provenanceBanner` | Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to your Dock. | Von Smart Add aus deinen zuletzt verwendeten Apps erstellt. Benenne sie um, ändere ihr Aussehen oder die Apps – und füge sie dann deinem Dock hinzu. | machine | Banner shown atop Tile Detail when a tile was just created by Smart Add |
| `smartAdd.reason.byCategory` | By category | Nach Kategorie | machine | Reason chip — apps grouped by their app category |
| `smartAdd.reason.mostUsed` | Most used this week | Meistgenutzt diese Woche | machine | Reason chip — the most-used cluster this week |
| `smartAdd.reason.openedTogether` | Opened together | Zusammen geöffnet | machine | Reason chip — apps repeatedly opened in the same session |
| `smartAdd.settings.sectionHeader` | Smart Add | Smart Add | machine | General settings section header for the Smart Add toggle |
| `smartAdd.settings.toggleDescription` | Learned on your Mac. Never leaves your device. | Auf deinem Mac ermittelt. Verlässt nie dein Gerät. | machine | General: Smart Add toggle description |
| `smartAdd.settings.toggleTitle` | Suggest tiles from my apps | Kacheln aus meinen Apps vorschlagen | machine | General: Smart Add toggle title |
| `smartAdd.title` | Add a Tile | Kachel hinzufügen | machine | Header title of the Smart Add suggestion sheet |
| `subtitle.chooseColour` | Choose a background colour for your tile | Wähle eine Hintergrundfarbe für deine Kachel | machine | Subtitle for colour picker section |
| `subtitle.configureToAdd` | Configure to add apps | Konfigurieren, um Apps hinzuzufügen | machine | Subtitle in empty state (grid view only) |
| `subtitle.iconSize` | Adjust the size of your icon within the tile | Passe die Größe des Symbols in der Kachel an | machine | Subtitle for icon size section |
| `symbolCategory.accessibility` | Accessibility | Bedienungshilfen | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.all` | All | Alle | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.arrows` | Arrows | Pfeile | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.automotive` | Automotive | Automobil | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.cameraandphotos` | Camera & Photos | Kamera & Fotos | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.commerce` | Commerce | Handel | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.communication` | Communication | Kommunikation | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.connectivity` | Connectivity | Verbindungen | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.devices` | Devices | Geräte | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.draw` | Draw | Zeichnen | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.editing` | Editing | Bearbeitung | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.fitness` | Fitness | Fitness | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.gaming` | Gaming | Spiele | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.health` | Health | Gesundheit | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.home` | Home | Zuhause | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.human` | Human | Menschen | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.indices` | Indices | Indizes | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.keyboard` | Keyboard | Tastatur | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.maps` | Maps | Karten | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.math` | Maths | Mathematik | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.media` | Media | Medien | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.multicolor` | Multicolour | Bunt | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.nature` | Nature | Natur | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.objectsandtools` | Objects & Tools | Objekte & Werkzeuge | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.privacyandsecurity` | Privacy & Security | Datenschutz & Sicherheit | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.shapes` | Shapes | Formen | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.textformatting` | Text Formatting | Textformatierung | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.time` | Time | Zeit | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.transportation` | Transportation | Transport | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.variable` | Variable | Variabel | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.weather` | Weather | Wetter | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.whatsnew` | What's New | Neue Funktionen | machine | Symbol picker: section header (SF Symbols category) |
| `tab.emoji` | Emoji | Emoji | machine | Emoji tab label |
| `tab.symbol` | Symbol | Symbol | machine | Symbol tab label |
| `title.customiseTile` | Customise Tile | Kachel anpassen | machine | Title of the Customise Tile inspector beside Tile Detail |
| `title.deleteTile` | Delete Tile | Kachel löschen | machine | Alert title for delete confirmation |
| `title.revertToDock` | Revert to Dock Version? | Auf Dock-Version zurücksetzen? | machine | Alert title: discard the tile's unapplied edits and go back to the version in the Dock |
| `tooltip.createNewTile` | Create new tile | Neue Kachel erstellen | machine | Tooltip when add button is enabled |
| `tooltip.editFirst` | Edit current tile before creating another | Bearbeite die aktuelle Kachel, bevor du eine weitere erstellst | machine | Tooltip when add button is disabled |
| `button.addATile` | Add a Tile… | Kachel hinzufügen … | machine | Sidebar + / empty state: opens the Add a Tile dialog |
| `sidebar.dockTileSection` | Dock Tile | Dock Tile | machine | Sidebar section holding About |
| `settings.addingTiles` | Adding Tiles | Kacheln hinzufügen | machine | General: section holding the Smart Add toggle and the Add a Tile row |
| `about.title` | About | Info | machine | About pane title |
| `about.version` | Version %@ | Version %@ | machine | About: version line |
| `about.website` | Website | Website | machine | About: website row label |
| `about.feedbackTitle` | Found a bug or have an idea? | Einen Fehler gefunden oder eine Idee? | machine | About: feedback card title |
| `about.feedbackBody` | Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal. | Feedback geht direkt an den Entwickler. Die Diagnose enthält ein Protokoll dessen, was die App und ihre Kacheln getan haben – nichts Persönliches. | machine | About: feedback card body |
| `about.sendFeedback` | Send Feedback… | Feedback senden … | machine | About: opens the feedback email |
| `about.alsoFrom` | Also from Happy Machines | Mehr von Happy Machines | machine | About: studio section header |
| `about.studioTitle` | Made by Happy Machines Company | Entwickelt von Happy Machines Company | machine | About: studio row title |
| `about.studioSubtitle` | A tiny product studio building nifty Mac apps that each fix one thing well. | Ein kleines Produktstudio, das clevere Mac-Apps entwickelt, die jeweils eine Sache richtig gut lösen. | machine | About: studio row subtitle |
| `about.spadesTitle` | Spades Audio | Spades Audio | machine | About: sibling product row title |
| `about.spadesSubtitle` | Per-app volume, EQ and output control for your Mac, from the menu bar. | Lautstärke, EQ und Ausgabe pro App für deinen Mac – direkt aus der Menüleiste. | machine | About: sibling product subtitle |
| `about.learnMore` | Learn More… | Weitere Infos … | machine | About: opens spadesaudio.com |
| `menu.aboutDockTile` | About Dock Tile | Über Dock Tile | machine | App menu |
| `popover.editing.remove` | Remove | Entfernen | machine | Context menu / remove badge in the tile editor |
| `section.inThisTile` | In This Tile | In dieser Kachel | machine | Tile Detail: apps section header |
| `label.editorHint` | Hover to remove · Drag to reorder | Darüberfahren zum Entfernen · Ziehen zum Sortieren | machine | Tile Detail: apps section caption |
| `tooltip.deleteTile` | Delete Tile | Kachel löschen | machine | Tile Detail: trash button tooltip |
| `smartAdd.blankTitle` | Create a blank tile | Leere Kachel erstellen | machine | Add a Tile: blank row title |
| `smartAdd.blankSubtitle` | Name it, pick an icon and add apps yourself. | Gib ihr einen Namen, wähle ein Symbol und füge selbst Apps hinzu. | machine | Add a Tile: blank row subtitle |
| `smartAdd.orStartFrom` | or start from what you use | oder starte mit dem, was du nutzt | machine | Add a Tile: rule between blank row and suggestions |
| `smartAdd.noSuggestions` | No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General. | Noch keine Vorschläge – Dock Tile lernt aus den Apps, die du öffnest. Du kannst das unter „Allgemein“ deaktivieren. | machine | Add a Tile: empty suggestions note |
| `label.addAppsTooltip` | Add apps or folders to this tile | Apps oder Ordner zu dieser Kachel hinzufügen | machine | Tooltip on the + Add button above the tile editor's popover preview. |
| `empty.createFirstTileDescription` | Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use. | Fasse Apps und Ordner hinter einem Symbol im Dock zusammen. Beginne mit einer leeren Kachel oder mit einem Vorschlag auf Basis der Apps, die du nutzt. | machine | Zero-tiles description |
| `popover.editing.noAppsTitle` | No apps yet | Noch keine Apps | machine | Tile editor: empty popover preview, title line. |
| `popover.editing.noAppsSubtitle` | Use Add to choose what opens from this tile. | Wähle mit „Hinzufügen“ aus, was sich über diese Kachel öffnen lässt. | machine | Tile editor: empty popover preview, subtitle line. |
| `about.diagnosticsBody` | A log of what the app and its tiles did. Attach it to an email when something looks wrong — it contains nothing personal. | Ein Protokoll dessen, was die App und ihre Kacheln getan haben. Hänge es an eine E-Mail an, wenn etwas nicht stimmt – es enthält nichts Persönliches. | machine | About: Copy Diagnostics row description. |
| `about.feedbackRowBody` | Feedback goes straight to the developer. | Feedback geht direkt an den Entwickler. | machine | About: Send Feedback row description. |
| `about.diagnosticsTitle` | Diagnostics | Diagnose | machine | About: Copy Diagnostics row label. |
| `button.copy` | Copy | Kopieren | machine | Generic Copy button label. |
| `tooltip.openSettings` | Settings | Einstellungen | machine | Tooltip for the settings toolbar button |
| `tooltip.revertToDock` | Revert to Dock Version | Auf Dock-Version zurücksetzen | machine | Tile Detail: revert button tooltip and accessibility label, and the File menu item — discards unapplied edits, restoring the version the tile's Dock icon was built from |
| `tooltip.toggleCustomiseTile` | Toggle Customise Tile | Kachel anpassen ein-/ausblenden | machine | Tooltip and accessibility label of the toolbar button that opens or closes the Customise Tile inspector |
| `tooltip.toggleCustomiser` | Toggle Customiser | Anpassungsbereich ein-/ausblenden | machine | Tooltip and accessibility label of the Tile Detail icon, which opens or closes the Customise Tile inspector when clicked |
| `translation.helpImprove` | Help Improve… | Verbessern helfen … | machine | Button: opens the language's review sheet on GitHub |
| `translation.invite.message` | This translation was made by a machine and has not yet been checked by a native speaker. If something reads wrong, you can fix it on GitHub — no coding needed. | Diese Übersetzung wurde maschinell erstellt und noch nicht muttersprachlich geprüft. Wenn etwas falsch klingt, kannst du es auf GitHub korrigieren – ganz ohne Programmierkenntnisse. | machine | One-time alert message inviting translation review |
| `translation.invite.title` | Dock Tile now speaks your language | Dock Tile spricht jetzt deine Sprache | machine | One-time alert title on first launch in a machine-translated language |
| `translation.reviewLine` | Machine translated. Not yet checked by a native speaker. | Maschinell übersetzt. Noch nicht muttersprachlich geprüft. | machine | About: translation row description. Reviewers replace this in their language with who reviewed it, e.g. 'Reviewed by @handle'. |
| `translation.title` | Translation | Übersetzung | machine | About: translation row label (shown only when the UI runs in a non-English language) |
