# How macOS decides which display shows the Dock (multi-monitor rules)

Research date: 2026-11-10. Almost everything below is community observation (Apple Community, Apple developer forum, third-party utility docs, how-to sites). I found **no current Apple Support or Mac User Guide page** that documents the rules in detail; the one Apple-authored statement I could find is a DTS engineer's forum reply (below). Treat every rule as empirical.

## 1. What triggers the Dock to move to another display?

### Takeaway
The Dock moves when the pointer pushes against the Dock edge (bottom, in practice) of another display and keeps pushing; reports describe a short dwell ("a few seconds") or continued downward motion, not a single touch. No source gives a pixel threshold or a measured dwell time.

### Cited Findings
- Apple DTS engineer (Sep 2024, Sequoia thread): "I hover my mouse at the bottom of the monitor's screen for a few seconds and the dock moves over to the other monitor." (with auto-hide on). The only Apple-staff description found. — [Apple Developer Forums 764007](https://developer.apple.com/forums/thread/764007)
- Another Apple engineer in the same thread redirected Dock questions to Apple Support Community (no documentation offered). — [Apple Developer Forums 764007](https://developer.apple.com/forums/thread/764007)
- Apple support article HT202780 is quoted secondhand as saying a bottom Dock "is available on whichever display you're working on" and that you get it by moving the pointer to the bottom of that display; if the Dock is hidden or a full-screen app is on the display, move the pointer to the Dock's location. I could not load the quoting page or the Apple article to verify the wording. — [BinaryAge forum (search snippet only, page timed out)](https://discuss.binaryage.com/t/dock-moving-to-display2/3647)
- "You've got to slide the mouse pointer to the bottom of the screen and then keep sliding down for it to work reliably." — [OWC/MacSales blog](https://eshop.macsales.com/blog/48027-how-to-move-the-dock-from-one-monitor-to-another-on-a-mac/)
- Pre-Sequoia method described as "dragging slowly along the bottom edge of the external screen." — [Apple Community 255763872](https://discussions.apple.com/thread/255763872)
- "The decisive factor is to bump the cursor against the bottom edge, on either side" and the cursor must hit an *outer* edge of the combined display area (Luis Sequeira1, Oct 2025). — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- Reliability varies: some users report ~30% success when not at the outer ends of the edge; others report every time when the pointer is at the far left/right of the monitor, in a stretch that does not align with the other screen. — [search summary of OWC / Apple Community results](https://eshop.macsales.com/blog/48027-how-to-move-the-dock-from-one-monitor-to-another-on-a-mac/)
- Pointer-driven movement works for a bottom Dock; Setapp says it "only works if the Dock is at the bottom." — [Setapp](https://setapp.com/how-to/how-to-move-dock-on-mac-to-a-second-monitor)
- Changing the Main Display (dragging the menu bar in System Settings > Displays > Arrange) also moves the Dock there, along with the menu bar and new windows. — [Setapp](https://setapp.com/how-to/how-to-move-dock-on-mac-to-a-second-monitor); [MacPaw](https://macpaw.com/how-to/move-dock-to-other-screen-mac)
- Third-party Dock replacements or Dock-lock utilities can stop the Dock switching screens. — [Apple Community 256019856](https://discussions-kr-prz.apple.com/thread/256019856)
- Lock utilities work by intercepting the pointer near the edge: DockAnchor "creates a low-level event tap to monitor mouse movements", "calculates dock trigger zones on secondary displays", and "prevents mouse events from reaching the dock when in trigger zones"; it needs Accessibility permission. — [DockAnchor (project-awesome mirror of README)](https://project-awesome.org/r/bwya77-DockAnchor)

### Inferences
- The trigger behaves like "pressure" against the screen edge: the pointer must be clamped at the edge and keep generating motion toward it (or dwell). An app that keeps the pointer a few points away from the edge on non-anchor displays (as the event-tap tools do) prevents the move; an app that wants to *cause* a move must put the pointer on an exposed edge stretch and push into it.
- The DTS "few seconds" figure is anecdotal and may reflect auto-hide delay, not a relocation threshold.

### Gaps
- No source gives the band height, required distance, motion count or dwell time. Needs an on-hardware measurement.
- Could not verify the HT202780 wording or whether that article still exists for current macOS.

## 2. Which edge segments can trigger a move (arrangements)?

### Takeaway
A display can receive a bottom Dock only through a stretch of its bottom edge that is an outer edge of the whole desktop (no display directly beneath). If another display covers the entire bottom edge (identical displays stacked, or a fully overlapping lower display), the upper display cannot get the Dock from the pointer; offsetting the arrangement by a few pixels, or leaving a gap, re-exposes a stretch. Side-by-side layouts always work.

### Cited Findings
- "The Dock cannot be placed at the bottom of a display if another display is immediately below it." (Oct 2024, called a change from earlier versions). — [Apple Community 255763872](https://discussions.apple.com/thread/255763872)
- "the bottom of the larger screen is now not an edge of your combined displays" — advice to use the stretches that are not above the laptop. — [Apple Community 255763872](https://discussions.apple.com/thread/255763872)
- The Dock can't move to a display whose bottom edge is "perfectly aligned or overlapped with another screen"; fix: a few pixels of offset in Arrange Displays (JulyIGHOR, DockLock developer, Oct 2025). — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- macOS "only moves the Dock to a screen if at least a few pixels of its bottom edge don't overlap another screen." — [search summary of DockLock Lite/App Store & forum results](https://apps.apple.com/app/docklock-lite/id6741814079) (not verified on the page itself)
- Pixel-offset workaround for identical stacked displays suggested (Dec 2025), not confirmed by the poster. — [Apple Community 256192595](https://discussions.apple.com/thread/256192595)
- Identical stacked monitors on macOS Tahoe 26.1 with the upper one as Main Display: Dock "always appears on the bottom edge of the lower monitor"; only inverting the arrangement moved it up. — [Apple Community 256192595](https://discussions.apple.com/thread/256192595)
- Sequoia 15.0 reports: external display above the MacBook → cannot move Dock there; "Only if the external display is left, right or at the bottom." Stacked without a seam → Dock "falls" to the bottom of the stack. MacBook centred under two top monitors → Dock reaches neither; offsetting the MacBook under one monitor lets the Dock reach the other. — [Apple Community 255762225](https://discussions.apple.com/thread/255762225)
- Workarounds reported: a small gap between the MacBook and the top display (cursor then jumps noticeably), or moving the pointer to the far left of the top display then down to its bottom edge. — [Apple Community 255762225](https://discussions.apple.com/thread/255762225)
- iPad (as extended display) **below** the main monitor: Dock could not be brought to the main monitor "offset or not"; iPad above or beside worked. Unresolved. — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- AirPlay test (Oct 2025): the Dock moved to the topmost display when the cursor pressed the bottom edge "on either side". — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- MacRumors reply: a Dock on the upper monitor of a vertical stack would sit mid-desktop rather than on an edge, "so it's not a bug". — [search summary, MacRumors](https://forums.macrumors.com/threads/can-i-stop-the-dock-from-hopping-to-other-monitors.2042049/) (not fetched)
- "The Dock has be on an edge." (Luis Sequeira1, Nov 2025). — [Apple Community 256192595](https://discussions.apple.com/thread/256192595)
- Extended desktop: the Dock appears on the designated edge of the primary display, "except when another display is placed along that edge," then on the displayable portion of the extended desktop (Grant Bennet-Alder, Nov 2025). — [Apple Community 256184856](https://discussions.apple.com/thread/256184856)
- One user reported restoring Dock movement on stacked displays by changing "Click wallpaper to reveal desktop" from Always to "Only in Stage Manager" (single report, Jan 2025). — [Apple Community 255762225](https://discussions.apple.com/thread/255762225)

### Inferences
- Rule of thumb for prediction: candidate edge = the bottom edge of display D minus every x-interval where another display's top edge touches it. If that set is empty, D cannot receive a bottom Dock by pointer. Gaps between displays count as exposed edge.
- With three or more displays the same rule applies per display (the "MacBook centred under two monitors" report fits it: each top monitor's free stretch was covered by the laptop until it was offset).
- Mismatched sizes help: a wider upper display usually has free stretches beyond the narrower one below.
- The iPad-below report contradicts the rule (the main monitor above should have had free stretches if offset); possibly a Sidecar-specific quirk or a user error. Unresolved.

### Gaps
- No source for the minimum exposed width that still works (one pixel? a few?).
- Behaviour with displays arranged *below* the main display beyond the iPad report: little data.
- Whether pressing a *top* display's bottom edge stretch requires the pointer to cross from that display (vs. arrive diagonally) is unknown.

## 3. Role of "Displays have separate Spaces" and the main display

### Takeaway
With "Displays have separate Spaces" OFF, the Dock (and the only menu bar) stays on the main display; it does not follow the pointer. With it ON, a bottom Dock follows the pointer per the edge rules above. The main display still sets the Dock's default/initial home. Changing the setting needs a log out.

### Cited Findings
- "Displays have separate Spaces" must be ON for the Dock to move (community reply). — [search summary, Apple Community 256168335](https://origin-discussions2-us-dr-prz.apple.com/thread/256168335)
- With the setting off, "the dock and menu bar only appear on the display I have set as the main display." — [search summary, MacRumors 2446351](https://forums.macrumors.com/threads/hide-menubar-but-keep-window-snapping.2446351); [MacMost](https://macmost.com/?p=34471)
- Turning it off is the standard advice to stop Dock jumping; requires log out/in; trade-off: a window can't span displays the same way. — [Apple Community 251134915](https://discussions.apple.com/thread/251134915)
- Conflict: one user reports that with the setting OFF a side Dock still sits on the extreme left/right display. — [search summary, Apple Community 251134915](https://discussions.apple.com/thread/251134915)
- Macworld (Sep 2016, OS X): with separate Spaces off, the screen with the only menu bar "becomes the main screen for the Dock." — [Macworld](https://www.macworld.com/article/228695/how-to-move-the-dock-about-and-where-it-will-never-ever-reside.html)
- DockLock Lite requires "Displays have separate Spaces" on, and its lock "only works on screens where macOS allows it to be moved manually." — [search summary, DockLock Lite App Store](https://apps.apple.com/app/docklock-lite/id6741814079)
- "There is no setting to configure the Dock location across screens." (Tahoe 26.1 thread). — [Apple Community 256192595](https://discussions.apple.com/thread/256192595)
- A Mac Studio user on Sequoia 15.7.2 with separate Spaces on and a right-edge auto-hidden Dock on vertically stacked displays: Dock now appears only on the bottom (main) screen; worked before. Unresolved. — [Apple Community 256184856](https://discussions.apple.com/thread/256184856)
- A forum reply claims separate Spaces "may only work when you have selected Dock hidden" — unverified opinion. — [Apple Community 256184856](https://discussions.apple.com/thread/256184856)

### Inferences
- A pinning app should treat spans-displays = true (separate Spaces off) as "Dock is pinned to the main display by the OS" and do nothing; moving the Dock then means changing the main display.
- The setting key is `com.apple.spaces spans-displays` (from the task brief; not independently sourced here).

### Gaps
- No Apple documentation of the Dock/separate-Spaces relationship found.

## 4. Dock on the left or right edge

### Takeaway
A side Dock lives on the outermost display on that side (leftmost for left, rightmost for right); when displays are stacked vertically it goes to the topmost per Macworld 2016. Pointer-based movement is generally reported not to apply to side Docks, but the vertical-stack case is contradictory.

### Cited Findings
- "a left-anchored Dock always remains fixed to either the leftmost display or the topmost if displays are stacked"; same for right. "The vertical Dock always locks to the farthest or topmost edge." (Sep 2016, OS X). — [Macworld](https://www.macworld.com/article/228695/how-to-move-the-dock-about-and-where-it-will-never-ever-reside.html)
- "it will be on the leftmost or rightmost display only." — [search summary, Apple Community 251134915](https://discussions.apple.com/thread/251134915)
- "A side-mounted Dock appears on whichever display is set to that side." — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- "If the Dock is set to the left or right edge, pointer-driven movement between displays will not work." — [search summary, DockLock results](https://talk.macpowerusers.com/t/docklock-lite-keep-your-mac-dock-from-jumping-between-displays/40948) (not fetched)
- Side Dock is the common advice to stop accidental moves. — [Apple Community 255763872](https://discussions.apple.com/thread/255763872); [OWC](https://eshop.macsales.com/blog/48027-how-to-move-the-dock-from-one-monitor-to-another-on-a-mac/)
- Contradiction (Sequoia 15.7.2): with vertically stacked displays and a right Dock, the Dock used to appear on whichever screen's right edge was hovered and now appears only on the bottom (main) screen. — [Apple Community 256184856](https://discussions.apple.com/thread/256184856)

### Inferences
- For vertically stacked displays both share the left and right desktop edges, so a side Dock can in principle sit on either; which one wins (topmost per 2016, main/bottom per a 2025 report) appears to have changed or to depend on the main display. Treat as unpredictable; measure.

### Gaps
- No current (15–27) systematic source on side Dock placement for stacked or offset layouts.

## 5. Auto-hide, full screen, Stage Manager

### Takeaway
Auto-hide does not change the rule: the Apple DTS description is with auto-hide on, and Macworld says the bottom Dock follows the pointer whether or not auto-hide is on. Full-screen and Stage Manager have almost no sourced data.

### Cited Findings
- Bottom Dock follows the pointer "whether or not auto-hide is on." (2016). — [Macworld](https://www.macworld.com/article/228695/how-to-move-the-dock-about-and-where-it-will-never-ever-reside.html)
- DTS engineer's working method uses auto-hide on, hovering a few seconds. — [Apple Developer Forums 764007](https://developer.apple.com/forums/thread/764007)
- Quoted Apple help text: with the Dock hidden or a full-screen app on the display, move the pointer to the Dock location (unverified, secondhand). — [BinaryAge forum (snippet)](https://discuss.binaryage.com/t/dock-moving-to-display2/3647)
- The "Click wallpaper to reveal desktop" (a Stage Manager–era setting) report in section 2. — [Apple Community 255762225](https://discussions.apple.com/thread/255762225)

### Gaps
- Whether a full-screen Space on a display blocks or permits relocation: not found.
- Stage Manager interaction: only the single wallpaper-click report.

## 6. Mirrored, Sidecar, AirPlay, DisplayLink, sleep/off, clamshell

### Takeaway
Sidecar/iPad and AirPlay displays take part in the same edge rules (with one unresolved iPad-below anomaly). DisplayLink on Tahoe 26.4 has a reported bug reserving Dock space on more than one display. No sourced data on mirroring, sleeping/off displays or clamshell.

### Cited Findings
- iPad used as an extended display on Sequoia 15.7.1: Dock stuck on the iPad when the iPad was below; worked when iPad was above or beside. — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- AirPlay second display: Dock moved to the topmost display when the cursor pressed the bottom edge. — [Apple Community 256165313](https://discussions.apple.com/thread/256165313)
- DisplayLink, macOS Tahoe 26.4/26.4.1 (Apr 2026): maximising a window on the non-Dock DisplayLink display leaves a blank strip at the bottom; "macOS incorrectly reserves Dock space on more than one display." Not consistently reproducible elsewhere; no fix. — [DisplayLink forum t-69877](https://www.displaylink.org/forum/archive/index.php/t-69877.html)
- DockAnchor falls back to the Primary display when the anchor display is removed (tool behaviour, not macOS). — [DockAnchor](https://project-awesome.org/r/bwya77-DockAnchor)

### Gaps
- Mirrored displays: no source found (a mirror set is presumably one logical display; unverified).
- Sleeping, powered-off or disconnected displays, and clamshell mode: no source found on where the Dock goes.

## 7. Changes across macOS versions

### Takeaway
macOS 15.0 (Sep 2024) broke moving a bottom Dock to a display that had another display directly below it; macOS 15.1 (24B83, late Oct 2024) restored it per many users. Late-2025 reports on 15.7.x and Tahoe 26.1 still describe stacked layouts where the Dock cannot reach the upper display. No new System Settings control for the Dock's display exists as of Tahoe 26.1. Nothing found on macOS 27.

### Cited Findings
- 15.0: "After updating to Sequoia last night, the issue started" (worked under Sonoma); ~202 "Me too" votes; Apple Support reportedly said "works as designed" (secondhand). — [Apple Community 255762225](https://discussions.apple.com/thread/255762225)
- 15.1 fix: "update, macos 15.1 fixed" (Oct 29, 2024); "the fix has arrived in the version 15.1 (24B83)" (Nov 1, 2024). — [Apple Community 255762225](https://discussions.apple.com/thread/255762225)
- OP of the other 15.0 thread marked it resolved Oct 31, 2024: 15.1 lets the Dock sit at the bottom of an external screen with the laptop beneath it. — [Apple Community 255763872](https://discussions.apple.com/thread/255763872)
- Sep 2024 developer forum complaint on Sequoia: external monitors can't access the Dock. — [Apple Developer Forums 764007](https://developer.apple.com/forums/thread/764007)
- Sequoia 15.7.2 (Nov 2025) regression report for stacked displays with a right Dock. — [Apple Community 256184856](https://discussions.apple.com/thread/256184856)
- Tahoe 26.1 (Nov 2025): no setting; identical stacked displays keep the Dock on the lower one. — [Apple Community 256192595](https://discussions.apple.com/thread/256192595)
- Tahoe 26.4 DisplayLink phantom Dock space (Apr 2026). — [DisplayLink forum t-69877](https://www.displaylink.org/forum/archive/index.php/t-69877.html)
- Older (2016, OS X) behaviour: bottom Dock follows the pointer; side Dock fixed to the outermost/topmost display. — [Macworld](https://www.macworld.com/article/228695/how-to-move-the-dock-about-and-where-it-will-never-ever-reside.html)

### Inferences
- The 15.1 fix restored the "exposed segment" behaviour; the identical-stack case (no exposed segment at all) was never fixed and is probably by design: there is no outer bottom edge on the upper display.

### Gaps
- No Apple release note confirms the 15.0 change or the 15.1 fix.
- No reports found for macOS 27 (searches returned nothing specific).
- No sourced Reddit / Ask Different threads were retrieved; searches returned none.
