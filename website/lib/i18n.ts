// Localisation for US, UK, AU English
// Default fallback: AU English

export type Locale = "en-AU" | "en-GB" | "en-US";

export const defaultLocale: Locale = "en-AU";

// Generate URL-safe slug from question text
export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/['']/g, "") // Remove apostrophes
    .replace(/[^a-z0-9\s-]/g, "") // Remove special characters except spaces and hyphens
    .replace(/\s+/g, "-") // Replace spaces with hyphens
    .replace(/-+/g, "-") // Replace multiple hyphens with single
    .replace(/^-|-$/g, ""); // Remove leading/trailing hyphens
}

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
  // What Dock Tile is (first section after the hero), split around the heading's tile
  introTitleA: "Less Dock.",
  introTitleB: "More multitasking.",
  introBefore: "Before",
  introAfter: "With Dock Tile",
  introPoints: [
    { lead: "One tile, many apps", body: "Group apps and folders behind a single Dock icon. Click it and they pop up, ready to open." },
    { lead: "Looks like it belongs", body: "Each tile is a real Mac app with its own icon, so it sits and magnifies like everything else in your Dock." },
    { lead: "Ready in a minute", body: "Pick a suggested tile or start blank, add your apps, then press Add to Dock." },
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
  dockLockBody:
    "It's a separate tool for Macs with more than one display that stops the Dock jumping between screens. Choose a display for each set of screens you use, and the Dock stays on it. Turn it on in Settings\u00A0›\u00A0Dock\u00A0Lock.",
  dockLockTip: "Remembers a display for each desk you work at.",
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
  // Feature vote banner (a raised hand for the next idea; lib/votes.ts counts every tap)
  voteTitle: "Widgets in your tiles?",
  voteBody:
    "A world clock, your calendar or the weather, the moment a tile pops up, without digging through windows. Raise your hand if you want it: the more hands, the sooner we build it.",
  voteThanks: "Counted! Want it more? Raise your hand again.",
  voteButton: "I want widgets in my tiles",
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
} as const;

