# Dock Tile — Français (fr)

How to review: [docs/l10n/README.md](README.md). Edit the **Translation** column, set
**Status** to `reviewed` for every row you checked (changed or not), then "Propose changes".
Status values: `machine` (not yet checked by a person), `reviewed`, `todo` (no translation yet).
Keep `%@`-style placeholders exactly as they are. `\n` means a line break, `\|` a pipe.

| Key | English | Translation | Status | Context |
|---|---|---|---|---|
| `alert.applyPopover.message` | Dock Tile will rebuild your pinned tiles with the new popover look and briefly restart the Dock. Your other Dock items won't be affected. | Dock Tile va reconstruire vos tuiles du Dock avec le nouvel aspect de la fenêtre surgissante et redémarrer brièvement le Dock. Vos autres éléments du Dock ne seront pas modifiés. | machine | Confirmation message warning the Dock will restart when applying popover settings |
| `alert.applyPopover.title` | Apply to your Dock tiles? | Appliquer à vos tuiles du Dock ? | machine | Confirmation title before rebuilding tiles to apply popover appearance settings |
| `alert.configUnreadable.message` | Your tiles haven't been changed. Dock Tile couldn't open its settings file and will quit. Check that you can open %@, then open Dock Tile again. | Vos tuiles n’ont pas été modifiées. Dock Tile n’a pas pu ouvrir son fichier de réglages et va se fermer. Vérifiez que vous pouvez ouvrir %@, puis rouvrez Dock Tile. | machine | Launch alert message when the tile settings file can't be read; %@ = the file's full path. The app quits when the alert closes. |
| `alert.configUnreadable.quit` | Quit | Quitter | machine | Only button of the can't-read-tiles launch alert; quits Dock Tile |
| `alert.configUnreadable.title` | Dock Tile Can't Read Your Tiles | Dock Tile ne peut pas lire vos tuiles | machine | Launch alert title: the tile settings file exists but could not be opened; the app quits after it |
| `alert.deleteTile.message` | This will permanently delete the tile and remove it from the dock. | La tuile sera définitivement supprimée et retirée du Dock. | machine | Delete-tile confirmation message |
| `alert.missingApps.message` | Some apps in your tiles can't be found on this Mac. Remove them from your tiles? | Certaines apps de vos tuiles sont introuvables sur ce Mac. Les retirer de vos tuiles ? | machine | Alert message offering to remove uninstalled apps from tiles |
| `alert.missingApps.title` | Some apps are no longer installed | Certaines apps ne sont plus installées | machine | Alert title when apps referenced by tiles can't be found on disk |
| `alert.missingAppsScan.foundMessage` | These apps can't be found on this Mac: | Ces apps sont introuvables sur ce Mac : | machine | Intro line of the manual scan results dialog; a list of tiles/apps follows |
| `alert.missingAppsScan.noneMessage` | Every app in your tiles is currently installed. | Toutes les apps de vos tuiles sont installées. | machine | Message of the manual scan dialog when nothing is missing |
| `alert.missingAppsScan.noneTitle` | No Missing Apps | Aucune app manquante | machine | Title of the manual scan dialog when every tile app is installed |
| `alert.relocate.blockingMessage` | Dock Tile can't create or update this tile because it's running from a temporary, read-only location. This happens when the app is launched from Downloads. Move Dock Tile to your Applications folder and try again. | Dock Tile ne peut pas créer ni mettre à jour cette tuile, car il s’exécute depuis un emplacement temporaire en lecture seule. Cela se produit lorsque l’app est ouverte depuis le dossier Téléchargements. Déplacez Dock Tile dans votre dossier Applications, puis réessayez. | machine | Message shown when a tile action is blocked because the app is translocated |
| `alert.relocate.checkbox` | Don't ask again | Ne plus demander | machine | Checkbox to suppress future move-to-Applications nudges |
| `alert.relocate.message` | Dock Tile is running from outside your Applications folder. macOS may run it from a temporary, read-only location, which can stop new tiles from being created. Move it to Applications to make sure everything works. | Dock Tile s’exécute en dehors de votre dossier Applications. macOS peut l’exécuter depuis un emplacement temporaire en lecture seule, ce qui peut empêcher la création de nouvelles tuiles. Déplacez-le dans Applications pour que tout fonctionne correctement. | machine | Message of the launch-time nudge to move the app to Applications |
| `alert.relocate.title` | Move Dock Tile to Applications? | Déplacer Dock Tile dans Applications ? | machine | Title of the prompt asking the user to move the app into the Applications folder |
| `alert.restartDock.checkbox` | Don't show this again | Ne plus afficher ce message | machine | Checkbox label to suppress future Dock restart alerts |
| `alert.restartDock.message` | Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected. | Dock Tile redémarre le Dock pour appliquer les modifications. Cela se produit chaque fois que vous ajoutez, mettez à jour ou supprimez des tuiles. Vos éléments du Dock actuels ne seront pas modifiés. | machine | Alert message explaining Dock restart |
| `alert.restartDock.title` | Dock Restart Required | Redémarrage du Dock nécessaire | machine | Alert title when Dock restart is required |
| `app.name` | Dock Tile | Dock Tile | machine | App display name |
| `button.add` | Add | Ajouter | machine | Add button label in file picker |
| `button.addToDock` | Add to Dock | Ajouter au Dock | machine | Button to add tile to Dock |
| `button.applyToTiles` | Apply | Appliquer | machine | Confirm button that rebuilds tiles to apply popover settings |
| `button.back` | Back | Retour | machine | Back button label |
| `button.cancel` | Cancel | Annuler | machine | Cancel button in alerts |
| `button.checkForUpdates` | Check for Updates… | Rechercher les mises à jour… | machine | Button that triggers a manual Sparkle update check |
| `button.checkNow` | Check Now | Vérifier maintenant | machine | Settings → Software Update: button that triggers a manual Sparkle update check |
| `button.confirm` | Confirm | Confirmer | machine | Confirm button for alert dialogs |
| `button.createNewTile` | Create New Tile | Créer une tuile | machine | Smart Add sheet — neutral button that starts a blank tile instead of a suggestion |
| `button.delete` | Delete | Supprimer | machine | Delete button |
| `button.done` | Done | Terminé | machine | Done button |
| `button.duplicate` | Duplicate | Dupliquer | machine | Duplicate button in context menu |
| `button.keep` | Keep | Conserver | machine | Button to keep uninstalled apps in tiles (dismiss the removal prompt) |
| `button.moveToApplications` | Move to Applications | Déplacer dans Applications | machine | Button that moves the app into the Applications folder |
| `button.newTile` | New Tile | Nouvelle tuile | machine | Button to create first tile on empty state |
| `button.notNow` | Not Now | Plus tard | machine | Dismiss button for the non-blocking move-to-Applications nudge |
| `button.openAccessibilitySettings` | Open Accessibility Settings… | Ouvrir les réglages Accessibilité… | machine | Button that opens the Accessibility pane in System Settings (Reduce Motion) |
| `button.openLoginItems` | Open Login Items Settings… | Ouvrir les réglages Ouverture… | machine | Button that opens System Settings Login Items for approval |
| `button.remove` | Remove | Retirer | machine | Remove button |
| `button.removeAll` | Remove All | Tout retirer | machine | Button to remove all missing apps from tiles at once |
| `button.removeFromDock` | Remove from Dock | Supprimer du Dock | machine | Button to remove tile from Dock |
| `button.resetToDefaults` | Reset to Defaults | Rétablir les valeurs par défaut | machine | Button that restores popover appearance settings to their defaults |
| `button.reviewInTiles` | Review in Tiles | Vérifier dans les tuiles | machine | Button that navigates to the first tile containing a missing app |
| `button.save` | Save | Enregistrer | machine | Primary toolbar button that commits the popover appearance settings |
| `button.saving` | Applying… | Mise à jour… | machine | Loading label on the Save button while applying settings to Dock tiles |
| `button.scanForMissingApps` | Scan | Analyser | machine | Settings button that scans tiles for moved/uninstalled apps |
| `button.update` | Update | Mettre à jour | machine | Update button when tile is already in Dock |
| `button.useThisTile` | Use This Tile | Utiliser cette tuile | machine | Smart Add sheet — button that creates a pre-filled tile from a suggestion |
| `emojiCategory.activity` | Activity | Activités | machine | Emoji picker: section header |
| `emojiCategory.animalsNature` | Animals & Nature | Animaux et nature | machine | Emoji picker: section header |
| `emojiCategory.foodDrink` | Food & Drink | Nourriture et boissons | machine | Emoji picker: section header |
| `emojiCategory.objects` | Objects | Objets | machine | Emoji picker: section header |
| `emojiCategory.people` | People | Personnes | machine | Emoji picker: section header |
| `emojiCategory.symbols` | Symbols | Symboles | machine | Emoji picker: section header |
| `emojiCategory.travelPlaces` | Travel & Places | Voyages et lieux | machine | Emoji picker: section header |
| `empty.createFirstTile` | Create Your First Tile | Créez votre première tuile | machine | Header text for empty state |
| `empty.detail` | Detail | Détails | machine | Placeholder text in detail view |
| `empty.noApps` | No apps configured | Aucune app configurée | machine | Empty state text when no apps configured |
| `empty.noTiles` | No Tiles | Aucune tuile | machine | Empty state text in sidebar |
| `error.appTranslocated` | Dock Tile is running from a temporary, read-only location and can't create tiles. Move it to your Applications folder and try again. | Dock Tile s’exécute depuis un emplacement temporaire en lecture seule et ne peut pas créer de tuiles. Déplacez-le dans votre dossier Applications, puis réessayez. | machine | Error when the app is translocated and cannot generate helper bundles |
| `error.bundleBuildInProgress` | This tile is already being rebuilt. Wait for that to finish, then try again. | Cette tuile est déjà en cours de reconstruction. Attendez la fin de l’opération, puis réessayez. | machine | Error when a second build is requested for a tile whose helper bundle is already being built |
| `error.dockChangeNotKept` | The Dock didn't keep this change. Try again. | Le Dock n’a pas conservé cette modification. Réessayez. | machine | Error when Dock Tile wrote a change to the Dock (add, update or hide a tile) but the Dock did not keep it, even after one retry |
| `error.failedToCodeSign` | Failed to code sign helper bundle | Échec de la signature du code du paquet auxiliaire | machine | Error when code signing fails |
| `error.failedToCopyBundle` | Failed to copy bundle | Échec de la copie du paquet | machine | Error when bundle copy fails |
| `error.failedToReadInfoPlist` | Failed to read Info.plist | Impossible de lire Info.plist | machine | Error when Info.plist cannot be read |
| `error.failedToWriteInfoPlist` | Failed to write Info.plist | Impossible d’écrire Info.plist | machine | Error when Info.plist cannot be written |
| `error.mainAppNotFound` | Main Dock Tile.app not found | App principale Dock Tile.app introuvable | machine | Error when main app bundle cannot be found |
| `filePicker.message` | Select one or more applications or folders to add | Sélectionnez une ou plusieurs apps ou un ou plusieurs dossiers à ajouter | machine | Message in file picker dialog |
| `iconWeight.bold` | Bold | Gras | machine | Customise: icon weight picker option |
| `iconWeight.heavy` | Heavy | Lourd | machine | Customise: icon weight picker option |
| `iconWeight.light` | Light | Léger | machine | Customise: icon weight picker option |
| `iconWeight.medium` | Medium | Moyen | machine | Customise: icon weight picker option |
| `iconWeight.regular` | Regular | Courant | machine | Customise: icon weight picker option |
| `iconWeight.semibold` | Semibold | Semi-gras | machine | Customise: icon weight picker option |
| `label.apps.arrangement` | Arrangement | Disposition | machine | Customise Tile: Apps card row — the grid the face uses |
| `label.apps.arrangement.threeByThree` | 3 × 3 | 3 × 3 | machine | Customise Tile: Arrangement value for 5 or more apps |
| `label.apps.arrangement.twoByTwo` | 2 × 2 | 2 × 2 | machine | Customise Tile: Arrangement value for 2–4 apps |
| `label.apps.glass` | A glass folder that follows Light and Dark Mode. | Un dossier en verre qui suit le mode clair et le mode sombre. | machine | Customise Tile: fixed sentence after the Apps caption (decided 2026-10-19: the dark appearance is system-dark) |
| `label.apps.header` | Apps | Apps | machine | Customise Tile: group header above the Apps card |
| `label.apps.note.all` | Shows all %lld apps, in tile order. | Affiche les %lld apps, dans l’ordre de la tuile. | machine | Customise Tile: Apps caption, 2–9 apps; %lld = app count |
| `label.apps.note.firstNine` | Shows the first 9 of %lld apps, in tile order. | Affiche les 9 premières apps sur %lld, dans l’ordre de la tuile. | machine | Customise Tile: Apps caption, more than nine apps; %lld = app count |
| `label.apps.note.none` | No apps yet — use Add under In This Tile. | Aucune app pour l’instant — ajoutez-en avec « Ajouter » dans la section « Dans cette tuile ». | machine | Customise Tile: Apps caption when the tile has no apps (builder copy, not in the handoff) |
| `label.apps.note.one` | Shows the only app in this tile. | Affiche la seule app de cette tuile. | machine | Customise Tile: Apps caption, one app |
| `label.apps.shown` | Shown | Affichées | machine | Customise Tile: Apps card row — how many apps the face shows |
| `label.apps.shownValue` | %1$lld of %2$lld | %1$lld sur %2$lld | machine | Customise Tile: Apps card Shown value, e.g. 9 of 12; %1$lld = shown, %2$lld = total (positional so a language may reorder them) |
| `label.appsBackground` | Dock Icon Background | Fond de l’icône du Dock | machine | App Grid inspector section for per-tile plate settings |
| `label.appsBackground.automatic` | Follow System | Suivre le système | machine | App Grid background follows the macOS icon appearance |
| `label.appsBackground.charcoal` | Dark Grey | Gris foncé | machine | Fixed dark background for an App Grid icon |
| `label.appsBackground.custom` | Custom Colour | Couleur personnalisée | machine | Native colour picker for an App Grid icon background |
| `label.appsBackground.hint` | Applies to this tile only. | S’applique uniquement à cette tuile. | machine | Caption under the App Grid background menu: the choice affects only this tile |
| `label.appsBackground.light` | Light | Clair | machine | Fixed light background for an App Grid icon |
| `label.appsFace.accessibility` | Apps face: showing %lld of this tile's apps | Vue des apps : affiche %lld apps de cette tuile | machine | VoiceOver label for a tile preview showing the Apps face; %lld = number of app icons shown |
| `label.background` | Background | Arrière-plan | machine | Customise Tile: background row label |
| `label.background.colour` | Colour | Couleur | machine | Customise Tile: Colour background chip |
| `label.background.colour.accessibility` | Colour, filled with your colour | Couleur, tuile remplie de votre couleur | machine | VoiceOver label for the Colour chip |
| `label.background.hint.colour` | Filled with your colour | Remplie de votre couleur | machine | Customise Tile: hint under Background when Colour |
| `label.background.hint.emojiColours` | Emoji keep their own colours. | Les emoji gardent leurs propres couleurs. | machine | Customise Tile: appended to the Background caption for an Emoji tile |
| `label.background.hint.mono` | White in Light Mode, black in Dark Mode | Blanche en mode clair, noire en mode sombre | machine | Customise Tile: hint under Background when Mono |
| `label.background.hint.mono.static` | White tile with a coloured symbol | Tuile blanche avec un symbole en couleur | machine | Customise Tile: hint under Background when Mono on macOS 15 (static white tile) |
| `label.background.mono` | Mono | Mono | machine | Customise Tile: Mono background chip |
| `label.background.mono.accessibility` | Mono, white in Light Mode and black in Dark Mode | Mono, blanche en mode clair et noire en mode sombre | machine | VoiceOver label for the Mono chip |
| `label.background.mono.static.accessibility` | Mono, a white tile with a coloured symbol | Mono, une tuile blanche avec un symbole en couleur | machine | VoiceOver label for the Mono chip on macOS 15 |
| `label.colour` | Colour | Couleur | machine | Label for colour picker section |
| `label.colour.hint.deepened` | Deepened slightly so the symbol stays clear | Légèrement assombrie pour que le symbole reste net | machine | Customise Tile: colour hint when the fill was darkened for contrast |
| `label.colour.hint.emoji` | Emoji keep their own colours | Les emoji gardent leurs propres couleurs | machine | Customise Tile: colour hint, Mono emoji tile (row disabled) |
| `label.colour.hint.fills` | Fills the tile | Remplit la tuile | machine | Customise Tile: colour hint, Colour tile |
| `label.colour.hint.tints` | Tints the symbol | Colore le symbole | machine | Customise Tile: Colour card caption for a Mono tile |
| `label.colour.hint.toned` | Toned for Light and Dark | Ajustée pour les modes clair et sombre | machine | Customise Tile: colour hint, Mono tile |
| `label.colour.hint.toned.static` | Toned to stay clear on white | Ajustée pour rester nette sur fond blanc | machine | Customise Tile: colour hint, Mono tile on macOS 15 |
| `label.iconSize` | Icon Size | Taille de l’icône | machine | Compact label for the icon size stepper (side-by-side with icon weight) |
| `label.iconWeight` | Icon Weight | Graisse de l’icône | machine | Label for the SF Symbol weight picker |
| `label.missingAppsScan` | Missing Apps | Apps manquantes | machine | Settings row title for the missing-app scan |
| `label.missingAppsScanDescription` | Check your tiles for apps that have been moved or uninstalled. | Recherchez dans vos tuiles les apps qui ont été déplacées ou désinstallées. | machine | Settings row description for the missing-app scan |
| `label.notInstalled` | Not installed | Non installée | machine | Badge/kind text shown for an app whose bundle is no longer on disk |
| `label.popover.animation` | Animation | Animation | machine | Label for the popover animation segmented control |
| `label.popover.highlightOnHover` | Highlight on Hover | Surbrillance au survol | machine | Toggle label — show a background fill on the hovered item |
| `label.popover.layout` | Layout | Disposition | machine | Label for the Grid/List preview toggle in popover settings |
| `label.popover.listAlwaysLabelled` | List view always shows labels | La vue Liste affiche toujours les noms | machine | Hint shown beside the disabled Show Labels control when previewing List |
| `label.popover.showLabels` | Show Labels | Afficher les noms | machine | Toggle label — show app names under grid icons |
| `label.popover.size` | Popover Size | Taille de la fenêtre | machine | Label for the popover size segmented control |
| `label.popover.spacing` | Spacing | Espacement | machine | Label for the popover item spacing segmented control |
| `label.popover.tileSize` | Tile Size | Taille des tuiles | machine | Label for the icon/cell size control inside the popover |
| `label.shareAnalytics` | Share anonymous usage data | Partager des données d’utilisation anonymes | machine | Label for the analytics opt-out toggle in Settings |
| `label.shareAnalyticsDescription` | Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected. | Aidez à améliorer Dock Tile en envoyant des données d’utilisation et des rapports de plantage anonymes. Aucune donnée personnelle n’est collectée. | machine | Explanation under the analytics toggle |
| `label.addAppsAndFolders` | Add Apps & Folders | Ajouter des apps et des dossiers | machine | Tooltip on the Add button in Tile Detail's In This Tile section |
| `label.appSwitcherNeedsShowTile` | Turn on Show Tile first — this only applies while the tile is in the Dock. | Activez d’abord « Afficher la tuile » — ce réglage ne s’applique que lorsque la tuile est dans le Dock. | machine | Tooltip on the disabled Show in App Switcher toggle when the tile is hidden |
| `label.showInAppSwitcher` | Show in App Switcher | Afficher dans le sélecteur d’app | machine | Label for app switcher toggle |
| `label.showTile` | Show Tile | Afficher la tuile | machine | Label for show tile toggle |
| `label.softwareUpdate` | Software Update | Mise à jour logicielle | machine | Title of the software-update row in General settings |
| `label.softwareUpdateDescription` | You’re using version %@. Dock Tile checks for updates automatically. | Vous utilisez la version %@. Dock Tile recherche automatiquement les mises à jour. | machine | Description under the software-update row; %@ is the current version |
| `label.startAtLogin` | Start tiles at login | Lancer les tuiles avec la session | machine | Label for the start-at-login toggle in Settings |
| `label.startAtLoginDescription` | Keep your tiles ready in the Dock so they respond instantly after you restart your Mac. | Gardez vos tuiles prêtes dans le Dock pour qu’elles répondent instantanément après le redémarrage de votre Mac. | machine | Explanation under the start-at-login toggle |
| `label.style.appPreview` | App Grid | Grille d’apps | machine | Customise Tile: Style picker card for the Apps face |
| `label.symbolColour` | Symbol Colour | Couleur du symbole | machine | Customise Tile: colour row label for a Mono tile |
| `label.tileColour` | Tile Colour | Couleur de la tuile | machine | Customise Tile: Colour card header for a Colour tile |
| `label.tileIcon` | Tile Icon | Icône de la tuile | machine | Label for tile icon section |
| `label.tileIconSize` | Tile Icon Size | Taille de l’icône de la tuile | machine | Label for tile icon size |
| `label.tileName` | Tile Name | Nom de la tuile | machine | Label for tile name field |
| `layout.grid` | Grid | Grille | machine | Grid layout option |
| `layout.list` | List | Liste | machine | List layout option |
| `itemMenu.forceQuit` | Force Quit | Forcer à quitter | machine | Popover item context menu: force quit (shown while Option is held) |
| `itemMenu.getInfo` | Get Info | Lire les informations | machine | Popover item context menu: open Finder's Get Info window |
| `itemMenu.hide` | Hide | Masquer | machine | Popover item context menu: hide the running app |
| `itemMenu.open` | Open | Ouvrir | machine | Popover item context menu: open the app or folder |
| `itemMenu.quickLook` | Quick Look | Coup d’œil | machine | Popover item context menu: preview the item with Quick Look |
| `itemMenu.quit` | Quit | Quitter | machine | Popover item context menu: quit the running app |
| `itemMenu.share` | Share… | Partager… | machine | Popover item context menu: open the share sheet for a folder |
| `itemMenu.showInFinder` | Show in Finder | Afficher dans le Finder | machine | Popover item context menu: reveal the item in Finder |
| `menu.configure` | Configure... | Configurer… | machine | Menu item to configure tile (opens main app) |
| `menu.configureTile` | Configure Tile | Configurer la tuile | machine | Tooltip for gear icon in popover |
| `menu.copyDiagnostics` | Copy Diagnostics | Copier les diagnostics | machine | File menu item that copies recent diagnostic logs to the clipboard |
| `menu.hideInspector` | Hide Inspector | Masquer l’inspecteur | machine | View menu item (Hide Inspector, ⌥⌘I) that closes the Customise Tile inspector |
| `menu.newTile` | New Tile | Nouvelle tuile | machine | Menu item to create a new tile |
| `menu.noAppsConfigured` | No apps configured | Aucune app configurée | machine | Dock menu: disabled row when the tile has no apps |
| `menu.noConfiguration` | No configuration | Aucune configuration | machine | Dock menu: disabled row when the tile's config cannot be found |
| `menu.openInFinder` | Open in Finder | Ouvrir dans le Finder | machine | Menu item to open in Finder |
| `menu.options` | Options | Options | machine | Section divider in menu |
| `menu.settings` | Settings… | Réglages… | machine | App menu item that opens the inline Settings pane (⌘,) |
| `menu.showInspector` | Show Inspector | Afficher l’inspecteur | machine | View menu item (Show Inspector, ⌥⌘I) that opens the Customise Tile inspector |
| `popover.option.animation.default` | Default | Par défaut | machine | Animation tier — default |
| `popover.option.animation.fast` | Fast | Rapide | machine | Animation tier — fast |
| `popover.option.animation.none` | None | Aucune | machine | Animation tier — none |
| `popover.option.comfortable` | Comfortable | Confortable | machine | Spacing tier — comfortable |
| `popover.option.compact` | Compact | Compact | machine | Spacing tier — compact |
| `popover.option.large` | Large | Grande | machine | Size tier — large |
| `popover.option.medium` | Medium | Moyenne | machine | Size tier — medium |
| `popover.option.small` | Small | Petite | machine | Size tier — small |
| `popover.option.spacious` | Spacious | Aéré | machine | Spacing tier — spacious |
| `search.emojis` | Search emojis | Rechercher des emoji | machine | Search placeholder for emojis |
| `search.symbols` | Search symbols | Rechercher des symboles | machine | Search placeholder for symbols |
| `settings.dockLock` | Dock Lock | Verrouillage du Dock | machine | Section header for the Dock Lock feature in Settings |
| `settings.dockLock.accessibilityGranted` | Accessibility access granted | Accès Accessibilité autorisé | machine | Status shown when Accessibility permission is granted |
| `settings.dockLock.accessibilityNeeded` | Accessibility access required | Accès Accessibilité requis | machine | Status shown when Accessibility permission is missing |
| `settings.dockLock.accessibilityNeededDetail` | Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings. | Dock Tile a besoin de l’accès Accessibilité pour garder le Dock en place. Activez Dock Tile dans Réglages Système. | machine | Explanation of why Accessibility access is needed |
| `settings.dockLock.anchor` | Keep Dock on | Garder le Dock sur | machine | Label for the anchor display picker |
| `settings.dockLock.defaultDisplay` | Default (follow macOS) | Par défaut (selon macOS) | machine | First option in the anchor picker — no lock, macOS default behaviour |
| `settings.dockLock.description` | Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose. | Empêchez le Dock de passer d’un écran à l’autre lorsque vous utilisez plusieurs écrans. Il reste sur l’écran de votre choix. | machine | Explanation under the Dock Lock toggle |
| `settings.dockLock.lockedTo` | Dock is locked to %@ | Le Dock est verrouillé sur %@ | machine | Indicator confirming the display the Dock is pinned to |
| `settings.dockLock.mainDisplay` | Main | principal | machine | Suffix marking the main display in the anchor picker |
| `settings.dockLock.moveFailed` | Couldn't move the Dock to %@. Make sure that display isn't mirrored, then try again. | Impossible de déplacer le Dock vers %@. Assurez-vous que cet écran n’est pas en recopie vidéo, puis réessayez. | machine | Error shown when the Dock could not be relocated |
| `settings.dockLock.moving` | Moving Dock to %@… | Déplacement du Dock vers %@… | machine | Progress message shown while the Dock is being relocated |
| `settings.dockLock.note` | Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays. | Fonctionne avec le Dock en bas, à gauche ou à droite. Le garder sur un écran réserve quelques pixels sur ce bord de vos autres écrans. | machine | Footnote describing Dock Lock behaviour and trade-off |
| `settings.dockLock.openSettings` | Open System Settings… | Ouvrir Réglages Système… | machine | Button that opens the Accessibility pane in System Settings |
| `settings.dockLock.primer.body` | Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens. | Le verrouillage du Dock garde le Dock sur l’écran de votre choix. Pour cela, Dock Tile a besoin de l’accès Accessibilité afin d’empêcher macOS de déplacer le Dock vers vos autres écrans. | machine | Explanation in the permission primer |
| `settings.dockLock.primer.continue` | Continue | Continuer | machine | Primary button in the permission primer that triggers the macOS dialog |
| `settings.dockLock.primer.notNow` | Not Now | Plus tard | machine | Secondary button in the permission primer that cancels enabling Dock Lock |
| `settings.dockLock.primer.reassurance` | Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time. | macOS vous demandera ensuite d’activer Dock Tile dans Réglages Système. Vous pourrez le désactiver à tout moment. | machine | Reassurance line in the permission primer about what happens next |
| `settings.dockLock.primer.title` | Allow Accessibility Access | Autoriser l’accès Accessibilité | machine | Title of the permission primer shown before requesting Accessibility |
| `settings.dockLock.retry` | Try Again | Réessayer | machine | Button to retry a failed Dock relocation |
| `settings.dockLock.singleDisplay` | Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it. | Connectez un deuxième écran pour utiliser le verrouillage du Dock. Avec un seul écran, le Dock reste exactement là où macOS le place. | machine | Note shown when only one display is connected |
| `settings.dockLock.toggle` | Lock Dock to one display | Verrouiller le Dock sur un écran | machine | Label for the Dock Lock enable toggle |
| `settings.general` | General | Général | machine | Title of the General settings pane |
| `settings.login.registrationFailed` | Couldn’t turn this on — macOS refused the registration. %@ | Impossible d’activer cette option — macOS a refusé l’enregistrement. %@ | machine | Shown under the Start tiles at login toggle when SMAppService registration failed; %@ is the system error |
| `settings.login.requiresApproval` | Approve Dock Tile in Login Items to finish enabling this. | Autorisez Dock Tile dans les réglages Ouverture pour terminer l’activation. | machine | Shown when macOS is holding the login item for user approval |
| `settings.popover` | Popover | Fenêtre surgissante | machine | Section header and pane title for popover appearance settings |
| `settings.popover.configure` | Configure | Configurer | machine | Label for the Grid/List panel switcher in popover settings |
| `settings.popover.configure.subtitle` | Each layout's settings are saved independently | Les réglages de chaque disposition sont enregistrés séparément | machine | Subtitle explaining that Grid and List popover settings are stored separately |
| `settings.popover.footer` | These settings apply to every tile's popover. List view always shows labels. Animation follows your system Reduce Motion setting. | Ces réglages s’appliquent à la fenêtre surgissante de chaque tuile. La vue Liste affiche toujours les noms. L’animation suit le réglage système « Réduire les animations ». | machine | Explanatory footer under the popover settings form |
| `settings.popover.reduceMotion` | Animation is off because Reduce Motion is on in System Settings. | L’animation est désactivée, car l’option « Réduire les animations » est activée dans Réglages Système. | machine | Caption shown under Animation when the system Reduce Motion setting forces it off |
| `settings.popover.section.tiles` | Tiles | Tuiles | machine | Section header for the per-item controls inside the popover settings |
| `sidebar.section.settings` | Settings | Réglages | machine | Sidebar section header for the inline app settings panes |
| `sidebar.section.tiles` | Tiles | Tuiles | machine | Sidebar section header for the list of dock tiles |
| `sidebar.title` | Dock Tile | Dock Tile | machine | Navigation title for sidebar |
| `smartAdd.identity.browse` | Browse | Naviguer | machine | Smart Add: suggested tile name for browsers |
| `smartAdd.identity.chat` | Chat | Discuter | machine | Smart Add: suggested tile name for social apps |
| `smartAdd.identity.ship` | Ship | Coder | machine | Smart Add: suggested tile name for developer tools |
| `smartAdd.identity.together` | Together | Ensemble | machine | Smart Add: suggested tile name for apps opened together |
| `smartAdd.identity.watch` | Watch | Regarder | machine | Smart Add: suggested tile name for video apps |
| `smartAdd.identity.work` | Work | Travailler | machine | Smart Add: suggested tile name for productivity apps |
| `smartAdd.privacyFootnote` | Learned on your Mac. Never leaves your device. | Appris sur votre Mac. Rien ne quitte votre appareil. | machine | Footer note stating Smart Add suggestions are computed on-device only |
| `smartAdd.provenanceBanner` | Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to your Dock. | Créée par Ajout intelligent à partir de vos apps récentes. Renommez-la, changez son style ou modifiez ses apps, puis ajoutez-la à votre Dock. | machine | Banner shown atop Tile Detail when a tile was just created by Smart Add |
| `smartAdd.reason.byCategory` | By category | Par catégorie | machine | Reason chip — apps grouped by their app category |
| `smartAdd.reason.mostUsed` | Most used this week | Les plus utilisées cette semaine | machine | Reason chip — the most-used cluster this week |
| `smartAdd.reason.openedTogether` | Opened together | Ouvertes ensemble | machine | Reason chip — apps repeatedly opened in the same session |
| `smartAdd.settings.sectionHeader` | Smart Add | Ajout intelligent | machine | General settings section header for the Smart Add toggle |
| `smartAdd.settings.toggleDescription` | Learned on your Mac. Never leaves your device. | Appris sur votre Mac. Rien ne quitte votre appareil. | machine | General: Smart Add toggle description |
| `smartAdd.settings.toggleTitle` | Suggest tiles from my apps | Suggérer des tuiles d’après mes apps | machine | General: Smart Add toggle title |
| `smartAdd.title` | Add a Tile | Ajouter une tuile | machine | Header title of the Smart Add suggestion sheet |
| `subtitle.chooseColour` | Choose a background colour for your tile | Choisissez une couleur d’arrière-plan pour votre tuile | machine | Subtitle for colour picker section |
| `subtitle.configureToAdd` | Configure to add apps | Configurez pour ajouter des apps | machine | Subtitle in empty state (grid view only) |
| `subtitle.iconSize` | Adjust the size of your icon within the tile | Ajustez la taille de votre icône dans la tuile | machine | Subtitle for icon size section |
| `symbolCategory.accessibility` | Accessibility | Accessibilité | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.all` | All | Tout | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.arrows` | Arrows | Flèches | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.automotive` | Automotive | Automobile | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.cameraandphotos` | Camera & Photos | Appareil photo et photos | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.commerce` | Commerce | Commerce | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.communication` | Communication | Communication | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.connectivity` | Connectivity | Connectivité | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.devices` | Devices | Appareils | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.draw` | Draw | Dessin | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.editing` | Editing | Édition | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.fitness` | Fitness | Sport | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.gaming` | Gaming | Jeux | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.health` | Health | Santé | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.home` | Home | Domicile | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.human` | Human | Humain | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.indices` | Indices | Indices | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.keyboard` | Keyboard | Clavier | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.maps` | Maps | Plans | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.math` | Maths | Maths | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.media` | Media | Multimédia | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.multicolor` | Multicolour | Multicolore | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.nature` | Nature | Nature | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.objectsandtools` | Objects & Tools | Objets et outils | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.privacyandsecurity` | Privacy & Security | Confidentialité et sécurité | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.shapes` | Shapes | Formes | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.textformatting` | Text Formatting | Formatage du texte | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.time` | Time | Temps | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.transportation` | Transportation | Transports | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.variable` | Variable | Variable | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.weather` | Weather | Météo | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.whatsnew` | What's New | Nouveautés | machine | Symbol picker: section header (SF Symbols category) |
| `tab.emoji` | Emoji | Emoji | machine | Emoji tab label |
| `tab.symbol` | Symbol | Symbole | machine | Symbol tab label |
| `title.customiseTile` | Customise Tile | Personnaliser la tuile | machine | Title of the Customise Tile inspector beside Tile Detail |
| `title.deleteTile` | Delete Tile | Supprimer la tuile | machine | Alert title for delete confirmation |
| `tooltip.createNewTile` | Create new tile | Créer une tuile | machine | Tooltip when add button is enabled |
| `tooltip.editFirst` | Edit current tile before creating another | Modifiez la tuile actuelle avant d’en créer une autre | machine | Tooltip when add button is disabled |
| `button.addATile` | Add a Tile… | Ajouter une tuile… | machine | Sidebar + / empty state: opens the Add a Tile dialog |
| `sidebar.dockTileSection` | Dock Tile | Dock Tile | machine | Sidebar section holding About |
| `settings.addingTiles` | Adding Tiles | Ajout de tuiles | machine | General: section holding the Smart Add toggle and the Add a Tile row |
| `about.title` | About | À propos | machine | About pane title |
| `about.version` | Version %@ | Version %@ | machine | About: version line |
| `about.website` | Website | Site web | machine | About: website row label |
| `about.feedbackTitle` | Found a bug or have an idea? | Un bug à signaler ou une idée ? | machine | About: feedback card title |
| `about.feedbackBody` | Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal. | Vos commentaires sont envoyés directement au développeur. Les diagnostics joignent un journal de ce qu’ont fait l’app et ses tuiles — rien de personnel. | machine | About: feedback card body |
| `about.sendFeedback` | Send Feedback… | Envoyer des commentaires… | machine | About: opens the feedback email |
| `about.alsoFrom` | Also from Happy Machines | Également par Happy Machines | machine | About: studio section header |
| `about.studioTitle` | Made by Happy Machines Company | Conçu par Happy Machines Company | machine | About: studio row title |
| `about.studioSubtitle` | A tiny product studio building nifty Mac apps that each fix one thing well. | Un petit studio qui conçoit des apps Mac astucieuses, chacune faite pour régler un seul problème, et bien. | machine | About: studio row subtitle |
| `about.spadesTitle` | Spades Audio | Spades Audio | machine | About: sibling product row title |
| `about.spadesSubtitle` | Per-app volume, EQ and output control for your Mac, from the menu bar. | Volume, égaliseur et sortie par app pour votre Mac, depuis la barre des menus. | machine | About: sibling product subtitle |
| `about.learnMore` | Learn More… | En savoir plus… | machine | About: opens spadesaudio.com |
| `menu.aboutDockTile` | About Dock Tile | À propos de Dock Tile | machine | App menu |
| `popover.editing.remove` | Remove | Retirer | machine | Context menu / remove badge in the tile editor |
| `section.inThisTile` | In This Tile | Dans cette tuile | machine | Tile Detail: apps section header |
| `label.editorHint` | Hover to remove · Drag to reorder | Survolez pour retirer · Faites glisser pour réorganiser | machine | Tile Detail: apps section caption |
| `tooltip.deleteTile` | Delete Tile | Supprimer la tuile | machine | Tile Detail: trash button tooltip |
| `smartAdd.blankTitle` | Create a blank tile | Créer une tuile vide | machine | Add a Tile: blank row title |
| `smartAdd.blankSubtitle` | Name it, pick an icon and add apps yourself. | Nommez-la, choisissez une icône et ajoutez vous-même des apps. | machine | Add a Tile: blank row subtitle |
| `smartAdd.orStartFrom` | or start from what you use | ou partez de ce que vous utilisez | machine | Add a Tile: rule between blank row and suggestions |
| `smartAdd.noSuggestions` | No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General. | Aucune suggestion pour l’instant — Dock Tile apprend des apps que vous ouvrez. Vous pouvez désactiver cette option dans Général. | machine | Add a Tile: empty suggestions note |
| `label.addAppsTooltip` | Add apps or folders to this tile | Ajouter des apps ou des dossiers à cette tuile | machine | Tooltip on the + Add button above the tile editor's popover preview. |
| `empty.createFirstTileDescription` | Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use. | Regroupez des apps et des dossiers derrière une seule icône du Dock. Partez de zéro ou d’une tuile suggérée d’après les apps que vous utilisez. | machine | Zero-tiles description |
| `popover.editing.noAppsTitle` | No apps yet | Aucune app pour l’instant | machine | Tile editor: empty popover preview, title line. |
| `popover.editing.noAppsSubtitle` | Use Add to choose what opens from this tile. | Utilisez « Ajouter » pour choisir ce qui s’ouvre depuis cette tuile. | machine | Tile editor: empty popover preview, subtitle line. |
| `about.diagnosticsBody` | A log of what the app and its tiles did. Attach it to an email when something looks wrong — it contains nothing personal. | Un journal de ce qu’ont fait l’app et ses tuiles. Joignez-le à un e-mail si quelque chose semble anormal — il ne contient rien de personnel. | machine | About: Copy Diagnostics row description. |
| `about.feedbackRowBody` | Feedback goes straight to the developer. | Vos commentaires sont envoyés directement au développeur. | machine | About: Send Feedback row description. |
| `about.diagnosticsTitle` | Diagnostics | Diagnostics | machine | About: Copy Diagnostics row label. |
| `button.copy` | Copy | Copier | machine | Generic Copy button label. |
| `tooltip.openSettings` | Settings | Réglages | machine | Tooltip for the settings toolbar button |
| `tooltip.toggleCustomiseTile` | Toggle Customise Tile | Afficher/masquer « Personnaliser la tuile » | machine | Tooltip and accessibility label of the toolbar button that opens or closes the Customise Tile inspector |
| `tooltip.toggleCustomiser` | Toggle Customiser | Afficher/masquer la personnalisation | machine | Tooltip and accessibility label of the Tile Detail icon, which opens or closes the Customise Tile inspector when clicked |
| `translation.helpImprove` | Help Improve… | Aider à améliorer… | machine | Button: opens the language's review sheet on GitHub |
| `translation.invite.message` | This translation was made by a machine and has not yet been checked by a native speaker. If something reads wrong, you can fix it on GitHub — no coding needed. | Cette traduction a été réalisée automatiquement et n’a pas encore été vérifiée par une personne de langue maternelle française. Si quelque chose vous semble incorrect, vous pouvez le corriger sur GitHub — sans aucune connaissance en programmation. | machine | One-time alert message inviting translation review |
| `translation.invite.title` | Dock Tile now speaks your language | Dock Tile parle désormais votre langue | machine | One-time alert title on first launch in a machine-translated language |
| `translation.reviewLine` | Machine translated. Not yet checked by a native speaker. | Traduction automatique. Pas encore vérifiée par une personne de langue maternelle. | machine | About: translation row description. Reviewers replace this in their language with who reviewed it, e.g. 'Reviewed by @handle'. |
| `translation.title` | Translation | Traduction | machine | About: translation row label (shown only when the UI runs in a non-English language) |
