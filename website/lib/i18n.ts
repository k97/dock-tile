// Localisation for US, UK, AU English, plus a Simplified Chinese test of /, /faq and /dock-lock
// (served at /zh-Hans; machine-first, review sheet docs/l10n/website-zh-Hans.md).
// Default fallback: AU English

export type Locale = "en-AU" | "en-GB" | "en-US" | "zh-Hans";

export const defaultLocale: Locale = "en-AU";

// v2 marketing copy — only spelling-sensitive strings vary by locale
const marketingBase = {
  heroHeadlineA: "Group your apps.",
  heroHeadlineB: "Declutter your Dock.",
  heroSub:
    "Put a group of apps behind one Dock icon. Click it and they pop up, like a folder on your iPhone.",
  tryIt: "Try it — click a tile",
  tilesTitleA: "Pick your apps. Pick a look.", // nbsp: break after "apps.", never strand "Pick"
  tilesTitleB: "Done.",
  tilesBody:
    "Set up every tile in the Dock Tile companion app. You arrange its apps in the same panel that pops up from the Dock, so what you see is what you get. Then pick its icon: a grid of its own apps, a symbol or an emoji, on colour or a plain background.",
  tilesAlt: "Dock Tile editing a tile: its popover in the middle, Customise Tile on the right.",
  // "Take a closer look" hotspots on the screenshot — label + one or two sentences each
  tilesSpotPopover: "In This Tile",
  tilesSpotPopoverBody: "Drag apps into order, or hover to remove one. It's the same popover your tile opens.",
  tilesSpotStyle: "Style",
  tilesSpotStyleBody: "App Grid shows the tile's own apps. Or pick a symbol or an emoji.",
  tilesSpotBackground: "Background",
  tilesSpotBackgroundBody: "Colour fills the tile. Mono keeps it white in Light Mode and black in Dark Mode.",
  tilesSpotTile: "Your tile",
  tilesSpotTileBody: "Every change shows on the tile as you make it.",
  tilesSpotPrevious: "Previous",
  tilesSpotNext: "Next",
  tilesSpotClose: "Close",
  tilesSpotLabelEnd: ".", // after the hotspot's bold label, before its sentence
  // What Dock Tile is (first section after the hero), split around the heading's tile
  introTitleA: "Less Dock.",
  introTitleB: "More multitasking.",
  introBefore: "Before",
  introAfter: "With Dock Tile",
  introPoints: [
    { lead: "One tile, many apps", body: "Group apps and folders behind a single Dock icon. Click it and they pop up, ready to open." },
    { lead: "Looks like it belongs", body: "Each tile is a real Mac app with its own icon, so it sits and magnifies like everything else in your Dock." },
    { lead: "Ready in a minute", body: "Pick a suggested tile or start blank, add your apps, then put it in your Dock." },
  ],
  // The card section's heading (Smart Add sets up; menu bar + Ghost stay out of the way)
  cardsTitleA: "Set up for you.",
  cardsTitleB: "Out of your way.",
  smartAddTitle: "Ready-made tiles from the apps you use.",
  smartAddBody:
    "Click +, and Dock Tile groups the apps you use most into ready-made tiles. Pick one and it opens ready to tweak; nothing reaches your Dock until you add it.",
  smartAddPrivacy: "Learned on your Mac. Never leaves your device.",
  ghostTitle: "Ghost mode.",
  ghostBody:
    "Tiles stay out of the app switcher (Command-Tab) by default, so it lists only the apps you're actually using.",
  ghostTip: "Want one in Command-Tab? Switch it on for that tile.",
  dockLockTitleA: "The Dock", // split around the heading's tilted tile
  dockLockTitleB: "stays put.",
  // Dock Lock is its own tool that ships with Dock Tile, not a tile feature: the lead says so.
  dockLockLead: "Dock Lock comes with Dock Tile.",
  // A teaser: the how and why live on /dock-lock, which the band links to
  dockLockBody: "Pick a screen for the Dock and it stays there, however many displays you use.",
  menuBarTitle: "Your tiles, in the menu bar.",
  menuBarLead: "On from the first launch.",
  menuBarIntro: "A menu bar shortcut comes with Dock Tile.", // bold lead-in, like Dock Lock's
  menuBarBody:
    "The tiles in your Dock and their apps, listed in the menu bar, ready even when the Dock is hidden. Turn it off in Settings any time.",
  // The row of small features: a plain name, then one calm sentence.
  details: [
    { lead: "Keyboard friendly", body: "Arrow keys move through a tile's apps. Return opens, Esc closes." },
    { lead: "Folders too", body: "Add a folder beside your apps and open it in one click." },
    { lead: "Free and open source", body: "No price and no account. MIT‑licensed, with the code on GitHub." },
    { lead: "In your language", body: "English, 简体中文, 日本語, Deutsch, Русский and Français." },
  ],
  // Feature requests and bug reports (footer + FAQ), both open a GitHub issue
  featureRequest: "Request a feature",
  featureRequestBody: "Tell us what Dock Tile should do next.",
  bugReport: "Report a bug",
  bugReportBody: "Something not working? Tell us what happened and on which macOS.",
  feedbackTitle: "Help shape Dock Tile",
  feedbackNote: "Both open a GitHub issue. No GitHub account? Use Contact support below.",
  ctaButton: "Download Dock Tile",
  ctaMetaOpenSource: "Free & open source",
  ctaMetaAppleSilicon: "Apple silicon",
  ctaMetaMacOS: "macOS 15+", // the floor; MacOSFloorGuardTests reads this file
  // Download buttons on a device that can't run the app (Windows, iPhone, Android, Linux)
  copyLinkButton: "Copy link for your Mac",
  copyLinkShort: "Copy link", // the nav pill: its width is a WebKit landmine (design-system.md)
  copyLinkDone: "Link copied",
  // Homepage FAQ (the top questions; the rest live on /faq)
  homeFaqTitleA: "Questions,", // split around the heading's tilted tile
  homeFaqTitleB: "answered.",
  homeFaqMore: "See all questions",
  // Download section (above the footer), split around the heading's tilted tile
  downloadTitleA: "Tidy your", // split around the heading's tilted tile
  downloadTitleB: "Dock today.",
  // Footer columns
  footerFeatures: "Features",
  footerWhatsNew: "What's new",
  footerFaq: "FAQ",
  footerDownload: "Download",
  footerResources: "Resources",
  footerGithub: "GitHub",
  footerContact: "Contact",
  footerCompany: "Company",
  footerAbout: "About",
  footerStudioTagline: "Products for the everyday.", // the studio site's own line
  footerMadeWithA: "Made with", // © YYYY, Made with ♥ for macOS
  footerMadeWithB: "for macOS",
  footerLove: "love", // the heart's accessible name
  opensInNewTab: "(opens in a new tab)",
  // The other language's home, named in its own words (footer)
  languageLink: "简体中文",
  // /faq's closing ask, and the Contact button on every ContactCta
  faqCtaTitle: "Still stuck?",
  faqCtaSubtitle: "Send a note and you'll usually hear back within a day.",
  contactSupport: "Contact support",
  // Download button states
  downloading: "Downloading…",
  downloaded: "Downloaded",
  // Footer theme switcher (accessible names)
  themeLight: "Light",
  themeSystem: "System",
  themeDark: "Dark",
  // macOS mocks: the app's own strings (re-check after an app release)
  mockOpenDockTile: "Open Dock Tile…",
  mockQuitDockTile: "Quit Dock Tile",
  mockConfigureTileItem: "Configure Tile…", // menu row
  mockConfigureTile: "Configure Tile", // the grid popover's gear (tooltip + accessible name)
  mockConfigure: "Configure…", // the list popover's last row
  mockPopoverLabel: "{tile} apps", // the hero popover's accessible name; {tile} = the tile's name
  mockClock: "Mon 9:41",
  mockAddTile: "Add a Tile",
  mockBlankTitle: "Create a blank tile",
  mockBlankBody: "Name it, pick an icon and add apps yourself.",
  mockStartFrom: "or start from what you use",
  mockMostUsed: "Most used this week",
  mockFiveApps: "5 apps",
  mockThreeApps: "3 apps",
  // The homepage Dock Lock band's link to /dock-lock, and the footer's
  dockLockPageLink: "How Dock Lock works",
  footerDockLock: "Dock Lock",
  // /dock-lock: answers "the Dock keeps moving to my other monitor". Every claim is the app's own
  // (AppStrings settings.dockLock.*, .claude/rules/dock-lock.md); macOS behaviour only as the app states it.
  dockLockPageEyebrow: "Dock Lock",
  dockLockPageTitle: "Keep the Dock on one display.",
  dockLockPageAnswer:
    "On a Mac with more than one display, the Dock jumps to whichever screen you push the pointer against. Dock Lock keeps it on the display you choose.",
  dockLockPageMetaNoAccount: "No account", // the proof line under the hero's Download: Free & open source · No account · macOS 15+ · Apple silicon
  // Four one-liners under the hero (the homepage's small-feature row style)
  dockLockPageBenefits: [
    { lead: "The Dock stays put", body: "It stays on the display you pick, wherever your pointer goes." },
    {
      lead: "One choice per desk",
      body: "It remembers a display for each set of screens and moves the Dock there when you plug in.",
    },
    { lead: "Keep your Spaces", body: "Unlike the built-in workaround, each display keeps its own Spaces." },
    { lead: "Bottom, left or right", body: "Works wherever your Dock sits." },
  ],
  dockLockPageWhyTitle: "Why the Dock moves",
  dockLockPageWhyBody:
    "When “Displays have separate Spaces” is on in System Settings → Desktop & Dock, each display has its own Spaces, and macOS moves the Dock to whichever display you push the pointer against at the Dock's edge: the bottom, or the side for a Dock on the left or right. While that option is on, macOS has no setting to choose which display keeps the Dock.",
  dockLockPageStepsTitle: "Fix it with Dock Lock",
  dockLockPageSteps: [
    "Open Dock Tile, go to Settings → Dock Lock and turn on Lock Dock to one display.",
    "Allow Accessibility access. Dock Tile explains why first, then macOS asks you to turn Dock Tile on in System Settings.",
    "Pick a display under Keep Dock on. The Dock moves there and stays.",
  ],
  dockLockPageStepsNote:
    "Dock Lock remembers your choice for each set of connected displays, so your home desk and your office each keep their own.",
  dockLockPageWithoutTitle: "Without an app",
  dockLockPageWithoutBody:
    "Turn off “Displays have separate Spaces” in System Settings → Desktop & Dock, then log out and back in. macOS then keeps the Dock on the main display. The cost: your displays no longer have separate Spaces, and the Dock can only stay on the main display.",
  dockLockPageFaqTitle: "Questions about Dock Lock",
  // This page's own questions (and FAQPage markup), worded apart from /faq's "stop the Dock moving"
  dockLockPageFaq: [
    {
      question: "Can I keep the Dock on one screen without an app?",
      answer:
        "Yes, on the main display only. Turn off “Displays have separate Spaces” in System Settings → Desktop & Dock, then log out and back in, and macOS keeps the Dock on the main display. Your displays then lose their separate Spaces. To keep them, or to keep the Dock on another display, use Dock Lock.",
    },
    {
      question: "Why does Dock Lock need Accessibility access?",
      answer:
        "Dock Lock watches pointer movement near the Dock's edge on your other displays and holds the pointer back there, so macOS never moves the Dock to them. macOS lets an app do that only with Accessibility access. Dock Lock reads only pointer movement, not keystrokes, and asks for access only when you turn it on.",
    },
    {
      question: "What happens when I plug in another display?",
      answer:
        "Once the displays settle, Dock Lock moves the Dock to the display you chose for that set of screens. For a set of screens you haven't set up yet, it leaves the Dock where macOS puts it until you pick a display in Settings → Dock Lock.",
    },
    {
      question: "Can my pointer still move between displays?",
      answer:
        "Yes. Dock Lock holds back only a strip a few pixels deep at the Dock's edge on your other displays, so the pointer crosses between screens as usual.",
    },
    {
      question: "Does it work with a Dock on the left or right?",
      answer:
        "Yes. Dock Lock works with the Dock at the bottom, left or right of the screen, and keeps it on the display you choose either way.",
    },
    {
      question: "Does it work with “Displays have separate Spaces” off?",
      answer:
        "Only for the main display. With that option off, macOS keeps the Dock on the main display, so Dock Lock can't move it to another one. To keep the Dock on a display that isn't the main one, turn the option on in System Settings → Desktop & Dock, then log out and back in.",
    },
    {
      question: "Why can't it move the Dock to one of my displays?",
      answer:
        "When another display covers that display's whole Dock edge, such as two equal displays stacked, macOS won't put the Dock there. Shift one display in System Settings → Displays so part of the edge is free, or pick another display.",
    },
    {
      question: "Do I need to use tiles?",
      answer:
        "No. Dock Lock works on its own, without any tiles. The lock holds while Dock Tile is running, so Dock Tile keeps running when you close its window. With a single display, Dock Lock does nothing: the Dock stays where macOS puts it.",
    },
    {
      question: "How do I turn it off?",
      answer:
        "In Dock Tile, go to Settings → Dock Lock and turn off Lock Dock to one display. To turn it off for just the current set of screens, pick Default (follow macOS) under Keep Dock on.",
    },
    {
      question: "Is Dock Lock free?",
      answer:
        "Yes. Dock Lock comes with Dock Tile, which is free and open source, with no account. Turn it on in Settings → Dock Lock.",
    },
  ],
  dockLockPageClosingA: "Pin your", // split around the heading's tilted tile
  dockLockPageClosingB: "Dock today.",
  dockLockPageClosingNote: "Free, open source, no account. Turn it off any time and the Dock goes back to how macOS does it.",
} as const;

