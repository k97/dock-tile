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

// Content that differs between locales
export const localisedContent = {
  "en-AU": {
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 26 or later",

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
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 26 or later",

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
    // Hero
    tagline: "A native macOS launcher, built for the Dock",
    description:
      "Create custom app icons for your apps and folders, with one-click access. A smarter take on iOS Home Screen folders.",
    downloadButton: "Download for macOS",
    systemRequirements: "Requires macOS 26 or later",

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
