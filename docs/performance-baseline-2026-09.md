# Performance baseline — 2026-09-17 / 18 / 19

> **Read this first.** The document grew over three passes. The current priorities are in the
> last review section, *Third pass — 2026-09-19* → **Revised plan order**. That pass also corrects
> the main-app numbers of the 2026-09-18 whole-app run (they were Debug-build and dev-config artefacts).
> Earlier sections stay as the evidence trail; where a later pass corrected an earlier claim it
> says so. Numbers: `docs/performance-baseline-2026-09.json`.

First measured performance pass. Trigger: the popover open produces a visible CPU blip in Activity
Monitor for an app meant to feel instant. Method: the app's own `measure()` timings from the dev
diagnostics log, `sample` (1 ms interval) attached to running dev helpers while a popover open was
triggered with `open -b <helper bundle id>`, `ps` for cumulative CPU/RSS, and three independent
read-only source reviews (popover open path · helper idle/launch · main app). Machine: M3 MacBook
Pro, macOS 26.6.2, **Debug** build (dev helpers). Numbers are Debug; Release will be somewhat
faster but the shape is the same.

Treat this the way `docs/analytics-baseline-2026-08.md` is treated: compare against it after a
change ships, and log every attempt (kept or reverted) in the ledger at the end.

## Measured

### Popover open, wall time (helper's `✔ Show popover` line)

| Tile | Apps | Wall time |
|---|---|---|
| Dev Tile | 6 | 129 / 138 / 192 ms (three warm opens) |
| Work | 102 | 465 / 522 ms warm · **2250 ms** first open after launch |

### Where the time goes (main-thread samples inside `showPopover`)

`sample` records **wall-clock** stacks: a thread parked in a synchronous XPC reply is sampled under
the frame that is waiting, exactly like a thread that is computing. Samples are therefore
main-thread *time*, not CPU; the two are separated below by reading the leaf frames. The sampler
collected ~21,300 samples in 25 s, so 1 sample ≈ 1.17 ms.

**6 apps (Dev Tile)** — 39 samples (~46 ms) of main-thread time for 129 ms of wall time. The
remaining ~80 ms is the run loop between the reopen Apple event and the popover being on screen
(WindowServer round trips for the anchor window and popover window, `NSApp.activate`), which the
sampler does not attribute to `showPopover`. Of the 39:

| Frames | Samples |
|---|---|
| `NSPopover showRelativeToRect` → `_makePopoverWindowIfNeeded` → `NSHostingView.viewDidMoveToWindow` → SwiftUI preference-graph update | 13 |
| SwiftUI sizing pass (`sizeThatFits`, `LazyLayout`) | ~10 |
| `NSWindow`/`_NSPopoverWindow` init | 2 |
| `StackAppItem.body` + `AppIconLoader.icon` + `NSWorkspace.iconForFile` | 5 |
| `NSApplication activate` | 2 |

Plus 7 samples in the CoreAnimation flush after show. These frames are genuine in-process compute
(AttributeGraph, layout, window setup), so ~40–50 ms of CPU per open is the honest figure. The
per-app cost is negligible at this size; the cost is the **fixed cost of building a fresh SwiftUI
hosting graph + popover window on every open**. That is the Activity Monitor blip for a normal
tile.

**102 apps (Work)** — 400 samples (~465 ms) of main-thread time for 465 ms of wall time: the main
thread is occupied for the entire open. **But 354 of those samples are the main thread blocked in
`xpc_connection_send_message_with_reply_sync` waiting for `iconservicesagent`**, not computing.
The CPU for that work is spent in iconservicesagent (a separate process, which is where part of the
Activity Monitor jump lands); the helper's own compute for the open is on the order of 50 ms.

| Frames | Samples |
|---|---|
| `NSHostingView.layout` → SwiftUI `DisplayList.ViewUpdater` → `ImageLayer.update` → `NSImage CGImageForProposedRect` → **IconServices `generateImageWithDescriptor` over XPC** | **356** |
| `StackAppItem.body` | 13 |
| `AppIconLoader.icon(for:)` / `NSWorkspace.iconForFile` | 10 |
| Launch Services (`_LSBindingCreateWithURL`, `_LSCopyApplicationInformation`) | 8 |
| `AppInstallChecker.resolve` | 2 |
| `CA::Render::prepare_image` (upload to CA) | 22 |

**89 % of the large-tile open is the main thread waiting, synchronously, for IconServices to
rasterise each app icon at cell size over XPC, ~3.5 ms per icon.** It happens on every open because
the popover content (and every `NSImage`) is rebuilt from scratch each time; nothing is cached
in-process across opens. `Image(nsImage:).resizable()` makes SwiftUI's `ImageLayer` ask the
IconServices-backed `NSImage` for a `CGImage` at display size, and that proxy answers by a
synchronous XPC render request. Whether `.interpolation(.high)` changes the request is untested.

