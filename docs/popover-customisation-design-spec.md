# Design Spec — Popover Customisation (Settings)

> **What this is.** A spec for a new **Popover Customisation** pane inside Dock Tile's Settings, letting users tune how the helper-tile Dock popover (Grid / List) looks and feels. Written to Apple HIG (macOS Tahoe / Liquid Glass) and to Dock Tile's existing settings conventions. Pairs with [dock-tile-design-brief.md](dock-tile-design-brief.md).
>
> **Status:** proposal · **Target version:** post-1.4.5 · **Scope:** global app settings (applies to every tile's popover; per-tile Grid/List choice stays in Tile Detail).

---

## 1. Why & where

The Dock popover today (Grid and List, see brief §5 Screens 7–8) has a fixed look. Power users with many tiles want control over size, spacing, and motion. This pane gives them appearance controls without touching per-tile config.

**Placement.** A third row in the sidebar's **Settings** section, after General and Dock Lock:

| Sidebar row | Badge icon | Tint | Pane title |
|---|---|---|---|
| General | `gearshape.fill` | gray | General |
| Dock Lock | `lock.display` | blue | Dock Lock |
| **Popover** *(new)* | `macwindow.on.rectangle` | indigo | Popover |

**Global, not per-tile.** These are app-wide defaults that every popover inherits. State the scope inline so users don't expect a per-tile override here (the Grid vs List toggle remains on the Tile Detail screen). A footer note carries this: *"These settings apply to every tile's popover."*

---

## 2. Research that shaped the design

| Finding | Source | Decision |
|---|---|---|
| Density tiers are an established pattern — Material (default/comfortable/compact), SAP Fiori (cozy/compact), Salesforce (comfy/compact). Three named tiers read clearly. | Material Design, SAP Fiori, Salesforce | Use **Compact / Comfortable / Spacious**, default Comfortable. |
| Dense layouts must keep ≥44pt (Apple) / 48dp (Material) hit targets and adequate gaps; users should *opt into* density. | Material Design density guidance | Compact reduces padding/gap but never icon hit area below 44pt. Default is the roomier Comfortable. |
| Grid item size is driven by a small set of column counts, not free pixels (Raycast: 8 / 5 / 3 per row). | Raycast API | Map **Popover Size** to discrete column counts, not a px slider — predictable and snappy. |
| Animation speed in mature design systems is generally tied to the OS Reduce-Motion preference rather than an in-app slider. | MDN `prefers-reduced-motion`, Material Motion | **Honor system Reduce Motion**: when it's on, force animation Off and disable the control with an explanatory note. Otherwise offer None / Default / Fast. |

(Full source links at the end.)

---

## 3. Layout

Follows the existing settings panes: a grouped `Form` (`.formStyle(.grouped)`), 13pt labels, captions at 11pt secondary. Adds a **live preview hero** at the top (mirrors the Customise-Tile icon studio), so changes are felt immediately.

```
┌───────────────────────── Popover ─────────────────────────┐
│                                                            │
│   ┌──── live preview (Liquid Glass popover mock) ────┐     │
│   │   ▣  ▣  ▣  ▣                                      │     │   ← reflects every control live,
│   │   ▣  ▣  ▣  ▣      (Grid sample, switch G/L)       │     │     toggleable Grid ⇄ List sample
│   │   Mail  Notes …                                   │     │
│   └──────────────────────────────────────────────────┘     │
│                                                            │
│  POPOVER                                                   │
│  ┌──────────────────────────────────────────────────┐    │
│  │ Popover Size            [ Small  ‹Medium›  Large ] │    │
│  │ Tile Size               [ Small  ‹Medium›  Large ] │    │
│  │ Animation               [ None  ‹Default›  Fast  ] │    │
│  └──────────────────────────────────────────────────┘    │
│  Tile size scales within the popover.                      │   ← section footer
│                                                            │
│  TILES                                                     │
│  ┌──────────────────────────────────────────────────┐    │
│  │ Spacing          [ Compact ‹Comfortable› Spacious]│    │
│  │ Show Labels                              (•   ) ON │    │
│  │ Highlight on Hover                       (•   ) ON │    │
│  └──────────────────────────────────────────────────┘    │
│  Labels show app names. Highlight adds a hover background. │
│                                                            │
│                                   [ Reset to Defaults ]    │
└────────────────────────────────────────────────────────────┘
```

### 3.1 Live preview hero
- A small Liquid-Glass popover mock (`.glassEffect()` / `.regularMaterial` fallback) showing ~6–8 sample apps.
- A tiny segmented control **Grid / List** on the preview to flip which layout you're previewing (this only changes the *sample*, not any tile's real layout).
- Re-renders on every control change. Same pattern as the Customise-Tile studio canvas.

