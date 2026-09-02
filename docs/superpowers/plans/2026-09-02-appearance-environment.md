# Appearance via the Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Load `.claude/skills/icon-rendering/SKILL.md` before any task.

**Goal:** Previews and popover app-icons receive Light/Dark from SwiftUI's environment (the Apple-sanctioned mechanism) instead of a detection-era cached style, and the rare explicit icon-style change refreshes on app activation — fixing the frozen-preview regression the declarative quarantine exposed, with zero observers, zero notifications, zero timers.

**Architecture:** Split the two signals by nature. Light/Dark: `@Environment(\.colorScheme)` in views, composed with a published **raw** style token via the existing pure `resolve(...isDarkMode:)` seam. Icon style (Default/Dark/Clear/Tinted, no public API): the raw token refreshes on `NSApplication.didBecomeActiveNotification` — a discrete reconcile moment, main-app only. `IconStyleManager.currentStyle` remains ONLY for the frozen macOS-15 detection internals; UI stops reading it.

**Tech Stack:** SwiftUI environment, Swift Testing, `ImageRenderer` (environment-injected render tests, pattern proven in `IconPreviewGeometryTests`).

**Spec:** This plan implements the research findings recorded in the conversation of 2026-09-02 (HIG Dark Mode: appearance is received, never detected; SwiftUI `colorScheme`; our own `docs/icon-rendering-history.md` establishes the icon-style key has no sanctioned signal). The prior behaviour rode on the deleted detection subsystem — this is the platform-correct replacement, not a revival.

## Global Constraints

- **No observers, no distributed notifications, no KVO, no timers** for appearance anywhere. The only new subscription permitted is `didBecomeActiveNotification` in the MAIN app (`AppEnvironment.isHelper == false` guarded).
- Helpers stay entirely observation-free. The three `IconPipeline.isDeclarative` activation points are untouched; this work is a refinement *inside* activation point 2, not a fourth point.
- The unresolved→no-op rule holds: an unrecognised or non-string style read during refresh keeps the previous raw value — never flips displays to Default (`IconStyleResolveTests` conventions).
- The frozen legacy path (`checkAndUpdateStyle`, `switchIcon`, macOS-15 detection) is not modified in any way.
- Guards must be able to fail (`.claude/rules/testing.md`): every new test must name the regression it catches and would genuinely fail under it. Prefer structural guarantees over tests where expressible.
- Test command after every task:
  `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`
- Commits: each `git commit` in its own Bash call, never a bare `-n` token in the same command; end messages with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Never touch `~/Library/Application Support/DockTile*/`, the Dock plist, or the global `AppleIconAppearanceTheme` during implementation or tests.

---

### Task 1: The display-resolution seam + published raw style

**Files:**
- Modify: `DockTile/Managers/IconStyleManager.swift`
- Test: `DockTileTests/Unit/Managers/IconStyleResolveTests.swift` (extend)

**Interfaces:**
- Produces (consumed by Tasks 2–4):

```swift
extension IconStyle {
    /// View-facing resolution: combines the published raw token with the view's OWN
    /// colorScheme, so Light/Dark comes from the environment (live, system-driven) and
    /// only the explicit style choice comes from the token. `.unresolved` raw keeps the
    /// prior display (callers pass their last-known style as `fallback`).
    static func forDisplay(raw: RawStyleToken, colorScheme: ColorScheme, fallback: IconStyle) -> IconStyle
}

/// Plain-value snapshot of the AppleIconAppearanceTheme key: `.absent`, `.value(String)`,
/// or `.unreadable` (present but not a string). Equatable, Sendable, pure to construct.
enum RawStyleToken: Equatable, Sendable { case absent; case value(String); case unreadable }

extension IconStyleManager {
    /// Published raw token. Seeded in init (structural: no declared default — definite
    /// initialisation forces the seed, same guarantee as `currentStyle`). Refreshed ONLY
    /// by Task 2's activation hook. Helpers never refresh it (popover content rebuilds
    /// per show(), so the launch seed suffices there).
    @Published private(set) var rawStyle: RawStyleToken
    static func token(from object: Any?) -> RawStyleToken   // pure, nonisolated
}
```

- [ ] **Step 1: Write failing tests** in `IconStyleResolveTests` — the full matrix, exact values:

