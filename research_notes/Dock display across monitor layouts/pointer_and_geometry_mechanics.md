# Pointer and display-geometry mechanics behind "warp the cursor to a display's Dock edge and push past it"

Scope: (1) synthetic pointer input on macOS, (2) multi-display coordinate geometry, focused on what makes a warp-then-push Dock move fail and how to detect each case. Research pass 2026-11-10. SDK header quotes are from the Xcode SDK installed on the research Mac (macOS 27 host); the matching Apple documentation pages are linked where they were found.

## 1. CGWarpMouseCursorPosition vs posted mouseMoved events; suppression; deltas; association; do synthetic events trigger the Dock?

### Takeaway
A warp moves the cursor and **posts no event**, so on its own it cannot trip anything that watches the event stream. After a warp or posted event, local hardware motion is suppressed for 0.25 s by default (adjustable per event source). The Dock's move-to-this-display trigger appears to be driven by mouse events in the session stream, not by where the cursor is: a tool that drops those events with an event tap stops the Dock from moving, and another tool reportedly moves the Dock by posting HID-level mouse moves for up to 1.5 s. No Apple source documents the Dock's trigger.

### Cited Findings
- SDK header (CGRemoteOperation.h): `CGWarpMouseCursorPosition` will "Move the mouse cursor to the desired position in global display coordinates without generating events." — [Apple archive, Controlling the Mouse Cursor](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html) says the same for both `CGWarpMouseCursorPosition` and `CGDisplayMoveCursorToPoint`: "Calling either of these functions does not generate a mouse event."
- `CGDisplayMoveCursorToPoint` takes a display ID and a point "relative to the origin or upper-left corner of the display"; `CGWarpMouseCursorPosition` takes "a point in global display coordinates." — [Apple archive, Controlling the Mouse Cursor](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
- `CGAssociateMouseAndMouseCursorPosition(false)` disconnects mouse and cursor "while an application is in the foreground"; then "all events received by your application have a constant absolute location but contain mouse delta (change in X and Y) data" (SDK header text; the archive page says the same) — [Apple archive, Controlling the Mouse Cursor](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html). The function only affects the foreground app per this text, so it is not a tool for a background agent.
- SDK header (CGEventSource.h): `CGEventSourceSetLocalEventsSuppressionInterval` "sets the period of time in seconds that local hardware events may be suppressed after posting a Quartz event created with the specified event source. The default suppression interval is 0.25 seconds." Apple's page for the deprecated global variant gives the range [0.0, 10.0] — [Apple docs, CGSetLocalEventsSuppressionInterval](https://developer.apple.com/tutorials/data/documentation/coregraphics/cgsetlocaleventssuppressioninterval(_:).md). The old global `CGSetLocalEventsSuppressionInterval` is marked `API_DEPRECATED("No longer supported", macos(10.0,10.6))` in the current header.
- Measured by a game developer (2023-02): after a warp the reported X position stayed stuck for about 0.25 s, then moved again; fix was `CGEventSourceSetLocalEventsSuppressionInterval(source, 0.0)` on a `kCGEventSourceStateCombinedSessionState` source. The post says the docs contradict themselves on whether suppression is on by default, and that in practice it is — [Colin Cornaby, Mac games and cursor warping weirdness](https://www.colincornaby.me/2023/02/mac-games-and-cursor-warping-weirdness/)
- Wine (2015) describes the same effect: a warp "effectively disassociates the mouse from the cursor position for 0.25 seconds"; during that window mouse movement doesn't move the cursor and events carry a constant location with deltas. Wine and SDL set the interval to 0 around the warp — [wine-cvs 2015-10](https://www.winehq.org/pipermail/wine-cvs/2015-October/109535.html); [SDL cocoamouse](https://hg.libsdl.org/SDL/file/841b66e4397a/src/video/cocoa/SDL_cocoamouse.m)
- Apple Forums (2024): a developer using `CGDisplayMoveCursorToPoint` found that moving the cursor to the top of a full-screen app does not reveal the menu bar the way real motion does; posting a `.mouseMoved` event at `.cghidEventTap` from a `.hidSystemState` source was tried, but the thread ended unresolved ("I'd file a DTS incident") — [Apple Forums 744024, CGMouseMove doesn't trigger menu bar](https://developer.apple.com/forums/thread/744024)
- Apple Forums: warping can get the cursor to a spot without the side effects of moving it there, which would otherwise hide the Dock — i.e. edge reactions follow motion events, not position — [Apple Forums 756199, Hide global mouse cursor on macOS dock](https://developer.apple.com/forums/thread/756199) (search-result summary; page not fetched in full)
- Apple Forums: programmatic cursor motion can trigger "shake to locate" (enlarged cursor), a side effect of posting a burst of moves — [Apple Forums 793236](https://developer.apple.com/forums/thread/793236) (title only; not fetched)
- DockLock (open source, Swift) stops the Dock relocating by running a `CGEvent.tapCreate` tap that "silently drops downward bottom-edge trigger packets on secondary monitors" — "downward edge-push packets (`deltaY > 0`)", "with no cursor bounce or `CGWarpMouseCursorPosition` lag." Requires Accessibility, Dock at Bottom and "Displays have separate Spaces" on; macOS 13+ — [omaralzare/DockLock README](https://github.com/omaralzare/DockLock)
- A pika-tools pull request ("Keep the Dock on one display…") reportedly brings the Dock back by posting "mouse moves at the HID level for up to 1.5 s and then puts the pointer back", keeps 8 pt at each edge end clear for hot corners, and stores the choice by display UUID — [dev-pikapik/pika-tools PR #48](https://github.com/dev-pikapik/pika-tools/pull/48). **Caveat:** known only from a search-result snippet; the PR returned HTTP 404 and `gh` could not resolve the repo on 2026-11-10, so the code could not be read.
- Consumer guides describe the manual trigger as pushing/holding the pointer at the bottom edge of the Dock-less display for a moment (one says "a few seconds") — [MacPaw](https://macpaw.com/how-to/move-dock-to-other-screen-mac); [Setapp](https://setapp.com/how-to/how-to-move-dock-on-mac-to-a-second-monitor)

### Inferences
- A warp alone will never move the Dock: it posts no event. The move has to come from posted `mouseMoved` events (with positive delta toward the edge) or real hardware motion after the warp.
- Because DockLock blocks the move by dropping events at a **session** tap and still lets the cursor sit at the edge, the Dock evidently reacts to the event stream after the session tap, including the delta fields. So posted events must carry a non-zero `kCGMouseEventDeltaX/Y` pointing past the edge, and they must be posted at a location upstream of the Dock's consumption (HID tap is the safe choice; posting at the session tap would also pass through any active session tap the same app installed — including its own clamp tap, which would drop them unless it whitelists its own events, e.g. by checking `kCGEventSourceUserData` or source PID).
- The 0.25 s suppression means real hand motion right after a warp is swallowed, and a warp followed immediately by posted events from a source with default suppression can briefly freeze the user's mouse. Use a dedicated `CGEventSource` with suppression set to 0.
- A single posted event is unlikely to be enough; the manual trigger needs sustained push. The pika-tools note (up to 1.5 s of posted moves) is consistent with that, but it is the only data point found.

### Gaps
- No Apple or reverse-engineering source documents the Dock's relocation trigger (distance, dwell time, whether it reads deltas or location, whether it ignores events flagged synthetic). The pika-tools code, which would be the closest prior art, was not readable.
- Not found: whether posting at `kCGHIDEventTap` vs `kCGSessionEventTap` changes whether the Dock reacts. Needs a hands-on test.
- `kCGMouseEventDeltaX/Y` semantics on posted events (whether the window server recomputes them from location) were not found in any source fetched.

## 2. Permissions: Accessibility vs Input Monitoring vs PostEvent; active taps; after re-signing

### Takeaway
macOS 10.15+ has separate preflight/request pairs for "listen" (Input Monitoring) and "post" (event synthesizing); both posting events and an active (`.defaultTap`) tap are granted through the Accessibility list in System Settings. Behaviour is inconsistent across processes and releases (Sequoia reports of `CGPreflightPostEventAccess` false while `AXIsProcessTrusted` true), so check each capability you use, not just `AXIsProcessTrusted`.

### Cited Findings
- SDK header (CGEvent.h), all `API_AVAILABLE(macos(10.15))`: `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` ("Requests event listening access if absent, potentially prompting"); `CGPreflightPostEventAccess` ("Checks whether the current process already has event synthesizing access") / `CGRequestPostEventAccess`. Apple DTS on the forums recommends this pair to manage the prompt yourself; posting "does not require any specific entitlements" but needs approval in Privacy & Security — [Apple Forums 724603](https://developer.apple.com/forums/thread/724603); [Apple Forums 820594](https://developer.apple.com/forums/thread/820594) (search-result summaries)
- Forum reports: PostEvent and Accessibility both appear as "Accessibility" in System Settings, though `kTCCServicePostEvent` is believed to be a separate TCC service; the post-event toggle "doesn't give you complete accessibility access" — [Apple Forums 820594](https://developer.apple.com/forums/thread/820594); [Apple Forums 789896](https://developer.apple.com/forums/thread/789896) (search-result summaries)
- Sequoia beta (Jul 2024): a background-only helper's `CGEventTapCreate(kCGSessionEventTap, …, kCGEventTapOptionDefault, keyDown)` returned NULL and `CGPreflightPostEventAccess` returned false while `AXIsProcessTrusted` returned true; it stopped reproducing after old builds were deleted. DTS (Kevin Elliott): grant the process that actually creates the tap, launch helpers via NSWorkspace not fork/exec, and prefer `.accessory` over `.prohibited` because "Prohibited… introduces API failures/differences" — [Apple Forums 758554](https://developer.apple.com/forums/thread/758554)
- Report: `CGPreflightPostEventAccess` "does not update while my process is running" (needs relaunch to see a grant) — [Apple Forums 744440](https://developer.apple.com/forums/thread/744440) (search-result summary)
- Revoking Accessibility while an active CGEventTap is running can make system input unresponsive / hang the app — [Apple Forums 844416](https://developer.apple.com/forums/thread/844416); [Apple Forums 735204](https://developer.apple.com/forums/thread/735204) (titles/summaries)
- App Review rejected a clipboard manager under 2.4.5 for `CGEvent.post` (non-App-Store distribution not affected) — [Apple Forums 820594](https://developer.apple.com/forums/thread/820594)
- DockLock's README notes the Accessibility entry "may appear as 'Device Control and Data Access'" on newer macOS — [omaralzare/DockLock](https://github.com/omaralzare/DockLock)

### Inferences
- An app that both runs a `.defaultTap` clamp and posts mouse moves should gate on **both** `AXIsProcessTrusted()` and `CGPreflightPostEventAccess()`; a `true` from one does not prove the other on Sequoia.
- A posted event without PostEvent access is dropped silently (`CGEvent.post` returns void), so a move that "does nothing" must be checked against the preflight before debugging geometry.
- Watch for tap disable: an active tap gets `kCGEventTapDisabledByTimeout` / `ByUserInput` callbacks and must re-enable itself (general knowledge; not sourced in this pass).

### Gaps
- No primary source fetched on how TCC treats a Sparkle-updated, re-signed Developer ID binary (the designated requirement normally survives an update with the same team ID; ad-hoc/dev signatures do not). The repo's own `docs/dock-lock-accessibility.md` covers dev-signing caveats and should be read alongside.
- No official Apple reference page for `CGPreflightPostEventAccess` behaviour beyond the one-line header comment.

## 3. Cursor clamping at edges; corners, gaps, partial overlaps, scale factors; coordinate systems

### Takeaway
The Dock will not sit on an edge segment that another display touches ("a seam"); only exposed edge segments can host it, and Sequoia 15.0 briefly broke even partly-exposed seams (users report it fixed in 15.1). Coordinates for warping/posting are Quartz global coordinates (origin top-left of the main display, points, y down); AppKit's `NSScreen.frame` is bottom-left origin, so every conversion must flip against the main display's height.

### Cited Findings
- SDK header (CGDirectDisplay.h): `CGDisplayBounds` returns "the screen size and screen origin of `display` in global coordinates, or `CGRectZero` if `display` is invalid." `CGGetDisplaysWithPoint` returns the displays containing a point (useful to test whether a point just past an edge lands on another display).
- `CGDisplayMoveCursorToPoint`'s point is relative to "the origin or upper-left corner of the display" and the example moves to `CGPointZero` = "the origin of the main display" — [Apple archive, Controlling the Mouse Cursor](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
- Apple Community, 2024-09: "You can't place the Dock on a seam between displays"; "When the external display is aligned above the macbook, its not possible to move the dock there"; others say seams worked before Sequoia and "the issue has been fixed on my computer since 15.1" (2024-11-08); one user removed a seam by "creating a gap on the right but not the left" — [Apple Community 255762225 p.3](https://discussions.apple.com/thread/255762225?page=3)
- MacRumors: "dock refuses to move from one monitor to another but will from a different monitor" (layout-dependent) — [MacRumors thread 2413807](https://forums.macrumors.com/threads/dock-refuses-to-move-from-one-monitor-to-another-but-will-from-a-different-monitor.2413807) (title only)
- r/osx 2024-08: with over/under monitors "there is still a common hard edge they both share", advice was to put the Dock on a side — [r/osx mirror](https://lr.ggtyler.dev/r/osx/comments/1erbrdo/showing_dock_on_monitor_that_is_above_another) (search summary)
- DockLock allows cursor movement across "shared top/bottom edges" of stacked monitors and filters only downward pushes on secondary displays — [omaralzare/DockLock](https://github.com/omaralzare/DockLock)
- The pika-tools PR reportedly keeps 8 pt at each end of an edge free so hot corners still work — [pika-tools PR #48](https://github.com/dev-pikapik/pika-tools/pull/48) (snippet only; see caveat above)

### Inferences
- The warp target must be on an **exposed** stretch of the target edge: compute, per edge, the segments not covered by any other display's bounds (in the same coordinate system), pick a point in the longest exposed segment, inset from the ends (corners trigger hot corners, and an edge end adjacent to another display lets the pushed cursor slide across). The posted "past the edge" location is then outside every display, which is what makes the push register as edge pressure rather than crossing.
- Test "would this push cross over?" with `CGGetDisplaysWithPoint` on the point 1 pt past the edge: non-empty means a neighbour is there and the cursor will cross instead of pressing.
- Gaps between displays don't exist in the global space in practice (System Settings snaps displays to touch), but a partially overlapping edge (different widths, offset) leaves exposed segments; identical widths stacked exactly leave none.
- Scale factors: Quartz global coordinates and `CGDisplayBounds` are in points, so mixed Retina/non-Retina displays need no pixel conversion for warping; only pixel-sized APIs (`CGDisplayPixelsWide`) differ. (Apple archive: `CGDisplayPixelsWide` "Returns the drawable width of a display in pixel units" — [Apple archive, Display Info](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/DisplayInfo.html))

### Gaps
- No source states exactly what macOS does with cursor motion at a corner where two exposed edges meet, or the minimum exposed segment length the Dock accepts.
- No primary source fetched for `NSScreen.frame`'s bottom-left origin (well known, but not re-verified in this pass).
- Whether Sequoia 15.1+ / Tahoe / macOS 27 allow the Dock on a partially-shared bottom edge is only user-reported.

## 4. Display enumeration, mirroring, sleep, virtual displays, ID churn, reconfiguration timing

### Takeaway
Use the **active** list for geometry (online includes hardware mirrors that aren't drawable), collapse mirror sets to one, skip sleeping displays, and act only on the completion phase of a reconfiguration callback, debounced across a burst.

### Cited Findings
- SDK header (CGDirectDisplay.h), `CGGetActiveDisplayList`: "The first display returned in the list is the main display (the one with the menu bar). When mirroring, this will be the largest drawable display in the mirror set, or, if all displays are the same size, the one with the deepest pixel depth."
- SDK header, `CGGetOnlineDisplayList`: "With hardware mirroring, a display may be online but not necessarily active or drawable."
- SDK header (CGDisplayConfiguration.h): `CGDisplayIsActive` = "connected, awake, and available for drawing"; `CGDisplayIsAsleep` = "asleep (and is therefore not drawable)"; `CGDisplayMirrorsDisplay` returns the mirrored primary for a secondary in a mirror set, else `kCGNullDirectDisplay`; `CGDisplayPrimaryDisplay` returns the primary of a hardware mirror set or the display itself.
- Reconfiguration callback: Quartz calls it "once for each online display to indicate a pending configuration change", with `kCGDisplayBeginConfigurationFlag` always set, then again "once for each added, removed, and online display" after the change; for removed displays, CG calls with that ID will fail — [Apple archive, Notification of Configuration Changes](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/Notification.html); [Apple docs, CGDisplayReconfigurationCallBack](https://developer.apple.com/documentation/coregraphics/cgdisplayreconfigurationcallback.md)
- Chromium and ROOT return early when the begin flag is set and act only on the completion call; WebRTC tracks displays mid-reconfiguration in a set — [Chromium screen_mac.mm](https://chromium.googlesource.com/chromium/src/+/8733d815f/ui/gfx/screen_mac.mm); [WebRTC desktop_configuration_monitor.cc](https://webrtc.googlesource.com/src/+/main/modules/desktop_capture/mac/desktop_configuration_monitor.cc)
- Apple Community: the Dock can get stuck on an iPad (Sidecar) used as a mirror — [Apple Community 256165313](https://discussions.apple.com/thread/256165313) (title only)

### Inferences
- Test the flag with `flags & kCGDisplayBeginConfigurationFlag`, not equality (other bits co-occur).
- Mirroring: a mirrored pair has one drawable surface; enumerate active displays, which already collapses hardware mirrors; software mirrors still list one active display per set.
- Display IDs are not stable across reboot/replug; persist `CGDisplayCreateUUIDFromDisplayID` instead (the project already does, per its dock-lock rule). Identical monitors without serials can share a UUID (project-internal note, not externally sourced here).

### Gaps
- No source found on how Sidecar, AirPlay or DisplayLink virtual displays report UUIDs, sleep state, or whether the Dock can relocate onto them; no measured timing for how long a hot-plug burst lasts.
- `NSApplication.didChangeScreenParametersNotification` vs the CG callback ordering was not documented in any fetched source.

## 5. Detecting which display the Dock is on

### Takeaway
There is no public API. Options, from most to least robust: private `CoreDockGetOrientationAndPinning` (orientation only, not display), the `com.apple.dock` `orientation` pref, `NSScreen.visibleFrame` insets (fails with auto-hide), and the Dock's on-screen windows / AX tree. None of them is documented to name the Dock's display.

### Cited Findings
- Ghostty declares `CoreDockGetOrientationAndPinning` (plus `CoreDockGetAutoHideEnabled` / `SetAutoHideEnabled`) via `@_silgen_name` as a private API and maps the integer to top/bottom/left/right — [Ghostty Dock.swift mirror](https://git.uoc.run.place/Applied-Software/ghostty/src/branch/vm-tests/macos/Sources/Helpers/Dock.swift) (search summary)
- Public alternatives: `defaults read com.apple.dock orientation` (absent → bottom), or compare `NSScreen.visibleFrame` with `frame` — [Stack Overflow 7717258 (kiwix mirror)](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/7717258/find-the-location-of-the-dock-programmatically); [gist wonderbit](https://gist.github.com/wonderbit/c8896ff429a858021a7623f312dcdbf9)
- No source found describing `CoreDockGetRect`.
- Project-internal measurement (this repo, macOS 27): the Dock draws in one full-screen window at layer 20 and every readable source (AX tree, CGWindow bounds, `CoreDockGetRect`) reports only the resting layout; an auto-hidden Dock reserves zero `visibleFrame` on every screen — `.claude/rules/architecture.md`, "NSPopover Positioning" (local file, no URL)

### Inferences
- `visibleFrame` works only when auto-hide is off: the screen whose visibleFrame is inset on the Dock's edge holds the Dock.
- With auto-hide on, the candidates are the Dock's CGWindow per screen (if it keeps one per display, the one with non-zero Dock content) or the AX `AXList` frame under the Dock process (needs Accessibility, which this feature has anyway). Both need a hands-on check on 15/26/27.

### Gaps
- Not found: whether the Dock owns one layer-20 window per display or one spanning, on current macOS, and whether its AX list frame updates while hidden.

## 6. A fully covered edge (two displays stacked with identical widths)

### Takeaway
Users and community experts state the Dock cannot be summoned onto an edge that is entirely shared with another display, and that this cannot be changed; the only routes are a different Dock edge (left/right), shifting the arrangement so part of the edge is exposed, or changing the main display.

### Cited Findings
- "You can't place the Dock on a seam between displays"; with three displays a gap is possible, but "each display still needs to touch at least one of the other two" — [Apple Community 255762225 p.3](https://discussions.apple.com/thread/255762225?page=3)
- One user got the Dock onto the top monitor by arranging it with "NO overlap ABOVE the MacBook Pro"; reports conflict on whether hovering works on a stacked display — [Apple Community 255762225](https://discussions.apple.com/thread/255762225) (search summary)
- Making a display main (dragging the menu bar in Displays settings) moves the Dock and menu bar there — [Setapp](https://setapp.com/how-to/how-to-move-dock-on-mac-to-a-second-monitor); [cyberciti](https://www.cyberciti.biz/faq/apple-osx-move-bottom-dock-top-menu-bar-second-monitor/)

### Inferences
- An anchor whose Dock-edge is fully covered has no exposed segment, so a warp-and-push cannot work there by construction; the app should detect it (zero exposed length) and say so instead of retrying. Changing the main display via `CGConfigureDisplayOrigin` would move the menu bar too, a far bigger side effect than the feature implies.

### Gaps
- No Apple statement of this rule; all evidence is community reports, and the 15.0 → 15.1 regression/fix shows the rule's details change between releases.
