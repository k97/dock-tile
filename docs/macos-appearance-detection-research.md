# macOS Appearance & Icon-Style Detection — Research Notes

Why this exists: each Dock Tile helper bundle polls every **1 second** for the user's icon
appearance style and, when the resolved style changes, rewrites its own `AppIcon.icns`, bumps the
bundle mtime and shells out to `lsregister -f -R`
([HelperAppDelegate.swift](../DockTile/App/HelperAppDelegate.swift) `checkForIconStyleChange` →
[HelperBundleManager.swift](../DockTile/Managers/HelperBundleManager.swift) `switchIcon` /
`touchBundle`). Production analytics show the resolved style **oscillating** on some machines —
548 `icon_style_changed` events in one day on one install, 430 on another, against a baseline of
1–2/day. This note records what Apple actually documents about the two preference keys we read,
about CFPreferences cache coherency, and about Dock icon invalidation, so the fix can be chosen on
evidence rather than on a hunch.

> How this investigation started and every dead end it closed: [icon-investigation-trail.md](icon-investigation-trail.md)

**Every claim below is tagged.** `[DOCUMENTED]` = Apple developer documentation, HIG, release notes
or a shipped man page, linked. `[SOURCE]` = Darwin / CoreFoundation open source or a shipped
header. `[OBSERVED]` = reproduced first-hand or widely reproduced by the community with no Apple
documentation behind it. `[INFERENCE]` = my own reasoning from the above. Where nothing exists,
the note says **undocumented** rather than guessing.

Verification environment for the `[OBSERVED]` items marked "verified here": macOS 26.6.2
(build 25G83), 2026-08-31, this machine, in **Auto** appearance
(`AppleInterfaceStyleSwitchesAutomatically = 1`) with `AppleIconAppearanceTheme = RegularAutomatic`.

---

## Summary — what we should actually do

1. **Three separate documented violations turned up, and all three are worth fixing on their own
   merits** — independent of the oscillation. We pass `kCFPreferencesAnyApplication` to an API whose
   reference says *"Do not pass NULL or kCFPreferencesAnyApplication"* (§B4); we modify a signed
   bundle on every icon flip, which Apple documents as unsupported and which DTS has answered for
   this *exact* icon case (§C8b); and we ship a dependency on `lsregister`, which Apple DTS says is
   *"for debugging only… not considered API"* and *"Do not ship anything that depends on"* (§C9).

2. **But none of them explains the oscillation, and neither does anything else Apple documents.**
   The documented CFPreferences staleness failure mode is a value that **sticks**, not one that
   **flaps** (§B6). The Auto appearance switch is documented as an idle-gated, at-most-twice-daily
   event (§D12). And two of our three distributed-notification observers **do not exist on macOS
   26.6.2** — verified here (§D11b). Nothing documented produces 548 events/day. Do **not** fix blind
   on the stale-cache theory.

3. **The oscillation is therefore arriving through the 1-second poll's read path**, by elimination
   (§D11b). And our code turns any anomalous read into a real style change:
   `IconStyle.from(preferencesValue:)` returns `.defaultStyle` for `nil` **and** for every
   unrecognised string, so one bad read costs two `icon_style_changed` events, two `.icns` rewrites
   and two `lsregister` spawns.

4. **The single highest-value change is to make an unreadable/unknown value a no-op.** Split "read
   failed / value unknown" from "value is Default" and have the poll ignore the former. Correct
   whatever the root cause is, and the only change that is safe to make before we have proof. It also
   closes a real second bug: Apple documents `Clear → Light` and `Clear → Dark` as user-selectable,
   and our switch statement has no case for them (§D12).

5. **Add hysteresis and a hard cap, not just a debounce.** Apple documents no expected frequency, so
   we must bound it ourselves — and Apple's one adjacent instruction, *"avoid expensive tasks during
   appearance transitions"* (§D11), is flatly violated by a synchronous `lsregister` spawn on the
   main actor.

6. **Instrument to get proof.** Log both *raw* preference strings (not just the resolved enum), which
   path detected the change, and process uptime. 548/day is ~1 per 2.6 minutes — cheap to catch.
   Until that lands we cannot distinguish "the system really changed the setting" from "our read
   misbehaved", and those need opposite fixes.

7. **A free diagnostic already exists.** `codesign --verify` on a helper fails with *"a sealed
   resource is missing or invalid / file modified: …/AppIcon.icns"* if and only if that tile has
   performed a runtime icon swap since it was generated — verified here across five production
   helpers, one failing and four clean (§C8b).

---

## A. Appearance & icon-style detection

### A1. `AppleIconAppearanceTheme` and the Tahoe "Icon and widget style" setting

- **The key is undocumented. There is no public API for this setting.** Searching
  developer.apple.com surfaces no reference page, HIG page, release note or sample code that
  mentions `AppleIconAppearanceTheme`. The WWDC25 session that introduces the new icon
  appearances, *"Say hello to the new look of app icons"* (session 220), describes the appearance
  modes (default, dark, clear/monochrome, tinted) and says *"All appearance modes are available on
  iPhone, iPad and Mac"*, but never describes a selection mechanism a third-party app can read or
  observe. **Undocumented; best available evidence is the raw preference key.**
  `[DOCUMENTED — absence of documentation]`
  Source: https://developer.apple.com/videos/play/wwdc2025/220/ ·
  https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer
- The same conclusion has been reached independently by other projects: matplotlib's macOS backend
  issue for matching system app icons states there is *"an undocumented `AppleIconAppearanceTheme`
  setting"* and that *"there is also no public way to determine if the user has light/dark icons
  selected (a separate preference from light/dark system appearance)"*, adding that using it
  *"could likely create a maintenance issue in the future."* `[OBSERVED]`
  Source: https://github.com/matplotlib/matplotlib/issues/31895
- **No public API supersedes it.** `NSAppearance` / `NSApplication.effectiveAppearance` describe the
  *interface* appearance only: *"An `NSAppearance` object manages how AppKit renders your app's UI
  elements. Specifically, appearance objects determine which colors and images AppKit uses when
  drawing windows, views, and controls."* Nothing in `NSAppearance`, `NSAppearanceCustomization`,
  `NSWorkspace` or `NSDockTile` exposes the icon/widget style. `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsappearance ·
  https://developer.apple.com/documentation/appkit/nsapplication/effectiveappearance
- **The HIG documents the *user-facing* model, and it is not "the app detects and swaps".**
  > "In iOS, iPadOS, and macOS, people can choose whether their Home Screen app icons are default,
  > dark, clear, or tinted in appearance. … You can design app icon variants for every appearance
  > variant, and **the system automatically generates variants you don't provide.**"

  The HIG's own enumeration of the appearance set is *"Default, dark, clear light, clear dark, tinted
  light, tinted dark"*. So Apple's supported model is: ship variants, the system selects. There is no
  supported runtime "read the setting and swap the file" story at all — Dock Tile only needs one
  because helper bundles have `Assets.car` stripped (see [icon-system rule](../.claude/rules/icon-system.md)),
  which is itself outside Apple's model. `[DOCUMENTED]`
  Source: https://developer.apple.com/design/human-interface-guidelines/app-icons
- **Enumerating the values is not possible from primary sources**, because the key is undocumented.
  Verified here: the value on this machine is `RegularAutomatic`, stored in
  `~/Library/Preferences/.GlobalPreferences.plist` (i.e. the global / `NSGlobalDomain` domain, not a
  by-host domain — `ByHost/.GlobalPreferences.<UUID>.plist` contains no appearance keys).
  `[OBSERVED — verified here]`
  The set the code currently handles (`RegularAutomatic`, `RegularDark`, `RegularLight`,
  `ClearAutomatic`, `TintedAutomatic`, plus absent = Default) is **community/field-observed only**;
  Apple publishes no list, so the set can grow in any macOS update without notice. This matters for
  the bug: `IconStyle.from` maps every unrecognised string to `.defaultStyle`, so a value Apple adds
  later would read as a style *change*, not as "unknown".

### A2. Observing Light/Dark appearance in AppKit — documented vs folklore

| Mechanism | Status |
|---|---|
| KVO on `NSApplication.effectiveAppearance` | **Documented.** |
| `NSView.viewDidChangeEffectiveAppearance()` | **Documented**, but per-view. |
| KVO on `UserDefaults` for an external change | **Documented** (the only documented cross-process one). |
| `DistributedNotificationCenter` `"AppleInterfaceThemeChangedNotification"` | **Undocumented folklore.** |
| `"com.apple.desktop.darkModeChanged"` | **Undocumented folklore.** |
| Reading `AppleInterfaceStyle` directly | **Undocumented.** |
| `NSApplication.didChangeScreenParametersNotification` | Documented, but **unrelated** to appearance. |

- **KVO on `effectiveAppearance` is explicitly sanctioned.** The AppKit 10.14 release notes:
  *"NSApplication now conforms to the NSAppearanceCustomization protocol, which you use to query,
  override, and **key-value observe** the global NSAppearance of your app."* This is the documented
  way to be told the app's Light/Dark appearance changed. `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-10_14
- **`viewDidChangeEffectiveAppearance()`** — *"Informs the view that its effective appearance
  changed."* Per-view, so an agent process with no visible view gets nothing useful from it.
  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/appkit/nsview/viewdidchangeeffectiveappearance()
- **Caution on `NSAppearance.current`**: *"When AppKit draws a control, it automatically sets the
  current appearance on the current thread to the control's appearance."* So the *current*
  appearance is a transient drawing-time value and is not a system-state signal. Use
  `effectiveAppearance`, never `NSAppearance.current`, if we ever switch to the AppKit route.
  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/appkit/nsappearance
- **`didChangeScreenParametersNotification` is not an appearance signal**: *"Posted when the
  configuration of the displays attached to the computer is changed."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification
- **The three distributed-notification names we observe are undocumented.** No Apple reference
  page, header or sample code names `AppleInterfaceThemeChangedNotification`,
  `AppleIconAppearanceThemeChangedNotification` or `com.apple.desktop.darkModeChanged`. They are
  community folklore, and the API they ride on documents that delivery is best-effort — see A3.
  **Undocumented** — and they are not equally real: verified here on macOS 26.6.2, only
  `AppleInterfaceThemeChangedNotification` exists at all; the other two are absent from the system
  entirely, so those two observers are dead code. See **§D11b**, which supersedes this bullet.
- **`AppleInterfaceStyle` is absent, not `"Light"`, in Light mode — verified here, undocumented by
  Apple.** On this machine in Light appearance, `defaults read -g AppleInterfaceStyle` errors ("does
  not exist") and the key is simply not present in `.GlobalPreferences.plist`, while
  `AppleInterfaceStyleSwitchesAutomatically = 1` and `AppleIconAppearanceTheme = RegularAutomatic`
  are. `[OBSERVED — verified here]` I found **no** Apple documentation stating this; the closest
  first-party surface is the `defaults(1)` man page's description of the global domain, which says
  nothing about appearance. **Undocumented.** The practical consequence for us is unavoidable:
  *absent* and *unreadable* are indistinguishable at the CFPreferences layer if you only look at the
  returned pointer, which is exactly the ambiguity that turns a bad read into a fake style change
  (§Summary #2/#3). `[INFERENCE]`
- **What `man defaults` does document, and why it matters for the fix:** *"Though all applications,
  system services, and other programs have their own domains, they also share a domain named
  NSGlobalDomain. If a default isn't specified in the application's domain, but is specified in
  NSGlobalDomain, then the application uses the value in that domain."* So a *normal* app-domain read
  already sees these global keys — we do not need `kCFPreferencesAnyApplication` at all. `[SOURCE —
  shipped man page]`

### A3. Behaviour in a background / `LSUIElement` / ad-hoc-signed process

This is where the current design is on the weakest documented ground.

- **`NSApplication` suspends distributed-notification delivery whenever the app is not active —
  documented, and our Ghost-mode helpers are essentially never active.**
  > "The NSApplication class automatically suspends distributed notification delivery when the
  > application is not active. Applications based on the Application Kit framework should let AppKit
  > manage the suspension of notification delivery."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspended

  Ghost mode sets `NSApp.setActivationPolicy(.accessory)`
  ([HelperAppDelegate.swift](../DockTile/App/HelperAppDelegate.swift)), which *"corresponds to value
  of the `LSUIElement` key in the application's Info.plist being 1"* and means the app *"doesn't
  appear in the Dock and doesn't have a menu bar, but it may be activated programmatically or by
  clicking on one of its windows."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory

  **Consequence** `[INFERENCE]`: in a helper the three `DistributedNotificationCenter` observers are
  suspended almost all the time. Registering via
  `addObserver(forName:object:queue:)` gets the default suspension behaviour, which is documented as
  *"The server only queues the last notification of the specified name and object; earlier
  notifications are dropped. In cover methods for which suspension behavior is not an explicit
  argument, `NSNotificationSuspensionBehaviorCoalesce` is the default."* So notifications that fire
  while a helper is inactive are coalesced to one-per-name and delivered later, when AppKit resumes
  delivery — i.e. **when the user clicks the tile**. The 1-second poll is therefore doing essentially
  all the work today, and the notification observers are a mostly-dead path that additionally
  produces a small burst on activation. If we keep them, register with
  `NSNotificationSuspensionBehaviorDeliverImmediately`, which is documented to bypass suspension
  entirely: *"The server delivers notifications matching this registration irrespective of whether
  `suspended` with an argument of true has been called."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior/coalesce ·
  https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior/deliverimmediately
- **A run loop is required, and delivery is best-effort with unbounded latency and possible drops.**
  > "Posting a distributed notification is an expensive operation. The notification gets sent to a
  > system-wide server that distributes it to all the tasks that have objects registered for
  > distributed notifications. The latency between posting the notification and the notification's
  > arrival in another task is unbounded. In fact, when too many notifications are posted and the
  > server's queue fills up, **notifications may be dropped**."
  >
  > "Distributed notifications are delivered via a task's run loop. A task must be running a run loop
  > in one of the 'common' modes, such as `NSDefaultRunLoopMode`, to receive a distributed
  > notification. For multithreaded applications running in macOS 10.3 and later, distributed
  > notifications are always delivered to the main thread."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter

  So: yes, a run loop is required (our helpers have one); and no, distributed notifications can
  never be treated as a reliable edge signal — Apple documents that they can be dropped. That
  justifies *some* fallback, but not necessarily a 1 Hz one.
- **Ad-hoc signing**: I found **no** Apple documentation that code-signing identity affects
  `DistributedNotificationCenter` delivery or CFPreferences reads of the global domain. **Undocumented;
  no primary source found.** (Signing identity demonstrably *does* matter for TCC — see
  [dock-lock-accessibility.md](dock-lock-accessibility.md) — but that is a different subsystem, and
  extrapolating from it would be unfounded.)
- **Sandboxing** would matter, but does not apply: Apple documents that *"A sandboxed app cannot
  access or modify the settings of another app or process"*. Dock Tile and its helpers are not
  sandboxed, so the global-domain read is permitted. `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/foundation/userdefaults

---

## B. CFPreferences cache coherency — the core question

### B4. Documented semantics of `CFPreferencesCopyAppValue` against another domain

- **The parameter contract forbids what we are doing.** Apple's reference for
  `CFPreferencesCopyAppValue(_:_:)`, `applicationID`:
  > "The identifier of the application whose preferences to search, typically
  > `kCFPreferencesCurrentApplication`. **Do not pass NULL or `kCFPreferencesAnyApplication`.**
  > Takes the form of a Java package name, com.foosoft."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/corefoundation/cfpreferencescopyappvalue(_:_:)

  `IconStyle.current` and `IconStyle.systemAppearanceIsDark` both pass exactly
  `kCFPreferencesAnyApplication`. This is the clearest, most actionable documented defect found in
  this whole investigation — independent of whether it is the cause of the oscillation.
- **The same prohibition is repeated for `CFPreferencesAppSynchronize(_:)`**: *"The ID of the
  application whose preferences to write to storage, typically `kCFPreferencesCurrentApplication`.
  Do not pass NULL or kCFPreferencesAnyApplication."* `[DOCUMENTED]` — so "just add a synchronize
  before the read" is **not** available in the shape we would reflexively write it.
  Source: https://developer.apple.com/documentation/corefoundation/cfpreferencesappsynchronize(_:)
- **Why it works anyway**, and why that is not reassurance: in CoreFoundation's open source,
  `_CFPreferencesURLForStandardDomainWithSafetyLevel` maps the constant to the global plist —
  `if (domainName == kCFPreferencesAnyApplication) { appName = CFSTR(".GlobalPreferences"); }` — and
  `_CFStandardApplicationPreferences` carries a **commented-out assertion** against precisely our
  call: `// CFAssert(appName != kCFPreferencesAnyApplication, __kCFLogAssertion, "Cannot use any of
  the CFPreferences...App... functions with an appName of kCFPreferencesAnyApplication");`. So the
  guard was written, then disabled — the behaviour is accidental, not contractual. `[SOURCE]`
  Source: https://github.com/apple-oss-distributions/CF/blob/main/CFPreferences.c (search
  `.GlobalPreferences`) ·
  https://github.com/apple-oss-distributions/CF/blob/main/CFApplicationPreferences.c (search
  `Cannot use any of the CFPreferences`)
