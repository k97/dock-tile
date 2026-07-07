/**
 * Full release history, newest first. Static data — the site never calls the
 * GitHub API. Curated from the git history between release tags; add a new
 * entry at the top of the array when a version ships.
 */

export type ReleaseGroup = {
  heading: string;
  items: string[];
};

export type Release = {
  version: string;
  date: string;
  intro: string;
  groups: ReleaseGroup[];
};

export const releases: Release[] = [
  {
    version: "1.8.4",
    date: "3 July 2026",
    intro: "Popover positioning fixes for magnified and auto-hidden Docks.",
    groups: [
      {
        heading: "Fixes",
        items: [
          "Tile popovers now clear magnified Dock icons instead of opening on top of them",
          "Popover anchoring reads the Dock's own preferences, so it lands correctly with auto-hidden Docks and Docks on any edge",
        ],
      },
    ],
  },
  {
    version: "1.8.3",
    date: "3 July 2026",
    intro: "Fixes tile icons rendering stale in the Dock after an update.",
    groups: [
      {
        heading: "Fixes",
        items: [
          "Updated tiles now refresh the Dock's icon cache, so new icon designs appear immediately instead of the Dock keeping the old render",
        ],
      },
    ],
  },
  {
    version: "1.8.2",
    date: "3 July 2026",
    intro: "Icon polish and self-healing tiles.",
    groups: [
      {
        heading: "Icons",
        items: [
          "Refined Dark icon style so deep tints stay visible, plus a subtle Liquid Glass sheen on tile glyphs",
        ],
      },
      {
        heading: "Reliability",
        items: [
          "Broken pinned tiles now repair themselves automatically on launch",
          "Tile migration retries until every tile succeeds instead of giving up after one attempt",
          "More reliable Dock reads right after login, so pinned tiles are never missed",
          "Two tiles with the same name no longer overwrite each other behind the scenes",
        ],
      },
    ],
  },
  {
    version: "1.8.1",
    date: "2 July 2026",
    intro: "Guards against running from Downloads.",
    groups: [
      {
        heading: "Reliability",
        items: [
          "Detects when macOS runs the app from a read-only location (e.g. straight from Downloads) and offers to move it to Applications, so creating tiles can't silently fail",
        ],
      },
    ],
  },
  {
    version: "1.8.0",
    date: "2 July 2026",
    intro: "Liquid Glass depth for tile icons.",
    groups: [
      {
        heading: "Icons",
        items: [
          "Tile icons pick up an emulated Liquid Glass treatment — surface sheen, glyph shading, contact shadow, and a specular highlight — in the Dock and in every in-app preview",
        ],
      },
      {
        heading: "Improvements",
        items: ["Tidier button labels in Software Update and Missing Apps settings"],
      },
    ],
  },
  {
    version: "1.7.2",
    date: "2 July 2026",
    intro: "New Tile flow fixes.",
    groups: [
      {
        heading: "Fixes",
        items: [
          "Repaired the New Tile flow and empty state, so deleting your last tile never strands you in Settings or leaves + disabled",
        ],
      },
      {
        heading: "Under the Hood",
        items: ["Richer click and workflow tracing in development diagnostics"],
      },
    ],
  },
  {
    version: "1.7.1",
    date: "2 July 2026",
    intro: "No more needless Dock restarts.",
    groups: [
      {
        heading: "Fixes",
        items: [
          "The Dock only restarts when a tile action actually changes it — pressing Done or deleting a hidden tile no longer bounces the Dock",
        ],
      },
    ],
  },
  {
    version: "1.7.0",
    date: "2 July 2026",
    intro: "Smart Add — suggested tiles when you press +.",
    groups: [
      {
        heading: "Smart Add",
        items: [
          "Pressing + can now offer ready-made tiles built from your recently used apps — Browse, Watch, Ship, Chat, Work",
          "Everything is learned on your Mac and never leaves your device",
          "Picking a suggestion only pre-fills the tile; Add to Dock stays your explicit choice",
          "Turn it off anytime in Settings → General",
        ],
      },
    ],
  },
  {
    version: "1.6.0",
    date: "1 July 2026",
    intro: "Multi-select adding and web-app support.",
    groups: [
      {
        heading: "Improvements",
        items: [
          "Add picker now supports selecting multiple apps and folders at once",
          "Apps are identified by their on-disk location, so multiple installs of the same web app (e.g. two Outlook profiles) can live in tiles side by side",
        ],
      },
    ],
  },
  {
    version: "1.5.0",
    date: "30 June 2026",
    intro: "Popover Appearance settings.",
    groups: [
      {
        heading: "Popover Appearance",
        items: [
          "New Appearance pane in Settings → General: popover size, tile size, spacing, animation, hover highlight, and grid labels — with a live preview",
          "Grid and List layouts are configured independently",
          "Saving can apply the new look to tiles already in your Dock immediately",
        ],
      },
    ],
  },
  {
    version: "1.4.5",
    date: "28 June 2026",
    intro: "Missing-app scanning improvements.",
    groups: [
      {
        heading: "Improvements",
        items: [
          "Manual “Scan for Missing Apps” in Settings, with a review of affected tiles",
          "Apps uninstalled before upgrading are now flagged too, instead of keeping their old cached icon",
        ],
      },
    ],
  },
  {
    version: "1.4.4",
    date: "28 June 2026",
    intro: "Uninstalled apps no longer show stale icons.",
    groups: [
      {
        heading: "Improvements",
        items: [
          "Apps you've uninstalled now show a clear “Not installed” placeholder instead of their old icon, with a Remove or Keep choice — nothing is deleted without you",
          "Tile popovers now show the same dark and themed app icons as the Dock",
        ],
      },
    ],
  },
  {
    version: "1.4.3",
    date: "25 June 2026",
    intro: "Icon weight, brand logo, and in-app update checks.",
    groups: [
      {
        heading: "Customisation",
        items: [
          "Per-tile SF Symbol icon weight, from light to heavy",
          "The Dock Tile logo joins the symbol picker as its own glyph",
        ],
      },
      {
        heading: "Improvements",
        items: ["Check for Updates directly from Settings → General"],
      },
    ],
  },
  {
    version: "1.4.2",
    date: "24 June 2026",
    intro: "Settings move into the main window.",
    groups: [
      {
        heading: "Improvements",
        items: [
          "Settings now live in the main window with an accordion sidebar, instead of a separate window",
        ],
      },
    ],
  },
  {
    version: "1.4.1",
    date: "24 June 2026",
    intro: "Dark-mode icon and popover fixes.",
    groups: [
      {
        heading: "Fixes",
        items: [
          "Dark icon style now applies correctly when macOS icon style is set to Automatic",
          "Clicking a tile to dismiss its popover no longer immediately re-opens it",
          "Brand-new tiles are no longer marked hidden before they've ever been added to the Dock",
        ],
      },
    ],
  },
  {
    version: "1.4.0",
    date: "23 June 2026",
    intro: "Dock Lock display picker and diagnostics.",
    groups: [
      {
        heading: "Dock Lock",
        items: [
          "Choose exactly which display anchors the Dock — selecting one moves the Dock there immediately",
        ],
      },
      {
        heading: "Improvements",
        items: [
          "File → Copy Diagnostics gathers a report you can attach to bug reports",
          "Fixed release publishing so in-app updates can't point at a missing download",
        ],
      },
    ],
  },
  {
    version: "1.3.1",
    date: "22 June 2026",
    intro: "Dock visibility fix.",
    groups: [
      {
        heading: "Fixes",
        items: ["Hiding a tile no longer leaves it stranded in the Dock"],
      },
    ],
  },
  {
    version: "1.3.0",
    date: "18 June 2026",
    intro: "Dock Lock and start-at-login.",
    groups: [
      {
        heading: "New",
        items: [
          "Dock Lock — pin the Dock to one display so it stops jumping between screens on multi-monitor setups (Settings → Dock Lock)",
          "Start tiles at login — tiles respond instantly after a restart instead of launching on first click (Settings → General)",
        ],
      },
      {
        heading: "Privacy",
        items: [
          "Optional, anonymous usage and crash reporting to help improve Dock Tile — no personal data, opt out anytime in Settings → General",
        ],
      },
    ],
  },
  {
    version: "1.2.1",
    date: "27 March 2026",
    intro: "Fixes the popover gear icon in production builds.",
    groups: [
      {
        heading: "Fixes",
        items: [
          "The popover's gear icon now opens the installed app instead of a development build",
          "Existing tiles are migrated automatically on first launch — the Dock restarts once",
        ],
      },
    ],
  },
  {
    version: "1.2.0",
    date: "27 March 2026",
    intro: "Configure from the popover, and automatic tile migration.",
    groups: [
      {
        heading: "Popover",
        items: [
          "Gear icon in the popover header opens the app to configure that tile — in both Ghost Mode and App Mode",
          "List view gains a working “Configure…” menu item",
        ],
      },
      {
        heading: "Migration",
        items: [
          "Existing tiles are updated automatically when the app updates — one Dock restart, no per-tile action needed",
        ],
      },
    ],
  },
  {
    version: "1.1.1",
    date: "26 March 2026",
    intro: "Code quality improvements and updated app icon.",
    groups: [
      {
        heading: "Under the Hood",
        items: [
          "Extracted shared utilities to reduce code duplication (~200 lines removed)",
          "Fixed a bug where some app icons displayed incorrectly in the detail view",
          "Tile uninstall no longer briefly freezes the UI",
          "Faster debounce when editing tile names",
          "Updated development app icon",
        ],
      },
    ],
  },
  {
    version: "1.1.0",
    date: "26 March 2026",
    intro: "Auto-updates, expanded icon library, and a proper About window.",
    groups: [
      {
        heading: "Auto-Updates",
        items: [
          "Sparkle 2.x integration for seamless in-app updates",
          "Automatic daily update checks in the background",
          "Check for Updates from the app menu or About window",
          "Secure EdDSA signature verification for all updates",
        ],
      },
      {
        heading: "SF Symbol Picker",
        items: [
          "Expanded from ~170 to 6,000+ SF Symbols loaded from the system",
          "28 categories matching Apple's SF Symbols app",
          "Keyword-based search powered by system search data",
          "Filtered out wide symbols that don't work well as icons",
          "Bolder semibold weight for better icon visibility",
          "Increased max icon scale for SF Symbols",
        ],
      },
      {
        heading: "Improvements",
        items: [
          "Custom About window with version info and Check for Updates button",
          "Icon picker now fills available window height",
          "Fixed version numbering to match release tags",
        ],
      },
    ],
  },
  {
    version: "1.0.0",
    date: "8 February 2026",
    intro: "Initial release of Dock Tile.",
    groups: [
      {
        heading: "Features",
        items: [
          "Create custom Dock tiles with personalised icons",
          "Add multiple apps to each tile for quick access",
          "Choose from SF Symbols or emojis for tile icons",
          "Customise icon colours with preset or custom gradients",
          "Grid and list view layouts for tile popovers",
          "Ghost Mode - tiles hidden from Cmd+Tab by default",
          "App Mode - optional visibility in App Switcher with context menu support",
          "Drag to reorder apps within tiles",
          "Multi-select apps for batch removal",
          "Dynamic grid sizing based on app count",
          "Full support for macOS icon styles (Default, Dark, Clear, Tinted)",
        ],
      },
    ],
  },
];
