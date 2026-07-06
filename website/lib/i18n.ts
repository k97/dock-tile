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
  heroEyebrow: "For macOS 26+",
  heroHeadlineA: "Group your apps.",
  heroHeadlineB: "Declutter your Dock.",
  heroSub:
    "iOS-style folders for the Mac. Group apps into beautiful tiles and launch anything in one click.",
  tryIt: "Try it — click a tile",
  tilesEyebrow: "Features / 01",
  tilesTitle: "Customised tiles with the simple editor.",
  tilesBody:
    "Give every group of apps a face you'll spot at a glance. Pick a colour, then a custom SF Symbol from Apple's library or any emoji — and fine-tune its size and weight — all in one simple editor.",
  tilesCaption: "Colour, symbols, emoji, size & weight",
  popoverEyebrow: "Features / 02",
  popoverTitle: "Grid or list. Sized your way.",
  popoverBody:
    "Each tile opens a native popover — an icon grid like an iOS folder, or a compact list. Appearance controls tune size, spacing and labels for every tile at once, and running tiles pick the change up immediately.",
  powerUserEyebrow: "Power user",
  smartAddTitle: "Tiles that build themselves.",
  smartAddBody:
    "Click +, and Dock Tile groups your recent apps into ready-made tiles to pick from — suggestions come from what you actually use.",
  smartAddPrivacy: "Learned on your Mac. Never leaves your device.",
  ghostTitle: "Ghost mode.",
  ghostBody:
    "Tiles stay out of Cmd-Tab and the App Switcher by default — in the Dock when you need them, invisible when you don't.",
  dockLockEyebrow: "Features / 02",
  dockLockTitle: "The Dock stays put.",
  dockLockBody:
    "Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose — always.",
  bentoTitle: "Built for the power user.",
  ctaTitle: "Get organised today.",
  ctaButton: "Download Dock Tile",
  ctaMetaFree: "Free download",
} as const;

const marketingUS = {
  ...marketingBase,
  ctaTitle: "Get organized today.",
  tilesTitle: "Customized tiles with the simple editor.",
  tilesBody:
    "Give every group of apps a face you'll spot at a glance. Pick a color, then a custom SF Symbol from Apple's library or any emoji — and fine-tune its size and weight — all in one simple editor.",
  tilesCaption: "Color, symbols, emoji, size & weight",
} as const;

// Content that differs between locales
export const localisedContent = {
  "en-AU": {
    marketing: marketingBase,
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 26 or later",

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
          "Design each tile with colour gradients, SF Symbols or emoji. Four icon styles follow Light, Dark, Clear and Tinted appearance.",
      },
    ],

    // FAQ
    faq: [
      {
        question: "What macOS version do I need?",
        answer: "Dock Tile requires macOS 26 (Tahoe) or later.",
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
          'Yes! Select the tile in Dock Tile, click "Customise", and choose a new colour, symbol, or emoji. The change applies immediately.',
      },
      {
        question: "Why doesn't right-click show a context menu?",
        answer:
          'By default, tiles run in "Ghost Mode" (hidden from Cmd+Tab) which doesn\'t support context menus. Enable "Show in App Switcher" in the tile settings to get the context menu.',
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          'Select the tile in Dock Tile, scroll down to "Remove from Dock", and click Remove. You can also drag the tile out of the Dock like any app.',
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
          "Yes! In the tile editor, drag the grip handle on each app row to reorder them. The order is reflected in the popover.",
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
    footerMessage: "Designed & made with care for macOS",
    privacy: "Privacy",
    terms: "Terms",
  },

  "en-GB": {
    marketing: marketingBase,
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 26 or later",

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
          "Design each tile with colour gradients, SF Symbols or emoji. Four icon styles follow Light, Dark, Clear and Tinted appearance.",
      },
    ],

    // FAQ
    faq: [
      {
        question: "What macOS version do I need?",
        answer: "Dock Tile requires macOS 26 (Tahoe) or later.",
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
          'Yes! Select the tile in Dock Tile, click "Customise", and choose a new colour, symbol, or emoji. The change applies immediately.',
      },
      {
        question: "Why doesn't right-click show a context menu?",
        answer:
          'By default, tiles run in "Ghost Mode" (hidden from Cmd+Tab) which doesn\'t support context menus. Enable "Show in App Switcher" in the tile settings to get the context menu.',
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          'Select the tile in Dock Tile, scroll down to "Remove from Dock", and click Remove. You can also drag the tile out of the Dock like any app.',
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
          "Yes! In the tile editor, drag the grip handle on each app row to reorder them. The order is reflected in the popover.",
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
    footerMessage: "Designed & made with care for macOS",
    privacy: "Privacy",
    terms: "Terms",
  },

  "en-US": {
    marketing: marketingUS,
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 26 or later",

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
          "Design each tile with color gradients, SF Symbols or emoji. Four icon styles follow Light, Dark, Clear and Tinted appearance.",
      },
    ],

    // FAQ
    faq: [
      {
        question: "What macOS version do I need?",
        answer: "Dock Tile requires macOS 26 (Tahoe) or later.",
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
          'Yes! Select the tile in Dock Tile, click "Customize", and choose a new color, symbol, or emoji. The change applies immediately.',
      },
      {
        question: "Why doesn't right-click show a context menu?",
        answer:
          'By default, tiles run in "Ghost Mode" (hidden from Cmd+Tab) which doesn\'t support context menus. Enable "Show in App Switcher" in the tile settings to get the context menu.',
      },
      {
        question: "How do I uninstall a tile?",
        answer:
          'Select the tile in Dock Tile, scroll down to "Remove from Dock", and click Remove. You can also drag the tile out of the Dock like any app.',
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
          "Yes! In the tile editor, drag the grip handle on each app row to reorder them. The order is reflected in the popover.",
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
    footerMessage: "Designed & made with care for macOS",
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
