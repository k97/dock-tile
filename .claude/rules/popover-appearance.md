# Popover Appearance (per-layout settings)

App-wide controls for how every tile's Dock popover looks — Popover Size, Tile Size, Animation,
Spacing, Highlight on Hover, plus Grid-only Show Labels. **Grid and List are configured
independently** (see below). Reached via **Settings → General → Appearance** — a `NavigationStack`
drill-down inside `GeneralSettingsView` (NOT a separate sidebar pane), titled "Appearance" with a
"‹ General" back. Per-tile Grid/List (which layout a tile uses) still lives on Tile Detail.

- **Per-layout, independent configs (critical)**: Grid and List are configured **separately** —
  `PopoverSettings.load(layout:)` / `.persist(layout:)` read/write a distinct key namespace per
  layout (`popover.grid.*` vs `popover.list.*`). A grid tile loads `.grid`, a list tile `.list`
  (`StackPopoverView`→grid, `ListPopoverView`→list). List has **no** `showLabels` key (a list popover
  always labels its rows) — `persist(.list)` skips it and `load(.list)` resolves it to `true`. The
  pane's **Layout** segmented control is a **panel switcher labelled "Configure", NOT a persisted
  setting**: it selects which independent config (`gridDraft`/`listDraft`) the form edits and the
  preview shows. Every control handler routes through the *active* config (via `activeDraft`); Show
  Labels writes only the grid config and its row is hidden on List (replaced by a static note). Reset
  resets only the active config; Save commits both. Guarded by `gridAndListPersistIndependently` /
  `listSkipsShowLabels` tests.
- **Persistence**: all keys live in the **shared suite** (`com.docktile.shared`, like analytics
  consent), so HELPER processes — which actually render the popover — read the same values. Defaults
  in `PopoverSettings.default` keep absent keys roomy. Model: [PopoverAppearance.swift](../../DockTile/Models/PopoverAppearance.swift).
- **Explicit save (draft/commit), NOT auto-save**: the pane is no longer `@AppStorage`-backed.
  Edits stage into a `@State draft: PopoverSettings`; only the **Save** toolbar button writes them to
  the shared suite via `PopoverSettings.persist()` (the symmetric counterpart to `load()`). A
  `savedBaseline` drives dirty state. **Reset to Defaults** stages `.default` into the draft (still
  needs Save to commit). HIG toolbar placement (`.primaryAction`): Reset is a secondary **icon-only**
  button (`arrow.counterclockwise`, `.bordered`, `.labelStyle(.iconOnly)`) with a `.help("Reset to
  Defaults")` tooltip + accessibility label; Save is the trailing primary (`.borderedProminent`, ⌘S).
  Save disables when not dirty, Reset when already at defaults. Save styling (Tahoe toolbar quirks):
  the label is forced `.foregroundStyle(.white)` because the toolbar otherwise tints a
  `.borderedProminent` label the accent colour (blue-on-blue, unreadable in light mode); and the
  disabled look is a uniform `.opacity(0.45)` on the whole button — `.disabled()` alone dims only the
  label there (bright fill + faded text), and `.tint(_.opacity())` is ignored by the prominent fill,
  so fading the rendered button is the only way to get one evenly-dimmed "disabled blue". The live preview renders the **draft** (not the shared suite) via a new
  `settingsOverride: PopoverSettings?` param on `StackPopoverView`/`ListPopoverView` (nil in the real
  popover, which always loads saved values), so unsaved edits preview without persisting.
- **Apply-on-Save (push to running helpers)**: persisting alone only affects the *next* popover open.
  So after Save, if any tile is pinned, the pane offers to push immediately:
  `HelperMigrationManager.reapply(_:)` rebuilds + relaunches every visible helper (reusing the launch
  migration's batch + single Dock restart) so their popovers adopt the new look now. Gated by a
  one-time confirmation (the Dock restarts) remembered in
  `UserDefaultsKeys.hasAcknowledgedPopoverApplyRestart`. **Read/write that consent with explicit
  `UserDefaults.standard`, NOT `@AppStorage`** — a cross-process cfprefsd cache split made `@AppStorage`
  read a stale `true`, silently skipping the prompt. Save shows an "Applying…" spinner during the
  rebuild (`@State isApplying`).
- **Pure metrics seam** (`PopoverMetrics`, `PopoverSettings.resolve`): the single source of truth
  mapping tiers → concrete sizes. Drives BOTH the live preview and the real `StackPopoverView` /
  `ListPopoverView`, so they can't drift. Unit-tested (`PopoverMetricsTests`). Popover Size = grid
  column count (Small 4 / Medium 5 / Large 6) **capped at the app count** so few-app tiles stay tight
  — meaning Popover Size is a visual no-op for a tile with ≤4 apps (the preview uses 6 sample apps so
  all three tiers differ). Animation is forced to 0 when system Reduce Motion is on.
- **Applied to real helper popovers** (per-tile by layout): `LauncherView` routes each helper to
  `StackPopoverView` (grid tiles) or `ListPopoverView` (list tiles) by the tile's own
  `layoutMode`; each reads its own config via `PopoverSettings.load(layout:)` (grid tiles `.grid`,
  list tiles `.list`) from the shared suite, so each tile is styled by the matching layout's config. `FloatingPanel` sizes the NSPopover from the SwiftUI
  content (`NSHostingController.sizingOptions = [.preferredContentSize]`) — NOT a hard-coded size —
  so Popover Size / Tile Size / Spacing / Labels actually resize the real Dock popover to match the
  metrics-driven content (and the preview). The popover content is rebuilt on every `show()`, so a
  running helper re-reads settings on the next open; existing helpers pick up the feature when they
  are regenerated (Update-after-edit, or the version-bump migration pipeline).
- **Live preview = the real panels** (critical): the hero embeds the actual `StackPopoverView` /
  `ListPopoverView` (not a mock) for true 1:1 fidelity, re-`.id(previewSignature)`'d on every control
  change so they re-render the active draft (passed in via `settingsOverride`, not a suite read). Two
  view flags keep this safe (both default to shipping
  behaviour): `showsBackground:false` lets the preview supply its own popover chrome (NSPopover's
  rounded surface is lost when embedding the bare content view — reproduce it with the `.popover`
  material `withinWindow` + ~14pt continuous corner + shadow); `isPreview:true` keeps the panel
  interactive for hover yet neutralises every action (clicks never launch apps / open the
  configurator). The preview hero sits on the shared `StudioCanvasBackgroundView` (same
  `underWindowBackground` treatment as the Customise-Tile studio).
- **Hover highlight**: mouse hover uses the subtle Liquid-Glass `.quaternary` fill (the Tahoe
  treatment), NOT the bold accent — the accent is reserved for keyboard-focus selection. Applies to
  the real popover too. The preview scales with `.scaleEffect` (a *fixed* per-layout fit, not a
  width-refill, so Spacing changes stay visible); `.scaleEffect` preserves `.onHover` hit-testing.