const marketingUS = {
  ...marketingBase,
  tilesBody:
    "Set up every tile in the Dock Tile companion app. You arrange its apps in the same panel that pops up from the Dock, so what you see is what you get. Then pick its icon: a grid of its own apps, a symbol or an emoji, on color or a plain background.",
  tilesAlt: "Dock Tile editing a tile: its popover in the middle, Customize Tile on the right.",
  tilesSpotBackgroundBody: "Color fills the tile. Mono keeps it white in Light Mode and black in Dark Mode.",
} as const;

// Simplified Chinese (machine-first, every row needs_review in docs/l10n/website-zh-Hans.md;
// `npm run check:zh` fails when an English string here drifts from that sheet). Terms follow
// docs/l10n/GLOSSARY.md and the app's own zh-Hans strings (Localizable.xcstrings): 磁贴, 程序坞,
// 弹出面板, 访达, App切换器, 你; full-width punctuation, no space between Chinese and Latin
// words (the app's style); "Dock Tile" is never translated. The macOS floor is checked by hand
// here (MacOSFloorGuardTests reads only English).
const marketingZh = {
  heroHeadlineA: "将App分组。",
  heroHeadlineB: "让程序坞井井有条。",
  heroSub: "将一组App放进一个程序坞图标。点一下，它们就会弹出来，就像iPhone上的文件夹。",
  tryIt: "试试看——点一个磁贴",
  tilesTitleA: "挑选App，选个外观。",
  tilesTitleB: "完成。",
  tilesBody:
    "每个磁贴都在Dock Tile配套App中设置。你在程序坞弹出的同一个面板里排列它的App，所见即所得。然后为它选择图标：由它自己的App组成的网格、一个符号或一个表情符号，配上彩色或纯色背景。",
  tilesAlt: "Dock Tile正在编辑一个磁贴：中间是它的弹出面板，右侧是“自定义磁贴”。",
  tilesSpotPopover: "此磁贴中的项目",
  tilesSpotPopoverBody: "拖动App调整顺序，或将指针悬停在App上将其移除。这就是你的磁贴打开的那个弹出面板。",
  tilesSpotStyle: "样式",
  tilesSpotStyleBody: "“App网格”显示磁贴自己的App。也可以选择一个符号或表情符号。",
  tilesSpotBackground: "背景",
  tilesSpotBackgroundBody: "“颜色”会填满整个磁贴。“单色”在浅色模式下为白色，在深色模式下为黑色。",
  tilesSpotTile: "你的磁贴",
  tilesSpotTileBody: "你做的每处更改都会立即显示在磁贴上。",
  tilesSpotPrevious: "上一个",
  tilesSpotNext: "下一个",
  tilesSpotClose: "关闭",
  tilesSpotLabelEnd: "：",
  introTitleA: "程序坞更清爽。",
  introTitleB: "多任务更从容。",
  introBefore: "之前",
  introAfter: "使用Dock Tile后",
  introPoints: [
    { lead: "一个磁贴，多个App", body: "将App和文件夹放在同一个程序坞图标后面。点一下，它们就会弹出，随时可以打开。" },
    { lead: "就像原生的一样", body: "每个磁贴都是一个真正的Mac App，有自己的图标，所以它在程序坞中的样子和放大效果都与其他图标一致。" },
    { lead: "一分钟就能设置好", body: "选择一个推荐的磁贴或从空白开始，添加你的App，然后把它放进程序坞。" },
  ],
  cardsTitleA: "为你设置好。",
  cardsTitleB: "绝不碍事。",
  smartAddTitle: "用你常用的App生成现成的磁贴。",
  smartAddBody:
    "点按+，Dock Tile会把你最常用的App分组成现成的磁贴。选一个，它会打开供你调整；在你添加之前，任何东西都不会进入程序坞。",
  smartAddPrivacy: "在你的Mac上学习得出，数据绝不离开你的设备。",
  ghostTitle: "Ghost mode（幽灵模式）。",
  ghostBody: "默认情况下，磁贴不会出现在App切换器（Command-Tab）中，因此那里只列出你真正在使用的App。",
  ghostTip: "想让某个磁贴出现在Command-Tab中？为该磁贴打开此选项即可。",
  dockLockTitleA: "程序坞",
  dockLockTitleB: "不再乱跑。",
  dockLockLead: "Dock Tile附带“程序坞锁定”。",
  dockLockBody: "为程序坞选一台显示器，无论你连接几台显示器，它都会留在那里。",
  menuBarTitle: "你的磁贴，就在菜单栏中。",
  menuBarLead: "首次启动即开启。",
  menuBarIntro: "Dock Tile附带菜单栏快捷方式。",
  menuBarBody: "程序坞中的磁贴及其App会列在菜单栏中，即使程序坞隐藏也能随时使用。你可以随时在“设置”中关闭它。",
  details: [
    { lead: "支持键盘操作", body: "用方向键在磁贴的App之间移动。按Return打开，按Esc关闭。" },
    { lead: "也支持文件夹", body: "在App旁边添加文件夹，点一下即可打开。" },
    { lead: "免费且开源", body: "无需付费，无需账户。采用MIT许可证，代码在GitHub上。" },
    { lead: "支持你的语言", body: "English、简体中文、日本語、Deutsch、Русский和Français。" },
  ],
  featureRequest: "建议新功能",
  featureRequestBody: "告诉我们Dock Tile接下来应该做什么。",
  bugReport: "报告错误",
  bugReportBody: "有东西不正常？告诉我们发生了什么，以及你使用的是哪个版本的macOS。",
  feedbackTitle: "帮助完善Dock Tile",
  feedbackNote: "两者都会在GitHub上新建一个议题（英文）。没有GitHub账户？请使用下方的“联系支持”。",
  ctaButton: "下载Dock Tile",
  ctaMetaOpenSource: "免费且开源",
  ctaMetaAppleSilicon: "Apple芯片",
  ctaMetaMacOS: "macOS 15+",
  copyLinkButton: "为你的Mac拷贝链接",
  copyLinkShort: "拷贝链接",
  copyLinkDone: "链接已拷贝",
  homeFaqTitleA: "常见问题，",
  homeFaqTitleB: "一一解答。",
  homeFaqMore: "查看所有问题",
  downloadTitleA: "今天就整理",
  downloadTitleB: "你的程序坞。",
  footerFeatures: "功能",
  footerWhatsNew: "更新内容",
  footerFaq: "常见问题",
  footerDownload: "下载",
  footerResources: "资源",
  footerGithub: "GitHub",
  footerContact: "联系我们",
  footerCompany: "公司",
  footerAbout: "关于",
  footerStudioTagline: "为日常而做的产品。",
  footerMadeWithA: "用",
  footerMadeWithB: "为macOS打造",
  footerLove: "爱",
  opensInNewTab: "（在新标签页中打开）",
  languageLink: "English",
  faqCtaTitle: "还有问题？",
  faqCtaSubtitle: "给我们发封邮件，通常一天内就会收到回复。",
  contactSupport: "联系支持",
  downloading: "正在下载…",
  downloaded: "已下载",
  themeLight: "浅色",
  themeSystem: "跟随系统",
  themeDark: "深色",
  mockOpenDockTile: "打开Dock Tile…",
  mockQuitDockTile: "退出Dock Tile",
  mockConfigureTileItem: "配置磁贴…",
  mockConfigureTile: "配置磁贴",
  mockConfigure: "配置…",
  mockPopoverLabel: "{tile}中的App",
  mockClock: "周一 9:41",
  mockAddTile: "添加磁贴",
  mockBlankTitle: "创建空白磁贴",
  mockBlankBody: "自行命名、选择图标并添加App。",
  mockStartFrom: "或从你常用的App开始",
  mockMostUsed: "本周最常用",
  mockFiveApps: "5个App",
  mockThreeApps: "3个App",
  dockLockPageLink: "了解“程序坞锁定”如何工作",
  footerDockLock: "程序坞锁定",
  dockLockPageEyebrow: "程序坞锁定",
  dockLockPageTitle: "让程序坞固定在一台显示器上。",
  dockLockPageAnswer:
    "在连接了多台显示器的Mac上，你把指针推向哪个屏幕，程序坞就会跳到哪个屏幕。“程序坞锁定”会让它停留在你选择的显示器上。",
  dockLockPageMetaNoAccount: "无需账户",
  dockLockPageBenefits: [
    { lead: "程序坞固定不动", body: "不论指针移到哪里，它都会停留在你选择的显示器上。" },
    { lead: "每张桌子一个选择", body: "它会为每组屏幕记住一台显示器，并在你接上显示器时把程序坞移过去。" },
    { lead: "保留你的空间", body: "与系统自带的变通办法不同，每台显示器都保留自己的空间。" },
    { lead: "底部、左侧或右侧", body: "无论程序坞在哪一边都能用。" },
  ],
  dockLockPageWhyTitle: "程序坞为什么会移动",
  dockLockPageWhyBody:
    "在“系统设置”→“桌面与程序坞”中打开“显示器具有单独空间”时，每台显示器都有自己的空间。你把指针推向哪台显示器的程序坞边缘（底部；程序坞在左侧或右侧时则是侧边），macOS就会把程序坞移到那台显示器上。此选项打开时，macOS没有可以选择由哪台显示器保留程序坞的设置。",
  dockLockPageStepsTitle: "用“程序坞锁定”解决",
  dockLockPageSteps: [
    "打开Dock Tile，前往“设置”→“程序坞锁定”，然后打开“将程序坞锁定到一台显示器”。",
    "允许无障碍访问。Dock Tile会先说明原因，然后macOS会请你在“系统设置”中打开Dock Tile。",
    "在“将程序坞固定在”中选择一台显示器。程序坞会移到那里并停留在那里。",
  ],
  dockLockPageStepsNote:
    "“程序坞锁定”会为每组已连接的显示器记住你的选择，因此家里和办公室会各自保留自己的设置。",
  dockLockPageWithoutTitle: "不用App的办法",
  dockLockPageWithoutBody:
    "在“系统设置”→“桌面与程序坞”中关闭“显示器具有单独空间”，然后退出登录并重新登录。之后macOS会将程序坞保留在主显示器上。代价是：各台显示器不再有单独的空间，而且程序坞只能停留在主显示器上。",
  dockLockPageFaqTitle: "关于“程序坞锁定”的问题",
  dockLockPageFaq: [
    {
      question: "不用App能让程序坞停留在一个屏幕上吗？",
      answer:
        "可以，但只能是主显示器。在“系统设置”→“桌面与程序坞”中关闭“显示器具有单独空间”，然后退出登录并重新登录，macOS就会把程序坞保留在主显示器上。之后各台显示器将不再有单独的空间。若想保留单独的空间，或让程序坞停留在其他显示器上，请使用“程序坞锁定”。",
    },
    {
      question: "为什么“程序坞锁定”需要无障碍访问权限？",
      answer:
        "“程序坞锁定”会留意指针在其他显示器程序坞边缘附近的移动，并在那里挡住指针，这样macOS就不会把程序坞移到那些显示器上。macOS只允许拥有无障碍访问权限的App这样做。“程序坞锁定”只读取指针移动，不读取按键，并且只在你打开它时才请求此权限。",
    },
    {
      question: "接上另一台显示器时会怎样？",
      answer:
        "显示器稳定下来后，“程序坞锁定”会把程序坞移到你为这组屏幕选择的显示器上。对于还没设置过的一组屏幕，它会让程序坞留在macOS放置的位置，直到你在“设置”→“程序坞锁定”中选择一台显示器。",
    },
    {
      question: "指针还能在显示器之间移动吗？",
      answer:
        "可以。“程序坞锁定”只会挡住其他显示器程序坞边缘几个像素宽的一条区域，指针仍能照常在屏幕之间移动。",
    },
    {
      question: "程序坞在左侧或右侧时也能用吗？",
      answer:
        "可以。无论程序坞位于屏幕底部、左侧还是右侧，“程序坞锁定”都能使用，并会让它停留在你选择的显示器上。",
    },
    {
      question: "关闭“显示器具有单独空间”时还能用吗？",
      answer:
        "只能用于主显示器。关闭此选项时，macOS会将程序坞保留在主显示器上，因此“程序坞锁定”无法把它移到其他显示器。若要让程序坞停留在非主显示器上，请在“系统设置”→“桌面与程序坞”中打开此选项，然后退出登录并重新登录。",
    },
    {
      question: "为什么它无法把程序坞移到我的某台显示器上？",
      answer:
        "如果另一台显示器贴住了那台显示器放置程序坞的整条边（例如两台尺寸相同的显示器上下叠放），macOS就不会把程序坞放到那里。请在“系统设置”→“显示器”中移动一台显示器，让这条边空出一部分，或选择其他显示器。",
    },
    {
      question: "必须使用磁贴吗？",
      answer:
        "不需要。“程序坞锁定”可以单独使用，无需任何磁贴。锁定在Dock Tile运行时有效，因此关闭Dock Tile的窗口后它会继续运行。只有一台显示器时，“程序坞锁定”不起作用：程序坞会停留在macOS放置的位置。",
    },
    {
      question: "如何关闭它？",
      answer:
        "在Dock Tile中前往“设置”→“程序坞锁定”，然后关闭“将程序坞锁定到一台显示器”。若只想对当前这组屏幕关闭，请在“将程序坞固定在”中选择“默认（跟随macOS）”。",
    },
    {
      question: "“程序坞锁定”免费吗？",
      answer:
        "是的。“程序坞锁定”随Dock Tile附带，而Dock Tile免费且开源，无需账户。在“设置”→“程序坞锁定”中打开它即可。",
    },
  ],
  dockLockPageClosingA: "今天就固定",
  dockLockPageClosingB: "你的程序坞。",
  dockLockPageClosingNote: "免费、开源，无需账户。随时可以关闭，关闭后程序坞会恢复macOS原本的行为。",
} as const satisfies Record<keyof typeof marketingBase, unknown>;

