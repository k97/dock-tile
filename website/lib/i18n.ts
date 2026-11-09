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
    "iOS-style folders for the Mac. Group apps into beautiful tiles and launch anything in one click.",
  tryIt: "Try it — click a tile",
  tilesTitleA: "Pick your apps. Pick a look.", // nbsp: break after "apps.", never strand "Pick"
  tilesTitleB: "Done.",
  tilesBody:
    "Arrange them right in the popover your tile opens, so what you see is what you get. Then show the tile as a grid of its apps, or give it a symbol or an emoji, in colour or mono.",
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
  smartAddTitle: "Tiles that build themselves.",
  smartAddBody:
    "Click +, and Dock Tile groups the apps you use most into ready-made tiles. Pick one and it opens ready to tweak; nothing reaches your Dock until you add it.",
  smartAddPrivacy: "Learned on your Mac. Never leaves your device.",
  ghostTitle: "Ghost mode.",
  ghostBody:
    "Tiles stay out of Cmd-Tab and the App Switcher by default — in the Dock when you need them, invisible when you don't.",
  ghostTip: "Per-tile control. Surface any tile on demand.",
  dockLockTitle: "The Dock stays put.",
  dockLockBody:
    "Stop the Dock from jumping between screens on multi-display setups. Choose a display for each set of screens you use, and the Dock stays on it.",
  dockLockTip: "Remembers your pick for every display setup.",
  bentoTitleA: "Built for the",
  bentoTitleB: "power user.",
  // "Hidden in plain sight" — the features nobody finds until they look
  detailsTitleA: "More than",
  detailsTitleB: "a tile in your Dock.", // nbsp: never strand "a" at a line end
  customPill: "Style",
  customTitle: "Make every tile yours.",
  customLead: "Try it here.",
  customBody:
    "Show a grid of the tile's own apps, or a symbol or an emoji, in full colour or Mono. Your Dock picks up the new look when you press Update.",
  customColour: "Colour", // the mock inspector's row label
  menuBarPill: "Menu bar",
  menuBarTitle: "Your tiles, in the menu bar.",
  menuBarLead: "On from the first launch.",
  menuBarBody:
    "The tiles in your Dock and their apps, listed in the menu bar, ready even when the Dock is hidden. Turn it off in Settings any time.",
  // The row of small features: a plain name, then one calm sentence.
  details: [
    { lead: "Keyboard friendly", body: "Arrow keys move through a popover. Return opens, Esc closes." },
    { lead: "Folders too", body: "Add a folder beside your apps and open it in one click." },
    { lead: "Grid or list", body: "An icon grid or a compact list, sized your way in Settings." },
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
  ctaMetaOpenSource: "Open source",
  ctaMetaAppleSilicon: "Apple silicon",
  // Closing band + closing Dock (the homepage's ending)
  closingTitle: "All your apps. One tile.",
  closingGithubTip: "Source on GitHub",
  closingGithubLabel: "GitHub",
  closingWhatsNewTip: "What's new in", // the component appends the version
  closingWhatsNewLabel: "What's new",
  closingContactTip: "Get in touch",
  closingContactLabel: "Contact",
  closingStudioLabel: "Studio",
  studioHere: "You're here",
  studioEarlyAccess: "Early access",
  opensInNewTab: "(opens in a new tab)",
} as const;

const marketingUS = {
  ...marketingBase,
  tilesBody:
    "Arrange them right in the popover your tile opens, so what you see is what you get. Then show the tile as a grid of its apps, or give it a symbol or an emoji, in color or mono.",
  tilesAlt: "Dock Tile editing a tile: its popover in the middle, Customize Tile on the right.",
  tilesSpotBackgroundBody: "Color fills the tile. Mono keeps it white in Light Mode and black in Dark Mode.",
  customBody:
    "Show a grid of the tile's own apps, or a symbol or an emoji, in full color or Mono. Your Dock picks up the new look when you press Update.",
  customColour: "Color",
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
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons are drawn by the system's Liquid Glass icon pipeline and follow its Icon and widget style automatically.",
      },
      {
        question: "Is it available on the App Store?",
        answer:
          "No, Dock Tile is distributed as a direct download. The app creates helper bundles that require permissions not allowed in sandboxed App Store apps.",
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
          'By default, tiles run in "Ghost Mode" (hidden from Cmd+Tab) which doesn\'t support context menus. Enable "Show in App Switcher" in the tile settings to get the context menu.',
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show Tile, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organise your apps and workflows.",
      },
      {
        question: "Can I add folders to a tile?",
        answer:
          "Yes! When adding items to a tile, you can select folders as well as applications. They'll open in Finder when clicked.",
      },
      {
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In In This Tile, drag an app to a new spot. It's the same popover your tile opens, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        question: "How do I backup my tiles?",
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
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons are drawn by the system's Liquid Glass icon pipeline and follow its Icon and widget style automatically.",
      },
      {
        question: "Is it available on the App Store?",
        answer:
          "No, Dock Tile is distributed as a direct download. The app creates helper bundles that require permissions not allowed in sandboxed App Store apps.",
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
          'By default, tiles run in "Ghost Mode" (hidden from Cmd+Tab) which doesn\'t support context menus. Enable "Show in App Switcher" in the tile settings to get the context menu.',
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show Tile, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organise your apps and workflows.",
      },
      {
        question: "Can I add folders to a tile?",
        answer:
          "Yes! When adding items to a tile, you can select folders as well as applications. They'll open in Finder when clicked.",
      },
      {
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In In This Tile, drag an app to a new spot. It's the same popover your tile opens, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        question: "How do I backup my tiles?",
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
        answer: "Dock Tile runs on macOS 15 (Sequoia) and later, on any Mac with Apple silicon (M1 or newer). Intel Macs aren't supported. On macOS 26 (Tahoe) and later, tile icons are drawn by the system's Liquid Glass icon pipeline and follow its Icon and widget style automatically.",
      },
      {
        question: "Is it available on the App Store?",
        answer:
          "No, Dock Tile is distributed as a direct download. The app creates helper bundles that require permissions not allowed in sandboxed App Store apps.",
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
          'By default, tiles run in "Ghost Mode" (hidden from Cmd+Tab) which doesn\'t support context menus. Enable "Show in App Switcher" in the tile settings to get the context menu.',
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          "Select the tile, turn off Show Tile, then click Remove from Dock. The tile stays in Dock Tile for later. To delete it for good, click the trash button. You can also drag the tile out of the Dock like any app.",
      },
      {
        question: "How many tiles can I create?",
        answer:
          "There's no hard limit. You can create as many tiles as you need to organize your apps and workflows.",
      },
      {
        question: "Can I add folders to a tile?",
        answer:
          "Yes! When adding items to a tile, you can select folders as well as applications. They'll open in Finder when clicked.",
      },
      {
        question: "Do tiles sync across Macs?",
        answer:
          "Not currently. Tile configurations are stored locally on each Mac. We may add iCloud sync in a future update.",
      },
      {
        question: "Can I reorder apps within a tile?",
        answer:
          "Yes. In In This Tile, drag an app to a new spot. It's the same popover your tile opens, so the order you see is the order you get. If the tile is already in your Dock, click Update to apply it.",
      },
      {
        question: "What's the difference between Grid and List layout?",
        answer:
          "Grid layout shows apps as icons in a grid (like iOS folders). List layout shows apps in a vertical menu with names, similar to the Dock's folder view.",
      },
      {
        question: "How do I backup my tiles?",
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
