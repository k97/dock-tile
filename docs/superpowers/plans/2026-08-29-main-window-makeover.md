# Main Window Makeover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin Dock Tile's main window on the locked v2 design (Klack-style surface, native sizing, title-band headers, the tile's app list as a live editable popover preview, a top-level Popover pane, an About pane, blank-first Add a Tile dialog, light + dark) **without changing any Dock, helper, migration, Smart Add or missing-app behaviour**.

**Architecture:** Keep `NavigationSplitView` + `List(.sidebar)`; hide the window's toolbar chrome and host each pane's header as toolbar items in the 52pt band (spiked first, with an AppKit fallback). Extract one `PopoverPreviewCanvas` that wraps the *real* `StackPopoverView` / `ListPopoverView`; give those panels an optional `editing` mode (remove / reorder / Delete key / context menu) that is `nil` in helpers, so Tile Detail's editor and the shipped popover are one implementation. Every behavioural rule stays behind its existing pure seam; new decisions get their own `nonisolated static` seam + Swift Testing test.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI + AppKit, macOS 15.0 floor (Tahoe-only APIs behind `#available(macOS 26.0, *)`), Swift Testing, `xcodebuild`, String Catalogs (en-GB source, en-US, en-AU).

**Spec:** `docs/superpowers/specs/2026-08-29-main-window-makeover-design.md` — the plan argues from it; read it first. Visuals: https://claude.ai/code/artifact/50e5d060-7281-4733-8f50-65ca058ae575 (working artboards in `docs/v2/canvas/`).

## Global Constraints

- **Do not break existing flows.** These rules from `.claude/rules/*.md` are load-bearing and must hold after every task: `isVisibleInDock` is written only by `DockTileDetailView.performDockAction`; the never-pinned guard; Dock restarts only on real change and `saveOnly` never reaches `HelperBundleManager`; one-time Dock-restart consent (`hasAcknowledgedDockRestart`); missing-app UX is non-destructive (the Remove/Keep alert is the only bulk delete); Smart Add stays on device and the sheet is `.sheet(item:)` never `isPresented` + array; Popover settings live in the shared suite, "preview = the real panels", `PopoverMetrics` is the only sizing seam, `isPreview` neutralises launches; helpers never touch the Dock; `AppEnvironment.isRunningTests` gates launch mutators.
- **When in doubt about a flow, use `superpowers:systematic-debugging` Phase 1 first:** read the rule file, read the call site, run the dev app (`Scripts/dev-capture.sh`, Task 0) and observe — never guess.
- macOS deployment floor **15.0**; anything Tahoe-only inside `if #available(macOS 26.0, *)` with a fallback.
- Every user-facing string goes through `AppStrings` **and** `DockTile/Resources/Localizable.xcstrings` (en-GB, en-US, en-AU). UK spelling (Customise, Colour). `AppStringsTests` asserts every accessor is non-empty — add one line per new accessor.
- `DockTileTests/` files auto-join the test target. **App-target Swift files do not** — add new types to an existing file in the same area (this plan never creates an app-target file), except the deliberate `project.pbxproj` edit in Task 11.
- Tests: Swift Testing (`@Test`, `#expect`, `#require`); assert exact values; never write `UserDefaults.standard` in tests.
- Test command (run after every task, must stay green):
  `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`
- Build command: `xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build`
- Commits: one per task, conventional message, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. **Never pass `-n` to any git command** (a repo hook blocks it). Work on a branch: `git switch -c feat/main-window-makeover` before Task 0.
- Window width stays **768pt**; sidebar 240 ideal; card radius **12pt**; form rows **40pt**; labels **13pt**; captions **11pt**; title band **52pt**, title **16pt semibold**.
- The dev app is **"Dock Tile Dev"** (Debug), bundle id `com.docktile.dev.app`, separate config + support folder — it may pin dev helper tiles into your real Dock during verification; that is the normal dev flow (remove them from Tile Detail afterwards).

---

## File map

| File | Responsibility after this plan |
|---|---|
| `Scripts/dev-capture.sh` (new, not app target) | Build-free capture of the dev app window (light/dark, optional sidebar row) for verification |
| `Scripts/add-string.py` (new) | Adds a key to `Localizable.xcstrings` for all three locales |
| `DockTile/Models/ConfigurationSchema.swift` | New-tile default icon = plus placeholder |
| `DockTile/Models/ConfigurationModels.swift` | + `AppListEditor` pure reorder/remove seam |
| `DockTile/Views/DockTileConfigurationView.swift` | Window chrome, `SettingsPane` (+popover, +about), `PaneTitleBand`, add-flow (always dialog), `.addTileRequested` handling, empty state |
| `DockTile/Views/DockTileSidebarView.swift` | Static sections Tiles / Settings / Dock Tile; Popover + About rows |
| `DockTile/Views/GeneralSettingsView.swift` | No Software Update, no Appearance drill-down; "Adding Tiles" card with *Add a Tile…* row |
| `DockTile/Views/PopoverAppearanceView.swift` | Top-level pane; hero → `PopoverPreviewCanvas` (extracted here, reused) |
| `DockTile/Views/DockLockSettingsView.swift` | Title band only |
| `DockTile/Views/AboutView.swift` | `AboutPaneView` (replaces the About window) |
| `DockTile/Views/SmartAddSheet.swift` | Blank-first dialog + no-suggestions state |
| `DockTile/Views/DockTileDetailView.swift` | Band actions, hero card, In This Tile header + editable preview; table + delete card removed |
| `DockTile/UI/NativePopoverViews.swift` | `PopoverEditing` + editing mode in both panels; drop delegate lives here |
| `DockTile/UI/LauncherView.swift` | + `Notification.Name.addTileRequested` |
| `DockTile/App/DockTileApp.swift` | About menu routes to the pane; no `AboutWindowController` |
| `DockTile/Constants/AppStrings.swift`, `Resources/Localizable.xcstrings` | New/changed strings |
| `DockTile/Components/ItemRowView.swift` | Deleted (dead code) |
| `DockTileTests/Unit/…` | `ConfigurationModelsTests` (+defaults), `AppListEditorTests` (new), `PopoverPreviewCanvasTests` (new), `SmartAddEngineTests` (+add-flow), `AppStringsTests` (+strings) |
| `.claude/rules/*.md`, `CLAUDE.md` | Updated to describe the new IA/flows |

---

### Task 0: Verification tooling + baseline

**Files:**
- Create: `Scripts/dev-capture.sh`
- Create: `Scripts/add-string.py`

**Interfaces:**
- Produces: `Scripts/dev-capture.sh <label> [--row "<sidebar row name>"] [--dark]` → `build/captures/<label>[-dark].png`
- Produces: `Scripts/add-string.py <key> "<en-GB value>" "<comment>" [--us "<en-US value>"]`

- [ ] **Step 1: Read the rules you are about to work inside**

Read `.claude/rules/architecture.md`, `.claude/rules/smart-add.md`, `.claude/rules/popover-appearance.md`, `.claude/rules/testing.md`, `.claude/rules/development.md`. Then read the spec.

- [ ] **Step 2: Create the branch and run the baseline test suite**

```bash
git switch -c feat/main-window-makeover
xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`. Note the executed-test count printed above it; every later task must report the same or a higher count with zero failures.

- [ ] **Step 3: Write the capture script**

```bash
#!/bin/zsh
# Capture the running dev app's main window to build/captures/<label>.png.
# Usage: Scripts/dev-capture.sh <label> [--row "General"] [--click X,Y] [--dark]
#   --row   clicks the sidebar row by its accessibility name (SwiftUI List rows expose the label).
#   --click clicks a window-relative point (pt) — the fallback when --row finds nothing; sidebar rows
#           sit at x≈60 and y≈ 84 + 32·index (measure once off a capture).
# Requires: the terminal has Accessibility + Automation (System Events) access.
set -euo pipefail
LABEL=${1:?label}; shift
ROW=""; CLICK=""; DARK=0
while [[ $# -gt 0 ]]; do case "$1" in --row) ROW="$2"; shift 2;; --click) CLICK="$2"; shift 2;; --dark) DARK=1; shift;; *) echo "unknown $1"; exit 2;; esac; done
APP_DIR=$(xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
APP="$APP_DIR/Dock Tile Dev.app"; PROC="Dock Tile Dev"
mkdir -p build/captures
open -a "$APP"; sleep 1.5
osascript -e "tell application \"System Events\" to tell process \"$PROC\" to set frontmost to true" >/dev/null
if [[ -n "$ROW" ]]; then
  osascript >/dev/null <<EOS
tell application "System Events" to tell process "$PROC"
  set els to entire contents of window 1
  repeat with e in els
    try
      if (name of e as string) is "$ROW" then
        click e
        exit repeat
      end if
    end try
  end repeat
end tell
EOS
  sleep 0.8
fi
if [[ -n "$CLICK" ]]; then
  P=$(osascript -e "tell application \"System Events\" to tell process \"$PROC\" to get position of window 1" | tr -d ' ')
  osascript -e "tell application \"System Events\" to click at {$(( ${P%%,*} + ${CLICK%%,*} )), $(( ${P#*,} + ${CLICK#*,} ))}" >/dev/null
  sleep 0.8
fi
restore_dark() { osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" >/dev/null; }
WAS_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
SUFFIX=""
if [[ $DARK -eq 1 && "$WAS_DARK" == "false" ]]; then restore_dark true; SUFFIX="-dark"; sleep 1.2; fi
POS=$(osascript -e "tell application \"System Events\" to tell process \"$PROC\" to get {position, size} of window 1" | tr -d ' ')
X=${POS%%,*}; R=${POS#*,}; Y=${R%%,*}; R=${R#*,}; W=${R%%,*}; H=${R#*,}
screencapture -x -R "$X,$Y,$W,$H" "build/captures/$LABEL$SUFFIX.png"
if [[ $DARK -eq 1 && "$WAS_DARK" == "false" ]]; then restore_dark false; fi
echo "build/captures/$LABEL$SUFFIX.png"
```

Run: `chmod +x Scripts/dev-capture.sh && grep -n '^build/' .gitignore || echo 'build/' >> .gitignore`

- [ ] **Step 4: Write the string-catalog helper**