// Names shown in the mocks, keyed by the English the data arrays use (comparisons stay English).
// English shows every name as-is; Chinese takes the names a Chinese Mac shows for Apple's own
// apps (third-party brands unchanged) and translates the demo's tile names.
const noNames: Readonly<Record<string, string>> = {};
const namesZh: Readonly<Record<string, string>> = {
  "AI Apps": "AI助手",
  "Dev Apps": "开发工具",
  Comms: "沟通",
  Media: "影音",
  // Smart Add identities: the app's smartAdd.identity.* strings
  Chat: "聊天",
  Ship: "开发",
  Watch: "观看",
  Finder: "访达",
  "System Settings": "系统设置",
  Messages: "信息",
  Music: "音乐",
  Podcasts: "播客",
  Screenshot: "截屏",
  FaceTime: "FaceTime通话",
};

// Legal pages — only spelling-sensitive strings vary by locale
const legalBase = {
  licenceHeading: "Licence",
  privacyConfigStores: "stores your tile settings, app lists, and customisations",
} as const;

const legalUS = {
  ...legalBase,
  licenceHeading: "License",
  privacyConfigStores: "stores your tile settings, app lists, and customizations",
} as const;

// UK/AU → US spelling for copy rendered from shared data (e.g. release notes),
// where duplicating the whole dataset per locale isn't worth it. Curated word
// map only — word-boundary matched, preserves a leading capital.
const usSpellings: Record<string, string> = {
  behaviour: "behavior",
  behaviours: "behaviors",
  centre: "center",
  centred: "centered",
  colour: "color",
  coloured: "colored",
  colours: "colors",
  customisation: "customization",
  customisations: "customizations",
  customise: "customize",
  customised: "customized",
  customiser: "customizer",
  customising: "customizing",
  favourite: "favorite",
  favourites: "favorites",
  grey: "gray",
  licence: "license",
  licences: "licenses",
  maximise: "maximize",
  maximised: "maximized",
  minimise: "minimize",
  minimised: "minimized",
  optimise: "optimize",
  optimised: "optimized",
  organise: "organize",
  organised: "organized",
  organising: "organizing",
  personalise: "personalize",
  personalised: "personalized",
  recognise: "recognize",
  recognised: "recognized",
  stabilise: "stabilize",
  stabilised: "stabilized",
  synchronise: "synchronize",
  synchronised: "synchronized",
};