```swift
@Test("forDisplay: Automatic follows the VIEW's colorScheme, not a cached appearance")
func automaticFollowsEnvironment() {
    let raw = RawStyleToken.value("RegularAutomatic")
    #expect(IconStyle.forDisplay(raw: raw, colorScheme: .dark, fallback: .defaultStyle) == .dark)
    #expect(IconStyle.forDisplay(raw: raw, colorScheme: .light, fallback: .dark) == .defaultStyle)
}
@Test("forDisplay: absent key is Default in both schemes")
func absentIsDefault() {
    #expect(IconStyle.forDisplay(raw: .absent, colorScheme: .dark, fallback: .clear) == .defaultStyle)
    #expect(IconStyle.forDisplay(raw: .absent, colorScheme: .light, fallback: .clear) == .defaultStyle)
}
@Test("forDisplay: explicit styles ignore the scheme", arguments: [
    ("RegularDark", IconStyle.dark), ("ClearDark", IconStyle.clear), ("TintedAutomatic", IconStyle.tinted)])
func explicitStylesIgnoreScheme(_ pair: (String, IconStyle)) {
    #expect(IconStyle.forDisplay(raw: .value(pair.0), colorScheme: .light, fallback: .defaultStyle) == pair.1)
    #expect(IconStyle.forDisplay(raw: .value(pair.0), colorScheme: .dark, fallback: .defaultStyle) == pair.1)
}
@Test("forDisplay: unresolved keeps the FALLBACK — the no-op rule at display level")
func unresolvedKeepsFallback() {
    #expect(IconStyle.forDisplay(raw: .unreadable, colorScheme: .dark, fallback: .clear) == .clear)
    #expect(IconStyle.forDisplay(raw: .value("SomeFutureStyle"), colorScheme: .light, fallback: .tinted) == .tinted)
}
@Test("token(from:): absent / string / non-string classified exactly")
func tokenClassification() {
    #expect(IconStyleManager.token(from: nil) == .absent)
    #expect(IconStyleManager.token(from: "RegularDark") == .value("RegularDark"))
    #expect(IconStyleManager.token(from: 7) == .unreadable)
}
```

- [ ] **Step 2: Run — expected FAIL** (types undefined).
- [ ] **Step 3: Implement.** `forDisplay` delegates to the existing `resolve(preferencesValue:isDarkMode:)` — no duplicated mapping table (`.value(s)` → `resolve(s, isDark) ?? fallback`; `.absent` → `.defaultStyle`; `.unreadable` → `fallback`). `rawStyle` gets NO declared default; `init` seeds it via `Self.token(from: IconStyle.rawPreferencesObject)` before `setupObservers()` (definite initialisation enforces ordering — cite the existing comment block; extend it to name this second property).
- [ ] **Step 4: Run tests — PASS; full suite green. Step 5: Commit.**

### Task 2: Activation refresh (main app only)

**Files:**
- Modify: `DockTile/Managers/IconStyleManager.swift`, `DockTile/App/AppDelegate.swift` (wherever `configureAsMainApp` wires main-app-only observers)
- Test: extend `DockTileTests/Unit/Managers/IconStyleQuarantineTests.swift`

**Interfaces:**
- Produces: `IconStyleManager.refreshRawStyle()` — re-reads the key, assigns `rawStyle` only when the new token differs (avoid spurious `objectWillChange`). Wired to `NSApplication.didBecomeActiveNotification` from `configureAsMainApp` (already `!isHelper`-guarded and `!isRunningTests`-gated — follow the existing pattern there; do NOT register it inside `IconStyleManager.init`, which helpers also run).

- [ ] **Step 1: Failing test** — pure decision: `refreshRawStyle` semantics via a seam `IconStyleManager.shouldAdopt(newToken:current:) -> Bool` (differs → true; equal → false), plus a test that calling `refreshRawStyle()` updates `rawStyle` to the live key's classification. (The live-read test asserts classification of whatever the real key holds — compare against `token(from: IconStyle.rawPreferencesObject)` read in the test — this discriminates because a broken refresh leaves the init-seeded value, which the test can't distinguish… **it can**: make the assertion `manager.rawStyle == IconStyleManager.token(from: IconStyle.rawPreferencesObject)` AFTER a `refreshRawStyle()` call preceded by directly assigning a sentinel via a test-only `@testable` setter? NO — no test-only mutators. Instead: assert `shouldAdopt` exactly, and cover the wiring by the structural argument below. State plainly in the test file that the notification wiring itself is covered by Task 5's manual check, not unit-testable without global mutation — a documented gap beats a decorative test, per `.claude/rules/testing.md` "A guard must be able to fail".)
- [ ] **Step 2: Implement.** ~10 lines. **Step 3: Suite green. Step 4: Commit.**

### Task 3: Adopt in the three main-app surfaces

**Files:**
- Modify: `DockTile/Components/DockTileIconPreview.swift` (line ~32), `DockTile/Views/DockTileDetailView.swift` (lines ~447, ~762)
- Test: extend `DockTileTests/Unit/Components/IconPreviewGeometryTests.swift`

