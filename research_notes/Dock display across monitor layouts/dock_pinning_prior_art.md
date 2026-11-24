# Prior art: macOS tools that pin, lock or anchor the Dock to one display

Researched 2026-11-10. Source code was read through the GitHub API at each repo's default branch on that date. Line numbers refer to that snapshot. Links use `blob/HEAD`, so they can drift if a repo changes later.

## Which tools exist (open source and commercial), and are they maintained?

### Takeaway
There is one popular open-source tool (DockAnchor, about 600 stars), a handful of small open-source clones (DockPin, DockCleat, darrenoakey's "DockLock", the DockGuard Hammerspoon Spoon), and two commercial families (DockLock Lite/Plus by Ihor July, and Still Dock by Little Bird Trading). The open-source tools all use the same core technique: an active CGEvent tap on the Dock-trigger band of the non-anchor displays. The commercial tools do not publish their mechanism.

### Cited Findings
**Open source**
- **DockAnchor** (bwya77, Swift, MIT). About 604 stars. Created 2025-07-01, last push 2026-07-09, latest release v2.1.0 on 2026-06-08. Distributed as a signed app and through Homebrew (`brew install --cask dockanchor`). Requires macOS 10.15+ and Accessibility. — [repo](https://github.com/bwya77/DockAnchor); [README](https://raw.githubusercontent.com/bwya77/DockAnchor/main/README.md); [Product Hunt launch, 2025-07-07](https://www.producthunt.com/products/dockanchor)
- **DockPin** (green2grey, Swift, MIT). About 24 stars. Created 2026-02-10, last push 2026-05-20. Requires macOS 13+, two or more displays, a Left/Bottom/Right Dock, and "Displays have separate Spaces" turned on. Features: per-setup profiles with auto-switch, a modifier-key override (Option), a blocked-edge warning, and a "best-effort" **Re-anchor Dock Now**. Updates through Sparkle. — [repo + README](https://github.com/green2grey/DockPin)
- **DockCleat** (aitiotekt, Swift). About 7 stars. Created 2025-12-13, last push 2025-12-14, so likely dormant. Locks the Dock to the main screen. Its code says it borrows "DockAnchor approach" event blocking. — [repo](https://github.com/aitiotekt/dock-cleat)
- **mac-dock-lock / "DockLock"** (darrenoakey, Swift). 0 stars. Created 2026-03-24, last push 2026-03-27. Locks to `CGMainDisplayID()` only. Its comments credit "DockAnchor's proven technique" for relocation. — [repo](https://github.com/darrenoakey/mac-dock-lock)
- **DockGuard.spoon** (ohyoungpark, Hammerspoon Lua, Unlicense). 0 stars. Created 2025-05-12. Submitted upstream as [Hammerspoon/Spoons PR #337](https://github.com/Hammerspoon/Spoons/pull/337), still OPEN since 2025-05-20. — [repo](https://github.com/ohyoungpark/DockGuard.spoon)

**Commercial**
- **DockLock Lite / DockLock Plus / DockLock Pro** (Ihor July, who describes himself as a "Ukrainian cybersecurity expert and reverse engineer").
  - Lite is free on the Mac App Store, with IAP at $1.99/mo, $16.99/yr or $49.99 for a full unlock, and a 7-day trial. Core locking stays free after the trial.
  - Plus is a one-time purchase that adds Shortcuts, a URL scheme, a CLI and "Dock follows mouse".
  - Pro is a website-only edition, "upcoming" or prototype.
  - The developer claims macOS 10.9+. The app is in active development: v1.4.9 (Sep 2026) added macOS 27 support. — [App Store listing](https://apps.apple.com/app/docklock-lite/id6741814079); [docklockpro.com](https://docklockpro.com); [GitHub README (no code)](https://github.com/JulyIghor/DockLockPro)
- **Still Dock** (Little Bird Trading LLC). $89.99 lifetime, plus annual and monthly plans. macOS 13+, Apple silicon, mostly tested on macOS 26. Sold as a direct download and on the App Store. Supports a Bottom/Left/Right Dock. The display lock is one of several "locks", alongside size, position, hide/show and contents. — [stilldock.com](https://stilldock.com); [guide](https://stilldock.com/guides/keep-mac-dock-on-one-monitor)
- Still Dock's guide also names a competitor, "LockMyDock". I found no product page for it. A web search returned only DockLock results. — [Still Dock guide](https://stilldock.com/guides/keep-mac-dock-on-one-monitor)

**Non-app workarounds that sources cite**
- Turn off "Displays have separate Spaces". Two costs are cited: full-screen apps are no longer per-display, and other monitors can go blank. Some lock apps require the setting ON instead. — [Still Dock guide](https://stilldock.com/guides/keep-mac-dock-on-one-monitor); [DockLock FAQ](https://docklockpro.com/faq/)
- Move the Dock to the left or right edge. It "can still move between screens". — [Still Dock guide](https://stilldock.com/guides/keep-mac-dock-on-one-monitor)
- Use `autohide-delay` (e.g. `-float 1000`) so the Dock rarely reveals. Still Dock calls this "unreliable on current macOS", and DockLock says it interferes with locking (see failures below). — [blog-45r post (self-described auto-generated, low quality)](https://blog-45r.pages.dev/blog/stop-the-dock-from-moving-across-monitors-in-macos); [Still Dock guide](https://stilldock.com/guides/keep-mac-dock-on-one-monitor)

### Inferences
- DockAnchor is the reference implementation. Two of the four small open-source tools say in their code comments that they copied its approach.
- DockPin is the only open-source tool that models display adjacency (exposed edge segments). It is the closest prior art to an "exposed-segment" design.

### Gaps
- I found no Hacker News or Reddit launch threads for these tools. The searches returned only MacRumors, Mac Power Users and Product Hunt.
- I found no product page for "LockMyDock".
- I found no evidence that any tool uses private CoreDock or SkyLight APIs to pin the Dock. See the next section.

## (a) How do they stop the Dock from moving to other displays, and what permissions do they need?

### Takeaway
Every open-source tool installs an active `CGEvent` tap (`.cgSessionEventTap`, `.headInsertEventTap`, `.defaultTap`), which needs Accessibility. When the pointer enters a thin band (5–10 px) along the Dock edge of a non-anchor display, the tool either **drops** the event (DockAnchor, DockCleat, mac-dock-lock) or **rewrites its location** 7 px inward (DockPin). DockGuard posts a synthetic event 1 px up instead. The commercial App Store editions say core locking needs **no** extra permission. Their mechanism is unpublished, and the vendors' own statements conflict.

### Cited Findings
- **DockAnchor tap.** Mask is `mouseMoved` + `tapDisabledByTimeout` + `tapDisabledByUserInput`. The tap re-enables itself when disabled. — [DockMonitor.swift L552–L593](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L552-L593)
- **DockAnchor block rule.** `handleMouseEvent` returns `nil`, which swallows the event, when `shouldBlockDockMovement` holds. The trigger zone is the **full width** of each non-anchor display's Dock edge, 10 px deep. For a bottom Dock: `CGRect(x: frame.minX, y: frame.maxY - 10, width: frame.width, height: 10)`. — [L916–L943](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L916-L943), [L1072–L1097](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L1072-L1097)
- **DockAnchor hot corners.** It has a 1 px corner zone (`cornerZoneSize = 1`). The first corner event passes so a hot corner can fire. The tool then warps the cursor 15 px off the edge after 10 ms and blocks further corner events. — [L120](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L120), [L945–L1008](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L945-L1008)
- **DockPin rewrites rather than drops.** `event.location = zone.nudgedPoint(from: loc)`, where the nudged point is `triggerLine - 7` for a bottom Dock. The zone for a bottom Dock runs from `cgBottom - 5` to `cgBottom + 2`. The tap mask covers `mouseMoved` **plus left, right and other `MouseDragged`**. The override modifier (default Option) passes events through. — [DockMonitor.swift L36–L60, L131–L171, L175–L200, L227–L248](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DockMonitor.swift#L227-L248)
- **DockCleat and mac-dock-lock** copy DockAnchor: a `mouseMoved`-only mask, a 10 px full-edge zone, and `return nil`. mac-dock-lock treats every display except `CGMainDisplayID()` as non-anchor. — [dock-cleat DockMonitorService.swift (startEventBlocking, getDockTriggerZone)](https://github.com/aitiotekt/dock-cleat/blob/HEAD/DockCleat/DockMonitorService.swift); [mac-dock-lock main.swift L154–L241](https://github.com/darrenoakey/mac-dock-lock/blob/HEAD/Sources/main.swift#L154-L241)
- **DockGuard.spoon** uses `hs.eventtap` on `mouseMoved`. Within 1 px of the bottom of the **current** screen (any screen, the main one included), it stops the watcher and posts a synthetic `mouseMoved` 1 px higher. It restarts the watcher after 0.1 s. Its docs warn: "If 'Automatically hide and show the Dock' is enabled, this plugin may not work as expected." — [init.lua L44–L69](https://github.com/ohyoungpark/DockGuard.spoon/blob/HEAD/init.lua#L44-L69)
- **Permissions (open source).** Accessibility only. DockAnchor: "without accessibility permissions, DockAnchor cannot prevent dock movement". If tap creation fails while permission appears granted, DockAnchor shows "Permission needs reset - remove and re-add app in Accessibility settings" (stale TCC entry after an update). — [DockAnchor README](https://raw.githubusercontent.com/bwya77/DockAnchor/main/README.md); [DockMonitor.swift L582–L589](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L582-L589)
- **DockLock (commercial): the developer's statements conflict.**
  - The FAQ says "Each DockLock app hooks into the system's Dock-relocation logic", and that core locking "needs no extra permissions in build 616 and later". An optional "Device Control and Data Access" permission "may improve Dock locking stability" and is required for auto-relocation. — [DockLock FAQ](https://docklockpro.com/faq/)
  - The GitHub README says "Fully sandboxed and secure (uses native macOS Accessibility APIs)". — [README](https://github.com/JulyIghor/DockLockPro)
  - The MacRumors post says it works "without any system modifications, hacks, or private APIs". — [MacRumors thread](https://forums.macrumors.com/threads/docklock-pro-finally-fix-macos-dock-jumping-on-multiple-monitors.2450246/)
  - The developer also claims other mouse-tracking utilities "used 20 to 80 times more CPU". This is not independently verified. — [DockLock FAQ](https://docklockpro.com/faq/)
- **Still Dock.** The direct download needs Accessibility to keep the Dock on one display. The App Store build needs it only for Presenting, Follow the mouse and Move Dock to This Screen. The App Store build "stops working while the Dock is set to auto-hide", and its locks "work by keeping your pointer away from the divider, so a determined drag can still get through". — [stilldock.com](https://stilldock.com)

### Inferences
- Still Dock's App Store wording ("keeping your pointer away from the divider", no permission needed) suggests an unprivileged approach: a global mouse-move monitor plus `CGWarpMouseCursorPosition`, neither of which needs a TCC grant. That approach cannot swallow the event, which would explain both "a determined drag can still get through" and the autohide caveat. DockLock Lite's "no extra permissions" claim fits the same model. **This is inference, not confirmed by either vendor.**
- Dropping the event (DockAnchor style) also freezes the pointer at the band edge. That would explain DockAnchor's Universal Control breakage (below), because the pointer can never cross the edge. Rewriting the location inward (DockPin) has the same effect on a fully covered edge. DockPin avoids the problem only because it never blocks covered segments.
- No tool found uses `CGAssociateMouseAndMouseCursorPosition`, private CoreDock/SkyLight calls, or a Dock restart to block movement.

### Gaps
- DockLock's and Still Dock's real blocking mechanism is unknown: closed source, and the public statements conflict.
- DockAnchor issue #7 (Universal Control) was closed as "Fixed in version 2.0" with no description. Grepping the current source for "Universal" found nothing, so the fix is not identifiable from code.

## (b) How do they move the Dock onto the chosen display on demand?

### Takeaway
Every tool that can move the Dock simulates the user. It warps the cursor near the target edge, then posts a series of synthetic `mouseMoved` events walking to the edge and dwelling there, then restores the cursor. None uses a private API or AppleScript to choose the *display*. AppleScript (`System Events › dock preferences › screen edge`) only sets the edge (orientation).

### Cited Findings
- **DockAnchor `relocateDockToAnchoredDisplay`** works in this order:
  1. Skips if there is only one display, or if the Dock is already on the anchor.
  2. Sets `isRelocating`, so the tap drops all *hardware* events but passes synthetic ones tagged with `eventSourceUserData = syntheticEventMarker`.
  3. Calls `NSCursor.hide()`.
  4. Warps to an approach point 50 px from the edge.
  5. Posts 8 `mouseMoved` events (`CGEventSource(.hidSystemState)`, posted at `.cghidEventTap`) every 15 ms, then 8 more at the edge every 25 ms.
  6. Warps back to the original position and unhides the cursor.
  The target x on a bottom Dock is configurable (left, center or right plus an offset). — [DockMonitor.swift L675–L798](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L675-L798), [L837–L914](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L837-L914)
- **mac-dock-lock** uses the same sequence (8 steps at 30 ms, then 10 at the target edge at 80 ms, about 0.7 s total). It caps at 5 attempts. The `isRelocating` window lasts 1.5 s past the restore. — [main.swift L252–L327](https://github.com/darrenoakey/mac-dock-lock/blob/HEAD/Sources/main.swift#L252-L327)
- **DockPin `DockReanchorer`** does three warp-and-post steps (18 px, 4 px, then at the edge) 70 ms apart, waits 200 ms, then warps back **and posts** a `mouseMoved` at the original point (in a `defer`). It uses `CGEventSource(.combinedSessionState)` and **does not** hide the cursor or suppress user input. The target point is the midpoint of the *longest exposed interval* of the target edge, not the display midpoint. — [DockReanchorer.swift L13–L71](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DockReanchorer.swift#L13-L71); [DisplayLayoutAnalyzer.swift L36–L56](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DisplayLayoutAnalyzer.swift#L36-L56)
- **DockCleat** sets only the edge, via AppleScript `tell application "System Events" to tell dock preferences to set screen edge to <position>`. A code comment says the "Mouse simulation methods [were] removed". — [DockMonitorService.swift (syncDockPosition)](https://github.com/aitiotekt/dock-cleat/blob/HEAD/DockCleat/DockMonitorService.swift)
- **DockLock.** After sleep or startup, it relocates the Dock to the first screen in "Allow Dock on Display". The developer: it "can't relocate the Dock when you are constantly moving the mouse or the context menu or the control center is opened." — [App Store listing](https://apps.apple.com/app/docklock-lite/id6741814079); [DockLockPro issue #9](https://github.com/JulyIghor/DockLockPro/issues/9)
- **Still Dock** offers "Move Dock to This Screen" and "Follow the mouse" (Accessibility required). The mechanism is unpublished. — [stilldock.com](https://stilldock.com)

### Inferences
- DockAnchor's restore is a bare `CGWarpMouseCursorPosition`, and Apple documents that a warp does not generate a mouse event. Its issue #35 traces stuck Dock magnification to exactly that (below). DockPin's "warp + post" restore avoids it.
- Hiding the cursor and dropping hardware events (DockAnchor, mac-dock-lock) makes the move invisible. The cost is a roughly 0.3–0.7 s input blackout that other software can notice (DockAnchor issue #39, below).

### Gaps
- No tool documents the minimum dwell or event count the Dock needs to relocate. All of them use hand-tuned constants.

## (c) How do they detect which display the Dock is on?

### Takeaway
No tool uses a public "which display holds the Dock" API, because none exists. DockAnchor reads the Dock process's AX window position. mac-dock-lock uses the `NSScreen.frame` vs `visibleFrame` inset on the Dock edge. DockPin and DockCleat do not detect it at all: DockCleat's comment says "There's no reliable API to detect which screen the Dock is on". Dock orientation is read from `com.apple.dock` `orientation` everywhere.

### Cited Findings
- **DockAnchor `getCurrentDockDisplayID`.** Reads `AXUIElementCreateApplication(<Dock pid>)` → `kAXWindowsAttribute` → `windows[0]` `kAXPositionAttribute`, then finds which display frame contains that point. Returns `nil` on any AX failure. — [DockMonitor.swift L801–L834](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L801-L834)
- **mac-dock-lock `detectDockScreen`.** For each `NSScreen`, computes the gap between `frame` and `visibleFrame` on the orientation's edge (`v.minY - f.minY` for bottom). Picks the largest gap and requires it to be greater than 2 pt, else returns "unknown". — [main.swift L431–L454](https://github.com/darrenoakey/mac-dock-lock/blob/HEAD/Sources/main.swift#L431-L454)
- **DockCleat.** "There's no reliable API to detect which screen the Dock is on". Its `getDockScreen()` just returns the screen under the mouse. — [DockMonitorService.swift (checkAndSyncDock, getDockScreen)](https://github.com/aitiotekt/dock-cleat/blob/HEAD/DockCleat/DockMonitorService.swift)
- **Orientation sources.**
  - DockAnchor spawns `/usr/bin/defaults read com.apple.dock orientation` as a `Process`. — [L1217–L1245](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L1217-L1245)
  - DockPin uses `UserDefaults(suiteName: "com.apple.dock")` and polls it every 0.5 s to catch edge changes. — [DockEdge.swift L10–L18](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DockEdge.swift#L10-L18); [DockMonitor.swift L65, L210–L220](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DockMonitor.swift#L210-L220)
  - mac-dock-lock uses the same suite read, plus the `com.apple.dock.prefchanged` distributed notification. — [main.swift L381–L425](https://github.com/darrenoakey/mac-dock-lock/blob/HEAD/Sources/main.swift#L381-L425)
  - DockCleat uses AppleScript `dock preferences`. — [DockMonitorService.swift](https://github.com/aitiotekt/dock-cleat/blob/HEAD/DockCleat/DockMonitorService.swift)
- **DockLock** says it handles cases where "macOS misreports Dock location or display ownership" by switching "internal engine modes". v1.4.4 added "automatic fallback to an alternative engine" when third-party apps break Dock configurations. — [MacRumors thread](https://forums.macrumors.com/threads/docklock-pro-finally-fix-macos-dock-jumping-on-multiple-monitors.2450246/); [App Store version history](https://apps.apple.com/app/docklock-lite/id6741814079)

### Inferences
- The `visibleFrame` inset reads zero with autohide on, so mac-dock-lock's detection returns "unknown" there and never corrects. DockAnchor's AX read works regardless of autohide but needs the Dock's AX tree to be ready (after wake or Dock restart it may not be).
- No tool uses `CGWindowListCopyWindowInfo` bounds or a private `CoreDockGetRect` for detection.

### Gaps
- I found no measurement in any tool of how reliable the AX-window-position method is across macOS 15/26/27.

## (d) How do they handle shared edges, offset layouts, side Docks, autohide, hot-plug and sleep?

### Takeaway
Only DockPin handles shared or offset edges correctly. It subtracts every adjacent display's overlap from the target edge, blocks only the **exposed** intervals of non-allowed displays, and refuses (with a warning) to lock onto a display whose Dock edge is fully covered. DockAnchor and its clones block the **whole** edge of every non-anchor display, which traps the pointer at shared edges. Hot-plug and sleep are handled by re-anchoring on wake, unlock and display-reconfiguration events after a delay, plus (mac-dock-lock) a 3 s poll. Autohide is a documented weak spot for the cursor-only tools.

### Cited Findings
**Shared and offset edges**
- **DockPin `DisplayLayoutAnalyzer`.**
  1. For the target display's Dock edge, takes the full axis interval.
  2. Collects every other display that is adjacent on that edge (within `adjacencyTolerance = 2`, e.g. `abs(other.maxY - target.minY) <= 2` for bottom, in AppKit coordinates).
  3. Merges their overlapping intervals and subtracts them.
  4. An edge is "reachable" if any remaining interval is longer than 0.5 pt.
  - Mirrored secondaries are ignored (`.ignoreMirroredSecondaries`).
  - Blocked zones are built only from the exposed intervals of non-allowed displays.
  - Allowed-but-unreachable displays are dropped. If none remain, `blockedZones = []`: the tool does nothing rather than trapping the pointer.
  — [DisplayLayoutAnalyzer.swift L59–L181](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DisplayLayoutAnalyzer.swift#L59-L181); [DockMonitor.swift L101–L129](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DockMonitor.swift#L101-L129)
- **DockPin README:** "if the Dock is set to **Bottom** and another display sits directly below the selected monitor, macOS will not place the Dock on that monitor's bottom edge. DockPin now warns when the current display arrangement blocks the selected edge." — [README](https://github.com/green2grey/DockPin)
- **DockPin issue #1 (a 2×2 stacked layout).** The maintainer: "macOS will only show the Dock on screen edges that are 'external' … there's no API or workaround for this." v2.1 added blocked-edge detection, left and right Docks, and Re-anchor. The reporter confirmed that dragging the lower monitor "down just a bit" in Arrange made the bottom edge usable. — [DockPin #1](https://github.com/green2grey/DockPin/issues/1)
- **DockAnchor** has no adjacency logic. The zone is `display.frame` full width for every non-anchor display. — [L1072–L1097](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L1072-L1097)
- **DockAnchor issue #16 (Sidecar or USB-C monitor below the primary, Dock at Bottom):** the Dock still goes to the lower screen. Maintainer: "this is an Apple thing. You cant have a dock at the bottom when there is a screen below." A commenter disagrees: the Dock *can* sit at the bottom of a display with a screen below, but "when you attach a screen below the main screen the dock automatically moves to that screen", and running the pointer along the main screen's *uncovered* bottom portion brings it back. — [DockAnchor #16](https://github.com/bwya77/DockAnchor/issues/16)
- **DockLock** requires that the display's "bottom edge must not fully overlap another display. At least a few pixels must be exposed." For vertically stacked displays: "if the top screen is smaller or the same width as the bottom one, you must offset its position slightly." The developer, on a wider-top-over-iPad layout: when reconnecting the iPad "you may see the dock still jump down, but the app will relocate it back." — [App Store listing](https://apps.apple.com/app/docklock-lite/id6741814079); [FAQ](https://docklockpro.com/faq/); [DockLockPro #4](https://github.com/JulyIghor/DockLockPro/issues/4)

**Side Docks**
- DockAnchor, DockPin, DockCleat and mac-dock-lock support left and right; DockGuard supports bottom only. DockLock Lite/Plus support **bottom only** ("Pro will also support vertical Dock positioning"). Still Dock supports bottom, left and right. — sources above; [DockLock FAQ](https://docklockpro.com/faq/); [stilldock.com](https://stilldock.com)

**Separate Spaces**
- Required ON by DockLock ("the Dock can't be properly locked per screen" without it) and by DockPin's README. DockLock Pro is advertised to work with it OFF. — [DockLock FAQ](https://docklockpro.com/faq/); [DockPin README](https://github.com/green2grey/DockPin); [docklockpro.com](https://docklockpro.com)

**Autohide**
- DockGuard: may not work. Still Dock App Store: stops working. DockLock: works only if "at least one display must allow Dock movement". — [DockGuard init.lua L22](https://github.com/ohyoungpark/DockGuard.spoon/blob/HEAD/init.lua#L22); [stilldock.com](https://stilldock.com); [DockLock FAQ](https://docklockpro.com/faq/)

**Hot-plug, display identity and profiles**
- **DockAnchor** registers `CGDisplayRegisterReconfigurationCallback`:
  - On `.addFlag` it restores the preferred anchor or auto-activates a per-display profile, then re-anchors after 1.0 s.
  - On `.removeFlag`, if the anchor is gone, it temporarily uses the built-in or primary display without overwriting the saved preference.
  - On `.enabledFlag` it waits 2 s ("firing it immediately while other displays are still coming back online can cause validateCurrentAnchorDisplay() to see a partial list").
  - It identifies displays by a fingerprint that includes the EDID serial number from IOKit, for identical monitors.
  — [DockMonitor.swift L1267–L1400](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L1267-L1400), [L17–L64](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L17-L64)
- **DockPin** saves per-display-setup profiles, auto-switched on display change with a debounce. — [AppDelegate.swift (scheduleAutoSwitch)](https://github.com/green2grey/DockPin/blob/HEAD/Sources/AppDelegate.swift)
- **DockLock** stores preferences "separately for every combination and arrangement of connected displays," so lid open and lid closed need separate setup. — [DockLock FAQ](https://docklockpro.com/faq/)

**Sleep, wake and unlock**
- **DockAnchor** re-anchors on `NSWorkspace.didWakeNotification` (3.0 s delay) and on screen unlock (1.0 s). Both go through one scheduler so that "only one sweep fires". Code comment: "macOS resets the Dock to the primary display on wake." — [DockMonitor.swift L248–L324](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L248-L324)
- **mac-dock-lock** checks on screen-parameter change, `com.apple.dock.prefchanged`, `NSWorkspaceActiveDisplayDidChangeNotification` (+0.5 s), `NSApplicationDockDidRestartNotification` (+2 s) and wake (+3 s), plus a 3 s backup timer. — [main.swift L370–L419](https://github.com/darrenoakey/mac-dock-lock/blob/HEAD/Sources/main.swift#L370-L419)
- **DockLock** developer: "when the system wakes up, macOS may push the Dock to the wrong screen, the app cannot prevent that. Instead, it detects if the Dock is not located in the 'Allow Dock on Display' setting and relocates the Dock." — [DockLockPro #9](https://github.com/JulyIghor/DockLockPro/issues/9)

### Inferences
- DockPin's interval-subtraction model is the strongest prior art for handling "another display touches the chosen display's Dock edge". DockAnchor-style full-edge blocking is the documented cause of trapped pointers and broken Universal Control.
- Wake and hot-plug re-anchoring is reactive in every tool. Each one accepts that macOS moves the Dock first and moves it back after a delay of 1–3 s.

### Gaps
- No tool documents behaviour on a display arranged with a partial offset at the *corner* (diagonal touch), or with mixed-DPI scaling at the shared edge.
- I found no source confirming whether macOS itself ignores sub-pixel or 1–2 pt exposed intervals. DockPin's 0.5 pt threshold and DockLock's "a few pixels" are both unexplained constants.

## Known failures and user complaints

### Takeaway
The recurring failures are:
- the Dock lands on the wrong display after wake, unlock or reboot (every tool);
- stacked or "display below" layouts;
- file drags slipping through a `mouseMoved`-only tap;
- Universal Control or edge crossing broken by full-edge blocking;
- side effects of synthetic relocation (stuck magnification, apps seeing "user input");
- full-screen and screen-sharing escapes;
- macOS-version regressions (Sequoia 15.0, macOS 27 ⌘Tab).

### Cited Findings
**DockAnchor**
- **#30, file drag escapes the lock.** Dragging a file to the bottom of another screen moves the Dock (v2.1.0, Sequoia 15.7.7), confirmed by two more users. The tap mask is `mouseMoved` only; DockPin includes `*MouseDragged`. — [#30](https://github.com/bwya77/DockAnchor/issues/30); [mask, L553–L556](https://github.com/bwya77/DockAnchor/blob/HEAD/DockAnchor/DockMonitor.swift#L552-L556); [DockPin mask](https://github.com/green2grey/DockPin/blob/HEAD/Sources/DockMonitor.swift#L175-L180)
- **#7, breaks Universal Control.** The pointer could not cross down to an iPad placed under a blocked monitor (macOS 26.1, a 3-wide plus 1-above layout). Closed "Fixed in version 2.0" with no detail. — [#7](https://github.com/bwya77/DockAnchor/issues/7)
- **#5, "Occasional lapse of anchoring", often after wake.**
  - One user saw the *anchor setting itself* change.
  - Another restarts DockAnchor on every wake via osascript.
  - A contributor has a fix branch.
  - Still reproducible in v2.1.0 with "secondary display … below the primary": the Dock "especially likely to move to the lower/secondary display after wake". The issue was closed despite these reports.
  — [#5](https://github.com/bwya77/DockAnchor/issues/5)
- **#38, sleep (still open).** With an external monitor above a MacBook, the Dock stays on the MacBook after sleep. — [#38](https://github.com/bwya77/DockAnchor/issues/38)
- **#29, not working after a restart** on macOS 27.0 beta. — [#29](https://github.com/bwya77/DockAnchor/issues/29)
- **#35, Dock icons stay magnified after every unlock.** The relocation's final `CGWarpMouseCursorPosition` posts no event, so the Dock's hover state never clears (macOS 26.6.2, 3 displays). — [#35](https://github.com/bwya77/DockAnchor/issues/35)
- **#39, automatic relocation after unlock interrupts ChatGPT "Locked use".** ChatGPT sees mouse movement and relocks (macOS 27.0.1). The reporter rolled back to 2.0.1 and asked for an option to disable auto-move. — [#39](https://github.com/bwya77/DockAnchor/issues/39)
- **#14, wrong monitor names, so the Dock is placed on the wrong display** (two externals got the same name). Fixed by switching to `NSScreen.localizedName`. — [#14](https://github.com/bwya77/DockAnchor/issues/14)
- **#10, disabling permission while running can freeze system input** (fixed 2.0.1). — [#10](https://github.com/bwya77/DockAnchor/issues/10)
- **#4, did not adapt to monitor configuration changes** (fixed 2.0). — [#4](https://github.com/bwya77/DockAnchor/issues/4)
- **#12, hot corners not working** (closed). — [#12](https://github.com/bwya77/DockAnchor/issues/12)
- **#33, feature request for an "Exclude Display" mode.** The user wants the Dock free between two displays but never on a third (an Elgato Prompter). — [#33](https://github.com/bwya77/DockAnchor/issues/33)

**DockLock (issues on its GitHub tracker)**
- **#3:** the Dock shows during Teams or Zoom screen sharing and in full-screen apps. — [#3](https://github.com/JulyIghor/DockLockPro/issues/3)
- **#6:** the Dock moves to a full-screen Parallels Desktop on the second display. — [#6](https://github.com/JulyIghor/DockLockPro/issues/6)
- **#7:** conflicts with `autohide-delay -float 0`; fixed with an option that "will increase CPU usage a little … because of the higher latency". — [#7](https://github.com/JulyIghor/DockLockPro/issues/7)
- **#4:** Sidecar with a stacked layout. — [#4](https://github.com/JulyIghor/DockLockPro/issues/4)
- **#12:** Lite resetting position after unlock. — [#12](https://github.com/JulyIghor/DockLockPro/issues/12)
- **#14:** Plus not working on macOS 27 (fixed in v2.1.1). — [#14](https://github.com/JulyIghor/DockLockPro/issues/14)
- **#11:** "Since upgrade to macOS 27 CMD+Tab is not tied to the Dock's current location but to the screen where the active window is". The developer: "a system limitation that DockLock cannot affect". The Important Notes page confirms it. — [#11](https://github.com/JulyIghor/DockLockPro/issues/11); [Important Notes](https://docklockpro.com/important-notes/)
- **#1:** "If macOS moves the Dock on its own … DockLock Lite can't prevent that". Later "fixed" by relocating to the first allowed screen. — [#1](https://github.com/JulyIghor/DockLockPro/issues/1)
- **App Store reviews:** core locking stopped after the trial (Jul 2025; the developer says v1.4.4 restored a free mode), and a subscription reminder at every startup (Jun 2026). — [App Store listing](https://apps.apple.com/app/docklock-lite/id6741814079)
- **Important Notes:** "certain fullscreen applications can interfere with DockLock Apps' ability to stop the Dock from jumping." It also reports a Tahoe bug where the Dock may fail to reappear "even when auto-hide is disabled". — [Important Notes](https://docklockpro.com/important-notes/)

**Still Dock**
- The App Store build fails with autohide, and a "determined drag can still get through". — [stilldock.com](https://stilldock.com)

**macOS itself**
- On Sequoia 15.0, the Dock stopped moving between displays. Apple first replied "expected", then fixed it in build 24B5046f+ (15.1 beta 6). — [Apple Developer Forums thread 757581](https://developer.apple.com/forums/thread/757581)

### Inferences
- Three classes of bug in DockAnchor follow directly from its design, and DockPin's design avoids all three:
  - the `mouseMoved`-only mask (drag escapes);
  - full-edge `return nil` (pointer trapped, Universal Control broken);
  - a warp-only restore (stuck magnification).
- Auto-relocating on *every* unlock or wake, even when the Dock is already correct or when no user is present, produces visible side effects (#35, #39). A check-first, act-only-if-wrong gate, and a way to opt out of moving the pointer, are lessons from the field.

### Gaps
- Most DockLock fixes are described only as "released an update"; the technical root causes are not public.
- I found no Reddit or Hacker News complaint threads specific to these tools.
