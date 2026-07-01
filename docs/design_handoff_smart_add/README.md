# Handoff: Smart Add — suggested tiles on tile creation

## Overview
"Smart Add" is a new step in Dock Tile's **create-a-tile** flow. Today, pressing **+** in the
sidebar toolbar silently creates a blank tile and drops the user on Tile Detail. This feature
intercepts that: if Dock Tile can suggest ready-made tiles grouped from the user's **recent app
usage** (on-device), it presents a **modal sheet** of suggestions. Picking one instantly creates a
pre-filled tile and lands on the normal Tile Detail screen — the user still confirms with the
existing **Add to Dock**. If there are no suggestions, the flow is exactly today's behavior.

**The full path:** `+` → (Dock Tile checks on-device usage) → if suggestions: **Smart Add sheet**
→ *Use This Tile* (pre-filled Tile Detail) **or** *Create New Tile* (empty draft) → **Add to Dock**.
If no suggestions: `+` → empty draft (unchanged).

## About the Design Files
`Smart Add.dc.html` in this bundle is a **design reference created in HTML** (a Design Component
that mounts the project's macOS design-system web components). It shows the intended look and
behavior — it is **not** production code to copy. The task is to **recreate it natively in the Dock
Tile app** (Swift 6 / SwiftUI + AppKit) using the app's existing patterns, components, and string
catalog. The HTML renders three frames on one canvas:
- **1a** — the Smart Add sheet (the new UI)
- **1b** — the Tile Detail screen after *Use This Tile* (pre-filled)
- **1c** — the Tile Detail screen after *Create New Tile* (empty draft — this already exists in the app)

## Fidelity
**High-fidelity.** Colors, type, spacing, corner radii, and button hierarchy are final and follow
Apple HIG + the app's native macOS look (system grays, system blue accent, SF Pro, continuous-corner
squircles, translucent sheet over a dimmed window). Recreate 1a pixel-faithfully with SwiftUI
controls; 1b/1c should reuse the app's **existing** `DockTileDetailView` unchanged.

---

## The critical framing (read before coding)
There is **no Siri or public Apple API that returns app-usage frequency** — do not try to read Siri
suggestions. Dock Tile is a **non-sandboxed** direct-download app, so it builds its **own on-device
usage signal**:
- **Launch/activation history** — observe `NSWorkspace.shared.notificationCenter`
  (`didLaunchApplicationNotification`, `didActivateApplicationNotification`); persist a rolling log
  locally (same prefs-dir pattern as `ConfigurationManager` storage).
- **Spotlight metadata per app** — `kMDItemUseCount` and `kMDItemLastUsedDate` via `NSMetadataQuery`
  over `/Applications` and `~/Applications`.
- **Category** — `LSApplicationCategoryType` from each app bundle's Info.plist
  (`public.app-category.web-browsers`, `.video`, `.social`, `.developer-tools`, `.productivity`, …).

All computation stays on device and never leaves it — this is **independent of the analytics consent
toggle**. Surface it with the footnote "Learned on your Mac. Never leaves your device."

---

## Screens / Views

### Screen A — Smart Add sheet (NEW) — see frame `1a`
- **Purpose:** offer 2–3 suggested tiles when creating a new tile; or start a blank one.
- **Presentation:** a macOS **sheet** over the main 768pt window. The window content behind is
  dimmed with a scrim `rgba(0,0,0,0.26)` + faint blur; the sheet is a floating rounded card.
- **Layout (top→bottom):** header row → divider → row of suggestion cards → divider → footer row.
- **Sheet card:** ~624pt wide, `background: --surface-card`, `border-radius: 12px`,
  `box-shadow: 0 22px 60px -12px rgba(0,0,0,.5)`, `overflow: hidden`.

**Components**
- **Header** (padding 16/18): 30×30 gradient "sparkle" badge (`linear-gradient(160deg,#7AA7FF,#3B6BFF)`,
  8px radius) with a white SF Symbol `sparkles`; title **"Add a Tile"** (15pt/700, `--text-primary`);
  subtitle **"Pick a tile to start from — you can rename it, restyle it and change the apps next."**
  (11.5pt, `--text-secondary`); trailing 22×22 circular close button (`xmark`, `--fill-secondary`).
