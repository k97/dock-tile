# Dock Lock: one anchor per display setup (issue #37)

## Goal

Dock Lock remembers the anchor display per **display setup**, so moving between home, work and a TV
never needs a re-pick. Owner decisions (2026-11-08):

1. **A setup is the exact set of connected displays** (non-mirrored, by display UUID). Work with one of
   its two monitors missing is a different, unknown setup.
2. **An unknown setup leaves the Dock alone** (behaves as Default) until an anchor is picked on it.
3. **Picker only, no setups list.** The existing "Lock Dock to" picker sets the anchor for the setup
   you are on; picking Default there forgets that setup. One new footer line says choices are per setup.

## Grounded

- `DockLockManager` (DockTile/Managers/DockLockManager.swift) stores ONE anchor UUID in
  `UserDefaultsKeys.dockLockAnchorUUID`: `persistedAnchorID()` reads it, `persistAnchor()` writes it,
  `migrateLegacyAnchorIfNeeded()` migrates the older raw-ID key into it.
- `resolveAnchorFromPersisted()` (display change) moves the Dock only when the anchor goes 0 → display
  (`wasAbsent`). A direct home→work change (anchor display A → display B, both non-zero) would NOT
  move the Dock under per-setup anchors — must change.
- The login spawner (DockTile/App/LoginTileSpawner.swift:44) decides "Dock Lock ready" with
  `DockLockManager.anchorIsActionable(anchorUUID:connectedUUIDs:)` on the single key.
- `connectedDisplayUUIDs()` (CoreGraphics, mirrors counted once, works without NSApplication) is the
  set the spawner already uses; the setup key is built from it.

## Design

**Plan gate (2026-11-08) → owner answers.** The gate returned Needs answers on two points; the owner chose:
4. **A display change waits for the displays to settle, then moves once** to the final setup's anchor (a
   dock adds displays one at a time, and each in-between set is its own setup).
5. **The old single anchor keeps covering every setup it is in** until the user picks something there
   (Default included). Nothing changes on update.

**Storage.** New `UserDefaultsKeys.dockLockSetupAnchors`: `[String: String]`, setup key → anchor UUID,
or `""` for an explicit Default (so the old anchor does not re-apply where the user chose Default).
Main-app domain (the spawner is the main binary, same domain). Setup key = the connected UUIDs sorted and
joined with ",". The reader AND the writer build it from `connectedDisplayUUIDs()` only, never from
`displays` (NSScreen).

**The old anchor (`dockLockAnchorUUID`) becomes a read-only fallback**: no migration, no claim, never
removed, never written again (the raw-ID → UUID migration that fills it for very old installs stays).
New installs never have it.

**Pure seams** (`DockLockManager`, `nonisolated static`; `anchorIsActionable` is replaced):

```swift
nonisolated static func setupKey(_ connected: [String]) -> String
nonisolated static func resolveAnchor(connected: [String], remembered: [String: String],
                                      legacy: String?) -> String?
nonisolated static func remembered(_ remembered: [String: String], picking anchor: String?,
                                   connected: [String]) -> [String: String]
```

`resolveAnchor`, in order: fewer than 2 connected → nil. The setup has an entry: `""` → nil; anchor
connected → it; else nil. No entry: legacy connected → legacy; else nil (unknown setup, decision 2).
`remembered(picking:)` sets the current setup's entry to the anchor, or `""` for Default (nil), and
touches no other entry.

**Engine.**
- `persistedAnchorID()` → `resolveAnchor(connectedDisplayUUIDs(), dict, legacy)` → live ID.
- `persistAnchor()` → writes `remembered(dict, picking: uuid, connected: connectedDisplayUUIDs())`.
- `resolveAnchorFromPersisted()` → set the live anchor at once (zones must match the screens now); when
  it drops to 0, cancel any move as today. Then ALWAYS `scheduleMoveAfterDisplayChange()`: one move
  1.5 s after the last change of a burst, only while an anchor is connected beside another display
  (its guard, unchanged). The immediate `display_reconnected` move is removed, so every display-change
  move has reason `displays_changed` (an analytics VALUE, no GA4 registration; the already-home event
  stays skipped for it).
- One non-verbose `docklock` log line when the resolved anchor changes:
  `setup of N displays → anchor <name>|none`.
- Fix the `resolveAnchorFromPersisted` doc comment and grep the old behaviour's words
  ("plugging it back in", "display_reconnected", "single anchor").

**Spawner.** `dockLockReady` = enabled && AX trusted && `resolveAnchor(...) != nil` (never writes).
Accepted risk (gate F3): if a display is not yet enumerated when the spawner runs, a known setup reads
as unknown and the main app stays closed for Dock Lock until opened.

**UI.** `DockLockSettingsView` unchanged except one new caption in the picker section's footer, above
the existing note: new key `settings.dockLock.perSetupNote`, "Each set of connected displays remembers
its own choice." (en-GB/en-AU/en-US + machine zh-Hans/ja/de/ru/fr via `l10n.py`).

## Out of scope

A setups list / Forget buttons (decision 3), naming setups, partial-overlap matching (decision 1),
analytics changes.

## Invariants

- An unknown setup never moves the Dock, even when another setup's anchor display is connected.
- The spawner never starts the main app for Dock Lock on an unknown setup (the 2026-11-07
  "contextual" rule, now per setup).
- An existing user's single anchor holds in every setup it held in before, until they pick there.
- Mirrored displays count once (unchanged).

## Tests (`DockLockSetupTests`, replaces `DockLockReadinessTests`)

Each with the value that would make it fail:
- `setupKey` is order-independent (fails if unsorted).
- Known setup → its anchor; `""` entry → nil.
- **Unknown setup with another setup's anchor connected → nil** (fails under a "last anchor" fallback).
- Single display / empty → nil (carried from `DockLockReadinessTests`).
- Old anchor: used in any 2+ setup without an entry that includes it; NOT used where the setup has its
  own entry, including `""` (fails if Default does not stick); not used on one display.
- `remembered(picking:)`: sets only the current setup; Default writes `""`; other setups untouched (fails
  if Default deletes another setup's entry); writer key == reader key for the same displays in another
  order (fails if the writer does not sort).

## Verify

1. `xcodebuild test … -only-testing:DockTileTests/DockLockSetupTests` + the full suite (per-suite counts).
2. `python3 -I Scripts/l10n/l10n.py check` + the l10n unittest (new string).
3. Hands-on on the owner's 3-display Mac (dev build, owner present): pick an anchor with all 3
   connected; unplug one (new setup → Dock left alone, log says unknown); pick another anchor there;
   replug (first anchor comes back, Dock moves, log line); unplug again (second anchor comes back).
   Every move lands ~1.5 s after the last display appears, one warp per plug-in.
   Spawner: log out/in on a known 3-display setup and on an unknown one; read
   `main app starts|stays closed (… Dock Lock ready N)`.
4. Rules: dock-lock.md (storage + "unplug → Default, replug → re-anchors" bullets), menu-bar.md and
   testing.md (`anchorIsActionable`) — update all.
