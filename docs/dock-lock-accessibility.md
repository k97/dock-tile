# Dock Lock — Accessibility Permission Notes

Dock Lock pins the Dock to one display by installing a `CGEvent` tap that clamps the
cursor out of the Dock-trigger band on non-anchor screens. An active event tap
**requires Accessibility (TCC) permission**, so the feature is gated behind it.

## Permission UX (industry-standard, no hacks)

- Permission is requested **only on user action** (enabling the toggle), never at launch
  unprompted.
- `DockLockManager.requestAccessibility()` calls `AXIsProcessTrustedWithOptions(prompt:)`,
  which registers the app in the Accessibility list and shows the native system prompt.
- The Settings → Dock Lock pane shows status: an **orange "Accessibility access required"**
  row with an **"Open System Settings…"** button while pending; controls (anchor picker,
  "Move Dock…") stay disabled until granted.
- Grant detection re-reads `AXIsProcessTrusted()` from three documented/standard signals —
  no polling:
  - `NSApplication.didBecomeActiveNotification` (returning from System Settings)
  - the system `com.apple.accessibility.api` distributed notification (the de-facto signal
    used by AltTab / Rectangle / Hammerspoon)
  - the pane's `.onAppear`

## Dev-build caveats (IMPORTANT — these are NOT product bugs)

TCC is sensitive to **how the app binary is signed**, and dev builds behave differently
from the notarized release.

1. **Ad-hoc signing breaks the grant on every rebuild.**
   With ad-hoc signing (`Signature=adhoc`, no Team ID), TCC binds the Accessibility grant to
   the binary's **cdhash**, which changes on every build. Result: System Settings shows
   "Dock Tile Dev" ✅ ticked, but the freshly-built binary reads `AXIsProcessTrusted() == false`
   → the pane shows "pending" forever.
   **Fix applied:** the **Debug** config now signs with the Apple Development identity
   (`DEVELOPMENT_TEAM = R68RHN3HF5` in the app target's Debug build settings). TCC then keys
   on the stable identity (team + bundle id), so the grant survives rebuilds.
   - After switching ad-hoc → Apple Development once, clear the stale entry:
     `tccutil reset Accessibility com.docktile.dev.app`, then grant once more.

2. **An already-running process may not see a grant made while it is running.**
   If you toggle the app ON in System Settings (or add it via the `+` button) **after** the
   process is already running, `AXIsProcessTrusted()` in that process can keep returning
   `false` until the app is **quit and reopened**. A freshly launched process picks the grant
   up immediately.
   - In normal product usage this is a non-issue: the user grants via the app's own prompt
     and the running process sees it live (same path Rectangle uses).
   - If the release build ever exhibits a stuck-pending state after granting, the robust,
     standard remedy is to **auto-relaunch the app once the grant is detected** (what
     AltTab/Rectangle do). Not implemented yet — only add if prod actually needs it.

## Release expectation

Release builds are Developer-ID signed (stable identity via `Scripts/build-release.sh`), so
end users grant **once** and it persists across rebuilds and Sparkle updates. Verify on the
notarized prod build: enable Dock Lock → grant in the native prompt → pane should flip to
the granted state without a manual relaunch.

## Verified during prototyping

- Pane renders the correct pending state (orange alert + button + disabled controls). ✅
- Root cause of "stays pending after granting" reproduced live: System Settings showed the
  dev app ticked while the running (pre-grant, ad-hoc-era) process read it as untrusted. ✅
- Debug signing fix confirmed at the `codesign` level
  (`Authority=Apple Development: Karthik Rajendran`, `TeamIdentifier=R68RHN3HF5`). ✅
- Live auto-flip on a *fresh* process: not verifiable in the automation sandbox (it could
  not restart the GUI process). To be confirmed on the prod build.