- **Suggestion cards** (equal flex, gap 12px, padding 16/18). Each card (radius 11px, hairline inset
  border, padding 14/12, centered column, gap 9px):
  - **Tile icon** 58×58, `border-radius: 13px` (≈22.5%), top→bottom gradient per category, white inner
    stroke `inset 0 0 0 .5px rgba(255,255,255,.5)`, soft colored drop shadow, centered white SF Symbol (30px).
  - **Name** 13.5pt/600.
  - **Reason chip** (inline, `--fill-secondary`, radius 9px, padding 2/8): 9px glyph + 10.5pt/500
    `--text-secondary` text. One of: "By category" (grid glyph), "Most used this week" (clock),
    "Opened together" (link).
  - **Member-app row**: up to 4 app icons, 22×22, radius 6px (real app icons via `AppIconLoader`; the
    mock uses gradient monograms as placeholders).
  - **Action button** (full width, 26px, radius 6px): label **"Use This Tile"**.
- **Footer** (padding 11/18): `lock` glyph (11px, `--text-tertiary`) + **"Learned on your Mac. Never
  leaves your device."** (11pt, `--text-tertiary`); spacer; a bordered **"Create New Tile"** button.

**Button hierarchy (Apple HIG — this is deliberate, keep it):**
- Exactly **one filled/prominent** button — the **top pick** (in the mock, "Watch"). It is the
  Return-key default. `.borderedProminent`, system blue, white label, 600 weight.
- The other suggestion buttons are **tinted** — accent-colored label on ~12% accent fill
  (`.bordered` + `.tint(.accentColor)` or `background: color-mix(in srgb, accent 12%, transparent)`).
- **"Create New Tile"** is a **bordered neutral** secondary button (gray, NOT accent — blue is
  reserved for the smart suggestions so the manual path stays visually distinct). It must look like a
  button (bordered push-button), not plain text.
- Never render three filled buttons — HIG: "avoid too many filled buttons… use style, not size, to
  distinguish the preferred choice."

### Screen B — Tile Detail after *Use This Tile* — see frame `1b`
Reuse the **existing** `DockTileDetailView`, pre-filled. Differences vs a blank tile:
- Sidebar shows the newly created tile selected (e.g. "Watch", pink `play.fill` squircle).
- A subtle **provenance banner** at the top of the detail (accent-tinted, sparkle glyph):
  "Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it
  to your Dock." (New, optional element; everything else is the standard detail.)
- Form: Tile Name (seeded), Show Tile (off — not docked yet), Layout (Grid), Show in App Switcher (off).
- Selected Items table pre-populated with the suggestion's apps (all "Application").
- Toolbar shows the standard prominent **Add to Dock** (the real commit).

### Screen C — Tile Detail after *Create New Tile* — see frame `1c`
The app's **current** empty-draft behavior, unchanged: "New Tile", empty Selected Items state
("No items added yet" / "Click + to add applications or folders"), toolbar Add to Dock.

---