```python
#!/usr/bin/env python3
"""Add one key to Localizable.xcstrings for en-GB (source), en-US and en-AU.
Usage: Scripts/add-string.py <key> "<en-GB value>" "<comment>" [--us "<en-US value>"]
"""
import json, sys
CATALOG = "DockTile/Resources/Localizable.xcstrings"
args = sys.argv[1:]
us = None
if "--us" in args:
    i = args.index("--us"); us = args[i + 1]; del args[i:i + 2]
key, value, comment = args
with open(CATALOG) as f:
    cat = json.load(f)
if key in cat["strings"]:
    sys.exit(f"{key} already exists")
def unit(v): return {"stringUnit": {"state": "translated", "value": v}}
cat["strings"][key] = {
    "comment": comment,
    "extractionState": "manual",
    "localizations": {"en-AU": unit(value), "en-GB": unit(value), "en-US": unit(us or value)},
}
with open(CATALOG, "w") as f:   # no re-sorting: keep the diff to the one new key
    json.dump(cat, f, indent=2, ensure_ascii=False); f.write("\n")
print("added", key)
```

Run: `chmod +x Scripts/add-string.py && python3 -c "import json;json.load(open('DockTile/Resources/Localizable.xcstrings'))" && echo catalog-ok`

- [ ] **Step 5: Build the dev app and capture the baseline**

```bash
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build 2>&1 | tail -2
Scripts/dev-capture.sh baseline-tile
Scripts/dev-capture.sh baseline-general --row "General"
Scripts/dev-capture.sh baseline-docklock --row "Dock Lock"
```
Expected: three PNGs in `build/captures/` showing today's UI. Open them (`open build/captures`) — you will compare against these after every task.

- [ ] **Step 6: Commit**

```bash
git add Scripts/dev-capture.sh Scripts/add-string.py .gitignore
git commit -m "chore(tools): dev-window capture + string-catalog helper for the makeover" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 1: New-tile draft uses the plus placeholder

**Files:**
- Modify: `DockTile/Models/ConfigurationSchema.swift:25`
- Test: `DockTileTests/Unit/Models/ConfigurationModelsTests.swift`

**Interfaces:**
- Produces: `ConfigurationDefaults.iconValue == "plus"` (tint stays `.gray`, `iconType` stays `.sfSymbol`). Every later "draft" render (sidebar row, hero, sheet blank row) gets the placeholder for free through `DockTileIconPreview`.

- [ ] **Step 1: Write the failing test** (append inside the existing `@Suite` in `ConfigurationModelsTests.swift`)

```swift
    @Test("A fresh tile is a grey plus placeholder until the user picks an icon")
    func freshTileDefaultsToPlusPlaceholder() {
        let config = DockTileConfiguration()
        #expect(config.iconType == .sfSymbol)
        #expect(config.iconValue == "plus")
        #expect(config.tintColor == .gray)
        #expect(config.name == "New Tile")
    }
```

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -destination 'platform=macOS' -only-testing:DockTileTests/ConfigurationModelsTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'freshTile|FAILED|SUCCEEDED'`
Expected: FAIL — `iconValue` is `"star.fill"`.

- [ ] **Step 3: Change the default**

In `ConfigurationSchema.swift` replace `static let iconValue = "star.fill"` with:
```swift
    // A draft reads as "not designed yet" — the grey plus placeholder from the v2 design. Existing
    // configs are untouched (this is only the seed for createConfiguration()).
    static let iconValue = "plus"
```

- [ ] **Step 4: Run the test file again**

Same command. Expected: PASS, and the rest of `ConfigurationModelsTests` still green (no test asserts the old default — `IconGeneratorTests` pass `"star.fill"` explicitly).

- [ ] **Step 5: Verify in the dev app**

`xcodebuild … build`, `Scripts/dev-capture.sh task1-draft`, press `+` in the app (or ⌘N) — the new sidebar row and hero show a grey squircle with a plus. Existing tiles unchanged.

- [ ] **Step 6: Commit**

```bash
git add DockTile/Models/ConfigurationSchema.swift DockTileTests/Unit/Models/ConfigurationModelsTests.swift
git commit -m "feat(tiles): new tile drafts start as a grey plus placeholder" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Title-band spike (throwaway — decides Task 3's approach)

**Files:**
- Modify (on a throwaway branch only): `DockTile/Views/DockTileConfigurationView.swift`

**Interfaces:**
- Produces: a written decision in the commit message of Task 3 — **A** (SwiftUI toolbar hosts the band) or **B** (AppKit `fullSizeContentView` + custom band).

- [ ] **Step 1: Branch**

`git switch -c spike/title-band`

- [ ] **Step 2: Apply the approach-A modifiers**

In `DockTileConfigurationView.body`, after `.navigationSplitViewStyle(.balanced)` add:
```swift
        .toolbar(removing: .title)
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
```
In `WindowAccessor.configureWindow(_:animated:)`, before the size code add:
```swift
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
```
In `DockTileDetailView.body`'s `.toolbar { … }` add a second item (temporary):
```swift
            ToolbarItem(placement: .navigation) {
                Text(editedConfig.name).font(.system(size: 16, weight: .semibold))
            }
```

- [ ] **Step 3: Build, capture light and dark**

```bash
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build 2>&1 | tail -1
Scripts/dev-capture.sh spike-a
Scripts/dev-capture.sh spike-a --dark
```
Check the PNGs against `docs/v2/canvas/Main.dc.html` (open it in a browser): (a) band is ~52pt and the same colour as the content column, no toolbar line; (b) the title is NOT inside a glass capsule; (c) the sidebar `+` sits in the band; (d) the "Add to Dock" button is a normal bordered button; (e) dark looks like `MainDark.dc.html`.
If (b) fails on macOS 26, wrap the item: `.sharedBackgroundVisibility(.hidden)` inside `if #available(macOS 26.0, *)` (use two `ToolbarItem` branches) and re-capture.

- [ ] **Step 4: Record the decision and discard the spike**

If all checks pass → **A**. If (a) or (b) cannot be made to pass → **B** (Task 3 has both recipes).
```bash
git stash -u && git switch feat/main-window-makeover && git stash drop && git branch -D spike/title-band
```
Nothing from the spike is kept.

---

### Task 3: Window chrome + `PaneTitleBand`

**Files:**
- Modify: `DockTile/Views/DockTileConfigurationView.swift` (body modifiers, `WindowAccessor`, + new `PaneTitleBand` types at the bottom)
- Modify: `DockTile/Views/DockTileDetailView.swift:141-165` (toolbar), `DockTile/Views/CustomiseTileView.swift:45-55`
- Modify: `DockTile/Views/GeneralSettingsView.swift`, `PopoverAppearanceView.swift:118-119`, `DockLockSettingsView.swift:80` (replace `.navigationTitle`)

**Interfaces:**
- Produces: `extension View { func paneTitleBand(_ title: String, icon: PaneIcon? = nil) -> some View }` and `struct PaneIcon { let systemName: String; let tint: Color }` with statics `.general`, `.popover`, `.dockLock`, `.about`. Later tasks call `.paneTitleBand(…)` instead of `.navigationTitle(…)`.

- [ ] **Step 1: Chrome (approach A)**

`DockTileConfigurationView.body` — after `.navigationSplitViewStyle(.balanced)`:
```swift
        // v2 chrome: the 52pt title band IS the page header. No window title, no sidebar toggle,
        // no toolbar surface — each pane hosts its title + actions as toolbar items (PaneTitleBand).
        .toolbar(removing: .title)
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
```
`WindowAccessor.configureWindow` — before `let minHeight = …`:
```swift
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
```
**Approach B only (if the spike chose B):** instead of the three SwiftUI modifiers, in `configureWindow` also do `window.styleMask.insert(.fullSizeContentView)`, and make `paneTitleBand` render an in-content `HStack` of 52pt height at the top of each pane (`safeAreaInset(edge: .top)`) with the traffic-light inset handled by a 78pt leading spacer in the sidebar band. Everything else in this plan is identical.

- [ ] **Step 2: Add the band API** (bottom of `DockTileConfigurationView.swift`)

```swift
// MARK: - Pane title band

/// Squircle badge for Settings/About headers (the tile pages carry no icon — their hero is right below).
struct PaneIcon: Equatable {
    let systemName: String
    let tint: Color
    static let general  = PaneIcon(systemName: "gearshape.fill", tint: .gray)
    static let popover  = PaneIcon(systemName: "macwindow.on.rectangle", tint: .indigo)
    static let dockLock = PaneIcon(systemName: "lock.display", tint: .blue)
    static let about    = PaneIcon(systemName: "info.circle.fill", tint: .gray)
}

private struct PaneTitleBand: ViewModifier {
    let title: String
    let icon: PaneIcon?

    func body(content: Content) -> some View {
        content.toolbar {
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .navigation) { label }
                    .sharedBackgroundVisibility(.hidden)   // no Liquid Glass capsule around a title
            } else {
                ToolbarItem(placement: .navigation) { label }
            }
        }
    }

    private var label: some View {
        HStack(spacing: 9) {
            if let icon {
                SettingsBadgeIcon(systemName: icon.systemName, tint: icon.tint, size: 26)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Page header in the title band: `title` (+ optional squircle). Replaces `.navigationTitle`.
    func paneTitleBand(_ title: String, icon: PaneIcon? = nil) -> some View {
        modifier(PaneTitleBand(title: title, icon: icon))
    }
}
```
`SettingsBadgeIcon` already exists in `DockTileSidebarView.swift` with a `size` parameter.

- [ ] **Step 3: Use it in every pane**

- `DockTileDetailView.swift`: add `.paneTitleBand(editedConfig.name)` right before `.toolbar {`.
- `CustomiseTileView.swift`: replace `.navigationTitle(AppStrings.Navigation.customiseTile)` with `.paneTitleBand(AppStrings.Navigation.customiseTile)` (its back-chevron `ToolbarItem(placement: .navigation)` stays and renders first).
- `GeneralSettingsView.swift`: replace `.navigationTitle(AppStrings.Settings.general)` with `.paneTitleBand(AppStrings.Settings.general, icon: .general)`.
- `PopoverAppearanceView.swift`: replace `.navigationTitle(AppStrings.Settings.popoverAppearance)` with `.paneTitleBand(AppStrings.Settings.popover, icon: .popover)`.
- `DockLockSettingsView.swift`: replace `.navigationTitle(AppStrings.Settings.dockLock)` with `.paneTitleBand(AppStrings.Settings.dockLock, icon: .dockLock)`.
- `DockTileSidebarView.swift`: remove `.navigationTitle(AppStrings.Sidebar.title)`; on the `+` button add `.accessibilityLabel(AppStrings.Button.addATile)` — add that string now: `Scripts/add-string.py button.addATile "Add a Tile…" "Sidebar + / empty state: opens the Add a Tile dialog"` and in `AppStrings.Button`:
```swift
        static let addATile = NSLocalizedString("button.addATile", value: "Add a Tile…", comment: "Sidebar + / empty state: opens the Add a Tile dialog")
```
plus `#expect(!AppStrings.Button.addATile.isEmpty)` in `AppStringsTests`.