A further ~500 ms of wall time per open is `NSPopover`'s own appearance animation
(`-[NSAnimation _runBlocking]` on a background queue, 427 samples, almost all parked): not CPU,
but it is part of what "instant" has to compete with. `FloatingPanel.swift:201` sets
`popover.animates = true` unconditionally, so neither the app's Animation tier nor system Reduce
Motion reaches the AppKit show/hide animation (see HIG note under the plan).

The 2250 ms first open was not sampled. The reviewers' model (consistent with the warm numbers):
first-time icon generation in `iconservicesagent` for 102 apps + first SwiftUI/AppKit/Metal
initialisation in a process that is pure AppKit until the first popover + first Launch Services
and cfprefsd contact.

### Helper processes at rest

| Helper | Apps | Resident | Peak footprint | Cumulative CPU | Uptime |
|---|---|---|---|---|---|
| Media | 6 | 45 MB (`ps` RSS) | not sampled | 18.6 s | 2 d 22 h |
| Dev Tile | 6 | 42 MB (`ps` RSS) · 131–140 MB (`sample` physical footprint) | **560 MB** | 19.4 s | 2 d 21 h |
| Work | 102 | 45 MB (`ps` RSS) · 204 MB (`sample` physical footprint) | **583 MB** | 19.0 s | 2 d 16 h |

RSS and physical footprint are different metrics (footprint counts compressed and swapped pages and
IOKit/graphics memory; RSS counts resident pages only) — compare like with like when re-measuring.

Idle CPU is a non-issue: ~19 s over ~3 days each, and the idle sample showed the main thread parked
in `mach_msg` for 100 % of samples (no timers firing, no churn). Memory is the issue: a helper that
shows six icons should not have a half-gigabyte peak. The peak is the launch path decoding the
whole config file, twice (below).

### Config file

| File | Size |
|---|---|
| `com.docktile.dev.configs.json` (dev) | **130.8 MB** |
| `com.docktile.configs.json` (release) | **10.4 MB** |

`AppItem.iconData` stores each app's entire `.icns` (`ConfigurationModels.swift:500-505`), base64
in JSON. It is only ever read as the last-resort fallback in `AppIconLoader` when an app is gone.

## Findings from the source reviews (ranked; ✔ = verified by reading the code, ▲ = reviewer's estimate)

### Helpers

1. ✔ **Every helper decodes the entire config twice at launch and keeps it all.**
   `HelperAppDelegate.readShowInAppSwitcherFromDisk` (`:489-519`) decodes every tile to read one
   Bool, then `ConfigurationManager.init` decodes it again (`ConfigurationManager.swift:470-493`).
   `LoginTileSpawner` does a third decode. This is the 560 MB peak, and on a cold Dock click it
   sits in front of the first popover. A helper needs one tile's few hundred bytes.
   **Side bug:** `:495` hardcodes `"com.docktile.configs.json"` instead of
   `AppEnvironment.preferencesURL`, so a **dev** helper decodes the **release** file (10 MB), never
   finds its own id, and always falls to Ghost mode regardless of the Show in App Switcher setting.
2. ✔ **Global mouse-down monitor leaks after any close that bypasses `hide()`.**
   `FloatingPanel.swift:341` installs `NSEvent.addGlobalMonitorForEvents` on every show; `hide()`
   and `cleanupPopover()` remove it, but `popoverDidClose` (`:420-437`) — the path taken by
   NSPopover's own transient close (app deactivation, Cmd-Tab, Mission Control) — does not. Until
   the tile is next clicked, that helper wakes on **every click anywhere on the Mac**. With several
   helpers in this state, every click wakes several processes.
3. ✔ **The popover is rebuilt from zero on every open** (`FloatingPanel.swift:196-222`, `:296`,
   `:420-437`): new `NSPopover`, new `LauncherView`, new `NSHostingController`, new anchor
   `NSWindow`, new global monitor, `NSApp.activate`. This is the fixed ~40 ms and the reason the
   floor is ~130 ms rather than ~16 ms. The Dock's own stack is instant because its content
   persists between shows.
4. ✔ **Per-cell I/O in SwiftUI `body`, re-run on every evaluation** (`NativePopoverViews.swift:645`,
   `:734`): two Launch Services lookups (`AppInstallChecker.resolve` then `AppIconLoader.icon`
   throws the resolved path away and looks up again), `NSWorkspace.icon(forFile:)`, and the
   IconServices rasterisation above. Runs once for the sizing pass, again in-window, and again on
   every hover flip (`:684`) — the mouse-over CPU cost. `showsMissingCaption` (`:525-528`) resolves
   every app a further time in edit mode.
5. ▲ Full Firebase Analytics + Crashlytics stack initialised in every helper before `NSApplication`
   exists (`main.swift:45-46`), for four events and crash reports. Order of 10 MB resident per
   process plus a Mach exception handler thread (visible in every sample).
6. ▲ `PopoverSettings.load` allocates a fresh `UserDefaults(suiteName:)` per panel construction;
   `DockPrefs.read()` does a `CFPreferencesAppSynchronize("com.apple.dock")` per open. Small,
   deliberate, but both could be read once and refreshed on change.