- **Is a stale read genuinely possible? Apple documents that it is — for *externally* changed
  values, which is exactly our case.** From the `CFPreferencesAppSynchronize(_:)` discussion:
  > "Conversely, **preference data is cached after it is first read. Changes made externally are not
  > automatically incorporated.** The `CFPreferencesAppSynchronize(_:)` function reads the latest
  > preferences from permanent storage."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/corefoundation/cfpreferencesappsynchronize(_:)

  Note the failure mode this describes: a value that **sticks**, not one that **flaps**. See §B6.

### B5. What `CFPreferencesAppSynchronize` actually does on modern macOS

Two Apple statements, both primary, that must be read together — and they do not fully agree.

1. **The reference page (still current)**: *"Writes to permanent storage all pending changes to the
   preference data for the application, and reads the latest preference data from permanent
   storage."* plus the cached-read text quoted in B4 — i.e. it flushes **both** a write cache and a
   read cache. `[DOCUMENTED]`
   Source: https://developer.apple.com/documentation/corefoundation/cfpreferencesappsynchronize(_:)
2. **The Core Foundation release notes**, which are where the "it's a no-op now" claim actually comes
   from — and which say something narrower than the folklore:
   > **OS X Lion:** "CFPreferences now uses the automatic synchronization system for the current
   > application's domain that NSUserDefaults has always used. Additionally, automatic
   > synchronization is now non-blocking in most cases. You should consider any calls to
   > `CFPreferencesAppSynchronize()` carefully to see if they're really necessary, as you can avoid
   > blocking IO by removing them."
   >
   > **OS X Mountain Lion:** "`CFPreferencesSynchronize()` (and therefore
   > `CFPreferencesAppSynchronize()` and `-[NSUserDefaults synchronize]`) is now automatic in
   > virtually all cases. **The only remaining reason to call it is if you need a separate process to
   > be able to synchronously access the values you just set**; for example if you set a preference,
   > then post a notification which another process receives and reads the same preference. …
   > `CFPreferencesSynchronize()` is also much faster in 10.8, and will avoid doing any work if there
   > are no outstanding changes to read or write."

   `[DOCUMENTED]` Source: https://developer.apple.com/library/archive/releasenotes/DataManagement/RN-CoreFoundationOlderNotes/

**Reading these honestly:** the Lion note scopes automatic synchronization to *"the current
application's domain"*, and the ML note frames the remaining use as a **writer-side** guarantee.
Neither says a *reader* of a domain it does not own is kept fresh automatically. Neither says
synchronize is a no-op — it says it is automatic *in virtually all cases* and cheap when there is
nothing to do. So: **"CFPreferencesAppSynchronize is a no-op since 10.9" is folklore that
overstates a real Apple statement.** `[INFERENCE]`

- **Does calling it before a read guarantee freshness? Not provably.** The reference text says it
  "reads the latest preference data from permanent storage", but the same release notes say
  cfprefsd caches and writes asynchronously (§B6), and the modern implementation is closed source
  (§B6), so there is no primary source that closes the loop. **Undocumented; best available
  evidence is the reference page's own wording.** `[INFERENCE]`
- **What it flushes, per the open source**: `CFPreferencesAppSynchronize` → (for a domain with no
  per-app prefs object) `_CFSynchronizeDomainCache()`, which iterates the process-wide `domainCache`
  and synchronizes **every** cached domain, not just the named one. `[SOURCE]`
  Source: https://github.com/apple-oss-distributions/CF/blob/main/CFApplicationPreferences.c ·
  https://github.com/apple-oss-distributions/CF/blob/main/CFPreferences.c
- **Apple's own guidance is against synchronizing on every read**, which is what a 1 Hz poll would
  do: *"Only synchronize when absolutely necessary… You should typically not, however, call these
  functions before every read of a preference key."* `[DOCUMENTED]`
  Source: https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFPreferences/Concepts/BestPractices.html

  (Note the tension with our existing Dock-plist convention, which *does* synchronize before every
  read — see [architecture.md](../.claude/rules/architecture.md) "Reliable reads". That was adopted
  for a real, reproduced cold-cache bug; this note does not propose changing it, only observes that
  Apple's written guidance is the other way and that a 1 Hz synchronize is a different cost profile
  from a once-per-user-action one.)

### B6. Can two reads seconds apart differ while the setting never changed?

**No primary source establishes a mechanism, and the documented mechanism points the wrong way.**

- The documented caching behaviour (B4) produces a **stuck** value, not an alternating one. A process
  that caches `RegularDark` and never synchronizes reports `RegularDark` forever — zero
  `icon_style_changed` events, not 548. So "unsynchronized read → stale cache" **does not by itself
  explain the telemetry.** `[INFERENCE]`
- What Apple *does* document is that the storage layer is asynchronous and mediated:
  > "In 10.8 and later, the CFPreferences agent process (cfprefsd) will **cache information from
  > these files and asynchronously write to them.** This means that directly modifying plist files is
  > unlikely to have the expected results (new settings will not necessarily be read, and may even be
  > overwritten)."

  `[DOCUMENTED]` Source: https://developer.apple.com/library/archive/releasenotes/DataManagement/RN-CoreFoundationOlderNotes/

  And the shipped man page confirms the daemon is the sole mediator with no configurability:
  *"cfprefsd provides preferences services for the CFPreferences and NSUserDefaults APIs. There are
  no configuration options to cfprefsd. Users should not run cfprefsd manually."* `[SOURCE — shipped
  man page, `man 8 cfprefsd`]`

  An asynchronous cache is a *plausible* source of transient inconsistency, but Apple never
  documents a transient-`nil` or read-tearing behaviour, and I found no Apple engineer statement
  asserting one. **Undocumented.**
- **Modern behaviour cannot be checked against source.** The open-source CoreFoundation drop
  (`apple-oss-distributions/CF`) still implements standard domains against XML plist callbacks
  (`__kCFXMLPropertyListDomainCallBacks`), i.e. it predates/omits the cfprefsd-backed
  `CFXPreferences` path that actually runs on macOS 26. So the source is good evidence for *domain
  naming and search-list structure* (B4, B7) and **not** evidence for cache-coherency behaviour
  today. `[SOURCE + INFERENCE]`
- **Two-key non-atomicity is a real, structural hazard in our code** even without any CF bug:
  `IconStyle.from(preferencesValue:)` reads `AppleIconAppearanceTheme`, then separately reads
  `AppleInterfaceStyle`. Those are two independent CFPreferences calls with no snapshot semantics.
  Nothing documents them as atomic, and nothing prevents an update landing between them. In
  `RegularAutomatic` (the Tahoe default, and this machine's setting) the *second* read is the one
  that decides `.dark` vs `.defaultStyle`, so it is the one an anomaly would flip. `[INFERENCE]`
- **By-host vs non-by-host**: verified here, both appearance keys live in the non-by-host global
  domain (`~/Library/Preferences/.GlobalPreferences.plist`);
  `ByHost/.GlobalPreferences.<UUID>.plist` contains no appearance keys. So a by-host/any-host
  mismatch is **not** a candidate explanation on this configuration. `[OBSERVED — verified here]`
  (`CFPreferencesCopyAppValue`'s search list covers both host scopes anyway — §B7.)
- **Multi-user / multi-session**: undocumented as a source of read instability. No primary source
  found.

### B7. Is `kCFPreferencesAnyApplication` the right domain?

**No — and there are two documented alternatives.**

- Passing it to `CFPreferencesCopyAppValue` is documented as prohibited (§B4). It *is* documented and
  legal for the low-level `CFPreferencesCopyValue(_:_:_:_:)`, whose `applicationID` parameter carries
  no such prohibition, and where `kCFPreferencesAnyApplication` is defined as *"Indicates a
  preference that applies to any application."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/corefoundation/cfpreferencescopyvalue(_:_:_:_:) ·
  https://developer.apple.com/documentation/corefoundation/kcfpreferencesanyapplication
- **Option 1 — stay in CoreFoundation, use the primitive with an explicit domain triple:**
  `CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
  kCFPreferencesAnyHost)`, paired if needed with `CFPreferencesSynchronize(kCFPreferencesAnyApplication,
  kCFPreferencesCurrentUser, kCFPreferencesAnyHost)` — the documented *"primitive synchronize
  mechanism"*, which unlike `CFPreferencesAppSynchronize` has **no** prohibition on the constant.
  Apple flags the primitives as *"Do not use this function directly unless you have a specific
  need"*; reading a system-owned global-domain key that the high-level call is documented not to
  accept is exactly such a need. `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/corefoundation/cfpreferencessynchronize(_:_:_:)
- **Option 2 (preferred) — just use `UserDefaults`.** The standard defaults object's search list
  falls through to the global domain: *"If a default isn't specified in the application's domain,
  but is specified in NSGlobalDomain, then the application uses the value in that domain"*
  `[SOURCE — `man defaults`]`, and `UserDefaults.globalDomain` is documented as *"The identifier for
  the domain that contains system-specified settings for all apps… You can read values from this
  domain, but don't write your own settings to it."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/foundation/userdefaults/globaldomain

  The same fall-through is visible in CF's standard search list, which places the
  `kCFPreferencesAnyApplication` domains (both host scopes) right after the app's own domains.
  `[SOURCE]`
  Source: https://github.com/apple-oss-distributions/CF/blob/main/CFApplicationPreferences.c
  (`_CFApplicationPreferencesSetStandardSearchList`)

  **And it brings the one documented cross-process change signal we have:**
  > "If a different process changes your app's settings, the system doesn't generate this
  > notification. **To detect changes made by another process, register a key-value observer on the
  > `UserDefaults` object. Key-value observing reports all updates to setting values, regardless of
  > which process made the change.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/foundation/userdefaults/didchangenotification

  That is the closest thing to a sanctioned replacement for both the poll and the undocumented
  distributed notifications. **Caveat, stated plainly:** the sentence is written about *your app's*
  settings; Apple does **not** explicitly document that KVO on `UserDefaults.standard` fires for a
  key resolved through the `NSGlobalDomain` fall-through. That specific case is **undocumented** and
  must be verified experimentally before we rely on it. `[INFERENCE]`
- **Does the choice affect cache behaviour?** No primary source addresses this. Both routes end at
  the same cfprefsd-mediated global domain. **Undocumented.** `[INFERENCE]`

---

## C. Dock icon update behaviour

### C8. Changing an app's own Dock icon at runtime

| Mechanism | Status | Applies to |
|---|---|---|
| `NSApplication.applicationIconImage` | Documented, sanctioned, **temporary** | the **running** app's tile |
| `NSDockTile` + custom `contentView` | Documented, sanctioned | the **running** app's tile |
| `NSDockTilePlugIn` | Documented, sanctioned | a tile whose app is **not running** |
| Rewriting `AppIcon.icns` inside the bundle | **Documented as *unsupported*** (§C8b) | — |

