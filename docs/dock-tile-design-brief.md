# Dock Tile — Design Brief & Product Spec

> **Purpose of this document.** A self-contained description of the Dock Tile macOS app — what it is, what it does, and every screen and control it currently contains — written to be pasted into a design tool (Claude design, Figma, Stitch, etc.) as a starting prompt for designing screens and exploring features.
>
> **App version described:** 1.4.5 · **Platform:** macOS 15+ (Tahoe icon styles need macOS 26) · **Stack:** Swift 6, SwiftUI + AppKit hybrid.

---

## 1. What Dock Tile Is

**Dock Tile is a native macOS launcher built for the Dock.** It lets you create custom Dock icons ("tiles") that each group a set of apps and folders behind a single, beautifully customizable icon. Click a tile in the Dock and a popover springs open showing its apps — one click to everything. Think of it as a smarter, native take on iOS Home Screen folders, living in the macOS Dock.

It is distributed as a direct download (not the App Store) so it can integrate deeply with the Dock and displays in ways a sandboxed app cannot.

**Positioning / voice:**
- "A native macOS launcher, built for the Dock."
- "Made for your Dock — native, fast, and out of your way."
- Three pillars: **One click to everything** (group apps behind one tile) · **Custom tile icons** (colors, symbols, emoji, 4 Tahoe styles) · **Dock Lock** (pin the Dock to one display on multi-monitor setups).

**Brand:** Product name is "Dock Tile" (with a space). Logo is a rising-sun glyph (a sun inside a rounded ring). Distributed at docktile.rkarthik.co.

---

## 2. Core Mental Model

