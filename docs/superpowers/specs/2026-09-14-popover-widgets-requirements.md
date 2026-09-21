# Popover Widgets — requirements (issue #14)

Grilled and agreed 2026-09-14. Source: https://github.com/k97/dock-tile/issues/14

## Decision: real system widgets, spike-gated

- **What**: the user's own macOS widget instances (Calendar, Weather, Stocks, any third-party
  widget) rendered inside a tile's popover. Not DockTile-built imitations.
- **Fact that shapes everything**: Apple ships no public API for hosting other apps' WidgetKit
  widgets. Hosting is done by system processes (Notification Center / Desktop / chronod) via
  private frameworks (`ChronoKit`, `ChronoServices`, `ChronoUIServices`, `WidgetRenderer` exist
  on macOS 26). No shipping third-party Mac app hosts system widgets; the "widget apps"
  (WidgetWall, MacWidget, FavTray) render their own.
- **Gate**: a ~2-day throwaway spike in a worktree before any product code. Pass conditions:
  1. An ad-hoc-signed DockTile helper (as shipped) shows one system widget (e.g. Calendar small)
     inside its existing NSPopover.
  2. On a stock Mac: SIP on, no AMFI flags, no entitlements notarization would reject.
  3. The widget refreshes at least once while open, or on reopen.
  Fail any one → stop, reply on the issue with findings, choose between DockTile-native cards
  and closing.
- **Hosting order inside the spike**: live hosting (ChronoKit remote views) first with a
  half-day cap → snapshot hosting (display the system's already-rendered timeline entry as an
  image). **Snapshot counts as a pass**; in-widget interactions are a stretch goal only live
  hosting can deliver.
- **Process order**: helper-direct first. If only the main app can reach the machinery, the
  main app becomes a broker (renders/fetches snapshots into the shared support folder, helpers
  display files) and stays resident like Dock Lock does; stale-snapshot placeholder when it
  isn't running.

## Product shape

- **Grid layout only, iPhone-home-screen style**: widgets are items in the tile's ordered list
  alongside apps. Small = 2×2 app cells, medium = 4×2. No large. Flow-packed in reading order
  at 4/5/6 columns (Popover Size), apps pad the remainder. Packing + height live in the pure
  `PopoverPanelLayout` seam; the editor canvas reads the same seam. Editor drag-reorder /
  remove treat a widget like an app (`AppListEditor` on the mixed list).
- **Schema**: `appItems` becomes an ordered mixed app-or-widget list (v9, `decodeIfPresent`
  fallback so old configs load).
- **List layout**: ignores widgets. Editor shows "Widgets show in Grid layout".
- **Picker** (Tile Detail): lists the widget instances already on the Desktop / Notification
  Center, each with app name, widget name, size and configuration (e.g. Weather · Melbourne).
  Empty state: "Add widgets in Notification Center first" + button that opens it. A full
  gallery section only if live hosting passes.
- **Click**: opens the owning app (deep link when the widget declares one) and closes the
  popover, exactly like an app. Keyboard navigation treats a widget as one focusable item.
  Editor preview neutralises the click. In-widget controls work in place only under live
  hosting.
- **Freshness**: latest render on every popover open (content is rebuilt on `show()`), plus a
  `DispatchSource` file watcher on the render source while open. No timer. "Real-time" is
  bounded by macOS's own timeline schedule.
- **Appearance**: show the system's render for the current Light/Dark + Icon & widget style,
  pixels untouched. If only one appearance's render exists, show it unchanged. Widget keeps its
  own corner radius; popover hover/focus chrome follows existing rules.

## Shipping posture (fail closed)

- **macOS 26 only**; nothing appears on macOS 15.
- **Off by default, labelled Experimental** ("Widgets in popovers (Experimental)") for the
  first release; per-tile picker only appears when on. Flip to default-on later once a couple
  of macOS point releases pass cleanly.
- **Baked allowlist of verified macOS builds** per release. Outside it → one-line placeholder
  "Widgets paused until Dock Tile is verified on this macOS version"; no private calls made.
  Re-opened by a Sparkle release, no network kill switch.
- **Guarded rendering**: a failure degrades to the placeholder, never takes the helper's
  popover down; logged + Crashlytics non-fatal.
- **Analytics**: toggle on/off; widget added with size only; render failure with macOS build +
  failure stage. Never widget identity, owning-app bundle ID, or content. Snapshot files stay
  on disk and are never transmitted (Smart Add posture).

## Sequence

1. Design prototypes now (cheap, no code risk): grid popover at 4/5/6 columns with mixed
   widgets; Tile Detail with picker + list-layout note; Settings toggle + paused placeholder.
2. Spike.
3. Product work only on a pass, planned against the prototypes and the proven hosting mode.

## Open items (spike outputs, not design inputs)

- Whether snapshot renders exist for both appearances or only the current one.
- Whether helper file access to the render store needs a container the helper lacks
  (→ broker fallback).
- Whether a widget's deep link is readable from the render/registry for the click action.
