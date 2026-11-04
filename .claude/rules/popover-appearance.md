# Popover Appearance (per-layout settings)

App-wide controls for how every tile's Dock popover looks — Popover Size, Tile Size, Animation,
Spacing, Highlight on Hover, plus Grid-only Show Labels. **Grid and List are configured
independently** (see below). Reached via **Settings → Popover** — a **top-level sidebar pane**
(`PaneIcon.popover`), not a `GeneralSettingsView` drill-down; the old "Appearance" back-navigation
is gone. Reset/Save are `.primaryAction` toolbar items riding in the pane's title band (see
architecture.md "Sidebar Selection & Empty State" for the title-band chrome). Per-tile Grid/List
(which layout a tile uses) still lives on Tile Detail.

- **The hero's frame is FIXED on purpose — do not shrink-to-fit**: trimming the canvas to the
  current panel's height was shipped and same-day reverted (2026-09-02, revert `3c8c56e`) because
  the frame resizing on every control change made the preview "jump around" — the fixed
  `.worstCase(height: 300)` box exists precisely for that stability, and it beats reclaiming the
  dead space around a small panel.
- **Hero = `PopoverPreviewCanvas` (critical)**: the live preview is `PopoverPreviewCanvas(fit:
  .worstCase(height: 300))` — the SAME component Tile Detail's tile editor uses with `.natural` and
  an `editing` handler (see architecture.md "Tile editor = the real popover"); here `editing` is
  omitted (defaults `nil`) so it renders exactly as the real popover ships. `PopoverPreviewCanvas.fitScale` is
  the pure zoom seam that scales the fixed-size real panel into the `.worstCase` frame, guarded by
  `PopoverPreviewCanvasTests`.

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
  Save is ONE `.borderedProminent` button whose tint is the accent only while it can act
  (`canSave` = dirty and not applying), with a forced white label then; disabled or busy it takes a
  neutral `tertiaryLabelColor` tint and a secondary label. The toolbar tints a DISABLED prominent
  button's label the tint colour whatever `.foregroundStyle` says, so an accent tint read blue text on
  a blue fill (owner report 2026-10-21); fading the whole button to 0.45 did not fix it. Change
  modifier VALUES only, never the structure: swapping the button style or swapping two toolbar items
  left the toolbar showing the first-built look. Confirmed by eye (owner, 2026-10-22): Save turns accent
  after a draft edit and grey otherwise. A capture of the window in the BACKGROUND always shows it grey —
  macOS draws prominent buttons grey in an inactive window — so judge it with the window in front. The live preview renders the **draft** (not the shared suite) via a new
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
  all three tiers differ). Animation is forced to 0 when system Reduce Motion is on. The same
  decision now reaches AppKit: `FloatingPanel.shouldAnimate(tier:reduceMotion:)` sets
  `NSPopover.animates`, which used to be hardcoded `true` (Animation = None and Reduce Motion still
  got the ~0.5 s appearance animation). Guarded by `FloatingPanelAnimationTests`.
- **Pure panel-geometry seam** (`PopoverPanelLayout`, in the same file): the chrome constants and the
  grid/list **size formulas**, one level above `PopoverMetrics`. `StackPopoverView.popoverWidth` /
  `.calculateHeight`, `ListPopoverView`'s paddings AND `PopoverPreviewCanvas.naturalPanelSize` all
  read it. **Why it must stay single (critical)**: the grid pins its own width and height, but
  `ListPopoverView` pins only its **width** and takes an intrinsic height, so the canvas's estimate
  is load-bearing — the canvas frames the panel and clips to that frame, and an underestimate cuts
  the panel off. Two copies of the list formula did drift exactly there: the empty-tile case billed
  one 36pt row against a ~110pt empty state, clipping the tile-name header and the hint.
  **Past the grid's whole-panel cap (600 pt), the shipped list scrolls its rows** at the height
  `PopoverPanelLayout.listRowsScrollHeight` returns, with the header and utility rows outside the scroll
  view; `nil` (the panel fits) keeps the intrinsic layout, so lists under the cap are untouched and the
  over-reserving estimate is pinned only where its slack shortens the scroll area (2026-11-04: a 30-app
  list ran off a laptop screen). Edit mode never scrolls. Arrow-key selection does not scroll into view
  (grid and list alike; a follow-up).
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
  `underWindowBackground` treatment as the About pane). It is **full-bleed**
  (`PopoverPreviewCanvas(fullBleed: true)`, owner 2026-10-21): flush with the detail column's sides
  and the title band, no rounded card or outline, a 0.5 pt separator along its bottom edge. Tile
  Detail's editor keeps the rounded card (`fullBleed` defaults to false).
- **Hover highlight**: mouse hover uses the subtle Liquid-Glass `.quaternary` fill (the Tahoe
  treatment), NOT the bold accent — the accent is reserved for keyboard-focus selection. Applies to
  the real popover too. The preview scales with `.scaleEffect` (a *fixed* per-layout fit, not a
  width-refill, so Spacing changes stay visible); `.scaleEffect` preserves `.onHover` hit-testing.
