# Dock Tile — 日本語 (ja)

How to review: [docs/l10n/README.md](README.md). Edit the **Translation** column, set
**Status** to `reviewed` for every row you checked (changed or not), then "Propose changes".
Status values: `machine` (not yet checked by a person), `reviewed`, `todo` (no translation yet).
Keep `%@`-style placeholders exactly as they are. `\n` means a line break, `\|` a pipe.

| Key | English | Translation | Status | Context |
|---|---|---|---|---|
| `alert.applyPopover.message` | Dock Tile will rebuild your pinned tiles with the new popover look and briefly restart the Dock. Your other Dock items won't be affected. | Dock Tileは、Dockにあるタイルを新しいポップオーバーの外観で再構築し、Dockを一時的に再起動します。Dock内のほかの項目には影響しません。 | machine | Confirmation message warning the Dock will restart when applying popover settings |
| `alert.applyPopover.title` | Apply to your Dock tiles? | Dockのタイルに適用しますか? | machine | Confirmation title before rebuilding tiles to apply popover appearance settings |
| `alert.configUnreadable.message` | Your tiles haven't been changed. Dock Tile couldn't open its settings file and will quit. Check that you can open %@, then open Dock Tile again. | タイルは変更されていません。Dock Tileは設定ファイルを開けなかったため、終了します。%@を開けることを確認してから、もう一度Dock Tileを開いてください。 | machine | Launch alert message when the tile settings file can't be read; %@ = the file's full path. The app quits when the alert closes. |
| `alert.configUnreadable.quit` | Quit | 終了 | machine | Only button of the can't-read-tiles launch alert; quits Dock Tile |
| `alert.configUnreadable.title` | Dock Tile Can't Read Your Tiles | Dock Tileがタイルを読み込めません | machine | Launch alert title: the tile settings file exists but could not be opened; the app quits after it |
| `alert.deleteTile.message` | This will permanently delete the tile and remove it from the dock. | このタイルは完全に削除され、Dockからも取り除かれます。 | machine | Delete-tile confirmation message |
| `alert.missingApps.message` | Some apps in your tiles can't be found on this Mac. Remove them from your tiles? | タイル内の一部のアプリがこのMacで見つかりません。タイルから取り除きますか? | machine | Alert message offering to remove uninstalled apps from tiles |
| `alert.missingApps.title` | Some apps are no longer installed | 一部のアプリがインストールされていません | machine | Alert title when apps referenced by tiles can't be found on disk |
| `alert.missingAppsScan.foundMessage` | These apps can't be found on this Mac: | 次のアプリがこのMacで見つかりません： | machine | Intro line of the manual scan results dialog; a list of tiles/apps follows |
| `alert.missingAppsScan.noneMessage` | Every app in your tiles is currently installed. | タイル内のすべてのアプリがインストールされています。 | machine | Message of the manual scan dialog when nothing is missing |
| `alert.missingAppsScan.noneTitle` | No Missing Apps | 見つからないアプリはありません | machine | Title of the manual scan dialog when every tile app is installed |
| `alert.relocate.blockingMessage` | Dock Tile can't create or update this tile because it's running from a temporary, read-only location. This happens when the app is launched from Downloads. Move Dock Tile to your Applications folder and try again. | Dock Tileは一時的な読み出し専用の場所から実行されているため、このタイルを作成または更新できません。これは、アプリを“ダウンロード”フォルダから起動したときに起こります。Dock Tileを“アプリケーション”フォルダに移動してから、もう一度お試しください。 | machine | Message shown when a tile action is blocked because the app is translocated |
| `alert.relocate.checkbox` | Don't ask again | 今後確認しない | machine | Checkbox to suppress future move-to-Applications nudges |
| `alert.relocate.message` | Dock Tile is running from outside your Applications folder. macOS may run it from a temporary, read-only location, which can stop new tiles from being created. Move it to Applications to make sure everything works. | Dock Tileは“アプリケーション”フォルダ以外の場所から実行されています。macOSが一時的な読み出し専用の場所からアプリを実行することがあり、その場合は新しいタイルを作成できなくなる可能性があります。すべてが正しく動作するように、“アプリケーション”フォルダに移動してください。 | machine | Message of the launch-time nudge to move the app to Applications |
| `alert.relocate.title` | Move Dock Tile to Applications? | Dock Tileを“アプリケーション”フォルダに移動しますか? | machine | Title of the prompt asking the user to move the app into the Applications folder |
| `alert.restartDock.checkbox` | Don't show this again | 今後このメッセージを表示しない | machine | Checkbox label to suppress future Dock restart alerts |
| `alert.restartDock.message` | Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected. | Dock Tileは変更を適用するためにDockを再起動します。これはタイルを追加、更新、または削除するたびに行われます。現在のDockの項目には影響しません。 | machine | Alert message explaining Dock restart |
| `alert.restartDock.title` | Dock Restart Required | Dockの再起動が必要です | machine | Alert title when Dock restart is required |
| `alert.revertToDock.message` | Your changes will be replaced by the version in the Dock. | 変更内容はDockのバージョンに置き換えられます。 | machine | Revert to Dock Version confirmation message: the tile's unapplied edits are discarded and the version its Dock icon was built from comes back |
| `app.name` | Dock Tile | Dock Tile | machine | App display name |
| `button.add` | Add | 追加 | machine | Add button label in file picker |
| `button.addToDock` | Add to Dock | Dockに追加 | machine | Button to add tile to Dock |
| `button.applyToTiles` | Apply | 適用 | machine | Confirm button that rebuilds tiles to apply popover settings |
| `button.back` | Back | 戻る | machine | Back button label |
| `button.cancel` | Cancel | キャンセル | machine | Cancel button in alerts |
| `button.checkForUpdates` | Check for Updates… | アップデートを確認… | machine | Button that triggers a manual Sparkle update check |
| `button.checkNow` | Check Now | 今すぐ確認 | machine | Settings → Software Update: button that triggers a manual Sparkle update check |
| `button.confirm` | Confirm | 確認 | machine | Confirm button for alert dialogs |
| `button.createNewTile` | Create New Tile | 新規タイルを作成 | machine | Smart Add sheet — neutral button that starts a blank tile instead of a suggestion |
| `button.delete` | Delete | 削除 | machine | Delete button |
| `button.done` | Done | 完了 | machine | Done button |
| `button.duplicate` | Duplicate | 複製 | machine | Duplicate button in context menu |
| `button.keep` | Keep | 残す | machine | Button to keep uninstalled apps in tiles (dismiss the removal prompt) |
| `button.moveToApplications` | Move to Applications | “アプリケーション”フォルダに移動 | machine | Button that moves the app into the Applications folder |
| `button.newTile` | New Tile | 新規タイル | machine | Button to create first tile on empty state |
| `button.notNow` | Not Now | 今はしない | machine | Dismiss button for the non-blocking move-to-Applications nudge |
| `button.openAccessibilitySettings` | Open Accessibility Settings… | アクセシビリティ設定を開く… | machine | Button that opens the Accessibility pane in System Settings (Reduce Motion) |
| `button.openLoginItems` | Open Login Items Settings… | ログイン項目設定を開く… | machine | Button that opens System Settings Login Items for approval |
| `button.remove` | Remove | 取り除く | machine | Remove button |
| `button.removeAll` | Remove All | すべて取り除く | machine | Button to remove all missing apps from tiles at once |
| `button.removeFromDock` | Remove from Dock | Dockから削除 | machine | Button to remove tile from Dock |
| `button.resetToDefaults` | Reset to Defaults | デフォルトに戻す | machine | Button that restores popover appearance settings to their defaults |
| `button.revert` | Revert | 戻す | machine | Confirm button of the Revert to Dock Version alert |
| `button.reviewInTiles` | Review in Tiles | タイルで確認 | machine | Button that navigates to the first tile containing a missing app |
| `button.save` | Save | 保存 | machine | Primary toolbar button that commits the popover appearance settings |
| `button.saving` | Applying… | 適用中… | machine | Loading label on the Save button while applying settings to Dock tiles |
| `button.scanForMissingApps` | Scan | スキャン | machine | Settings button that scans tiles for moved/uninstalled apps |
| `button.update` | Update | 更新 | machine | Update button when tile is already in Dock |
| `button.useThisTile` | Use This Tile | このタイルを使用 | machine | Smart Add sheet — button that creates a pre-filled tile from a suggestion |
| `emojiCategory.activity` | Activity | 活動 | machine | Emoji picker: section header |
| `emojiCategory.animalsNature` | Animals & Nature | 動物と自然 | machine | Emoji picker: section header |
| `emojiCategory.foodDrink` | Food & Drink | 食べ物と飲み物 | machine | Emoji picker: section header |
| `emojiCategory.objects` | Objects | 物 | machine | Emoji picker: section header |
| `emojiCategory.people` | People | 人々 | machine | Emoji picker: section header |
| `emojiCategory.symbols` | Symbols | 記号 | machine | Emoji picker: section header |
| `emojiCategory.travelPlaces` | Travel & Places | 旅行と場所 | machine | Emoji picker: section header |
| `empty.createFirstTile` | Create Your First Tile | 最初のタイルを作成 | machine | Header text for empty state |
| `empty.detail` | Detail | 詳細 | machine | Placeholder text in detail view |
| `empty.noApps` | No apps configured | アプリが設定されていません | machine | Empty state text when no apps configured |
| `empty.noTiles` | No Tiles | タイルなし | machine | Empty state text in sidebar |
| `error.appTranslocated` | Dock Tile is running from a temporary, read-only location and can't create tiles. Move it to your Applications folder and try again. | Dock Tileは一時的な読み出し専用の場所から実行されているため、タイルを作成できません。“アプリケーション”フォルダに移動してから、もう一度お試しください。 | machine | Error when the app is translocated and cannot generate helper bundles |
| `error.bundleBuildInProgress` | This tile is already being rebuilt. Wait for that to finish, then try again. | このタイルはすでに再構築中です。完了するまで待ってから、もう一度お試しください。 | machine | Error when a second build is requested for a tile whose helper bundle is already being built |
| `error.dockChangeNotKept` | The Dock didn't keep this change. Try again. | Dockはこの変更を保持しませんでした。もう一度お試しください。 | machine | Error when Dock Tile wrote a change to the Dock (add, update or hide a tile) but the Dock did not keep it, even after one retry |
| `error.failedToCodeSign` | Failed to code sign helper bundle | ヘルパーバンドルにコード署名できませんでした | machine | Error when code signing fails |
| `error.failedToCopyBundle` | Failed to copy bundle | バンドルをコピーできませんでした | machine | Error when bundle copy fails |
| `error.failedToReadInfoPlist` | Failed to read Info.plist | Info.plistを読み込めませんでした | machine | Error when Info.plist cannot be read |
| `error.failedToWriteInfoPlist` | Failed to write Info.plist | Info.plistに書き込めませんでした | machine | Error when Info.plist cannot be written |
| `error.mainAppNotFound` | Main Dock Tile.app not found | メインのDock Tile.appが見つかりません | machine | Error when main app bundle cannot be found |
| `filePicker.message` | Select one or more applications or folders to add | 追加するアプリケーションまたはフォルダを1つ以上選択してください | machine | Message in file picker dialog |
| `iconWeight.bold` | Bold | ボールド | machine | Customise: icon weight picker option |
| `iconWeight.heavy` | Heavy | ヘビー | machine | Customise: icon weight picker option |
| `iconWeight.light` | Light | ライト | machine | Customise: icon weight picker option |
| `iconWeight.medium` | Medium | ミディアム | machine | Customise: icon weight picker option |
| `iconWeight.regular` | Regular | レギュラー | machine | Customise: icon weight picker option |
| `iconWeight.semibold` | Semibold | セミボールド | machine | Customise: icon weight picker option |
| `label.apps.arrangement` | Arrangement | 配置 | machine | Customise Tile: Apps card row — the grid the face uses |
| `label.apps.arrangement.threeByThree` | 3 × 3 | 3 × 3 | machine | Customise Tile: Arrangement value for 5 or more apps |
| `label.apps.arrangement.twoByTwo` | 2 × 2 | 2 × 2 | machine | Customise Tile: Arrangement value for 2–4 apps |
| `label.apps.glass` | A glass folder that follows Light and Dark Mode. | ライトモードとダークモードに合わせて変化するガラスのフォルダです。 | machine | Customise Tile: fixed sentence after the Apps caption (decided 2026-10-19: the dark appearance is system-dark) |
| `label.apps.header` | Apps | アプリ | machine | Customise Tile: group header above the Apps card |
| `label.apps.note.all` | Shows all %lld apps, in tile order. | %lld 個のアプリをすべてタイル内の順序で表示します。 | machine | Customise Tile: Apps caption, 2–9 apps; %lld = app count |
| `label.apps.note.firstNine` | Shows the first 9 of %lld apps, in tile order. | %lld 個のアプリのうち最初の 9 個をタイル内の順序で表示します。 | machine | Customise Tile: Apps caption, more than nine apps; %lld = app count |
| `label.apps.note.none` | No apps yet — use Add under In This Tile. | まだアプリがありません。「このタイルの内容」の「追加」から追加してください。 | machine | Customise Tile: Apps caption when the tile has no apps (builder copy, not in the handoff) |
| `label.apps.note.one` | Shows the only app in this tile. | このタイルにある唯一のアプリを表示します。 | machine | Customise Tile: Apps caption, one app |
| `label.apps.shown` | Shown | 表示数 | machine | Customise Tile: Apps card row — how many apps the face shows |
| `label.apps.shownValue` | %1$lld of %2$lld | %2$lld 個中 %1$lld 個 | machine | Customise Tile: Apps card Shown value, e.g. 9 of 12; %1$lld = shown, %2$lld = total (positional so a language may reorder them) |
| `label.appsBackground` | Dock Icon Background | Dockアイコンの背景 | machine | App Grid inspector section for per-tile plate settings |
| `label.appsBackground.automatic` | Follow System | システムに合わせる | machine | App Grid background follows the macOS icon appearance |
| `label.appsBackground.charcoal` | Dark Grey | ダークグレー | machine | Fixed dark background for an App Grid icon |
| `label.appsBackground.custom` | Custom Colour | カスタムカラー | machine | Native colour picker for an App Grid icon background |
| `label.appsBackground.hint` | Applies to this tile only. | このタイルにのみ適用されます。 | machine | Caption under the App Grid background menu: the choice affects only this tile |
| `label.appsBackground.light` | Light | ライト | machine | Fixed light background for an App Grid icon |
| `label.appsFace.accessibility` | Apps face: showing %lld of this tile's apps | アプリ表示：このタイルのアプリを %lld 個表示中 | machine | VoiceOver label for a tile preview showing the Apps face; %lld = number of app icons shown |
| `label.background` | Background | 背景 | machine | Customise Tile: background row label |
| `label.background.colour` | Colour | カラー | machine | Customise Tile: Colour background chip |
| `label.background.colour.accessibility` | Colour, filled with your colour | カラー、選択した色で塗りつぶし | machine | VoiceOver label for the Colour chip |
| `label.background.hint.colour` | Filled with your colour | 選択した色で塗りつぶします | machine | Customise Tile: hint under Background when Colour |
| `label.background.hint.emojiColours` | Emoji keep their own colours. | 絵文字は元の色のままです。 | machine | Customise Tile: appended to the Background caption for an Emoji tile |
| `label.background.hint.mono` | White in Light Mode, black in Dark Mode | ライトモードでは白、ダークモードでは黒 | machine | Customise Tile: hint under Background when Mono |
| `label.background.hint.mono.static` | White tile with a coloured symbol | 白いタイルにカラーのシンボル | machine | Customise Tile: hint under Background when Mono on macOS 15 (static white tile) |
| `label.background.mono` | Mono | モノクロ | machine | Customise Tile: Mono background chip |
| `label.background.mono.accessibility` | Mono, white in Light Mode and black in Dark Mode | モノクロ、ライトモードでは白、ダークモードでは黒 | machine | VoiceOver label for the Mono chip |
| `label.background.mono.static.accessibility` | Mono, a white tile with a coloured symbol | モノクロ、白いタイルにカラーのシンボル | machine | VoiceOver label for the Mono chip on macOS 15 |
| `label.colour` | Colour | カラー | machine | Label for colour picker section |
| `label.colour.hint.deepened` | Deepened slightly so the symbol stays clear | シンボルが見やすいように少し濃くしました | machine | Customise Tile: colour hint when the fill was darkened for contrast |
| `label.colour.hint.emoji` | Emoji keep their own colours | 絵文字は元の色のままです | machine | Customise Tile: colour hint, Mono emoji tile (row disabled) |
| `label.colour.hint.fills` | Fills the tile | タイル全体を塗りつぶします | machine | Customise Tile: colour hint, Colour tile |
| `label.colour.hint.tints` | Tints the symbol | シンボルに色を付けます | machine | Customise Tile: Colour card caption for a Mono tile |
| `label.colour.hint.toned` | Toned for Light and Dark | ライトとダークに合わせて調整済み | machine | Customise Tile: colour hint, Mono tile |
| `label.colour.hint.toned.static` | Toned to stay clear on white | 白の上でも見やすいように調整済み | machine | Customise Tile: colour hint, Mono tile on macOS 15 |
| `label.iconSize` | Icon Size | アイコンサイズ | machine | Compact label for the icon size stepper (side-by-side with icon weight) |
| `label.iconWeight` | Icon Weight | アイコンの太さ | machine | Label for the SF Symbol weight picker |
| `label.missingAppsScan` | Missing Apps | 見つからないアプリ | machine | Settings row title for the missing-app scan |
| `label.missingAppsScanDescription` | Check your tiles for apps that have been moved or uninstalled. | 移動またはアンインストールされたアプリがないか、タイルを確認します。 | machine | Settings row description for the missing-app scan |
| `label.notInstalled` | Not installed | 未インストール | machine | Badge/kind text shown for an app whose bundle is no longer on disk |
| `label.popover.animation` | Animation | アニメーション | machine | Label for the popover animation segmented control |
| `label.popover.highlightOnHover` | Highlight on Hover | ポインタを重ねたときにハイライト | machine | Toggle label — show a background fill on the hovered item |
| `label.popover.layout` | Layout | レイアウト | machine | Label for the Grid/List preview toggle in popover settings |
| `label.popover.listAlwaysLabelled` | List view always shows labels | リスト表示では常にラベルが表示されます | machine | Hint shown beside the disabled Show Labels control when previewing List |
| `label.popover.showLabels` | Show Labels | ラベルを表示 | machine | Toggle label — show app names under grid icons |
| `label.popover.size` | Popover Size | ポップオーバーのサイズ | machine | Label for the popover size segmented control |
| `label.popover.spacing` | Spacing | 間隔 | machine | Label for the popover item spacing segmented control |
| `label.popover.tileSize` | Tile Size | タイルのサイズ | machine | Label for the icon/cell size control inside the popover |
| `label.shareAnalytics` | Share anonymous usage data | 匿名の使用状況データを共有 | machine | Label for the analytics opt-out toggle in Settings |
| `label.shareAnalyticsDescription` | Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected. | 匿名の使用状況データとクラッシュレポートを送信して、Dock Tileの改善にご協力ください。個人データは収集されません。 | machine | Explanation under the analytics toggle |
| `label.addAppsAndFolders` | Add Apps & Folders | アプリとフォルダを追加 | machine | Tooltip on the Add button in Tile Detail's In This Tile section |
| `label.appSwitcherNeedsShowTile` | Turn on Show Tile first — this only applies while the tile is in the Dock. | 先に“タイルを表示”をオンにしてください。この設定は、タイルがDockにあるときにのみ適用されます。 | machine | Tooltip on the disabled Show in App Switcher toggle when the tile is hidden |
| `label.showInAppSwitcher` | Show in App Switcher | アプリスイッチャーに表示 | machine | Label for app switcher toggle |
| `label.showTile` | Show Tile | タイルを表示 | machine | Label for show tile toggle |
| `label.softwareUpdate` | Software Update | ソフトウェアアップデート | machine | Title of the software-update row in General settings |
| `label.softwareUpdateDescription` | You’re using version %@. Dock Tile checks for updates automatically. | バージョン%@を使用しています。Dock Tileはアップデートを自動的に確認します。 | machine | Description under the software-update row; %@ is the current version |
| `label.startAtLogin` | Start tiles at login | ログイン時にタイルを起動 | machine | Label for the start-at-login toggle in Settings |
| `label.startAtLoginDescription` | Keep your tiles ready in the Dock so they respond instantly after you restart your Mac. | Macを再起動した後もすぐに反応するように、タイルをDockで準備しておきます。 | machine | Explanation under the start-at-login toggle |
| `label.style.appPreview` | App Grid | アプリグリッド | machine | Customise Tile: Style picker card for the Apps face |
| `label.symbolColour` | Symbol Colour | シンボルのカラー | machine | Customise Tile: colour row label for a Mono tile |
| `label.tileColour` | Tile Colour | タイルのカラー | machine | Customise Tile: Colour card header for a Colour tile |
| `label.tileIcon` | Tile Icon | タイルのアイコン | machine | Label for tile icon section |
| `label.tileIconSize` | Tile Icon Size | タイルのアイコンサイズ | machine | Label for tile icon size |
| `label.tileName` | Tile Name | タイル名 | machine | Label for tile name field |
| `layout.grid` | Grid | グリッド | machine | Grid layout option |
| `layout.list` | List | リスト | machine | List layout option |
| `itemMenu.forceQuit` | Force Quit | 強制終了 | machine | Popover item context menu: force quit (shown while Option is held) |
| `itemMenu.getInfo` | Get Info | 情報を見る | machine | Popover item context menu: open Finder's Get Info window |
| `itemMenu.hide` | Hide | 非表示 | machine | Popover item context menu: hide the running app |
| `itemMenu.open` | Open | 開く | machine | Popover item context menu: open the app or folder |
| `itemMenu.quickLook` | Quick Look | クイックルック | machine | Popover item context menu: preview the item with Quick Look |
| `itemMenu.quit` | Quit | 終了 | machine | Popover item context menu: quit the running app |
| `itemMenu.share` | Share… | 共有… | machine | Popover item context menu: open the share sheet for a folder |
| `itemMenu.showInFinder` | Show in Finder | Finderに表示 | machine | Popover item context menu: reveal the item in Finder |
| `menu.configure` | Configure... | タイルを設定… | machine | Menu item to configure tile (opens main app) |
| `menu.configureTile` | Configure Tile | タイルを設定 | machine | Tooltip for gear icon in popover |
| `menu.configureTileItem` | Configure Tile… | タイルを設定… | machine | Tile submenu item in the menu bar and Dock menus: opens that tile in Dock Tile's window |
| `menu.copyDiagnostics` | Copy Diagnostics | 診断情報をコピー | machine | File menu item that copies recent diagnostic logs to the clipboard |
| `menu.hideInspector` | Hide Inspector | インスペクタを非表示 | machine | View menu item (Hide Inspector, ⌥⌘I) that closes the Customise Tile inspector |
| `menu.newTile` | New Tile | 新規タイル | machine | Menu item to create a new tile |
| `menu.noAppsConfigured` | No apps configured | アプリが設定されていません | machine | Dock menu: disabled row when the tile has no apps |
| `menu.noConfiguration` | No configuration | 設定が見つかりません | machine | Dock menu: disabled row when the tile's config cannot be found |
| `menu.openDockTile` | Open Dock Tile… | Dock Tileを開く… | machine | Menu bar and Dock menu item that opens Dock Tile's main window |
| `menu.openInFinder` | Open in Finder | Finderで開く | machine | Menu item to open in Finder |
| `menu.options` | Options | オプション | machine | Section divider in menu |
| `menu.quitDockTile` | Quit Dock Tile | Dock Tileを終了 | machine | Menu bar icon's menu: quits Dock Tile (tiles already in the Dock keep working) |
| `menu.settings` | Settings… | 設定… | machine | App menu item that opens the inline Settings pane (⌘,) |
| `menu.showInspector` | Show Inspector | インスペクタを表示 | machine | View menu item (Show Inspector, ⌥⌘I) that opens the Customise Tile inspector |
| `popover.option.animation.default` | Default | デフォルト | machine | Animation tier — default |
| `popover.option.animation.fast` | Fast | 高速 | machine | Animation tier — fast |
| `popover.option.animation.none` | None | なし | machine | Animation tier — none |
| `popover.option.comfortable` | Comfortable | 標準 | machine | Spacing tier — comfortable |
| `popover.option.compact` | Compact | コンパクト | machine | Spacing tier — compact |
| `popover.option.large` | Large | 大 | machine | Size tier — large |
| `popover.option.medium` | Medium | 中 | machine | Size tier — medium |
| `popover.option.small` | Small | 小 | machine | Size tier — small |
| `popover.option.spacious` | Spacious | ゆったり | machine | Spacing tier — spacious |
| `search.emojis` | Search emojis | 絵文字を検索 | machine | Search placeholder for emojis |
| `search.symbols` | Search symbols | シンボルを検索 | machine | Search placeholder for symbols |
| `settings.dockLock` | Dock Lock | Dockロック | machine | Section header for the Dock Lock feature in Settings |
| `settings.dockLock.accessibilityGranted` | Accessibility access granted | アクセシビリティへのアクセスが許可されています | machine | Status shown when Accessibility permission is granted |
| `settings.dockLock.accessibilityNeeded` | Accessibility access required | アクセシビリティへのアクセスが必要です | machine | Status shown when Accessibility permission is missing |
| `settings.dockLock.accessibilityNeededDetail` | Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings. | Dockを固定するには、Dock Tileにアクセシビリティへのアクセスを許可する必要があります。システム設定でDock Tileをオンにしてください。 | machine | Explanation of why Accessibility access is needed |
| `settings.dockLock.anchor` | Keep Dock on | Dockを表示する画面 | machine | Label for the anchor display picker |
| `settings.dockLock.defaultDisplay` | Default (follow macOS) | デフォルト（macOSに従う） | machine | First option in the anchor picker — no lock, macOS default behaviour |
| `settings.dockLock.description` | Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose. | マルチディスプレイ環境で、Dockが画面間を移動しないようにします。Dockは選択したディスプレイに留まります。 | machine | Explanation under the Dock Lock toggle |
| `settings.dockLock.lockedTo` | Dock is locked to %@ | Dockは%@に固定されています | machine | Indicator confirming the display the Dock is pinned to |
| `settings.dockLock.mainDisplay` | Main | メイン | machine | Suffix marking the main display in the anchor picker |
| `settings.dockLock.moveFailed` | Couldn't move the Dock to %@. Make sure that display isn't mirrored, then try again. | Dockを%@に移動できませんでした。そのディスプレイがミラーリングされていないことを確認してから、もう一度お試しください。 | machine | Error shown when the Dock could not be relocated |
| `settings.dockLock.moving` | Moving Dock to %@… | Dockを%@に移動中… | machine | Progress message shown while the Dock is being relocated |
| `settings.dockLock.note` | Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays. | Dockが下、左、右のどの位置にあっても機能します。Dockを1つの画面に固定すると、ほかのディスプレイのその端で数ピクセルが確保されます。 | machine | Footnote describing Dock Lock behaviour and trade-off |
| `settings.dockLock.openSettings` | Open System Settings… | システム設定を開く… | machine | Button that opens the Accessibility pane in System Settings |
| `settings.dockLock.perSetupNote` | Each set of connected displays remembers its own choice. | 接続しているディスプレイの組み合わせごとに、選択が記憶されます。 | machine | Footnote under the Dock Lock display picker: the chosen display is remembered separately for each combination of connected displays (home, work…) |
| `settings.dockLock.primer.body` | Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens. | Dockロックは、Dockを選択したディスプレイに留めます。macOSがDockをほかの画面に移動しないようにするため、Dock Tileにはアクセシビリティへのアクセスが必要です。 | machine | Explanation in the permission primer |
| `settings.dockLock.primer.continue` | Continue | 続ける | machine | Primary button in the permission primer that triggers the macOS dialog |
| `settings.dockLock.primer.notNow` | Not Now | 今はしない | machine | Secondary button in the permission primer that cancels enabling Dock Lock |
| `settings.dockLock.primer.reassurance` | Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time. | 次に、システム設定でDock Tileをオンにするよう、macOSから求められます。この設定はいつでもオフにできます。 | machine | Reassurance line in the permission primer about what happens next |
| `settings.dockLock.primer.title` | Allow Accessibility Access | アクセシビリティへのアクセスを許可 | machine | Title of the permission primer shown before requesting Accessibility |
| `settings.dockLock.retry` | Try Again | 再試行 | machine | Button to retry a failed Dock relocation |
| `settings.dockLock.singleDisplay` | Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it. | Dockロックを使用するには、2台目のディスプレイを接続してください。画面が1つの場合、DockはmacOSが配置した場所に留まります。 | machine | Note shown when only one display is connected |
| `settings.dockLock.toggle` | Lock Dock to one display | Dockを1つのディスプレイに固定 | machine | Label for the Dock Lock enable toggle |
| `settings.general` | General | 一般 | machine | Title of the General settings pane |
| `settings.login.registrationFailed` | Couldn’t turn this on — macOS refused the registration. %@ | オンにできませんでした。macOSが登録を拒否しました。%@ | machine | Shown under the Start tiles at login toggle when SMAppService registration failed; %@ is the system error |
| `settings.login.requiresApproval` | Approve Dock Tile in Login Items to finish enabling this. | この設定を有効にするには、ログイン項目でDock Tileを承認してください。 | machine | Shown when macOS is holding the login item for user approval |
| `settings.menuBar` | Menu Bar | メニューバー | machine | General: section holding the menu bar icon toggle |
| `settings.menuBar.toggle` | Show Dock Tile in the menu bar | メニューバーにDock Tileを表示 | machine | General: toggle that adds Dock Tile's icon to the menu bar, listing the tiles and their apps |
| `settings.menuBar.toggleDescription` | Lists the tiles in your Dock and their apps. Dock Tile keeps running in the background while this is on. | Dockにあるタイルとそのアプリを一覧表示します。オンのあいだ、Dock Tileはバックグラウンドで実行され続けます。 | machine | General: caption under the menu bar icon toggle |
| `settings.popover` | Popover | ポップオーバー | machine | Section header and pane title for popover appearance settings |
| `settings.popover.configure` | Configure | 設定対象 | machine | Label for the Grid/List panel switcher in popover settings |
| `settings.popover.configure.subtitle` | Each layout's settings are saved independently | 各レイアウトの設定は個別に保存されます | machine | Subtitle explaining that Grid and List popover settings are stored separately |
| `settings.popover.footer` | These settings apply to every tile's popover. List view always shows labels. Animation follows your system Reduce Motion setting. | これらの設定はすべてのタイルのポップオーバーに適用されます。リスト表示では常にラベルが表示されます。アニメーションはシステムの“視差効果を減らす”設定に従います。 | machine | Explanatory footer under the popover settings form |
| `settings.popover.reduceMotion` | Animation is off because Reduce Motion is on in System Settings. | システム設定で“視差効果を減らす”がオンになっているため、アニメーションはオフです。 | machine | Caption shown under Animation when the system Reduce Motion setting forces it off |
| `settings.popover.section.tiles` | Tiles | タイル | machine | Section header for the per-item controls inside the popover settings |
| `sidebar.section.settings` | Settings | 設定 | machine | Sidebar section header for the inline app settings panes |
| `sidebar.section.tiles` | Tiles | タイル | machine | Sidebar section header for the list of dock tiles |
| `sidebar.title` | Dock Tile | Dock Tile | machine | Navigation title for sidebar |
| `smartAdd.identity.browse` | Browse | ブラウズ | machine | Smart Add: suggested tile name for browsers |
| `smartAdd.identity.chat` | Chat | チャット | machine | Smart Add: suggested tile name for social apps |
| `smartAdd.identity.ship` | Ship | 開発 | machine | Smart Add: suggested tile name for developer tools |
| `smartAdd.identity.together` | Together | セット | machine | Smart Add: suggested tile name for apps opened together |
| `smartAdd.identity.watch` | Watch | 視聴 | machine | Smart Add: suggested tile name for video apps |
| `smartAdd.identity.work` | Work | 仕事 | machine | Smart Add: suggested tile name for productivity apps |
| `smartAdd.privacyFootnote` | Learned on your Mac. Never leaves your device. | このMac上で学習します。データがデバイスの外に出ることはありません。 | machine | Footer note stating Smart Add suggestions are computed on-device only |
| `smartAdd.provenanceBanner` | Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to your Dock. | 最近使用したアプリをもとに、スマート追加で作成されたタイルです。名前やスタイル、アプリを編集してから、Dockに追加してください。 | machine | Banner shown atop Tile Detail when a tile was just created by Smart Add |
| `smartAdd.reason.byCategory` | By category | カテゴリ別 | machine | Reason chip — apps grouped by their app category |
| `smartAdd.reason.mostUsed` | Most used this week | 今週よく使用 | machine | Reason chip — the most-used cluster this week |
| `smartAdd.reason.openedTogether` | Opened together | よく一緒に開く | machine | Reason chip — apps repeatedly opened in the same session |
| `smartAdd.settings.sectionHeader` | Smart Add | スマート追加 | machine | General settings section header for the Smart Add toggle |
| `smartAdd.settings.toggleDescription` | Learned on your Mac. Never leaves your device. | このMac上で学習します。データがデバイスの外に出ることはありません。 | machine | General: Smart Add toggle description |
| `smartAdd.settings.toggleTitle` | Suggest tiles from my apps | 使用中のアプリからタイルを提案 | machine | General: Smart Add toggle title |
| `smartAdd.title` | Add a Tile | タイルを追加 | machine | Header title of the Smart Add suggestion sheet |
| `subtitle.chooseColour` | Choose a background colour for your tile | タイルの背景色を選択してください | machine | Subtitle for colour picker section |
| `subtitle.configureToAdd` | Configure to add apps | 設定してアプリを追加 | machine | Subtitle in empty state (grid view only) |
| `subtitle.iconSize` | Adjust the size of your icon within the tile | タイル内のアイコンのサイズを調整します | machine | Subtitle for icon size section |
| `symbolCategory.accessibility` | Accessibility | アクセシビリティ | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.all` | All | すべて | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.arrows` | Arrows | 矢印 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.automotive` | Automotive | 自動車 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.cameraandphotos` | Camera & Photos | カメラと写真 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.commerce` | Commerce | コマース | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.communication` | Communication | コミュニケーション | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.connectivity` | Connectivity | コネクティビティ | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.devices` | Devices | デバイス | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.draw` | Draw | 描画 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.editing` | Editing | 編集 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.fitness` | Fitness | フィットネス | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.gaming` | Gaming | ゲーム | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.health` | Health | ヘルスケア | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.home` | Home | ホーム | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.human` | Human | 人 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.indices` | Indices | インデックス | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.keyboard` | Keyboard | キーボード | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.maps` | Maps | マップ | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.math` | Maths | 数学 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.media` | Media | メディア | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.multicolor` | Multicolour | マルチカラー | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.nature` | Nature | 自然 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.objectsandtools` | Objects & Tools | オブジェクトとツール | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.privacyandsecurity` | Privacy & Security | プライバシーとセキュリティ | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.shapes` | Shapes | 図形 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.textformatting` | Text Formatting | テキストフォーマット | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.time` | Time | 時計 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.transportation` | Transportation | 交通 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.variable` | Variable | 可変 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.weather` | Weather | 天気 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.whatsnew` | What's New | 新機能 | machine | Symbol picker: section header (SF Symbols category) |
| `tab.emoji` | Emoji | 絵文字 | machine | Emoji tab label |
| `tab.symbol` | Symbol | シンボル | machine | Symbol tab label |
| `title.customiseTile` | Customise Tile | タイルをカスタマイズ | machine | Title of the Customise Tile inspector beside Tile Detail |
| `title.deleteTile` | Delete Tile | タイルを削除 | machine | Alert title for delete confirmation |
| `title.revertToDock` | Revert to Dock Version? | Dockのバージョンに戻しますか？ | machine | Alert title: discard the tile's unapplied edits and go back to the version in the Dock |
| `tooltip.createNewTile` | Create new tile | 新規タイルを作成 | machine | Tooltip when add button is enabled |
| `tooltip.editFirst` | Edit current tile before creating another | 別のタイルを作成する前に、現在のタイルを編集してください | machine | Tooltip when add button is disabled |
| `button.addATile` | Add a Tile… | タイルを追加… | machine | Sidebar + / empty state: opens the Add a Tile dialog |
| `sidebar.dockTileSection` | Dock Tile | Dock Tile | machine | Sidebar section holding About |
| `settings.addingTiles` | Adding Tiles | タイルの追加 | machine | General: section holding the Smart Add toggle and the Add a Tile row |
| `about.title` | About | 情報 | machine | About pane title |
| `about.version` | Version %@ | バージョン%@ | machine | About: version line |
| `about.website` | Website | Webサイト | machine | About: website row label |
| `about.feedbackTitle` | Found a bug or have an idea? | バグの報告やアイデアはありますか? | machine | About: feedback card title |
| `about.feedbackBody` | Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal. | フィードバックは開発者に直接届きます。診断情報として、アプリとそのタイルの動作ログが添付されます。個人情報は含まれません。 | machine | About: feedback card body |
| `about.sendFeedback` | Send Feedback… | フィードバックを送信… | machine | About: opens the feedback email |
| `about.alsoFrom` | Also from Happy Machines | Happy Machinesのほかの製品 | machine | About: studio section header |
| `about.studioTitle` | Made by Happy Machines Company | Happy Machines Company製 | machine | About: studio row title |
| `about.studioSubtitle` | A tiny product studio building nifty Mac apps that each fix one thing well. | 1つのことをしっかり解決する、気の利いたMacアプリを作る小さなプロダクトスタジオです。 | machine | About: studio row subtitle |
| `about.spadesTitle` | Spades Audio | Spades Audio | machine | About: sibling product row title |
| `about.spadesSubtitle` | Per-app volume, EQ and output control for your Mac, from the menu bar. | メニューバーから、Macのアプリごとの音量、EQ、出力を制御できます。 | machine | About: sibling product subtitle |
| `about.learnMore` | Learn More… | 詳しく見る… | machine | About: opens spadesaudio.com |
| `menu.aboutDockTile` | About Dock Tile | Dock Tileについて | machine | App menu |
| `popover.editing.remove` | Remove | 取り除く | machine | Context menu / remove badge in the tile editor |
| `section.inThisTile` | In This Tile | このタイルの内容 | machine | Tile Detail: apps section header |
| `label.editorHint` | Hover to remove · Drag to reorder | ポインタを重ねて取り除く · ドラッグして並べ替え | machine | Tile Detail: apps section caption |
| `tooltip.deleteTile` | Delete Tile | タイルを削除 | machine | Tile Detail: trash button tooltip |
| `smartAdd.blankTitle` | Create a blank tile | 空のタイルを作成 | machine | Add a Tile: blank row title |
| `smartAdd.blankSubtitle` | Name it, pick an icon and add apps yourself. | 名前を付け、アイコンを選び、アプリを自分で追加します。 | machine | Add a Tile: blank row subtitle |
| `smartAdd.orStartFrom` | or start from what you use | または、よく使うものから始める | machine | Add a Tile: rule between blank row and suggestions |
| `smartAdd.noSuggestions` | No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General. | まだ提案はありません。Dock Tileは開いたアプリから学習します。この機能は“一般”でオフにできます。 | machine | Add a Tile: empty suggestions note |
| `label.addAppsTooltip` | Add apps or folders to this tile | このタイルにアプリまたはフォルダを追加 | machine | Tooltip on the + Add button above the tile editor's popover preview. |
| `empty.createFirstTileDescription` | Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use. | アプリやフォルダを1つのDockアイコンにまとめましょう。空のタイルから始めることも、使用しているアプリから提案されたタイルから始めることもできます。 | machine | Zero-tiles description |
| `popover.editing.noAppsTitle` | No apps yet | まだアプリがありません | machine | Tile editor: empty popover preview, title line. |
| `popover.editing.noAppsSubtitle` | Use Add to choose what opens from this tile. | “追加”を使って、このタイルから開く項目を選択してください。 | machine | Tile editor: empty popover preview, subtitle line. |
| `about.diagnosticsBody` | A log of what the app and its tiles did. Attach it to an email when something looks wrong — it contains nothing personal. | アプリとそのタイルの動作ログです。問題が起きたときはメールに添付してください。個人情報は含まれません。 | machine | About: Copy Diagnostics row description. |
| `about.feedbackRowBody` | Feedback goes straight to the developer. | フィードバックは開発者に直接届きます。 | machine | About: Send Feedback row description. |
| `about.diagnosticsTitle` | Diagnostics | 診断情報 | machine | About: Copy Diagnostics row label. |
| `button.copy` | Copy | コピー | machine | Generic Copy button label. |
| `tooltip.openSettings` | Settings | 設定 | machine | Tooltip for the settings toolbar button |
| `tooltip.revertToDock` | Revert to Dock Version | Dockのバージョンに戻す | machine | Tile Detail: revert button tooltip and accessibility label, and the File menu item — discards unapplied edits, restoring the version the tile's Dock icon was built from |
| `tooltip.toggleCustomiseTile` | Toggle Customise Tile | 「タイルをカスタマイズ」の表示/非表示を切り替え | machine | Tooltip and accessibility label of the toolbar button that opens or closes the Customise Tile inspector |
| `tooltip.toggleCustomiser` | Toggle Customiser | カスタマイズパネルの表示/非表示を切り替え | machine | Tooltip and accessibility label of the Tile Detail icon, which opens or closes the Customise Tile inspector when clicked |
| `translation.helpImprove` | Help Improve… | 改善に協力… | machine | Button: opens the language's review sheet on GitHub |
| `translation.invite.message` | This translation was made by a machine and has not yet been checked by a native speaker. If something reads wrong, you can fix it on GitHub — no coding needed. | この翻訳は機械翻訳によるもので、ネイティブスピーカーによる確認はまだ行われていません。おかしな表現があれば、GitHubで修正できます。コーディングは不要です。 | machine | One-time alert message inviting translation review |
| `translation.invite.title` | Dock Tile now speaks your language | Dock Tileが日本語に対応しました | machine | One-time alert title on first launch in a machine-translated language |
| `translation.reviewLine` | Machine translated. Not yet checked by a native speaker. | 機械翻訳です。ネイティブスピーカーによる確認はまだ行われていません。 | machine | About: translation row description. Reviewers replace this in their language with who reviewed it, e.g. 'Reviewed by @handle'. |
| `translation.title` | Translation | 翻訳 | machine | About: translation row label (shown only when the UI runs in a non-English language) |