| Concept | What it means for the UI |
|---|---|
| **Tile** | One customizable Dock icon. Has a name, a designed icon, and a list of apps/folders. Users can make unlimited tiles. |
| **Popover** | The panel that opens when a tile is clicked in the Dock. Shows the tile's apps as a **Grid** or **List**. Has a gear to jump back to configuration. |
| **Ghost mode vs App mode** | Per-tile behavior. **Ghost (default):** hidden from Cmd-Tab, no context menu, cleanest. **App mode:** visible in app switcher, has a context menu. (macOS can't do "Dock icon + hidden from Cmd-Tab + context menu" all at once.) |
| **Tahoe icon styles** | On macOS 26 each tile renders in 4 variants that follow the system: Default (colorful), Dark, Clear, Tinted — switching live with appearance. |

---

## 3. Screen Inventory

The app is a single main window (a 3-pane look: sidebar + detail) plus Dock popovers. There is no separate Settings window — Settings live as panes inside the same sidebar.

| # | Screen | Role |
|---|---|---|
| 1 | **Main window — Sidebar** | Lists all tiles + Settings entries; add-tile button in toolbar. |
| 2 | **Tile Detail** | The selected tile's config: name, visibility, layout, app-switcher, the apps table, remove. |
| 3 | **Customise Tile (drill-down)** | Icon studio: live preview hero + controls for colour, size, weight, and symbol/emoji picker. |
| 4 | **General Settings** | Start at login, software update, missing-apps scan, analytics consent. |
| 5 | **Dock Lock Settings** | Enable lock, accessibility permission flow, display anchor picker. |
| 6 | **Accessibility Permission Primer** | Sheet explaining why Dock Lock needs Accessibility access. |
| 7 | **Dock popover — Grid** | iOS-folder-style grid of app icons. |
| 8 | **Dock popover — List** | macOS-folder-style vertical list of apps. |

---

## 4. Design System / Visual Language

Native macOS (AppKit/SwiftUI) look. Use these as design tokens.

**Window**
- Fixed width **768pt**; height flexible (min 500pt; min 700pt while in the Customise drill-down).
- Horizontally non-resizable; vertical resize allowed.
- 3-column `NavigationSplitView`, balanced style. Sidebar: min 220 / ideal 240 / max 280pt.

**Color**
- Text: `.primary`, `.secondary`, `.tertiary`. Accent: system blue.
- Surfaces: window background, control background, `systemGroupedBackground` for form groups.
- Separators: `quinaryLabel` and `separatorColor`, 1pt.
- Hero/canvas backgrounds use vibrancy materials (`underWindowBackground`, `.popover`) — translucent "Liquid Glass."

**Typography**
- Sidebar & form labels: 13pt system.
- Section headers: headline / medium weight.
- Captions & help text: 11pt, secondary.
- Steppers use monospaced digits.

**Shape & spacing**
- Tile icon shape: continuous-corner squircle, radius = **22.5%** of size.
- Form groups: 12pt continuous corners. Buttons/overlays: 6pt. Grid cells: 8pt.
- Form row height: 40pt. Table row height: 28pt. Section content padding ~10–20pt.

**Tile icon design (the heart of the app)**
- Background: linear gradient (top color → bottom color) from the chosen tint.
- Glass effect: white inner stroke at 50% opacity, line width scales with size.
- Content: SF Symbol (white, weighted) **or** emoji (full color) **or** the DockTile brand glyph.
- No baked shadow (the Dock adds its own).
- 7 preset tint colors + a custom color picker (rainbow swatch → native color panel).

**Motion**
- Color swatch select: spring (response 0.3, damping 0.7).
- Detail ↔ Customise transition: slide `.move(edge: .trailing)`, easeInOut 0.3.
- App row reorder: easeInOut 0.2.

---

## 5. Screen Specs (exact controls & labels)

All user-facing strings are real (from the app's string catalog). UK English base ("Customise", "Colour").

### Screen 1 — Main Window: Sidebar
Accordion list with two collapsible sections (expand state remembered).

- **Section "Tiles"**
  - One row per tile (`ConfigurationRow`): 24×24 live mini icon preview + tile name (13pt, truncates). Selected row highlights.
  - Right-click menu: **Duplicate** · divider · **Delete** (destructive/red).
  - Empty state text: "No Tiles" (13pt, secondary).
- **Section "Settings"**
  - Row **General** — squircle badge icon `gearshape.fill` (gray) + label "General".
  - Row **Dock Lock** — badge icon `lock.display` (blue) + label "Dock Lock".
- **Toolbar (primary action):** "+" icon-only button.
  - Disabled until the current tile has been edited. Tooltip when disabled: "Edit current tile before creating another"; when enabled: "Create new tile".

### Screen 2 — Tile Detail
Two parts: a hero row at top, then sections below.

**Hero row** (HStack)
- Left: 118×118 live icon preview (tappable → opens Customise; pointing-hand cursor). Below it a subtle **"Customise"** button.
- Right: a form group with 4 rows (40pt each, 1pt separators):
  1. **Tile Name** — text field, trailing-aligned. Auto-saves (debounced 300ms).
  2. **Show Tile** — toggle. ON shows an "Add to Dock"/"Update" action in toolbar; OFF shows "Remove from Dock"/"Done".
  3. **Layout** — pop-up menu: **Grid** / **List**.
  4. **Show in App Switcher** — toggle (this is the Ghost↔App mode switch).

**Section "Selected Items"** (the apps table)
- Header: "Selected Items" (headline).
- Native table with header row columns **Item** (flexible) and **Kind** (100pt fixed).
- Data rows (28pt, alternating background): drag handle (`line.3.horizontal`) · 16×16 app icon (cached; fallback `app.fill`/`folder.fill`) · item name · Kind = "Application"/"Folder".
  - Missing app: dimmed to 70%, name secondary, Kind shows **"Not installed"**.
- Selection: click replaces; Cmd-click toggles; Shift-click range; Esc clears.
- Reorder: drag rows (animated swap).
- Empty state (centered): "No items added yet" + caption "Click + to add applications or folders".
- Bottom toolbar: **"+"** (opens file picker for apps/folders, defaults to /Applications; beeps on duplicate) · divider · **"−"** (removes selected, disabled when none selected).

**Section "Remove from Dock"**
- Left: title "Remove from Dock" + subtitle "This removes the tile only, and your apps or folders stay intact."
- Right: **"Remove"** button (red/subtle). Confirms via alert: title "Delete Tile", message "This will permanently delete the tile and remove it from the dock.", buttons Cancel / Delete (destructive).

**Toolbar action button (right side, contextual):** "Add to Dock" / "Update" / "Remove from Dock" / "Done" depending on state. First Dock change ever shows a one-time consent alert ("Dock Restart Required" with "Don't show this again" checkbox).

### Screen 3 — Customise Tile (drill-down)
Pushed in from the right. Toolbar: back chevron "Back"; title "Customise Tile".

**Studio Canvas (hero)** — full-width, vibrancy background.
- Centered 100×100 live icon preview with an **Apple icon design-guide grid overlay** (8×8 grid, diagonal X, 3 concentric circles marking the safe area; adaptive line color).
- Tile name shown beneath (headline).

**Inspector card (scrolls), three sections separated by dividers:**

1. **Tile Colour** (52pt row)
   - Label "Tile Colour" + a swatch strip: 7 preset color circles (24×24; selected = white ring + checkmark) and a custom-color button (rainbow angular-gradient ring with "+", or checkmark when active) that opens the native color panel (no alpha).

2. **Icon Size / Icon Weight** (split 52pt row, vertical divider)
   - Left: "Icon Size" + stepper (10 → 14 for emoji / 19 for symbols), value in monospaced digits.
   - Right: "Icon Weight" + info button (popover: "Weight applies to symbols only. Emoji aren't affected.") + pop-up menu of weights (Light, Regular, Medium, Semibold, Bold, Heavy).

3. **Tile Icon**
   - Title "Tile Icon".
   - Segmented control: **Symbol** / **Emoji** (switching only changes the picker, not the saved icon until one is tapped).
   - Sticky search field (magnifier + clear "✕"): placeholder "Search symbols" or "Search emojis".
   - **Symbol grid:** 7 columns, grouped by category with captions; a pinned first **"DockTile"** brand-logo category. Selected cell = filled accent circle + white glyph; cells render at the chosen weight.
   - **Emoji grid:** 7 columns, 7 categories (People, Animals & Nature, Food & Drink, Activity, Travel & Places, Objects, Symbols). Selected cell = 20% accent fill + accent border.

### Screen 4 — General Settings
Grouped form, title "General".
1. **Start tiles at login** — toggle + help: "Keep your tiles ready in the Dock so they respond instantly after you restart your Mac." (ON by default / opt-out.) If approval pending: caption "Approve Dock Tile in Login Items to finish enabling this." + button "Open Login Items Settings…".
2. **Software Update** — label + help "You're using version X.Y.Z. Dock Tile checks for updates automatically." + button "Check for Updates…" (disabled while a check is in flight).
3. **Missing Apps** — label + help "Check your tiles for apps that have been moved or uninstalled." + button "Scan…". Result alert: either "Some apps are no longer installed" (lists "• Tile — App, App"; buttons Review in Tiles / Remove All / Cancel) or "No Missing Apps" → "Every app in your tiles is currently installed." (Done).
4. **Share anonymous usage data** — toggle + help "Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected." (opt-out, default ON; release builds only).

### Screen 5 — Dock Lock Settings
Grouped form, title "Dock Lock".
- **Lock Dock to one display** — toggle + help "Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose." Toggling ON without permission opens the Primer sheet.
- **Permission needed** (conditional): orange `exclamationmark.triangle.fill` + "Accessibility access required" + detail "Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings." + buttons "Continue" / "Open System Settings…".
- **Anchor picker** (multi-display + permission granted): label "Keep Dock on" with options "Default (follow macOS)" + each connected display (e.g. "Built-in Retina Display (Main)"). Selecting one immediately moves the Dock there.
  - Status line below: Moving (spinner + "Moving Dock to X…") / Locked (green `lock.fill` + "Dock is locked to X") / Failed (red warning + "Couldn't move the Dock to X. Make sure that display isn't mirrored, then try again." + "Try Again").
  - Footer: "Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays."
- **Single display** (conditional): `display` icon + "Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it."

### Screen 6 — Accessibility Permission Primer (sheet)
Centered, 400pt wide, 28pt padding. Auto-dismisses when permission is granted.
- 68×68 accent-gradient blob with white `accessibility` glyph (soft shadow).
- Title "Allow Accessibility Access".
- Body "Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens."
- Info callout (`info.circle`): "Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time."
- Buttons: "Not Now" (cancel/Esc) · "Continue" (prominent/Return → triggers the native permission dialog).

### Screens 7 & 8 — Dock Popovers (Grid & List)
Opened by clicking a tile in the Dock; anchored flush to the Dock edge (bottom/left/right). Liquid-glass popover material.
- **Grid:** app/folder icons in a flexible grid (8pt spacing), iOS-folder feel.
- **List:** vertical rows of 16×16 icon + name, macOS-folder feel; scrolls if long.
- Both: full keyboard navigation (arrows / Enter / Esc); a **gear** button (`gearshape.fill`, tooltip "Configure Tile") bottom-right that opens the main app to that tile's configuration.

---

## 6. Full Feature Catalog

| Feature | One-liner |
|---|---|
| **Custom Dock tiles** | Unlimited tiles, each a named icon grouping apps/folders, launched from the Dock. |
| **Icon customization** | Gradient backgrounds, 7 presets + custom color, SF Symbols, emoji, brand logo, 6 symbol weights, adjustable scale, glass squircle. |
| **Tahoe icon styles** | 4 live-switching variants (Default / Dark / Clear / Tinted) that follow macOS 26 appearance. |
| **Popover layouts** | Per-tile Grid or List view of the tile's apps with keyboard nav + configure gear. |
| **Ghost vs App mode** | Per-tile choice between invisible-and-clean and app-switcher-visible-with-menu. |
| **Dock Lock** | Pin the Dock to one display on multi-monitor setups; UUID-persisted anchor; needs Accessibility. |
| **Start tiles at login** | Warms helper processes at login for instant clicks (opt-out, on by default). |
| **Missing app detection** | Non-destructively flags moved/uninstalled apps with a placeholder; never silently deletes. |
| **Auto-updates** | Sparkle (EdDSA-signed appcast), daily checks, manual "Check for Updates…". |
| **Migration pipeline** | Re-bakes stale helper tiles automatically after app updates with a single Dock restart. |
| **Diagnostics** | Copy structured logs to the clipboard for bug reports. |
| **Analytics & consent** | Firebase Analytics/Crashlytics, opt-out, release-only, helpers honor the main toggle. |
| **One-time Dock consent** | A single confirmation before the first Dock-modifying action. |

---

## 7. Key User Workflows
1. **Create a tile:** "+" → name it → Customise (color, symbol/emoji, weight, size) → add apps/folders → pick Grid/List → Add to Dock.
2. **Use a tile:** click it in the Dock → popover opens → click an app to launch.
3. **Re-customize:** select tile → Customise → changes auto-save and re-bake the icon.
4. **Pin the Dock:** Settings → Dock Lock → enable → grant Accessibility → pick a display.
5. **Clean up:** Scan for missing apps (General settings) → Review/Remove; or Remove a whole tile from its Detail screen.

---

## 8. Ready-to-Paste Design Prompt

> Design the macOS app **Dock Tile** — a native launcher that creates customizable Dock icons ("tiles"), each grouping apps and folders behind one beautifully designed icon; clicking a tile in the Dock opens a popover of its apps. Follow the native macOS look (Liquid Glass vibrancy, system grays, blue accent, SF Pro, continuous-corner squircles). The main window is a fixed 768pt-wide split view: a left sidebar listing tiles and Settings, and a detail pane. Design these screens: (1) **Tile Detail** — large live icon preview + a "Customise" button, a form (Tile Name, Show Tile toggle, Layout Grid/List, Show in App Switcher), a "Selected Items" apps table with drag-reorder and add/remove, and a Remove-from-Dock section; (2) **Customise Tile** — a hero canvas with a 100×100 live tile preview over an icon-grid overlay, then inspector sections for Tile Colour (7 preset swatches + custom), Icon Size + Icon Weight, and a Tile Icon picker with Symbol/Emoji segmented tabs, search, and a 7-column category grid; (3) **General Settings** (start at login, software update, missing-apps scan, analytics toggle); (4) **Dock Lock Settings** (enable toggle, accessibility-permission state, display anchor picker with locked/moving/failed status); (5) the **Dock popovers** in both Grid and List layouts with a configure gear. The tile icons themselves are gradient squircles with a white glass inner stroke containing a white SF Symbol or a colored emoji. Keep copy in UK English ("Customise", "Colour").

---

*Generated from the Dock Tile v1.4.5 codebase. Strings reflect the app's current string catalog (UK English base).*