7. ✔ SpinWatchdog's 30 s `DispatchSourceTimer` has zero leeway (no coalescing) and pings the main
   thread every tick. Microseconds; keep it, add leeway.

### Main app (not measured live; ranked by the reviewer's size × frequency estimate)

1. ✔ **Every save encodes every tile with every `.icns` blob, on the main actor, atomically**
   (`ConfigurationManager.swift:457-466`, pretty-printed + sorted keys). Triggered by the 300 ms
   debounce on every Tile Detail edit. ✔ `CustomiseTileView.swift:56-71` spawns an **uncancelled**
   `Task` per change, so a colour-panel drag queues one full save per tick.
2. ▲ Helper generation blocks the main thread on `codesign --deep`, `docktile-actool`, `assetutil`,
   `iconutil`, `killall Dock` (all `waitUntilExit`) plus 1024² renders: seconds of frozen UI per
   Add/Update, × tiles at a version-bump migration. With Dock Lock on, the event tap runs on the
   main run loop, so these stalls freeze the cursor system-wide until macOS disables the tap.
3. ▲ Every Dock read (`findInDock` and siblings, `HelperBundleManager.swift:1352-1391`) parses the
   Info.plist of every non-matching Dock entry: O(tiles × Dock entries) plist reads per sync, at
   init before the first frame and on every watcher fire.
4. ✔ `DockPlistWatcher` watches a file descriptor and never reopens after `.rename`
   (`DockPlistWatcher.swift:60-86`); cfprefsd replaces the plist atomically, so after the first
   replacement the fd points at a dead inode. Needs a live check: the "live sync" may be mostly the
   init-time sweep.
5. ▲ `onChange(of: configManager.configurations)` in Tile Detail (`DockTileDetailView.swift:239`)
   reintroduces the O(icon bytes) struct comparison the `saveGeneration` counter was added to avoid.
6. ▲ Smart Add: Spotlight harvest does `Bundle(path:)` for every installed app on the main thread at
   launch and on every window appear; the launch log is JSON-written on every app activation while
   the app is resident.
7. ▲ Launch-time helper-folder scans are O(tiles²) plist parses (`findExistingHelper` called twice
   per pinned tile in self-heal).

## What to do about it (proposed order, each gated on re-measuring the same way)

1. **Cache rasterised icons across opens in the helper.** The win is doing the IconServices request
   **once per icon per process** and ahead of the click, not merely moving it off the main thread
   (the same XPC still happens; it just stops blocking the open). Shape that fits Swift 6 strict
   concurrency: an `actor` (a domain name such as `TileIconRasterCache`, not a "utils" file) that
   stores `CGImage` (Sendable) keyed by `(bundle id, pixel size, appearance)`; `AppIconLoader` is a
   `@MainActor` enum today, so the fetch path must be split out and its off-main use of
   `NSWorkspace.icon(forFile:)` + `cgImage(forProposedRect:)` verified on Tahoe (NSWorkspace icon
   queries are widely used off-main, but `NSImage` is not Sendable — only the `CGImage` crosses the
   actor boundary). **The key must include the effective appearance**: an IconServices `NSImage` is
   appearance-aware, a rasterised `CGImage` is not, and the popover already re-keys cells on
   Light/Dark and icon style. Warm at launch and after the missing-app scan; drop on appearance
   change. Expected: removes ~354 of 400 main-thread samples on the 102-app open. Target: Work tile
   < 120 ms warm. Verify with the same `sample` + `open -b` procedure.