- [ ] **Step 4: Build + tests + capture**

```bash
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build 2>&1 | tail -1
xcodebuild test … -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
Scripts/dev-capture.sh task3-tile; Scripts/dev-capture.sh task3-general --row "General"; Scripts/dev-capture.sh task3-tile --dark
```
Expected: band shows the tile name (no icon) with the action button trailing; General shows the grey squircle + "General"; Customise shows `‹` + "Customise Tile"; the window still cannot be resized horizontally (drag the edge); ⌘, still lands on General; Dock-icon click still reopens the single window.

- [ ] **Step 5: Commit**

```bash
git add DockTile/Views DockTile/Constants/AppStrings.swift DockTile/Resources/Localizable.xcstrings DockTileTests/Unit/Constants/AppStringsTests.swift
git commit -m "feat(window): title-band headers, hidden toolbar chrome (approach A)" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
(If B was chosen, say so in the message.)

---

### Task 4: Sidebar IA — Popover becomes a top-level pane, static sections

**Files:**
- Modify: `DockTile/Views/DockTileConfigurationView.swift:12-15` (`SettingsPane`), `:189-198` (`settingsDetail`)
- Modify: `DockTile/Views/DockTileSidebarView.swift:23-65`
- Modify: `DockTile/Views/GeneralSettingsView.swift` (remove the Popover section, `NavigationStack`, size mirrors)
- Modify: `DockTile/Constants/AppStrings.swift`, `Localizable.xcstrings`; Test: `AppStringsTests.swift`

**Interfaces:**
- Produces: `SettingsPane.popover`; sidebar rows General / Popover / Dock Lock; `AppStrings.Sidebar.dockTileSection` ("Dock Tile") for Task 7.

- [ ] **Step 1: Strings**

```bash
Scripts/add-string.py sidebar.dockTileSection "Dock Tile" "Sidebar section holding About"
```
`AppStrings.Sidebar`: `static let dockTileSection = NSLocalizedString("sidebar.dockTileSection", value: "Dock Tile", comment: "Sidebar section holding About")`. Test: `#expect(AppStrings.Sidebar.dockTileSection == "Dock Tile")`.

- [ ] **Step 2: `SettingsPane`**

```swift
enum SettingsPane: Hashable, CaseIterable {
    case general
    case popover     // v2: top-level pane (was a drill-down inside General)
    case dockLock
}
```
`settingsDetail`: add `case .popover: PopoverAppearanceView().environmentObject(configManager)`.

- [ ] **Step 3: Sidebar sections**

Replace the two `Section(…, isExpanded:)` blocks and delete the two `@AppStorage("sidebar.…Expanded")` properties:
```swift
        List(selection: $selection) {
            Section(AppStrings.Sidebar.tilesSection) {
                if configManager.configurations.isEmpty {
                    Text(AppStrings.Empty.noTiles)
                        .font(.callout).foregroundStyle(.secondary)
                        .tag(SidebarSelection.tilesPlaceholder)
                } else {
                    ForEach(configManager.configurations) { config in
                        ConfigurationRow(config: config)
                            .tag(SidebarSelection.tile(config.id))
                            .contextMenu { ConfigurationContextMenu(config: config) }
                    }
                }
            }
            Section(AppStrings.Sidebar.settingsSection) {
                SettingsRow(title: AppStrings.Settings.general, systemName: PaneIcon.general.systemName, tint: PaneIcon.general.tint)
                    .tag(SidebarSelection.settings(.general))
                SettingsRow(title: AppStrings.Settings.popover, systemName: PaneIcon.popover.systemName, tint: PaneIcon.popover.tint)
                    .tag(SidebarSelection.settings(.popover))
                SettingsRow(title: AppStrings.Settings.dockLock, systemName: PaneIcon.dockLock.systemName, tint: PaneIcon.dockLock.tint)
                    .tag(SidebarSelection.settings(.dockLock))
            }
        }
```
(`.listStyle(.sidebar)` and the toolbar stay.)

- [ ] **Step 4: General loses the drill-down**

In `GeneralSettingsView`: delete the `Section(AppStrings.Settings.popover) { NavigationLink … }` block, the `popoverAppearanceRow` and `popoverSummary` members, the two `@AppStorage(UserDefaultsKeys.popoverGridSize/ListSize …)` properties, and unwrap the `NavigationStack { Form … }` to just `Form { … }` (keep `.formStyle(.grouped)` and the `.onAppear` / `.alert`). Leave `AppStrings.Settings.popoverAppearance*` strings in place for now (removed in Task 12 cleanup).

- [ ] **Step 5: Tests + build + capture**

Run the test command (expect green, +1 test). Build. `Scripts/dev-capture.sh task4-popover --row "Popover"`. Verify: Popover row selects the pane; Reset/Save render trailing in the band; change *Spacing*, press **Save** → with a pinned tile the "Apply to your Dock tiles?" alert appears exactly as before (Cancel it); ⌘, → General; General no longer shows an Appearance row.

- [ ] **Step 6: Commit**

```bash
git add DockTile/Views DockTile/Constants DockTile/Resources DockTileTests
git commit -m "feat(sidebar): Popover is a top-level pane; static Tiles/Settings sections" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: General pane — Software Update out, "Adding Tiles" card with *Add a Tile…*

**Files:**
- Modify: `DockTile/Views/GeneralSettingsView.swift`
- Modify: `DockTile/UI/LauncherView.swift:15-22` (+ notification name)
- Modify: `DockTile/Views/DockTileConfigurationView.swift` (`.onReceive` for it)
- Modify: `AppStrings.swift`, `Localizable.xcstrings`; Test: `AppStringsTests.swift`

**Interfaces:**
- Produces: `Notification.Name.addTileRequested` — posting it runs the same `handleAddTapped()` as the sidebar `+`.

- [ ] **Step 1: Notification name** (in the `extension Notification.Name` in `LauncherView.swift`)

```swift
    /// Posted by any "Add a Tile…" affordance that lives outside the sidebar (General's row). The
    /// configuration window routes it through the SAME handleAddTapped as the sidebar + so the two
    /// entry points can never diverge.
    static let addTileRequested = Notification.Name("addTileRequested")
```

- [ ] **Step 2: Strings** (three commands, then the accessors + tests)

```bash
Scripts/add-string.py settings.addingTiles "Adding Tiles" "General: section holding the Smart Add toggle and the Add a Tile row"
Scripts/add-string.py smartAdd.settingsToggleTitleV2 "Suggest tiles from my apps" "General: Smart Add toggle title"
```
`AppStrings.Settings`: `static let addingTiles = NSLocalizedString("settings.addingTiles", value: "Adding Tiles", comment: "…")`.
`AppStrings.SmartAdd`: change `settingsToggleTitle`'s key/value to `"smartAdd.settingsToggleTitleV2"` / `"Suggest tiles from my apps"` and make `settingsToggleDescription` return `privacyFootnote`'s text by pointing it at the existing key `smartAdd.privacyFootnote` (edit the accessor: `NSLocalizedString("smartAdd.privacyFootnote", value: "Learned on your Mac. Never leaves your device.", …)`). Tests: `#expect(AppStrings.Settings.addingTiles == "Adding Tiles")`, `#expect(AppStrings.SmartAdd.settingsToggleTitle == "Suggest tiles from my apps")`.

- [ ] **Step 3: Rows**

In `GeneralSettingsView.body`'s `Form`:
```swift
            Section {
                startAtLoginRow
                missingAppsRow
                analyticsRow
            }
            Section(AppStrings.Settings.addingTiles) {
                smartAddRow
                Button(AppStrings.Button.addATile) {
                    DiagnosticsLog.shared.ui("General → Add a Tile… row")
                    NotificationCenter.default.post(name: .addTileRequested, object: nil)
                }
                .buttonStyle(.link)
            }
```
Delete `softwareUpdateRow`, the `@EnvironmentObject private var updateController`, and the old privacy-footnote `Label` (its text is now the toggle description).

- [ ] **Step 4: Route the notification** (in `DockTileConfigurationView.body`, next to the `.openSettingsPane` receiver)

```swift
        .onReceive(NotificationCenter.default.publisher(for: .addTileRequested)) { _ in
            handleAddTapped()
        }
```

- [ ] **Step 5: Tests + build + capture + flow check**

Test command green. Build. `Scripts/dev-capture.sh task5-general --row "General"`. Click *Add a Tile…* in General: with Smart Add on and suggestions available the sheet opens; otherwise a blank tile is created and selected (today's behaviour — Task 10 changes it to always open the dialog). *Check for Updates* is no longer in General (it returns in Task 7's About).

- [ ] **Step 6: Commit**

```bash
git add DockTile/Views DockTile/UI/LauncherView.swift DockTile/Constants DockTile/Resources DockTileTests
git commit -m "feat(general): Adding Tiles card with Add a Tile row; Software Update moves to About" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5b: Title band carries no icon (decision 2026-08-30)

**Files:**
- Modify: `DockTile/Views/DockTileConfigurationView.swift` (`PaneTitleBand` / `paneTitleItem` / both `paneTitleBand` overloads)
- Modify: call sites `GeneralSettingsView.swift`, `PopoverAppearanceView.swift`, `DockLockSettingsView.swift`

**Interfaces:**
- Produces: `.paneTitleBand(_ title: String)` and `.paneTitleBand(_ title: String) { trailing }` — the `icon:` parameter is removed. `PaneIcon` stays (the sidebar rows use `.systemName` / `.tint`); `PaneIcon.about` stays for Task 7's sidebar row.

- [ ] **Step 1: Remove the icon from the band**

In `paneTitleItem` drop the `SettingsBadgeIcon` branch and the `icon` parameter; drop `icon` from both modifiers and both `paneTitleBand` overloads. Update every call site to `.paneTitleBand(AppStrings.Settings.general)`, `.paneTitleBand(AppStrings.Settings.popover) { … }`, `.paneTitleBand(AppStrings.Settings.dockLock)`. Tile Detail and Customise already pass no icon.

- [ ] **Step 2: Build, tests, capture**

Build; the filtered test command (398 green); `Scripts/dev-capture.sh task5b-general --row "General"` and `--row "Popover"` — the band shows the title text only, actions still trailing.

- [ ] **Step 3: Commit**

```bash
git add DockTile/Views
git commit -m "feat(window): title band shows the title only — no pane icon" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Extract `PopoverPreviewCanvas`