- **`applicationIconImage`** — the entire documentation is: *"Assign an image to this property when
  you want to **temporarily** change the app icon in the dock app tile. The image you provide is
  **scaled as needed** so that it fits in the tile. To restore your app's original icon, set this
  property to `nil`."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage

  "Scaled as needed" is the documented basis for the effect the comment in
  `HelperBundleManager.switchIcon` describes ("causes the Dock icon to appear larger than other
  apps") — the system fits *your* image into the tile instead of running it through the IconServices
  pipeline that renders a bundle's `.icns`. Apple documents no persistence whatsoever; by
  construction it is a property of a *running* `NSApplication`. `[INFERENCE]`
- **`NSDockTile`** — *"An application Dock tile defaults to display the application's
  `applicationIconImage`."* A custom `contentView` is supported, but *"Cocoa does not automatically
  redraw the contents of your dock tile. Instead, your application must explicitly send `display`
  messages…"*. `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsdocktile ·
  https://developer.apple.com/documentation/appkit/nsdocktile/contentview

  The shipped `NSDockTile.h` public surface is `size` (readonly), `contentView`, `-display`,
  `showsApplicationBadge`, `badgeLabel`, `owner` — **there is no property or method that sets the
  tile's image**; `contentView` + `display()` is the only image path. `[SOURCE — shipped SDK header]`
- **`NSDockTilePlugIn` is the only documented way to control a *pinned but not running* tile** —
  *"A set of methods implemented by plug-ins that allow an app's Dock tile to be customized **while
  the app is not running**. … The plugin is loaded in a system process at login time or when the
  application tile is added to the Dock."* Declared via the `NSDockTilePlugIn` Info.plist key
  ("the name of the plug-in with the `.docktileplugin` filename extension that resides in the app's
  `Contents/PlugIns` folder"). The macOS App Programming Guide states the same split: *"An app's Dock
  icon is, by default, the app's icon. **While your app is running**, you can modify or replace the
  default icon… You can also customize a dock tile **when your app is not currently running** by
  creating a Dock tile plug-in."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsdocktileplugin ·
  https://developer.apple.com/documentation/bundleresources/information-property-list/nsdocktileplugin ·
  https://developer.apple.com/library/archive/documentation/General/Conceptual/MOSXAppProgrammingGuide/CommonAppBehaviors/CommonAppBehaviors.html

  Recorded, not proposed: this is the only Apple-sanctioned mechanism whose shape matches what Dock
  Tile actually needs, and it would move the appearance decision out of five polling agent processes
  into a system-loaded plug-in. `[INFERENCE]`
- **Rewriting the bundle's `.icns` is not merely undocumented — see §C8b.** `CFBundleIconFile` is
  documented only as *"The file containing the bundle's icon."*, with no discussion section at all;
  nothing in the Bundle Programming Guide addresses mutating it at runtime. `[DOCUMENTED — absence]`
  Source: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile

### C8b. Rewriting a resource inside a signed bundle — documented as unsupported

This is the sharpest finding in section C. It applies to **every** icon switch we perform, and Apple
has addressed our exact use case by name.

- **A current (non-archive) Apple doc states the rule outright** — *Embedding nonstandard code
  structures in a bundle*, "Separate read-only and read/write content":
  > "**A bundle is a read-only structure.** All Apple platforms except the Mac enforce this
  > requirement at runtime. On iOS, for example, any attempt to modify your app's bundle at runtime
  > will fail with an error. **The Mac may or may not enforce this requirement at runtime, depending
  > on the context, but modifying your app's bundle isn't supported because it breaks the seal on the
  > app's code signature.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/xcode/embedding-nonstandard-code-structures-in-a-bundle
- **TN2206 *macOS Code Signing In Depth*** says the same, and enumerates exactly which changes are
  survivable — ours is not among them:
  > "**Bundles should be treated as read-only once they have been signed.**" · "**If you must modify
  > your bundle, do it before signing. If you modify a signed bundle, you must re-sign it
  > afterwards.**"
  >
  > *"I store data in or otherwise modify my bundle after I sign it."* — "**This is no longer
  > allowed.** … It also won't work to write that data after your app first runs. That still breaks
  > the signature. … **macOS APIs that rely on a valid identity will fail. In general, you should
  > plan for future stricter runtime checks of code validity.**"
  >
  > "**Removing** files from `.lproj` directories inside `Contents/Resources` will not invalidate the
  > code signature, but **adding or changing files will**."

  `Contents/Resources/AppIcon.icns` is a *changed file in `Contents/Resources`* — squarely in the
  "will invalidate" set. `[DOCUMENTED]`
  Source: https://developer.apple.com/library/archive/technotes/tn2206/_index.html
- **The Code Signing Guide describes the seal itself**: *"The code signing machinery generates the
  seal by running different parts of your final bundle (app, library, or framework), including
  executables, **resources**, the `Info.plist` file, code requirements, and so on, through a one-way
  hashing algorithm. … Even a small modification in the code results in a different digest."*
  `man codesign(1)` confirms verification *"confirms that the code at those path(s) is signed, that
  the signature is valid, and that **all sealed components are unaltered**."* `[DOCUMENTED]` +
  `[SOURCE — shipped man page]`
  Source: https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/AboutCS/AboutCS.html
- **Apple DTS has answered this exact question — "dynamically changing app icon" — on the record.**
  Quinn "The Eskimo!":
  > "This is going to be tricky. **An app's icon is part of its bundle, and thus modify the icon will
  > break the seal on the code signature.** You don't want to leave the user with an app with a broken
  > code signature because sooner or later Gatekeeper look at the app, notice the broken signature,
  > and kvetch."
  >
  > "Also, **avoid modifying any app that the user has previously run. If you're updating a live app,
  > make a copy of it and then modify the copy, using APFS clone** to minimise the disk space impact."

  `[APPLE STAFF]` Source: https://developer.apple.com/forums/thread/800303

  That second sentence is a direct prescription for what Dock Tile should be doing, and it is much
  closer to `installHelper` (copy → modify → sign → place) than to the in-place `switchIcon` +
  `touchBundle` path. Also on the record, on modifying a bundle after signing generally: *"If you
  mean 'Is this supported?' then the answer is 'No.' … You are likely to have more problems on future
  versions of macOS as Apple continues to tighten platform security. **Stop now and rethink your
  approach.**"* `[APPLE STAFF]` Source: https://developer.apple.com/forums/thread/769374
- **The honest counterweight, also from Apple DTS** — this is why it has not visibly broken anything
  yet, and it should be quoted alongside the above rather than buried:
  > "Regardless, **macOS does not currently protect your app from such modifications (after the
  > initial Gatekeeper check).** … It wouldn't surprise me if this changed at some point but I can't
  > speculate about The Future™. … Validating your app's code signature on launch is never going to
  > fly performance-wise."

  `[APPLE STAFF]` Source: https://developer.apple.com/forums/thread/705806
- **Reproduced here, on this machine, today.** `_CodeSignature/CodeResources` in a helper bundle
  seals `Resources/AppIcon.icns` alongside the four variants, and `codesign --verify` on a helper
  that has performed a runtime style switch fails:

  ```
  …/Dev Tile.app: a sealed resource is missing or invalid
  file modified: …/Dev Tile.app/Contents/Resources/AppIcon.icns
  ```

  Across the five production helper bundles here, **one** (`AI Tile.app`) fails with that error and
  four verify clean — so `codesign --verify` is, for free, an on-disk record of *"this tile has
  performed at least one runtime icon swap since it was generated"*. `[OBSERVED — verified here]`
- **Consequences, stated precisely** `[INFERENCE]`: helpers are ad-hoc signed and created locally, so
  they carry no quarantine xattr and today's Gatekeeper check does not fire on them — which matches
  the DTS quote above. What it costs us is (a) exactly the future tightening TN2206 tells us to plan
  for, (b) any macOS API that validates the helper's identity, and (c) the debuggability of every
  helper, since a broken seal is now normal noise rather than a signal.

### C9. How the Dock and the system cache app icons, and what invalidates that

- **Apple documents the Launch Services half — and it matches what `touchBundle` does, but via API,
  not the CLI.** *Launch Services Concepts*:
  > "**After making any significant change in an application's Launch Services–related information,
  > you should either reregister the application explicitly, by calling `LSRegisterFSRef` or
  > `LSRegisterURL` with `inUpdate` set to `true`, or update the modification time of the application**
  > to ensure that it will be updated by the automatic registration utilities described above."
  >
  > "…the **installer** should call one of the Launch Services registration functions `LSRegisterFSRef`
  > or `LSRegisterURL` to register the application explicitly."

  Note who is meant to call it: **installers**, at install time — not a running app on a timer.
  `[DOCUMENTED]` Source: https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/LaunchServicesConcepts/LSCConcepts/LSCConcepts.html
- **`LSRegisterURL` is public, current, non-deprecated API — the sanctioned equivalent of what we
  shell out for.** *"Registers an app, using a URL, in the Launch Services database."* `inUpdate`:
  *"if the parameter is `true`, the app's registered information will be updated **even if its
  modification date has not changed**"* — i.e. `inUpdate: true` ≡ `lsregister -f`. The shipped SDK
  header declares it `API_AVAILABLE( ios(4.0), macos(10.3), tvos(9.0), watchos(1.0) )` with **no**
  `API_DEPRECATED`; the deprecated sibling is `LSRegisterFSRef`
  (`API_DEPRECATED("Use LSRegisterURL instead.", macos(10.3,10.10))`). `[DOCUMENTED]` + `[SOURCE —
  shipped SDK header `LaunchServices.framework/Headers/LSInfo.h`]`
  Source: https://developer.apple.com/documentation/coreservices/1446350-lsregisterurl
- **`lsregister` is, on the record from Apple DTS, a debugging tool that must not ship.** It has no
  man page ("No manual entry for lsregister" on macOS 26.6.2) and is not on the default `PATH`. Two
  independent DTS statements:
  > "`lsregister`, to interrogate and manipulate the Launch Services database … **IMPORTANT Both of
  > these tools are for debugging only; they are not considered API.** Also, `lsregister` is not on
  > the default path…"
  >
  > "The standard tool for this sort of thing is `lsregister` … **WARNING Do not *ship* anything that
  > depends on the presence or output of this tool. Its location, deep within the Core Services
  > framework, indicates that it's not something that's officially supported.**"

  `[APPLE STAFF]` Source: https://developer.apple.com/forums/thread/725805 ·
  https://developer.apple.com/forums/thread/46803

  **Dock Tile ships a dependency on this tool and invokes it hundreds of times a day on affected
  machines.** This is the second documented-as-unsupported mechanism in the same code path as §C8b.
- **What the tool's own help text tells us about our call site** — `-f` is *"force-update
  registration even if mod date is unchanged"* (confirming mtime is the normal staleness key, which
  is why `touchBundle` bumps it) and `-R` is *"Recursive directory scan, **descending into packages**
  and invisible directories"*. `touchBundle` passes **both** on a bundle path, i.e. a forced,
  fully-recursive descent *into* a helper containing Sparkle, Firebase and Google frameworks — on
  every flip. `-f` alone is the `LSRegisterURL(url, true)` equivalent; `-R` is pure waste here.
  The same help text shows this is a database-maintenance tool (`-delete` "You must then reboot!",
  `-gc` "Garbage collect old data and compact the database"). `[SOURCE — shipped tool's help output]`
- **The icon cache is acknowledged by Apple in exactly two terse man pages and nowhere else.**
  `man iconservicesd(1)`: *"iconservicesd – deamon responsible for managing the shared icon cache.
  iconservicesd is used by the system to add and remove images to/from shared icon cache."*
  `man iconservicesagent(1)`: *"agent responsible for **generating icon images from the resources
  provided in application bundles** and by the system."* That is the whole of Apple's documentation.
  No cache key, no invalidation rule, no API. `[SOURCE — shipped man pages]`

  The closest Apple engineering comes is a DTS reply distinguishing *"Your app is built wrong"* from
  *"**The system has cached the old info**"*, and adding: *"That sounds like an old bug. **macOS has a
  long history of problems like this**, dating all the way back to traditional macOS. I don't know
  what the state of the art for this is on current versions of the system."* `[APPLE STAFF]`
  Source: https://developer.apple.com/forums/thread/729965

  **Undocumented:** what invalidates the icon cache. The circulated `rm -rf …com.apple.iconservices.store;
  killall Dock` recipe appears only in developer-to-developer forum threads, never in Apple
  documentation. `[OBSERVED]` Source: https://developer.apple.com/forums/thread/676723
- **`killall Dock` is not sanctioned, and the only shipped Apple text on the subject is negative.**
  `man 8 Dock`, in its entirety, verified here:
  ```
  NAME
       Dock – Provides the Dock interface for the system
  DESCRIPTION
       Dock dock goose

       There are no options for Dock, and users should not run Dock manually.
  ```
  `[SOURCE — shipped man page, verified here]` `killall Dock` appears in no Apple developer
  documentation, technote or support article. **Undocumented community folklore** — consistent with
  what [dock-tile-display-names.md](dock-tile-display-names.md) already records.
- **Apple DTS on the surrounding technique, which also bears on our Dock *reads*:**
  > "**Unless otherwise documented, system preferences files are not considered API.** Relying on them
  > incurs a significant binary compatibility risk. … **In short, don't start down that path!**"
  >
  > "`UserDefaults` is better than reading the property list directly, but it still has the same
  > fundamental problem: **Unless otherwise documented, the domain, keys, and values for Apple
  > preferences are implementation details, not API.**"
  >
  > (on programmatically pinning a Dock item) "Has apple provided an API for this? — **No.** … **That
  > technique is not supported.**"

  `[APPLE STAFF]` Source: https://developer.apple.com/forums/thread/747595 ·
  https://developer.apple.com/forums/thread/736974

  Recorded plainly because it cuts both ways: it is the same objection that applies to §B's
  `AppleInterfaceStyle` / `AppleIconAppearanceTheme` reads and to `DockPrefs.read()`. Moving to
  `UserDefaults` (§B7) fixes the *documented API-contract* violation; it does **not** make the keys
  themselves API. Nothing does — there is no alternative, which is why the right posture is
  defensive reading (§Recommendations 1), not a search for a supported key.
