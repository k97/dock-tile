# Dock Tile website — 简体中文 (zh-Hans)

The Chinese test of the homepage, the FAQ and the Dock Lock page (`/zh-Hans`, `/zh-Hans/faq`,
`/zh-Hans/dock-lock`; plans: docs/superpowers/plans/2026-11-23-website-zh-hans-test.md and
2026-11-23-website-dock-lock-page.md). Machine-first, like the app's
zh-Hans: every row is `needs_review` until a native speaker checks it.

- **Source of truth is `website/lib/i18n.ts`** (the `zh-Hans` entry, `namesZh`, `zhPageMeta`).
  This sheet records the English each Chinese string was translated from, so an English edit
  can't leave stale Chinese unnoticed: `npm run check:zh` (in `website/`) fails when the
  English, the Chinese or the key set here and in `lib/i18n.ts` disagree.
- **Reviewing:** edit the 简体中文 column, set Status to `translated` (the app catalog's word for reviewed), then copy the same text into
  `lib/i18n.ts` (the check fails until both match). After an English change, re-translate the
  row and update its English here.
- Terms: docs/l10n/GLOSSARY.md (磁贴, 程序坞, 弹出面板, 访达, App切换器, 你); the mock macOS UI
  reuses the app's own strings (Localizable.xcstrings). Style follows the app: full-width
  punctuation, no space between Chinese and Latin words, "Dock Tile" never translated.
- `names.*`: names shown in the mocks (tooltips, alt text, menu rows). Third-party brands stay as
  they are. **Apple TV is left in English** (not sure what a Chinese macOS 26 calls it; earlier
  versions said 视频). Screenshot = 截屏, Messages = 信息, System Settings = 系统设置 as on a
  Chinese Mac.
- The `/privacy`, `/terms` and `/release-notes` pages stay English.

| Key | English | 简体中文 | Status | Note |
|---|---|---|---|---|
| `marketing.heroHeadlineA` | Group your apps. | 将App分组。 | needs_review |  |
| `marketing.heroHeadlineB` | Declutter your Dock. | 让程序坞井井有条。 | needs_review |  |
| `marketing.heroSub` | Put a group of apps behind one Dock icon. Click it and they pop up, like a folder on your iPhone. | 将一组App放进一个程序坞图标。点一下，它们就会弹出来，就像iPhone上的文件夹。 | needs_review |  |
| `marketing.tryIt` | Try it — click a tile | 试试看——点一个磁贴 | needs_review |  |
| `marketing.tilesTitleA` | Pick your apps. Pick a look. | 挑选App，选个外观。 | needs_review |  |
| `marketing.tilesTitleB` | Done. | 完成。 | needs_review |  |
| `marketing.tilesBody` | Set up every tile in the Dock Tile companion app. You arrange its apps in the same panel that pops up from the Dock, so what you see is what you get. Then pick its icon: a grid of its own apps, a symbol or an emoji, on colour or a plain background. | 每个磁贴都在Dock Tile配套App中设置。你在程序坞弹出的同一个面板里排列它的App，所见即所得。然后为它选择图标：由它自己的App组成的网格、一个符号或一个表情符号，配上彩色或纯色背景。 | needs_review |  |
| `marketing.tilesAlt` | Dock Tile editing a tile: its popover in the middle, Customise Tile on the right. | Dock Tile正在编辑一个磁贴：中间是它的弹出面板，右侧是“自定义磁贴”。 | needs_review |  |
| `marketing.tilesSpotPopover` | In This Tile | 此磁贴中的项目 | needs_review | App string section.inThisTile |
| `marketing.tilesSpotPopoverBody` | Drag apps into order, or hover to remove one. It's the same popover your tile opens. | 拖动App调整顺序，或将指针悬停在App上将其移除。这就是你的磁贴打开的那个弹出面板。 | needs_review |  |
| `marketing.tilesSpotStyle` | Style | 样式 | needs_review |  |
| `marketing.tilesSpotStyleBody` | App Grid shows the tile's own apps. Or pick a symbol or an emoji. | “App网格”显示磁贴自己的App。也可以选择一个符号或表情符号。 | needs_review |  |
| `marketing.tilesSpotBackground` | Background | 背景 | needs_review |  |
| `marketing.tilesSpotBackgroundBody` | Colour fills the tile. Mono keeps it white in Light Mode and black in Dark Mode. | “颜色”会填满整个磁贴。“单色”在浅色模式下为白色，在深色模式下为黑色。 | needs_review |  |
| `marketing.tilesSpotTile` | Your tile | 你的磁贴 | needs_review |  |
| `marketing.tilesSpotTileBody` | Every change shows on the tile as you make it. | 你做的每处更改都会立即显示在磁贴上。 | needs_review |  |
| `marketing.tilesSpotPrevious` | Previous | 上一个 | needs_review |  |
| `marketing.tilesSpotNext` | Next | 下一个 | needs_review |  |
| `marketing.tilesSpotClose` | Close | 关闭 | needs_review |  |
| `marketing.tilesSpotLabelEnd` | . | ： | needs_review | Punctuation after the hotspot card's bold label |
| `marketing.introTitleA` | Less Dock. | 程序坞更清爽。 | needs_review |  |
| `marketing.introTitleB` | More multitasking. | 多任务更从容。 | needs_review |  |
| `marketing.introBefore` | Before | 之前 | needs_review |  |
| `marketing.introAfter` | With Dock Tile | 使用Dock Tile后 | needs_review |  |
| `marketing.introPoints.0.lead` | One tile, many apps | 一个磁贴，多个App | needs_review |  |
| `marketing.introPoints.0.body` | Group apps and folders behind a single Dock icon. Click it and they pop up, ready to open. | 将App和文件夹放在同一个程序坞图标后面。点一下，它们就会弹出，随时可以打开。 | needs_review |  |
| `marketing.introPoints.1.lead` | Looks like it belongs | 就像原生的一样 | needs_review |  |
| `marketing.introPoints.1.body` | Each tile is a real Mac app with its own icon, so it sits and magnifies like everything else in your Dock. | 每个磁贴都是一个真正的Mac App，有自己的图标，所以它在程序坞中的样子和放大效果都与其他图标一致。 | needs_review |  |
| `marketing.introPoints.2.lead` | Ready in a minute | 一分钟就能设置好 | needs_review |  |
| `marketing.introPoints.2.body` | Pick a suggested tile or start blank, add your apps, then put it in your Dock. | 选择一个推荐的磁贴或从空白开始，添加你的App，然后把它放进程序坞。 | needs_review |  |
| `marketing.cardsTitleA` | Set up for you. | 为你设置好。 | needs_review |  |
| `marketing.cardsTitleB` | Out of your way. | 绝不碍事。 | needs_review |  |
| `marketing.smartAddTitle` | Ready-made tiles from the apps you use. | 用你常用的App生成现成的磁贴。 | needs_review |  |
| `marketing.smartAddBody` | Click +, and Dock Tile groups the apps you use most into ready-made tiles. Pick one and it opens ready to tweak; nothing reaches your Dock until you add it. | 点按+，Dock Tile会把你最常用的App分组成现成的磁贴。选一个，它会打开供你调整；在你添加之前，任何东西都不会进入程序坞。 | needs_review |  |
| `marketing.smartAddPrivacy` | Learned on your Mac. Never leaves your device. | 在你的Mac上学习得出，数据绝不离开你的设备。 | needs_review | App string smartAdd.privacyFootnote |
| `marketing.ghostTitle` | Ghost mode. | Ghost mode（幽灵模式）。 | needs_review | Glossary: Ghost mode stays in Latin letters, the Chinese in brackets on first use |
| `marketing.ghostBody` | Tiles stay out of the app switcher (Command-Tab) by default, so it lists only the apps you're actually using. | 默认情况下，磁贴不会出现在App切换器（Command-Tab）中，因此那里只列出你真正在使用的App。 | needs_review |  |
| `marketing.ghostTip` | Want one in Command-Tab? Switch it on for that tile. | 想让某个磁贴出现在Command-Tab中？为该磁贴打开此选项即可。 | needs_review |  |
| `marketing.dockLockTitleA` | The Dock | 程序坞 | needs_review | Split around the heading's tilted tile: A 🔒 B |
| `marketing.dockLockTitleB` | stays put. | 不再乱跑。 | needs_review |  |
| `marketing.dockLockLead` | Dock Lock comes with Dock Tile. | Dock Tile附带“程序坞锁定”。 | needs_review |  |
| `marketing.dockLockBody` | Pick a screen for the Dock and it stays there, however many displays you use. | 为程序坞选一台显示器，无论你连接几台显示器，它都会留在那里。 | needs_review |  |
| `marketing.menuBarTitle` | Your tiles, in the menu bar. | 你的磁贴，就在菜单栏中。 | needs_review |  |
| `marketing.menuBarLead` | On from the first launch. | 首次启动即开启。 | needs_review |  |
| `marketing.menuBarIntro` | A menu bar shortcut comes with Dock Tile. | Dock Tile附带菜单栏快捷方式。 | needs_review |  |
| `marketing.menuBarBody` | The tiles in your Dock and their apps, listed in the menu bar, ready even when the Dock is hidden. Turn it off in Settings any time. | 程序坞中的磁贴及其App会列在菜单栏中，即使程序坞隐藏也能随时使用。你可以随时在“设置”中关闭它。 | needs_review |  |
| `marketing.details.0.lead` | Keyboard friendly | 支持键盘操作 | needs_review |  |
| `marketing.details.0.body` | Arrow keys move through a tile's apps. Return opens, Esc closes. | 用方向键在磁贴的App之间移动。按Return打开，按Esc关闭。 | needs_review |  |
| `marketing.details.1.lead` | Folders too | 也支持文件夹 | needs_review |  |
| `marketing.details.1.body` | Add a folder beside your apps and open it in one click. | 在App旁边添加文件夹，点一下即可打开。 | needs_review |  |
| `marketing.details.2.lead` | Free and open source | 免费且开源 | needs_review |  |
| `marketing.details.2.body` | No price and no account. MIT‑licensed, with the code on GitHub. | 无需付费，无需账户。采用MIT许可证，代码在GitHub上。 | needs_review |  |
| `marketing.details.3.lead` | In your language | 支持你的语言 | needs_review |  |
| `marketing.details.3.body` | English, 简体中文, 日本語, Deutsch, Русский and Français. | English、简体中文、日本語、Deutsch、Русский和Français。 | needs_review |  |
| `marketing.featureRequest` | Request a feature | 建议新功能 | needs_review |  |
| `marketing.featureRequestBody` | Tell us what Dock Tile should do next. | 告诉我们Dock Tile接下来应该做什么。 | needs_review |  |
| `marketing.bugReport` | Report a bug | 报告错误 | needs_review |  |
| `marketing.bugReportBody` | Something not working? Tell us what happened and on which macOS. | 有东西不正常？告诉我们发生了什么，以及你使用的是哪个版本的macOS。 | needs_review |  |
| `marketing.feedbackTitle` | Help shape Dock Tile | 帮助完善Dock Tile | needs_review |  |
| `marketing.feedbackNote` | Both open a GitHub issue. No GitHub account? Use Contact support below. | 两者都会在GitHub上新建一个议题（英文）。没有GitHub账户？请使用下方的“联系支持”。 | needs_review |  |
| `marketing.ctaButton` | Download Dock Tile | 下载Dock Tile | needs_review |  |
| `marketing.ctaMetaOpenSource` | Free & open source | 免费且开源 | needs_review |  |
| `marketing.ctaMetaAppleSilicon` | Apple silicon | Apple芯片 | needs_review |  |
| `marketing.ctaMetaMacOS` | macOS 15+ | macOS 15+ | needs_review | the macOS floor; keep the number in step with the app |
| `marketing.copyLinkButton` | Copy link for your Mac | 为你的Mac拷贝链接 | needs_review |  |
| `marketing.copyLinkShort` | Copy link | 拷贝链接 | needs_review |  |
| `marketing.copyLinkDone` | Link copied | 链接已拷贝 | needs_review |  |
| `marketing.homeFaqTitleA` | Questions, | 常见问题， | needs_review | Split around the heading's tilted tile: A ❓ B; also the /faq header |
| `marketing.homeFaqTitleB` | answered. | 一一解答。 | needs_review |  |
| `marketing.homeFaqMore` | See all questions | 查看所有问题 | needs_review |  |
| `marketing.downloadTitleA` | Tidy your | 今天就整理 | needs_review | Split around the heading's tilted tile: A ▦ B |
| `marketing.downloadTitleB` | Dock today. | 你的程序坞。 | needs_review |  |
| `marketing.footerFeatures` | Features | 功能 | needs_review |  |
| `marketing.footerWhatsNew` | What's new | 更新内容 | needs_review |  |
| `marketing.footerFaq` | FAQ | 常见问题 | needs_review | Also the /faq header's eyebrow and the nav pill |
| `marketing.footerDownload` | Download | 下载 | needs_review |  |
| `marketing.footerResources` | Resources | 资源 | needs_review |  |
| `marketing.footerGithub` | GitHub | GitHub | needs_review |  |
| `marketing.footerContact` | Contact | 联系我们 | needs_review |  |
| `marketing.footerCompany` | Company | 公司 | needs_review |  |
| `marketing.footerAbout` | About | 关于 | needs_review |  |
| `marketing.footerStudioTagline` | Products for the everyday. | 为日常而做的产品。 | needs_review |  |
| `marketing.footerMadeWithA` | Made with | 用 | needs_review |  |
| `marketing.footerMadeWithB` | for macOS | 为macOS打造 | needs_review |  |
| `marketing.footerLove` | love | 爱 | needs_review |  |
| `marketing.opensInNewTab` | (opens in a new tab) | （在新标签页中打开） | needs_review |  |
| `marketing.languageLink` | 简体中文 | English | needs_review | The footer link to the other language, named in its own language |
| `marketing.faqCtaTitle` | Still stuck? | 还有问题？ | needs_review |  |
| `marketing.faqCtaSubtitle` | Send a note and you'll usually hear back within a day. | 给我们发封邮件，通常一天内就会收到回复。 | needs_review |  |
| `marketing.contactSupport` | Contact support | 联系支持 | needs_review |  |
| `marketing.downloading` | Downloading… | 正在下载… | needs_review |  |
| `marketing.downloaded` | Downloaded | 已下载 | needs_review |  |
| `marketing.themeLight` | Light | 浅色 | needs_review |  |
| `marketing.themeSystem` | System | 跟随系统 | needs_review |  |
| `marketing.themeDark` | Dark | 深色 | needs_review |  |
| `marketing.mockOpenDockTile` | Open Dock Tile… | 打开Dock Tile… | needs_review | App string menu.openDockTile |
| `marketing.mockQuitDockTile` | Quit Dock Tile | 退出Dock Tile | needs_review | App string menu.quitDockTile |
| `marketing.mockConfigureTileItem` | Configure Tile… | 配置磁贴… | needs_review | App string menu.configureTileItem |
| `marketing.mockConfigureTile` | Configure Tile | 配置磁贴 | needs_review | App string menu.configureTile |
| `marketing.mockConfigure` | Configure… | 配置… | needs_review | App string menu.configure |
| `marketing.mockPopoverLabel` | {tile} apps | {tile}中的App | needs_review | {tile} = the tile's name; keep the placeholder |
| `marketing.mockClock` | Mon 9:41 | 周一 9:41 | needs_review | The mock menu bar's clock |
| `marketing.mockAddTile` | Add a Tile | 添加磁贴 | needs_review | App string smartAdd.title |
| `marketing.mockBlankTitle` | Create a blank tile | 创建空白磁贴 | needs_review | App string smartAdd.blankTitle |
| `marketing.mockBlankBody` | Name it, pick an icon and add apps yourself. | 自行命名、选择图标并添加App。 | needs_review | App string smartAdd.blankSubtitle |
| `marketing.mockStartFrom` | or start from what you use | 或从你常用的App开始 | needs_review | App string smartAdd.orStartFrom |
| `marketing.mockMostUsed` | Most used this week | 本周最常用 | needs_review | App string smartAdd.reason.mostUsed |
| `marketing.mockFiveApps` | 5 apps | 5个App | needs_review |  |
| `marketing.mockThreeApps` | 3 apps | 3个App | needs_review |  |
| `marketing.dockLockPageLink` | How Dock Lock works | 了解“程序坞锁定”如何工作 | needs_review | The homepage Dock Lock band's link to /zh-Hans/dock-lock |
| `marketing.footerDockLock` | Dock Lock | 程序坞锁定 | needs_review | Footer link; 程序坞锁定 = the app's settings.dockLock |
| `marketing.dockLockPageEyebrow` | Dock Lock | 程序坞锁定 | needs_review |  |
| `marketing.dockLockPageTitle` | Keep the Dock on one display. | 让程序坞固定在一台显示器上。 | needs_review |  |
| `marketing.dockLockPageAnswer` | On a Mac with more than one display, the Dock jumps to whichever screen you push the pointer against. Dock Lock keeps it on the display you choose. | 在连接了多台显示器的Mac上，你把指针推向哪个屏幕，程序坞就会跳到哪个屏幕。“程序坞锁定”会让它停留在你选择的显示器上。 | needs_review |  |
| `marketing.dockLockPageMetaNoAccount` | No account | 无需账户 | needs_review | Under the /dock-lock hero's Download: 免费且开源 · 无需账户 · macOS 15+ · Apple芯片 |
| `marketing.dockLockPageBenefits.0.lead` | The Dock stays put | 程序坞固定不动 | needs_review |  |
| `marketing.dockLockPageBenefits.0.body` | It stays on the display you pick, wherever your pointer goes. | 不论指针移到哪里，它都会停留在你选择的显示器上。 | needs_review |  |
| `marketing.dockLockPageBenefits.1.lead` | One choice per desk | 每张桌子一个选择 | needs_review |  |
| `marketing.dockLockPageBenefits.1.body` | It remembers a display for each set of screens and moves the Dock there when you plug in. | 它会为每组屏幕记住一台显示器，并在你接上显示器时把程序坞移过去。 | needs_review |  |
| `marketing.dockLockPageBenefits.2.lead` | Keep your Spaces | 保留你的空间 | needs_review |  |
| `marketing.dockLockPageBenefits.2.body` | Unlike the built-in workaround, each display keeps its own Spaces. | 与系统自带的变通办法不同，每台显示器都保留自己的空间。 | needs_review |  |
| `marketing.dockLockPageBenefits.3.lead` | Bottom, left or right | 底部、左侧或右侧 | needs_review |  |
| `marketing.dockLockPageBenefits.3.body` | Works wherever your Dock sits. | 无论程序坞在哪一边都能用。 | needs_review |  |
| `marketing.dockLockPageWhyTitle` | Why the Dock moves | 程序坞为什么会移动 | needs_review |  |
| `marketing.dockLockPageWhyBody` | When “Displays have separate Spaces” is on in System Settings → Desktop & Dock, each display has its own Spaces, and macOS moves the Dock to whichever display you push the pointer against at the Dock's edge: the bottom, or the side for a Dock on the left or right. While that option is on, macOS has no setting to choose which display keeps the Dock. | 在“系统设置”→“桌面与程序坞”中打开“显示器具有单独空间”时，每台显示器都有自己的空间。你把指针推向哪台显示器的程序坞边缘（底部；程序坞在左侧或右侧时则是侧边），macOS就会把程序坞移到那台显示器上。此选项打开时，macOS没有可以选择由哪台显示器保留程序坞的设置。 | needs_review | “显示器具有单独空间” = the app's settings.dockLock.spacesShared; 桌面与程序坞 = macOS's Desktop & Dock pane, verify |
| `marketing.dockLockPageStepsTitle` | Fix it with Dock Lock | 用“程序坞锁定”解决 | needs_review |  |
| `marketing.dockLockPageSteps.0` | Open Dock Tile, go to Settings → Dock Lock and turn on Lock Dock to one display. | 打开Dock Tile，前往“设置”→“程序坞锁定”，然后打开“将程序坞锁定到一台显示器”。 | needs_review | UI terms from the app catalog: settings.dockLock.toggle |
| `marketing.dockLockPageSteps.1` | Allow Accessibility access. Dock Tile explains why first, then macOS asks you to turn Dock Tile on in System Settings. | 允许无障碍访问。Dock Tile会先说明原因，然后macOS会请你在“系统设置”中打开Dock Tile。 | needs_review |  |
| `marketing.dockLockPageSteps.2` | Pick a display under Keep Dock on. The Dock moves there and stays. | 在“将程序坞固定在”中选择一台显示器。程序坞会移到那里并停留在那里。 | needs_review | 将程序坞固定在 = settings.dockLock.anchor |
| `marketing.dockLockPageStepsNote` | Dock Lock remembers your choice for each set of connected displays, so your home desk and your office each keep their own. | “程序坞锁定”会为每组已连接的显示器记住你的选择，因此家里和办公室会各自保留自己的设置。 | needs_review |  |
| `marketing.dockLockPageWithoutTitle` | Without an app | 不用App的办法 | needs_review |  |
| `marketing.dockLockPageWithoutBody` | Turn off “Displays have separate Spaces” in System Settings → Desktop & Dock, then log out and back in. macOS then keeps the Dock on the main display. The cost: your displays no longer have separate Spaces, and the Dock can only stay on the main display. | 在“系统设置”→“桌面与程序坞”中关闭“显示器具有单独空间”，然后退出登录并重新登录。之后macOS会将程序坞保留在主显示器上。代价是：各台显示器不再有单独的空间，而且程序坞只能停留在主显示器上。 | needs_review |  |
| `marketing.dockLockPageFaqTitle` | Questions about Dock Lock | 关于“程序坞锁定”的问题 | needs_review |  |
| `marketing.dockLockPageFaq.0.question` | Can I keep the Dock on one screen without an app? | 不用App能让程序坞停留在一个屏幕上吗？ | needs_review |  |
| `marketing.dockLockPageFaq.0.answer` | Yes, on the main display only. Turn off “Displays have separate Spaces” in System Settings → Desktop & Dock, then log out and back in, and macOS keeps the Dock on the main display. Your displays then lose their separate Spaces. To keep them, or to keep the Dock on another display, use Dock Lock. | 可以，但只能是主显示器。在“系统设置”→“桌面与程序坞”中关闭“显示器具有单独空间”，然后退出登录并重新登录，macOS就会把程序坞保留在主显示器上。之后各台显示器将不再有单独的空间。若想保留单独的空间，或让程序坞停留在其他显示器上，请使用“程序坞锁定”。 | needs_review |  |
| `marketing.dockLockPageFaq.1.question` | Why does Dock Lock need Accessibility access? | 为什么“程序坞锁定”需要无障碍访问权限？ | needs_review |  |
| `marketing.dockLockPageFaq.1.answer` | Dock Lock watches pointer movement near the Dock's edge on your other displays and holds the pointer back there, so macOS never moves the Dock to them. macOS lets an app do that only with Accessibility access. Dock Lock reads only pointer movement, not keystrokes, and asks for access only when you turn it on. | “程序坞锁定”会留意指针在其他显示器程序坞边缘附近的移动，并在那里挡住指针，这样macOS就不会把程序坞移到那些显示器上。macOS只允许拥有无障碍访问权限的App这样做。“程序坞锁定”只读取指针移动，不读取按键，并且只在你打开它时才请求此权限。 | needs_review | 无障碍 = GLOSSARY Accessibility |
| `marketing.dockLockPageFaq.2.question` | What happens when I plug in another display? | 接上另一台显示器时会怎样？ | needs_review |  |
| `marketing.dockLockPageFaq.2.answer` | Once the displays settle, Dock Lock moves the Dock to the display you chose for that set of screens. For a set of screens you haven't set up yet, it leaves the Dock where macOS puts it until you pick a display in Settings → Dock Lock. | 显示器稳定下来后，“程序坞锁定”会把程序坞移到你为这组屏幕选择的显示器上。对于还没设置过的一组屏幕，它会让程序坞留在macOS放置的位置，直到你在“设置”→“程序坞锁定”中选择一台显示器。 | needs_review |  |
| `marketing.dockLockPageFaq.3.question` | Can my pointer still move between displays? | 指针还能在显示器之间移动吗？ | needs_review |  |
| `marketing.dockLockPageFaq.3.answer` | Yes. Dock Lock holds back only a strip a few pixels deep at the Dock's edge on your other displays, so the pointer crosses between screens as usual. | 可以。“程序坞锁定”只会挡住其他显示器程序坞边缘几个像素宽的一条区域，指针仍能照常在屏幕之间移动。 | needs_review |  |
| `marketing.dockLockPageFaq.4.question` | Does it work with a Dock on the left or right? | 程序坞在左侧或右侧时也能用吗？ | needs_review |  |
| `marketing.dockLockPageFaq.4.answer` | Yes. Dock Lock works with the Dock at the bottom, left or right of the screen, and keeps it on the display you choose either way. | 可以。无论程序坞位于屏幕底部、左侧还是右侧，“程序坞锁定”都能使用，并会让它停留在你选择的显示器上。 | needs_review |  |
| `marketing.dockLockPageFaq.5.question` | Does it work with “Displays have separate Spaces” off? | 关闭“显示器具有单独空间”时还能用吗？ | needs_review |  |
| `marketing.dockLockPageFaq.5.answer` | Only for the main display. With that option off, macOS keeps the Dock on the main display, so Dock Lock can't move it to another one. To keep the Dock on a display that isn't the main one, turn the option on in System Settings → Desktop & Dock, then log out and back in. | 只能用于主显示器。关闭此选项时，macOS会将程序坞保留在主显示器上，因此“程序坞锁定”无法把它移到其他显示器。若要让程序坞停留在非主显示器上，请在“系统设置”→“桌面与程序坞”中打开此选项，然后退出登录并重新登录。 | needs_review | From settings.dockLock.spacesShared |
| `marketing.dockLockPageFaq.6.question` | Why can't it move the Dock to one of my displays? | 为什么它无法把程序坞移到我的某台显示器上？ | needs_review |  |
| `marketing.dockLockPageFaq.6.answer` | When another display covers that display's whole Dock edge, such as two equal displays stacked, macOS won't put the Dock there. Shift one display in System Settings → Displays so part of the edge is free, or pick another display. | 如果另一台显示器贴住了那台显示器放置程序坞的整条边（例如两台尺寸相同的显示器上下叠放），macOS就不会把程序坞放到那里。请在“系统设置”→“显示器”中移动一台显示器，让这条边空出一部分，或选择其他显示器。 | needs_review | From settings.dockLock.edgeCovered |
| `marketing.dockLockPageFaq.7.question` | Do I need to use tiles? | 必须使用磁贴吗？ | needs_review |  |
| `marketing.dockLockPageFaq.7.answer` | No. Dock Lock works on its own, without any tiles. The lock holds while Dock Tile is running, so Dock Tile keeps running when you close its window. With a single display, Dock Lock does nothing: the Dock stays where macOS puts it. | 不需要。“程序坞锁定”可以单独使用，无需任何磁贴。锁定在Dock Tile运行时有效，因此关闭Dock Tile的窗口后它会继续运行。只有一台显示器时，“程序坞锁定”不起作用：程序坞会停留在macOS放置的位置。 | needs_review |  |
| `marketing.dockLockPageFaq.8.question` | How do I turn it off? | 如何关闭它？ | needs_review |  |
| `marketing.dockLockPageFaq.8.answer` | In Dock Tile, go to Settings → Dock Lock and turn off Lock Dock to one display. To turn it off for just the current set of screens, pick Default (follow macOS) under Keep Dock on. | 在Dock Tile中前往“设置”→“程序坞锁定”，然后关闭“将程序坞锁定到一台显示器”。若只想对当前这组屏幕关闭，请在“将程序坞固定在”中选择“默认（跟随macOS）”。 | needs_review | = settings.dockLock.toggle / .anchor / .defaultDisplay |
| `marketing.dockLockPageFaq.9.question` | Is Dock Lock free? | “程序坞锁定”免费吗？ | needs_review |  |
| `marketing.dockLockPageFaq.9.answer` | Yes. Dock Lock comes with Dock Tile, which is free and open source, with no account. Turn it on in Settings → Dock Lock. | 是的。“程序坞锁定”随Dock Tile附带，而Dock Tile免费且开源，无需账户。在“设置”→“程序坞锁定”中打开它即可。 | needs_review |  |
| `marketing.dockLockPageClosingA` | Pin your | 今天就固定 | needs_review | Split around the heading's tilted tile: A 🔒 B |
| `marketing.dockLockPageClosingB` | Dock today. | 你的程序坞。 | needs_review |  |
| `marketing.dockLockPageClosingNote` | Free, open source, no account. Turn it off any time and the Dock goes back to how macOS does it. | 免费、开源，无需账户。随时可以关闭，关闭后程序坞会恢复macOS原本的行为。 | needs_review | Under the closing Download |
| `downloadButton` | Download for macOS | 下载macOS版 | needs_review |  |
| `privacy` | Privacy | 隐私 | needs_review |  |
| `terms` | Terms | 条款 | needs_review |  |
| `faq.what-macos-version-do-i-need.question` | What macOS version do I need? | 需要什么版本的macOS？ | needs_review |  |
| `faq.what-macos-version-do-i-need.answer` | Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically. | Dock Tile可在macOS 15（Sequoia）及更高版本上运行，适用于任何搭载Apple芯片（M1或更新）的Mac，不支持Intel芯片的Mac。在macOS 26（Tahoe）及更高版本上，磁贴图标会自动跟随你的“图标和小组件样式”（默认、深色、透明或着色）。 | needs_review | macOS 15 / 26 checked by hand. Icon and widget style names (默认、深色、透明、着色) not verified against a Chinese macOS 26 |
| `faq.is-it-available-on-the-app-store.question` | Is it available on the App Store? | 可以在App Store下载吗？ | needs_review |  |
| `faq.is-it-available-on-the-app-store.answer` | No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do. | 不可以，它需要直接下载。Dock Tile会为每个磁贴构建一个小App并修改你的程序坞，而App Store中的App不允许这样做。 | needs_review |  |
| `faq.is-dock-tile-free.question` | Is Dock Tile free? | Dock Tile免费吗？ | needs_review |  |
| `faq.is-dock-tile-free.answer` | Yes. It's free and open source under the MIT licence, with no account, ads or in-app purchases. | 是的。它免费且开源，采用MIT许可证，没有账户、广告或App内购买项目。 | needs_review |  |
| `faq.what-does-dock-tile-change-on-my-mac.question` | What does Dock Tile change on my Mac? | Dock Tile会对我的Mac做哪些更改？ | needs_review |  |
| `faq.what-does-dock-tile-change-on-my-mac.answer` | It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these. | 它会为每个磁贴构建一个小App，修改你的程序坞并重新启动程序坞以应用更改（第一次会先询问你），还会在登录时启动你的磁贴，除非你关闭此功能。只有在你打开“程序坞锁定”时，它才会请求无障碍访问权限。隐私政策（英文）对每一项都有说明。 | needs_review | Says the Privacy Policy is in English |
| `faq.how-do-i-group-apps-into-folders-in-the-mac-dock.question` | How do I group apps into folders in the Mac Dock? | 如何在Mac的程序坞中将App分组放进文件夹？ | needs_review |  |
| `faq.how-do-i-group-apps-into-folders-in-the-mac-dock.answer` | macOS can't put apps in a folder in the Dock the way an iPhone can. Dock Tile adds that: click + and pick a suggested tile or Create New Tile, add the apps (and folders) that belong together, choose an icon, then click Add. The tile sits in your Dock like any app, and clicking it pops its apps up in a grid or a list. Make as many tiles as you need. | macOS不能像iPhone那样把App放进程序坞中的文件夹。Dock Tile补上了这一点：点按+，选择一个推荐的磁贴或“新建磁贴”，添加属于同一组的App（以及文件夹），选择一个图标，然后点按“添加”。磁贴会像任何App一样待在程序坞中，点按它，它的App就会以网格或列表的形式弹出。需要多少磁贴就创建多少。 | needs_review |  |
| `faq.how-is-a-tile-different-from-a-folder-in-the-dock.question` | How is a tile different from a folder in the Dock? | 磁贴和程序坞中的文件夹有什么不同？ | needs_review |  |
| `faq.how-is-a-tile-different-from-a-folder-in-the-dock.answer` | A folder in the Dock (a stack) sits past the divider and shows the files inside a Finder folder; to hold apps, you'd fill that folder with aliases. A tile sits among your apps and is a small app of its own, with its own icon: a grid of its apps, a symbol or an emoji. It opens its apps in a panel anchored to it. On macOS 26 and later, tiles also follow the Light, Dark, Clear and Tinted icon styles. | 程序坞中的文件夹（叠放）位于分隔线之后，显示访达文件夹中的文件；要用它放App，你得在那个文件夹里放满替身。磁贴则和你的App放在一起，本身就是一个小App，有自己的图标：由它的App组成的网格、一个符号或一个表情符号。它会在锚定于自身的面板中打开它的App。在macOS 26及更高版本上，磁贴还会跟随浅色、深色、透明和着色图标样式。 | needs_review | Icon style names (浅色、深色、透明、着色) not verified against a Chinese macOS 26; 叠放 = Apple's 'stack' |
| `faq.how-do-i-stop-the-dock-moving-to-my-other-display.question` | How do I stop the Dock moving to my other display? | 如何阻止程序坞跑到另一台显示器上？ | needs_review |  |
| `faq.how-do-i-stop-the-dock-moving-to-my-other-display.answer` | With more than one display, macOS moves the Dock to whichever screen you push the pointer against at the Dock's edge. Dock Lock, which comes with Dock Tile, keeps it on the display you choose: open Settings → Dock Lock, turn on Lock Dock to one display, allow Accessibility access when macOS asks, then pick a display under Keep Dock on. It remembers a display for each set of screens you use. | 连接多台显示器时，你在哪块屏幕上把指针推向程序坞所在的边缘，macOS就会把程序坞移到那块屏幕上。Dock Tile附带的“程序坞锁定”可以让它停留在你选择的显示器上：打开“设置”→“程序坞锁定”，打开“将程序坞锁定到一台显示器”，在macOS询问时允许无障碍访问，然后在“将程序坞固定在”下选择一台显示器。它会为你使用的每组屏幕记住一台显示器。 | needs_review |  |
| `faq.what-is-a-dock-tile-extension.question` | What is a Dock tile extension? | 什么是“Dock tile”扩展？ | needs_review | Keeps the English term: the query people search for |
| `faq.what-is-a-dock-tile-extension.answer` | It's a macOS feature, not this app. Some apps include a Dock tile plug-in that keeps their Dock icon up to date, and macOS may tell you when one is added. You can see them, and switch them off, in System Settings → General → Login Items & Extensions. Dock Tile, the app on this site, doesn't install one: each of its tiles is a small app of its own. | 这是macOS的一项功能，而不是本App。有些App带有Dock tile插件，用来让它们的程序坞图标保持最新，添加插件时macOS可能会通知你。你可以在“系统设置”→“通用”→“登录项与扩展”中查看并关闭它们。本网站介绍的Dock Tile不会安装这种插件：它的每个磁贴都是一个独立的小App。 | needs_review |  |
| `faq.how-do-i-create-a-new-tile.question` | How do I create a new tile? | 如何创建新磁贴？ | needs_review |  |
| `faq.how-do-i-create-a-new-tile.answer` | Open Dock Tile, click + in the sidebar and choose a suggested tile or Create New Tile. Name it, add apps, pick its icon, then click Add to put it in your Dock. | 打开Dock Tile，点按边栏中的+，然后选择一个推荐的磁贴或“新建磁贴”。为它命名、添加App、选择图标，然后点按“添加”将它放进程序坞。 | needs_review |  |
| `faq.can-i-change-a-tiles-icon-after-creating-it.question` | Can I change a tile's icon after creating it? | 创建磁贴后还能更改它的图标吗？ | needs_review |  |
| `faq.can-i-change-a-tiles-icon-after-creating-it.answer` | Yes. Select the tile and click its icon to open Customise Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look. | 可以。选择该磁贴，然后点按它的图标打开“自定义磁贴”。可以将磁贴自己的App显示为网格，也可以选择一个符号或表情符号及其背景。如果磁贴已经在程序坞中，点按“更新”以应用新外观。 | needs_review |  |
| `faq.why-doesnt-right-click-show-a-context-menu.question` | Why doesn't right-click show a context menu? | 为什么右键点按不显示快捷菜单？ | needs_review |  |
| `faq.why-doesnt-right-click-show-a-context-menu.answer` | By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one. | 默认情况下，磁贴以Ghost mode（幽灵模式，不出现在Command-Tab中）运行，这种模式不支持快捷菜单。为该磁贴打开“在App切换器中显示”即可使用快捷菜单。 | needs_review |  |
| `faq.how-do-i-uninstall-a-tile.question` | How do I uninstall a tile? | 如何卸载一个磁贴？ | needs_review |  |
| `faq.how-do-i-uninstall-a-tile.answer` | Select the tile, turn off Show in Dock, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app. | 选择该磁贴，关闭“在程序坞中显示”，然后点按“移除”。磁贴仍会保留在Dock Tile中，供以后使用。要永久删除它，请点按废纸篓按钮。你也可以像拖移任何App一样，把磁贴拖出程序坞。 | needs_review | The English says 'turn off Show in Dock'; the app's switch (label.showTile) reads Show in Dock / 在程序坞中显示, which the Chinese follows |
| `faq.how-do-i-uninstall-dock-tile.question` | How do I uninstall Dock Tile? | 如何卸载Dock Tile？ | needs_review |  |
| `faq.how-do-i-uninstall-dock-tile.answer` | Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Bin. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Bin, the tiles in your Dock keep working: drag them out, then delete that folder. | 打开Dock Tile，用废纸篓按钮删除每个磁贴，这也会把它从程序坞中移除。在“设置”→“通用”中关闭“登录时启动磁贴”，退出Dock Tile，然后将它移到废纸篓。若要彻底清除，还要删除~/Library/Application Support/DockTile/以及~/Library/Preferences/中以com.docktile开头的文件。如果你只把App移到废纸篓，程序坞中的磁贴仍可继续使用：把它们拖出程序坞，然后删除那个文件夹。 | needs_review |  |
| `faq.how-many-tiles-can-i-create.question` | How many tiles can I create? | 可以创建多少个磁贴？ | needs_review |  |
| `faq.how-many-tiles-can-i-create.answer` | There's no hard limit. You can create as many tiles as you need to organise your apps and workflows. | 没有硬性限制。你可以根据整理App和工作流程的需要，创建任意数量的磁贴。 | needs_review |  |
| `faq.can-i-add-folders-to-a-tile.question` | Can I add folders to a tile? | 可以在磁贴中添加文件夹吗？ | needs_review |  |
| `faq.can-i-add-folders-to-a-tile.answer` | Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder. | 可以。向磁贴添加项目时，除了App，你还可以选择文件夹。点按文件夹，它就会在访达中打开。 | needs_review |  |
| `faq.do-tiles-sync-across-macs.question` | Do tiles sync across Macs? | 磁贴会在多台Mac之间同步吗？ | needs_review |  |
| `faq.do-tiles-sync-across-macs.answer` | Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update. | 目前不会。磁贴配置存储在每台Mac本地。我们可能会在将来的更新中加入iCloud同步。 | needs_review |  |
| `faq.can-i-reorder-apps-within-a-tile.question` | Can I reorder apps within a tile? | 可以调整磁贴中App的顺序吗？ | needs_review |  |
| `faq.can-i-reorder-apps-within-a-tile.answer` | Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it. | 可以。在磁贴的“此磁贴中的项目”列表中，将App拖到新位置。这就是磁贴在程序坞中打开的那个面板，所以你看到的顺序就是最终的顺序。如果磁贴已经在程序坞中，点按“更新”以应用更改。 | needs_review |  |
| `faq.whats-the-difference-between-grid-and-list-layout.question` | What's the difference between Grid and List layout? | “网格”和“列表”布局有什么区别？ | needs_review |  |
| `faq.whats-the-difference-between-grid-and-list-layout.answer` | Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view. | 网格布局以网格形式显示App图标（类似iOS文件夹）。列表布局以竖向菜单显示App及其名称，类似程序坞的文件夹视图。 | needs_review |  |
| `faq.how-do-i-back-up-my-tiles.question` | How do I back up my tiles? | 如何备份我的磁贴？ | needs_review |  |
| `faq.how-do-i-back-up-my-tiles.answer` | Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles. | 你的磁贴配置存储在~/Library/Preferences/com.docktile.configs.json中。备份此文件即可保留你的磁贴。 | needs_review |  |
| `names.AI Apps` | AI Apps | AI助手 | needs_review | A demo tile's name, freely translated |
| `names.Dev Apps` | Dev Apps | 开发工具 | needs_review | A demo tile's name, freely translated |
| `names.Comms` | Comms | 沟通 | needs_review | A demo tile's name, freely translated |
| `names.Media` | Media | 影音 | needs_review | A demo tile's name, freely translated |
| `names.Chat` | Chat | 聊天 | needs_review | App string smartAdd.identity.chat |
| `names.Ship` | Ship | 开发 | needs_review | App string smartAdd.identity.ship |
| `names.Watch` | Watch | 观看 | needs_review | App string smartAdd.identity.watch |
| `names.Finder` | Finder | 访达 | needs_review | Glossary |
| `names.System Settings` | System Settings | 系统设置 | needs_review |  |
| `names.Messages` | Messages | 信息 | needs_review |  |
| `names.Music` | Music | 音乐 | needs_review |  |
| `names.Podcasts` | Podcasts | 播客 | needs_review |  |
| `names.Screenshot` | Screenshot | 截屏 | needs_review |  |
| `names.FaceTime` | FaceTime | FaceTime通话 | needs_review | What a Chinese Mac shows for FaceTime; verify |
| `meta.homeTitle` | Dock Tile - iOS-style app folders for your Mac's Dock | Dock Tile - 为Mac程序坞带来iOS风格的App文件夹 | needs_review | English: siteConfig.appName + tagline (lib/config.ts); not drift-checked |
| `meta.homeDescription` | Put a group of apps behind one Dock icon. Click it and they pop up, like a folder on your iPhone. Free and open source, for macOS 15+ on Apple silicon. | 将一组App放进一个程序坞图标。点一下，它们就会弹出来，就像iPhone上的文件夹。免费且开源，适用于macOS 15及更高版本，需搭载Apple芯片。 | needs_review | English: siteConfig.description; also the JSON-LD description on /zh-Hans; not drift-checked. macOS 15 checked by hand |
| `meta.faqTitle` | Frequently Asked Questions - Dock Tile | 常见问题 - Dock Tile | needs_review | English: app/faq/page.tsx; not drift-checked |
| `meta.faqDescription` | Answers to common Dock Tile questions — macOS version requirements, creating and customising tiles, Ghost Mode, backups, and Grid vs List layouts. | Dock Tile常见问题解答：macOS版本要求、创建和自定义磁贴、Ghost mode、备份，以及网格与列表布局。 | needs_review | English: app/faq/page.tsx; not drift-checked |
| `meta.dockLockTitle` | Stop the Mac Dock jumping to your other monitor | 让Mac程序坞不再跳到另一台显示器上 | needs_review | English: app/dock-lock/page.tsx; not drift-checked |
| `meta.dockLockDescription` | With more than one display, the Mac Dock jumps to the screen you push the pointer against. Dock Lock, free with Dock Tile, keeps it on the display you choose. | 在连接了多台显示器的Mac上，程序坞会跳到你用指针推向的那个屏幕。“程序坞锁定”随免费的Dock Tile附带，会让程序坞停留在你选择的显示器上。 | needs_review | English: app/dock-lock/page.tsx; not drift-checked |