**Files:**
- Modify: `DockTile/Views/PopoverAppearanceView.swift:176-270` (hero) — add `struct PopoverPreviewCanvas` at the bottom of the same file
- Test: `DockTileTests/Unit/UI/PopoverPreviewCanvasTests.swift` (new)

**Interfaces:**
- Produces:
```swift
struct PopoverPreviewCanvas: View {
    enum Fit: Equatable { case natural; case worstCase(height: CGFloat) }
    let configuration: DockTileConfiguration
    let layout: LayoutMode
    var settings: PopoverSettings? = nil          // nil → the panel loads the saved shared-suite values
    var editing: PopoverEditing? = nil             // Task 8 adds the type; keep nil until then
    var fit: Fit = .natural
    var signature: String = ""                     // .id() for the embedded panel
    nonisolated static func fitScale(available: CGSize, worst: CGSize) -> CGFloat
}
```
(Until Task 8 exists, omit the `editing` property — Task 8 adds it.)

- [ ] **Step 1: Write the failing test**

```swift
//  PopoverPreviewCanvasTests.swift — guards the hero zoom rule: fit the worst-case panel with a
//  margin, boost 10%, never exceed the flush fit or 1.04 (so the panel can't clip or zoom in).
import Testing
import Foundation
@testable import Dock_Tile

@Suite("PopoverPreviewCanvas fit scale")
struct PopoverPreviewCanvasTests {
    @Test("Roomy hero: boosted fit wins, capped at 1.04")
    func roomyCapsAtMaxZoom() {
        let s = PopoverPreviewCanvas.fitScale(available: CGSize(width: 1000, height: 1000), worst: CGSize(width: 200, height: 100))
        #expect(s == 1.04)
    }
    @Test("Tight hero: the flush fit clamps the boosted fit")
    func tightClampsToRawFit() {
        let s = PopoverPreviewCanvas.fitScale(available: CGSize(width: 300, height: 300), worst: CGSize(width: 292, height: 100))
        // rawFit = (300-8)/292 = 1.0 ; fit = (300-56)/292 = 0.8356 → ×1.10 = 0.919 → min = 0.919
        #expect(abs(s - 0.9191) < 0.001)
    }
    @Test("Height-bound hero uses the height axis")
    func heightBound() {
        let s = PopoverPreviewCanvas.fitScale(available: CGSize(width: 1000, height: 144), worst: CGSize(width: 100, height: 100))
        // fit = (144-44)/100 = 1.0 → 1.1 ; rawFit = (144-8)/100 = 1.36 ; cap 1.04 → 1.04
        #expect(s == 1.04)
    }
}
```

- [ ] **Step 2: Run to verify it fails** — `… -only-testing:DockTileTests/PopoverPreviewCanvasTests` → compile error (type missing).

- [ ] **Step 3: Implement the canvas** (bottom of `PopoverAppearanceView.swift`)

```swift
// MARK: - Popover preview canvas (shared by Popover settings, Tile Detail, About)

/// The wallpaper-style surface (`underWindowBackground`) with the REAL popover panel floating on it in
/// NSPopover-like chrome. `.natural` renders 1:1 (Tile Detail's editor); `.worstCase(height:)` zooms to
/// a fixed fit derived from the largest possible panel (Settings preview), so control changes visibly
/// spread/tighten instead of re-filling the width.
struct PopoverPreviewCanvas: View {
    enum Fit: Equatable { case natural; case worstCase(height: CGFloat) }

    let configuration: DockTileConfiguration
    let layout: LayoutMode
    var settings: PopoverSettings? = nil
    var fit: Fit = .natural
    var signature: String = ""

    private let cornerRadius: CGFloat = 14

    nonisolated static func fitScale(available: CGSize, worst: CGSize) -> CGFloat {
        let fit = min((available.width - 56) / worst.width, (available.height - 44) / worst.height)
        let rawFit = min((available.width - 8) / worst.width, (available.height - 8) / worst.height)
        return min(rawFit, fit * 1.10, 1.04)
    }

    var body: some View {
        Group {
            switch fit {
            case .natural:
                chrome
                    .padding(22)
                    .frame(maxWidth: .infinity)
            case .worstCase(let height):
                GeometryReader { proxy in
                    let scale = Self.fitScale(available: proxy.size, worst: Self.worstCasePanelSize(for: layout, appCount: configuration.appItems.count))
                    chrome
                        .fixedSize()
                        .scaleEffect(scale, anchor: .center)
                        .shadow(color: .black.opacity(0.28), radius: 22 * scale, y: 10 * scale)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(height: height)
            }
        }
        .background(StudioCanvasBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
    }

    @ViewBuilder private var panel: some View {
        Group {
            if layout == .grid {
                StackPopoverView(configuration: configuration, onLaunch: {}, showsBackground: false,
                                 isPreview: true, settingsOverride: settings)
            } else {
                ListPopoverView(configuration: configuration, onLaunch: {}, showsBackground: false,
                                isPreview: true, settingsOverride: settings)
            }
        }
        .id(signature)
    }

    private var chrome: some View {
        panel
            .background(VisualEffectView.popoverSurfaceInWindow)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .shadow(color: .black.opacity(fit == .natural ? 0.22 : 0), radius: 18, y: 8)
    }

    /// Largest footprint over every tier — moved verbatim from PopoverAppearanceView.worstCasePanelSize,
    /// parameterised on the app count.
    private static func worstCasePanelSize(for layout: LayoutMode, appCount count: Int) -> CGSize {
        switch layout {
        case .grid:
            var maxW: CGFloat = 1, maxH: CGFloat = 1
            for size in PopoverSizeTier.allCases {
                let m = PopoverMetrics.grid(popoverSize: size, tileSize: .large, spacing: .spacious, showLabels: true)
                let cols = max(1, min(m.columns, max(1, count)))
                let rows = max(1, Int(ceil(Double(max(1, count)) / Double(cols))))
                let w = m.cellWidth * CGFloat(cols) + m.gap * CGFloat(cols - 1) + 32
                let itemH = m.iconSize + 18 + 4
                let h = 36 + CGFloat(rows) * itemH + CGFloat(rows - 1) * m.gap + 32
                maxW = max(maxW, w); maxH = max(maxH, h)
            }
            return CGSize(width: maxW, height: maxH)
        case .list:
            let m = PopoverMetrics.list(popoverSize: .large, tileSize: .large, spacing: .spacious)
            let rowH = max(m.iconSize, m.fontSize) + m.rowVerticalPadding * 2 + 4
            let h = 33 + CGFloat(max(1, count)) * rowH + 9 + 42 + 16
            return CGSize(width: m.width, height: h)
        }
    }
}
```

- [ ] **Step 4: Use it in the Popover pane**