- Our own previously-verified finding still stands and is the reason `touchBundle` alone is
  insufficient: rewriting a helper's `.icns` in place plus mtime plus `lsregister` does **not** make
  the Dock redraw an unchanged `persistent-apps` entry — only re-seating the entry does (see
  [architecture.md](../.claude/rules/architecture.md), "Refresh the Dock icon cache after an in-place
  regenerate"). Apple documents nothing about how the Dock decides to redraw a pinned entry's icon.
  `[OBSERVED — previously verified in this project]`

### C10. Rate limits, throttling, known pathologies

- **No documented rate limit, throttle or backoff exists** on `LSRegisterURL` or `lsregister` —
  nothing in the reference docs, in *Launch Services Concepts*, in `LSInfo.h`, or in the tool's help
  text. There is no error code for excessive registration. **Undocumented.**
- **No documented cost model** for Launch Services registration or database rebuild either. What the
  documentation *does* establish is that the LS database is a **global, machine-wide, shared**
  resource: the automatic registration utility runs *"whenever the system is booted or a new user
  logs in"* and scans four domains, and the maintenance tool offers `-gc` compaction and a `-delete`
  that requires a reboot. Writing to it several hundred times a day from five agent processes is
  outside anything the documentation contemplates, even though no document forbids it by name.
  `[DOCUMENTED facts + INFERENCE]`
- **The one pathology Apple does describe is behaviourally what an affected Dock Tile machine looks
  like.** DTS, on why plug-in registration testing is unreliable on a dev machine:
  > "My experience is that testing plug-in registration on your development machine is **extremely**
  > error prone. The problem is that **your development machine regularly builds and rebuilds** the
  > plug-in (and, if you have one, the host app), sometimes in an inconsistent state, and **that can
  > confuse the automatic plug-in registration mechanism.**"

  `[APPLE STAFF]` Source: https://developer.apple.com/forums/thread/46883

  Apple's remedy for a dev machine is "test on a clean machine". There is no remedy for a user whose
  Mac is doing this continuously. `[INFERENCE]` The same DTS post also notes that explicit
  registration is usually unnecessary: *"Most users don't have a bazillion copies of your app
  installed; most users have a single copy of your app in `/Applications`, where the `LSRegisterURL`
  is unnecessary."*
- **The concrete cost is in our own code and is measurable without Apple's help.** `[INFERENCE from
  source]` `switchIcon` → `touchBundle` does a delete + copy, two `setAttributes`, then
  `Process.run()` + **`waitUntilExit()`**, invoked from the 1-second `Timer` handler in
  `HelperAppDelegate` — i.e. on the `@MainActor`. Every flip blocks a helper's main thread for a
  synchronous, recursive `lsregister` descent into a framework-bearing bundle. At 548 flips/day that
  is 548 synchronous subprocess spawns per affected install. Whether this contributes to the separate
  "helper at 82.9 % CPU" report ([diagnostics.md](../.claude/rules/diagnostics.md), "Spin watchdog")
  is **worth checking against the watchdog captures — it is a correlation to test, not a claim**.

---

## D. Debouncing / robustness guidance

### D11. Apple guidance on debouncing and on expected frequency

- **There is no debouncing or coalescing guidance, and no stated frequency.** No Apple document,
  header comment or WWDC session addresses either. **Undocumented — and the absence is the finding:**
  the rate-limiting policy has to be ours and has to be explicit.
- **The one frequency-adjacent instruction Apple does give points the opposite way — do the work, but
  fast:**
  > "**Avoid expensive tasks during appearance transitions.** When the user toggles between light and
  > dark interfaces, the system asks your app to redraw all of its content. … Your code must be as
  > quick as possible and not perform tasks unrelated to the appearance change. In macOS, AppKit
  > usually creates transition animations during appearance changes, **but it aborts those animations
  > if your app takes too long to redraw itself.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface
  (the canonical Dark Mode article, linked from AppKit's Appearance Customization page)

  A synchronous `lsregister` spawn on the main thread is the textbook violation of that instruction.
  `[INFERENCE]`
- **The sanctioned detection mechanism is stated most explicitly in a shipped header's deprecation
  message**, and it is neither polling nor distributed notifications:
  > `API_DEPRECATED("Changes to the accent color can be manually observed by implementing
  > -viewDidChangeEffectiveAppearance in a NSView subclass, or by **Key-Value Observing the
  > -effectiveAppearance property on NSApplication**. …", macos(10.0, 11.0))` — `NSCell.h`

  `[SOURCE — shipped SDK header]`. The Dark Mode article says the same for non-view code: *"If your
  app has code that's not part of an `NSView` and can't use the preferred methods listed above, it can
  observe the app's `effectiveAppearance` property"*, and a DTS Engineer confirms it on the forums:
  *"the standard way to be notified for appearance changes is by use KVO to observe the
  `effectiveAppearance` property."* `[DOCUMENTED]` + `[APPLE STAFF]`
  Source: https://developer.apple.com/forums/thread/710135
- **One documented mechanism does deliver many callbacks per logical change** — the *drawing*
  appearance, which is thread-local and explicitly not a system-state signal. The shipped
  `NSAppearance.h` is blunt about it:
  > "Automatically set by NSView before that view's `drawRect:`, `updateLayer`, and `layout` methods
  > are invoked. **At other times its return value is unreliable** (depending on if the previous
  > caller restored it to a previous value after setting it). **This is not the correct way to
  > determine the 'system' appearance.** Use a view's, window's, or the app's `effectiveAppearance`."

  `[SOURCE — shipped SDK header]`, matching the reference text *"When AppKit draws a control, it
  automatically sets the current appearance on the current thread to the control's appearance."*
  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/appkit/nsappearance ·
  https://developer.apple.com/documentation/appkit/nsappearance/current

  `viewDidChangeEffectiveAppearance` is per-view by construction, so one logical change produces N
  callbacks; Apple documents **no** duplicate delivery for KVO on `NSApplication.effectiveAppearance`.
  `[INFERENCE]`
- The distributed-notification path is documented as unreliable in both directions — droppable,
  unbounded latency, suspended and coalesced while inactive (quoted with sources in §A3). Combined
  with an unrate-limited handler and a 1 Hz poll, the current design has **no bound** on how often
  the expensive path can run. `[DOCUMENTED + INFERENCE]`

### D11b. Two of our three notification observers cannot fire on macOS 26 — verified here

This refines §A2, where I could only say the three names are undocumented. They are not equally
real, and the difference is directly actionable.

Verified on this machine (macOS 26.6.2, build 25G83) by scanning the dyld shared cache
(`/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e.01/.05/.09`):

| Name Dock Tile observes | Occurrences found |
|---|---|
| `AppleInterfaceThemeChangedNotification` | **15** (12 in `.01`, 3 in `.05`) — real, undocumented SPI |
| `AppleIconAppearanceThemeChangedNotification` | **0** — does not exist |
| `com.apple.desktop.darkModeChanged` (and bare `darkModeChanged`) | **0** — does not exist |

Also found: `ApplePrivateInterfaceThemeChangedNotification` (4) and
`NSWorkspaceIconAppearanceConfigurationDidChangeNotification` (1). `[OBSERVED — verified here]`

**`NSWorkspaceIconAppearanceConfigurationDidChangeNotification` is an exported AppKit symbol** —
`_NSWorkspaceIconAppearanceConfigurationDidChangeNotification` is present in
`MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit.tbd`, verified here — but it
appears in **no public header** and on **no documentation page** (`NSWorkspace`'s reference lists no
appearance notification). It is exported SPI, not API. `[SOURCE — shipped SDK stub library, verified
here]` Also verified: `grep -rl AppleInterfaceStyle` across every framework in the macOS 26 SDK
returns **nothing** — the key is in no header at all.

**Consequences** `[INFERENCE]`:
1. Two of the three observers registered in both `HelperAppDelegate` and `IconStyleManager` are
   **dead code** on Tahoe. They cannot contribute to the 548 events, and removing them changes
   nothing except cost and noise.
2. The oscillation must therefore be arriving via the **1-second poll** or via
   `AppleInterfaceThemeChangedNotification` — and the latter is suspended-and-coalesced for an
   inactive Ghost-mode helper (§A3). That narrows the investigation to the poll's read path.
3. `NSWorkspaceIconAppearanceConfigurationDidChangeNotification` is the name that actually
   corresponds to the signal we want. It is SPI; using it would trade one undocumented dependency
   for a better-targeted one. **Not recommended without deliberate acceptance of the SPI risk** —
   noted so the option is on the record.

### D12. Automatic Light/Dark switching, and the other environmental triggers

**This section gets the most attention because the telemetry pattern — bursts on days with
below-average user activity — points at an environmental trigger, and Apple's own user documentation
says the Auto switch is gated on the machine being idle.**

- **Apple documents Auto precisely, in the macOS 26 User Guide:**
  > "Choose the appearance for buttons, menus, and windows on your Mac. **Auto switches the appearance
  > from light to dark, based on the Night Shift schedule you set. If no schedule is set, Auto
  > switches the appearance based on sunrise and sunset times. Auto won't switch the appearance until
  > your Mac has been idle for at least a minute.**"

  `[DOCUMENTED]` Source: https://support.apple.com/guide/mac-help/change-appearance-settings-mchlp1225/26.0/mac/26.0 ·
  https://support.apple.com/en-au/guide/mac-help/mchl52e1c2d2/mac
- **Night Shift is documented to drive appearance — this is not a misconception:** *"If your
  Appearance setting is set to Auto, your Mac switches appearance from light to dark based on the
  Night Shift schedule you set: **When Night Shift is on, the appearance is dark.**"* Night Shift's own
  schedule *"uses your computer's clock and geolocation to determine when it's sunset in your
  location."* **True Tone** has no documented relationship to appearance — treating it as an input is
  a misconception with no first-party support. `[DOCUMENTED]`
  Source: https://support.apple.com/en-us/102191

Three things follow, and the third is where I have to be careful not to overclaim:

1. **The switch is condition-gated, not clock-driven.** It is not "at sunset"; it is "at or after the
   Night Shift boundary, once the Mac has been idle for a minute". Something in the system has to
   *re-evaluate* a pending transition against an idleness condition, so the flip time is
   non-deterministic and coupled to user activity. `[INFERENCE from DOCUMENTED]`
2. **That gate is an idleness gate — the same axis on which affected installs differ from healthy
   ones.** An idle machine satisfies the condition immediately; a machine in use defers it. Any
   instability in that machinery would be *expressed* on idle machines and *suppressed* on busy ones,
   which is the observed telemetry shape. `[INFERENCE]`
3. **But nothing Apple documents can produce 548 events/day.** Auto is documented as a schedule-boundary
   state change, i.e. **at most twice a day**. Apple documents no transition period, no repeated
   firing, and no instability window. So the idle correlation makes Auto a plausible *trigger* — the
   thing that happens near the burst — without making it a sufficient *cause*. **Whether a
   pending-but-gated transition can flip the stored value more than once is undocumented; no primary
   source found.** Combined with §D11b (two observers inert, the third suspended), this points the
   investigation firmly at our own read path rather than at documented OS behaviour. `[INFERENCE]`

- **A same-subsystem Apple defect shipped in this very release cycle**, which is worth knowing before
  we assume our code is the only suspect. macOS 26 release notes:
  > "Fixed: Finder does not display Dark Mode app icons or tinted folder colors when the Folder Color
  > setting in System Settings > Appearance is set to **Automatic**. (152193702)"

  Same subsystem, same "Automatic" mode, an acknowledged Apple bug in the Tahoe cycle. Not our bug,
  but it establishes that Automatic icon-appearance resolution shipped with defects in 26.
  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes
- **The Icon & widget style options are documented — and the documented option set is larger than the
  value set our code handles:**
  > "**Default:** Items are opaque, and the background is either light or colored, depending on the app."
  > "**Dark:** … Choose **Always** to always show items in Dark style. Choose **Auto** to switch between
  > Dark and Light, depending on system appearance."
  > "**Clear:** … Choose **Light** for a light appearance, choose **Dark** for a darker appearance, or
  > choose **Auto** to switch between Dark and Light, depending on system appearance."
  > "**Tinted:** Items are opaque against a dark background."

  `[DOCUMENTED]` Source: https://support.apple.com/guide/mac-help/change-appearance-settings-mchlp1225/26.0/mac/26.0

  Apple never maps these onto `AppleIconAppearanceTheme` strings (§A1), but the shape is informative:
  **Clear has documented Light and Dark sub-options that `IconStyle.from` has no case for.** It
  handles `"ClearAutomatic"` / `"Clear"` / `"RegularClear"`; a user selecting Clear → Light or
  Clear → Dark would, on the obvious naming, produce a value that falls into `default:` and resolves
  to `.defaultStyle`. That is a **correctness gap independent of the oscillation**, and another
  instance of the same root problem — unknown values silently treated as a real style.
  `[INFERENCE from DOCUMENTED options + source reading]`

  It also means two independent "Auto" layers compose into one resolved value: the icon style can be
  Auto, and the system appearance it follows can itself be Auto. A compounding surface — though
  nothing documented makes either layer flap. `[INFERENCE]`
- **Every other environmental trigger is undocumented.** No primary source states that login,
  wake from sleep, screen lock/unlock, fast user switching, screen sharing, Stage Manager or display
  reconfiguration causes appearance re-evaluation. Checked directly: Apple's *Supporting Fast User
  Switching* and *User Switch Notifications* archive documents contain the words "appearance",
  "theme" and "dark" **zero times**; `NSWorkspace.didWakeNotification` and QA1340 say nothing about
  appearance; `CGDisplayRegisterReconfigurationCallback` has no appearance relationship.
  **Undocumented; no primary source found — and no credible community reproduction either, so this
  should not even be treated as folklore-supported.**
  Source: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/Concepts/FastUserSwitching.html ·
  https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification

---

## Unknowns / undocumented

Everything below could **not** be established from a primary source. This list is why we should
instrument before committing to a root-cause fix.

1. `AppleIconAppearanceTheme` — not documented by Apple anywhere; no public API supersedes it.
   Verified here: `AppleInterfaceStyle` appears in **no header in the macOS 26 SDK**. (§A1, §D11b)
2. The complete value set of `AppleIconAppearanceTheme`, and the mapping from the User Guide's option
   names (Default / Dark·Always / Dark·Auto / Clear·Light / Clear·Dark / Clear·Auto / Tinted) onto
   those strings. Our handled set is field-observed only. (§A1, §D12)
3. Whether `AppleInterfaceStyle` being **absent** rather than `"Light"` in Light appearance is
   contractual. Verified here; documented nowhere; the only forum thread on it has **no Apple-staff
   reply**. (§A2)
4. The notification names. `AppleInterfaceThemeChangedNotification` is real but undocumented SPI;
   `AppleIconAppearanceThemeChangedNotification` and `com.apple.desktop.darkModeChanged` **do not
   exist on macOS 26.6.2** (verified here); `NSWorkspaceIconAppearanceConfigurationDidChangeNotification`
   is an exported-but-unheadered AppKit symbol. (§A2, §D11b)
5. Whether a CFPreferences read can **transiently return `nil` or a different value** while the
   setting is unchanged. No primary source. The documented caching behaviour predicts a *stuck*
   value, not a flapping one. **This is one of the two places the root cause can live.** (§B4, §B6)
6. Whether a synchronize before a read **guarantees** freshness on a cfprefsd-mediated macOS. The
   reference page and the 10.8 release note say different-sized things and neither closes the loop.
   (§B5)
7. Whether KVO on `UserDefaults.standard` fires for a key resolved through the **`NSGlobalDomain`
   fall-through**. Apple documents the general cross-process KVO guarantee but not this case. **Must
   be verified experimentally before relying on it.** (§B7)
8. Whether code-signing identity (ad-hoc vs Developer ID) affects `DistributedNotificationCenter`
   delivery or CFPreferences reads. No primary source. (§A3)
9. Modern CFPreferences internals — the cfprefsd-backed `CFXPreferences` path is **not** in the
   open-source CoreFoundation drop, so cache coherency on macOS 26 cannot be checked against source.
   (§B6)
10. Any sanctioned API or documented invalidation path for the icon cache. Two terse man pages
    acknowledge a "shared icon cache" and say nothing else. `killall Dock` is documented nowhere and
    `man 8 Dock` says users should not run Dock manually. (§C9)
11. Any documented rate limit, throttle or cost model for repeated Launch Services registration.
    (§C10)
12. Any Apple guidance on debouncing appearance-change handling, or any statement of expected
    appearance-change frequency. The only adjacent guidance says the opposite — be fast. (§D11)
13. Whether the Auto appearance transition has an instability window, or can fire more than once per
    schedule boundary. Documented as an idle-gated, at-most-twice-daily state change. **This is the
    leading environmental hypothesis and it is undocumented.** (§D12)
14. Whether login, wake-from-sleep, screen lock, fast user switching, screen sharing, Stage Manager
    or display reconfiguration trigger appearance re-evaluation. No primary source, and no credible
    community reproduction. (§D12)
15. How the Dock decides to redraw a `persistent-apps` entry's icon. Entirely reverse-engineered.
    (§C9)

**The honest bottom line.** We now have **three** documented violations that are real and worth
fixing on their own merits — passing `kCFPreferencesAnyApplication` to an API that documents "do not
pass" it (§B4); modifying a signed bundle, which Apple documents as unsupported and DTS has answered
for this exact icon case (§C8b); and shipping a dependency on `lsregister`, which DTS says is "for
debugging only… not considered API" (§C9). **But we still do not have a documented mechanism that
explains the oscillation.** Nothing Apple documents produces 548 events/day: Auto is an at-most-twice-daily
idle-gated event, and two of our three notification observers are provably inert. That leaves the
1 Hz read path — items 5 and 13 — and neither can be settled from Apple's documentation.

---

## Recommendations for Dock Tile

Ordered. Each says which section justifies it, and whether it is safe to ship **before** we have
proof of the root cause.

### Safe to do now — correct regardless of the root cause

1. **Make "unknown / unreadable" a no-op, not a style change.** `[§B6, §D12 — safe now]`
   `IconStyle.from(preferencesValue:)` collapses `nil` **and** every unrecognised string to
   `.defaultStyle`, so one anomalous read becomes a genuine style transition — and, given the
   `guard newStyle != currentIconStyle` in both handlers, costs exactly two `icon_style_changed`
   events, two `.icns` rewrites and two `lsregister` spawns. Add a distinct "could not resolve"
   outcome and have both `checkForIconStyleChange` and `handleIconStyleChange` **return without
   changing state** on it. This bounds the damage from *every* unproven mechanism in the Unknowns
   list, and it also closes the documented `Clear → Light` / `Clear → Dark` gap (§D12) by refusing to
   guess rather than guessing "Default". **Highest value per line changed.**

2. **Stop passing `kCFPreferencesAnyApplication` to `CFPreferencesCopyAppValue`.** `[§B4, §B7 — safe
   now]` Apple's reference explicitly forbids that argument. Preferred replacement:
   `UserDefaults.standard.string(forKey:)`, which reaches the same keys through the documented
   `NSGlobalDomain` fall-through. Acceptable alternative: the primitive
   `CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
   kCFPreferencesAnyHost)`, which *is* documented to accept that domain. Do **not** "fix" it by
   adding `CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)` — the same prohibition applies
   to that call. Note the honest limit (§C9, DTS): this fixes the API-contract violation; it does not
   make the keys themselves API, and nothing can.

3. **Delete the two dead notification observers; keep one, registered correctly.** `[§D11b, §A3 —
   safe now]` `AppleIconAppearanceThemeChangedNotification` and `com.apple.desktop.darkModeChanged`
   **do not exist on macOS 26.6.2** (verified here) — they are dead code in *both*
   `HelperAppDelegate` and `IconStyleManager`, i.e. four inert registrations per helper. Keep
   `AppleInterfaceThemeChangedNotification`, and register it with
   `NSNotificationSuspensionBehaviorDeliverImmediately`, which is documented to bypass the
   suspension that otherwise silences it for an inactive Ghost-mode helper. While there: each helper
   currently runs **two** pollers (1 s in `HelperAppDelegate`, 2 s inside `IconStyleManager.shared`,
   which helpers instantiate via `NativePopoverViews`) — collapse to one.

4. **Log both raw preference strings on every transition.** `[§B6, §Unknowns 5 — safe now, and this
   is the instrumentation]` Non-verbose, per flip: the raw `AppleIconAppearanceTheme` string (or
   "absent"), the raw `AppleInterfaceStyle` string (or "absent"), the resolved style, which path
   detected it (poll vs notification), and process uptime. 548/day is ~1 per 2.6 minutes, so the cost
   is negligible, and it is the **only** thing that distinguishes "the system really changed the
   setting" from "our read misbehaved". **Ship this in the same release as items 1–3** — without it,
   items 5 and 13 of the Unknowns stay unresolved forever.

5. **Rate-limit the expensive path, not just the decision.** `[§C10, §D11 — safe now]` Apple
   documents no expected frequency and no throttle, and its only adjacent guidance is *"avoid
   expensive tasks during appearance transitions… your code must be as quick as possible"* — which a
   synchronous `lsregister` spawn on the main thread flatly violates. Require the same resolved style
   on N consecutive samples before acting (hysteresis, not a plain debounce), and hard-cap actual
   `.icns` rewrites per process per hour, logging when the cap trips. A tile being correct 30 seconds
   late is invisible; 548 rewrites a day is not.

6. **Replace the `lsregister` subprocess with `LSRegisterURL(url, true)`.** `[§C9, §C10 — safe now]`
   Apple DTS is explicit that `lsregister` is *"for debugging only; … not considered API"* and *"Do
   not ship anything that depends on the presence or output of this tool"* — and we ship it, on a
   1 Hz-driven path. `LSRegisterURL` is public, non-deprecated, macOS 10.3+ (verified in the shipped
   SDK header), and `inUpdate: true` is the exact semantic of `-f`. This also removes a
   `waitUntilExit()` from the `@MainActor` and drops the `-R` recursive descent into
   Sparkle/Firebase/Google frameworks that we currently pay for on every flip for no benefit.

7. **Add `codesign --verify` output to Copy Diagnostics.** `[§C8b — safe now]` Verified here: a
   helper that has performed a runtime icon swap fails with *"a sealed resource is missing or
   invalid / file modified: …/AppIcon.icns"*, while one that has not verifies clean. That is a free,
   per-tile, on-disk indicator of whether a given tile has been flipping — available in a user's
   diagnostics report with no new telemetry.

### Needs the instrumentation first

8. **Do not add synchronize-before-every-read on the strength of the stale-cache theory.** `[§B5,
   §B6 — needs proof]` Apple's guidance is *"You should typically not… call these functions before
   every read of a preference key"*, and a stale cache predicts a **stuck** value, not the flapping we
   see. If item 4's logging shows genuine read anomalies, revisit. (Deliberate contrast with the
   Dock-plist convention in [architecture.md](../.claude/rules/architecture.md), which was adopted
   against a *reproduced* cold-cache bug and is a once-per-user-action cost, not a 1 Hz one.)

