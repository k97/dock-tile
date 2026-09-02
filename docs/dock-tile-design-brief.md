# Dock Tile — Design Brief & Product Spec

> **Purpose of this document.** A self-contained description of the Dock Tile macOS app — what it is, what it does, and every screen and control it currently contains — written to be pasted into a design tool (Claude design, Figma, Stitch, etc.) as a starting prompt for designing screens and exploring features.
>
> **App version described:** 1.8.8 · **Platform:** macOS 15+ (Tahoe icon styles need macOS 26) · **Stack:** Swift 6, SwiftUI + AppKit hybrid.

---

## 1. What Dock Tile Is

**Dock Tile is a native macOS launcher built for the Dock.** It lets you create custom Dock icons ("tiles") that each group a set of apps and folders behind a single, beautifully customizable icon. Click a tile in the Dock and a popover springs open showing its apps — one click to everything. Think of it as a smarter, native take on iOS Home Screen folders, living in the macOS Dock.

It is distributed as a direct download (not the App Store) so it can integrate deeply with the Dock and displays in ways a sandboxed app cannot.

**Positioning / voice:**
- "A native macOS launcher, built for the Dock."
- "Made for your Dock — native, fast, and out of your way."
- Three pillars: **One click to everything** (group apps behind one tile) · **Custom tile icons** (colors, symbols, emoji, 4 Tahoe styles) · **Dock Lock** (pin the Dock to one display on multi-monitor setups).

**Brand:** Product name is "Dock Tile" (with a space). Logo is a rising-sun glyph (a sun inside a rounded ring). Distributed at docktile.app.

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

The app is a single main window (a 3-pane look: sidebar + detail) plus Dock popovers. There is no
separate Settings window and no About window — Settings and About live as panes inside the same
sidebar, and each pane's title lives in a 52pt title band (title text only, no icon) that replaces
the window's title bar and toolbar entirely.

| # | Screen | Role |
|---|---|---|
| 1 | **Main window — Sidebar** | Static sections: Tiles · Settings (General, Popover, Dock Lock) · Dock Tile (About); add-tile button in toolbar. |
| 2 | **Add a Tile (dialog)** | Opens from every add entry point. A blank-tile row (always present, Return default) plus up to 3 on-device suggestion cards when Smart Add has some. |
| 3 | **Tile Detail** | The selected tile's config: hero icon + name/visibility/app-switcher card, then "In This Tile" — the tile's apps edited directly in the live popover preview (no table), remove. |
| 4 | **Customise Tile (drill-down)** | Icon studio: live preview hero + controls for colour, size, weight, and symbol/emoji picker. |
| 5 | **General Settings** | Start at login, missing-apps scan, analytics consent, Smart Add toggle + Add a Tile row. |
| 6 | **Popover Settings** | Top-level pane (no longer a General drill-down): Popover Size, Tile Size, Animation, Spacing, Labels, Hover — a live preview of the real popover panel. |
| 7 | **Dock Lock Settings** | Enable lock, accessibility permission flow, display anchor picker. |
| 8 | **Accessibility Permission Primer** | Sheet explaining why Dock Lock needs Accessibility access. |
| 9 | **About** | Sidebar pane (not a window): product hero, Software Update, website, feedback, sibling-product links. |
| 10 | **Dock popover — Grid** | iOS-folder-style grid of app icons. |
| 11 | **Dock popover — List** | macOS-folder-style vertical list of apps. |

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
- Form row height: 40pt. Section content padding ~10–20pt.

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
No window title, no sidebar toggle, no toolbar surface — the sidebar and detail column sit
directly under the traffic lights. Three **static** sections (the old accordion expand/collapse
state is gone):

- **Section "Tiles"**
  - One row per tile (`ConfigurationRow`): 24×24 live mini icon preview + tile name (13pt, truncates). Selected row highlights.
  - Right-click menu: **Duplicate** · divider · **Delete** (destructive/red).
  - Empty state: a selectable "No Tiles" placeholder row (13pt, secondary) that routes the detail column to the empty state.