Replace `heroPreview`, `popoverChrome`, `realPopoverPanel`, `worstCasePanelSize`, `heroHeight`, `popoverCornerRadius` in `PopoverAppearanceView` with:
```swift
    private var heroPreview: some View {
        PopoverPreviewCanvas(configuration: PreviewAppCatalog.sampleConfiguration,
                             layout: previewLayout,
                             settings: activeDraft.wrappedValue,
                             fit: .worstCase(height: 300),
                             signature: previewSignature)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .animation(.easeInOut(duration: max(0.18, motionDuration)), value: previewSignature)
    }
```
Also restyle `sectionHeader` to the design (13pt semibold, not uppercased) and `card` to `cornerRadius: 12`:
```swift
    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4).padding(.bottom, 6)
    }
```
(`configureStrip`'s uppercase title likewise: `Text(AppStrings.Settings.popoverConfigure).font(.system(size: 13, weight: .semibold))`.)

- [ ] **Step 5: Tests + build + capture**

`PopoverPreviewCanvasTests` PASS; whole suite green; `PopoverMetricsTests` untouched. Capture `task6-popover --row "Popover"`; hover a tile in the preview — highlight still works; clicking never launches anything.

- [ ] **Step 6: Commit**

```bash
git add DockTile/Views/PopoverAppearanceView.swift DockTileTests/Unit/UI/PopoverPreviewCanvasTests.swift
git commit -m "refactor(popover): extract PopoverPreviewCanvas around the real panels" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: About pane

**Files:**
- Modify: `DockTile/Views/AboutView.swift` (replace whole file with `AboutPaneView`)
- Modify: `DockTile/App/DockTileApp.swift:26, 80-92`
- Modify: `DockTile/Views/DockTileConfigurationView.swift` (`SettingsPane.about`, `settingsDetail`), `DockTileSidebarView.swift` (third section)
- Modify: `AppStrings.swift`, `Localizable.xcstrings`, `DockTile/Resources/Info.plist` (optional `DTFeedbackEmail`); Test: `AppStringsTests.swift`

**Interfaces:**
- Consumes: `updateController.checkForUpdates()` / `.canCheckForUpdates`, `DiagnosticsLog.shared.copyToPasteboard()`, `AppEnvironment.appVersion`, `PaneIcon.about`.
- Produces: `SettingsPane.about`; `AboutPaneView`.

- [ ] **Step 1: Strings** (run each; then add the accessors under a new `enum About` in `AppStrings` and one `#expect(!….isEmpty)` per accessor in `AppStringsTests`)

```bash
Scripts/add-string.py about.title "About" "About pane title"
Scripts/add-string.py about.version "Version %@" "About: version line"
Scripts/add-string.py about.website "Website" "About: website row label"
Scripts/add-string.py about.feedbackTitle "Found a bug or have an idea?" "About: feedback card title"
Scripts/add-string.py about.feedbackBody "Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal." "About: feedback card body"
Scripts/add-string.py about.sendFeedback "Send Feedback…" "About: opens the feedback email"
Scripts/add-string.py about.alsoFrom "Also from Happy Machines" "About: studio section header"
Scripts/add-string.py about.studioTitle "Made by Happy Machines Company" "About: studio row title"
Scripts/add-string.py about.studioSubtitle "A tiny product studio building nifty Mac apps that each fix one thing well." "About: studio row subtitle"
Scripts/add-string.py about.spadesTitle "Spades Audio" "About: sibling product row title"
Scripts/add-string.py about.spadesSubtitle "Per-app volume, EQ and output control for your Mac, from the menu bar." "About: sibling product subtitle"
Scripts/add-string.py about.learnMore "Learn More…" "About: opens spadesaudio.com"
```
```swift
    enum About {
        static let title = NSLocalizedString("about.title", value: "About", comment: "About pane title")
        static func version(_ v: String) -> String { String(format: NSLocalizedString("about.version", value: "Version %@", comment: "About: version line"), v) }
        static let website = NSLocalizedString("about.website", value: "Website", comment: "About: website row label")
        static let feedbackTitle = NSLocalizedString("about.feedbackTitle", value: "Found a bug or have an idea?", comment: "About: feedback card title")
        static let feedbackBody = NSLocalizedString("about.feedbackBody", value: "Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal.", comment: "About: feedback card body")
        static let sendFeedback = NSLocalizedString("about.sendFeedback", value: "Send Feedback…", comment: "About: opens the feedback email")
        static let alsoFrom = NSLocalizedString("about.alsoFrom", value: "Also from Happy Machines", comment: "About: studio section header")
        static let studioTitle = NSLocalizedString("about.studioTitle", value: "Made by Happy Machines Company", comment: "About: studio row title")
        static let studioSubtitle = NSLocalizedString("about.studioSubtitle", value: "A tiny product studio building nifty Mac apps that each fix one thing well.", comment: "About: studio row subtitle")
        static let spadesTitle = NSLocalizedString("about.spadesTitle", value: "Spades Audio", comment: "About: sibling product row title")
        static let spadesSubtitle = NSLocalizedString("about.spadesSubtitle", value: "Per-app volume, EQ and output control for your Mac, from the menu bar.", comment: "About: sibling product subtitle")
        static let learnMore = NSLocalizedString("about.learnMore", value: "Learn More…", comment: "About: opens spadesaudio.com")
    }
```
`AppStrings.Button.checkNow` ("Check Now") exists — About uses the existing app-menu wording instead: add `Scripts/add-string.py button.checkForUpdates "Check for Updates…" "About/menu"` + `static let checkForUpdates`. Also `Scripts/add-string.py menu.copyDiagnostics …` already exists as `AppStrings.Menu.copyDiagnostics` — reuse it.

- [ ] **Step 2: Replace `AboutView.swift`**

```swift
//
//  AboutView.swift
//  DockTile
//
//  The About pane (v2): lives in the sidebar under "Dock Tile" — the only home of Software Update.
//  Swift 6 - Strict Concurrency
//

import SwiftUI

/// Links the pane opens. `feedback` comes from Info.plist `DTFeedbackEmail` (mailto:) when set,
/// otherwise the website — never a hard-coded address.
enum AboutLinks {
    static let website = URL(string: "https://docktile.rkarthik.co")!
    static let studio  = URL(string: "https://happymachines.company/")!
    static let spades  = URL(string: "https://spadesaudio.com/")!
    static var feedback: URL {
        if let email = Bundle.main.object(forInfoDictionaryKey: "DTFeedbackEmail") as? String,
           !email.isEmpty, let url = URL(string: "mailto:\(email)?subject=Dock%20Tile%20feedback") {
            return url
        }
        return website
    }
}

struct AboutPaneView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @EnvironmentObject private var updateController: UpdateController

    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    // One grouped Form (a Form is List-backed and will not size itself inside a ScrollView): the hero
    // rides as a full-bleed, clear-background first row.
    var body: some View {
        Form {
                    Section {
                        hero
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    Section {
                        LabeledContent {
                            Button(AppStrings.Button.checkForUpdates) {
                                DiagnosticsLog.shared.ui("About → Check for Updates")
                                updateController.checkForUpdates()
                            }
                            .disabled(!updateController.canCheckForUpdates)
                        } label: {
                            Text(AppStrings.appName)
                            Text(AppStrings.About.version(AppEnvironment.appVersion))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        LabeledContent(AppStrings.About.website) {
                            Link("docktile.rkarthik.co", destination: AboutLinks.website)
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppStrings.About.feedbackTitle)
                            Text(AppStrings.About.feedbackBody).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            Button {
                                DiagnosticsLog.shared.ui("About → Send Feedback")
                                NSWorkspace.shared.open(AboutLinks.feedback)
                            } label: { Label(AppStrings.About.sendFeedback, systemImage: "envelope") }
                            .frame(maxWidth: .infinity)
                            Button {
                                DiagnosticsLog.shared.ui("About → Copy Diagnostics")
                                DiagnosticsLog.shared.copyToPasteboard()
                            } label: { Label(AppStrings.Menu.copyDiagnostics, systemImage: "doc.text") }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Section(AppStrings.About.alsoFrom) {
                        studioRow(icon: "face.smiling", tint: .orange, title: AppStrings.About.studioTitle,
                                  subtitle: AppStrings.About.studioSubtitle) {
                            Link("happymachines.company", destination: AboutLinks.studio)
                        }
                        studioRow(icon: "suit.spade.fill", tint: .black, title: AppStrings.About.spadesTitle,
                                  subtitle: AppStrings.About.spadesSubtitle) {
                            Button(AppStrings.About.learnMore) { NSWorkspace.shared.open(AboutLinks.spades) }
                        }
                    } footer: {
                        Text(copyright)
                            .font(.caption).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
        }
        .formStyle(.grouped)
        .paneTitleBand(AppStrings.About.title)
    }

    /// The product in context: the user's first three tiles (or the defaults) on a Dock strip.
    private var hero: some View {
        let tiles = Array(configManager.configurations.prefix(3))
        return HStack(spacing: 10) {
            if tiles.isEmpty {
                ForEach([TintColor.blue, .purple, .pink], id: \.self) { tint in
                    DockTileIconPreview(tintColor: tint, iconType: .sfSymbol, iconValue: "folder.fill",
                                        iconScale: ConfigurationDefaults.iconScale,
                                        iconWeight: ConfigurationDefaults.iconWeight, size: 48)
                }
            } else {
                ForEach(tiles) { DockTileIconPreview.fromConfig($0, size: 48) }
            }
            Divider().frame(height: 40)
            Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable().frame(width: 48, height: 48)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(StudioCanvasBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func studioRow<Trailing: View>(icon: String, tint: Color, title: String, subtitle: String,
                                           @ViewBuilder trailing: () -> Trailing) -> some View {
        LabeledContent {
            trailing()
        } label: {
            HStack(spacing: 12) {
                SettingsBadgeIcon(systemName: icon, tint: tint, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Wire it**

- `SettingsPane`: add `case about` (after `dockLock`); `settingsDetail`: `case .about: AboutPaneView().environmentObject(configManager)` — `updateController` is already in the environment from `DockTileApp`.
- `DockTileSidebarView`: third section:
```swift
            Section(AppStrings.Sidebar.dockTileSection) {
                SettingsRow(title: AppStrings.About.title, systemName: PaneIcon.about.systemName, tint: PaneIcon.about.tint)
                    .tag(SidebarSelection.settings(.about))
            }
```
- `DockTileApp.swift`: delete `private let aboutWindowController = AboutWindowController()`; the About command becomes
```swift
                Button(AppStrings.Menu.aboutDockTile) {
                    DiagnosticsLog.shared.ui("Menu → About Dock Tile")
                    NotificationCenter.default.post(name: .openSettingsPane, object: SettingsPane.about)
                }
```
with `Scripts/add-string.py menu.aboutDockTile "About Dock Tile" "App menu"` + `AppStrings.Menu.aboutDockTile`; the "Check for Updates..." menu item uses `AppStrings.Button.checkForUpdates`.
- `AppDelegate`: the deep-link / reopen paths call `showConfigurationWindow()`; About reuses that window so nothing changes there.
- Info.plist: add `DTFeedbackEmail` (string) with the address you want feedback sent to (leave unset → button opens the website).

- [ ] **Step 4: Tests + build + capture + flow check**

Suite green (+13 string expectations). `Scripts/dev-capture.sh task7-about --row "About"` light and `--dark`. App menu → About Dock Tile selects the pane; *Check for Updates…* runs Sparkle (dialog appears); *Copy Diagnostics* puts the report on the clipboard (`pbpaste | head -3`); links open in the browser.

- [ ] **Step 5: Commit**

```bash
git add DockTile/Views DockTile/App/DockTileApp.swift DockTile/Constants DockTile/Resources DockTileTests
git commit -m "feat(about): About pane in the sidebar replaces the About window" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Editing mode in the real popover panels

**Files:**
- Modify: `DockTile/Models/ConfigurationModels.swift` (+ `AppListEditor`)
- Modify: `DockTile/UI/NativePopoverViews.swift` (`PopoverEditing`, `PopoverItemDropDelegate`, editing in `StackPopoverView`/`StackAppItem`/`ListPopoverView`/`ListAppRow`)
- Modify: `DockTile/Views/PopoverAppearanceView.swift` (`PopoverPreviewCanvas` gains `editing`)
- Modify: `AppStrings.swift`, `Localizable.xcstrings`; Tests: `DockTileTests/Unit/Models/AppListEditorTests.swift` (new), `AppStringsTests.swift`

**Interfaces:**
- Produces:
```swift
enum AppListEditor {
    nonisolated static func removing(_ id: UUID, from items: [AppItem]) -> [AppItem]
    nonisolated static func moving(_ draggedID: UUID, onto targetID: UUID, in items: [AppItem]) -> [AppItem]
}
struct PopoverEditing {
    let onRemove: (AppItem) -> Void
    let onMove: (_ dragged: AppItem, _ target: AppItem) -> Void
}
// StackPopoverView / ListPopoverView / PopoverPreviewCanvas: `var editing: PopoverEditing? = nil`
```

- [ ] **Step 1: Write the failing tests**

```swift
//  AppListEditorTests.swift — the preview editor's reorder/remove reducer (pure arrays in/out).
import Testing
import Foundation
@testable import Dock_Tile

@Suite("AppListEditor")
struct AppListEditorTests {
    private func items(_ names: String...) -> [AppItem] {
        names.map { AppItem(bundleIdentifier: "com.test.\($0)", name: $0) }
    }

    @Test("removing drops exactly the matching item")
    func removing() {
        let list = items("A", "B", "C")
        let out = AppListEditor.removing(list[1].id, from: list)
        #expect(out.map(\.name) == ["A", "C"])
    }

    @Test("removing an unknown id is a no-op")
    func removingUnknown() {
        let list = items("A", "B")
        #expect(AppListEditor.removing(UUID(), from: list).map(\.name) == ["A", "B"])
    }

    @Test("moving forward lands after the target; backward lands before it")
    func moving() {
        let list = items("A", "B", "C", "D")
        #expect(AppListEditor.moving(list[0].id, onto: list[2].id, in: list).map(\.name) == ["B", "C", "A", "D"])
        #expect(AppListEditor.moving(list[3].id, onto: list[1].id, in: list).map(\.name) == ["A", "D", "B", "C"])
    }

    @Test("moving onto itself or an unknown target changes nothing")
    func movingNoop() {
        let list = items("A", "B")
        #expect(AppListEditor.moving(list[0].id, onto: list[0].id, in: list).map(\.name) == ["A", "B"])
        #expect(AppListEditor.moving(list[0].id, onto: UUID(), in: list).map(\.name) == ["A", "B"])
    }
}
```

- [ ] **Step 2: Run to verify it fails** — compile error (`AppListEditor` missing).

- [ ] **Step 3: Implement the seam** (append to `ConfigurationModels.swift`)

```swift
// MARK: - App list editing (pure seam behind the Tile Detail preview editor)

/// Plain-value reducer for the editable popover preview. Mirrors the semantics of the old table's
/// `AppItemDropDelegate.dropEntered` (drag forward → after target, backward → before target).
enum AppListEditor {
    nonisolated static func removing(_ id: UUID, from items: [AppItem]) -> [AppItem] {
        items.filter { $0.id != id }
    }

    nonisolated static func moving(_ draggedID: UUID, onto targetID: UUID, in items: [AppItem]) -> [AppItem] {
        guard draggedID != targetID,
              let from = items.firstIndex(where: { $0.id == draggedID }),
              let to = items.firstIndex(where: { $0.id == targetID }) else { return items }
        var out = items
        out.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        return out
    }
}
```

- [ ] **Step 4: Run the tests** — `AppListEditorTests` PASS.

- [ ] **Step 5: Strings**

```bash
Scripts/add-string.py popover.editing.remove "Remove" "Context menu / remove badge in the tile editor"
Scripts/add-string.py popover.editing.noAppsYet "No apps yet. Use Add to choose what opens from this tile." "Tile editor empty state"
```
`AppStrings.PopoverOption`: `static let editingRemove = …`, `static let editingNoAppsYet = …` (+ tests).

- [ ] **Step 6: Editing types + drop delegate** (in `NativePopoverViews.swift`, above `StackPopoverView`)

```swift
// MARK: - Editing mode (Tile Detail's preview editor; nil in helpers)

/// Handlers the main app supplies to turn the panel into the tile's app editor. `nil` (helpers,
/// Settings preview) leaves the panel exactly as it ships. Editing implies preview: no launches.
struct PopoverEditing {
    let onRemove: (AppItem) -> Void
    let onMove: (_ dragged: AppItem, _ target: AppItem) -> Void
}

/// Drag-to-reorder inside the panel; moved from DockTileDetailView's table (same semantics).
struct PopoverItemDropDelegate: DropDelegate {
    let target: AppItem
    let dragged: () -> AppItem?
    let onMove: (AppItem, AppItem) -> Void
    let onFinish: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = dragged(), dragged.id != target.id else { return }
        withAnimation(.easeInOut(duration: 0.2)) { onMove(dragged, target) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { onFinish(); return true }
}
```

- [ ] **Step 7: `StackPopoverView` edit mode**

Add `var editing: PopoverEditing? = nil` after `settingsOverride`, `@State private var draggedItem: AppItem? = nil`, and `private var actionsDisabled: Bool { isPreview || editing != nil }`. Change `launchAppAt` and `openConfigurator` guards to `guard !actionsDisabled …`. In the header, wrap the gear button: `if editing == nil { Button(action: openConfigurator) {…} } else { Color.clear.frame(width: 28, height: 28) }`. In the grid `ForEach`, replace the `StackAppItem(...)` construction with:
```swift
                            StackAppItem(
                                app: app,
                                isSelected: selectedIndex == index,
                                iconSize: metrics.iconSize,
                                cellWidth: metrics.cellWidth,
                                showLabel: settings.showLabels,
                                highlightOnHover: settings.highlightOnHover,
                                editing: editing,
                                onLaunch: onLaunch
                            )
                            .id("\(app.id)-\(iconStyleManager.currentStyle.rawValue)")
                            .onTapGesture { launchAppAt(index: index) }
                            .onDrag(if: editing != nil) {
                                draggedItem = app
                                return NSItemProvider(object: app.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: PopoverItemDropDelegate(
                                target: app, dragged: { draggedItem },
                                onMove: { d, t in editing?.onMove(d, t) },
                                onFinish: { draggedItem = nil }))
```
`onDrag(if:)` doesn't exist — add this tiny helper next to the delegate:
```swift
extension View {
    @ViewBuilder func onDrag(if enabled: Bool, _ data: @escaping () -> NSItemProvider) -> some View {
        if enabled { self.onDrag(data) } else { self }
    }
}
```
Empty state: in `emptyStateView`, when `editing != nil` show `Text(AppStrings.PopoverOption.editingNoAppsYet)` (12pt, secondary, multiline, 230pt max width) instead of the "No apps configured / Configure to add apps" pair.

**No nested scrolling in edit mode.** The shipped panel wraps its grid in a `ScrollView` and caps its height at 600 (`calculateHeight()`); inside Tile Detail's own `ScrollView` that would trap the wheel. When `editing != nil`, render the `LazyVGrid` **without** the inner `ScrollView` and skip the 600 cap:
```swift
            } else if editing != nil {
                gridContent          // the LazyVGrid + paddings, extracted into a private var
            } else {
                ScrollView(.vertical, showsIndicators: true) { gridContent }
            }
```
and in `calculateHeight()` return the uncapped total when `editing != nil`. `ListPopoverView` has no inner scroll view, so only its utility rows change.

- [ ] **Step 8: `StackAppItem` edit affordances**

Add `var editing: PopoverEditing? = nil` (before `onLaunch`). After `.onHover { isHovered = $0 }` append:
```swift
        .overlay(alignment: .topLeading) {
            if let editing, isHovered {
                Button { editing.onRemove(app) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(nsColor: .tertiaryLabelColor), in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppStrings.PopoverOption.editingRemove)
                .offset(x: 2, y: -2)
            }
        }
        .contextMenu {
            if let editing {
                Button(AppStrings.PopoverOption.editingRemove, role: .destructive) { editing.onRemove(app) }
            }
        }
        .focusable(editing != nil)
        .onDeleteCommand { editing?.onRemove(app) }
        .accessibilityAction(named: Text(AppStrings.PopoverOption.editingRemove)) { editing?.onRemove(app) }
```
Below the label, add the "Not installed" caption in edit mode:
```swift
            if editing != nil, AppInstallChecker.resolve(app).status == .missing {
                Text(AppStrings.Label.notInstalled).font(.system(size: 10)).foregroundStyle(.secondary)
            }
```
(`AppStrings.Label.notInstalled` already exists.)

- [ ] **Step 9: `ListPopoverView` / `ListAppRow`**

Same additions: `editing`, `draggedItem`, `actionsDisabled`; hide the `Divider` + both `ListMenuRow`s when `editing != nil`; rows get `editing:` + `onDrag(if:)` / `onDrop`. `ListAppRow` gets `var editing: PopoverEditing? = nil`, a trailing remove button `if let editing, isHovered { Button … "xmark.circle.fill" … }` in place of the `Spacer()`'s end, the same `.contextMenu`, `.focusable`, `.onDeleteCommand`, `.accessibilityAction`, and a trailing `Text(AppStrings.Label.notInstalled)` caption when editing and missing.

- [ ] **Step 10: Thread it through the canvas**

`PopoverPreviewCanvas`: add `var editing: PopoverEditing? = nil` and pass `editing: editing` into both panel constructors.

- [ ] **Step 11: Build + full tests + helper sanity**

Build; suite green (+4 editor tests, +2 strings). **Helpers are unaffected by construction** — verify: click a pinned dev tile in the Dock; its popover still shows the gear (grid) / utility rows (list), taps still launch, no × badges appear.

- [ ] **Step 12: Commit**

```bash
git add DockTile/Models DockTile/UI DockTile/Views/PopoverAppearanceView.swift DockTile/Constants DockTile/Resources DockTileTests
git commit -m "feat(popover): editing mode on the real panels (remove, reorder, Delete key, context menu)" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Tile Detail — band actions, hero card, editable preview

**Files:**
- Modify: `DockTile/Views/DockTileDetailView.swift` (body, toolbar, hero, `appsTableSection` → `inThisTileSection`, delete `deleteSection`, `NativeAppsTableView`, `AppItemDropDelegate`, `removeSelectedApp`, `selectedAppIDs`)
- Modify: `AppStrings.swift`, `Localizable.xcstrings`; Test: `AppStringsTests.swift`

**Interfaces:**
- Consumes: `PopoverPreviewCanvas(configuration:layout:editing:fit:signature:)`, `PopoverEditing`, `AppListEditor`.
- Preserves unchanged: `resolveDockAction`, `dockActionIsEnabled`, `contentSignature`, `handleDockAction`, `performDockAction`, `showDockRestartConsentAlert`, `addItem()`, the auto-save `.task(id: saveGeneration)`, every `.onChange`.

- [ ] **Step 1: Strings**

```bash
Scripts/add-string.py section.inThisTile "In This Tile" "Tile Detail: apps section header"
Scripts/add-string.py label.editorHint "Hover to remove · Drag to reorder" "Tile Detail: apps section caption"
Scripts/add-string.py tooltip.deleteTile "Delete Tile" "Tile Detail: trash button tooltip"
```
Accessors: `AppStrings.Section.inThisTile`, `AppStrings.Label.editorHint`, `AppStrings.Tooltip.deleteTile` (+ tests).

- [ ] **Step 2: Toolbar → band actions** (replace the existing `.toolbar { ToolbarItem(placement: .confirmationAction) … }`)

```swift
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    DiagnosticsLog.shared.ui("Tile Detail → Delete tile pressed '\(editedConfig.name)' (shows delete confirmation)")
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(AppStrings.Tooltip.deleteTile)
                .accessibilityLabel(AppStrings.Title.deleteTile)

                actionButton
            }
        }