const ukSpellingPattern = new RegExp(
  `\\b(${Object.keys(usSpellings).join("|")})\\b`,
  "gi"
);

export function localiseText(text: string, locale: Locale): string {
  if (locale !== "en-US") return text;
  return text.replace(ukSpellingPattern, (match) => {
    const us = usSpellings[match.toLowerCase()];
    if (!us) return match;
    return match[0] === match[0].toUpperCase()
      ? us[0].toUpperCase() + us.slice(1)
      : us;
  });
}

// Content that differs between locales
export const localisedContent = {
  "en-AU": {
    marketing: marketingBase,
    legal: legalBase,
    names: noNames,
    // Hero
    downloadButton: "Download for macOS",

    // FAQ
    faq: [
      {
        slug: "what-macos-version-do-i-need",
        question: "What macOS version do I need?",
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically.",
      },
      {
        slug: "is-it-available-on-the-app-store",
        question: "Is it available on the App Store?",
        answer:
          "No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do.",
      },
      {
        slug: "is-dock-tile-free",
        question: "Is Dock Tile free?",
        answer:
          "Yes. It's free and open source under the MIT licence, with no account, ads or in-app purchases.",
      },
      {
        slug: "what-does-dock-tile-change-on-my-mac",
        question: "What does Dock Tile change on my Mac?",
        answer:
          "It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these.",
      },
      {
        slug: "how-do-i-group-apps-into-folders-in-the-mac-dock",
        question: "How do I group apps into folders in the Mac Dock?",
        answer:
          "macOS can't put apps in a folder in the Dock the way an iPhone can. Dock Tile adds that: click + and pick a suggested tile or Create New Tile, add the apps (and folders) that belong together, choose an icon, then click Add. The tile sits in your Dock like any app, and clicking it pops its apps up in a grid or a list. Make as many tiles as you need.",
      },
      {
        slug: "how-is-a-tile-different-from-a-folder-in-the-dock",
        question: "How is a tile different from a folder in the Dock?",
        answer:
          "A folder in the Dock (a stack) sits past the divider and shows the files inside a Finder folder; to hold apps, you'd fill that folder with aliases. A tile sits among your apps and is a small app of its own, with its own icon: a grid of its apps, a symbol or an emoji. It opens its apps in a panel anchored to it. On macOS 26 and later, tiles also follow the Light, Dark, Clear and Tinted icon styles.",
      },
      {
        slug: "how-do-i-stop-the-dock-moving-to-my-other-display",
        question: "How do I stop the Dock moving to my other display?",
        answer:
          "With more than one display, macOS moves the Dock to whichever screen you push the pointer against at the Dock's edge. Dock Lock, which comes with Dock Tile, keeps it on the display you choose: open Settings → Dock Lock, turn on Lock Dock to one display, allow Accessibility access when macOS asks, then pick a display under Keep Dock on. It remembers a display for each set of screens you use.",
      },
      {
        slug: "what-is-a-dock-tile-extension",
        question: "What is a Dock tile extension?",
        answer:
          "It's a macOS feature, not this app. Some apps include a Dock tile plug-in that keeps their Dock icon up to date, and macOS may tell you when one is added. You can see them, and switch them off, in System Settings → General → Login Items & Extensions. Dock Tile, the app on this site, doesn't install one: each of its tiles is a small app of its own.",
      },
      {
        slug: "how-do-i-create-a-new-tile",
        question: "How do I create a new tile?",
        answer:
          'Open Dock Tile, click + in the sidebar and choose a suggested tile or Create New Tile. Name it, add apps, pick its icon, then click Add to put it in your Dock.',
      },
      {
        slug: "can-i-change-a-tiles-icon-after-creating-it",
        question: "Can I change a tile's icon after creating it?",
        answer:
          "Yes. Select the tile and click its icon to open Customise Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look.",
      },
      {
        slug: "why-doesnt-right-click-show-a-context-menu",
        question: "Why doesn't right-click show a context menu?",
        answer:
          "By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one.",
      },
      {
        slug: "how-do-i-uninstall-a-tile",
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show in Dock, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        slug: "how-do-i-uninstall-dock-tile",
        question: "How do I uninstall Dock Tile?",
        answer:
          "Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Bin. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Bin, the tiles in your Dock keep working: drag them out, then delete that folder.",
      },
      {
        slug: "how-many-tiles-can-i-create",
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organise your apps and workflows.",
      },
      {
        slug: "can-i-add-folders-to-a-tile",
        question: "Can I add folders to a tile?",
        answer:
          "Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder.",
      },
      {
        slug: "do-tiles-sync-across-macs",
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        slug: "can-i-reorder-apps-within-a-tile",
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        slug: "whats-the-difference-between-grid-and-list-layout",
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        slug: "how-do-i-back-up-my-tiles",
        question: "How do I back up my tiles?",
        answer:
          "Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles.",
      },
    ],

    // Footer
    privacy: "Privacy",
    terms: "Terms",
  },

  "en-GB": {
    marketing: marketingBase,
    legal: legalBase,
    names: noNames,
    // Hero
    downloadButton: "Download for macOS",

    // FAQ
    faq: [
      {
        slug: "what-macos-version-do-i-need",
        question: "What macOS version do I need?",
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically.",
      },
      {
        slug: "is-it-available-on-the-app-store",
        question: "Is it available on the App Store?",
        answer:
          "No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do.",
      },
      {
        slug: "is-dock-tile-free",
        question: "Is Dock Tile free?",
        answer:
          "Yes. It's free and open source under the MIT licence, with no account, ads or in-app purchases.",
      },
      {
        slug: "what-does-dock-tile-change-on-my-mac",
        question: "What does Dock Tile change on my Mac?",
        answer:
          "It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these.",
      },
      {
        slug: "how-do-i-group-apps-into-folders-in-the-mac-dock",
        question: "How do I group apps into folders in the Mac Dock?",
        answer:
          "macOS can't put apps in a folder in the Dock the way an iPhone can. Dock Tile adds that: click + and pick a suggested tile or Create New Tile, add the apps (and folders) that belong together, choose an icon, then click Add. The tile sits in your Dock like any app, and clicking it pops its apps up in a grid or a list. Make as many tiles as you need.",
      },
      {
        slug: "how-is-a-tile-different-from-a-folder-in-the-dock",
        question: "How is a tile different from a folder in the Dock?",
        answer:
          "A folder in the Dock (a stack) sits past the divider and shows the files inside a Finder folder; to hold apps, you'd fill that folder with aliases. A tile sits among your apps and is a small app of its own, with its own icon: a grid of its apps, a symbol or an emoji. It opens its apps in a panel anchored to it. On macOS 26 and later, tiles also follow the Light, Dark, Clear and Tinted icon styles.",
      },
      {
        slug: "how-do-i-stop-the-dock-moving-to-my-other-display",
        question: "How do I stop the Dock moving to my other display?",
        answer:
          "With more than one display, macOS moves the Dock to whichever screen you push the pointer against at the Dock's edge. Dock Lock, which comes with Dock Tile, keeps it on the display you choose: open Settings → Dock Lock, turn on Lock Dock to one display, allow Accessibility access when macOS asks, then pick a display under Keep Dock on. It remembers a display for each set of screens you use.",
      },
      {
        slug: "what-is-a-dock-tile-extension",
        question: "What is a Dock tile extension?",
        answer:
          "It's a macOS feature, not this app. Some apps include a Dock tile plug-in that keeps their Dock icon up to date, and macOS may tell you when one is added. You can see them, and switch them off, in System Settings → General → Login Items & Extensions. Dock Tile, the app on this site, doesn't install one: each of its tiles is a small app of its own.",
      },
      {
        slug: "how-do-i-create-a-new-tile",
        question: "How do I create a new tile?",
        answer:
          'Open Dock Tile, click + in the sidebar and choose a suggested tile or Create New Tile. Name it, add apps, pick its icon, then click Add to put it in your Dock.',
      },
      {
        slug: "can-i-change-a-tiles-icon-after-creating-it",
        question: "Can I change a tile's icon after creating it?",
        answer:
          "Yes. Select the tile and click its icon to open Customise Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look.",
      },
      {
        slug: "why-doesnt-right-click-show-a-context-menu",
        question: "Why doesn't right-click show a context menu?",
        answer:
          "By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one.",
      },
      {
        slug: "how-do-i-uninstall-a-tile",
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show in Dock, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        slug: "how-do-i-uninstall-dock-tile",
        question: "How do I uninstall Dock Tile?",
        answer:
          "Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Bin. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Bin, the tiles in your Dock keep working: drag them out, then delete that folder.",
      },
      {
        slug: "how-many-tiles-can-i-create",
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organise your apps and workflows.",
      },
      {
        slug: "can-i-add-folders-to-a-tile",
        question: "Can I add folders to a tile?",
        answer:
          "Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder.",
      },
      {
        slug: "do-tiles-sync-across-macs",
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        slug: "can-i-reorder-apps-within-a-tile",
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        slug: "whats-the-difference-between-grid-and-list-layout",
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        slug: "how-do-i-back-up-my-tiles",
        question: "How do I back up my tiles?",
        answer:
          "Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles.",
      },
    ],

    // Footer
    privacy: "Privacy",
    terms: "Terms",
  },

  "en-US": {
    marketing: marketingUS,
    legal: legalUS,
    names: noNames,
    // Hero
    downloadButton: "Download for macOS",

    // FAQ
    faq: [
      {
        slug: "what-macos-version-do-i-need",
        question: "What macOS version do I need?",
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically.",
      },
      {
        slug: "is-it-available-on-the-app-store",
        question: "Is it available on the App Store?",
        answer:
          "No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do.",
      },
      {
        slug: "is-dock-tile-free",
        question: "Is Dock Tile free?",
        answer:
          "Yes. It's free and open source under the MIT license, with no account, ads or in-app purchases.",
      },
      {
        slug: "what-does-dock-tile-change-on-my-mac",
        question: "What does Dock Tile change on my Mac?",
        answer:
          "It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these.",
      },
      {
        slug: "how-do-i-group-apps-into-folders-in-the-mac-dock",
        question: "How do I group apps into folders in the Mac Dock?",
        answer:
          "macOS can't put apps in a folder in the Dock the way an iPhone can. Dock Tile adds that: click + and pick a suggested tile or Create New Tile, add the apps (and folders) that belong together, choose an icon, then click Add. The tile sits in your Dock like any app, and clicking it pops its apps up in a grid or a list. Make as many tiles as you need.",
      },
      {
        slug: "how-is-a-tile-different-from-a-folder-in-the-dock",
        question: "How is a tile different from a folder in the Dock?",
        answer:
          "A folder in the Dock (a stack) sits past the divider and shows the files inside a Finder folder; to hold apps, you'd fill that folder with aliases. A tile sits among your apps and is a small app of its own, with its own icon: a grid of its apps, a symbol or an emoji. It opens its apps in a panel anchored to it. On macOS 26 and later, tiles also follow the Light, Dark, Clear and Tinted icon styles.",
      },
      {
        slug: "how-do-i-stop-the-dock-moving-to-my-other-display",
        question: "How do I stop the Dock moving to my other display?",
        answer:
          "With more than one display, macOS moves the Dock to whichever screen you push the pointer against at the Dock's edge. Dock Lock, which comes with Dock Tile, keeps it on the display you choose: open Settings → Dock Lock, turn on Lock Dock to one display, allow Accessibility access when macOS asks, then pick a display under Keep Dock on. It remembers a display for each set of screens you use.",
      },
      {
        slug: "what-is-a-dock-tile-extension",
        question: "What is a Dock tile extension?",
        answer:
          "It's a macOS feature, not this app. Some apps include a Dock tile plug-in that keeps their Dock icon up to date, and macOS may tell you when one is added. You can see them, and switch them off, in System Settings → General → Login Items & Extensions. Dock Tile, the app on this site, doesn't install one: each of its tiles is a small app of its own.",
      },
      {
        slug: "how-do-i-create-a-new-tile",
        question: "How do I create a new tile?",
        answer:
          'Open Dock Tile, click + in the sidebar and choose a suggested tile or Create New Tile. Name it, add apps, pick its icon, then click Add to put it in your Dock.',
      },
      {
        slug: "can-i-change-a-tiles-icon-after-creating-it",
        question: "Can I change a tile's icon after creating it?",
        answer:
          "Yes. Select the tile and click its icon to open Customize Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look.",
      },
      {
        slug: "why-doesnt-right-click-show-a-context-menu",
        question: "Why doesn't right-click show a context menu?",
        answer:
          "By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one.",
      },
      {
        slug: "how-do-i-uninstall-a-tile",
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show in Dock, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        slug: "how-do-i-uninstall-dock-tile",
        question: "How do I uninstall Dock Tile?",
        answer:
          "Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Trash. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Trash, the tiles in your Dock keep working: drag them out, then delete that folder.",
      },
      {
        slug: "how-many-tiles-can-i-create",
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organize your apps and workflows.",
      },
      {
        slug: "can-i-add-folders-to-a-tile",
        question: "Can I add folders to a tile?",
        answer:
          "Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder.",
      },
      {
        slug: "do-tiles-sync-across-macs",
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        slug: "can-i-reorder-apps-within-a-tile",
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        slug: "whats-the-difference-between-grid-and-list-layout",
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        slug: "how-do-i-back-up-my-tiles",
        question: "How do I back up my tiles?",
        answer:
          "Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles.",
      },
    ],

    // Footer
    privacy: "Privacy",
    terms: "Terms",
  },

  // Served only under /zh-Hans (the route sets it; detectLocale never returns it).
  // Legal pages stay English, so `legal` is the English one.
  "zh-Hans": {
    marketing: marketingZh,
    legal: legalBase,
    names: namesZh,
    downloadButton: "下载macOS版",

    faq: [
      {
        slug: "what-macos-version-do-i-need",
        question: "需要什么版本的macOS？",
        answer: "Dock Tile可在macOS 15（Sequoia）及更高版本上运行，适用于任何搭载Apple芯片（M1或更新）的Mac，不支持Intel芯片的Mac。在macOS 26（Tahoe）及更高版本上，磁贴图标会自动跟随你的“图标和小组件样式”（默认、深色、透明或着色）。",
      },
      {
        slug: "is-it-available-on-the-app-store",
        question: "可以在App Store下载吗？",
        answer:
          "不可以，它需要直接下载。Dock Tile会为每个磁贴构建一个小App并修改你的程序坞，而App Store中的App不允许这样做。",
      },
      {
        slug: "is-dock-tile-free",
        question: "Dock Tile免费吗？",
        answer:
          "是的。它免费且开源，采用MIT许可证，没有账户、广告或App内购买项目。",
      },
      {
        slug: "what-does-dock-tile-change-on-my-mac",
        question: "Dock Tile会对我的Mac做哪些更改？",
        answer:
          "它会为每个磁贴构建一个小App，修改你的程序坞并重新启动程序坞以应用更改（第一次会先询问你），还会在登录时启动你的磁贴，除非你关闭此功能。只有在你打开“程序坞锁定”时，它才会请求无障碍访问权限。隐私政策（英文）对每一项都有说明。",
      },
      {
        slug: "how-do-i-group-apps-into-folders-in-the-mac-dock",
        question: "如何在Mac的程序坞中将App分组放进文件夹？",
        answer:
          "macOS不能像iPhone那样把App放进程序坞中的文件夹。Dock Tile补上了这一点：点按+，选择一个推荐的磁贴或“新建磁贴”，添加属于同一组的App（以及文件夹），选择一个图标，然后点按“添加”。磁贴会像任何App一样待在程序坞中，点按它，它的App就会以网格或列表的形式弹出。需要多少磁贴就创建多少。",
      },
      {
        slug: "how-is-a-tile-different-from-a-folder-in-the-dock",
        question: "磁贴和程序坞中的文件夹有什么不同？",
        answer:
          "程序坞中的文件夹（叠放）位于分隔线之后，显示访达文件夹中的文件；要用它放App，你得在那个文件夹里放满替身。磁贴则和你的App放在一起，本身就是一个小App，有自己的图标：由它的App组成的网格、一个符号或一个表情符号。它会在锚定于自身的面板中打开它的App。在macOS 26及更高版本上，磁贴还会跟随浅色、深色、透明和着色图标样式。",
      },
      {
        slug: "how-do-i-stop-the-dock-moving-to-my-other-display",
        question: "如何阻止程序坞跑到另一台显示器上？",
        answer:
          "连接多台显示器时，你在哪块屏幕上把指针推向程序坞所在的边缘，macOS就会把程序坞移到那块屏幕上。Dock Tile附带的“程序坞锁定”可以让它停留在你选择的显示器上：打开“设置”→“程序坞锁定”，打开“将程序坞锁定到一台显示器”，在macOS询问时允许无障碍访问，然后在“将程序坞固定在”下选择一台显示器。它会为你使用的每组屏幕记住一台显示器。",
      },
      {
        slug: "what-is-a-dock-tile-extension",
        question: "什么是“Dock tile”扩展？",
        answer:
          "这是macOS的一项功能，而不是本App。有些App带有Dock tile插件，用来让它们的程序坞图标保持最新，添加插件时macOS可能会通知你。你可以在“系统设置”→“通用”→“登录项与扩展”中查看并关闭它们。本网站介绍的Dock Tile不会安装这种插件：它的每个磁贴都是一个独立的小App。",
      },
      {
        slug: "how-do-i-create-a-new-tile",
        question: "如何创建新磁贴？",
        answer:
          "打开Dock Tile，点按边栏中的+，然后选择一个推荐的磁贴或“新建磁贴”。为它命名、添加App、选择图标，然后点按“添加”将它放进程序坞。",
      },
      {
        slug: "can-i-change-a-tiles-icon-after-creating-it",
        question: "创建磁贴后还能更改它的图标吗？",
        answer:
          "可以。选择该磁贴，然后点按它的图标打开“自定义磁贴”。可以将磁贴自己的App显示为网格，也可以选择一个符号或表情符号及其背景。如果磁贴已经在程序坞中，点按“更新”以应用新外观。",
      },
      {
        slug: "why-doesnt-right-click-show-a-context-menu",
        question: "为什么右键点按不显示快捷菜单？",
        answer:
          "默认情况下，磁贴以Ghost mode（幽灵模式，不出现在Command-Tab中）运行，这种模式不支持快捷菜单。为该磁贴打开“在App切换器中显示”即可使用快捷菜单。",
      },
      {
        slug: "how-do-i-uninstall-a-tile",
        question: "如何卸载一个磁贴？",
        answer:
          "选择该磁贴，关闭“在程序坞中显示”，然后点按“移除”。磁贴仍会保留在Dock Tile中，供以后使用。要永久删除它，请点按废纸篓按钮。你也可以像拖移任何App一样，把磁贴拖出程序坞。",
      },
      {
        slug: "how-do-i-uninstall-dock-tile",
        question: "如何卸载Dock Tile？",
        answer:
          "打开Dock Tile，用废纸篓按钮删除每个磁贴，这也会把它从程序坞中移除。在“设置”→“通用”中关闭“登录时启动磁贴”，退出Dock Tile，然后将它移到废纸篓。若要彻底清除，还要删除~/Library/Application Support/DockTile/以及~/Library/Preferences/中以com.docktile开头的文件。如果你只把App移到废纸篓，程序坞中的磁贴仍可继续使用：把它们拖出程序坞，然后删除那个文件夹。",
      },
      {
        slug: "how-many-tiles-can-i-create",
        question: "可以创建多少个磁贴？",
        answer:
          "没有硬性限制。你可以根据整理App和工作流程的需要，创建任意数量的磁贴。",
      },
      {
        slug: "can-i-add-folders-to-a-tile",
        question: "可以在磁贴中添加文件夹吗？",
        answer:
          "可以。向磁贴添加项目时，除了App，你还可以选择文件夹。点按文件夹，它就会在访达中打开。",
      },
      {
        slug: "do-tiles-sync-across-macs",
        question: "磁贴会在多台Mac之间同步吗？",
        answer:
          "目前不会。磁贴配置存储在每台Mac本地。我们可能会在将来的更新中加入iCloud同步。",
      },
      {
        slug: "can-i-reorder-apps-within-a-tile",
        question: "可以调整磁贴中App的顺序吗？",
        answer:
          "可以。在磁贴的“此磁贴中的项目”列表中，将App拖到新位置。这就是磁贴在程序坞中打开的那个面板，所以你看到的顺序就是最终的顺序。如果磁贴已经在程序坞中，点按“更新”以应用更改。",
      },
      {
        slug: "whats-the-difference-between-grid-and-list-layout",
        question: "“网格”和“列表”布局有什么区别？",
        answer:
          "网格布局以网格形式显示App图标（类似iOS文件夹）。列表布局以竖向菜单显示App及其名称，类似程序坞的文件夹视图。",
      },
      {
        slug: "how-do-i-back-up-my-tiles",
        question: "如何备份我的磁贴？",
        answer:
          "你的磁贴配置存储在~/Library/Preferences/com.docktile.configs.json中。备份此文件即可保留你的磁贴。",
      },
    ],

    // Footer (the pages they link to stay English)
    privacy: "隐私",
    terms: "条款",
  },
} as const;