- **Section "Settings"**
  - Row **General** — squircle badge icon `gearshape.fill` (gray) + label "General".
  - Row **Popover** — badge icon `macwindow.on.rectangle` (indigo) + label "Popover".
  - Row **Dock Lock** — badge icon `lock.display` (blue) + label "Dock Lock".
- **Section "Dock Tile"**
  - Row **About** — badge icon `info.circle.fill` (gray) + label "About".
- **Toolbar (primary action):** "+" icon-only button. Disabled only while a freshly-created,
  unedited tile is selected. Tooltip when disabled: "Edit current tile before creating another";
  when enabled: "Create new tile". Always opens the **Add a Tile** dialog (Screen 2).

Every pane's title lives in a shared **52pt title band** (`PaneTitleBand`) that replaces the
window's title bar and toolbar: the pane title, text only (no leading icon), left-aligned, with
any trailing actions (Save, Delete, the tile action button) on the right of the same band.

### Screen 2 — Add a Tile (dialog)
A 588pt-wide sheet (native materials, rounded corners) that opens from **every** add entry point
— sidebar +, General's "Add a Tile…" row, the empty-state button. ⌘N still creates a blank tile
directly, bypassing the dialog.
- Header: "Add a Tile" (bold) + a small circular "✕" close button (Esc).
- **Blank row** (always shown, first): 44×44 placeholder-tile icon preview + "Create a blank tile"
  / "Name it, pick an icon and add apps yourself." + a prominent **"Create New Tile"** button
  (Return default).
- If Smart Add has suggestions: a divider rule "or start from what you use", then up to 3
  **suggestion cards** side by side — each a plain-bordered **"Use This Tile"** button (never the
  prominent style; the blank path stays visually primary). Picking one only pre-fills Tile Detail —
  nothing here ever docks a tile.
- If Smart Add has none (or is toggled off in General): a small note instead — "No suggestions yet
  — Dock Tile learns from the apps you open. You can turn this off in General."
- Footer: a lock glyph + "Learned on your Mac. Never leaves your device."

### Screen 3 — Tile Detail
Two parts: a hero row at top, then the tile's apps below. The tile name + Delete + the contextual
action button live in the title band, not this scroll area.

**Hero row** (HStack)
- Left: 96×96 live icon preview (tappable → opens Customise; pointing-hand cursor). Below it a subtle **"Customise"** button.
- Right: a form group with 3 rows (40pt each, 1pt separators):
  1. **Tile Name** — text field, trailing-aligned. Auto-saves (debounced 300ms).
  2. **Show Tile** — toggle. ON shows an "Add to Dock"/"Update" action in the title band; OFF shows "Remove from Dock"/"Done".
  3. **Show in App Switcher** — toggle (this is the Ghost↔App mode switch).

**Section "In This Tile"** — apps edited directly in the live popover preview; there is no apps table.
- Header: "In This Tile" (semibold) + caption "Hover to remove · Drag to reorder", with a
  Grid/List segmented control and a **"+ Add"** button (native file picker, multi-select apps or
  folders) on the trailing edge.