```
```swift
    /// Prominent for Dock-adding actions, plain otherwise; spinner INSIDE while processing.
    @ViewBuilder private var actionButton: some View {
        let button = Button(action: handleDockAction) {
            HStack(spacing: 6) {
                if isProcessing { ProgressView().controlSize(.small) }
                else if currentDockAction == .install {
                    Image(systemName: isCurrentlyInDock ? "arrow.clockwise" : "plus")
                }
                Text(actionButtonText)
            }
        }
        .disabled(!Self.dockActionIsEnabled(action: currentDockAction, isDirty: isDirty, isProcessing: isProcessing))
        if currentDockAction == .install {
            button.buttonStyle(.borderedProminent).foregroundStyle(.white)
        } else {
            button.buttonStyle(.bordered)
        }
    }
```

- [ ] **Step 3: Hero**

In `heroSection`: change `size: 118` → `96`, the `.contentShape` radius to `96 * 0.225`, `SubtleButton(... width: 96 ...)`; delete the **Layout** `formRow` (row 3) so the card is Tile Name / Show Tile / Show in App Switcher (`isLast: true` on the App Switcher row).

- [ ] **Step 4: In This Tile section** (replaces `appsTableSection`)

```swift
    private var previewSignature: String {
        ([editedConfig.layoutMode.rawValue, iconStyleManager.currentStyle.rawValue]
         + editedConfig.appItems.map { $0.id.uuidString }
         + configManager.missingAppIDs.map { $0.uuidString }).joined(separator: "-")
    }

    private var inThisTileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(AppStrings.Section.inThisTile).font(.system(size: 13, weight: .semibold))
                    Text(AppStrings.Label.editorHint).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Spacer()
                Picker("", selection: $editedConfig.layoutMode) {
                    Text(AppStrings.Layout.grid).tag(LayoutMode.grid)
                    Text(AppStrings.Layout.list).tag(LayoutMode.list)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                Button(action: addItem) { Label(AppStrings.Button.add, systemImage: "plus") }
                    .help(AppStrings.FilePicker.message)
            }
            .padding(.horizontal, 4)

            PopoverPreviewCanvas(
                configuration: editedConfig,
                layout: editedConfig.layoutMode,
                editing: PopoverEditing(
                    onRemove: { app in
                        editedConfig.appItems = AppListEditor.removing(app.id, from: editedConfig.appItems)
                        DiagnosticsLog.shared.log("tile", "Removed 1 item(s) from '\(editedConfig.name)': \(app.name)")
                    },
                    onMove: { dragged, target in
                        editedConfig.appItems = AppListEditor.moving(dragged.id, onto: target.id, in: editedConfig.appItems)
                    }),
                fit: .natural,
                signature: previewSignature)

            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red).padding(.top, 4)
            }
        }
    }
