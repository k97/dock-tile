# Dock Tile — Русский (ru)

How to review: [docs/l10n/README.md](README.md). Edit the **Translation** column, set
**Status** to `reviewed` for every row you checked (changed or not), then "Propose changes".
Status values: `machine` (not yet checked by a person), `reviewed`, `todo` (no translation yet).
Keep `%@`-style placeholders exactly as they are. `\n` means a line break, `\|` a pipe.

| Key | English | Translation | Status | Context |
|---|---|---|---|---|
| `alert.applyPopover.message` | Dock Tile will rebuild your pinned tiles with the new popover look and briefly restart the Dock. Your other Dock items won't be affected. | Dock Tile пересоздаст закрепленные плитки с новым видом всплывающей панели и ненадолго перезапустит Dock. Другие объекты в Dock не изменятся. | machine | Confirmation message warning the Dock will restart when applying popover settings |
| `alert.applyPopover.title` | Apply to your Dock tiles? | Применить к плиткам в Dock? | machine | Confirmation title before rebuilding tiles to apply popover appearance settings |
| `alert.configUnreadable.message` | Your tiles haven't been changed. Dock Tile couldn't open its settings file and will quit. Check that you can open %@, then open Dock Tile again. | Ваши плитки не изменены. Dock Tile не удалось открыть файл настроек, поэтому программа завершит работу. Убедитесь, что вы можете открыть %@, затем снова откройте Dock Tile. | machine | Launch alert message when the tile settings file can't be read; %@ = the file's full path. The app quits when the alert closes. |
| `alert.configUnreadable.quit` | Quit | Завершить | machine | Only button of the can't-read-tiles launch alert; quits Dock Tile |
| `alert.configUnreadable.title` | Dock Tile Can't Read Your Tiles | Dock Tile не может прочитать ваши плитки | machine | Launch alert title: the tile settings file exists but could not be opened; the app quits after it |
| `alert.deleteTile.message` | This will permanently delete the tile and remove it from the dock. | Плитка будет удалена без возможности восстановления и исчезнет из Dock. | machine | Delete-tile confirmation message |
| `alert.missingApps.message` | Some apps in your tiles can't be found on this Mac. Remove them from your tiles? | Некоторые приложения из ваших плиток не найдены на этом Mac. Удалить их из плиток? | machine | Alert message offering to remove uninstalled apps from tiles |
| `alert.missingApps.title` | Some apps are no longer installed | Некоторые приложения больше не установлены | machine | Alert title when apps referenced by tiles can't be found on disk |
| `alert.missingAppsScan.foundMessage` | These apps can't be found on this Mac: | Следующие приложения не найдены на этом Mac: | machine | Intro line of the manual scan results dialog; a list of tiles/apps follows |
| `alert.missingAppsScan.noneMessage` | Every app in your tiles is currently installed. | Все приложения из ваших плиток установлены. | machine | Message of the manual scan dialog when nothing is missing |
| `alert.missingAppsScan.noneTitle` | No Missing Apps | Отсутствующих приложений нет | machine | Title of the manual scan dialog when every tile app is installed |
| `alert.relocate.blockingMessage` | Dock Tile can't create or update this tile because it's running from a temporary, read-only location. This happens when the app is launched from Downloads. Move Dock Tile to your Applications folder and try again. | Dock Tile не может создать или обновить эту плитку, так как программа запущена из временного расположения, доступного только для чтения. Так бывает, если открыть ее из папки «Загрузки». Переместите Dock Tile в папку «Программы» и повторите попытку. | machine | Message shown when a tile action is blocked because the app is translocated |
| `alert.relocate.checkbox` | Don't ask again | Больше не спрашивать | machine | Checkbox to suppress future move-to-Applications nudges |
| `alert.relocate.message` | Dock Tile is running from outside your Applications folder. macOS may run it from a temporary, read-only location, which can stop new tiles from being created. Move it to Applications to make sure everything works. | Программа Dock Tile запущена не из папки «Программы». macOS может запускать ее из временного расположения, доступного только для чтения, и тогда новые плитки не удастся создать. Переместите ее в папку «Программы», чтобы все работало. | machine | Message of the launch-time nudge to move the app to Applications |
| `alert.relocate.title` | Move Dock Tile to Applications? | Переместить Dock Tile в папку «Программы»? | machine | Title of the prompt asking the user to move the app into the Applications folder |
| `alert.restartDock.checkbox` | Don't show this again | Больше не показывать | machine | Checkbox label to suppress future Dock restart alerts |
| `alert.restartDock.message` | Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected. | Чтобы применить изменения, Dock Tile перезапускает Dock. Это происходит каждый раз, когда вы добавляете, обновляете или удаляете плитки. Текущие объекты в Dock не изменятся. | machine | Alert message explaining Dock restart |
| `alert.restartDock.title` | Dock Restart Required | Требуется перезапуск Dock | machine | Alert title when Dock restart is required |
| `app.name` | Dock Tile | Dock Tile | machine | App display name |
| `button.add` | Add | Добавить | machine | Add button label in file picker |
| `button.addToDock` | Add to Dock | Добавить в Dock | machine | Button to add tile to Dock |
| `button.applyToTiles` | Apply | Применить | machine | Confirm button that rebuilds tiles to apply popover settings |
| `button.back` | Back | Назад | machine | Back button label |
| `button.cancel` | Cancel | Отменить | machine | Cancel button in alerts |
| `button.checkForUpdates` | Check for Updates… | Проверить обновления… | machine | Button that triggers a manual Sparkle update check |
| `button.checkNow` | Check Now | Проверить сейчас | machine | Settings → Software Update: button that triggers a manual Sparkle update check |
| `button.confirm` | Confirm | Подтвердить | machine | Confirm button for alert dialogs |
| `button.createNewTile` | Create New Tile | Создать плитку | machine | Smart Add sheet — neutral button that starts a blank tile instead of a suggestion |
| `button.delete` | Delete | Удалить | machine | Delete button |
| `button.done` | Done | Готово | machine | Done button |
| `button.duplicate` | Duplicate | Дублировать | machine | Duplicate button in context menu |
| `button.keep` | Keep | Оставить | machine | Button to keep uninstalled apps in tiles (dismiss the removal prompt) |
| `button.moveToApplications` | Move to Applications | Переместить в «Программы» | machine | Button that moves the app into the Applications folder |
| `button.newTile` | New Tile | Новая плитка | machine | Button to create first tile on empty state |
| `button.notNow` | Not Now | Не сейчас | machine | Dismiss button for the non-blocking move-to-Applications nudge |
| `button.openAccessibilitySettings` | Open Accessibility Settings… | Открыть настройки Универсального доступа… | machine | Button that opens the Accessibility pane in System Settings (Reduce Motion) |
| `button.openLoginItems` | Open Login Items Settings… | Открыть настройки объектов входа… | machine | Button that opens System Settings Login Items for approval |
| `button.remove` | Remove | Удалить | machine | Remove button |
| `button.removeAll` | Remove All | Удалить все | machine | Button to remove all missing apps from tiles at once |
| `button.removeFromDock` | Remove from Dock | Удалить из Dock | machine | Button to remove tile from Dock |
| `button.resetToDefaults` | Reset to Defaults | Вернуть настройки по умолчанию | machine | Button that restores popover appearance settings to their defaults |
| `button.reviewInTiles` | Review in Tiles | Показать в плитках | machine | Button that navigates to the first tile containing a missing app |
| `button.save` | Save | Сохранить | machine | Primary toolbar button that commits the popover appearance settings |
| `button.saving` | Applying… | Применение… | machine | Loading label on the Save button while applying settings to Dock tiles |
| `button.scanForMissingApps` | Scan | Проверить | machine | Settings button that scans tiles for moved/uninstalled apps |
| `button.update` | Update | Обновить | machine | Update button when tile is already in Dock |
| `button.useThisTile` | Use This Tile | Использовать | machine | Smart Add sheet — button that creates a pre-filled tile from a suggestion |
| `emojiCategory.activity` | Activity | Активность | machine | Emoji picker: section header |
| `emojiCategory.animalsNature` | Animals & Nature | Животные и природа | machine | Emoji picker: section header |
| `emojiCategory.foodDrink` | Food & Drink | Еда и напитки | machine | Emoji picker: section header |
| `emojiCategory.objects` | Objects | Предметы | machine | Emoji picker: section header |
| `emojiCategory.people` | People | Люди | machine | Emoji picker: section header |
| `emojiCategory.symbols` | Symbols | Символы | machine | Emoji picker: section header |
| `emojiCategory.travelPlaces` | Travel & Places | Путешествия и места | machine | Emoji picker: section header |
| `empty.createFirstTile` | Create Your First Tile | Создайте первую плитку | machine | Header text for empty state |
| `empty.detail` | Detail | Подробности | machine | Placeholder text in detail view |
| `empty.noApps` | No apps configured | Приложения не добавлены | machine | Empty state text when no apps configured |
| `empty.noTiles` | No Tiles | Нет плиток | machine | Empty state text in sidebar |
| `error.appTranslocated` | Dock Tile is running from a temporary, read-only location and can't create tiles. Move it to your Applications folder and try again. | Программа Dock Tile запущена из временного расположения, доступного только для чтения, и не может создавать плитки. Переместите ее в папку «Программы» и повторите попытку. | machine | Error when the app is translocated and cannot generate helper bundles |
| `error.bundleBuildInProgress` | This tile is already being rebuilt. Wait for that to finish, then try again. | Эта плитка уже пересоздается. Дождитесь завершения и повторите попытку. | machine | Error when a second build is requested for a tile whose helper bundle is already being built |
| `error.dockChangeNotKept` | The Dock didn't keep this change. Try again. | Dock не сохранил это изменение. Повторите попытку. | machine | Error when Dock Tile wrote a change to the Dock (add, update or hide a tile) but the Dock did not keep it, even after one retry |
| `error.failedToCodeSign` | Failed to code sign helper bundle | Не удалось подписать вспомогательный пакет | machine | Error when code signing fails |
| `error.failedToCopyBundle` | Failed to copy bundle | Не удалось скопировать пакет | machine | Error when bundle copy fails |
| `error.failedToReadInfoPlist` | Failed to read Info.plist | Не удалось прочитать Info.plist | machine | Error when Info.plist cannot be read |
| `error.failedToWriteInfoPlist` | Failed to write Info.plist | Не удалось записать Info.plist | machine | Error when Info.plist cannot be written |
| `error.mainAppNotFound` | Main Dock Tile.app not found | Основное приложение Dock Tile.app не найдено | machine | Error when main app bundle cannot be found |
| `filePicker.message` | Select one or more applications or folders to add | Выберите одно или несколько приложений или папок для добавления | machine | Message in file picker dialog |
| `iconWeight.bold` | Bold | Жирный | machine | Customise: icon weight picker option |
| `iconWeight.heavy` | Heavy | Тяжелый | machine | Customise: icon weight picker option |
| `iconWeight.light` | Light | Легкий | machine | Customise: icon weight picker option |
| `iconWeight.medium` | Medium | Средний | machine | Customise: icon weight picker option |
| `iconWeight.regular` | Regular | Обычный | machine | Customise: icon weight picker option |
| `iconWeight.semibold` | Semibold | Полужирный | machine | Customise: icon weight picker option |
| `label.apps.arrangement` | Arrangement | Расположение | machine | Customise Tile: Apps card row — the grid the face uses |
| `label.apps.arrangement.threeByThree` | 3 × 3 | 3 × 3 | machine | Customise Tile: Arrangement value for 5 or more apps |
| `label.apps.arrangement.twoByTwo` | 2 × 2 | 2 × 2 | machine | Customise Tile: Arrangement value for 2–4 apps |
| `label.apps.glass` | A glass folder that follows Light and Dark Mode. | Стеклянная папка, которая подстраивается под светлый и темный режим. | machine | Customise Tile: fixed sentence after the Apps caption (decided 2026-10-19: the dark appearance is system-dark) |
| `label.apps.header` | Apps | Приложения | machine | Customise Tile: group header above the Apps card |
| `label.apps.note.all` | Shows all %lld apps, in tile order. | Показывает все приложения (%lld) в порядке плитки. | machine | Customise Tile: Apps caption, 2–9 apps; %lld = app count |
| `label.apps.note.firstNine` | Shows the first 9 of %lld apps, in tile order. | Показывает первые 9 приложений из %lld в порядке плитки. | machine | Customise Tile: Apps caption, more than nine apps; %lld = app count |
| `label.apps.note.none` | No apps yet — use Add under In This Tile. | Приложений пока нет — добавьте их кнопкой «Добавить» в разделе «В этой плитке». | machine | Customise Tile: Apps caption when the tile has no apps (builder copy, not in the handoff) |
| `label.apps.note.one` | Shows the only app in this tile. | Показывает единственное приложение в этой плитке. | machine | Customise Tile: Apps caption, one app |
| `label.apps.shown` | Shown | Показано | machine | Customise Tile: Apps card row — how many apps the face shows |
| `label.apps.shownValue` | %1$lld of %2$lld | %1$lld из %2$lld | machine | Customise Tile: Apps card Shown value, e.g. 9 of 12; %1$lld = shown, %2$lld = total (positional so a language may reorder them) |
| `label.appsBackground` | Dock Icon Background | Фон значка в Dock | machine | App Grid inspector section for per-tile plate settings |
| `label.appsBackground.automatic` | Follow System | Следовать системным настройкам | machine | App Grid background follows the macOS icon appearance |
| `label.appsBackground.charcoal` | Dark Grey | Тёмно-серый | machine | Fixed dark background for an App Grid icon |
| `label.appsBackground.custom` | Custom Colour | Свой цвет | machine | Native colour picker for an App Grid icon background |
| `label.appsBackground.hint` | Applies to this tile only. | Применяется только к этой плитке. | machine | Caption under the App Grid background menu: the choice affects only this tile |
| `label.appsBackground.light` | Light | Светлый | machine | Fixed light background for an App Grid icon |
| `label.appsFace.accessibility` | Apps face: showing %lld of this tile's apps | Вид приложений: показано приложений этой плитки — %lld | machine | VoiceOver label for a tile preview showing the Apps face; %lld = number of app icons shown |
| `label.background` | Background | Фон | machine | Customise Tile: background row label |
| `label.background.colour` | Colour | Цвет | machine | Customise Tile: Colour background chip |
| `label.background.colour.accessibility` | Colour, filled with your colour | Цвет: плитка залита вашим цветом | machine | VoiceOver label for the Colour chip |
| `label.background.hint.colour` | Filled with your colour | Заливка вашим цветом | machine | Customise Tile: hint under Background when Colour |
| `label.background.hint.emojiColours` | Emoji keep their own colours. | Эмодзи сохраняют свои цвета. | machine | Customise Tile: appended to the Background caption for an Emoji tile |
| `label.background.hint.mono` | White in Light Mode, black in Dark Mode | Белый в светлом режиме, черный — в темном | machine | Customise Tile: hint under Background when Mono |
| `label.background.hint.mono.static` | White tile with a coloured symbol | Белая плитка с цветным символом | machine | Customise Tile: hint under Background when Mono on macOS 15 (static white tile) |
| `label.background.mono` | Mono | Моно | machine | Customise Tile: Mono background chip |
| `label.background.mono.accessibility` | Mono, white in Light Mode and black in Dark Mode | Моно: белый фон в светлом режиме и черный в темном | machine | VoiceOver label for the Mono chip |
| `label.background.mono.static.accessibility` | Mono, a white tile with a coloured symbol | Моно: белая плитка с цветным символом | machine | VoiceOver label for the Mono chip on macOS 15 |
| `label.colour` | Colour | Цвет | machine | Label for colour picker section |
| `label.colour.hint.deepened` | Deepened slightly so the symbol stays clear | Немного затемнен, чтобы символ оставался четким | machine | Customise Tile: colour hint when the fill was darkened for contrast |
| `label.colour.hint.emoji` | Emoji keep their own colours | Эмодзи сохраняют свои цвета | machine | Customise Tile: colour hint, Mono emoji tile (row disabled) |
| `label.colour.hint.fills` | Fills the tile | Заливает плитку | machine | Customise Tile: colour hint, Colour tile |
| `label.colour.hint.tints` | Tints the symbol | Окрашивает символ | machine | Customise Tile: Colour card caption for a Mono tile |
| `label.colour.hint.toned` | Toned for Light and Dark | Подобран для светлого и темного режимов | machine | Customise Tile: colour hint, Mono tile |
| `label.colour.hint.toned.static` | Toned to stay clear on white | Подобран для четкости на белом | machine | Customise Tile: colour hint, Mono tile on macOS 15 |
| `label.iconSize` | Icon Size | Размер значка | machine | Compact label for the icon size stepper (side-by-side with icon weight) |
| `label.iconWeight` | Icon Weight | Толщина значка | machine | Label for the SF Symbol weight picker |
| `label.missingAppsScan` | Missing Apps | Отсутствующие приложения | machine | Settings row title for the missing-app scan |
| `label.missingAppsScanDescription` | Check your tiles for apps that have been moved or uninstalled. | Проверьте, нет ли в плитках перемещенных или удаленных приложений. | machine | Settings row description for the missing-app scan |
| `label.notInstalled` | Not installed | Не установлено | machine | Badge/kind text shown for an app whose bundle is no longer on disk |
| `label.popover.animation` | Animation | Анимация | machine | Label for the popover animation segmented control |
| `label.popover.highlightOnHover` | Highlight on Hover | Подсветка при наведении | machine | Toggle label — show a background fill on the hovered item |
| `label.popover.layout` | Layout | Вид | machine | Label for the Grid/List preview toggle in popover settings |
| `label.popover.listAlwaysLabelled` | List view always shows labels | В виде списка подписи показываются всегда | machine | Hint shown beside the disabled Show Labels control when previewing List |
| `label.popover.showLabels` | Show Labels | Показывать подписи | machine | Toggle label — show app names under grid icons |
| `label.popover.size` | Popover Size | Размер панели | machine | Label for the popover size segmented control |
| `label.popover.spacing` | Spacing | Интервалы | machine | Label for the popover item spacing segmented control |
| `label.popover.tileSize` | Tile Size | Размер плиток | machine | Label for the icon/cell size control inside the popover |
| `label.shareAnalytics` | Share anonymous usage data | Отправлять анонимную статистику | machine | Label for the analytics opt-out toggle in Settings |
| `label.shareAnalyticsDescription` | Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected. | Помогите улучшить Dock Tile, отправляя анонимные данные об использовании и отчеты о сбоях. Личные данные не собираются. | machine | Explanation under the analytics toggle |
| `label.addAppsAndFolders` | Add Apps & Folders | Добавить приложения и папки | machine | Tooltip on the Add button in Tile Detail's In This Tile section |
| `label.appSwitcherNeedsShowTile` | Turn on Show Tile first — this only applies while the tile is in the Dock. | Сначала включите «Показывать плитку» — этот параметр действует, только когда плитка находится в Dock. | machine | Tooltip on the disabled Show in App Switcher toggle when the tile is hidden |
| `label.showInAppSwitcher` | Show in App Switcher | Показывать в переключателе приложений | machine | Label for app switcher toggle |
| `label.showTile` | Show Tile | Показывать плитку | machine | Label for show tile toggle |
| `label.softwareUpdate` | Software Update | Обновление ПО | machine | Title of the software-update row in General settings |
| `label.softwareUpdateDescription` | You’re using version %@. Dock Tile checks for updates automatically. | Вы используете версию %@. Dock Tile проверяет наличие обновлений автоматически. | machine | Description under the software-update row; %@ is the current version |
| `label.startAtLogin` | Start tiles at login | Запускать плитки при входе | machine | Label for the start-at-login toggle in Settings |
| `label.startAtLoginDescription` | Keep your tiles ready in the Dock so they respond instantly after you restart your Mac. | Плитки будут готовы в Dock и сразу откликнутся после перезагрузки Mac. | machine | Explanation under the start-at-login toggle |
| `label.style.appPreview` | App Grid | Сетка | machine | Customise Tile: Style picker card for the Apps face |
| `label.symbolColour` | Symbol Colour | Цвет символа | machine | Customise Tile: colour row label for a Mono tile |
| `label.tileColour` | Tile Colour | Цвет плитки | machine | Customise Tile: Colour card header for a Colour tile |
| `label.tileIcon` | Tile Icon | Значок плитки | machine | Label for tile icon section |
| `label.tileIconSize` | Tile Icon Size | Размер значка плитки | machine | Label for tile icon size |
| `label.tileName` | Tile Name | Название плитки | machine | Label for tile name field |
| `layout.grid` | Grid | Сетка | machine | Grid layout option |
| `layout.list` | List | Список | machine | List layout option |
| `itemMenu.forceQuit` | Force Quit | Завершить принудительно | machine | Popover item context menu: force quit (shown while Option is held) |
| `itemMenu.getInfo` | Get Info | Свойства | machine | Popover item context menu: open Finder's Get Info window |
| `itemMenu.hide` | Hide | Скрыть | machine | Popover item context menu: hide the running app |
| `itemMenu.open` | Open | Открыть | machine | Popover item context menu: open the app or folder |
| `itemMenu.quickLook` | Quick Look | Быстрый просмотр | machine | Popover item context menu: preview the item with Quick Look |
| `itemMenu.quit` | Quit | Завершить | machine | Popover item context menu: quit the running app |
| `itemMenu.share` | Share… | Поделиться… | machine | Popover item context menu: open the share sheet for a folder |
| `itemMenu.showInFinder` | Show in Finder | Показать в Finder | machine | Popover item context menu: reveal the item in Finder |
| `menu.configure` | Configure... | Настроить… | machine | Menu item to configure tile (opens main app) |
| `menu.configureTile` | Configure Tile | Настроить плитку | machine | Tooltip for gear icon in popover |
| `menu.copyDiagnostics` | Copy Diagnostics | Скопировать диагностику | machine | File menu item that copies recent diagnostic logs to the clipboard |
| `menu.hideInspector` | Hide Inspector | Скрыть инспектор | machine | View menu item (Hide Inspector, ⌥⌘I) that closes the Customise Tile inspector |
| `menu.newTile` | New Tile | Новая плитка | machine | Menu item to create a new tile |
| `menu.noAppsConfigured` | No apps configured | Приложения не добавлены | machine | Dock menu: disabled row when the tile has no apps |
| `menu.noConfiguration` | No configuration | Нет конфигурации | machine | Dock menu: disabled row when the tile's config cannot be found |
| `menu.openInFinder` | Open in Finder | Открыть в Finder | machine | Menu item to open in Finder |
| `menu.options` | Options | Параметры | machine | Section divider in menu |
| `menu.settings` | Settings… | Настройки… | machine | App menu item that opens the inline Settings pane (⌘,) |
| `menu.showInspector` | Show Inspector | Показать инспектор | machine | View menu item (Show Inspector, ⌥⌘I) that opens the Customise Tile inspector |
| `popover.option.animation.default` | Default | По умолчанию | machine | Animation tier — default |
| `popover.option.animation.fast` | Fast | Быстро | machine | Animation tier — fast |
| `popover.option.animation.none` | None | Нет | machine | Animation tier — none |
| `popover.option.comfortable` | Comfortable | Свободно | machine | Spacing tier — comfortable |
| `popover.option.compact` | Compact | Компактно | machine | Spacing tier — compact |
| `popover.option.large` | Large | Большой | machine | Size tier — large |
| `popover.option.medium` | Medium | Средний | machine | Size tier — medium |
| `popover.option.small` | Small | Малый | machine | Size tier — small |
| `popover.option.spacious` | Spacious | Просторно | machine | Spacing tier — spacious |
| `search.emojis` | Search emojis | Поиск эмодзи | machine | Search placeholder for emojis |
| `search.symbols` | Search symbols | Поиск символов | machine | Search placeholder for symbols |
| `settings.dockLock` | Dock Lock | Закрепление Dock | machine | Section header for the Dock Lock feature in Settings |
| `settings.dockLock.accessibilityGranted` | Accessibility access granted | Доступ к функциям универсального доступа разрешен | machine | Status shown when Accessibility permission is granted |
| `settings.dockLock.accessibilityNeeded` | Accessibility access required | Требуется доступ к функциям универсального доступа | machine | Status shown when Accessibility permission is missing |
| `settings.dockLock.accessibilityNeededDetail` | Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings. | Dock Tile нужен доступ к функциям универсального доступа, чтобы удерживать Dock на месте. Включите Dock Tile в Системных настройках. | machine | Explanation of why Accessibility access is needed |
| `settings.dockLock.anchor` | Keep Dock on | Дисплей для Dock | machine | Label for the anchor display picker |
| `settings.dockLock.defaultDisplay` | Default (follow macOS) | По умолчанию (как в macOS) | machine | First option in the anchor picker — no lock, macOS default behaviour |
| `settings.dockLock.description` | Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose. | Не дает Dock перескакивать между экранами, если подключено несколько дисплеев. Dock остается на выбранном дисплее. | machine | Explanation under the Dock Lock toggle |
| `settings.dockLock.lockedTo` | Dock is locked to %@ | Dock закреплен на дисплее %@ | machine | Indicator confirming the display the Dock is pinned to |
| `settings.dockLock.mainDisplay` | Main | Основной | machine | Suffix marking the main display in the anchor picker |
| `settings.dockLock.moveFailed` | Couldn't move the Dock to %@. Make sure that display isn't mirrored, then try again. | Не удалось переместить Dock на дисплей %@. Убедитесь, что для этого дисплея не включен видеоповтор, и повторите попытку. | machine | Error shown when the Dock could not be relocated |
| `settings.dockLock.moving` | Moving Dock to %@… | Перемещение Dock на дисплей %@… | machine | Progress message shown while the Dock is being relocated |
| `settings.dockLock.note` | Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays. | Работает, когда Dock находится внизу, слева или справа. Чтобы удерживать Dock на одном экране, у того же края на других дисплеях резервируется несколько пикселей. | machine | Footnote describing Dock Lock behaviour and trade-off |
| `settings.dockLock.openSettings` | Open System Settings… | Открыть Системные настройки… | machine | Button that opens the Accessibility pane in System Settings |
| `settings.dockLock.primer.body` | Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens. | Закрепление Dock удерживает Dock на выбранном дисплее. Для этого Dock Tile нужен доступ к функциям универсального доступа, чтобы не давать macOS перемещать Dock на другие экраны. | machine | Explanation in the permission primer |
| `settings.dockLock.primer.continue` | Continue | Продолжить | machine | Primary button in the permission primer that triggers the macOS dialog |
| `settings.dockLock.primer.notNow` | Not Now | Не сейчас | machine | Secondary button in the permission primer that cancels enabling Dock Lock |
| `settings.dockLock.primer.reassurance` | Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time. | Затем macOS попросит включить Dock Tile в Системных настройках. Это можно отключить в любой момент. | machine | Reassurance line in the permission primer about what happens next |
| `settings.dockLock.primer.title` | Allow Accessibility Access | Разрешить универсальный доступ | machine | Title of the permission primer shown before requesting Accessibility |
| `settings.dockLock.retry` | Try Again | Повторить | machine | Button to retry a failed Dock relocation |
| `settings.dockLock.singleDisplay` | Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it. | Чтобы использовать закрепление Dock, подключите второй дисплей. С одним экраном Dock остается там, где его размещает macOS. | machine | Note shown when only one display is connected |
| `settings.dockLock.toggle` | Lock Dock to one display | Закрепить Dock на одном дисплее | machine | Label for the Dock Lock enable toggle |
| `settings.general` | General | Основные | machine | Title of the General settings pane |
| `settings.login.registrationFailed` | Couldn’t turn this on — macOS refused the registration. %@ | Не удалось включить: macOS отклонила регистрацию. %@ | machine | Shown under the Start tiles at login toggle when SMAppService registration failed; %@ is the system error |
| `settings.login.requiresApproval` | Approve Dock Tile in Login Items to finish enabling this. | Чтобы завершить включение, разрешите Dock Tile в настройках «Объекты входа». | machine | Shown when macOS is holding the login item for user approval |
| `settings.popover` | Popover | Всплывающая панель | machine | Section header and pane title for popover appearance settings |
| `settings.popover.configure` | Configure | Настройка | machine | Label for the Grid/List panel switcher in popover settings |
| `settings.popover.configure.subtitle` | Each layout's settings are saved independently | Настройки каждого вида сохраняются отдельно | machine | Subtitle explaining that Grid and List popover settings are stored separately |
| `settings.popover.footer` | These settings apply to every tile's popover. List view always shows labels. Animation follows your system Reduce Motion setting. | Эти настройки применяются к всплывающим панелям всех плиток. В виде списка подписи показываются всегда. Анимация учитывает системный параметр «Уменьшить движение». | machine | Explanatory footer under the popover settings form |
| `settings.popover.reduceMotion` | Animation is off because Reduce Motion is on in System Settings. | Анимация выключена, так как в Системных настройках включен параметр «Уменьшить движение». | machine | Caption shown under Animation when the system Reduce Motion setting forces it off |
| `settings.popover.section.tiles` | Tiles | Плитки | machine | Section header for the per-item controls inside the popover settings |
| `sidebar.section.settings` | Settings | Настройки | machine | Sidebar section header for the inline app settings panes |
| `sidebar.section.tiles` | Tiles | Плитки | machine | Sidebar section header for the list of dock tiles |
| `sidebar.title` | Dock Tile | Dock Tile | machine | Navigation title for sidebar |
| `smartAdd.identity.browse` | Browse | Интернет | machine | Smart Add: suggested tile name for browsers |
| `smartAdd.identity.chat` | Chat | Общение | machine | Smart Add: suggested tile name for social apps |
| `smartAdd.identity.ship` | Ship | Разработка | machine | Smart Add: suggested tile name for developer tools |
| `smartAdd.identity.together` | Together | Вместе | machine | Smart Add: suggested tile name for apps opened together |
| `smartAdd.identity.watch` | Watch | Видео | machine | Smart Add: suggested tile name for video apps |
| `smartAdd.identity.work` | Work | Работа | machine | Smart Add: suggested tile name for productivity apps |
| `smartAdd.privacyFootnote` | Learned on your Mac. Never leaves your device. | Анализ выполняется на вашем Mac. Данные не покидают устройство. | machine | Footer note stating Smart Add suggestions are computed on-device only |
| `smartAdd.provenanceBanner` | Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to your Dock. | Создано функцией «Умное добавление» на основе недавних приложений. Переименуйте плитку, измените ее вид или список приложений, а затем добавьте ее в Dock. | machine | Banner shown atop Tile Detail when a tile was just created by Smart Add |
| `smartAdd.reason.byCategory` | By category | По категории | machine | Reason chip — apps grouped by their app category |
| `smartAdd.reason.mostUsed` | Most used this week | Чаще всего на этой неделе | machine | Reason chip — the most-used cluster this week |
| `smartAdd.reason.openedTogether` | Opened together | Открываются вместе | machine | Reason chip — apps repeatedly opened in the same session |
| `smartAdd.settings.sectionHeader` | Smart Add | Умное добавление | machine | General settings section header for the Smart Add toggle |
| `smartAdd.settings.toggleDescription` | Learned on your Mac. Never leaves your device. | Анализ выполняется на вашем Mac. Данные не покидают устройство. | machine | General: Smart Add toggle description |
| `smartAdd.settings.toggleTitle` | Suggest tiles from my apps | Предлагать плитки из моих приложений | machine | General: Smart Add toggle title |
| `smartAdd.title` | Add a Tile | Добавить плитку | machine | Header title of the Smart Add suggestion sheet |
| `subtitle.chooseColour` | Choose a background colour for your tile | Выберите цвет фона плитки | machine | Subtitle for colour picker section |
| `subtitle.configureToAdd` | Configure to add apps | Настройте, чтобы добавить приложения | machine | Subtitle in empty state (grid view only) |
| `subtitle.iconSize` | Adjust the size of your icon within the tile | Настройте размер значка внутри плитки | machine | Subtitle for icon size section |
| `symbolCategory.accessibility` | Accessibility | Универсальный доступ | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.all` | All | Все | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.arrows` | Arrows | Стрелки | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.automotive` | Automotive | Автотранспорт | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.cameraandphotos` | Camera & Photos | Камера и фото | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.commerce` | Commerce | Коммерция | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.communication` | Communication | Общение | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.connectivity` | Connectivity | Связь | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.devices` | Devices | Устройства | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.draw` | Draw | Рисование | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.editing` | Editing | Редактирование | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.fitness` | Fitness | Спорт | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.gaming` | Gaming | Видеоигры | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.health` | Health | Здоровье | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.home` | Home | Дом | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.human` | Human | Люди | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.indices` | Indices | Индексы | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.keyboard` | Keyboard | Клавиатура | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.maps` | Maps | Карты | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.math` | Maths | Математика | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.media` | Media | Медиа | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.multicolor` | Multicolour | Многоцветные | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.nature` | Nature | Природа | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.objectsandtools` | Objects & Tools | Объекты и инструменты | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.privacyandsecurity` | Privacy & Security | Конфиденциальность и безопасность | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.shapes` | Shapes | Фигуры | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.textformatting` | Text Formatting | Форматирование текста | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.time` | Time | Время | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.transportation` | Transportation | Транспорт | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.variable` | Variable | Вариативность | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.weather` | Weather | Погода | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.whatsnew` | What's New | Что нового | machine | Symbol picker: section header (SF Symbols category) |
| `tab.emoji` | Emoji | Эмодзи | machine | Emoji tab label |
| `tab.symbol` | Symbol | Символ | machine | Symbol tab label |
| `title.customiseTile` | Customise Tile | Настройка плитки | machine | Title of the Customise Tile inspector beside Tile Detail |
| `title.deleteTile` | Delete Tile | Удалить плитку | machine | Alert title for delete confirmation |
| `tooltip.createNewTile` | Create new tile | Создать плитку | machine | Tooltip when add button is enabled |
| `tooltip.editFirst` | Edit current tile before creating another | Измените текущую плитку, прежде чем создавать новую | machine | Tooltip when add button is disabled |
| `button.addATile` | Add a Tile… | Добавить плитку… | machine | Sidebar + / empty state: opens the Add a Tile dialog |
| `sidebar.dockTileSection` | Dock Tile | Dock Tile | machine | Sidebar section holding About |
| `settings.addingTiles` | Adding Tiles | Добавление плиток | machine | General: section holding the Smart Add toggle and the Add a Tile row |
| `about.title` | About | О программе | machine | About pane title |
| `about.version` | Version %@ | Версия %@ | machine | About: version line |
| `about.website` | Website | Сайт | machine | About: website row label |
| `about.feedbackTitle` | Found a bug or have an idea? | Нашли ошибку или есть идея? | machine | About: feedback card title |
| `about.feedbackBody` | Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal. | Отзывы попадают напрямую к разработчику. К диагностике прилагается журнал действий программы и ее плиток — без личных данных. | machine | About: feedback card body |
| `about.sendFeedback` | Send Feedback… | Отправить отзыв… | machine | About: opens the feedback email |
| `about.alsoFrom` | Also from Happy Machines | Также от Happy Machines | machine | About: studio section header |
| `about.studioTitle` | Made by Happy Machines Company | Создано Happy Machines Company | machine | About: studio row title |
| `about.studioSubtitle` | A tiny product studio building nifty Mac apps that each fix one thing well. | Маленькая студия, создающая полезные программы для Mac. Каждая хорошо решает одну задачу. | machine | About: studio row subtitle |
| `about.spadesTitle` | Spades Audio | Spades Audio | machine | About: sibling product row title |
| `about.spadesSubtitle` | Per-app volume, EQ and output control for your Mac, from the menu bar. | Громкость, эквалайзер и выбор выхода звука для каждого приложения на Mac — прямо из строки меню. | machine | About: sibling product subtitle |
| `about.learnMore` | Learn More… | Подробнее… | machine | About: opens spadesaudio.com |
| `menu.aboutDockTile` | About Dock Tile | О программе Dock Tile | machine | App menu |
| `popover.editing.remove` | Remove | Удалить | machine | Context menu / remove badge in the tile editor |
| `section.inThisTile` | In This Tile | В этой плитке | machine | Tile Detail: apps section header |
| `label.editorHint` | Hover to remove · Drag to reorder | Наведите для удаления · Перетащите для сортировки | machine | Tile Detail: apps section caption |
| `tooltip.deleteTile` | Delete Tile | Удалить плитку | machine | Tile Detail: trash button tooltip |
| `smartAdd.blankTitle` | Create a blank tile | Создать пустую плитку | machine | Add a Tile: blank row title |
| `smartAdd.blankSubtitle` | Name it, pick an icon and add apps yourself. | Выберите название, значок и приложения. | machine | Add a Tile: blank row subtitle |
| `smartAdd.orStartFrom` | or start from what you use | или начните с ваших приложений | machine | Add a Tile: rule between blank row and suggestions |
| `smartAdd.noSuggestions` | No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General. | Пока нет предложений — Dock Tile учится на приложениях, которые вы открываете. Это можно отключить в разделе «Основные». | machine | Add a Tile: empty suggestions note |
| `label.addAppsTooltip` | Add apps or folders to this tile | Добавить приложения или папки в эту плитку | machine | Tooltip on the + Add button above the tile editor's popover preview. |
| `empty.createFirstTileDescription` | Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use. | Объедините приложения и папки под одним значком в Dock. Начните с пустой плитки или с плитки, предложенной на основе ваших приложений. | machine | Zero-tiles description |
| `popover.editing.noAppsTitle` | No apps yet | Приложений пока нет | machine | Tile editor: empty popover preview, title line. |
| `popover.editing.noAppsSubtitle` | Use Add to choose what opens from this tile. | Нажмите «Добавить», чтобы выбрать, что будет открываться из этой плитки. | machine | Tile editor: empty popover preview, subtitle line. |
| `about.diagnosticsBody` | A log of what the app and its tiles did. Attach it to an email when something looks wrong — it contains nothing personal. | Журнал действий программы и ее плиток. Приложите его к письму, если что-то работает не так, — личных данных в нем нет. | machine | About: Copy Diagnostics row description. |
| `about.feedbackRowBody` | Feedback goes straight to the developer. | Отзывы попадают напрямую к разработчику. | machine | About: Send Feedback row description. |
| `about.diagnosticsTitle` | Diagnostics | Диагностика | machine | About: Copy Diagnostics row label. |
| `button.copy` | Copy | Скопировать | machine | Generic Copy button label. |
| `tooltip.openSettings` | Settings | Настройки | machine | Tooltip for the settings toolbar button |
| `tooltip.toggleCustomiseTile` | Toggle Customise Tile | Показать/скрыть «Настройка плитки» | machine | Tooltip and accessibility label of the toolbar button that opens or closes the Customise Tile inspector |
| `tooltip.toggleCustomiser` | Toggle Customiser | Показать/скрыть настройки | machine | Tooltip and accessibility label of the Tile Detail icon, which opens or closes the Customise Tile inspector when clicked |
| `translation.helpImprove` | Help Improve… | Помочь улучшить… | machine | Button: opens the language's review sheet on GitHub |
| `translation.invite.message` | This translation was made by a machine and has not yet been checked by a native speaker. If something reads wrong, you can fix it on GitHub — no coding needed. | Этот перевод выполнен машиной и еще не проверен носителем языка. Если что-то звучит неправильно, вы можете исправить это на GitHub — программировать не нужно. | machine | One-time alert message inviting translation review |
| `translation.invite.title` | Dock Tile now speaks your language | Dock Tile теперь говорит по-русски | machine | One-time alert title on first launch in a machine-translated language |
| `translation.reviewLine` | Machine translated. Not yet checked by a native speaker. | Машинный перевод. Еще не проверен носителем языка. | machine | About: translation row description. Reviewers replace this in their language with who reviewed it, e.g. 'Reviewed by @handle'. |
| `translation.title` | Translation | Перевод | machine | About: translation row label (shown only when the UI runs in a non-English language) |
