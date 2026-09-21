# macOS 26: every `NSPopover` instance leaks its Liquid Glass backdrop

Found 2026-09-21 while chasing a slow memory creep in helper tiles. Status: **worked around in
Dock Tile; the system bug is open.** Re-test on each new macOS release (next: the release after
26.6.2), and file a Feedback report with Apple using the reproduction below.

## What happens

On macOS 26 (observed on 26.6.2, build 25G83) each `NSPopover` instance is given a Liquid Glass
backdrop: an `NSGlassView`, a `_NSCoreHostingView<NSGlassEffectView.RootView>` with its SwiftUI view
graph, and an `IOSurface` sized to the popover. When the popover closes and the `NSPopover` is
released, its `NSPopoverFrame` and window go away, but the glass views do not. A `leaks --traceTree`
on an orphan shows it retained by a block AppKit registers itself,
`-[NSView _commonAwake]_block_invoke`, held in an `NSNotificationCenter` registrar and never removed.

Cost: one orphaned set per `NSPopover` instance, forever. For Dock Tile that was 3–5 MB per Dock
click depending on popover size. A production 2.0.1 tile's footprint went from 85 MB to 149 MB over
six days of use; the leak is the per-click component of that, not necessarily all of it.

## Reproduction, no Dock Tile code

`docs/repro/popover-glass-leak.swift` is a self-contained AppKit program with three modes.

    swiftc -O -o popleak docs/repro/popover-glass-leak.swift
    ./popleak fresh 8 &     # new NSPopover per open
    heap $! | grep -E " NSGlassView|NSGlassEffectView.RootView"

| Mode | What it does | `NSGlassView` after 8 opens | Footprint |
|---|---|---|---|
| `fresh` | new `NSPopover` each open | 7 | 28 → 40 MB, climbing |
| `reuse` | one `NSPopover`, one content controller | none extra | 28 MB, flat |
| `swap` | one `NSPopover`, content controller released on close and replaced on open | none extra | 28 MB, flat |

## Measured on real tiles, 2026-09-21

Optimised builds swapped into the same dev tile, `footprint` before and after open/close cycles.

| 102-app tile | New popover per open | One reused popover |
|---|---|---|
| Opens 1–5 | +17 to +31 MB | +8 MB (one-time: icon cache, first window) |
| Opens 6–10 | +25 MB | 0 MB (62 → 62) |

Also checked on a bare probe: a reused popover given different-sized content on each open sizes
correctly at show (no stale frame), and `close()` on a closed popover posts no `popoverDidClose`.

## The workaround Dock Tile ships

`FloatingPanel.popover` is a `let`: one `NSPopover` per helper process, configured afresh and given a
new `NSHostingController` on every open (the `swap` row), so Popover Appearance settings are still
re-read on each click. Making it a constant blocks one specific regression, assigning a fresh
`NSPopover()` to that property per open. It does not stop someone constructing a `FloatingPanel` per
open; both current owners hold one for their lifetime. The leak itself is invisible to unit tests,
so the check is the ten-open `footprint` measurement above.

If Apple fixes the bug the workaround stays correct and costs nothing, so there is no need to
remove it.

## Related, and NOT a bug of ours: the first-popover memory spike

The first time any process displays a popover on macOS 26, its footprint spikes by roughly 220 MB
and falls straight back (bare probe: peak 14 MB with no popover shown, 234 MB after one, resting at
28 MB). A helper launched in the background and never clicked peaks at 12 MB. This was recorded in
the September 2026 baseline as a "launch spike" and wrongly attributed to decoding the config. It is
a one-time system cost of bringing up the glass rendering path; nothing in app code causes or can
avoid it. Pre-showing a popover at login would only move the cost to every tile up front.