- Below: the **actual Dock popover panel** (Grid or List, matching the tile's layout), rendered
  live at natural size in an editable mode — hovering a cell/row reveals a small **×** to remove
  it; right-click offers **Remove**; dragging reorders; the Delete key removes the focused/hovered
  item; a "Not installed" caption still marks missing apps. It is pixel-identical to what the Dock
  will show, minus the popover's own gear/utility rows (hidden while editing).

**Toolbar (title band):** trash icon (Delete Tile) + the contextual action button — "Add to Dock" /
"Update" (`.borderedProminent`) or "Remove from Dock" / "Done" (`.bordered`) depending on state.
First Dock change ever shows a one-time consent alert ("Dock Restart Required" with "Don't show
this again" checkbox). Delete confirms via alert: title "Delete Tile", message "This will
permanently delete the tile and remove it from the dock.", buttons Cancel / Delete (destructive).

### Screen 4 — Customise Tile (drill-down)
Pushed in from the right. Title band shows "Customise Tile"; a separate back-chevron toolbar item
("Back") sits at the leading edge.

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

A newly-created, uncustomised tile shows a neutral grey "+" placeholder glyph, not a category icon.

### Screen 5 — General Settings
Grouped form, title band "General" (no toolbar actions).
1. **Start tiles at login** — toggle + help: "Keep your tiles ready in the Dock so they respond instantly after you restart your Mac." (ON by default / opt-out.) If approval pending: caption "Approve Dock Tile in Login Items to finish enabling this." + button "Open Login Items Settings…".
2. **Missing Apps** — label + help "Check your tiles for apps that have been moved or uninstalled." + button "Scan…". Result alert: either "Some apps are no longer installed" (lists "• Tile — App, App"; buttons Review in Tiles / Remove All / Cancel) or "No Missing Apps" → "Every app in your tiles is currently installed." (Done).
3. **Share anonymous usage data** — toggle + help "Help improve Dock Tile by sending anonymous usage and crash reports. No personal data is collected." (opt-out, default ON; release builds only).
4. **Section "Adding Tiles"** — a separate grouped section:
   - **Smart Add** toggle (no leading icon) + help, on/off for the suggestion cards in the Add a Tile dialog (the dialog itself always opens).
   - **"Add a Tile…"** link button — the same dialog as the sidebar +.

Software Update has moved out of General entirely — see Screen 9 (About).

### Screen 6 — Popover Settings
**Top-level sidebar pane** (no longer a General drill-down) — title band "Popover" with **Reset**
(icon-only, secondary) and **Save** (`.borderedProminent`, primary, ⌘S) as trailing title-band
actions. Grid and List layouts are configured **independently**; a "Configure" segmented switcher
(Grid/List — not itself a persisted setting) selects which one the form edits and the preview shows.
- **Hero**: the actual Dock popover panel, live, showing the active layout's in-progress (unsaved)
  settings, scaled to a fixed worst-case fit so control changes visibly spread/tighten the tiles.
- **Section "Popover"**: Popover Size (Small/Medium/Large segmented), Tile Size in Popover
  (Small/Medium/Large), Animation (None/Default/Fast — forced to None and disabled under system
  Reduce Motion).
- **Section "Tiles"**: Spacing (Compact/Comfortable/Spacious), Show Labels (Grid only — replaced by
  a static note on List), Highlight on Hover.
- Footer note: "These settings apply to every tile's popover. List view always shows labels.
  Animation follows your system Reduce Motion setting."
- Saving with any tile pinned offers to push the change to running tiles immediately (one-time
  "this restarts the Dock" confirmation, "Applying…" spinner on Save while it rebuilds).

### Screen 7 — Dock Lock Settings
Grouped form, title band "Dock Lock".
- **Lock Dock to one display** — toggle + help "Stop the Dock from jumping between screens on multi-display setups. It stays on the display you choose." Toggling ON without permission opens the Primer sheet.
- **Permission needed** (conditional): orange `exclamationmark.triangle.fill` + "Accessibility access required" + detail "Dock Tile needs Accessibility access to keep the Dock in place. Turn on Dock Tile in System Settings." + buttons "Continue" / "Open System Settings…".
- **Anchor picker** (multi-display + permission granted): label "Keep Dock on" with options "Default (follow macOS)" + each connected display (e.g. "Built-in Retina Display (Main)"). Selecting one immediately moves the Dock there.
  - Status line below: Moving (spinner + "Moving Dock to X…") / Locked (green `lock.fill` + "Dock is locked to X") / Failed (red warning + "Couldn't move the Dock to X. Make sure that display isn't mirrored, then try again." + "Try Again").
  - Footer: "Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays."
- **Single display** (conditional): `display` icon + "Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it."

### Screen 8 — Accessibility Permission Primer (sheet)
Centered, 400pt wide, 28pt padding. Auto-dismisses when permission is granted.
- 68×68 accent-gradient blob with white `accessibility` glyph (soft shadow).
- Title "Allow Accessibility Access".
- Body "Dock Lock keeps the Dock on the display you choose. To do that, Dock Tile needs Accessibility access so it can stop macOS from moving the Dock to your other screens."
- Info callout (`info.circle`): "Next, macOS will ask you to turn on Dock Tile in System Settings. You can turn this off any time."
- Buttons: "Not Now" (cancel/Esc) · "Continue" (prominent/Return → triggers the native permission dialog).

### Screen 9 — About
**Sidebar pane** under "Dock Tile" (replaces the old detached About window) — title band "About".
- **Hero**: the product in context — the user's first 3 tiles (or 3 default folder tiles) as live
  icon previews on a small Dock-like strip, plus a system folder icon, on a vibrancy card.
- **Version row**: app name + "Version X.Y.Z" caption, trailing **"Check for Updates…"** button
  (disabled mid-check) — Software Update's only home now.
- **Website row**: "Website" label, link "docktile.app".
- **Feedback card**: "Found a bug or have an idea?" + "Feedback goes straight to the developer.
  Diagnostics attach a log of what the app and its tiles did — nothing personal." + two buttons,
  **"Send Feedback…"** (mailto:, falls back to the website if no feedback address is configured)
  and **"Copy Diagnostics"**.
- **Section "Also from Happy Machines"**: two rows with a squircle badge icon, title, subtitle, and
  a link/button — "Made by Happy Machines Company" (website link) and "Spades Audio" (per-app
  volume/EQ menu-bar app, "Learn More…" link) — footer shows the copyright string.

### Screens 10 & 11 — Dock Popovers (Grid & List)
Opened by clicking a tile in the Dock; anchored flush to the Dock edge (bottom/left/right). Liquid-glass popover material. Unaffected by the Tile Detail editor above — these are the exact same panels rendered outside any editing mode.
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

> Design the macOS app **Dock Tile** — a native launcher that creates customizable Dock icons ("tiles"), each grouping apps and folders behind one beautifully designed icon; clicking a tile in the Dock opens a popover of its apps. Follow the native macOS look (Liquid Glass vibrancy, system grays, blue accent, SF Pro, continuous-corner squircles). The main window is a fixed 768pt-wide split view with no window title and no toolbar surface — every pane's title lives in its own 52pt title band (text only, no icon) that carries that pane's trailing actions. The sidebar is three static sections: **Tiles**, **Settings** (General, Popover, Dock Lock), and **Dock Tile** (About). Design these screens: (1) **Add a Tile** — a dialog opening from every add entry point, blank-first: a prominent "Create a blank tile" row (the Return default) plus, when Smart Add has suggestions, up to 3 "Use This Tile" cards below a "start from what you use" rule; (2) **Tile Detail** — a hero with a large live icon preview + "Customise" button beside a form (Tile Name, Show Tile toggle, Show in App Switcher), then "In This Tile": the tile's apps edited directly inside the real, live Dock popover panel itself (hover to remove, drag to reorder, Delete key) — there is no separate apps table and no bottom Remove-from-Dock card; the title band carries Delete plus the contextual "Add to Dock"/"Update"/"Remove from Dock"/"Done" action; (3) **Customise Tile** — a hero canvas with a 100×100 live tile preview over an icon-grid overlay, then inspector sections for Tile Colour (7 preset swatches + custom), Icon Size + Icon Weight, and a Tile Icon picker with Symbol/Emoji segmented tabs, search, and a 7-column category grid; (4) **Settings** as three independent panes — **General** (start at login, missing-apps scan, analytics toggle, an "Adding Tiles" section with the Smart Add toggle and an "Add a Tile…" row), **Popover** (a top-level pane, not a General drill-down: Popover Size, Tile Size, Animation, Spacing, Show Labels, Highlight on Hover, with a live preview of the real popover panel and title-band Reset/Save actions), and **Dock Lock** (enable toggle, accessibility-permission state, display anchor picker with locked/moving/failed status); (5) **About** — a sidebar pane, not a window: a product hero, Software Update's only home ("Check for Updates…"), website and feedback links, and sibling-product rows; (6) the **Dock popovers** in both Grid and List layouts with a configure gear — the exact same panels the Tile Detail editor above wraps, rendered here with no editing affordances. The tile icons themselves are gradient squircles with a white glass inner stroke containing a white SF Symbol or a colored emoji; a freshly-created tile defaults to a neutral grey "+" placeholder. Keep copy in UK English ("Customise", "Colour").

---

*Generated from the Dock Tile v1.8.8 codebase (the v2 main-window makeover). Strings reflect the app's current string catalog (UK English base).*