---

## 4. Controls

### Group A — "Popover" (the container)

| Control | Type | Options (default **bold**) | Behaviour | Applies to |
|---|---|---|---|---|
| **Popover Size** | Segmented picker | Small · **Medium** · Large | Maps to grid columns & overall width. Suggested: Small = 4 cols, Medium = 5, Large = 6 (List = narrow / standard / wide). | Grid + List |
| **Tile Size** | Segmented picker | Small · **Medium** · Large | Icon/cell size *within* the popover. Independent of Popover Size, so users get small icons in a big popover or vice-versa. Never shrinks hit target below 44pt. | Grid + List |
| **Animation** | Segmented picker | None · **Default** · Fast | Open/close + content motion. Maps to durations (None = instant, Default ≈ 0.25s, Fast ≈ 0.15s). **Disabled & forced to None when system Reduce Motion is on.** | Grid + List |

Section footer: *"Tile size scales within the popover."* When Reduce Motion is active, append an inline caption under Animation: *"Animation is off because Reduce Motion is on in System Settings."* (with a button "Open Accessibility Settings…").

### Group B — "Tiles" (items inside the popover)

| Control | Type | Options (default **bold**) | Behaviour | Applies to |
|---|---|---|---|---|
| **Spacing** | Segmented picker | Compact · **Comfortable** · Spacious | Gap + padding between items. Compact tightens to an 8pt rhythm; Spacious opens to ~20pt. Hit targets stay ≥44pt at all tiers. | Grid + List |
| **Show Labels** | Toggle | **ON** | Grid: app names under icons (off = pure icon grid, iOS-folder feel). List: always labelled, so when previewing List this control is shown but disabled/greyed with a hint. | Grid (primarily) |
| **Highlight on Hover** | Toggle | **ON** | Subtle background fill on the hovered item. Off = no hover chrome. Keyboard focus highlight is unaffected (accessibility). | Grid + List |

Section footer: *"Labels show app names under each icon. Highlight adds a background on hover."*

### Footer action
- **Reset to Defaults** — bordered button, bottom-trailing. Restores all six controls to defaults. No confirmation needed (non-destructive, instantly previewable).

---

## 5. Defaults

| Setting | Default | Rationale |
|---|---|---|
| Popover Size | Medium | Matches today's feel; 5-col grid is the comfortable middle. |
| Tile Size | Medium | Legible without dominating. |
| Animation | Default | Native motion; auto-overridden by Reduce Motion. |
| Spacing | Comfortable | Density opt-in principle — start roomy, let users tighten. |
| Show Labels | ON | Names aid recognition; iOS-folder grid is the opt-in. |
| Highlight on Hover | ON | Standard macOS affordance. |

Defaults must keep the popover visually identical to current 1.4.5 behaviour, so existing users see no surprise change on upgrade.

---

## 6. Behaviour & engineering notes

- **Persistence.** Store in the shared suite (`com.docktile.shared`, like analytics consent) so **helper processes read the same values** — the popover is rendered by helpers, not the main app. New `UserDefaultsKeys` entries; mirror the brief's schema-evolution rule (default-valued, backward compatible).
- **Live propagation.** Helpers already poll/observe shared state for icon styles (`IconStyleManager`, 2s poll). Reuse that channel (or a `DistributedNotificationCenter` post) so an open popover — or the next open — reflects changes without an app restart.
- **Grid vs List applicability.** Show Labels is grid-centric; in the List preview show it disabled with a hint ("List always shows labels"). Everything else applies to both.
- **Reduce Motion.** Read `@Environment(\.accessibilityReduceMotion)`. When true: force Animation = None, disable the segmented control, show the explanatory caption + Settings deep-link button. Never animate regardless of the stored value.
- **Hit targets.** Compact/Small must clamp the interactive cell to ≥44pt even if the visual glyph is smaller (use `contentShape` + `frame(minWidth:minHeight:)`).
- **No per-tile bleed.** This pane writes global keys only. The per-tile `layoutMode` (Grid/List) is untouched.

---

## 7. Proposed `AppStrings` keys (UK English base)

