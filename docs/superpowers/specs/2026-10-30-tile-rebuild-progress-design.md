# Tile rebuild without a dead tile, with progress on the tile

Date: 2026-10-30. Status: approved by the owner (2026-10-31) and built on `fix/tile-rebuild-swap`.
Scope: the macOS app. Target release: 2.6.3.

## Why

On 2026-10-29 the update to 2.6.1 rebuilt the owner's pinned tiles. Both tiles stopped responding
for seconds. The owner clicked the AI Tile, got nothing, right-clicked it and chose **Force Quit**.
The system log shows that this killed **Dock Tile itself** (the main app, pid 3149) 0.4 s into its
rebuild of the tiles, not the tile:

    launchd: application.com.docktile.app [3149] exited due to SIGTERM | sent by Dock[94764]
    Dock:    Calling force quit asn=… / Dock Tile [3149] force quit

The reason, from how the rebuild works today (`HelperBundleManager.regenerateHelperBundle`,
`generateHelperBundle`):

1. The tile's helper is quit, so nothing answers a click.
2. Its bundle is rebuilt **in place** by copying the main app into the tile's folder, then rewriting
   the copy's Info.plist. For a moment the tile's folder holds a copy of the main app, carrying the
   main app's bundle id. The Dock resolves a pinned entry by bundle id (measured 2026-10-30,
   issue #35). So it matched the AI Tile's icon to the running main app, and its Force Quit
   targeted Dock Tile.
3. A second launch then re-ran the interrupted rebuild, and every tile went through it twice.

## Goals

- **A tile never goes dead or half-built while it is rebuilt.** The new bundle is built in a
  separate folder while the old helper keeps running. It replaces the old one with a single rename
  only when it is complete and signed.
- **The tile shows progress while it rebuilds (owner's pick: style C).** The icon darkens and a
  thin bar fills along its bottom edge, like a Finder copy. It fills through the stages *building
  → signing → ready*, then the tile returns to normal. (Mockups: `.superpowers/brainstorm/` in this
  repo.)
- **Clicks are ignored while the bar shows:** no popover opens and no app launches from the tile.
- **The atomic swap applies to every rebuild of a pinned tile:** the version-update migration,
  self-heal, the **Update** button in Tile Detail, and Popover **Apply** (owner agreed).
- **The bar shows only where a running helper can draw it** (owner, 2026-10-31). The bar is drawn
  by the tile's own running helper, so:
  - **Not on the update to 2.6.3 itself.** Every helper being replaced then is an older build that
    does not know the protocol. That update gets the swap (no dead tile, nothing half-built for
    Force Quit to hit) but no bar. Release notes promise only that.
  - **Not when the tile's helper is not running** (for example Start at Login is off, or self-heal
    is repairing a missing bundle). The tile is then built silently; nothing is launched just to
    show the bar.
  - Everywhere else (Update, Apply, every update after 2.6.3) the bar shows.
- **In a batch, a tile's bar clears at its own swap** (owner, 2026-10-31). Clicks work again at
  once; the new icon appears after the batch's one Dock restart. Tiles still waiting their turn
  stay fully normal: only the tile being rebuilt shows the bar.
- **A failed rebuild leaves the old tile as it was:** the bar goes away and the old helper keeps
  working (owner agreed). The failure is logged as today.

## Non-goals

- Removing the Dock's right-click menu or its Force Quit item. Apple owns that menu and no public
  API hides it. The fix is that nothing broken sits behind it.
- Avoiding the Dock restart at the end of a rebuild. Re-seating the entry and restarting the Dock
  is what makes the Dock load the new icon (architecture.md, "Refresh the Dock icon cache"). The
  owner accepted one blink of the whole Dock per rebuild batch.
- Any change to the Dock write path shipped in 2.6.2 (SIGKILL, the verified restart, self-heal).
- Issue #35 (stale Launch Services registrations) — but see the constraint on registration below.

## Anti-goals (a failure even if it technically works)

- A tile that shows the bar but still opens a broken popover or launches the wrong thing.
- A tile left showing the bar forever after a crash or failure.
- A second process (another Dock Tile launch) rebuilding the same tile at the same time.
- A tile's folder that, at any instant, carries the main app's bundle id.

## Constraints

- macOS 15 floor, Swift 6. Helpers are copies of the main app, ad-hoc signed per tile (seal must
  stay valid: `codesign --verify`).
- **Ghost mode is the default.** A Ghost helper runs as an `.accessory` app (`LSUIElement`) and has
  no Dock tile of its own; the pinned icon is a persistent entry. App-mode helpers run `.regular`.
  See the open risk below.
- The new bundle must be complete, Info.plist rewritten and signed **before** it appears at the
  tile's path. Build it on the same volume (inside the helper folder, in a hidden staging folder),
  so that the swap is an atomic rename.