2. **Keep the popover alive between opens** (one `NSPopover`, one hosting controller, anchor window
   and global monitor installed once) and swap the configuration. This is the pattern Apple's own
   menu-bar-popover sample uses (create the popover once, `show`/`performClose` on toggle). Expected:
   6-app open from ~130 ms to < 50 ms wall. Fix the monitor leak as part of the same change.
   **HIG note (Reduce Motion)**: make `popover.animates` follow the app's Animation tier and
   `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, so "None" and Reduce Motion actually
   remove the ~0.5 s AppKit appearance animation instead of only the content motion.
3. **Stop decoding the world in helpers**: one lightweight read of the helper's own tile through a
   named seam (`HelperTileConfigurationReader` or similar) that decodes only the fields a helper
   needs, and fix the hardcoded release path. Expected: peak footprint from 560 MB to tens of MB,
   cold first open shorter. Measure with `sample`'s footprint lines before/after.
4. **Main app saves**: stop embedding `.icns` in the config (or stop encoding it on every save), and
   cancel the previous debounce task in Customise (hold the `Task` and `cancel()` it before starting
   the next — the pattern in `DockTileDetailView`'s `.task(id:)` already does this correctly).
   Moving `iconData` out of the JSON is a **schema change**: old configs must still load
   (`decodeIfPresent`, keep the v8 fallback readable), and the blob's one remaining use (the
   uninstalled-app placeholder) needs a sidecar or an explicit decision to drop it. Then measure a
   colour drag with Instruments.
5. Everything else in the main-app list, each with its own before/after.

Each change is one experiment: land it alone, re-measure the same way, keep only if the delta
clears run-to-run noise (three opens per condition at minimum), and record it in the ledger.

Not evidence-backed yet, so not in the plan: the 82.9 % / 16 h helper spin from July 2026. Nothing
in the reviewed code loops; the idle sample is clean. The SpinWatchdog capture remains the only
way to name it.

## Validation notes (2026-09-17, same day)

Reviewed against the macOS development, HIG and architecture guidance in this repo's skills.
Corrections made to the first draft:

- The 102-app open was described as "compute-bound, 400 samples of CPU". Wrong: `sample` is a
  wall-clock sampler and the leaf frames show the main thread **blocked in synchronous XPC** to
  `iconservicesagent` for 354 of those samples. The helper's own CPU for that open is ~50 ms; the
  rest of the CPU is in iconservicesagent. Conclusion and fix are unchanged (cache, and fetch ahead
  of the click), but "move it off the main thread" alone would not reduce the work, only unblock
  the UI.
- The "~70 % waiting / ~30 % compute" split for the 6-app open was not derivable from the sampler
  and has been replaced with what is: ~46 ms attributed inside `showPopover`, ~80 ms elsewhere in
  the run loop.
- Added: `popover.animates = true` is unconditional, so the Animation tier and Reduce Motion do not
  reach the AppKit appearance animation (HIG accessibility gap, ~0.5 s of perceived latency).
- Added to the plan: the Swift 6 shape of the icon cache (actor, `CGImage`, appearance in the key,
  `NSImage` never crossing the boundary), the schema-evolution constraint on moving `iconData`, and
  the one-experiment-at-a-time rule.

Still unmeasured, stated as such: the 2250 ms cold open, every main-app finding, Release-build
numbers, and the July 2026 spin.

## Performance review — Dock Tile 2.0.1 (29), 2026-09-18, against Apple's thresholds

Run with the `macos-app-performance` skill's protocol. This section **supersedes two claims
above** (marked below). Machine-readable copy: `docs/performance-baseline-2026-09.json`.

### Conditions

MacBook Pro `Mac15,10` (10 P + 4 E cores), macOS 26.6.2. **On battery, 54 %, discharging** — do
not compare these numbers with an AC run. Thermal state Nominal (from the trace, start to end).
Machine was busy: load average 5–8 during the run. Five repetitions per measurement, first
discarded, median and spread (max − min) reported. Builds: **Release** helpers `AI Tile` (10 apps)
and `Utils` (11 apps), up 4 d 5 h, started by the login agent; **Debug** helpers `Dev Tile` (6),
`Media` (6), `Work` (102). No root: `spindump`, `powermetrics`, `timerfires` not available.
Popovers were triggered with `open -b`, which also made the Release helper send five
`popover_opened` analytics events.

### Summary

The shipped build has no hangs, idles perfectly, and a normal-sized tile opens well inside Apple's
"instant" budget **once warm**. What dominates is the **first open after the tile has sat idle**,
which is the normal case for a Dock tile: 201 ms on a 10-app Release tile and 451–522 ms on the
102-app tile (a micro hang by Apple's scale). Second: **every popover open abandons about 2 MB of
graphics memory that never comes back** (6 MB on the large tile), so helpers grow for as long as
they run. Fix the first-open cost first, and fix the memory growth in the same change.

### Measurements

| Measure | Result | Apple's threshold | Verdict |
|---|---|---|---|
| Worst main-thread block, Release 10-app tile | 201 ms (first open after idle, n = 1) | > 250 ms tools report a hang; < 100 ms feels instant | pass on hangs, **fail on instant** |
| Main-thread busy per open, Release 10-app, warm | median 31 ms, spread 14 ms (29.8 / 31.8 / 30.3 / 43.7) | < 100 ms, and "assume less than half is yours" (50 ms) | pass |
| Main-thread busy per dismiss, Release | 12–16 ms | 16.7 ms frame at 60 Hz | pass |
| Worst main-thread block, Debug 102-app tile | 474 ms (first open after idle; wall 451 / 465 / 522 across three days) | 250–500 ms is a micro hang | **fail (micro hang)**, Debug build |
| Show-call wall time, Debug 102-app, warm | median 46 ms, spread 19 ms (46 / 37 / 56 / 50 / 40) | < 100 ms | pass, Debug build |
| Cold first open after launch, Debug 102-app | 2250 ms (n = 1, 2026-09-16) | > 500 ms is a proper hang | **fail**, Debug build, not re-measured |
| Idle wakeups, all five helpers | 0 /s over 10 s | > 1 /s indicates a problem | pass |
| Idle CPU, all five helpers | 0.0 % | 1 % CPU = 1.1× idle power | pass |
| Cumulative CPU, Release helpers | 31.7 s and 28.9 s in 4 d 5 h | none published | recorded |
| Power assertions held by Dock Tile | none | must be balanced and justified | pass |
| Footprint, steady, Release | 85 MB (AI Tile), 70 MB (Utils) | no macOS limit | recorded |
| Footprint, peak, Release | 307 MB, 297 MB | no macOS limit | recorded |
| Footprint, steady / peak, Debug | 130–224 MB / 559–583 MB | no macOS limit | recorded |
| **Footprint growth per open, Release** | **+2.3 MB and +4.4 IOSurface regions per open** (85 → 97 MB, 22 → 44 regions over 5 opens; unchanged ~10 min later) | abandoned memory: a step that never comes back down | **fail** |
| Footprint growth per open, Debug 102-app | +6 MB per open (224 → 262 MB, 21 → 41 regions over 6 opens; 12 MB flagged reclaimable) | same | **fail** |
| Leaked memory, Release AI Tile | 1232 nodes, 72 KB | none published | recorded, trivial |

### Findings, ranked by user impact

1. **The slow open is "first after idle", not "every open" — supersedes the "warm 465 / 522 ms"
   rows above.** Measured: opens seconds apart cost 30–60 ms on both builds; an open after minutes
   of idle costs 201 ms (Release, 10 apps) to ~470 ms (Debug, 102 apps), all of it the main thread
   blocked in synchronous XPC to `iconservicesagent` (leaf frames, 2026-09-17). Inference: the
   rendered icons live only in iconservicesagent's cache, which evicts within minutes, and the
   helper keeps nothing because every `NSImage` dies with the popover. Because tile clicks are
   naturally minutes apart, the slow path is what users get almost every time. Smallest change:
   hold the rasterised icons in the helper (plan item 1), so the cost stops depending on another
   process's cache. Revised projection: first-after-idle drops to the warm figure, i.e. **~85 %
   on a 10-app Release tile (201 → ~30 ms) and ~90 % on the large tile**; back-to-back opens are
   already fast and will not move much.
2. **Every open abandons graphics memory.** Measured with five repetitions per build, as the
   generational method requires: IOSurface regions and footprint step up on each open and do not
   return. After four days of ordinary use the Release AI Tile held 46 MB of IOSurface with its
   popover closed. Not a leak in the `leaks` sense (that tool reports 72 KB) — it is reachable,
   never-reused backing store. Inference: a window or layer tree created per open (popover window,
   anchor window, visual-effect backing) outlives `popoverDidClose`. macOS has no memory limit, so
   the cost is compression and system-wide pressure rather than a crash, growing with uptime ×
   usage across every helper. Smallest change: reuse one popover and one anchor window (plan
   item 2), then re-run this exact test; if regions still climb, take two memory graphs
   (`leaks --outputGraph`) and diff them with `heap --diffFrom`.
3. **Launch spike reproduces on Release**: 297–307 MB peak against 70–85 MB steady, with a 10 MB
   config. Consistent with the double whole-config decode (plan item 3). Measured as a peak
   figure only; the launch itself was not traced.
4. **Idle behaviour is exemplary** and should be protected: zero wakeups, zero CPU, no
   assertions. The monitor-leak finding (every system click waking a helper) did not show in this
   10-second idle window because no clicks occurred during it; it stays a code-verified finding,
   not a measured one.

### Not measured

- **Main app** (launch, save path, helper generation): the Debug product fails `codesign --verify`
  (post-test state), and the repo rule is not to launch it unsigned; the Release main app was not
  launched to avoid its launch-time reconcilers writing to production data uninvited.
- **Launch to first frame**: no signpost exists from `main` to first frame, and Instruments' App
  Launch lifecycle table is empty on macOS. Add the signpost or an `XCTApplicationLaunchMetric`
  UI test to get it.
- **Release build of a large tile**: the only 102-app tile is a Debug helper.
- **QoS distribution, per-cluster residency, timer attribution, cross-process lock holders**:
  `powermetrics`, `timerfires`, `spindump` need root.
- **Thread Performance Checker**: needs a Run from Xcode.
- **AC power**: every figure here is on battery.
- Instruments' own `potential-hangs` table came back empty for the attach-mode trace even where
  the run-loop data shows a 474 ms busy interval; the busy intervals were therefore computed from
  the `runloop-events` table using Apple's definition (time between two waiting-for-events
  periods on the main run loop).

## Whole-app review — 2026-09-18, second run (main app + helper lifecycle)

Extends the review above from the popover path to the rest of the app. Same skill protocol, same
machine. **This section changes the priority order**: the main app's problems are an order of
magnitude larger than the popover's, and most of them share one root cause.

### Conditions

`Mac15,10`, macOS 26.6.2, **battery 27 % → 21 %, discharging**, Low Power Mode off, thermal
Nominal, load average 5–7. **Debug build** of the main app (rebuilt signed; `codesign --verify`
passes) against the **130.8 MB dev config** — both inflate absolute numbers. The release config is
10.4 MB (12.6× smaller), so anything that scales with config bytes will be much smaller for real
users; where a figure is config-bound that is stated, and the release-scale estimate is marked as
an estimate. UI driven through Accessibility (`set selected`, `click`, `set value`), never
synthetic mouse movement. Main-thread blocks are the main run loop's busy intervals (Apple's hang
definition) computed from the trace's `runloop-events` table.

### Measurements

| Measure | Result | Apple's threshold | Verdict |
|---|---|---|---|
| Launch to first window on screen | median 1174 ms, spread 31 ms (1174 / 1199 / 1168) | none published for macOS | recorded |
| Main-thread blocks right after the window appears | 453 ms + 197 ms | > 250 ms reported as a hang | **fail (micro hang)** |
| Usable after launch (window + blocks) | ≈ 2.4 s | none published | recorded |
| Select the 102-app tile, first time | **3665 ms** | > 500 ms is a proper hang | **fail** |
| Select the 102-app tile again | 333 ms | 250–500 ms micro hang | **fail** |
| Select the 6-app tile | 711 ms; **1796 ms** when arriving from a Settings pane | > 500 ms | **fail** |
| Open Settings → Popover | 281 ms | 250–500 ms micro hang | **fail** |
| Open Settings → General | 61 ms | < 100 ms | pass |
| Open the Smart Add sheet | 148 ms | < 100 ms feels instant; 250 ms hang | pass on hangs, fail on instant |
| One edit to the tile name (render) | 97 ms and 123 ms | < 100 ms | borderline |
| **Debounced save after one edit** | **1698 ms and 1621 ms** | > 500 ms is a proper hang | **fail** — config-bound |
| Update a tile (helper generation), wall | 4266 ms (icon catalog compile 985 ms) | none | recorded |
| Update a tile, worst main-thread block | 1638 ms, plus 527 / 317 / 245 / 121 / 121 ms | > 500 ms | **fail** |
| Main app idle, window open | 0.1 % CPU, 0 wakeups/s | > 1 /s indicates a problem | pass |
| Main app footprint at launch | 370 MB (304 MB in large heap blocks) | no macOS limit | recorded — config-bound |
| Main app footprint after ~4 min of use | 591 MB, peak 684 MB; a second session reached 678 MB after one sheet and one Update | abandoned-memory pattern | **fail** |
| Helper cold launch, footprint | 343 MB steady right after launch, 558 MB peak | no macOS limit | recorded — config-bound |
| Helper cold launch, click to popover | under ~1 s (process start logged to the second); show call 98 ms | 100 ms instant | recorded |

### Findings, ranked by user impact

1. **Icon blobs inside the config are the root cause of most of the table.** Measured: a
   single-character edit blocks the main thread for ~1.65 s when its debounced save fires, because
   every save re-encodes all tiles with every app's `.icns`, pretty-printed, on the main actor, then
   writes 130 MB atomically. The same bytes account for the 370 MB launch footprint (304 MB of large
   heap blocks), the footprint climbing to 590–680 MB (each copy of the `configurations` array
   carries the blobs), the 343 MB / 558 MB helper launch, and the ~300 MB Release helper peak.
   The Update's worst block (1638 ms) matches the save cost almost exactly, so it is most likely the
   post-Update save, not signing (inference, not yet attributed by call tree). **Release-scale
   estimate**: at 10.4 MB the save would be roughly 130 ms — still over the 100 ms bar on every
   pause in typing, and it grows with every app a user adds. Smallest change: take `iconData` out of
   the hot config (sidecar or drop), honouring the schema-evolution rule.
2. **Tile selection hangs for seconds.** 3.7 s for the 102-app tile, 0.7–1.8 s for a 6-app tile.
   The 6-app figure shows this is not only per-app work. Candidates from the source review, none
   yet attributed: `.id(selectedConfig.id)` view recreation copying blob-laden structs,
   `onChange(of: configurations)` comparing every icon byte, and the editor canvas resolving and
   rasterising every icon on the main thread. **Profile this one with CPU Profiler before touching
   it** — the call tree will say which, and finding 1 may remove most of it on its own.
3. **Popover first open after idle** (201 ms Release 10-app, ~470 ms large tile) — unchanged from the
   section above; icon cache in the helper.
4. **Abandoned graphics memory per popover open** (~2.3 MB Release) — unchanged; reuse one popover.
5. **Helper generation blocks the main thread in chunks** (527 / 317 / 245 ms besides the save).
   These are the synchronous subprocess waits. Real, but a quarter the size of the save stall.
6. **Launch**: 1.2 s to a window is fine; the 650 ms of blocks immediately after it are the config
   decode and first Dock sweep landing after first paint. Config-bound; expect finding 1 to shrink it.
7. **Settings → Popover at 281 ms** renders the real popover panels as its live preview, so it pays
   the same per-cell icon cost as a popover open. Shares the icon-cache fix if the cache lives where
   both processes can use it, otherwise a main-app equivalent.
8. **Idle is clean everywhere** (main app 0.1 % / 0 wakeups; helpers 0.0 % / 0). Protect it.

### Revised plan order (measured impact first)

1. Take icon blobs out of the config hot path (finding 1). One change, expected to move: save
   stall, launch footprint and post-window blocks, main-app memory growth, helper launch peak, and
   probably the Update's worst block. Measure each of those rows again afterwards.
2. Profile tile selection (finding 2) on the result of step 1, then fix what the call tree names.
3. Helper icon cache (first-open-after-idle).
4. Reuse one popover + anchor window; wire `animates` to the Animation tier and Reduce Motion; fix
   the global-monitor leak.
5. Helper reads only its own tile; fix the hardcoded release config path.
6. Subprocess waits off the main actor in helper generation; cancel the previous debounce task in
   Customise.
7. The remaining source-review items, each with its own before/after.

### Not measured in this run

- **Customise view** (colour drag, icon size stepper): needs continuous pointer input, which was
  not synthesised. The uncancelled-save finding there stays code-verified only.
- **Popover hover and keyboard navigation**: same reason.
- **Dock Lock event tap**: Dock Lock is off in the dev build and enabling it needs an Accessibility
  grant; per-event cost unmeasured.
- **Launch migration / self-heal batch**: all dev helpers are current, so the batch did not run.
- **Release build of the main app**: a Release build uses the production data paths, and its
  launch-time reconcilers write production data. To get Release numbers safely, build Release-level
  optimisation into the Debug configuration, or point a Release build at a copy of the production
  config.
- **List-layout popover**, **Smart Add suggestion compute with a cold Spotlight cache**, QoS
  distribution, timer attribution (root).
- Launch-to-first-frame proper: the figure above is first window on screen from a window-server
  poll, the closest available proxy without a signpost.

### Incident during this run

One batch of synthetic keystrokes (Cmd+A, then the text "Dev Tile") was delivered to VS Code
instead of Dock Tile because focus had moved between two commands. No tracked file changed on
disk. The dev tile's name was briefly saved as "x" and restored. All later input used Accessibility
value-sets and clicks, which target a process rather than the focused app. Rule for future runs:
never send raw keystrokes while driving the app.

## Third pass — 2026-09-19: the "not measured" list, and a correction to the main-app numbers

Closes most of the gaps left by the two runs above. **The headline is a correction**: yesterday's
multi-second main-app hangs were mostly artefacts of measuring a Debug build against the 130 MB dev
config. On an optimised build with a release-sized config the main app has **no hangs in ordinary
use**. Two real-user problems remain in the main app (the Customise colour drag and helper
generation), and the popover findings stand unchanged.

### Conditions

`Mac15,10`, macOS 26.6.2, **battery 97 % → 91 %, discharging**, Low Power Mode off. No root.
Builds: (a) **optimised build** — the Debug configuration compiled with `-O`, whole-module, no
debug dylib, no testability, in a separate build folder, so it keeps the dev data paths; (b) the
standard Debug build for flows that regenerate helpers. Configs: the 130.8 MB dev config, and a
**release-sized test config** — a copy of the 10.4 MB production config (2 tiles, 10 and 11 apps)
with both bundle IDs rewritten to the dev prefix so the dev app treats them as never pinned
(verified in its log: "visible but never pinned — not hiding"; no Dock entry matched). The dev
config was restored afterwards and verified byte-identical by checksum. Pointer input came from a
guarded tool that refuses to post unless the topmost window under the target belongs to the
process being measured; arrow keys were posted to a process ID, never to the focused app.

### Debug versus optimised, same 130 MB config

| Measure | Debug (2026-09-18) | Optimised | Reading |
|---|---|---|---|
| Launch to first window | 1174 ms | 1133 / 1146 ms (first run 2232 ms discarded) | data- and framework-bound, not code-bound |
| Select 102-app tile, first time | 3665 ms | **686 ms** | ~80 % of yesterday's figure was unoptimised Swift |
| Select 6-app tile | 711 / 1796 ms | 196 / 208 ms | same |
| Select 102-app tile, warm | 333 ms | 173 + 90 ms | same |
| Debounced save after one edit | 1698 / 1621 ms | **420 / 567 ms** | still a hang at this config size |
| Footprint after use / peak | 591–678 MB / 684 MB | 621 MB / **948 MB** | data-bound; optimisation does not help |

### Optimised build, release-sized config — what a real user gets

| Measure | Result | Apple's threshold | Verdict |
|---|---|---|---|
| Launch to first window | median 645 ms, spread 49 ms (664 / 615 / 645) | none published | recorded |
| Select a tile (10–11 apps) | 114 + 54 ms · 142 ms · 75 + 71 ms warm | < 100 ms instant; 250 ms hang | pass on hangs, just over instant |
| Open Smart Add sheet, seconds after launch | 230 ms | 250 ms hang | pass on hangs, fail on instant |
| One edit to the tile name (render) | 24 / 37 ms | < 100 ms | pass |
| Debounced save after one edit | **98.9 / 96.5 ms** | < 100 ms | borderline — and grows with every app added |
| Customise: one stepper step | ~25 ms render, then a 91–97 ms save, **one save per step** | < 100 ms | borderline each; they queue |
| **Customise: 4 s colour-wheel drag** | main thread saturated for the whole drag: 28 blocks ≥ 50 ms, typically 85–135 ms back to back, **worst 288 ms** | > 250 ms reported as a hang; 16.7 ms frame budget | **fail** — ~8–10 fps while dragging |

### Helpers and generation

| Measure | Result | Apple's threshold | Verdict |
|---|---|---|---|
| Popover hover, 102-app grid, 287 pointer moves | nothing above ~14–18 ms | 16.7 ms frame | pass — the per-cell hover cost flagged in the source review is not significant |
| Popover open that preceded it (after idle) | 498 ms | 250–500 ms micro hang | **fail** — third independent reproduction of first-open-after-idle |
| Arrow keys, 25 presses posted to the helper | no measurable cost | — | unconfirmed: could not verify the popover was in keyboard mode |
| List-layout popover, 6 apps (Debug) | 97 ms cold launch, 31 / 26 ms warm | < 100 ms | pass |
| **Batch regeneration, 3 helpers** (Settings → Popover → Save → Apply; same batch as launch migration) | 5395 / 5364 ms wall | none | recorded |
| Main-thread block per helper during the batch | **957–1021 ms, six out of six** | > 500 ms is a proper hang | **fail** — one ~1 s hang per tile |
| Icon catalog compile per helper | 842–941 ms | — | this is the block: a synchronous subprocess wait on the main actor |

### What changes

1. **Main-app hangs in ordinary use are a developer-machine problem, not a user problem.** Tile
   selection and saves pass Apple's hang threshold on release-scale data. They sit right at the
   100 ms "instant" bar, and the save scales with config bytes, so taking icon blobs out of the
   config is still worth doing — for memory (300 MB helper peaks, ~950 MB main-app peak on large
   configs) and headroom — but it is no longer the first fix.
2. **The Customise colour drag is the worst main-app flow for real users**, now measured: every
   drag tick queues its own full save because the debounce task is never cancelled
   (`CustomiseTileView.swift:56-71`). Holding the task and cancelling it before starting the next is
   a few lines and should remove the saturation entirely. Best cost-to-benefit item in the list.
3. **Helper generation hangs ~1 s per tile**, attributed: the synchronous `docktile-actool` +
   `assetutil` wait. An Update is one hang; a migration or "apply" batch is one per tile.
4. **Popover findings stand**: first-open-after-idle reproduced a third time (498 ms), and hover is
   cleared.
5. New, small: **stray subprocess stderr lands in the diagnostics log and never ages out** — 65
   untimestamped `assetutil:` lines sit at the top of the dev log because the one-hour trim only
   drops lines whose timestamp it can parse.

### Revised plan order (supersedes the order in the section above)

1. Helper icon cache — first-open-after-idle is what every real click pays (201 ms Release 10-app).
2. Reuse one popover + anchor window — abandoned ~2.3 MB per open, fixed open cost, wire `animates`
   to the Animation tier and Reduce Motion, fix the global-monitor leak.
3. Customise: cancel the previous debounce task. Tiny change, removes the drag saturation.
4. Helper generation: take the compile/sign subprocess waits off the main actor.
5. Icon blobs out of the config hot path — memory peaks, save headroom, launch.
6. Helper reads only its own tile; fix the hardcoded release config path.
7. Re-measure tile selection after 5; profile only if it is still over 100 ms.
8. Diagnostics-log stray lines; remaining source-review items.

### Still not measured, and what each needs

- **Dock Lock event tap**: the dev app lacks the Accessibility grant (its pane says so). Grant
  *Dock Tile Dev* in System Settings → Privacy & Security → Accessibility, enable Dock Lock, then
  sample the main app while moving the pointer.
- **Root-only tools** (passwordless `sudo` is not available to the agent). Run and paste:
  `sudo powermetrics --samplers tasks --show-process-qos --show-process-energy -n 1`,
  `sudo timerfires -p <helper pid> -s`, `sudo spindump <helper pid> 10 -o /tmp/spin.txt`.
- **Main-app footprint on the release-sized config** — not read during that phase.
- **Keyboard navigation in a popover** — needs the popover opened in keyboard mode (App-mode tile,
  activated by Cmd-Tab).
- **Launch migration itself** — measured through the identical "apply" batch instead; the classify
  step that precedes it was not exercised.
- **A true Release configuration**, **Thread Performance Checker**, **AC power** (all three runs
  were on battery), and a 102-app tile on a Release helper.

### Side effects of this run

The Dock restarted twice (the two batch regenerations); the Media and Dev Tile helpers were
relaunched; Media was switched to List and back; Popover Spacing was changed and restored; the
Dock Lock switch was turned on and off; the one-time "apply" consent flag the run set was deleted
again. A temporary optimised build remains in the session scratch folder (`scratchpad/dd-opt`)
because its deletion was declined — remove it so Launch Services cannot resolve the dev app to it.

## Attempt ledger

| Idea | Baseline → Result | Verdict | Why |
|---|---|---|---|
| _(none yet)_ | | | |
