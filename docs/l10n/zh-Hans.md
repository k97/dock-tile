# Dock Tile — 简体中文 (zh-Hans)

How to review: [docs/l10n/README.md](README.md). Edit the **Translation** column, set
**Status** to `reviewed` for every row you checked (changed or not), then "Propose changes".
Status values: `machine` (not yet checked by a person), `reviewed`, `todo` (no translation yet).
Keep `%@`-style placeholders exactly as they are. `\n` means a line break, `\|` a pipe.

| Key | English | Translation | Status | Context |
|---|---|---|---|---|
| `alert.applyPopover.message` | Dock Tile will rebuild your pinned tiles with the new popover look and briefly restart the Dock. Your other Dock items won't be affected. | Dock Tile将使用新的弹出面板外观重建程序坞中的磁贴，并短暂重新启动程序坞。程序坞中的其他项目不受影响。 | machine | Confirmation message warning the Dock will restart when applying popover settings |
| `alert.applyPopover.title` | Apply to your Dock tiles? | 要应用到程序坞中的磁贴吗？ | machine | Confirmation title before rebuilding tiles to apply popover appearance settings |
| `alert.configUnreadable.message` | Your tiles haven't been changed. Dock Tile couldn't open its settings file and will quit. Check that you can open %@, then open Dock Tile again. | 你的磁贴未被更改。Dock Tile无法打开其设置文件，将会退出。请确认你可以打开%@，然后再次打开Dock Tile。 | machine | Launch alert message when the tile settings file can't be read; %@ = the file's full path. The app quits when the alert closes. |
| `alert.configUnreadable.quit` | Quit | 退出 | machine | Only button of the can't-read-tiles launch alert; quits Dock Tile |
| `alert.configUnreadable.title` | Dock Tile Can't Read Your Tiles | Dock Tile无法读取你的磁贴 | machine | Launch alert title: the tile settings file exists but could not be opened; the app quits after it |
| `alert.deleteTile.message` | This will permanently delete the tile and remove it from the dock. | 此操作将永久删除该磁贴，并将其从程序坞中移除。 | machine | Delete-tile confirmation message |
| `alert.missingApps.message` | Some apps in your tiles can't be found on this Mac. Remove them from your tiles? | 你的磁贴中有些App在这台Mac上找不到了。要将它们从磁贴中移除吗？ | machine | Alert message offering to remove uninstalled apps from tiles |
| `alert.missingApps.title` | Some apps are no longer installed | 部分App已不再安装 | machine | Alert title when apps referenced by tiles can't be found on disk |
| `alert.missingAppsScan.foundMessage` | These apps can't be found on this Mac: | 在这台Mac上找不到以下App： | machine | Intro line of the manual scan results dialog; a list of tiles/apps follows |
| `alert.missingAppsScan.noneMessage` | Every app in your tiles is currently installed. | 你的磁贴中的所有App目前均已安装。 | machine | Message of the manual scan dialog when nothing is missing |
| `alert.missingAppsScan.noneTitle` | No Missing Apps | 没有缺失的App | machine | Title of the manual scan dialog when every tile app is installed |
| `alert.relocate.blockingMessage` | Dock Tile can't create or update this tile because it's running from a temporary, read-only location. This happens when the app is launched from Downloads. Move Dock Tile to your Applications folder and try again. | Dock Tile无法创建或更新此磁贴，因为它正从一个临时的只读位置运行。从“下载”文件夹打开App时会出现这种情况。请将Dock Tile移到“应用程序”文件夹，然后重试。 | machine | Message shown when a tile action is blocked because the app is translocated |
| `alert.relocate.checkbox` | Don't ask again | 不再询问 | machine | Checkbox to suppress future move-to-Applications nudges |
| `alert.relocate.message` | Dock Tile is running from outside your Applications folder. macOS may run it from a temporary, read-only location, which can stop new tiles from being created. Move it to Applications to make sure everything works. | Dock Tile正在“应用程序”文件夹之外运行。macOS可能会从临时的只读位置运行它，导致无法创建新磁贴。请将它移到“应用程序”文件夹，以确保一切正常。 | machine | Message of the launch-time nudge to move the app to Applications |
| `alert.relocate.title` | Move Dock Tile to Applications? | 要将Dock Tile移到“应用程序”文件夹吗？ | machine | Title of the prompt asking the user to move the app into the Applications folder |
| `alert.restartDock.checkbox` | Don't show this again | 不再显示 | machine | Checkbox label to suppress future Dock restart alerts |
| `alert.restartDock.message` | Dock Tile restarts the Dock to apply changes. This happens whenever you add, update, or remove tiles. Your current Dock items won't be affected. | Dock Tile会重新启动程序坞以应用更改。每次添加、更新或移除磁贴时都会如此。程序坞中现有的项目不受影响。 | machine | Alert message explaining Dock restart |
| `alert.restartDock.title` | Dock Restart Required | 需要重新启动程序坞 | machine | Alert title when Dock restart is required |
| `app.name` | Dock Tile | Dock Tile | machine | App display name |
| `button.add` | Add | 添加 | machine | Add button label in file picker |
| `button.addToDock` | Add to Dock | 添加到程序坞 | machine | Button to add tile to Dock |
| `button.applyToTiles` | Apply | 应用 | machine | Confirm button that rebuilds tiles to apply popover settings |
| `button.back` | Back | 返回 | machine | Back button label |
| `button.cancel` | Cancel | 取消 | machine | Cancel button in alerts |
| `button.checkForUpdates` | Check for Updates… | 检查更新… | machine | Button that triggers a manual Sparkle update check |
| `button.checkNow` | Check Now | 立即检查 | machine | Settings → Software Update: button that triggers a manual Sparkle update check |
| `button.confirm` | Confirm | 确认 | machine | Confirm button for alert dialogs |
| `button.createNewTile` | Create New Tile | 新建磁贴 | machine | Smart Add sheet — neutral button that starts a blank tile instead of a suggestion |
| `button.delete` | Delete | 删除 | machine | Delete button |
| `button.done` | Done | 完成 | machine | Done button |
| `button.duplicate` | Duplicate | 复制 | machine | Duplicate button in context menu |
| `button.keep` | Keep | 保留 | machine | Button to keep uninstalled apps in tiles (dismiss the removal prompt) |
| `button.moveToApplications` | Move to Applications | 移到“应用程序”文件夹 | machine | Button that moves the app into the Applications folder |
| `button.newTile` | New Tile | 新建磁贴 | machine | Button to create first tile on empty state |
| `button.notNow` | Not Now | 以后 | machine | Dismiss button for the non-blocking move-to-Applications nudge |
| `button.openAccessibilitySettings` | Open Accessibility Settings… | 打开无障碍设置… | machine | Button that opens the Accessibility pane in System Settings (Reduce Motion) |
| `button.openLoginItems` | Open Login Items Settings… | 打开登录项设置… | machine | Button that opens System Settings Login Items for approval |
| `button.remove` | Remove | 移除 | machine | Remove button |
| `button.removeAll` | Remove All | 全部移除 | machine | Button to remove all missing apps from tiles at once |
| `button.removeFromDock` | Remove from Dock | 从程序坞中移除 | machine | Button to remove tile from Dock |
| `button.resetToDefaults` | Reset to Defaults | 恢复默认设置 | machine | Button that restores popover appearance settings to their defaults |
| `button.reviewInTiles` | Review in Tiles | 在磁贴中查看 | machine | Button that navigates to the first tile containing a missing app |
| `button.save` | Save | 保存 | machine | Primary toolbar button that commits the popover appearance settings |
| `button.saving` | Applying… | 正在应用… | machine | Loading label on the Save button while applying settings to Dock tiles |
| `button.scanForMissingApps` | Scan | 扫描 | machine | Settings button that scans tiles for moved/uninstalled apps |
| `button.update` | Update | 更新 | machine | Update button when tile is already in Dock |
| `button.useThisTile` | Use This Tile | 使用此磁贴 | machine | Smart Add sheet — button that creates a pre-filled tile from a suggestion |
| `emojiCategory.activity` | Activity | 活动 | machine | Emoji picker: section header |
| `emojiCategory.animalsNature` | Animals & Nature | 动物与自然 | machine | Emoji picker: section header |
| `emojiCategory.foodDrink` | Food & Drink | 食物与饮料 | machine | Emoji picker: section header |
| `emojiCategory.objects` | Objects | 物体 | machine | Emoji picker: section header |
| `emojiCategory.people` | People | 人物 | machine | Emoji picker: section header |
| `emojiCategory.symbols` | Symbols | 符号 | machine | Emoji picker: section header |
| `emojiCategory.travelPlaces` | Travel & Places | 旅行与地点 | machine | Emoji picker: section header |
| `empty.createFirstTile` | Create Your First Tile | 创建你的第一个磁贴 | machine | Header text for empty state |
| `empty.detail` | Detail | 详细信息 | machine | Placeholder text in detail view |
| `empty.noApps` | No apps configured | 未配置App | machine | Empty state text when no apps configured |
| `empty.noTiles` | No Tiles | 没有磁贴 | machine | Empty state text in sidebar |
| `error.appTranslocated` | Dock Tile is running from a temporary, read-only location and can't create tiles. Move it to your Applications folder and try again. | Dock Tile正从临时的只读位置运行，无法创建磁贴。请将它移到“应用程序”文件夹，然后重试。 | machine | Error when the app is translocated and cannot generate helper bundles |
| `error.bundleBuildInProgress` | This tile is already being rebuilt. Wait for that to finish, then try again. | 此磁贴正在重建。请等待完成后再试。 | machine | Error when a second build is requested for a tile whose helper bundle is already being built |
| `error.dockChangeNotKept` | The Dock didn't keep this change. Try again. | 程序坞未能保留此更改。请再试一次。 | machine | Error when Dock Tile wrote a change to the Dock (add, update or hide a tile) but the Dock did not keep it, even after one retry |
| `error.failedToCodeSign` | Failed to code sign helper bundle | 辅助程序包代码签名失败 | machine | Error when code signing fails |
| `error.failedToCopyBundle` | Failed to copy bundle | 拷贝程序包失败 | machine | Error when bundle copy fails |
| `error.failedToReadInfoPlist` | Failed to read Info.plist | 读取Info.plist失败 | machine | Error when Info.plist cannot be read |
| `error.failedToWriteInfoPlist` | Failed to write Info.plist | 写入Info.plist失败 | machine | Error when Info.plist cannot be written |
| `error.mainAppNotFound` | Main Dock Tile.app not found | 找不到主程序Dock Tile.app | machine | Error when main app bundle cannot be found |
| `filePicker.message` | Select one or more applications or folders to add | 选择要添加的一个或多个App或文件夹 | machine | Message in file picker dialog |
| `iconWeight.bold` | Bold | 粗体 | machine | Customise: icon weight picker option |
| `iconWeight.heavy` | Heavy | 特黑体 | machine | Customise: icon weight picker option |
| `iconWeight.light` | Light | 细体 | machine | Customise: icon weight picker option |
| `iconWeight.medium` | Medium | 中黑体 | machine | Customise: icon weight picker option |
| `iconWeight.regular` | Regular | 常规体 | machine | Customise: icon weight picker option |
| `iconWeight.semibold` | Semibold | 中粗体 | machine | Customise: icon weight picker option |
| `label.apps.arrangement` | Arrangement | 排列 | machine | Customise Tile: Apps card row — the grid the face uses |
| `label.apps.arrangement.threeByThree` | 3 × 3 | 3 × 3 | machine | Customise Tile: Arrangement value for 5 or more apps |
| `label.apps.arrangement.twoByTwo` | 2 × 2 | 2 × 2 | machine | Customise Tile: Arrangement value for 2–4 apps |
| `label.apps.glass` | A glass folder that follows Light and Dark Mode. | 跟随浅色和深色模式变化的玻璃文件夹。 | machine | Customise Tile: fixed sentence after the Apps caption (decided 2026-10-19: the dark appearance is system-dark) |
| `label.apps.header` | Apps | App | machine | Customise Tile: group header above the Apps card |
| `label.apps.note.all` | Shows all %lld apps, in tile order. | 按磁贴中的顺序显示全部 %lld 个App。 | machine | Customise Tile: Apps caption, 2–9 apps; %lld = app count |
| `label.apps.note.firstNine` | Shows the first 9 of %lld apps, in tile order. | 按磁贴中的顺序显示 %lld 个App中的前 9 个。 | machine | Customise Tile: Apps caption, more than nine apps; %lld = app count |
| `label.apps.note.none` | No apps yet — use Add under In This Tile. | 还没有App——请在“此磁贴中的项目”中点按“添加”。 | machine | Customise Tile: Apps caption when the tile has no apps (builder copy, not in the handoff) |
| `label.apps.note.one` | Shows the only app in this tile. | 显示此磁贴中唯一的App。 | machine | Customise Tile: Apps caption, one app |
| `label.apps.shown` | Shown | 显示 | machine | Customise Tile: Apps card row — how many apps the face shows |
| `label.apps.shownValue` | %1$lld of %2$lld | %2$lld 个中的 %1$lld 个 | machine | Customise Tile: Apps card Shown value, e.g. 9 of 12; %1$lld = shown, %2$lld = total (positional so a language may reorder them) |
| `label.appsBackground` | Dock Icon Background | 程序坞图标背景 | machine | App Grid inspector section for per-tile plate settings |
| `label.appsBackground.automatic` | Follow System | 跟随系统 | reviewed | App Grid background follows the macOS icon appearance |
| `label.appsBackground.charcoal` | Dark Grey | 深灰色 | reviewed | Fixed dark background for an App Grid icon |
| `label.appsBackground.custom` | Custom Colour | 自定义颜色 | reviewed | Native colour picker for an App Grid icon background |
| `label.appsBackground.hint` | Applies to this tile only. | 仅应用于此磁贴。 | machine | Caption under the App Grid background menu: the choice affects only this tile |
| `label.appsBackground.light` | Light | 浅色 | reviewed | Fixed light background for an App Grid icon |
| `label.appsFace.accessibility` | Apps face: showing %lld of this tile's apps | App视图：显示此磁贴中的 %lld 个App | machine | VoiceOver label for a tile preview showing the Apps face; %lld = number of app icons shown |
| `label.background` | Background | 背景 | machine | Customise Tile: background row label |
| `label.background.colour` | Colour | 颜色 | machine | Customise Tile: Colour background chip |
| `label.background.colour.accessibility` | Colour, filled with your colour | 颜色，以你选择的颜色填充 | machine | VoiceOver label for the Colour chip |
| `label.background.hint.colour` | Filled with your colour | 以你选择的颜色填充 | machine | Customise Tile: hint under Background when Colour |
| `label.background.hint.emojiColours` | Emoji keep their own colours. | 表情符号保留自身颜色。 | machine | Customise Tile: appended to the Background caption for an Emoji tile |
| `label.background.hint.mono` | White in Light Mode, black in Dark Mode | 浅色模式下为白色，深色模式下为黑色 | machine | Customise Tile: hint under Background when Mono |
| `label.background.hint.mono.static` | White tile with a coloured symbol | 白色磁贴配彩色符号 | machine | Customise Tile: hint under Background when Mono on macOS 15 (static white tile) |
| `label.background.mono` | Mono | 单色 | machine | Customise Tile: Mono background chip |
| `label.background.mono.accessibility` | Mono, white in Light Mode and black in Dark Mode | 单色，浅色模式下为白色，深色模式下为黑色 | machine | VoiceOver label for the Mono chip |
| `label.background.mono.static.accessibility` | Mono, a white tile with a coloured symbol | 单色，白色磁贴配彩色符号 | machine | VoiceOver label for the Mono chip on macOS 15 |
| `label.colour` | Colour | 颜色 | machine | Label for colour picker section |
| `label.colour.hint.deepened` | Deepened slightly so the symbol stays clear | 已略微加深，让符号保持清晰 | machine | Customise Tile: colour hint when the fill was darkened for contrast |
| `label.colour.hint.emoji` | Emoji keep their own colours | 表情符号保留自身颜色 | machine | Customise Tile: colour hint, Mono emoji tile (row disabled) |
| `label.colour.hint.fills` | Fills the tile | 填充磁贴 | machine | Customise Tile: colour hint, Colour tile |
| `label.colour.hint.tints` | Tints the symbol | 为符号着色 | machine | Customise Tile: Colour card caption for a Mono tile |
| `label.colour.hint.toned` | Toned for Light and Dark | 已针对浅色和深色调整色调 | machine | Customise Tile: colour hint, Mono tile |
| `label.colour.hint.toned.static` | Toned to stay clear on white | 已调整色调，在白色上保持清晰 | machine | Customise Tile: colour hint, Mono tile on macOS 15 |
| `label.iconSize` | Icon Size | 图标大小 | machine | Compact label for the icon size stepper (side-by-side with icon weight) |
| `label.iconWeight` | Icon Weight | 图标粗细 | machine | Label for the SF Symbol weight picker |
| `label.missingAppsScan` | Missing Apps | 缺失的App | machine | Settings row title for the missing-app scan |
| `label.missingAppsScanDescription` | Check your tiles for apps that have been moved or uninstalled. | 检查你的磁贴中是否有已被移动或卸载的App。 | machine | Settings row description for the missing-app scan |
| `label.notInstalled` | Not installed | 未安装 | machine | Badge/kind text shown for an app whose bundle is no longer on disk |
| `label.popover.animation` | Animation | 动画 | machine | Label for the popover animation segmented control |
| `label.popover.highlightOnHover` | Highlight on Hover | 悬停时高亮显示 | machine | Toggle label — show a background fill on the hovered item |
| `label.popover.layout` | Layout | 布局 | machine | Label for the Grid/List preview toggle in popover settings |
| `label.popover.listAlwaysLabelled` | List view always shows labels | 列表视图始终显示标签 | machine | Hint shown beside the disabled Show Labels control when previewing List |
| `label.popover.showLabels` | Show Labels | 显示标签 | machine | Toggle label — show app names under grid icons |
| `label.popover.size` | Popover Size | 弹出面板大小 | machine | Label for the popover size segmented control |
| `label.popover.spacing` | Spacing | 间距 | machine | Label for the popover item spacing segmented control |
| `label.popover.tileSize` | Tile Size | 项目大小 | machine | Label for the icon/cell size control inside the popover |
| `label.shareAnalytics` | Share anonymous usage data | 共享匿名使用数据 | machine | Label for the analytics opt-out toggle in Settings |
| `label.shareAnalyticsDescription` | Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected. | 发送匿名使用情况和崩溃报告，帮助改进Dock Tile。不会收集任何个人数据。 | machine | Explanation under the analytics toggle |
| `label.addAppsAndFolders` | Add Apps & Folders | 添加App和文件夹 | machine | Tooltip on the Add button in Tile Detail's In This Tile section |
| `label.appSwitcherNeedsShowTile` | Turn on Show Tile first — this only applies while the tile is in the Dock. | 请先打开“显示磁贴”——此设置仅在磁贴位于程序坞中时生效。 | machine | Tooltip on the disabled Show in App Switcher toggle when the tile is hidden |
| `label.showInAppSwitcher` | Show in App Switcher | 在App切换器中显示 | machine | Label for app switcher toggle |
| `label.showTile` | Show Tile | 显示磁贴 | machine | Label for show tile toggle |
| `label.softwareUpdate` | Software Update | 软件更新 | machine | Title of the software-update row in General settings |
| `label.softwareUpdateDescription` | You’re using version %@. Dock Tile checks for updates automatically. | 你正在使用版本%@。Dock Tile会自动检查更新。 | machine | Description under the software-update row; %@ is the current version |
| `label.startAtLogin` | Start tiles at login | 登录时启动磁贴 | machine | Label for the start-at-login toggle in Settings |
| `label.startAtLoginDescription` | Keep your tiles ready in the Dock so they respond instantly after you restart your Mac. | 让程序坞中的磁贴随时待命，重新启动Mac后也能立即响应。 | machine | Explanation under the start-at-login toggle |
| `label.style.appPreview` | App Grid | App网格 | machine | Customise Tile: Style picker card for the Apps face |
| `label.symbolColour` | Symbol Colour | 符号颜色 | machine | Customise Tile: colour row label for a Mono tile |
| `label.tileColour` | Tile Colour | 磁贴颜色 | machine | Customise Tile: Colour card header for a Colour tile |
| `label.tileIcon` | Tile Icon | 磁贴图标 | machine | Label for tile icon section |
| `label.tileIconSize` | Tile Icon Size | 磁贴图标大小 | machine | Label for tile icon size |
| `label.tileName` | Tile Name | 磁贴名称 | machine | Label for tile name field |
| `layout.grid` | Grid | 网格 | machine | Grid layout option |
| `layout.list` | List | 列表 | machine | List layout option |
| `itemMenu.forceQuit` | Force Quit | 强制退出 | machine | Popover item context menu: force quit (shown while Option is held) |
| `itemMenu.getInfo` | Get Info | 显示简介 | machine | Popover item context menu: open Finder's Get Info window |
| `itemMenu.hide` | Hide | 隐藏 | machine | Popover item context menu: hide the running app |
| `itemMenu.open` | Open | 打开 | machine | Popover item context menu: open the app or folder |
| `itemMenu.quickLook` | Quick Look | 快速查看 | machine | Popover item context menu: preview the item with Quick Look |
| `itemMenu.quit` | Quit | 退出 | machine | Popover item context menu: quit the running app |
| `itemMenu.share` | Share… | 共享… | machine | Popover item context menu: open the share sheet for a folder |
| `itemMenu.showInFinder` | Show in Finder | 在访达中显示 | machine | Popover item context menu: reveal the item in Finder |
| `menu.configure` | Configure... | 配置… | machine | Menu item to configure tile (opens main app) |
| `menu.configureTile` | Configure Tile | 配置磁贴 | machine | Tooltip for gear icon in popover |
| `menu.configureTileItem` | Configure Tile… | 配置磁贴… | machine | Tile submenu item in the menu bar and Dock menus: opens that tile in Dock Tile's window |
| `menu.copyDiagnostics` | Copy Diagnostics | 拷贝诊断信息 | machine | File menu item that copies recent diagnostic logs to the clipboard |
| `menu.hideInspector` | Hide Inspector | 隐藏检查器 | machine | View menu item (Hide Inspector, ⌥⌘I) that closes the Customise Tile inspector |
| `menu.newTile` | New Tile | 新建磁贴 | machine | Menu item to create a new tile |
| `menu.noAppsConfigured` | No apps configured | 未配置App | machine | Dock menu: disabled row when the tile has no apps |
| `menu.noConfiguration` | No configuration | 无配置 | machine | Dock menu: disabled row when the tile's config cannot be found |
| `menu.openDockTile` | Open Dock Tile… | 打开Dock Tile… | machine | Menu bar and Dock menu item that opens Dock Tile's main window |
| `menu.openInFinder` | Open in Finder | 在访达中打开 | machine | Menu item to open in Finder |
| `menu.options` | Options | 选项 | machine | Section divider in menu |
| `menu.quitDockTile` | Quit Dock Tile | 退出Dock Tile | machine | Menu bar icon's menu: quits Dock Tile (tiles already in the Dock keep working) |
| `menu.settings` | Settings… | 设置… | machine | App menu item that opens the inline Settings pane (⌘,) |
| `menu.showInspector` | Show Inspector | 显示检查器 | machine | View menu item (Show Inspector, ⌥⌘I) that opens the Customise Tile inspector |
| `popover.option.animation.default` | Default | 默认 | machine | Animation tier — default |
| `popover.option.animation.fast` | Fast | 快速 | machine | Animation tier — fast |
| `popover.option.animation.none` | None | 无 | machine | Animation tier — none |
| `popover.option.comfortable` | Comfortable | 适中 | machine | Spacing tier — comfortable |
| `popover.option.compact` | Compact | 紧凑 | machine | Spacing tier — compact |
| `popover.option.large` | Large | 大 | machine | Size tier — large |
| `popover.option.medium` | Medium | 中 | machine | Size tier — medium |
| `popover.option.small` | Small | 小 | machine | Size tier — small |
| `popover.option.spacious` | Spacious | 宽松 | machine | Spacing tier — spacious |
| `search.emojis` | Search emojis | 搜索表情符号 | machine | Search placeholder for emojis |
| `search.symbols` | Search symbols | 搜索符号 | machine | Search placeholder for symbols |
| `settings.dockLock` | Dock Lock | 程序坞锁定 | machine | Section header for the Dock Lock feature in Settings |
| `settings.dockLock.accessibilityGranted` | Accessibility access granted | 已授予无障碍访问权限 | machine | Status shown when Accessibility permission is granted |
| `settings.dockLock.accessibilityNeeded` | Accessibility access required | 需要无障碍访问权限 | machine | Status shown when Accessibility permission is missing |
| `settings.dockLock.accessibilityNeededDetail` | Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings. | Dock Tile需要无障碍访问权限才能固定程序坞的位置。请在“系统设置”中打开Dock Tile。 | machine | Explanation of why Accessibility access is needed |
| `settings.dockLock.anchor` | Keep Dock on | 将程序坞固定在 | machine | Label for the anchor display picker |
| `settings.dockLock.defaultDisplay` | Default (follow macOS) | 默认（跟随macOS） | machine | First option in the anchor picker — no lock, macOS default behaviour |
| `settings.dockLock.description` | Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose. | 防止程序坞在多显示器环境下于屏幕之间跳动。它会停留在你选择的显示器上。 | machine | Explanation under the Dock Lock toggle |
| `settings.dockLock.lockedTo` | Dock is locked to %@ | 程序坞已锁定到%@ | machine | Indicator confirming the display the Dock is pinned to |
| `settings.dockLock.mainDisplay` | Main | 主显示器 | machine | Suffix marking the main display in the anchor picker |
| `settings.dockLock.moveFailed` | Couldn't move the Dock to %@. Make sure that display isn't mirrored, then try again. | 无法将程序坞移到%@。请确认该显示器未设为镜像，然后重试。 | machine | Error shown when the Dock could not be relocated |
| `settings.dockLock.moving` | Moving Dock to %@… | 正在将程序坞移到%@… | machine | Progress message shown while the Dock is being relocated |
| `settings.dockLock.note` | Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays. | 适用于位于底部、左侧或右侧的程序坞。将程序坞保持在一个屏幕上时，其他显示器的对应边缘会预留几个像素。 | machine | Footnote describing Dock Lock behaviour and trade-off |
| `settings.dockLock.openSettings` | Open System Settings… | 打开系统设置… | machine | Button that opens the Accessibility pane in System Settings |
| `settings.dockLock.primer.body` | Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens. | “程序坞锁定”会让程序坞停留在你选择的显示器上。为此，Dock Tile需要无障碍访问权限，以阻止macOS将程序坞移到其他屏幕。 | machine | Explanation in the permission primer |
| `settings.dockLock.primer.continue` | Continue | 继续 | machine | Primary button in the permission primer that triggers the macOS dialog |
| `settings.dockLock.primer.notNow` | Not Now | 以后 | machine | Secondary button in the permission primer that cancels enabling Dock Lock |
| `settings.dockLock.primer.reassurance` | Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time. | 接下来，macOS会请你在“系统设置”中打开Dock Tile。你可以随时关闭此功能。 | machine | Reassurance line in the permission primer about what happens next |
| `settings.dockLock.primer.title` | Allow Accessibility Access | 允许无障碍访问 | machine | Title of the permission primer shown before requesting Accessibility |
| `settings.dockLock.retry` | Try Again | 重试 | machine | Button to retry a failed Dock relocation |
| `settings.dockLock.singleDisplay` | Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it. | 连接第二台显示器即可使用“程序坞锁定”。只有一个屏幕时，程序坞会停留在macOS放置的位置。 | machine | Note shown when only one display is connected |
| `settings.dockLock.toggle` | Lock Dock to one display | 将程序坞锁定到一台显示器 | machine | Label for the Dock Lock enable toggle |
| `settings.general` | General | 通用 | machine | Title of the General settings pane |
| `settings.login.registrationFailed` | Couldn’t turn this on — macOS refused the registration. %@ | 无法打开此功能——macOS拒绝了注册。%@ | machine | Shown under the Start tiles at login toggle when SMAppService registration failed; %@ is the system error |
| `settings.login.requiresApproval` | Approve Dock Tile in Login Items to finish enabling this. | 在“登录项”中批准Dock Tile以完成启用。 | machine | Shown when macOS is holding the login item for user approval |
| `settings.menuBar` | Menu Bar | 菜单栏 | machine | General: section holding the menu bar icon toggle |
| `settings.menuBar.toggle` | Show Dock Tile in the menu bar | 在菜单栏中显示Dock Tile | machine | General: toggle that adds Dock Tile's icon to the menu bar, listing the tiles and their apps |
| `settings.menuBar.toggleDescription` | Lists the tiles in your Dock and their apps. Dock Tile keeps running in the background while this is on. | 列出程序坞中的磁贴及其应用。开启后，Dock Tile会在后台持续运行。 | machine | General: caption under the menu bar icon toggle |
| `settings.popover` | Popover | 弹出面板 | machine | Section header and pane title for popover appearance settings |
| `settings.popover.configure` | Configure | 配置 | machine | Label for the Grid/List panel switcher in popover settings |
| `settings.popover.configure.subtitle` | Each layout's settings are saved independently | 每种布局的设置分别存储 | machine | Subtitle explaining that Grid and List popover settings are stored separately |
| `settings.popover.footer` | These settings apply to every tile's popover. List view always shows labels. Animation follows your system Reduce Motion setting. | 这些设置适用于每个磁贴的弹出面板。列表视图始终显示标签。动画遵循系统的“减弱动态效果”设置。 | machine | Explanatory footer under the popover settings form |
| `settings.popover.reduceMotion` | Animation is off because Reduce Motion is on in System Settings. | 由于“系统设置”中已打开“减弱动态效果”，动画已关闭。 | machine | Caption shown under Animation when the system Reduce Motion setting forces it off |
| `settings.popover.section.tiles` | Tiles | 项目 | machine | Section header for the per-item controls inside the popover settings |
| `sidebar.section.settings` | Settings | 设置 | machine | Sidebar section header for the inline app settings panes |
| `sidebar.section.tiles` | Tiles | 磁贴 | machine | Sidebar section header for the list of dock tiles |
| `sidebar.title` | Dock Tile | Dock Tile | machine | Navigation title for sidebar |
| `smartAdd.identity.browse` | Browse | 浏览 | machine | Smart Add: suggested tile name for browsers |
| `smartAdd.identity.chat` | Chat | 聊天 | machine | Smart Add: suggested tile name for social apps |
| `smartAdd.identity.ship` | Ship | 开发 | machine | Smart Add: suggested tile name for developer tools |
| `smartAdd.identity.together` | Together | 组合 | machine | Smart Add: suggested tile name for apps opened together |
| `smartAdd.identity.watch` | Watch | 观看 | machine | Smart Add: suggested tile name for video apps |
| `smartAdd.identity.work` | Work | 工作 | machine | Smart Add: suggested tile name for productivity apps |
| `smartAdd.privacyFootnote` | Learned on your Mac. Never leaves your device. | 在你的Mac上学习得出，数据绝不离开你的设备。 | machine | Footer note stating Smart Add suggestions are computed on-device only |
| `smartAdd.provenanceBanner` | Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to your Dock. | 由“智能添加”根据你最近使用的App创建。你可以重命名、更改样式或编辑其中的App，然后将它添加到程序坞。 | machine | Banner shown atop Tile Detail when a tile was just created by Smart Add |
| `smartAdd.reason.byCategory` | By category | 按类别 | machine | Reason chip — apps grouped by their app category |
| `smartAdd.reason.mostUsed` | Most used this week | 本周最常用 | machine | Reason chip — the most-used cluster this week |
| `smartAdd.reason.openedTogether` | Opened together | 经常一起打开 | machine | Reason chip — apps repeatedly opened in the same session |
| `smartAdd.settings.sectionHeader` | Smart Add | 智能添加 | machine | General settings section header for the Smart Add toggle |
| `smartAdd.settings.toggleDescription` | Learned on your Mac. Never leaves your device. | 在你的Mac上学习得出，数据绝不离开你的设备。 | machine | General: Smart Add toggle description |
| `smartAdd.settings.toggleTitle` | Suggest tiles from my apps | 根据我的App推荐磁贴 | machine | General: Smart Add toggle title |
| `smartAdd.title` | Add a Tile | 添加磁贴 | machine | Header title of the Smart Add suggestion sheet |
| `subtitle.chooseColour` | Choose a background colour for your tile | 为磁贴选择背景颜色 | machine | Subtitle for colour picker section |
| `subtitle.configureToAdd` | Configure to add apps | 配置以添加App | machine | Subtitle in empty state (grid view only) |
| `subtitle.iconSize` | Adjust the size of your icon within the tile | 调整图标在磁贴中的大小 | machine | Subtitle for icon size section |
| `symbolCategory.accessibility` | Accessibility | 无障碍 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.all` | All | 全部 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.arrows` | Arrows | 箭头 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.automotive` | Automotive | 汽车 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.cameraandphotos` | Camera & Photos | 相机与照片 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.commerce` | Commerce | 商业 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.communication` | Communication | 通信 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.connectivity` | Connectivity | 连接状态 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.devices` | Devices | 设备 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.draw` | Draw | 绘制 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.editing` | Editing | 编辑 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.fitness` | Fitness | 健身 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.gaming` | Gaming | 游戏 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.health` | Health | 健康 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.home` | Home | 家庭 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.human` | Human | 人 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.indices` | Indices | 索引 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.keyboard` | Keyboard | 键盘 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.maps` | Maps | 地图 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.math` | Maths | 数学 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.media` | Media | 媒体 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.multicolor` | Multicolour | 多色 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.nature` | Nature | 自然 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.objectsandtools` | Objects & Tools | 物体与工具 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.privacyandsecurity` | Privacy & Security | 隐私与安全性 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.shapes` | Shapes | 形状 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.textformatting` | Text Formatting | 文本格式化 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.time` | Time | 时间 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.transportation` | Transportation | 交通 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.variable` | Variable | 可变 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.weather` | Weather | 天气 | machine | Symbol picker: section header (SF Symbols category) |
| `symbolCategory.whatsnew` | What's New | 新符号 | machine | Symbol picker: section header (SF Symbols category) |
| `tab.emoji` | Emoji | 表情符号 | machine | Emoji tab label |
| `tab.symbol` | Symbol | 符号 | machine | Symbol tab label |
| `title.customiseTile` | Customise Tile | 自定义磁贴 | machine | Title of the Customise Tile inspector beside Tile Detail |
| `title.deleteTile` | Delete Tile | 删除磁贴 | machine | Alert title for delete confirmation |
| `tooltip.createNewTile` | Create new tile | 新建磁贴 | machine | Tooltip when add button is enabled |
| `tooltip.editFirst` | Edit current tile before creating another | 请先编辑当前磁贴，再创建新的磁贴 | machine | Tooltip when add button is disabled |
| `button.addATile` | Add a Tile… | 添加磁贴… | machine | Sidebar + / empty state: opens the Add a Tile dialog |
| `sidebar.dockTileSection` | Dock Tile | Dock Tile | machine | Sidebar section holding About |
| `settings.addingTiles` | Adding Tiles | 添加磁贴 | machine | General: section holding the Smart Add toggle and the Add a Tile row |
| `about.title` | About | 关于 | machine | About pane title |
| `about.version` | Version %@ | 版本%@ | machine | About: version line |
| `about.website` | Website | 网站 | machine | About: website row label |
| `about.feedbackTitle` | Found a bug or have an idea? | 发现错误或有新想法？ | machine | About: feedback card title |
| `about.feedbackBody` | Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal. | 反馈会直接发送给开发者。诊断信息会附上App及其磁贴的操作日志，不含任何个人信息。 | machine | About: feedback card body |
| `about.sendFeedback` | Send Feedback… | 发送反馈… | machine | About: opens the feedback email |
| `about.alsoFrom` | Also from Happy Machines | Happy Machines的其他作品 | machine | About: studio section header |
| `about.studioTitle` | Made by Happy Machines Company | 由Happy Machines Company打造 | machine | About: studio row title |
| `about.studioSubtitle` | A tiny product studio building nifty Mac apps that each fix one thing well. | 一家小型产品工作室，专做精巧的Mac App，每款只把一件事做好。 | machine | About: studio row subtitle |
| `about.spadesTitle` | Spades Audio | Spades Audio | machine | About: sibling product row title |
| `about.spadesSubtitle` | Per-app volume, EQ and output control for your Mac, from the menu bar. | 在菜单栏中为你的Mac提供按App调节的音量、均衡器和输出控制。 | machine | About: sibling product subtitle |
| `about.learnMore` | Learn More… | 进一步了解… | machine | About: opens spadesaudio.com |
| `menu.aboutDockTile` | About Dock Tile | 关于Dock Tile | machine | App menu |
| `popover.editing.remove` | Remove | 移除 | machine | Context menu / remove badge in the tile editor |
| `section.inThisTile` | In This Tile | 此磁贴中的项目 | machine | Tile Detail: apps section header |
| `label.editorHint` | Hover to remove · Drag to reorder | 悬停可移除 · 拖移可重新排序 | machine | Tile Detail: apps section caption |
| `tooltip.deleteTile` | Delete Tile | 删除磁贴 | machine | Tile Detail: trash button tooltip |
| `smartAdd.blankTitle` | Create a blank tile | 创建空白磁贴 | machine | Add a Tile: blank row title |
| `smartAdd.blankSubtitle` | Name it, pick an icon and add apps yourself. | 自行命名、选择图标并添加App。 | machine | Add a Tile: blank row subtitle |
| `smartAdd.orStartFrom` | or start from what you use | 或从你常用的App开始 | machine | Add a Tile: rule between blank row and suggestions |
| `smartAdd.noSuggestions` | No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General. | 暂无建议——Dock Tile会从你打开的App中学习。你可以在“通用”中关闭此功能。 | machine | Add a Tile: empty suggestions note |
| `label.addAppsTooltip` | Add apps or folders to this tile | 向此磁贴添加App或文件夹 | machine | Tooltip on the + Add button above the tile editor's popover preview. |
| `empty.createFirstTileDescription` | Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use. | 将App和文件夹归入一个程序坞图标。可以从空白开始，也可以从根据你常用App推荐的磁贴开始。 | machine | Zero-tiles description |
| `popover.editing.noAppsTitle` | No apps yet | 还没有App | machine | Tile editor: empty popover preview, title line. |
| `popover.editing.noAppsSubtitle` | Use Add to choose what opens from this tile. | 使用“添加”选择要从此磁贴打开的项目。 | machine | Tile editor: empty popover preview, subtitle line. |
| `about.diagnosticsBody` | A log of what the app and its tiles did. Attach it to an email when something looks wrong — it contains nothing personal. | 记录App及其磁贴所执行操作的日志。出现异常时，可将其附加到电子邮件中——其中不含任何个人信息。 | machine | About: Copy Diagnostics row description. |
| `about.feedbackRowBody` | Feedback goes straight to the developer. | 反馈会直接发送给开发者。 | machine | About: Send Feedback row description. |
| `about.diagnosticsTitle` | Diagnostics | 诊断信息 | machine | About: Copy Diagnostics row label. |
| `button.copy` | Copy | 拷贝 | machine | Generic Copy button label. |
| `tooltip.openSettings` | Settings | 设置 | machine | Tooltip for the settings toolbar button |
| `tooltip.toggleCustomiseTile` | Toggle Customise Tile | 显示/隐藏“自定义磁贴” | machine | Tooltip and accessibility label of the toolbar button that opens or closes the Customise Tile inspector |
| `tooltip.toggleCustomiser` | Toggle Customiser | 显示/隐藏自定义面板 | machine | Tooltip and accessibility label of the Tile Detail icon, which opens or closes the Customise Tile inspector when clicked |
| `translation.helpImprove` | Help Improve… | 帮助改进… | machine | Button: opens the language's review sheet on GitHub |
| `translation.invite.message` | This translation was made by a machine and has not yet been checked by a native speaker. If something reads wrong, you can fix it on GitHub — no coding needed. | 此翻译由机器生成，尚未经过母语人士校对。如果有读起来不对的地方，你可以在GitHub上修改——无需编程。 | machine | One-time alert message inviting translation review |
| `translation.invite.title` | Dock Tile now speaks your language | Dock Tile现已支持你的语言 | machine | One-time alert title on first launch in a machine-translated language |
| `translation.reviewLine` | Machine translated. Not yet checked by a native speaker. | 机器翻译，尚未经过母语人士校对。 | machine | About: translation row description. Reviewers replace this in their language with who reviewed it, e.g. 'Reviewed by @handle'. |
| `translation.title` | Translation | 翻译 | machine | About: translation row label (shown only when the UI runs in a non-English language) |