9. **Verify `UserDefaults` KVO on the global-domain fall-through before adopting it.** `[§B7,
   §Unknowns 7 — needs proof]` It is the one documented cross-process change signal (*"Key-value
   observing reports all updates to setting values, regardless of which process made the change"*)
   and would replace both the poll and the SPI notification. But Apple does not document it for a key
   resolved via `NSGlobalDomain`. A short experiment settles it; do not adopt on the documentation
   alone.

10. **Test the Auto-appearance hypothesis directly.** `[§D12, §Unknowns 13 — needs proof]` Apple
    documents that Auto *"won't switch the appearance until your Mac has been idle for at least a
    minute"*, which gates the transition on exactly the axis (idleness) separating affected installs
    from healthy ones. With item 4 in place, an affected user's diagnostics will show whether the
    burst is `AppleInterfaceStyle` genuinely changing repeatedly (an OS behaviour we work around) or
    our read of it misbehaving (a bug we own). Leaving a Mac idle across a scheduled Night Shift
    boundary with logging on is a cheap local repro attempt — though a negative result proves nothing.
    Note for triage: Apple shipped and fixed a same-subsystem "Automatic" icon-appearance bug in the
    macOS 26 cycle (§D12), so "it's the OS" is not an unreasonable prior — it just isn't proven.

### Longer term, recorded not proposed

11. **Adopt Apple's own prescription for updating a live app: copy, modify the copy, swap.** `[§C8b]`
    DTS, on this exact problem: *"avoid modifying any app that the user has previously run. If you're
    updating a live app, make a copy of it and then modify the copy, using APFS clone to minimise the
    disk space impact."* That is much closer to `installHelper` (copy → modify → sign → place) than to
    the in-place `switchIcon` + `touchBundle` path, and it would restore a valid seal on every change.
    Re-signing ad-hoc after a swap is the cheaper half-measure — but it makes each flip *more*
    expensive, which is a further reason to fix the flip **rate** (items 1 and 5) first.

12. **`NSDockTilePlugIn` is the only Apple-documented way to customise a pinned tile whose app is not
    running.** `[§C8]` It would move appearance handling into a system-loaded plug-in and remove the
    per-helper poll entirely. Large change; recorded so the option is not lost.

13. **If a targeted signal is ever wanted, `NSWorkspaceIconAppearanceConfigurationDidChangeNotification`
    is the right name — and it is SPI.** `[§D11b]` It is an exported AppKit symbol (verified in the
    macOS 26 SDK stub library) with no public header and no documentation. Using it trades one
    undocumented dependency for a better-targeted one; only do so as a deliberate, recorded choice.

---

## E. Validating the event-driven design (documentation pass)

**The question this section answers.** Sections A–D were written to explain an *oscillation*. This
one answers a different, forward-looking question: **can appearance detection be made reliable
enough with NO timer at all?** The maintainer's position is *"if the event-based solution is
failproof, I don't see a reason for a timer."* This section is deliberately adversarial — it argues
the case **against** before concluding.

**Method and its limits, stated up front.** This is a **documentation-only** pass: no command was
run and nothing was reproduced on the machine. Two consequences you should weigh when reading it:
(1) every "verified here" claim in this section is absent — where A–D could settle a question by
scanning the dyld cache, E cannot, so it says **NEEDS LOCAL VERIFICATION** instead; and (2)
`developer.apple.com/forums` returned **HTTP 403** to every fetch attempt, so forum material below is
quoted from search-engine summaries and is marked with its attribution confidence. Where a section
of A–D is refined or contradicted, E says so with a pointer rather than editing A–D.

---

### E14. Delivery guarantees — "suspended", "coalesced" and "dropped" are three different things

The single most important correction this section makes: §A3 treats *suspension* and *dropping* as
one hazard. Apple documents them as **two independent mechanisms with different triggers and
different remedies**, and `DeliverImmediately` addresses only one of them.

#### E14a. What "not active" means, and whether an accessory helper is permanently inactive

- **The suspension rule, restated from the primary source** (this is the same quote as §A3, refetched
  to confirm it is still current):
  > "The `NSApplication` class automatically suspends distributed notification delivery when the
  > application is not active. Applications based on the Application Kit framework should let AppKit
  > manage the suspension of notification delivery. Foundation-only programs may have occasional need
  > to use this method."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspended
- **The archived Notification Programming Topics article is more explicit about the *context* in
  which suspension happens, and it is the fullest treatment Apple has ever published:**
  > "When a process is no longer interested in receiving notifications immediately, it may suspend
  > notification delivery. This is often done when the application is hidden, or is put into the
  > background. (The `NSApplication` object automatically suspends delivery when the application is
  > not active.)"
  >
  > "You suspend notifications by sending `setSuspended:YES` to the distributed notification center.
  > When the process resumes notification delivery, **all queued notifications are delivered
  > immediately.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Notifications/Articles/Registering.html
- **"Active" is never defined.** `NSApplication.isActive`'s entire documentation is *"A Boolean value
  indicating whether this is the active app."* / *"The value of this property is `true` if the app is
  active or `false` if it's not."* — circular. Apple publishes no definition of the predicate, and no
  document states the exact moment AppKit calls `setSuspended:`. `[DOCUMENTED — and the circularity
  is the finding]`
  Source: https://developer.apple.com/documentation/appkit/nsapplication/isactive
- **So: does "inactive" mean "not frontmost", or something narrower?** `[INFERENCE]` macOS has exactly
  one active app at a time, and Apple's own framing pairs "not active" with *"hidden, or … put into
  the background"*. The only reading the documentation supports is the broad one: **not frontmost =
  not active = suspended.** There is no documented narrower sense (e.g. "only when hidden", or "only
  when the app has been backgrounded for N seconds"). If a narrower rule exists it is an
  implementation detail. **This is the reading that hurts us**, and nothing in Apple's documentation
  offers a way out of it.
- **Is an accessory app *permanently* inactive? No — and this matters in both directions.**
  Apple documents `.accessory` as an app that *"doesn't appear in the Dock and doesn't have a menu
  bar, but it may be activated programmatically or by clicking on one of its windows."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory

  And Dock Tile's own helper implements `applicationDidBecomeActive` / `applicationDidResignActive`
  and handles `applicationShouldHandleReopen`
  ([HelperAppDelegate.swift](../DockTile/App/HelperAppDelegate.swift)), i.e. the helper **does**
  become active when the user clicks its tile. `[SOURCE — this repo]`

  **Consequence** `[INFERENCE]`: a Ghost helper is inactive ~100 % of wall-clock time but not
  permanently. Under the default `Coalesce` behaviour the queued notification is therefore delivered
  — *at the moment the user clicks the tile*, which is exactly too late to have painted the right
  icon. **The design is not "notifications never arrive"; it is "notifications arrive after the user
  has already seen the wrong icon."** That is a worse failure than a silent drop, because it is
  invisible in any log that only records "did the observer fire".
- **Whether AppKit's automatic suspension applies at all to a `.accessory` process is itself
  undocumented.** No Apple document addresses `LSUIElement` / `.accessory` in combination with
  distributed-notification suspension. It is plausible AppKit skips suspension for an app that can
  never be frontmost in the normal sense — and equally plausible it does not.
  **NEEDS LOCAL VERIFICATION** (this is verification item 2 below).

#### E14b. `DeliverImmediately` — precisely what it fixes

- **The full discussion, which is more useful than the one-line quote in §A3:**
  > "The server delivers notifications matching this registration irrespective of whether `suspended`
  > with an argument of `true` has been called. **When a notification with this suspension behavior is
  > matched, it has the effect of first flushing any queued notifications.** The effect is as if
  > `suspended` with an argument of `false` were first called if the application is suspended,
  > followed by the notification in question being delivered, followed by a transition back to the
  > previous suspended or unsuspended state."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior/deliverimmediately

  The archived article states the same and adds the reciprocal poster-side option
  (`postNotificationName:object:userInfo:deliverImmediately:`), which is **not** available to us —
  we are the receiver, and the poster is a system daemon. `[DOCUMENTED]`
  Source: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Notifications/Articles/Registering.html
- **What we register today is the wrong one.** `IconStyleManager.setupObservers()` uses
  `DistributedNotificationCenter.default().addObserver(forName:object:queue:)`
  ([IconStyleManager.swift](../DockTile/Managers/IconStyleManager.swift)) — a cover method with no
  explicit suspension argument, and Apple documents that *"In cover methods for which suspension
  behavior is not an explicit argument, `NSNotificationSuspensionBehaviorCoalesce` is the default."*
  `[DOCUMENTED]` + `[SOURCE — this repo]`
  Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior/coalesce
- **One piece of good news, and it is worth stating plainly** `[INFERENCE from DOCUMENTED]`:
  `Coalesce`'s "only the last notification of the specified name is queued" is **semantically
  harmless for us**. Appearance is a *level*, not an *edge* — we re-read the preference in the
  handler and never use the notification's payload, so collapsing ten flips into one loses nothing.
  Coalescing is not the bug. **Deferral is.** Switching to `.deliverImmediately` fixes the deferral,
  and it is the one documented, first-party, zero-risk change available in this whole area.

#### E14c. Dropping — a different mechanism, and `DeliverImmediately` does not touch it

This is the distinction the brief asked to be precise about, and Apple's own wording keeps the two
apart cleanly.

| | Suspension-time queueing | Server-queue overflow |
|---|---|---|
| Trigger | receiver is not the active app | **too many notifications posted, system-wide** |
| Documented in | `SuspensionBehavior` cases | `DistributedNotificationCenter` overview |
| Scope | per-registration policy | global to the notification server |
| Controlled by receiver? | **Yes** — `suspensionBehavior:` | **No** |
| Fixed by `DeliverImmediately`? | **Yes** | **Not documented to be. Assume no.** |

- **The overflow statement, verbatim:**
  > "Posting a distributed notification is an expensive operation. … **The latency between posting the
  > notification and the notification's arrival in another task is unbounded. In fact, when too many
  > notifications are posted and the server's queue fills up, notifications may be dropped.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter
- **Everything about *when* this happens is undocumented.** Apple publishes **no** queue size, **no**
  threshold for "too many", **no** error code, **no** back-pressure signal, and **no** delivery
  receipt. The only adjacent number is in `Hold`, and it is explicitly unspecified: *"the server holds
  all matching notifications until the queue has been filled (**queue size determined by the
  server**), at which point the server **may** flush queued notifications."* Note "may".
  `[DOCUMENTED — absence, plus deliberately unspecified wording]`
  Source: https://developer.apple.com/documentation/foundation/distributednotificationcenter/suspensionbehavior
- **Therefore: there is no delivery guarantee, at any suspension behaviour.** `[INFERENCE from
  DOCUMENTED]` `DeliverImmediately` is documented purely in terms of the `suspended` flag — every
  sentence of its discussion is about suspension. Nothing extends it to overflow. Reading it as "now
  delivery is guaranteed" is exactly the false-confidence this note exists to prevent.
- **Honest counterweight, so the risk is not overstated** `[INFERENCE]`: the documented drop condition
  is *system-wide posting load*, not something a single idle Mac hits often. An appearance flip is a
  once-or-twice-a-day event and is not competing for queue space with itself. A drop is a **real but
  low-probability** event. The correct posture is not "the drop makes event-driven impossible"; it is
  "the drop makes an **unmonitored, unrecoverable** event-driven design impossible."

#### E14d. Sleep/wake, screen lock, fast user switching

- **Fast user switching is the one case Apple documents, and it documents a *scoping* rule, not a
  reliability rule:**
  > "Prior to the introduction of fast user switching, distributed notifications sent using either the
  > Core Foundation or Cocoa interfaces were delivered to any process that registered as an observer.
  > **With the introduction of fast user switching in OS X v10.3, the existing interfaces have changed
  > to limit distribution to registered processes in the current login session.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/Concepts/FastUserSwitching.html

  `[INFERENCE]` Appearance is a per-user setting and our helpers live in the user's own session, so
  session scoping is *mostly* aligned with what we want. The unresolved half: when the user is
  switched **away**, their helpers keep running in a background session — whether the appearance
  daemon still posts into that session, and whether AppKit considers a background-session app
  "active", is **undocumented**. This refines §D12's "fast user switching: no primary source found"
  by supplying the scoping rule while leaving the delivery question open.
- **Sleep/wake and screen lock: nothing. No primary source at all.** Apple documents no behaviour for
  distributed notification delivery across sleep, wake, display sleep, screen lock or unlock — not in
  the `DistributedNotificationCenter` reference, not in the archived Notifications topics, not in
  QA1340, not in the `NSWorkspace` sleep/wake notification pages. Whether a notification posted while
  the machine was asleep is delivered on wake, coalesced, or lost is **entirely undocumented**.
  **NEEDS LOCAL VERIFICATION.**
- **But there is a documented reason to think the *change itself* usually happens while awake**, which
  softens this risk: Auto *"won't switch the appearance until your Mac has been idle for at least a
  minute"* — a sleeping Mac is not evaluating the switch, so the flip most likely lands at or after
  wake, with the process running. `[DOCUMENTED]`
  Source: https://support.apple.com/guide/mac-help/change-appearance-settings-mchlp1225/26.0/mac/26.0
- **Community reports point the same way and are worth recording as a hypothesis only.** Multiple
  third-party write-ups describe the Auto switch landing at display-sleep/wake — e.g. that the theme
  "is being switched when you put the display to sleep" and that closing and reopening the lid applies
  a pending Dark Mode. `[OBSERVED — community, low trust, no Apple source, not reproduced here]`
  Source: https://codelearn.me/2022/10/28/macos-auto-theme.html

  `[INFERENCE]` If that is right, **wake is the single highest-value re-check trigger available**, and
  `NSWorkspace.didWakeNotification` is a documented, public, free event — an *event*, not a timer.
  Source: https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification

---

### E15. Is there a documented signal at all?

#### E15a. KVO on `UserDefaults.standard` for an `NSGlobalDomain` key

- **The documented guarantee is unchanged from §B7** and is still the only cross-process one Apple
  states: *"To detect changes made by another process, register a key-value observer on the
  `UserDefaults` object. Key-value observing reports all updates to setting values, regardless of
  which process made the change."* `[DOCUMENTED]`
  Source: https://developer.apple.com/documentation/foundation/userdefaults/didchangenotification
- **Nothing found in this pass resolves the `NSGlobalDomain` fall-through case.** The sentence is
  still written about *your app's* settings. Searching for a first-party statement covering a key the
  app does not own, reached through the global-domain search list, returned nothing.
  **Still undocumented** — §B7's caveat and Unknowns item 7 stand unchanged.
- **New evidence, and it is community, not Apple — but it is directly on point.** Jesse Squires's
  appearance-observation write-up registers **exactly our case**: `UserDefaults.standard` +
  `forKeyPath: "AppleInterfaceStyle"` (an `NSGlobalDomain` key reached by fall-through), and reports
  that it fires:
  > "This works but it is a hack. And in my testing **it can take a few seconds** before
  > `observeValue(forKeyPath:of:change:context:)` gets called."

  `[OBSERVED — community, 2020, macOS Catalina era, normal windowed app]`
  Source: https://www.jessesquires.com/blog/2020/01/08/observing-appearance-changes-on-ios-and-macos/

  `[INFERENCE]` Two things make this more interesting than a generic "it works" report. First,
  `AppleInterfaceStyle` is **absent** in Light mode (§A2), so a Light↔Dark flip is an
  *absent↔present* transition — the hardest KVO case, and it still fired. Second, the reported
  **multi-second latency** is itself a finding: it is consistent with cfprefsd mediating the change
  asynchronously (§B6), and it means KVO is not an instant signal even when it works. For an icon
  that only needs to be right, a few seconds is fine. Three caveats keep this from settling anything:
  it is six years and many OS versions old, it was a normal app with windows, and it says nothing
  about `AppleIconAppearanceTheme`. **NEEDS LOCAL VERIFICATION** (verification item 1).

#### E15b. `effectiveAppearance` in an accessory process with no windows

This is where the documentation is most encouraging on the surface and most hollow underneath.

- **Apple's own sample code registers it exactly where we would**, with no window in sight — in
  `applicationDidFinishLaunching`:
  > "If your app has code that's not part of an `NSView` and can't use the preferred methods listed
  > above, it can observe the app's `effectiveAppearance` property and update `NSAppearance.current`
  > manually."

  ```swift
  var observation: NSKeyValueObservation?

  func applicationDidFinishLaunching(_ aNotification: Notification) {
      observation = NSApp.observe(\.effectiveAppearance) { (app, _) in
          app.effectiveAppearance.performAsCurrentDrawingAppearance {
              // Invoke your non-view code that needs to be aware of the
              // change in appearance.
          }
      }
  }
  ```

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface

  This is the strongest documented support for the app-level KVO route and it is stronger than §D11
  recorded — it is not just a deprecation-message aside, it is a first-party code sample for
  **non-view code**.
- **Now the adversarial half, and it is a documented one.** Every definition of the property is written
  in terms of **windows and drawing**:
  - `NSApplication.appearance`, abstract: *"**The appearance associated with the app's windows.**"*
    Discussion: *"When the value of this property is `nil` (the default), AppKit applies the current
    system appearance to the app's user interface elements, **including its windows, views, panels,
    and popovers**."* `[DOCUMENTED]`
    Source: https://developer.apple.com/documentation/appkit/nsapplication/appearance
  - `NSApplication.effectiveAppearance`, in full: *"The appearance that AppKit uses to draw the app's
    interface."* / *"This property always contains an `NSAppearance` object representing **the
    appearance to use during drawing**. If you don't explicitly assign a value to the `appearance`
    property, the app inherits the system's effective appearance."* `[DOCUMENTED]`
    Source: https://developer.apple.com/documentation/appkit/nsapplication/effectiveappearance
  - `NSAppearanceCustomization`, abstract: *"A set of methods for getting and setting the appearance
    attributes of **a view**."* `effectiveAppearance` *"reflects any inherited attributes."*
    `[DOCUMENTED]` Source: https://developer.apple.com/documentation/appkit/nsappearancecustomization

  `[INFERENCE]` The property is documented as a **drawing** property whose value is *inherited* down a
  view hierarchy. Apple never states what it does in a process that has no windows and never draws.
  The sample above proves Apple intends app-level observation to work; it does **not** prove AppKit
  keeps pushing updates into a process with an empty window list. Those are different claims and only
  the first is documented.
- **Community evidence is split, which is itself the honest signal.**
  - For: *"a much better and more reliable solution, and the observation closure is called
    immediately"* — Jesse Squires, on `NSApp.observe(\.effectiveAppearance)`. `[OBSERVED — community]`
    Source: https://www.jessesquires.com/blog/2020/01/08/observing-appearance-changes-on-ios-and-macos/
  - Against: Christian Tietze reports **"mixed results with observing changes to this attribute"** on
    `NSApp.effectiveAppearance` and pivoted to observing the **main window's `contentView`** instead.
    `[OBSERVED — community]`
    Source: https://christiantietze.de/posts/2019/01/nsappearance-dark-mode-change-notification-rxswift/

  `[INFERENCE]` That second report is the more alarming one for us, because the workaround he
  landed on is precisely the dependency we cannot satisfy: **he fixed it with a window.** Both authors
  had windows; **neither tested a windowless `.accessory` process**, which is the only configuration
  we care about. **NEEDS LOCAL VERIFICATION** (verification item 3).
- **The decisive limitation, which no amount of verification can remove** `[INFERENCE from
  DOCUMENTED §A1]`: `effectiveAppearance` reports **Light/Dark only**. It cannot report
  `AppleIconAppearanceTheme` — §A1 established that no public API exposes the icon/widget style at
  all. So a user changing Icon style **Default → Tinted** (or → Clear) with no Light/Dark change
  produces **no `effectiveAppearance` change whatsoever**, and `IconStyle.resolve` would go on
  returning the old style. **`effectiveAppearance` can never be the sole event source for this
  feature.** It covers one of the two inputs to our resolution function. This is the finding that
  most constrains the verdict.

#### E15c. Every other documented cross-process mechanism

- **The Darwin notification centre is the strongest documented finding in this section, and it is
  structurally immune to the whole of §E14a.** Two first-party statements:
  > `suspensionBehavior` — "Flag indicating how notifications should be handled when the application
  > is in the background. … **If `center` is a Darwin notification center, this value is ignored.**"

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/corefoundation/cfnotificationcenteraddobserver(_:_:_:_:_:_:)

  > "The Darwin Notify Center **has no notion of per-user sessions, all notifications are
  > system-wide.** As with distributed notifications, the main thread's run loop must be running in one
  > of the common modes (usually `kCFRunLoopDefaultMode`) for Darwin-style notifications to be
  > delivered."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/corefoundation/cfnotificationcentergetdarwinnotifycenter()

  `[INFERENCE]` "suspensionBehavior is ignored" means a Darwin observer is **never suspended** —
  the AppKit inactive-app problem simply does not exist on this transport, by documentation rather
  than by hope. It also sidesteps the fast-user-switching session scoping of §E14d. Darwin
  notifications are now also a **documented public framework** (`DarwinNotify`, macOS 10.14+).
  Source: https://developer.apple.com/documentation/DarwinNotify
- **But Darwin notifications carry no delivery guarantee either — the `notify(3)` man page is candid:**
  > "**Notifications may be coalesced in some cases.** Multiple events posted for a name in rapid
  > succession may result in a single notification sent to clients registered for notification for
  > that name."
  >
  > "Note that the kernel limits the size of the message queue for any port. **If it is important that
  > notifications should not be lost due to queue overflow**, clients should service messages quickly,
  > and be cautious in using the same port for notifications for more than one name."

  `[DOCUMENTED — shipped man page]`
  Source: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/notify.3.html

  `[INFERENCE]` Same shape as §E14c: coalescing is harmless for a level signal; loss is possible and
  unquantified. Darwin removes the *suspension* hazard, not the *drop* hazard.
- **And the gap that makes it unusable today: there is no documented Darwin notification name for
  appearance or icon style.** We know from §D11b that `AppleInterfaceThemeChangedNotification` exists
  in the dyld cache as a *distributed* notification name. Whether any Darwin name is posted for
  Light/Dark or for `AppleIconAppearanceTheme` is **unknown and undocumented**.
  **NEEDS LOCAL VERIFICATION** (verification item 4 — `notifyutil -w`, cheap and non-destructive).
- **`NSWorkspace`: still no documented appearance notification.** `NSWorkspace`'s reference lists no
  appearance or icon-appearance notification, and the macOS 26 release notes introduce none — the only
  appearance-adjacent entry is the already-recorded Finder Automatic-icon bug fix (§D12).
  `[DOCUMENTED — absence]`
  Source: https://developer.apple.com/documentation/appkit/nsworkspace ·
  https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes

  This confirms §D11b's finding from the other direction: `NSWorkspaceIconAppearanceConfigurationDidChangeNotification`
  remains exported-but-undocumented SPI as of macOS 26.
- **launchd / XPC: nothing.** No documented launchd or XPC mechanism publishes appearance state. No
  primary source found.
- **A relevant DTS position on stringly-typed notification APIs generally**, which is the standing
  objection to *every* name in §D11b: *"the only supported strings are those documented by Apple,
  either by way of a string constant in the headers or explicitly in the documentation."*
  `[APPLE STAFF — attribution NOT confirmed: developer.apple.com/forums returned HTTP 403 to every
  fetch, so this is quoted from a search-engine summary of thread 686011. Treat the wording as
  approximate and re-read the thread in a browser before quoting it anywhere that matters.]`
  Source: https://developer.apple.com/forums/thread/686011
- **Also recorded, same 403 caveat:** DTS is reported to steer developers at this layer toward Darwin
  notifications over Foundation's distributed notifications, on the grounds that the latter *"introduce
  all sorts of complexity related to both login sessions and App Sandbox."* `[APPLE STAFF —
  attribution NOT confirmed, search-summary only]`
  Source: https://developer.apple.com/forums/thread/702840

---

### E16. Adversarial review — every way a timer-less design shows the wrong icon

Ordered by likelihood. "Duration" is how long the tile stays wrong. Note that **the wrong icon is
visible the whole time** — the Dock renders the on-disk `.icns`, so unlike a stale in-memory value
there is no "nobody is looking" grace period.

**1. There is no known event for the icon-style key at all.** `[DOCUMENTED — the decisive one]`
`AppleIconAppearanceThemeChangedNotification` **does not exist** (§D11b, verified in A–D);
`effectiveAppearance` cannot see icon style (§E15b); `NSWorkspace` has no public appearance
notification (§E15c). So today, a user changing **Default → Tinted/Clear** with no Light/Dark change
has **no verified event path whatsoever**. Only the poll catches it.
· *Duration:* indefinite — until the next Light/Dark flip, a relaunch, or a Dock-click-driven
re-check. · *Noticed?* **Yes, immediately** — the user just changed the setting in System Settings
and is looking at the Dock to see the effect. This is the most visible failure in the list.
· *Cheapest non-timer mitigation:* KVO on `UserDefaults` for `AppleIconAppearanceTheme` (item 1
below), or the SPI `NSWorkspaceIconAppearanceConfigurationDidChangeNotification` (§D11b rec 13), or
a Darwin name if one exists. **If none of these verify, "no timer" is not viable** — this single row
decides the verdict.

**2. The notification arrives, but only after the user clicks the tile.** `[DOCUMENTED]` Registered
with the `Coalesce` default (§E14b), a never-active helper has delivery suspended (§E14a); the
queued notification flushes on resume, i.e. on activation. · *Duration:* until the user next
interacts with that tile — hours, easily. · *Noticed?* Yes. · *Mitigation:* register
`.deliverImmediately` — **documented to bypass suspension entirely**, one-line change, no SPI risk
added. This is the cheapest real win in the whole section.

**3. The helper is not running when the appearance changes.** `[INFERENCE — structural]` A pinned
tile whose helper has been quit, crashed, or was never launched (Start-at-Login opted out) receives
nothing, because there is no process. · *Duration:* until next launch. · *Noticed?* Yes.
· *Mitigation:* none available in-process — **and note the current 1 Hz timer does not fix this
either**, since it also requires a live process. Correct framing: this failure is **not a reason to
keep the timer**; it argues for a re-check at every launch (already done:
`currentIconStyle = IconStyle.current` in `applicationDidFinishLaunching`) plus a main-app sweep.

**4. Missed across sleep/wake.** `[NEEDS LOCAL VERIFICATION]` Delivery across sleep is entirely
undocumented (§E14d), and community reports suggest the Auto flip frequently lands at display
sleep/wake — the worst possible moment. · *Duration:* until the next event. · *Noticed?* Yes — this
is the "woke my Mac in the morning and the tiles are still dark" case. · *Mitigation:*
`NSWorkspace.didWakeNotification` re-check. Documented, public, free, and **an event, not a timer**.

**5. Notification dropped under server-queue load.** `[DOCUMENTED as possible, undocumented as to
when]` §E14c. `DeliverImmediately` does **not** protect against this. · *Duration:* until the next
event. · *Noticed?* Yes. · *Mitigation:* no transport-level fix exists. The only defence is
**redundant cheap triggers** — wake, become-active, popover-show, screen-parameters-changed — each
of which is a documented event.

**6. A macOS update removes or renames the notification.** `[DOCUMENTED — it has already happened
to us, twice]` §D11b found two of our three names simply do not exist on macOS 26. There is no error,
no registration failure, no log line: `addObserver` accepts any string. · *Duration:* **permanent**,
across every tile, from the day the user updates macOS. · *Noticed?* Yes, but attributed to Dock Tile,
not to the OS update. · *Mitigation:* not a timer — **instrumentation**. Record per session whether
any appearance event has *ever* fired, and log when a change is detected by a non-notification path
(launch/wake/click) while the notification count is still zero. That converts today's silent,
permanent regression into a single diagnosable log line. This is the mitigation that makes a
timer-less design *defensible* rather than merely *hopeful*.

**7. The observer silently fails to register.** `[DOCUMENTED — absence]`
`DistributedNotificationCenter.addObserver(forName:object:queue:)` returns an opaque token, documents
no failure mode, and Apple provides no way to ask whether a distributed observer is live. A failure is
undetectable in-process. · *Duration:* permanent for that process. · *Noticed?* Yes.
· *Mitigation:* same self-test as row 6.

**8. The event fires but the follow-up read is anomalous.** `[INFERENCE — §B6, largely already
fixed]` The handler re-reads two independent, non-atomic CFPreferences keys (§B6). **This is already
mitigated in the current code**: `IconStyle.resolve` returns `nil` for an unrecognised value and
`currentResolved` exists specifically so a change detector cannot mistake an unresolved read for
"Default" ([IconStyleManager.swift](../DockTile/Managers/IconStyleManager.swift)) — i.e.
Recommendation 1 has landed. · *Duration:* one event. · *Noticed?* No. · *Mitigation:* already done.

**Note on ordering.** Rows 1 and 2 are near-certain and happen on healthy machines; rows 5–7 are rare
but unbounded and silent. The design risk is not evenly spread: **rows 1–2 are fixable with
documented, first-party changes today**, and rows 5–7 are only manageable through instrumentation.

---

### E17. Where this refines or contradicts A–D

- **§A3 conflates suspension and dropping.** It presents both as "delivery is best-effort". §E14
  separates them: suspension is a per-registration policy we control and can eliminate with
  `.deliverImmediately`; dropping is a global server condition we cannot control or detect. The
  practical upshot is more optimistic than §A3 reads — most of the unreliability §A3 describes is
  *ours to fix*.
- **§A3's "the notification observers are a mostly-dead path" is right but for a second reason.**
  §D11b showed two of three names don't exist; §E14a adds that the surviving one is not merely
  *delayed* but delivered *at click time*, which is the worst-case timing rather than a random one.
- **§D11's "the sanctioned detection mechanism … is neither polling nor distributed notifications"
  needs a caveat.** §E15b confirms Apple sanctions `effectiveAppearance` KVO for non-view code (with a
  code sample), but establishes that it **cannot see the icon-style key at all**. §D11 should not be
  read as "adopt `effectiveAppearance` and delete the poll" — it covers at most half the problem.
- **Unknowns item 7 (KVO on the global-domain fall-through) gains community evidence but is not
  resolved.** §E15a: a third-party report says it fires for `AppleInterfaceStyle` with multi-second
  latency; still no Apple statement, still unverified for `.accessory`, for `AppleIconAppearanceTheme`,
  or for macOS 26.
- **Unknowns item 14 (fast user switching) gains a documented scoping rule** — distribution is limited
  to the current login session — which §D12 recorded as "no primary source found". The delivery
  question for a *background* session remains open (§E14d).
- **New unknowns this pass adds:** (a) whether AppKit's automatic suspension applies to a `.accessory`
  process at all; (b) whether `effectiveAppearance` KVO fires in a process with zero windows;
  (c) whether any Darwin notification name carries appearance or icon-style changes; (d) whether
  distributed notifications are delivered, coalesced or lost across sleep/wake.

---

### Verdict (documentation pass)

**Is "no timer" defensible on the documented evidence? Not yet — and one specific gap is why.**

Not because event-driven detection is unsound. The documentation actually supports it better than
§A3 implied: suspension is a solved problem (`.deliverImmediately`, documented), coalescing is
harmless for a level signal, and Apple sanctions app-level `effectiveAppearance` KVO with its own
sample code. The blocker is narrower and harder:

> **There is currently no verified event of any kind for `AppleIconAppearanceTheme`.** The
> notification name we observe for it does not exist (§D11b). `effectiveAppearance` cannot see it
> (§E15b). `NSWorkspace` publishes nothing for it (§E15c). Today, the **only** thing that detects an
> Icon-style change is the poll the maintainer wants to delete.

Delete the timer with nothing verified in its place and Dock Tile ships a feature — the Tahoe icon
styles the whole icon system is built around — that **silently stops responding to the setting that
controls it**, on the machines of 100+ Sparkle users, discoverable only by them noticing.

**What would have to be true for "no timer" to be safe:**

| # | Condition | Status |
|---|---|---|
| 1 | A change to `AppleIconAppearanceTheme` reaches a windowless `.accessory` helper by *some* observer | **NEEDS LOCAL VERIFICATION** — decisive |
| 2 | A Light/Dark change reaches that same helper | Partly `[DOCUMENTED]` (KVO sanctioned, sample code); windowless case **NEEDS LOCAL VERIFICATION** |
| 3 | Delivery is not deferred to click-time for a never-frontmost app | `[DOCUMENTED]` fix exists (`.deliverImmediately`); effect **NEEDS LOCAL VERIFICATION** |
| 4 | Missed events are recoverable from documented lifecycle events (wake, activate) | Events are `[DOCUMENTED]`; coverage **NEEDS LOCAL VERIFICATION** |
| 5 | A silent regression (row 6/7 above) becomes visible instead of permanent | Not documented — **a design choice we must make**, and the one that converts "hopeful" into "defensible" |

**Recommended posture, stated as a decision rather than a hedge.** Condition 5 is free and should
ship regardless. Conditions 2–4 are documented or cheaply mitigated. **Condition 1 is the whole
decision**, and it is a ~30-minute experiment (item 1 below). Concretely:

- If item 1 verifies → **"no timer" is defensible.** Ship: KVO on `UserDefaults` for both keys,
  `.deliverImmediately` on the one surviving distributed name, re-check on
  `NSWorkspace.didWakeNotification` + `applicationDidBecomeActive` + popover show, and the
  never-fired self-test. None of those is a timer; all are events.
- If item 1 does not verify → **keep a fallback, but not a 1–2 second one.** Nothing documented
  justifies 1 Hz; the event Apple documents is at-most-twice-daily (§D12). A re-check on the
  documented events above, plus a low-frequency backstop, is 3+ orders of magnitude cheaper than
  today and removes the entire §C10 cost argument. The maintainer's instinct is right about the
  *timer's frequency* even if item 1 fails.

**The honest bottom line.** The maintainer asked for "failproof". Apple documents **no delivery
guarantee on any available transport** — not distributed notifications (§E14c), not Darwin
notifications (§E15c), and KVO's cross-process guarantee is documented for a case that is not quite
ours (§E15a). "Failproof" is therefore not achievable and should not be the bar. The achievable bar
is **"correct on every path we can verify, and loud on every path we cannot"** — and that bar is
reachable, cheaply, with the five conditions above.

---

### What to verify locally, in priority order

Each is phrased as a specific observable question. Items 1–3 want a **Debug helper bundle** with
`.accessory` policy and no windows — that is the configuration under test, and testing in the main
app would prove nothing. Per the project's own rule, do this against the **dev** build, never
production data.

1. **Does KVO on `UserDefaults.standard` fire for `AppleIconAppearanceTheme` inside a running,
   never-clicked, windowless `.accessory` helper?** *(Decisive — the verdict turns on this alone.)*
   Register the observer in `applicationDidFinishLaunching`, do not touch the helper, change System
   Settings → Appearance → Icon and widget style, and record whether the callback fires and after how
   long. Repeat for `AppleInterfaceStyle` with a Light↔Dark toggle. **Observable:** callback fires
   Y/N; latency in seconds; the raw string reported.

2. **Is a Ghost helper's distributed-notification delivery actually suspended, and does
   `.deliverImmediately` change it?** Register `AppleInterfaceThemeChangedNotification` twice — once
   via the current `addObserver(forName:object:queue:)` (Coalesce) and once via
   `addObserver(_:selector:name:object:suspensionBehavior:)` with `.deliverImmediately` — then toggle
   Light/Dark **without clicking the tile**. **Observable:** does the Coalesce observer stay silent
   until the tile is clicked, while the DeliverImmediately one fires at toggle time? This directly
   tests §E14a's central inference.

3. **Does `NSApp.effectiveAppearance` KVO fire in a process with zero windows?** Same helper, observe
   `\.effectiveAppearance` in `applicationDidFinishLaunching`, toggle Light/Dark. **Observable:**
   fires Y/N, and does the new value actually differ? (Christian Tietze's "mixed results" and his
   window-based workaround make a negative result genuinely plausible here.)

4. **Is any Darwin notification posted for appearance or icon style?** `notifyutil -w` on candidate
   names while toggling both settings — read-only, non-destructive, no bundle changes. **Observable:**
   any name that fires on an Icon-style change would be the best available signal in the whole
   investigation, because `suspensionBehavior` is documented to be *ignored* on that centre (§E15c).

5. **Does the pending Auto flip actually land at display sleep/wake?** Set Auto, leave the Mac idle
   across the Night Shift boundary with the raw-string logging from Recommendation 4 running.
   **Observable:** the wall-clock time the raw `AppleInterfaceStyle` string changes, relative to sleep
   and to wake. This settles both §E14d and Unknowns item 13, and tells you whether
   `NSWorkspace.didWakeNotification` is the high-value trigger §E14d predicts.

6. **Does a distributed notification posted while asleep arrive on wake?** Harder to stage; approach it
   by observing whether the helper's appearance handler fires at all in the wake window from item 5.
   **Observable:** handler fires before/after/never relative to `didWakeNotification`.

7. **Re-read the two 403'd forum threads in a browser** (686011, 702840) and confirm or correct the two
   `[APPLE STAFF — attribution NOT confirmed]` quotes in §E15c before either is relied on or repeated.

---

## F. Local verification results — 2026-08-31

Answers the "What to verify locally" list at the end of §E. Method: a purpose-built probe
(`AppearanceProbe.swift`, throwaway) reproducing a Ghost helper's exact runtime shape —
`NSApplication.setActivationPolicy(.accessory)`, no windows, never frontmost — registering every
candidate channel simultaneously and logging with millisecond timestamps. The maintainer changed the
settings by hand in System Settings; **no Dock Tile tile was clicked during the run**, which is what
makes the suspension result meaningful. Environment: macOS 26.6.2, 2026-08-31, ~3 h session.

### F1. Is there an event for `AppleIconAppearanceTheme`? — YES `[OBSERVED]`

This was §E's blocker and its stated reason "no timer" was not defensible. **It is now answered:
`UserDefaults` KVO fires for `AppleIconAppearanceTheme`.** Five consecutive icon-style changes, each
caught by KVO, each ahead of or level with the 1 s poll:

| Icon style set | KVO | Poll | KVO lead |
|---|---|---|---|
| `ClearAutomatic` | 19:01:07.798 | 19:01:08.609 | **0.81 s** |
| `TintedAutomatic` | 19:01:15.611 | 19:01:15.611 | 0.00 s |
| absent (Default) | 19:01:21.476 | 19:01:21.610 | 0.13 s |
| `RegularDark` | 19:01:24.241 | 19:01:24.610 | 0.37 s |
| `RegularAutomatic` | 19:01:28.188 | 19:01:28.610 | 0.42 s |

**No distributed notification of any name fired on these five** — confirming §D11b from the other
direction. KVO is the *only* channel that sees the icon-style key, and it is the documented one.

Across all 13 transitions in the session (5 icon-style + 2 Light/Dark, with duplicates), **KVO was
first or tied every time, and the poll never once caught a change the events missed.**

### F2. Is a Ghost helper's delivery suspended until it is activated? — NO `[OBSERVED]`

§E14a inferred that a never-active accessory app would have delivery deferred to click-time. It did
not happen: the observer registered with the **`Coalesce` default fired at toggle time**, in the
same millisecond as the `.deliverImmediately` one, with the app never activated and no tile clicked.
`.deliverImmediately` is therefore **defensive, not a fix** — worth keeping (it costs one argument
and the documentation supports it) but it is not load-bearing. **This contradicts the inference in
§A3/§E14a; the documentation is correct about the mechanism, but the mechanism did not engage here.**

### F3. Does `effectiveAppearance` KVO work with zero windows? — YES, for Light/Dark only `[OBSERVED]`

Fired on both Light/Dark toggles in the windowless `.accessory` process, resolving the conflicting
community reports in §E15b. It did **not** fire on any icon-style change — structurally expected,
since it reports interface appearance, not icon style. Usable as a secondary Light/Dark signal;
useless for the key that matters.

### F4. Events arrive DUPLICATED `[OBSERVED]` — a design constraint

On each Light/Dark toggle, `effectiveAppearance`, the `NSWorkspace` menu-bar notification and both
distributed observers each fired **twice within ~100 ms**. Any handler must therefore be idempotent.
Ours is, via the `newStyle != currentStyle` guard — but a design that performed work per *event*
rather than per *resolved change* would do everything twice.

### F5. `absent` is a legitimate value, not an error `[OBSERVED]`

Selecting Default removes `AppleIconAppearanceTheme` entirely (`theme=<absent>`). This validates the
resolver split shipped alongside this research: **absent → `.defaultStyle` (legitimate), unrecognised
string → `nil` (unresolved)**. Collapsing absent into "unknown" would have broken Default outright.

### F6. No oscillation observed `[OBSERVED]`

Over ~3 h, all 8 detected changes correspond to deliberate user actions. Nothing spurious. This says
nothing about the machines producing 548 events/day — it establishes only that a healthy system in
Auto appearance does not flap on its own.

### Verdict (verification pass) — "no timer" IS defensible

Every condition in §E's verdict table that was marked NEEDS LOCAL VERIFICATION is now verified,
except sleep/wake (item 5/6), which this session did not cover. The timer has no demonstrated job:
it was never first, and never unique.

**Shipped as a result** (see the working tree, not yet committed):

- `UserDefaults` KVO on both keys is the **primary** signal, for both the main app and helpers.
- The surviving distributed name stays as a Light/Dark secondary, `.deliverImmediately`.
- **All polling removed.** Recovery is `NSWorkspace.didWakeNotification` + a re-check when a tile's
  popover is shown — discrete events, not a timer. Wake is the one path F1–F4 could not test, and is
  precisely where an event has no running observer to reach.
- The **never-fired self-test** stays: if a reconcile ever finds a change when no event has ever been
  received, that is logged once per process. It converts "detection silently degraded on a future
  macOS" from invisible into reportable — the §E bar of *correct on every path we can verify, loud on
  every path we cannot*.

**Still unverified, stated plainly:** sleep/wake delivery; behaviour over days rather than hours;
and anything about the machines that actually produced the oscillation. One healthy Mac for three
hours is evidence, not proof.

---

## G. Architectural decision — why the subsystem exists, and what we are NOT building

Recorded 2026-08-31, after the fixes in §F. This section exists so the next person does not
re-litigate a decision that was already made with evidence.

### G1. The root constraint: mutable state inside a sealed artifact

Every problem in this document is downstream of one design property: **Dock Tile stores mutable
state inside an immutable, signed artifact.** All four appearance variants already exist in every
helper (`AppIcon-default/dark/clear/tinted.icns`); the live icon is selected by rewriting
`AppIcon.icns`. That is a signed container being used as a variable, and it is why:

- the code-signature seal breaks (§C8b, §F — verified on a live install),
- the Dock and IconServices caches need explicit invalidation (§C9),
- Launch Services must be re-registered at all (§C9/§C10),
- and appearance must be *detected* by us in the first place (§A1) rather than by the OS.

Apple's model is the inverse — ship every variant, the system selects, the app never knows
(§A1, HIG). Dock Tile cannot use it: helper bundles have `Assets.car` stripped so per-tile custom
icons are not overridden ([icon-system rule](../.claude/rules/icon-system.md)), and asset catalogs
are produced by `actool` at BUILD time, so one cannot be generated on a user's Mac for a tile whose
icon is chosen at runtime. `[INFERENCE, from §A1 + the build-tooling constraint]`

**Consequence for how this subsystem should be judged:** it is a workaround for a platform
constraint, not an intended design. The goal is not elegance — it is to make a known workaround
safe and quiet. Given the constraint there are exactly three useful moves: stop lying about state,
mutate the container less often, and repair it when we do. Every change in §F is one of those.

### G2. "One owner across processes" — considered and REJECTED

A cross-process redesign was proposed: the main app resolves the style once and pushes it to all
tiles via the existing `regenerateBatch` pipeline. It is **not being built.** Its four
justifications were absorbed or refuted:

| Justification | Outcome |
|---|---|
| Helpers are multiple writers to shared Dock state | **Refuted.** Each helper writes only its OWN bundle. Not the multi-writer race that [architecture.md](../.claude/rules/architecture.md) "Helpers must not touch the Dock" was written against. |
| Routing through `regenerateBatch` restores a valid seal | **Absorbed** by re-sealing in place after the icon swap (§F verdict) — same outcome, no restructuring. |
| Few reconciliation moments = structural rate limiting | **Absorbed** by event-driven detection with no timer (§F). |
| Two competing detectors with duplicated logic | **Absorbed** — detection now has one owner per process. |

The two residual benefits — tiles moving in lockstep, and a tile whose helper is not running
refreshing anyway — are **also addressed without it**, by the launch-time self-heal
(`HelperBundleManager.iconMatchesStyle`, guarded by `HelperIconMatchTests`): a helper compares its
live `AppIcon.icns` against the variant for the resolved style at launch and corrects a mismatch.
That covers both a change missed while the process was not running and an event missed while it
was. A single owner would not have closed the gap anyway, since the main app is not guaranteed to
be running either. `[INFERENCE]`

### G3. The question that IS still open

Not "who owns the decision" but **"should this subsystem exist at all"** — i.e. can we stop
mutating a signed bundle? Two unexplored candidates:

1. **`NSDockTilePlugIn`** — flagged in §C8 as the only Apple-documented way to customise a pinned
   tile whose app is not running. Unknown whether it can influence the app ICON as opposed to the
   badge/menu. **Not investigated.**
2. **Prebuilt appearance variants** — almost certainly dead (per-tile icons are runtime renders and
   `actool` is build-time), but cheap to rule out definitively.

If either works, `IconStyleManager`, the re-seal, the Launch Services call and the entire detection
path delete themselves. Worth one focused investigation — **after** the current fixes have been
validated in production, since it changes nothing about whether they are safe to ship.

### F7. Corrections from the first end-to-end run (added later on 2026-08-31)

Three findings from running the event-driven build as real dev tiles, with the probe as a
concurrent control. Two correct earlier statements in this document.

1. **§F1's value list was incomplete — `ClearLight`, `ClearDark`, `TintedDark` are REAL.**
   The first capture only clicked the `*Automatic` options. A fuller click-through observed macOS
   26.6.2 writing `ClearLight` (20:09:05), `ClearDark` (20:09:24) and `TintedDark` (20:09:25)
   for the light/dark Clear and Tinted variants. `[OBSERVED]` These were briefly REMOVED from the
   resolver as "guessed values" on the strength of the incomplete capture, during which three live
   user selections were silently ignored (the unresolved-→-no-op guard worked as designed — it
   failed safe, but it failed). Restored, with `TintedLight` mapped by symmetry (unobserved).
   **Lesson recorded: an absent observation is not an observation of absence** — for an
   undocumented value space, only a positive observation can justify REMOVING a mapping.

2. **End-to-end, the event-driven implementation tracks real System Settings changes at ≤10 ms.**
   A rapid manual click-through (11 changes in ~15 s) was matched by the helper flip-for-flip,
   each within 10 ms of the probe's KVO timestamp, all attributed `(kvo)`, no timer running.
   `[OBSERVED]` (An earlier read of this same burst as "the 548/day oscillation reproduced" was
   WRONG — the changes were user-made; the probe control disproved it. §F6 stands: no spontaneous
   oscillation has ever been observed on this machine.)

3. **A helper killed mid-swap leaves a broken seal.** One helper was terminated ~3 s after an icon
   swap and came back `codesign: a sealed resource is missing or invalid` — the same
   interrupted-mid-operation class `helperIconsComplete` exists for. The launch self-heal corrects
   the ICON but not the SEAL (a matching icon skips the rewrite-and-reseal). `[OBSERVED]` Left as
   a known gap: the next regeneration heals it, and Copy Diagnostics now surfaces it per tile.