```
Add `@ObservedObject private var iconStyleManager = IconStyleManager.shared` to the view. In `body`'s `VStack` replace `appsTableSection` with `inThisTileSection` and **delete `deleteSection`** (the trash is in the band). Delete `deleteSection`, `selectedAppIDs`, `removeSelectedApp`, `NativeAppsTableView`, `AppItemDropDelegate` (now `PopoverItemDropDelegate` in the UI file). Keep `AppIconView` (the sheet uses it) and `SubtleButton`.

- [ ] **Step 5: Build + tests + flow verification (the important one)**

Suite green (`DockActionResolutionTests` unchanged). Then in the dev app, in this order, checking `Copy Diagnostics` output where noted:
1. `+` → blank draft; **Add** → pick two apps and a folder (multi-select) → they appear in the preview; the sidebar `+` re-enables (edited).
2. Drag the folder to the first position — order persists after switching tiles and back (auto-save).
3. Hover an app → × → removed; right-click → Remove; Tab to a cell, press Delete → removed. Undo is not expected.
4. Grid ↔ List segmented control switches the preview layout; the tile's `layoutMode` persists.
5. Action button: draft reads **Add to Dock** (prominent) → click → consent alert (first time) → helper pinned in the Dock; button reads **Update**. Turn *Show Tile* off → **Remove from Dock** (bordered) → click → unpinned; button reads **Done** (disabled) until an edit.
6. A tile with an uninstalled app shows the dashed cell + "Not installed"; removing it via × works; Settings → General → Scan still offers Remove All / Review in Tiles.
7. Trash in the band → "Delete Tile" alert → Delete removes the tile and its Dock entry.
Capture `task9-tile`, `task9-tile --dark`, and compare with `Main.dc.html` / `MainDark.dc.html`.

- [ ] **Step 6: Commit**

```bash
git add DockTile/Views/DockTileDetailView.swift DockTile/Constants DockTile/Resources DockTileTests
git commit -m "feat(tile): band actions, hero card, editable popover preview replaces the apps table" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Add a Tile dialog — blank first, always opens

**Files:**
- Modify: `DockTile/Views/SmartAddSheet.swift`
- Modify: `DockTile/Views/DockTileConfigurationView.swift:157-175` (`handleAddTapped`), `:307-329` (`EmptyConfigurationView`)
- Modify: `DockTile/Managers/SmartAddEngine.swift` (+ pure seam), `AppStrings.swift`, `Localizable.xcstrings`
- Tests: `DockTileTests/Unit/Managers/SmartAddEngineTests.swift`, `AppStringsTests.swift`

**Interfaces:**
- Produces: `SmartAddEngine.suggestionsForAddFlow(enabled: Bool, computed: [TileSuggestion]) -> [TileSuggestion]` (nonisolated static). `SmartAddSheet` accepts an empty `suggestions` array.

- [ ] **Step 1: Failing test** (append to `SmartAddEngineTests`)

```swift
    @Test("The Add dialog always opens; Smart Add off just empties the suggestions")
    func addFlowAlwaysOpens() {
        let one = TileSuggestion(name: "Work", strategy: .category, reason: "By category", tint: .blue,
                                 symbol: "folder.fill", appItems: [AppItem(bundleIdentifier: "a", name: "A")])
        #expect(SmartAddEngine.suggestionsForAddFlow(enabled: false, computed: [one]).isEmpty)
        #expect(SmartAddEngine.suggestionsForAddFlow(enabled: true, computed: [one]).count == 1)
        #expect(SmartAddEngine.suggestionsForAddFlow(enabled: true, computed: []).isEmpty)
    }
```

- [ ] **Step 2: Run → fails** (missing member). **Step 3: Implement** (in `SmartAddEngine`):

```swift
    /// v2 add flow: the Add a Tile dialog opens from EVERY entry point. The toggle only decides
    /// whether suggestions are shown inside it — never whether the dialog appears.
    nonisolated static func suggestionsForAddFlow(enabled: Bool, computed: [TileSuggestion]) -> [TileSuggestion] {
        enabled ? computed : []
    }
```
**Step 4:** test passes.

- [ ] **Step 5: `handleAddTapped` always presents**

```swift
    private func handleAddTapped() {
        let computed = smartAddEnabled
            ? smartAddEngine.computeSuggestions(existing: configManager.configurations) : []
        let suggestions = SmartAddEngine.suggestionsForAddFlow(enabled: smartAddEnabled, computed: computed)
        DiagnosticsLog.shared.ui("+ pressed → Add a Tile dialog (\(suggestions.count) suggestion(s), smartAdd=\(smartAddEnabled))")
        smartAddPresentation = SmartAddPresentation(suggestions: suggestions)
    }
```
(`.sheet(item:)` stays; `onCreateNew` / `onUse` / `onClose` unchanged.)

- [ ] **Step 6: Empty state**

`EmptyConfigurationView`: button label → `Label(AppStrings.Button.addATile, systemImage: "plus")`; description string: `Scripts/add-string.py empty.createFirstTileDescriptionV2 "Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use." "Zero-tiles description"` → point `AppStrings.Empty.createFirstTileDescription` at that key/value.

- [ ] **Step 7: Sheet strings**

```bash
Scripts/add-string.py smartAdd.blankTitle "Create a blank tile" "Add a Tile: blank row title"
Scripts/add-string.py smartAdd.blankSubtitle "Name it, pick an icon and add apps yourself." "Add a Tile: blank row subtitle"
Scripts/add-string.py smartAdd.orStartFrom "or start from what you use" "Add a Tile: rule between blank row and suggestions"
Scripts/add-string.py smartAdd.noSuggestions "No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General." "Add a Tile: empty suggestions note"
```
Accessors in `AppStrings.SmartAdd` (+ tests). Remove `SmartAdd.subtitle` accessor + its `#expect` (the catalog key may stay).

- [ ] **Step 8: Rebuild the sheet body**

```swift
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            blankRow
            if suggestions.isEmpty {
                noSuggestionsNote
            } else {
                orRule
                cardsRow
            }
            Divider()
            footer
        }
        .frame(width: 588)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("smartAddSheet")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(AppStrings.SmartAdd.title).font(.system(size: 15, weight: .bold))
            Spacer()
            closeButton
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    /// Blank-first: the plain path is the first thing you see and the Return default.
    private var blankRow: some View {
        HStack(spacing: 12) {
            DockTileIconPreview(tintColor: ConfigurationDefaults.tintColor, iconType: ConfigurationDefaults.iconType,
                                iconValue: ConfigurationDefaults.iconValue, iconScale: ConfigurationDefaults.iconScale,
                                iconWeight: ConfigurationDefaults.iconWeight, size: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.SmartAdd.blankTitle).font(.system(size: 13, weight: .semibold))
                Text(AppStrings.SmartAdd.blankSubtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(action: onCreateNew) {
                Label(AppStrings.Button.createNewTile, systemImage: "plus").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent).tint(.accentColor).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private var orRule: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 0.5)
            Text(AppStrings.SmartAdd.orStartFrom).font(.system(size: 11)).foregroundStyle(.tertiary)
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 0.5)
        }
        .padding(.horizontal, 18).padding(.bottom, 10)
    }

    private var noSuggestionsNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(.tertiary)
            Text(AppStrings.SmartAdd.noSuggestions).font(.system(size: 11)).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.bottom, 14)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.tertiary).accessibilityHidden(true)
            Text(AppStrings.SmartAdd.privacyFootnote).font(.system(size: 11)).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
    }
```
Delete `sparkleBadge`. `cardsRow` keeps `.padding(.horizontal, 18).padding(.bottom, 16)` (no top padding). In `SuggestionCard.actionButton` drop `.tint(.accentColor)` so it is a plain bordered button. Update the `#Preview` if it references removed members.