const marketingUS = {
  ...marketingBase,
  tilesBody:
    "Set up every tile in the Dock Tile companion app. You arrange its apps in the same panel that pops up from the Dock, so what you see is what you get. Then pick its icon: a grid of its own apps, a symbol or an emoji, on color or a plain background.",
  tilesAlt: "Dock Tile editing a tile: its popover in the middle, Customize Tile on the right.",
  tilesSpotBackgroundBody: "Color fills the tile. Mono keeps it white in Light Mode and black in Dark Mode.",
} as const;

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
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 15 or later on a Mac with Apple silicon",

    // Features
    featuresTitle: "Made for your Dock",
    featuresSubtitle: "Native, fast, and out of your way.",
    features: [
      {
        title: "One click to everything",
        description:
          "Tuck a group of apps and folders behind a single Dock tile, then open them all with one click.",
      },
      {
        title: "Dock Lock",
        description:
          "Pin the Dock to one display so it stops hopping between screens on a multi-monitor setup.",
      },
      {
        title: "Custom tile icons",
        description:
          "Show a grid of the tile's own apps, or an SF Symbol or emoji on a colour or mono background. On macOS Tahoe and later, tiles follow the Light, Dark, Clear and Tinted icon styles.",
      },
    ],

    // FAQ
    faq: [
      {
        question: "What macOS version do I need?",
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically.",
      },
      {
        question: "Is it available on the App Store?",
        answer:
          "No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do.",
      },
      {
        question: "Is Dock Tile free?",
        answer:
          "Yes. It's free and open source under the MIT licence, with no account, ads or in-app purchases.",
      },
      {
        question: "What does Dock Tile change on my Mac?",
        answer:
          "It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these.",
      },
      {
        question: "How do I create a new tile?",
        answer:
          'Open Dock Tile, click the "+" button in the sidebar, customise your tile\'s icon and name, add apps, then click "Add to Dock".',
      },
      {
        question: "Can I change a tile's icon after creating it?",
        answer:
          "Yes. Select the tile and click its icon to open Customise Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look.",
      },
      {
        question: "Why doesn't right-click show a context menu?",
        answer:
          "By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one.",
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show Tile, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        question: "How do I uninstall Dock Tile?",
        answer:
          "Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Bin. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Bin, the tiles in your Dock keep working: drag them out, then delete that folder.",
      },
      {
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organise your apps and workflows.",
      },
      {
        question: "Can I add folders to a tile?",
        answer:
          "Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder.",
      },
      {
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        question: "How do I back up my tiles?",
        answer:
          "Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles.",
      },
    ],

    // Support
    supportTitle: "Support",
    supportText: "Have a question or found a bug?",
    supportLink: "Get in touch",

    // Footer
    privacy: "Privacy",
    terms: "Terms",
  },

  "en-GB": {
    marketing: marketingBase,
    legal: legalBase,
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 15 or later on a Mac with Apple silicon",

    // Features
    featuresTitle: "Made for your Dock",
    featuresSubtitle: "Native, fast, and out of your way.",
    features: [
      {
        title: "One click to everything",
        description:
          "Tuck a group of apps and folders behind a single Dock tile, then open them all with one click.",
      },
      {
        title: "Dock Lock",
        description:
          "Pin the Dock to one display so it stops hopping between screens on a multi-monitor setup.",
      },
      {
        title: "Custom tile icons",
        description:
          "Show a grid of the tile's own apps, or an SF Symbol or emoji on a colour or mono background. On macOS Tahoe and later, tiles follow the Light, Dark, Clear and Tinted icon styles.",
      },
    ],

    // FAQ
    faq: [
      {
        question: "What macOS version do I need?",
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically.",
      },
      {
        question: "Is it available on the App Store?",
        answer:
          "No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do.",
      },
      {
        question: "Is Dock Tile free?",
        answer:
          "Yes. It's free and open source under the MIT licence, with no account, ads or in-app purchases.",
      },
      {
        question: "What does Dock Tile change on my Mac?",
        answer:
          "It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these.",
      },
      {
        question: "How do I create a new tile?",
        answer:
          'Open Dock Tile, click the "+" button in the sidebar, customise your tile\'s icon and name, add apps, then click "Add to Dock".',
      },
      {
        question: "Can I change a tile's icon after creating it?",
        answer:
          "Yes. Select the tile and click its icon to open Customise Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look.",
      },
      {
        question: "Why doesn't right-click show a context menu?",
        answer:
          "By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one.",
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show Tile, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        question: "How do I uninstall Dock Tile?",
        answer:
          "Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Bin. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Bin, the tiles in your Dock keep working: drag them out, then delete that folder.",
      },
      {
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organise your apps and workflows.",
      },
      {
        question: "Can I add folders to a tile?",
        answer:
          "Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder.",
      },
      {
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        question: "How do I back up my tiles?",
        answer:
          "Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles.",
      },
    ],

    // Support
    supportTitle: "Support",
    supportText: "Have a question or found a bug?",
    supportLink: "Get in touch",

    // Footer
    privacy: "Privacy",
    terms: "Terms",
  },

  "en-US": {
    marketing: marketingUS,
    legal: legalUS,
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 15 or later on a Mac with Apple silicon",

    // Features
    featuresTitle: "Made for your Dock",
    featuresSubtitle: "Native, fast, and out of your way.",
    features: [
      {
        title: "One click to everything",
        description:
          "Tuck a group of apps and folders behind a single Dock tile, then open them all with one click.",
      },
      {
        title: "Dock Lock",
        description:
          "Pin the Dock to one display so it stops hopping between screens on a multi-monitor setup.",
      },
      {
        title: "Custom tile icons",
        description:
          "Show a grid of the tile's own apps, or an SF Symbol or emoji on a color or mono background. On macOS Tahoe and later, tiles follow the Light, Dark, Clear and Tinted icon styles.",
      },
    ],

    // FAQ
    faq: [
      {
        question: "What macOS version do I need?",
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons follow your Icon and widget style (Default, Dark, Clear or Tinted) automatically.",
      },
      {
        question: "Is it available on the App Store?",
        answer:
          "No, it's a direct download. Dock Tile builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do.",
      },
      {
        question: "Is Dock Tile free?",
        answer:
          "Yes. It's free and open source under the MIT license, with no account, ads or in-app purchases.",
      },
      {
        question: "What does Dock Tile change on my Mac?",
        answer:
          "It builds a small app for each tile, edits your Dock and restarts it to apply changes (it asks the first time), and starts your tiles at login unless you switch that off. Dock Lock asks for Accessibility access, only if you turn it on. The Privacy Policy covers each of these.",
      },
      {
        question: "How do I create a new tile?",
        answer:
          'Open Dock Tile, click the "+" button in the sidebar, customize your tile\'s icon and name, add apps, then click "Add to Dock".',
      },
      {
        question: "Can I change a tile's icon after creating it?",
        answer:
          "Yes. Select the tile and click its icon to open Customize Tile. Show the tile's own apps as a grid, or choose a symbol or an emoji and its background. If the tile is already in your Dock, click Update to apply the new look.",
      },
      {
        question: "Why doesn't right-click show a context menu?",
        answer:
          "By default, tiles run in Ghost mode (hidden from Command-Tab), which doesn't support context menus. Turn on Show in App Switcher for the tile to get one.",
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show Tile, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        question: "How do I uninstall Dock Tile?",
        answer:
          "Open Dock Tile and delete each tile with the trash button, which also takes it out of your Dock. Turn off Start tiles at login in Settings → General, quit Dock Tile, then move it to the Trash. For a clean slate, also delete ~/Library/Application Support/DockTile/ and the files starting with com.docktile in ~/Library/Preferences/. If you only move the app to the Trash, the tiles in your Dock keep working: drag them out, then delete that folder.",
      },
      {
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organize your apps and workflows.",
      },
      {
        question: "Can I add folders to a tile?",
        answer:
          "Yes. When you add items to a tile, you can pick folders as well as apps. Click one and it opens in Finder.",
      },
      {
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In the tile's In This Tile list, drag an app to a new spot. It's the same panel your tile opens from the Dock, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        question: "How do I back up my tiles?",
        answer:
          "Your tile configurations are stored in ~/Library/Preferences/com.docktile.configs.json. Back up this file to preserve your tiles.",
      },
    ],

    // Support
    supportTitle: "Support",
    supportText: "Have a question or found a bug?",
    supportLink: "Get in touch",

    // Footer
    privacy: "Privacy",
    terms: "Terms",
  },
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
