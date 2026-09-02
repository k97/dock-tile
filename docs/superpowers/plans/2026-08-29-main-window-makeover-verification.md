# Main Window Makeover — Verification Record (Task 12)

Branch `worktree-main-window-makeover`, head at time of pass: `1c480a8`
Run by the controller (implementers are barred from screen capture after three
mis-captures of unrelated windows; see "Process notes").
Dev build: `Dock Tile Dev.app` (Debug), dev config seeded with one tile — 4 installed
apps, 1 folder, 1 deliberately-uninstalled app — then restored to empty.

## 1. Visual pass (captures in `build/captures/`, git-ignored)

| Surface | Capture | Result |
|---|---|---|
| Zero tiles | `final-tile.png` | "Create Your First Tile" + single **Add a Tile…** button; sidebar shows Tiles / Settings / Dock Tile with the "No Tiles" row selected. Matches `EmptyState.dc.html`. |
| Tile Detail — Grid | `final-tile-grid2.png` | Band: title "Work" (no icon) + trash + prominent **Add to Dock** trailing. Hero: 96pt icon + Customise. Card: Tile Name / Show Tile / Show in App Switcher (Layout moved out). "In This Tile" + "Hover to remove · Drag to reorder" + Grid\|List + **+ Add**. Preview canvas renders the real app icons, the **folder** (Projects) and the **missing app** (Sketch — dashed placeholder + "Not installed"). Matches `Main.dc.html`. |
| Tile Detail — dark | `final-tile-dark.png` | Same layout; window/sidebar/cards/text all adapt via system colours, no white cards, no unreadable text. Tile face uses the Tahoe Dark icon style (existing `IconStyleManager` behaviour). Matches `MainDark.dc.html`. |
| Settings — General | `final-general.png` | No Software Update row; "Adding Tiles" section with *Suggest tiles from my apps* + the **Add a Tile…** action row. Title-only band. Matches `General.dc.html`. |
| Settings — Popover | `task6-popover.png` (Task 6) | Preview canvas hero + Configure Grid\|List + the six controls; Reset/Save trailing in the band. |
| About | `task7-about.png`, `task7-about-dark-dark.png` (Task 7) | Hero, version + Check for Updates…, Website, feedback card, "Also from Happy Machines" (studio + Spades Audio), copyright. Renders in both appearances. |

Deviation from the canvas, accepted: the preview canvas's `StudioCanvasBackgroundView`
uses `.behindWindow` blending, so in a screenshot it composites to a flat grey rather
than the canvas mock's wallpaper gradient. On screen over a desktop it shows the
intended vibrancy; this is pre-existing behaviour, not introduced here.

## 2. Flow checks

Verified during the tasks that changed each flow (see the per-task reports for the
narration and evidence):

| Flow | Where verified | Result |
|---|---|---|
| Add to Dock → Update → Show Tile off → Remove from Dock → Done | Task 9 | Pinned, re-rendered, unpinned with `savedIndex` preserved; Done disabled and logged "no Dock op, Dock NOT restarted" |
| Delete Tile (trash) | Task 9 | Alert → tile, helper bundle and Dock entry all removed |
| Helper popover unchanged (`editing == nil`) | Task 8 | Real Dock round-trip: gear present, taps launch, no × badges/captions; list keeps its two utility rows |
| Editor: hover ×, context menu, Delete key, VoiceOver Remove, drag reorder | Tasks 8–9 | All work; drag lands where released and persists across a tile switch |
| Missing apps: launch alert + inline cell | Task 12 (this pass) | Launch scan raised **Some apps are no longer installed** with Remove / Keep; Keep left the cell flagged inline ("Not installed") — non-destructive path intact |
| Add a Tile dialog from every entry point (+, General row, empty state); Smart Add off → blank row + note; Return / Esc; ⌘N direct | Task 10 | All confirmed via AX + diagnostics |
| Popover Save → apply prompt | Task 4 | Save persists; with a pinned tile the "Apply to your Dock tiles?" prompt appears as before |
| ⌘, → General; Dock-icon reopen; fixed 768pt width | Task 3 | Unchanged |
| Sparkle Check for Updates… | Task 7 | Sparkle UI appears from About |

## 3. Test suite

`xcodebuild test … -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`
Final: **406 total / 399 passed / 7 skipped / 0 failed** (baseline at branch start: 397).
New regression guards added by this branch: `AppListEditorTests` (4),
`PopoverPreviewCanvasTests` (3), `SmartAddEngineTests.addFlowAlwaysOpens` (1),
`ConfigurationModelsTests.freshTileDefaultsToPlusPlaceholder` (1), plus string
expectations inside the existing `AppStringsTests` smoke test.

## 4. Deferred minors (for the final whole-branch review to triage)

- `.focusable()` cells only take keyboard focus with Full Keyboard Access (or VoiceOver)
  enabled; the always-available non-hover paths are the context-menu **Remove** and the
  VoiceOver Remove action. A follow-up could add explicit selection state.
- `draggedItem` is cleared only in `performDrop`; a cancelled drag leaves it set
  (faithful port of the old table's behaviour).
- `AppInstallChecker.resolve(app)` is called twice per cell body in edit mode.
- Orphaned catalog keys left behind by the retired accessors (`empty.noItemsAdded`,
  `section.selectedItems`, `smartAdd.subtitle`, `empty.createFirstTileDescription`,
  `settings.popoverAppearance*`) — accessors removed, catalog entries left stale.
- `AppStrings.FilePicker.message` doubles as the **+ Add** button tooltip.
- `.toolbar(removing: .sidebarToggle)` is applied three times (only the one on the
  sidebar's `List` was proven necessary).

## Process notes

Three separate implementer sessions took raw `screencapture -R` region grabs that
captured unrelated windows — one of them the user's private messaging app. Files were
deleted immediately, were never used for judgement, and none were committed
(`build/` is git-ignored). From Task 10 onward, implementers were barred from taking
screen captures by any means; visual verification is the controller's job, and
implementers verify through the accessibility tree, logs and tests.