- [ ] **Step 9: Tests + build + flow verification**

Suite green. In the dev app: sidebar `+`, General's *Add a Tile…*, and the zero-tiles button (delete all tiles to see it, then restore) each open the dialog; with Smart Add OFF the dialog shows only the blank row + note; Return → blank draft selected; *Use This Tile* → pre-filled draft with the provenance banner; Esc closes with no tile; ⌘N still creates a blank tile directly. Capture `task10-sheet` (open the dialog first) light + dark.

- [ ] **Step 10: Commit**

```bash
git add DockTile/Views DockTile/Managers/SmartAddEngine.swift DockTile/Constants DockTile/Resources DockTileTests
git commit -m "feat(add-tile): blank-first dialog that opens from every add entry point" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: Remove dead `ItemRowView.swift` and retired strings

**Files:**
- Delete: `DockTile/Components/ItemRowView.swift`
- Modify: `DockTile.xcodeproj/project.pbxproj`, `AppStrings.swift`, `AppStringsTests.swift`

- [ ] **Step 1: Confirm it is unreferenced**

`grep -rn "ItemRowView" DockTile DockTileTests | grep -v "Components/ItemRowView.swift"` → no output.

- [ ] **Step 2: Remove the file and its project entries**

```bash
git rm DockTile/Components/ItemRowView.swift
python3 - <<'EOF'
import re
p = "DockTile.xcodeproj/project.pbxproj"; s = open(p).read()
before = len(s.splitlines())
s = "\n".join(l for l in s.splitlines() if "ItemRowView.swift" not in l) + "\n"
open(p, "w").write(s); print("removed", before - len(s.splitlines()), "lines")
EOF
```
Expected: 4 lines removed (PBXBuildFile, PBXFileReference, group child, Sources phase). Build must succeed.

- [ ] **Step 3: Retire the Appearance drill-down strings**

Delete `AppStrings.Settings.popoverAppearance`, `popoverAppearanceSubtitle` accessors and their `#expect`s (the catalog entries may stay; Xcode marks them stale). Build; suite green.

- [ ] **Step 4: Commit**

```bash
git add -A DockTile DockTile.xcodeproj DockTileTests
git commit -m "chore: remove dead ItemRowView and retired Appearance strings" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: Dark-mode + full-flow regression pass

**Files:** none (verification only; fix anything found in a follow-up commit named `fix(makeover): …`)

- [ ] **Step 1: Capture every pane in both appearances**

```bash
for r in "General" "Popover" "Dock Lock" "About"; do Scripts/dev-capture.sh final-$r --row "$r"; Scripts/dev-capture.sh final-$r --row "$r" --dark; done
Scripts/dev-capture.sh final-tile; Scripts/dev-capture.sh final-tile --dark
```
Compare each with the matching `docs/v2/canvas/<Name>.dc.html` / `<Name>Dark.dc.html` opened in a browser. Acceptable deviations: real app icons, system material tint. Not acceptable: clipped content, a visible toolbar line, white cards in dark mode, unreadable text.

- [ ] **Step 2: Flow checklist (all must hold — these are the existing flows)**

- Launch with tiles pinned: no Dock restart, tiles unchanged (`Copy Diagnostics` shows no `Removed tile` / `Added tile` lines from launch).
- Hidden-but-pinned tile at launch is reconciled exactly as before (rule: launch-only destructive direction).
- Manual Dock removal of a dev tile → the app marks it hidden (watcher).
- Popover pane: Save with a pinned tile → apply prompt → Apply → tiles rebuilt once, Dock restarted once; helper popover shows the new spacing on next open.
- Dock Lock: toggle on without permission → primer sheet; picker moves the Dock; toggle off.
- Missing app: uninstall (move to Trash) an app in a tile → launch → alert Remove/Keep; Keep → dashed cell in the editor and in the helper popover.
- Smart Add toggle off → dialog opens blank-only; on → suggestions.
- Sparkle: About → Check for Updates… → Sparkle UI appears.
- Window: fixed 768 width; vertical resize ok; Dock-icon click reopens the one window; `docktile://configure?bundleId=…` still selects the tile.
- Keyboard: ⌘N (blank tile), ⌘, (General), ⌘S on Popover (Save), Esc in the dialog, Delete on a focused cell.

- [ ] **Step 3: Record**

Paste the capture list and the checklist result into the PR description (or `docs/superpowers/plans/` as `2026-08-29-main-window-makeover-verification.md` if working without a PR). Commit any fixes separately.

---

### Task 13: Documentation + rules

**Files:**
- Modify: `.claude/rules/architecture.md` ("Sidebar Selection & Empty State", "Tile Detail action button", add "Tile editor" + "About pane" paragraphs), `.claude/rules/smart-add.md` ("The + flow"), `.claude/rules/popover-appearance.md` (top-level pane, `PopoverPreviewCanvas`), `.claude/rules/testing.md` (seams list), `CLAUDE.md` (Rules index unchanged; bump nothing), `docs/dock-tile-design-brief.md` §3/§5 (screen inventory)

- [ ] **Step 1: architecture.md**

Replace the "Sidebar Selection & Empty State" first paragraph's bullets with the v2 facts (title band = title text only, no pane icon): static sections **Tiles · Settings (General, Popover, Dock Lock) · Dock Tile (About)**; `.tilesPlaceholder` unchanged; the empty state's single **Add a Tile…** opens the dialog; the `+` gate seam unchanged. Add under "Tile Detail action button": *the button lives in the title band (`ToolbarItemGroup(.primaryAction)` next to the trash); install actions are `.borderedProminent`*. Add a new section:
```markdown
## Tile editor = the real popover (critical)

"In This Tile" renders `PopoverPreviewCanvas` (the wallpaper canvas around the SAME `StackPopoverView` /
`ListPopoverView` helpers ship) with `PopoverEditing` handlers: hover ×, context-menu Remove, Delete key,
drag reorder. `editing` is `nil` in helpers and the Settings preview — the panel's shipped behaviour is
untouched by construction; editing implies `isPreview` (no launches). Reorder/remove go through the pure
`AppListEditor` seam (`AppListEditorTests`). Adding apps stays the native `NSOpenPanel` (multi-select).
There is no apps table any more; do not reintroduce one.
```
And an "About pane" paragraph: sidebar section "Dock Tile" → `AboutPaneView` (replaced the About window); the only home of Software Update; `AboutLinks.feedback` reads `DTFeedbackEmail`.

- [ ] **Step 2: smart-add.md** — replace "The + flow" code block and bullets with:

```markdown
## The + flow (v2: the dialog always opens)

Every add entry point — sidebar `+`, General's *Add a Tile…* row (posts `.addTileRequested`), the
zero-tiles button — calls the SAME `handleAddTapped`, which ALWAYS presents `SmartAddSheet` via
`.sheet(item:)`. `SmartAddEngine.suggestionsForAddFlow(enabled:computed:)` decides what the dialog
shows: suggestions when Smart Add is on and the engine has some, otherwise only the blank-first row +
"No suggestions yet". The sheet's Return default is **Create New Tile** (blank); *Use This Tile* pre-fills
Tile Detail. ⌘N *New Dock Tile* still creates a blank tile directly. Nothing in the dialog docks a tile.
```

- [ ] **Step 3: popover-appearance.md** — first bullet: reached via **Settings → Popover** (top-level pane; the General drill-down is gone); Reset/Save are `.primaryAction` items in the title band. Add: *the hero is `PopoverPreviewCanvas(fit: .worstCase(height: 300))` — the same component Tile Detail uses with `.natural` and `editing`; `PopoverPreviewCanvas.fitScale` is the zoom seam (`PopoverPreviewCanvasTests`).*

- [ ] **Step 4: testing.md** — append to the seams list: `AppListEditor.removing/moving` (preview editor reducer), `PopoverPreviewCanvas.fitScale` (hero zoom), `SmartAddEngine.suggestionsForAddFlow` (dialog always opens; toggle only filters), `ConfigurationDefaults` plus-placeholder default.

- [ ] **Step 5: Commit**

```bash
git add .claude/rules CLAUDE.md docs/dock-tile-design-brief.md
git commit -m "docs(rules): describe the v2 main window (title band, tile editor, About, add flow)" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-review (done while writing)

- **Spec coverage:** §3.1 chrome → Tasks 2–3; §3.2 cards/Customise → 3, 6, 9; §3.3 canvas → 6; §3.4 dark → 12; §4 IA → 4, 7; §5.1 → 8–9; §5.2 → 10; §5.3 → 10; §5.4 → 5; §5.5 → 4, 6; §5.6 → 3 (band only); §5.7 → 7; §5.8 states → covered by the state-bearing code in 8–9 (no separate task); §6 invariants → global constraints + Task 9/12 checks; §7 table → one task each, `ItemRowView` → 11; §8 copy → per-task string steps; §9 a11y → Task 8 (`accessibilityAction`, `focusable`, `onDeleteCommand`), Task 3 (`isHeader`, `+` label); §10 assumptions → Task 7 `DTFeedbackEmail`, ⌘N unchanged in Task 10; §11 testing → Tasks 1, 6, 8, 10 seams.
- **Type consistency:** `PopoverEditing(onRemove:onMove:)`, `PopoverPreviewCanvas(configuration:layout:settings:editing:fit:signature:)`, `AppListEditor.removing(_:from:)` / `.moving(_:onto:in:)`, `SmartAddEngine.suggestionsForAddFlow(enabled:computed:)`, `PaneIcon.{general,popover,dockLock,about}`, `.paneTitleBand(_:icon:)`, `Notification.Name.addTileRequested`, `AppStrings.Button.addATile`, `AppStrings.About.*` are used with the same names everywhere above.
- **Sequencing:** Task 6 ships `PopoverPreviewCanvas` without `editing`; Task 8 adds it before Task 9 consumes it. Task 7 depends on Task 4's `SettingsPane` shape and Task 3's `PaneIcon`.