| Key | String |
|---|---|
| `Settings.popover` | "Popover" |
| `Settings.popover.appliesToAll` | "These settings apply to every tile's popover." |
| `Label.popoverSize` | "Popover Size" |
| `Label.tileSizeInPopover` | "Tile Size" |
| `Label.popoverAnimation` | "Animation" |
| `Label.popoverSpacing` | "Spacing" |
| `Label.showLabels` | "Show Labels" |
| `Label.highlightOnHover` | "Highlight on Hover" |
| `Size.small` / `Size.medium` / `Size.large` | "Small" / "Medium" / "Large" |
| `Animation.none` / `Animation.default` / `Animation.fast` | "None" / "Default" / "Fast" |
| `Density.compact` / `Density.comfortable` / `Density.spacious` | "Compact" / "Comfortable" / "Spacious" |
| `Hint.listAlwaysLabelled` | "List view always shows labels." |
| `Hint.reduceMotionOn` | "Animation is off because Reduce Motion is on in System Settings." |
| `Button.openAccessibilitySettings` | "Open Accessibility Settings…" |
| `Button.resetToDefaults` | "Reset to Defaults" |

---

## 8. HIG compliance checklist

- [x] Settings live in the in-app Settings panes (Dock Tile's established pattern), not a separate window.
- [x] Grouped `Form` with section headers + explanatory footers (standard macOS settings layout).
- [x] Segmented pickers for mutually-exclusive 3-tier choices; toggles for booleans.
- [x] Respects **Reduce Motion** (overrides Animation).
- [x] Maintains ≥44pt hit targets at the densest setting.
- [x] Keyboard-focus highlight independent of the hover-highlight toggle (accessibility).
- [x] Liquid Glass material for the preview popover, with pre-Tahoe material fallback.
- [x] Live preview gives immediate, reversible feedback; Reset offers a safe escape.
- [x] Semantic colors / system typography throughout (adapts to light/dark + Tahoe icon styles).

---

## 9. Ready-to-paste design prompt

> Design a new **"Popover"** settings pane for the native macOS app **Dock Tile** (Tahoe / Liquid Glass look — translucent materials, system grays, blue accent, SF Pro, continuous-corner squircles). It's the third row in the sidebar's Settings section (after General and Dock Lock), icon `macwindow.on.rectangle` tinted indigo. The pane is a grouped Form with a live-preview hero at top: a small Liquid-Glass popover mock showing ~6 sample app icons, with a tiny Grid/List segmented toggle to preview either layout; it updates live as controls change. Below, two grouped sections. **Section "Popover":** three rows, each a label + segmented picker — "Popover Size" (Small/Medium/Large, default Medium), "Tile Size" (Small/Medium/Large, default Medium), "Animation" (None/Default/Fast, default Default), with a footer note "Tile size scales within the popover." **Section "Tiles":** "Spacing" segmented (Compact/Comfortable/Spacious, default Comfortable), "Show Labels" toggle (ON), "Highlight on Hover" toggle (ON), footer "Labels show app names under each icon. Highlight adds a background on hover." A trailing "Reset to Defaults" button sits below. Show an alternate state where macOS Reduce Motion is on: the Animation picker is disabled on None with the caption "Animation is off because Reduce Motion is on in System Settings." and an "Open Accessibility Settings…" link. Keep copy in UK English. Match the existing Dock Tile settings panes (768pt fixed-width window, 13pt labels, 11pt secondary captions). Also produce a second frame showing the actual Dock popover rendered at: Popover Size = Large, Tile Size = Small, Spacing = Compact, Labels OFF — to show the densest configuration.

---

## Sources
- [Material Design — Applying density](https://m2.material.io/design/layout/applying-density.html) · [Material 3 — Density](https://m3.material.io/foundations/layout/understanding-layout/density)
- [SAP Fiori — Content Density (Cozy & Compact)](https://www.sap.com/design-system/fiori-design-web/v1-96/foundations/visual/cozy-compact)
- [Salesforce — Density settings in Lightning](https://developer.salesforce.com/blogs/2018/08/new-density-settings-for-the-lightning-experience-ui-in-winter-19)
- [Raycast API — Grid](https://developers.raycast.com/api-reference/user-interface/grid) · [Raycast Manual — Settings](https://manual.raycast.com/settings)
- [MDN — prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion) · [Material — Motion speed](https://m2.material.io/design/motion/speed.html)
- [Apple HIG — Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers)