## Interactions & Behavior
- **+ pressed:** compute suggestions. `if suggestions.isEmpty { createConfiguration() }`
  (today's flow) `else { present Smart Add sheet }`. Keep the existing enable/disable gating on the
  + button (`selectedConfigHasBeenEdited`) unchanged.
- **Use This Tile:** create a pre-filled configuration, select it, dismiss the sheet → land on Tile
  Detail. Do **not** auto-add to Dock.
- **Create New Tile:** existing `createConfiguration()` + dismiss → Tile Detail (empty draft).
- **Close (✕) / Esc:** dismiss the sheet, create nothing.
- **Card hover:** hairline border brightens to ~55% accent + faint accent wash; the top pick stays
  visually prominent regardless.
- **Sheet transition:** standard macOS sheet drop-in; respect Reduce Motion.

## State Management
- New `SmartAddEngine` service (`@MainActor`): builds/persists the on-device launch log, reads
  Spotlight metadata + categories, and produces `[TileSuggestion]`.
- `computeSuggestions(existing:limit:)` runs when + is pressed (cheap; can be precomputed on window
  appear and cached). Excludes apps already covered by existing tiles; requires ≥3 apps/group;
  scores by recency × frequency; returns best-first, `limit` default 3.
- Sheet presentation state lives in `DockTileConfigurationView` (`@State showSmartAdd` +
  `@State suggestions`), mirroring how it already hosts alerts.
- `ConfigurationManager` gains `createConfiguration(from: TileSuggestion)`; selection flows through
  the existing `SidebarSelection.tile(id)` / `selectedConfigId` machinery.

## Design Tokens (native equivalents)
- **Accent / primary:** system blue (`.accentColor`; #007AFF light / #0A84FF dark).
- **Tinted secondary fill:** ~12% accent (`color-mix(in srgb, accent 12%, transparent)`).
- **Neutral secondary button:** system bordered gray (`.bordered`, control background + hairline).
- **Surfaces:** window background, `--surface-card` (white), `systemGroupedBackground` for detail.
- **Text:** `.primary` / `.secondary` / `.tertiary`.
- **Scrim:** `rgba(0,0,0,0.26)`.
- **Radii:** tile icon 22.5% of size; sheet 12px; cards 11px; buttons 6px; reason chips 9px.
- **Type:** SF Pro. Titles 15pt/700, labels 13pt, captions/footnote 11pt.
- **Category → identity map:** browsers→"Browse"/`globe`/blue · video→"Watch"/`play.fill`/pink-red
  · developer-tools→"Ship"/`chevron.left.forwardslash.chevron.right`/indigo ·
  social→"Chat"/`bubble.left.and.bubble.right`/green · productivity→"Work"/`folder`/blue.

## Assets
- No new raster assets. Tile/app icons come from `DockTileIconPreview` and `AppIconLoader`
  (real app icons). SF Symbols for glyphs. The HTML mock uses inline SVGs / gradient monograms only
  as stand-ins — use SF Symbols + real icons natively.

## Strings (UK English base — add to `AppStrings` + `Resources/Localizable.xcstrings`)
"Add a Tile" · "Pick a tile to start from — you can rename it, restyle it and change the apps next."
· "Use This Tile" · "Create New Tile" · "Learned on your Mac. Never leaves your device." ·
"Created by Smart Add from your recent apps. Rename it, restyle it or edit the apps — then add it to
your Dock." · reason strings "By category" / "Most used this week" / "Opened together".

## Codebase integration points (already validated)
- `DockTile/Views/DockTileSidebarView.swift` — the `+` toolbar `Button` (`.primaryAction`) currently
  calls `configManager.createConfiguration()`. Route it through the suggestion check instead.
- `DockTile/Views/DockTileConfigurationView.swift` — host the `.sheet` here (it already hosts the
  missing-apps `.alert` and owns `SidebarSelection`).
- `DockTile/Managers/ConfigurationManager.swift` — add `createConfiguration(from:)` alongside
  `createConfiguration()`; reuse `addAppItem`, `generateUniqueName`, `uniqueName(base:existing:)`,
  and the save/select pattern. Set `isVisibleInDock = false`.
- `DockTile/Models/ConfigurationModels.swift` / `ConfigurationSchema.swift` — `DockTileConfiguration`
  (name, tintColor, symbolEmoji, iconType, iconValue, layoutMode, appItems, isVisibleInDock) and
  `AppItem` (name, isFolder, lastKnownPath). Seed these from a suggestion.
- `AppInstallChecker` / `AppIconLoader` — resolve + render suggested apps.

## Testing
- Unit: `computeSuggestions` — empty history → `[]`; apps in existing tiles excluded; ≥3 apps/group;
  scoring order; category→identity mapping.
- Unit: `createConfiguration(from:)` seeds name/tint/symbol/appItems and leaves `isVisibleInDock == false`.
- UI: + with suggestions opens sheet; *Use This Tile* → pre-filled Tile Detail; *Create New Tile* and
  the no-suggestions path both match the current blank-tile flow; Esc creates nothing.

## Out of scope
- No auto-add to Dock from the sheet (Add to Dock stays the explicit confirm on Tile Detail).
- No changes to Dock Lock, popovers, or the migration pipeline.
- No analytics-default changes; Smart Add data never leaves the device regardless of that toggle.

## Files in this bundle
- `Smart Add.dc.html` — the high-fidelity design reference (open in a browser to view all three frames).
- `IMPLEMENTATION_PROMPT.md` — a ready-to-run task prompt for Claude Code (start here).