Each surface: add `@Environment(\.colorScheme) private var colorScheme`, replace `iconStyleManager.currentStyle` with `IconStyle.forDisplay(raw: iconStyleManager.rawStyle, colorScheme: colorScheme, fallback: <the view's current display style — keep a small `@State` only if genuinely needed; prefer `.defaultStyle` as fallback since unresolved raw is an edge>)`. `DockTileDetailView:447` (the id-composite) and `:762` (bare re-render trigger) both switch to the same expression so the canvas re-renders on either signal.

- [ ] **Step 1: Failing render test** — the regression that started all this, as a guard that can fail:

```swift
@Test("Preview renders DIFFERENT output for light vs dark colorScheme under an Automatic raw style")
@MainActor func previewFollowsEnvironmentScheme() throws {
    // Render the REAL preview twice via ImageRenderer with injected environments.
    // Under the frozen-currentStyle implementation both renders were identical
    // (the environment was ignored) — this test fails there and passes now.
    let light = try renderPreview(scheme: .light)   // helper: ImageRenderer + .environment(\.colorScheme, .light)
    let dark  = try renderPreview(scheme: .dark)
    #expect(light != dark)
}
```

(`renderPreview` must pin `rawStyle`'s effect by constructing the view with a raw token parameter if the singleton's live value is `.absent`/Automatic-free — inject `.value("RegularAutomatic")` through the same `forDisplay` path the view uses; if the view API needs a small injectable seam for testability, add it as a default-valued parameter that production never passes. Ensure the discriminating condition: with an explicit style like ClearDark this test would NOT discriminate — the test must force the Automatic case.)
- [ ] **Step 2: Run — FAIL on the pre-change implementation** (both renders identical). **Step 3: Wire the three surfaces. Step 4: PASS + full suite. Step 5: Commit.**

### Task 4: Adopt in the helper popover views

**Files:**
- Modify: `DockTile/UI/NativePopoverViews.swift` (lines ~469, ~628–629, ~823, ~970–971)
- Test: none new (see below)

Same substitution at the four sites (`.id` composites and `let _ =` triggers). Effect: third-party app icons in an OPEN popover now track Light↔Dark live via the environment — previously they could go stale mid-open. Helpers remain observation-free: `rawStyle` is seeded at helper launch and never refreshed there, which is correct — popover content rebuilds on every `show()`, and explicit style changes while a popover is open remain a non-goal (document this in a comment at the first site). No new tests: the substitution is the same expression Task 3 guards, and popover render-tests would require the full helper view stack — name this gap in the task's commit message rather than adding a decorative test.

- [ ] **Step 1: Wire the four sites. Step 2: Full suite green (popover tests exist in the makeover's suite — they must stay untouched-green). Step 3: Commit.**

### Task 5: Manual verification — the original repro, dead

**No files.** The exact scenario from the 2026-09-02 report, on the unified dev build:

- [ ] **Step 1:** Launch the dev app while the system is in Dark. Confirm previews render dark.
- [ ] **Step 2:** With the app frontmost and untouched, flip appearance to Light in System Settings. **Previews must follow within the transition — no relaunch, no click.** (This is the step that was broken.)
- [ ] **Step 3:** Background the app, change icon style to ClearDark in System Settings, click back into the app. Previews must show Clear on activation (Task 2's path).
- [ ] **Step 4:** Open a dev tile's popover, flip Light↔Dark while it is open — third-party app icons follow (Task 4's path).
- [ ] **Step 5:** Confirm the diagnostics log contains no new `[icon-style]` observer lines from helpers, and `grep -rn "addObserver" DockTile/Managers/IconStyleManager.swift` shows nothing new beyond the quarantined legacy block. Record results; STOP before any release step.

---

## Self-review notes

- Coverage: frozen-preview fix (T1–T3), popover mid-open staleness (T4), activation refresh for explicit styles (T2), no-observer constraint (structural: the only registration is in `configureAsMainApp`), manual repro closure (T5).
- The `fallback` parameter deliberately reuses the unresolved→no-op philosophy at display level; T1's tests pin it.
- Type consistency: `RawStyleToken`, `forDisplay(raw:colorScheme:fallback:)`, `rawStyle`, `refreshRawStyle`, `shouldAdopt(newToken:current:)` — defined in T1/T2, consumed by name in T3/T4.
- Deliberately NOT in scope: any change to helper detection, `currentStyle`'s role in the frozen legacy path, an Icon-Composer-style preview picker (HIG advises against app-specific appearance settings for consumer apps; revisit only if activation-refresh proves insufficient in practice).