// The Chinese pages' <title>, meta description and JSON-LD description. Their English
// counterparts are siteConfig (title, description), app/faq/page.tsx and app/dock-lock/page.tsx.
export const zhPageMeta = {
  homeTitle: "Dock Tile - 为Mac程序坞带来iOS风格的App文件夹",
  homeDescription:
    "将一组App放进一个程序坞图标。点一下，它们就会弹出来，就像iPhone上的文件夹。免费且开源，适用于macOS 15及更高版本，需搭载Apple芯片。",
  faqTitle: "常见问题 - Dock Tile",
  faqDescription:
    "Dock Tile常见问题解答：macOS版本要求、创建和自定义磁贴、Ghost mode、备份，以及网格与列表布局。",
  dockLockTitle: "让Mac程序坞不再跳到另一台显示器上",
  dockLockDescription:
    "在连接了多台显示器的Mac上，程序坞会跳到你用指针推向的那个屏幕。“程序坞锁定”随免费的Dock Tile附带，会让程序坞停留在你选择的显示器上。",
} as const;

// Helper to get content for a locale with fallback to AU
export function getContent(locale: Locale = defaultLocale) {
  return localisedContent[locale] || localisedContent[defaultLocale];
}

// Detect locale from browser (client-side only)
export function detectLocale(): Locale {
  if (typeof window === "undefined") {
    return defaultLocale;
  }

  const browserLocale = navigator.language;

  if (browserLocale.startsWith("en-US")) {
    return "en-US";
  }
  if (browserLocale.startsWith("en-GB")) {
    return "en-GB";
  }
  // Default to AU for all other English variants
  return "en-AU";
}