- Launch Services must point the bundle id at the tile's real path after the swap
  (`LSRegisterURL`, as `touchBundle` does). The staging copy must never be left registered (that
  is the stale-registration risk of issue #35): register only the final path, and remove any
  staging leftovers on launch.
- All existing behaviour around a rebuild stays: stamp-on-success, re-seat the entry, one verified
  Dock restart per batch, relaunch, the per-tile build lock.

## Open risk: can a Ghost tile show the bar? (decided by a spike, before the plan)

Apps draw progress on their own Dock tile (`NSApp.dockTile` with a content view, then
`display()`). Unknown: whether that draws on the pinned icon of an `.accessory` helper. The spike
answers two questions on macOS 27, then on the CI runners' 15 and 26 if it works:

1. Does a Ghost helper's `NSApp.dockTile` draw on its pinned icon at all?
2. If not: does switching the helper to `.regular` for the rebuild (it then appears in ⌘Tab for
   those seconds) make it draw, and does switching back restore Ghost mode cleanly?

**Spike result (macOS 27, 2026-10-31)** — a throwaway `LSUIElement` app pinned to the owner's Dock
(written then SIGKILL; the pinned list restored byte-identical afterwards), Dock window captured by ID:

1. **No.** As `.accessory`, `NSApp.dockTile.contentView` + `display()` never reached the pinned
   icon: five captures across the bar were byte-identical and showed the plain bundle icon.
2. **Yes.** `setActivationPolicy(.regular)` for the bar's duration, then back to `.accessory`:
   the bar drew on the SAME pinned tile and filled step by step (no second tile). After the switch
   back the icon and the Ghost state were restored (no running dot, policy logged as accessory).
   The switch did **not** take focus (frontmost app unchanged, `NSApp.isActive` false).

So Ghost tiles switch to `.regular` while their bar shows. Side effects for those seconds, which
App-mode tiles already have all the time: a running dot under the tile, an entry in ⌘Tab and the
Force Quit window, and the Dock's standard right-click menu (Options, Show in Finder, Quit). Quit
or Force Quit there hits the helper itself, never the main app: the swap still lands and the new
helper launches. **Same on macOS 15 and 26 (CI, 2026-10-31, run 41164745626, throwaway branch since deleted):** on
both runners the five `.accessory` captures were byte-identical; in `.regular` the three mid-bar
captures differed from the before capture and showed the bar on the pinned tile by eye, the after
capture equalled the before one, and the log read `switch → accessory ok=true policy=1`. Focus was
not taken (Finder stayed frontmost).

**If neither works**, style C is not possible for Ghost tiles. Decided (owner, 2026-10-31): 2.6.3
then ships the atomic swap alone, and progress comes in a later release. The swap matters more
than the indicator, so the plan orders the swap first and the bar second, each shippable alone.

## Decided by the owner

- Style C (darkened icon, bottom progress bar).
- Clicks ignored while the bar shows.
- Every rebuild path gets the atomic swap; the bar shows only where a running 2.6.3+ helper can
  draw it (not on the 2.6.3 update itself, not for a helper that isn't running).
- A helper that isn't running is rebuilt silently, never launched just to show the bar.
- In a batch, each tile's bar clears at its own swap; queued tiles stay normal.
- If the spike fails, 2.6.3 ships the swap alone.
- A failure leaves the old tile working.
- One Dock blink per rebuild batch is acceptable.
- Solve it now, in this repo, as 2.6.3, not as a separate issue.

## Settled by the designer (check these while reading)

- **Update stops taking the tile off the Dock and quitting its helper before the build.** Today
  `HelperBundleManager.installHelper` (called by Tile Detail's `performDockAction`) removes the
  entry and quits the helper first, which is part of why the tile
  goes dead. The new order is: build in staging while the old helper runs and shows the bar, then
  swap, re-seat the entry, verified restart, relaunch. The old reason for removing first (stop the
  Dock relaunching a half-built app) is gone once the old bundle stays whole until the swap. The
  plan gate must check that no other code relies on the early removal (the Dock-plist watcher's
  in-flight skip, `lastDockIndex` capture).

## Left to the builder

- How the main app tells a running helper "you are being rebuilt; progress is X" (for example a
  distributed notification keyed by the tile's bundle id), and how the helper times out of the bar
  if the main app dies mid-rebuild.
- The stage boundaries and what fraction each stage fills.
- Drawing details of the bar, within the mockup's look.
- How the old helper is replaced at the swap (quit, rename, launch the new one) so that the gap
  between the old process exiting and the new one launching is as short as possible.
- How to stop two Dock Tile processes rebuilding the same tile (a lock file in the helper folder is
  one option).
