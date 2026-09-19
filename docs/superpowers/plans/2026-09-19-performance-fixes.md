# Performance Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every measured performance failure in `docs/performance-baseline-2026-09.md` — slow first popover open after idle, memory abandoned per open, the Customise colour-drag stall, the ~1 s main-thread hang per helper build, config bloat — each proven by re-measuring the same way it was found.

**Architecture:** Twelve tasks, each an independent change with one root cause, ordered smallest-and-safest first. (The spec orders by user impact and would start with Task 4; the tasks are independent except 6 → 5, so the order was Karthik's to change; he chose smallest-first, 2026-09-19.) Execution mode chosen: one fresh subagent per task, reviewed between tasks. Every task ends in a commit and carries its own before/after measurement; a change that does not beat run-to-run noise is reverted and recorded, not kept. Where the root cause is not yet established (memory growth, the Dock watcher) the task starts with evidence gathering and states its hypothesis before any fix.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI + AppKit, Swift Testing (`@Test`, `#expect`, `@testable import Dock_Tile`), `xctrace` / `sample` / `footprint` for measurement, Python 3 + Swift scripts for the harness.

**Spec:** `docs/performance-baseline-2026-09.md` (read its last review section, *Third pass — 2026-09-19*, first) and `docs/performance-baseline-2026-09.json`.

## Global Constraints

- macOS 15.0+ deployment target; Swift 6 strict concurrency; no new dependencies.
- **Karthik's production tiles are live and untouchable (critical).** `AI Tile` and `Utils` are
  pinned in his real Dock, running from `~/Library/Application Support/DockTile/`, against
  `~/Library/Preferences/com.docktile.configs.json`. Nothing in this plan may write that config,
  that support folder, those bundles, or their `persistent-apps` entries, and the Release main app
  is never launched (its launch reconcilers regenerate and re-seat real tiles). Every task ends
  with `Scripts/perf/prod_fingerprint.sh` matching what it printed at the task's start — if it
  differs, stop and report before doing anything else. The dev build is a separate universe by
  design (`.dev` bundle IDs, `com.docktile.dev.configs.json`, `DockTile-Dev/`); this check is what
  proves that separation held rather than assuming it.
- **These fixes only reach a user's tiles through a version bump.** A helper is a *copy* of the main
  app, so replacing the main app leaves every helper running the old code. `classifyForMigration`
  (`HelperMigrationManager.swift:341-353`) regenerates a tile only when it is visible, pinned, has a
  bundle on disk, and its stored `helperAppVersion` differs from `CFBundleShortVersionString` —
  which is `$(MARKETING_VERSION)`. So the release that carries these fixes MUST bump
  `MARKETING_VERSION`, or users keep the old popover behaviour with a new main app. Task 11 proves
  that path works before anything ships.
- Always build and run the **Debug** configuration for development (`.dev` bundle IDs, `com.docktile.dev.configs.json`, `DockTile-Dev/`). Never launch the Release **main app** to measure: its launch reconcilers write production data. Attaching to an already-running Release *helper* and toggling its popover with `open -b` is allowed — that is how the baseline's Release numbers were taken.
- Tests: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO`. That leaves the product unsigned — before launching the dev app afterwards, rebuild without the flag and gate on `codesign --verify "$APP"`.
- New files under `DockTileTests/` auto-join the test target. New **app-target** files do NOT — this plan appends new types to existing app files so `project.pbxproj` is never edited.
- Regression-guard convention (`.claude/rules/testing.md`): a regression-prone decision is extracted to a `nonisolated static` seam taking plain values and unit-tested with exact values. Before writing a guard, name the value that would make it fail.
- Schema evolution (`.claude/rules/development.md`): old configs must always load.
- Surgical changes only: no drive-by refactors, reformatting or comment edits.
- One optimisation per commit. After each task: re-measure with the Task 0 harness under the same conditions (record power source, build, config size), add a row to the **Attempt ledger** at the end of the spec — kept or reverted. **Neutral is a revert.**
- Driving the dev app: Accessibility `set value` / `click` / `set selected` in the single-`to` AppleScript form only. **Never send raw keystrokes.** Pointer input only through `Scripts/perf/safe_input.swift`.
- Gates (CLAUDE.md): `stage-gate --plan` on this file before Task 1; `stage-gate --dev` on each task's diff before push.
- Commits: each task's last step shows the intended commit boundary. **Karthik approved one commit per task on `perf/2026-09-fixes` (2026-09-19)**; nothing is pushed or tagged without asking. Work on the branch Task 0 creates, never on `main` — `main` carries unrelated uncommitted website changes, so stage by explicit path only, never `git add -A`.
- Design principles that constrain the popover tasks (Apple's *Designing Fluid Interfaces*): **response** — nothing avoidable on the click path; **spatial consistency** — the popover keeps originating from the clicked Dock icon; **interruptibility** — a click during show/hide must still be honoured by the existing `PanelState` machine; **reduced motion** — when the user asks for no motion they get none, not a shorter animation.

## File map

| File | Change |
|---|---|
| `Scripts/perf/*` (new) | Measurement harness: `runloop_busy.py`, `analyze.sh`, `launch_timer.swift`, `safe_input.swift`, `make_test_config.py`, `README.md` |
| `DockTile/Managers/DockPlistWatcher.swift` | `SaveDebounce` seam (beside `Debouncer`); watcher reopens its descriptor after an atomic replace; injectable path |
| `DockTile/Views/CustomiseTileView.swift` | cancellable debounced save; pending edit flushed on disappear |
| `DockTile/Views/DockTileDetailView.swift` | cancelled debounce no longer saves; pending edit flushed on disappear |
| `DockTile/Models/ConfigurationModels.swift` | `AppItem.iconData` removed |
| `DockTile/Utilities/AppIconLoader.swift` | blob fallback removed; `TileIconRasterCache` added |
| `DockTile/App/HelperAppDelegate.swift` | config path seam (hardcoded-path bug); icon prewarm |
| `DockTile/UI/NativePopoverViews.swift` | cells render from the raster cache |
| `DockTile/UI/FloatingPanel.swift` | monitor removal on every close path; `shouldAnimate` seam; popover/anchor reuse |
| `DockTile/UI/LauncherView.swift` | `openGeneration` identity |
| `DockTile/Utilities/DeclarativeIconPipeline.swift` | `IconCompiler.compileOffMain` |
| `DockTile/Managers/HelperBundleManager.swift` | compile + codesign awaited off the main actor |
| `DockTile/Managers/DiagnosticsLog.swift` | single-line messages; trim drops orphan continuation lines |
| `DockTileTests/Unit/...` (new) | `SaveDebounceTests`, `AppItemIconDataRemovalTests`, `HelperConfigLookupTests`, `TileIconRasterCacheTests`, `FloatingPanelAnimationTests`, `IconCompilerOffMainTests`, `DiagnosticsLogTrimTests`, `DockPlistWatcherReplaceTests` |
| `.claude/rules/*.md`, spec ledger | updated in the task that changes the behaviour they describe |

---

### Task 0: Commit the measurement harness

Every later task ends with "re-measure". That is only honest if the tools are in the repo, not in a deleted scratch folder.

**Files:**
- Create: `Scripts/perf/runloop_busy.py`, `Scripts/perf/analyze.sh`, `Scripts/perf/launch_timer.swift`, `Scripts/perf/safe_input.swift`, `Scripts/perf/make_test_config.py`, `Scripts/perf/prod_fingerprint.sh`, `Scripts/perf/README.md`

**Interfaces:**
- Produces: `Scripts/perf/analyze.sh <trace-path> [min-ms]` → prints main-run-loop busy intervals; `swift Scripts/perf/launch_timer.swift <App.app>` → `first-window-on-screen=<ms>`; `swift Scripts/perf/safe_input.swift {windows|hover|drag} <pid> …`; `python3 Scripts/perf/make_test_config.py [out]` → a release-sized test config that is safe to load in the dev app; `Scripts/perf/prod_fingerprint.sh` → one line per production artefact, to be compared before and after every task.

- [ ] **Step 0: Branch, record the spec, and protect the baseline fixture**

```bash
Scripts/perf/prod_fingerprint.sh > /tmp/prod-fingerprint-baseline.txt   # after Step 4c exists
cat /tmp/prod-fingerprint-baseline.txt
git switch -c perf/2026-09-fixes
git add docs/performance-baseline-2026-09.md docs/performance-baseline-2026-09.json docs/superpowers/plans/2026-09-19-performance-fixes.md
git commit -m "docs(perf): 2026-09 performance baseline and the fix plan"
cp -p ~/Library/Preferences/com.docktile.dev.configs.json ~/docktile-dev-config-with-blobs.backup.json
md5 -q ~/docktile-dev-config-with-blobs.backup.json
```
The backup matters: the unit tests run hosted by the dev app against the live dev config, and once Task 2 lands any test that saves will rewrite that 130 MB file without its blobs — it is the only large-config fixture the baseline was measured on. Later ledger edits to the spec then land as small diffs inside each task's commit.

- [ ] **Step 1: Write `Scripts/perf/runloop_busy.py`**

```python
#!/usr/bin/env python3
"""Main-run-loop busy intervals from an xctrace `runloop-events` export.

Apple's hang definition: the busy portion of the main run loop, i.e. the time between the END of
one `waiting_for_events` period and the START of the next. xctrace XML de-duplicates values with
id/ref, so every element is resolved through an id table first.

usage: runloop_busy.py <runloop-events.xml> [min-ms]
"""
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
min_ms = float(sys.argv[2]) if len(sys.argv) > 2 else 8.0

root = ET.parse(path).getroot()
ids = {}


def resolve(el):
    ref = el.get("ref")
    if ref is not None:
        return ids[ref]
    if el.get("id") is not None:
        ids[el.get("id")] = el
    return el


events = []  # (t_ns, START|END) for the main run loop's waiting_for_events
for row in root.iter("row"):
    t = kind = phase = None
    is_main = None
    for child in row:
        el = resolve(child)
        for sub in el.iter():
            if sub.get("id") is not None:
                ids[sub.get("id")] = sub
        tag = el.tag
        if tag == "event-time" and t is None:
            t = int(el.text)
        elif tag == "short-string" and kind is None:
            kind = el.text
        elif tag == "kdebug-func" and phase is None:
            phase = el.get("fmt")
        elif tag == "boolean" and is_main is None:
            is_main = el.text == "1"
    if t is not None and kind == "waiting_for_events" and is_main:
        events.append((t, phase))

events.sort()
busy = []
last_end = None
for t, phase in events:
    if phase == "END":
        last_end = t
    elif phase == "START" and last_end is not None:
        busy.append((last_end, (t - last_end) / 1e6))
        last_end = None

print(f"main run-loop busy intervals: {len(busy)}")
for label, lo in (("> 250 ms (Apple: tools report a hang)", 250), ("> 100 ms (Apple: no longer instant)", 100),
                  ("> 50 ms", 50), ("> 16.7 ms (one 60 Hz frame)", 16.7)):
    print(f"  {label}: {sum(1 for _, d in busy if d > lo)}")
print(f"\nintervals >= {min_ms} ms, in time order:")
for start, d in busy:
    if d >= min_ms:
        print(f"  t={start / 1e9:8.3f}s  busy={d:7.1f} ms")
```

- [ ] **Step 2: Write `Scripts/perf/analyze.sh`**

```sh
#!/bin/sh
# usage: analyze.sh <path/to/file.trace> [min-ms]
# Exports the trace's runloop-events table and prints the main-run-loop busy intervals.
set -e
TRACE="$1"
OUT="${TRACE%.trace}-runloop.xml"
HERE="$(cd "$(dirname "$0")" && pwd)"
rm -f "$OUT"
xcrun xctrace export --input "$TRACE" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="runloop-events"]' --output "$OUT" >/dev/null
python3 "$HERE/runloop_busy.py" "$OUT" "${2:-40}"
```

Then: `chmod +x Scripts/perf/analyze.sh`

- [ ] **Step 3: Write `Scripts/perf/launch_timer.swift`**

```swift
// Launch an app bundle and report the time until its first normal-layer window is on screen.
// usage: swift launch_timer.swift "/path/to/App.app"
import AppKit
import CoreGraphics

let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let config = NSWorkspace.OpenConfiguration()
config.activates = true
var launchedPID: pid_t = 0
let sema = DispatchSemaphore(value: 0)
let t0 = DispatchTime.now()
NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
    if let error { FileHandle.standardError.write("launch failed: \(error)\n".data(using: .utf8)!) }
    launchedPID = app?.processIdentifier ?? 0
    sema.signal()
}
sema.wait()
guard launchedPID != 0 else { exit(1) }

func ms(_ a: DispatchTime, _ b: DispatchTime) -> Double { Double(b.uptimeNanoseconds - a.uptimeNanoseconds) / 1e6 }

var windowMs: Double = -1
let deadline = DispatchTime.now() + .seconds(30)
while DispatchTime.now() < deadline {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let hit = list.contains { w in
        guard (w[kCGWindowOwnerPID as String] as? pid_t) == launchedPID,
              (w[kCGWindowLayer as String] as? Int) == 0,
              let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
        return (b["Width"] ?? 0) > 300 && (b["Height"] ?? 0) > 300
    }
    if hit { windowMs = ms(t0, DispatchTime.now()); break }
    usleep(4000)
}
guard windowMs >= 0 else {
    print(String(format: "pid=%d  TIMEOUT: no window on screen within 30s", launchedPID))
    exit(1)
}
print(String(format: "pid=%d  first-window-on-screen=%.0f ms", launchedPID, windowMs))
```

- [ ] **Step 4: Write `Scripts/perf/safe_input.swift`**

```swift
// Guarded synthetic input for performance measurement. Every pointer event is preceded by a check
// that the topmost window under the target point is owned by the expected pid; on any mismatch the
// tool stops.
//
//   swift safe_input.swift windows <pid>
//   swift safe_input.swift hover   <pid> <seconds>
//   swift safe_input.swift drag    <pid> <x1> <y1> <x2> <y2> <seconds>
// There is deliberately no keyboard mode: the project rule is never to synthesise keystrokes.
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3, let pid = pid_t(args[2]) else { print("usage: see header"); exit(2) }
let mode = args[1]

func onScreenWindows() -> [[String: Any]] {
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
}

func bounds(_ w: [String: Any]) -> CGRect? {
    guard let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
    return CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
}

/// Topmost on-screen window containing the point must belong to `pid`. The Dock and the Window
/// Server keep full-screen transparent overlay windows above everything; those are skipped.
func pointBelongs(_ p: CGPoint, to pid: pid_t) -> Bool {
    for w in onScreenWindows() {   // front-to-back
        let owner = w[kCGWindowOwnerName as String] as? String ?? ""
        if owner == "Dock" || owner == "Window Server" { continue }
        guard let r = bounds(w), r.contains(p) else { continue }
        return (w[kCGWindowOwnerPID as String] as? pid_t) == pid
    }
    return false
}

func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}

let original = CGEvent(source: nil)?.location ?? .zero

switch mode {
case "windows":
    for w in onScreenWindows() where (w[kCGWindowOwnerPID as String] as? pid_t) == pid {
        print("layer=\(w[kCGWindowLayer as String] ?? 0) bounds=\(bounds(w) ?? .zero) name=\(w[kCGWindowName as String] ?? "")")
    }

case "hover":
    let seconds = Double(args[3]) ?? 5
    guard let r0 = onScreenWindows().first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && (bounds($0)?.width ?? 0) > 100 }).flatMap(bounds) else {
        print("no window for pid"); exit(1)
    }
    let r = r0.insetBy(dx: 24, dy: 48)
    let end = Date().addingTimeInterval(seconds)
    var t = 0.0, moves = 0
    while Date() < end {
        let p = CGPoint(x: r.midX + (r.width / 2) * CGFloat(sin(t * 1.7)), y: r.midY + (r.height / 2) * CGFloat(sin(t * 2.9)))
        guard pointBelongs(p, to: pid) else { print("ABORT: point left pid \(pid) after \(moves) moves"); break }
        post(.mouseMoved, p); moves += 1
        t += 0.05; usleep(16_000)
    }
    CGWarpMouseCursorPosition(original)
    print("hover done: \(moves) moves")

case "drag":
    guard args.count >= 8, let x1 = Double(args[3]), let y1 = Double(args[4]),
          let x2 = Double(args[5]), let y2 = Double(args[6]), let seconds = Double(args[7]) else { print("usage: see header"); exit(2) }
    let a = CGPoint(x: x1, y: y1), b = CGPoint(x: x2, y: y2)
    guard pointBelongs(a, to: pid), pointBelongs(b, to: pid) else { print("ABORT: drag endpoints are not over pid \(pid)"); exit(1) }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { print("ABORT: pid \(pid) is not frontmost"); exit(1) }
    post(.leftMouseDown, a)
    let end = Date().addingTimeInterval(seconds)
    var t = 0.0, moves = 0
    var lastGood = a
    var aborted = false
    while Date() < end {
        let f = CGFloat((sin(t) + 1) / 2)
        let p = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
        guard pointBelongs(p, to: pid) else { aborted = true; break }
        post(.leftMouseDragged, p); moves += 1
        lastGood = p
        t += 0.12; usleep(16_000)
    }
    // The button MUST be released or the session is left with a stuck mouse button — but release at
    // the last VERIFIED-good point, never at an unchecked location.
    post(.leftMouseUp, lastGood)
    CGWarpMouseCursorPosition(original)
    if aborted {
        print("ABORTED mid-drag after \(moves) events — button released at the last verified point")
        exit(1)
    }
    print("drag done: \(moves) drag events")

default:
    print("unknown mode")
}
```

- [ ] **Step 4b: Write `Scripts/perf/make_test_config.py`**

```python
#!/usr/bin/env python3
"""Write a release-sized TEST config for the dev app from a READ-ONLY copy of the production config.

Bundle IDs are STORED in the config. A raw production copy loaded by the dev app would carry
production bundle IDs; self-heal would see them as "pinned in the Dock but bundle missing" and
re-seat the real Dock entries. Rewriting them to the dev prefix makes the tiles "never pinned",
which every reconciler leaves alone.

usage: make_test_config.py [output-path]
"""
import json
import os
import re
import sys

src = os.path.expanduser("~/Library/Preferences/com.docktile.configs.json")
dst = sys.argv[1] if len(sys.argv) > 1 else "/tmp/docktile-release-sized-test-config.json"
text = open(src).read()
pattern = re.compile(r'"com\.docktile\.([0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})"')
rewritten, count = pattern.subn(r'"com.docktile.dev.\1"', text)
configs = json.loads(rewritten)
ok = count == len(configs) and all(c.get("bundleIdentifier", "").startswith("com.docktile.dev.") for c in configs)
if not ok:
    sys.exit("bundle id rewrite incomplete — do NOT load this file in the dev app")
open(dst, "w").write(rewritten)
print(f"wrote {dst}: {len(configs)} tiles, {len(rewritten)} bytes, {count} bundle ids rewritten")
```

- [ ] **Step 4c: Write `Scripts/perf/prod_fingerprint.sh`**

```sh
#!/bin/sh
# Fingerprint the PRODUCTION tiles so development can prove it did not touch them.
# Run before and after each task; the two outputs must be identical.
PROD_CONFIG="$HOME/Library/Preferences/com.docktile.configs.json"
PROD_SUPPORT="$HOME/Library/Application Support/DockTile"

echo "config     $(md5 -q "$PROD_CONFIG" 2>/dev/null || echo MISSING)  $(stat -f%z "$PROD_CONFIG" 2>/dev/null || echo 0) bytes"
for app in "$PROD_SUPPORT"/*.app; do
  [ -e "$app" ] || continue
  # mtime + signature state: a regenerate or a re-seal changes one of them.
  echo "bundle     $(basename "$app")  $(stat -f%m "$app")  $(codesign --verify "$app" >/dev/null 2>&1 && echo signed || echo UNSIGNED)"
done
# Dock entries for production tiles: id, GUID, tooltip label and on-disk path. All are documented
# invariants (architecture.md: same-name disambiguation, `dockFileLabel`, `refreshDockEntry`), and
# GUID is what changes when an entry is re-seated without the bundle changing.
# Read the plist FILE, not `defaults read`: reading another app's cfprefsd domain can serve a stale
# cache (architecture.md, "Reliable reads"), and a consistently stale read would report "unchanged"
# after a real mutation — a false negative in the one check whose whole purpose is catching that.
python3 -c '
import plistlib, os
p = os.path.expanduser("~/Library/Preferences/com.apple.dock.plist")
try:
    with open(p, "rb") as f:
        d = plistlib.load(f)
except Exception as exc:
    print("dock       UNREADABLE: " + str(exc))
    raise SystemExit(0)
for e in d.get("persistent-apps", []):
    td = e.get("tile-data", {})
    bid = td.get("bundle-identifier", "")
    if bid.startswith("com.docktile.") and not bid.startswith("com.docktile.dev."):
        url = td.get("file-data", {}).get("_CFURLString", "")
        print("dock       " + bid + "  GUID=" + str(e.get("GUID")) + "  label=" + str(td.get("file-label")) + "  url=" + url)
'
echo "helpers    $(pgrep -f 'Application Support/DockTile/' | tr '\n' ' ')"
```

Then: `chmod +x Scripts/perf/prod_fingerprint.sh`

- [ ] **Step 5: Write `Scripts/perf/README.md`**

```markdown
# Performance harness

Tools behind `docs/performance-baseline-2026-09.md`. Record with every number: machine, macOS,
build (Debug / optimised / Release helper), config size, power source, thermal state.

## Main-thread blocks for any flow
    xcrun xctrace record --template 'Time Profiler' --attach <pid> --time-limit 60s --output /tmp/x.trace
    # …perform the flow…
    Scripts/perf/analyze.sh /tmp/x.trace 40

## Popover open (helper)
    open -b <helper bundle id>        # toggles: a second call closes it
First open after ≥10 min idle is the number that matters; opens seconds apart are ~5–10× faster.

## Memory abandoned per open
    footprint <helper pid> | grep -E "Footprint:|IOSurface"   # before
    # five open/close cycles
    footprint <helper pid> | grep -E "Footprint:|IOSurface"   # after, and again 10 min later

## Launch
    swift Scripts/perf/launch_timer.swift "<App.app>"          # three runs, discard the first

## Pointer / key input (guarded)
    swift Scripts/perf/safe_input.swift hover <pid> 6
    swift Scripts/perf/safe_input.swift drag  <pid> x1 y1 x2 y2 4

## Release-grade main-app numbers without touching production data
Build the Debug configuration optimised into its own folder:
    xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug \
      -derivedDataPath /tmp/dd-opt SWIFT_OPTIMIZATION_LEVEL=-O SWIFT_COMPILATION_MODE=wholemodule \
      ENABLE_TESTABILITY=NO ENABLE_DEBUG_DYLIB=NO build
Delete `/tmp/dd-opt` afterwards. NEVER load a raw copy of the production config in the dev app —
see `make_test_config.py` for why. To measure on release-sized data, with the dev app QUIT:
    python3 Scripts/perf/make_test_config.py /tmp/rel-test.json
    cp -p ~/Library/Preferences/com.docktile.dev.configs.json /tmp/dev-config.swap-backup.json
    md5 -q ~/Library/Preferences/com.docktile.dev.configs.json      # note it
    cp /tmp/rel-test.json ~/Library/Preferences/com.docktile.dev.configs.json
    # launch, confirm the log says "visible but never pinned — not hiding" for every tile, measure, quit
    cp -p /tmp/dev-config.swap-backup.json ~/Library/Preferences/com.docktile.dev.configs.json
    md5 -q ~/Library/Preferences/com.docktile.dev.configs.json      # must match the noted value

## Production safety
`prod_fingerprint.sh` prints the production config's checksum, each production helper bundle's
mtime and signature state, the production tiles' Dock entries, and the running production helper
pids. Run it at the start and end of every task; identical output is the proof that development
did not touch live tiles. It changing means something regenerated, re-sealed or re-seated a real
tile — stop and investigate before continuing.

## Rules
Never send raw keystrokes (the harness has no keyboard mode on purpose). Drive the app with Accessibility `set value` (focus the field through
Accessibility first or SwiftUI ignores it), `click`, `set selected`, single-`to` form only.
```

- [ ] **Step 6: Verify the harness runs**

Run: `python3 Scripts/perf/runloop_busy.py /dev/null 2>&1 | head -2`
Expected: a Python `ParseError` (proves the script loads; a real trace is exercised in Task 1).
Run: `swift Scripts/perf/safe_input.swift windows $$`
Expected: exits 0 and prints nothing (the shell owns no windows).

- [ ] **Step 7: Commit**

```bash
git add Scripts/perf
git commit -m "chore(perf): commit the measurement harness used for the 2026-09 baseline"
```

---

### Task 1: Debounced saves that actually debounce (Customise + Tile Detail)

**Root cause (established):** `CustomiseTileView.swift:56-71` starts a new `Task` per change and never cancels the previous one, so a colour drag queues one full-config save per tick (measured: main thread saturated for a 4 s drag, 85–135 ms blocks back to back, worst 288 ms). `DockTileDetailView.swift:195-212` has the sibling defect by code reading: its `.task(id:)` IS cancelled on each edit, but `try? await Task.sleep` swallows the cancellation and execution falls through to the save, so a cancelled debounce saves immediately instead of not at all.

**Pattern to follow:** the `.task(id: saveGeneration)` cancel-restart already in `DockTileDetailView`, plus an explicit cancellation check.

**The trap in the obvious fix:** `.task(id:)` is cancelled for two different reasons — a newer edit arrived, or **the view is going away** (tile switch, Back, opening Customise, a Settings pane). Today both views still save in the second case (Tile Detail by falling through the swallowed cancellation, Customise because its unstructured `Task` outlives the view). Simply skipping the save on cancellation would lose an edit made within 300 ms of leaving. So both views track a pending edit and flush it in `onDisappear`. `updateConfiguration` is a logged no-op for a tile that no longer exists, so a flush after Delete is harmless; the delete path clears the flag first to keep the log clean.

**What the unit test does and does not guard:** `SaveDebounceTests` guards the seam only. The two call sites are guarded by the Step 8 measurement and the Step 8b flush check — say so rather than pretending the test covers them.

**Files:**
- Modify: `DockTile/Managers/DockPlistWatcher.swift` (append after the `Debouncer` class, end of file)
- Modify: `DockTile/Views/CustomiseTileView.swift:18-23` (state), `:56-71` (onChange)
- Modify: `DockTile/Views/DockTileDetailView.swift:195-199`
- Test: `DockTileTests/Unit/Managers/SaveDebounceTests.swift` (new)

**Interfaces:**
- Produces: `enum SaveDebounce { static func waitedFullInterval(nanoseconds: UInt64) async -> Bool }` — `true` when the full interval elapsed, `false` when the task was cancelled while waiting.

- [ ] **Step 0: Capture the "before" under the conditions you will re-measure under**

Pick ONE build + config pair and use it for both before and after — the spec's 288 ms figure was the optimised build on the release-sized test config, so use that pair (`Scripts/perf/README.md`). Run the Step 8 procedure now, on the unmodified code, and note: count of intervals ≥ 50 ms during the drag, and the worst one.

- [ ] **Step 1: Write the failing test**

`DockTileTests/Unit/Managers/SaveDebounceTests.swift`:

```swift
import Testing
@testable import Dock_Tile

/// Guards the rule behind every debounced config save: a debounce that was CANCELLED must not
/// save. The regression this kills: `try? await Task.sleep` swallowed the cancellation, so each
/// superseded edit saved the whole config immediately (one full save per colour-drag tick).
/// Failing value: a cancelled wait returning `true`.
@Suite("Save debounce")
struct SaveDebounceTests {

    @Test("An uninterrupted wait reports that the full interval elapsed")
    func uninterruptedWaitCompletes() async {
        let completed = await SaveDebounce.waitedFullInterval(nanoseconds: 1_000_000)
        #expect(completed == true)
    }

    @Test("A wait cancelled part-way reports false so the caller skips its save")
    func cancelledWaitReportsFalse() async {
        let task = Task { await SaveDebounce.waitedFullInterval(nanoseconds: 5_000_000_000) }
        task.cancel()
        let completed = await task.value
        #expect(completed == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/SaveDebounceTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: build FAILS with `cannot find 'SaveDebounce' in scope`.

- [ ] **Step 3: Add the seam**

Append to the end of `DockTile/Managers/DockPlistWatcher.swift`:

```swift

// MARK: - SaveDebounce

/// The wait half of a `.task(id:)` debounce. `try? await Task.sleep` cannot be used for this: it
/// swallows `CancellationError`, so a debounce superseded by a newer edit falls straight through to
/// its save — every keystroke, stepper tick and colour-drag tick then writes the whole config.
enum SaveDebounce {
    /// Sleeps for `nanoseconds`. Returns `false` when the task was cancelled while waiting — the
    /// caller must NOT save from the debounce in that case: either a newer edit owns the save, or
    /// the view is going away and its `onDisappear` flush owns it.
    static func waitedFullInterval(nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return true
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: the Step 2 command.
Expected: `Test Suite 'SaveDebounceTests' passed`, 2 tests.

- [ ] **Step 5: Fix Tile Detail**

In `DockTile/Views/DockTileDetailView.swift`:

Add a state property after `@State private var saveGeneration: Int = 0`:
```swift
    /// True from an edit until it is persisted — lets `onDisappear` flush an edit whose debounce
    /// was cancelled because the view is going away.
    @State private var hasPendingSave = false
```

In `.onChange(of: editedConfig)`, add `hasPendingSave = true` as the FIRST statement of the closure — outside the existing `DispatchQueue.main.async { … }` block, so a view torn down in the same run-loop turn as the edit still sees the flag set. (Assigning `@State` from `onChange` is what the deferred block avoids for *published* changes; this flag is local view state and is safe.)

Replace the whole `.task(id: saveGeneration) { … }` modifier (the block that sleeps 300 ms, preserves the stored visibility and calls `updateConfiguration`) with:

```swift
        .task(id: saveGeneration) {
            guard hasAppearedOnce, saveGeneration > 0 else { return }
            // A superseded debounce must not save — see SaveDebounce. A view that is going away
            // flushes through onDisappear instead.
            guard await SaveDebounce.waitedFullInterval(nanoseconds: 300_000_000) else { return }
            persistEdits()
        }
        .onDisappear {
            // Leaving within the debounce window (tile switch, Customise, a Settings pane) cancels
            // the task above; without this flush the last edit would be lost.
            if hasPendingSave { persistEdits() }
        }
```

Add this method in the `// MARK: - Actions` section:

```swift
    /// Persist the editor's content edits (name, layout, icon, app list…). Visibility is owned
    /// EXCLUSIVELY by performDockAction, gated on the Dock op actually completing — so this must
    /// NOT commit the Show Tile toggle's transient isVisibleInDock, or a hide whose un-pin never
    /// runs leaves a permanent "hidden in config but still pinned" desync. Preserve the stored value.
    private func persistEdits() {
        var toSave = editedConfig
        if let stored = configManager.configuration(for: editedConfig.id) {
            toSave.isVisibleInDock = stored.isVisibleInDock
            toSave.lastDockIndex = stored.lastDockIndex
        }
        configManager.updateConfiguration(toSave)
        hasPendingSave = false
    }
```
(The comment is the one currently inside the task body, moved with the code it explains — not new prose.)

In `deleteTile()`, add `hasPendingSave = false` as the first statement, so the disappear that follows a delete does not log a no-op save for a tile that is gone.

- [ ] **Step 6: Fix Customise**

In `DockTile/Views/CustomiseTileView.swift`, add one state property after `@State private var showWeightInfo: Bool = false`:

```swift
    /// Monotonic edit counter — the `.task(id:)` identity for the debounced save (same pattern as
    /// DockTileDetailView), so each edit CANCELS the previous pending save.
    @State private var saveGeneration: Int = 0
```

Replace the whole `.onChange(of: editedConfig) { oldValue, newValue in … }` modifier (lines 56-71) with:

```swift
        .onChange(of: editedConfig) { oldValue, newValue in
            // Mark as edited immediately (enables + button)
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                configManager.markSelectedConfigAsEdited()
            }

            // Only save if the config actually changed (prevent infinite loop)
            if oldValue.id == newValue.id {
                saveGeneration += 1
            }
        }
        .task(id: saveGeneration) {
            guard saveGeneration > 0 else { return }
            guard await SaveDebounce.waitedFullInterval(nanoseconds: 300_000_000) else { return }
            configManager.updateConfiguration(editedConfig)
            hasPendingSave = false
        }
        .onDisappear {
            // Back within the debounce window cancels the task above; flush so the edit survives.
            if hasPendingSave {
                configManager.updateConfiguration(editedConfig)
                hasPendingSave = false
            }
        }
```
Add the matching state beside `saveGeneration`: `@State private var hasPendingSave = false`, and set `hasPendingSave = true` on the line before `saveGeneration += 1`.

Note the deliberate asymmetry with Tile Detail: Customise writes `editedConfig` wholesale, including the visibility fields as it loaded them, exactly as its existing debounced save already does. Customise has no Show Tile control, so it cannot have staged a visibility change — this task does not alter that behaviour, it only adds a second moment (teardown) at which the same write happens. If the visibility desync described in architecture.md ever reappears from this path, make Customise use Tile Detail's `persistEdits` shape.

- [ ] **Step 7: Run the full unit suite**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Re-measure the colour drag**

Rebuild signed (`xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build`), `codesign --verify` the product, launch it, open Customise on a dev tile, click the custom-colour button, then:

```bash
xcrun xctrace record --template 'Time Profiler' --attach <main pid> --time-limit 45s --output /tmp/colordrag.trace &
swift Scripts/perf/safe_input.swift windows <main pid>      # find the "Colors" panel bounds
swift Scripts/perf/safe_input.swift drag <main pid> <x1> <y> <x2> <y> 4
Scripts/perf/analyze.sh /tmp/colordrag.trace 30
```

Expected: during the 4 s drag no interval ≥ 50 ms caused by saving; exactly one save-sized block ~0.3 s after the drag ends. Compare against YOUR Step 0 numbers (same build, same config), not against the spec's.

- [ ] **Step 8b: Verify an edit made just before leaving is not lost**

With the dev app running and a tile selected, focus the name field and change it through Accessibility, then select another sidebar row in the very next command (well inside 300 ms of the edit is not required — the point is that the view disappears before the debounce fires or immediately after):

```bash
osascript -e 'tell application "System Events" to tell (first process whose unix id is <pid>) to set focused of text field 1 of scroll area 1 of group 2 of splitter group 1 of group 1 of window 1 to true'
osascript -e 'tell application "System Events" to tell (first process whose unix id is <pid>) to set value of text field 1 of scroll area 1 of group 2 of splitter group 1 of group 1 of window 1 to "Flush Probe"' -e 'tell application "System Events" to tell (first process whose unix id is <pid>) to set selected of row 3 of outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1 to true'
python3 -c "import json,os; print([c['name'] for c in json.load(open(os.path.expanduser('~/Library/Preferences/com.docktile.dev.configs.json')))])"
```
Expected: the list contains `Flush Probe`. Restore the original name the same way and confirm it saved.

- [ ] **Step 9: Ledger + commit**

Add to the spec's Attempt ledger: `| Cancel superseded debounced saves (Customise + Tile Detail) | 28 blocks ≥50 ms / worst 288 ms → <result> | kept/reverted | <why> |`

```bash
git add DockTile/Managers/DockPlistWatcher.swift DockTile/Views/CustomiseTileView.swift DockTile/Views/DockTileDetailView.swift DockTileTests/Unit/Managers/SaveDebounceTests.swift docs/performance-baseline-2026-09.md
git commit -m "fix(editor): a superseded debounce no longer saves — colour drag stops queuing full-config writes"
```

---

### Task 2: Stop persisting app icon blobs in the config

**Root cause (established):** `AppItem.from(appURL:)` stores each app's entire `.icns` in `iconData` (`ConfigurationModels.swift:500-505`), base64 in JSON. Measured consequences: release config 10.4 MB / dev 130.8 MB; ~97 ms save per edit at 10 MB (growing with every app); 370 MB main-app footprint at launch and a 948 MB peak on the big config; ~300 MB Release helper launch peak; every copy of `[DockTileConfiguration]` and every synthesized `==` walks the blobs.

**Why deletion is safe:** the blob has no reachable display path. Popover cells and the editor render a missing app as the `questionmark.app.dashed` placeholder *before* consulting the loader (`NativePopoverViews.swift:730-734`, `DockTileDetailView.swift:784-788`), and the architecture rule says a cached icon must never be shown for a missing app. The only reader is the last-resort branch in `AppIconLoader.icon(for:)`, reached only when Launch Services, `lastKnownPath` and the common-path probe all fail — exactly the "missing" case the UI already intercepts.

**Compatibility, including the update window (critical):** `Codable` ignores unknown keys, so configs written by older versions (with `iconData`) still load; older app versions reading a new config see an absent optional. No schema version bump. Existing configs shrink on their first save after upgrade.

The state that needs thinking about is the minutes *during* an update, when a new main app has already rewritten the config but a tile's helper is still the old binary (hidden tiles stay old until next shown; a failed regeneration retries next launch). An old helper reading a blob-less config calls the old `AppIconLoader.icon(for:)`: Launch Services resolves every installed app normally, and an app that resolves nowhere now returns `nil` instead of a stale blob — which the old popover already draws as the `questionmark.app.dashed` placeholder, because it checks `AppInstallChecker` *before* the loader. So the worst case in the mixed window is that an uninstalled app shows the placeholder slightly sooner, which is the behaviour the architecture rule asks for anyway. Verified in Task 11 Step 4, not assumed.

**Decided (Karthik, 2026-09-19): remove the field outright**, no sidecar. If a stored fallback icon is ever wanted it should be a sidecar file keyed by bundle ID, never the config.

**Files:**
- Modify: `DockTile/Models/ConfigurationModels.swift:433-505`
- Modify: `DockTile/Utilities/AppIconLoader.swift:45-49` and the doc comment at `:18`
- Modify: `DockTileTests/Unit/Models/ConfigurationModelsTests.swift:721,744,758`
- Test: `DockTileTests/Unit/Models/AppItemIconDataRemovalTests.swift` (new)
- Modify: `.claude/rules/architecture.md` (Missing App Detection section)

**Interfaces:**
- Produces: `AppItem` without `iconData`; `AppItem.init(id:bundleIdentifier:name:isFolder:folderPath:lastKnownPath:)`.

- [ ] **Step 0: Confirm the fixture backup exists and capture the "before"**

`ls -la ~/docktile-dev-config-with-blobs.backup.json` must show the ~130 MB file from Task 0 Step 0 **before any test is run in this task** (from Step 6 on, a hosted test that saves will strip the blobs from the live dev config). Then, on the unmodified code and the Debug build with the dev config, record: config size, save block for one Accessibility edit, main-app footprint at launch, one helper's peak footprint after relaunch. These are the "before" for Step 8.

- [ ] **Step 1: Write the failing tests**

`DockTileTests/Unit/Models/AppItemIconDataRemovalTests.swift`:

```swift
import Foundation
import Testing
@testable import Dock_Tile

/// `iconData` used to embed every app's whole `.icns` in the config JSON (release config 10 MB,
/// dev 130 MB), making every save, copy and equality check scale with icon bytes.
/// Failing values: an encoded item that still contains an "iconData" key; a legacy config that no
/// longer decodes.
@Suite("AppItem no longer persists icon blobs")
struct AppItemIconDataRemovalTests {

    private let legacyJSON = """
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "bundleIdentifier": "com.example.app",
      "name": "Example",
      "iconData": "aGVsbG8gaWNvbg==",
      "isFolder": false,
      "lastKnownPath": "/Applications/Example.app"
    }
    """

    @Test("A legacy item that carries iconData still decodes, with every other field intact")
    func legacyItemDecodes() throws {
        let item = try JSONDecoder().decode(AppItem.self, from: Data(legacyJSON.utf8))
        #expect(item.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(item.bundleIdentifier == "com.example.app")
        #expect(item.name == "Example")
        #expect(item.isFolder == false)
        #expect(item.lastKnownPath == "/Applications/Example.app")
    }

    @Test("Re-encoding a legacy item drops the blob")
    func reencodingDropsTheBlob() throws {
        let item = try JSONDecoder().decode(AppItem.self, from: Data(legacyJSON.utf8))
        let encoded = try #require(String(data: JSONEncoder().encode(item), encoding: .utf8))
        #expect(encoded.contains("iconData") == false)
        #expect(encoded.contains("aGVsbG8gaWNvbg==") == false)
    }

    @Test("An item built from a real app bundle encodes to well under 1 KB")
    func newItemIsSmall() throws {
        let item = try #require(AppItem.from(appURL: URL(fileURLWithPath: "/System/Applications/Calculator.app")))
        let bytes = try JSONEncoder().encode(item).count
        #expect(bytes < 1024)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/AppItemIconDataRemovalTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: `reencodingDropsTheBlob` and `newItemIsSmall` FAIL (the encoded item contains `iconData`; Calculator's `AppIcon.icns` is ~50 KB, about 67 KB once base64-encoded, so the item is far over the 1 KB assertion). `legacyItemDecodes` passes — it is the compatibility guard and must keep passing.

- [ ] **Step 3: Remove the field from the model**

In `DockTile/Models/ConfigurationModels.swift`:

Delete the stored property line
```swift
    var iconData: Data?  // Serialized NSImage as PNG/TIFF data
```
Delete the initialiser parameter `iconData: Data? = nil,` and its assignment `self.iconData = iconData`.
Delete the decoder line
```swift
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
```
Change the coding keys line `case id, bundleIdentifier, name, iconData` to
```swift
        case id, bundleIdentifier, name
```
In `static func from(appURL:)` delete the whole `// Extract icon data` block (`var iconData: Data?` through the closing brace of the `if let iconFile …` statement) and delete the `iconData: iconData,` argument from the `AppItem(` call.
In `static func from(folderURL:)` (just below) delete these three lines
```swift
        // Get folder icon from system
        let icon = NSWorkspace.shared.icon(forFile: folderPath)
        let iconData = icon.tiffRepresentation
```
and the `iconData: iconData,` argument in its `AppItem(` call. (Folders stored a whole TIFF of the system folder icon per item.)

- [ ] **Step 4: Remove the only reader**

In `DockTile/Utilities/AppIconLoader.swift` delete

```swift
        // Fallback to stored icon data
        if let iconData = item.iconData,
           let nsImage = NSImage(data: iconData) {
            return nsImage
        }

```
and change the doc line `/// - Falls back to common paths, then stored icon data.` to
```swift
    /// - Falls back to the last-known path, then common paths. There is no stored-icon fallback:
    ///   an app that resolves nowhere is "missing" and the UI draws a placeholder instead.
```
Leave the comment at `:32` alone except replacing `the stale cached \`iconData\`` with `a placeholder`. Also update the `AppInstallChecker` comment at `:212`, which will otherwise reference a field that no longer exists — replace

```swift
    /// A cached `iconData` does NOT count as an installation signal — it's DockTile's own snapshot,
```
with
```swift
    /// DockTile's own cached snapshot of an icon would NOT count as an installation signal (and no
    /// such snapshot is stored any more — see AppItem) — only the live system does,
```
keeping whatever the sentence continues into on the following lines.

- [ ] **Step 5: Fix the three existing assertions**

In `DockTileTests/Unit/Models/ConfigurationModelsTests.swift`: delete the line `#expect(item.iconData == nil)` (≈721); delete the `iconData: "test".data(using: .utf8),` argument (≈744); delete `#expect(decoded.iconData == original.iconData)` (≈758).

- [ ] **Step 6: Build and run the whole suite**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`. If the build reports another `iconData` reference, remove that reference the same way (the pre-plan grep found none outside the files above).

- [ ] **Step 7: Update the architecture rule**

In `.claude/rules/architecture.md`, section *Missing App Detection*, replace the sentence beginning "A cached `iconData` is **not** an install signal" through the end of that parenthetical with:

```markdown
  Tiles no longer store an icon snapshot at all (`AppItem.iconData` was removed 2026-09: it put
  every app's whole `.icns` into the config — 10 MB release configs, ~100 ms saves — for a fallback
  the missing-app placeholder already superseded). Old configs carrying the key still load; the
  blob is dropped on their next save.
```

- [ ] **Step 8: Re-measure**

Rebuild signed, launch, make one edit through Accessibility (same build and config as Step 0), then:

```bash
ls -la ~/Library/Preferences/com.docktile.dev.configs.json      # expect KBs, was 130,754,674 bytes
swift Scripts/perf/launch_timer.swift "<dev App.app>"            # three runs
footprint <main pid> | grep -E "Footprint:|MALLOC_LARGE|phys_footprint"
# save block: trace + one AX edit, as in Task 1 Step 8
```
Expected, against your Step 0 numbers: config from ~130 MB to tens of KB; the save block gone from the trace at a 25 ms threshold; launch footprint and helper peak each down by at least the size of the old config. Re-select a tile and record the interval for Task 8.

- [ ] **Step 9: Ledger + commit**

```bash
git add DockTile/Models/ConfigurationModels.swift DockTile/Utilities/AppIconLoader.swift DockTileTests/Unit/Models .claude/rules/architecture.md docs/performance-baseline-2026-09.md
git commit -m "perf(config): stop persisting app icon blobs — configs drop from MBs to KBs"
```

---

### Task 3: Helpers read their own build's config (hardcoded release path)

**Root cause (established):** `HelperAppDelegate.readShowInAppSwitcherFromDisk` (`:489-519`) hardcodes `"com.docktile.configs.json"`. A dev helper therefore decodes the *release* file, never finds its `com.docktile.dev.<UUID>` id, and always runs in Ghost mode whatever "Show in App Switcher" says. (After Task 2 the double decode it performs is a few KB and no longer worth removing — that part of the earlier finding is dropped, YAGNI.)

**Files:**
- Modify: `DockTile/App/HelperAppDelegate.swift:487-519`
- Test: `DockTileTests/Unit/App/HelperConfigLookupTests.swift` (new)

**Interfaces:**
- Produces: `nonisolated static func HelperAppDelegate.showInAppSwitcher(inConfigAt url: URL, bundleId: String) -> Bool`

- [ ] **Step 1: Write the failing test**

`DockTileTests/Unit/App/HelperConfigLookupTests.swift`:

```swift
import Foundation
import Testing
@testable import Dock_Tile

/// The helper decides Ghost vs App mode before ConfigurationManager exists, by reading the config
/// file itself. It used to hardcode the RELEASE filename, so a dev helper read the wrong file and
/// was always Ghost. Failing value: `true` expected, `false` returned, for a tile present in the
/// file that was passed in.
@Suite("Helper config lookup")
struct HelperConfigLookupTests {

    private func writeConfig(showInAppSwitcher: Bool, bundleId: String) throws -> URL {
        var config = DockTileConfiguration(name: "Probe")
        config.bundleIdentifier = bundleId
        config.showInAppSwitcher = showInAppSwitcher
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("helper-lookup-\(UUID().uuidString).json")
        try encoder.encode([config]).write(to: url)
        return url
    }

    @Test("Reads the flag for the matching bundle id from the file it is given")
    func readsFlagFromGivenFile() throws {
        let url = try writeConfig(showInAppSwitcher: true, bundleId: "com.docktile.dev.PROBE")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: url, bundleId: "com.docktile.dev.PROBE") == true)
    }

    @Test("An unknown bundle id or a missing file defaults to Ghost mode")
    func defaultsToGhost() throws {
        let url = try writeConfig(showInAppSwitcher: true, bundleId: "com.docktile.dev.PROBE")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: url, bundleId: "com.docktile.dev.OTHER") == false)
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).json")
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: missing, bundleId: "com.docktile.dev.PROBE") == false)
    }

    @Test("An unreadable or wrongly-shaped config file defaults to Ghost mode")
    func undecodableFileDefaultsToGhost() throws {
        let dir = FileManager.default.temporaryDirectory

        // Not JSON at all.
        let garbage = dir.appendingPathComponent("helper-lookup-garbage-\(UUID().uuidString).json")
        try Data("{ this is not valid JSON".utf8).write(to: garbage)
        defer { try? FileManager.default.removeItem(at: garbage) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: garbage, bundleId: "com.docktile.dev.PROBE") == false)

        // Valid JSON, wrong shape — the likelier real regression, since a schema change can
        // produce this while the file still parses.
        let wrongShape = dir.appendingPathComponent("helper-lookup-shape-\(UUID().uuidString).json")
        try Data("{\"configurations\": []}".utf8).write(to: wrongShape)
        defer { try? FileManager.default.removeItem(at: wrongShape) }
        #expect(HelperAppDelegate.showInAppSwitcher(inConfigAt: wrongShape, bundleId: "com.docktile.dev.PROBE") == false)
    }
}
```

If `DockTileConfiguration(name:)` is not the available initialiser, use the one `ConfigurationModelsTests` uses to build a config — the assertions do not change.

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/HelperConfigLookupTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: build FAILS — `type 'HelperAppDelegate' has no member 'showInAppSwitcher'`.

- [ ] **Step 3: Extract the seam and use the environment's path**

In `DockTile/App/HelperAppDelegate.swift` replace the whole `readShowInAppSwitcherFromDisk()` function with:

```swift
    /// Read showInAppSwitcher directly from disk (for early initialization)
    /// This is used before ConfigurationManager is created
    private func readShowInAppSwitcherFromDisk() -> Bool {
        // `AppEnvironment.preferencesURL`, never a literal filename: a hardcoded release name made
        // every DEV helper read the wrong file and fall back to Ghost mode.
        Self.showInAppSwitcher(inConfigAt: AppEnvironment.preferencesURL, bundleId: currentBundleId)
    }

    /// Pure lookup seam (guarded by HelperConfigLookupTests). Missing file, undecodable file or an
    /// unknown bundle id all mean Ghost mode.
    nonisolated static func showInAppSwitcher(inConfigAt url: URL, bundleId: String) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let configs = try? decoder.decode([DockTileConfiguration].self, from: data) else { return false }
        return configs.first { $0.bundleIdentifier == bundleId }?.showInAppSwitcher ?? false
    }
```

- [ ] **Step 4: Run to verify it passes, then the full suite**

Expected: `HelperConfigLookupTests` 2/2 pass; full suite `** TEST SUCCEEDED **`.

- [ ] **Step 5: Verify on a real dev helper**

Rebuild signed. In the dev app turn **Show in App Switcher** on for a dev tile and press Update. Expected: the helper now appears in Cmd-Tab (before this fix it never did in dev). Turn it back off and Update.

- [ ] **Step 6: Commit**

```bash
git add DockTile/App/HelperAppDelegate.swift DockTileTests/Unit/App/HelperConfigLookupTests.swift
git commit -m "fix(helper): read the running build's config path — dev helpers were always Ghost"
```

---

### Task 4: Rasterised icon cache in the popover (first open after idle)

**Root cause (established by stack):** on the 102-app tile, 354 of 400 main-thread samples of an open sit in `NSImage CGImageForProposedRect → -[ISConcreteIcon generateImageWithDescriptor:] → xpc_connection_send_message_with_reply_sync`: SwiftUI's `ImageLayer` asks each IconServices-backed `NSImage` for a bitmap and the proxy answers with a **synchronous XPC render**, ~3.5 ms per icon. Opens seconds apart are 30–60 ms because `iconservicesagent` still has the renders cached; after minutes of idle it has evicted them and the helper kept nothing (every `NSImage` dies with the popover). Measured first-open-after-idle: 201 ms (Release, 10 apps), 451–522 ms (Debug, 102 apps), reproduced three times.

**Hypothesis:** if the helper holds the rasterised `CGImage`s itself and hands SwiftUI plain bitmaps, no XPC happens at render time, so an idle open costs what a warm one costs. **The measurement in Step 9 is the test of the hypothesis** — if the `_ISRetryRequest` frames are still present, stop and return to the stack; do not add more fixes.

**Design constraints:** everything stays on the main actor (no claim is made about `NSWorkspace`/`NSImage` thread-safety); the cost moves *ahead of the click* by prewarming one icon per run-loop turn at helper launch. A cache miss rasterises synchronously exactly as today, so nothing gets slower. Keys include pixel size, an appearance token (a rasterised bitmap bakes in Light/Dark and the Tahoe icon style; the popover already re-keys cells on those) and the app bundle's modification time (an updated app gets a fresh icon).

**Files:**
- Modify: `DockTile/Utilities/AppIconLoader.swift` (inside `enum AppIconLoader`, and after its closing brace before `// MARK: - App Install Checker`)
- Modify: `DockTile/UI/NativePopoverViews.swift:598-612` (StackAppItem state), `:645-650`, `:726-743`, and the list row's equivalents near `:975`, `:992`, `:1047`
- Modify: `DockTile/App/HelperAppDelegate.swift` (`applicationDidFinishLaunching`, after the `SpinWatchdog.shared.start()` line)
- Test: `DockTileTests/Unit/Utilities/TileIconRasterCacheTests.swift` (new)
- Modify: `.claude/rules/icon-system.md` (App Icon Loading section)

**Interfaces:**
- Produces:
  - `@MainActor final class TileIconRasterCache` with `static let shared`, `init(rasterise: @escaping (AppItem, Int) -> CGImage?)`, `func image(for: AppItem, pointSize: CGFloat, scale: CGFloat, appearanceToken: String, contentStamp: TimeInterval) -> CGImage?`, `private(set) var rasteriseCount: Int`
  - `nonisolated static func TileIconRasterCache.pixelSize(pointSize: CGFloat, scale: CGFloat) -> Int`
  - `nonisolated static func TileIconRasterCache.appearanceToken(style: IconStyle, isDark: Bool) -> String`
  - `nonisolated static func AppIconLoader.modificationStamp(atPath: String?) -> TimeInterval`
  - `nonisolated static func TileIconRasterCache.contentStamp(for: AppItem, resolvedPath: String?) -> TimeInterval` — the ONE place the stamp is derived, used by cells and by prewarm, so a prewarmed entry can never miss for a key-derivation reason.
  - `func prewarm(items: [AppItem], pointSize: CGFloat, scales: [CGFloat], appearanceToken: String) async`

**Stated costs and assumptions:** the cache has no eviction. Worst case is ~8 MB (102 icons × 144 px² × 4 bytes at the Large tier on a 2× display), per process that shows the tile; the main app's editor canvas shares the same type and pays the same for the tiles it displays. That is accepted against the ~2 MB *per open* Task 6 removes. Prewarm covers every connected display's backing scale, so a mixed-DPI setup still hits. It is an assumption — checked in Step 9b — that `cgImage(forProposedRect:)` under the app's effective appearance reproduces the Tahoe icon-style treatment SwiftUI got from the `NSImage`.

- [ ] **Step 1: Write the failing tests**

`DockTileTests/Unit/Utilities/TileIconRasterCacheTests.swift`:

```swift
import AppKit
import Testing
@testable import Dock_Tile

/// Guards the popover's icon cache. The regression it exists to prevent: every popover open
/// re-asked IconServices for every icon over synchronous XPC (~3.5 ms each, main thread).
/// Failing values: a second lookup that rasterises again; a bitmap served for the wrong
/// appearance, size or app version.
@MainActor
@Suite("Tile icon raster cache")
struct TileIconRasterCacheTests {

    private func onePixel() -> CGImage {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    private let app = AppItem(bundleIdentifier: "com.example.one", name: "One")

    @Test("A second lookup for the same key does not rasterise again")
    func secondLookupHits() {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        #expect(cache.rasteriseCount == 1)
    }

    @Test("A different pixel size, app version or item is a miss")
    func differentKeysMiss() {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 72, scale: 2, appearanceToken: "t", contentStamp: 100)   // size
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 200)   // app updated
        let other = AppItem(bundleIdentifier: "com.example.two", name: "Two")
        _ = cache.image(for: other, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 100) // item
        #expect(cache.rasteriseCount == 4)
    }

    @Test("An appearance change empties the cache, so nothing is served for the old look")
    func appearanceChangeClears() {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "dark-dark", contentStamp: 100)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "default-light", contentStamp: 100)
        #expect(cache.rasteriseCount == 3)
    }

    @Test("A failed rasterisation is not cached")
    func failuresAreRetried() {
        let cache = TileIconRasterCache { _, _ in nil }
        #expect(cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 1) == nil)
        #expect(cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: 1) == nil)
        #expect(cache.rasteriseCount == 2)
    }

    @Test("Prewarm fills the cache so the later lookup is a hit")
    func prewarmFills() async {
        let cache = TileIconRasterCache { _, _ in self.onePixel() }
        let items = [app, AppItem(bundleIdentifier: "com.example.two", name: "Two")]
        await cache.prewarm(items: items, pointSize: 56, scales: [1, 2], appearanceToken: "t")
        #expect(cache.rasteriseCount == 4)   // two items × two display scales
        // The cell derives its stamp through the SAME function prewarm used.
        let stamp = TileIconRasterCache.contentStamp(for: app, resolvedPath: AppInstallChecker.resolve(app).resolvedPath)
        _ = cache.image(for: app, pointSize: 56, scale: 2, appearanceToken: "t", contentStamp: stamp)
        _ = cache.image(for: app, pointSize: 56, scale: 1, appearanceToken: "t", contentStamp: stamp)
        #expect(cache.rasteriseCount == 4)
    }

    @Test("A folder stamps from its folder path, an app from its resolved path")
    func contentStampSources() {
        let folder = AppItem(bundleIdentifier: "folder.1", name: "Tmp", isFolder: true, folderPath: NSTemporaryDirectory())
        #expect(TileIconRasterCache.contentStamp(for: folder, resolvedPath: nil) == AppIconLoader.modificationStamp(atPath: NSTemporaryDirectory()))
        #expect(TileIconRasterCache.contentStamp(for: app, resolvedPath: "/System/Applications/Calculator.app") == AppIconLoader.modificationStamp(atPath: "/System/Applications/Calculator.app"))
        #expect(TileIconRasterCache.contentStamp(for: app, resolvedPath: nil) == 0)
    }

    @Test("Pixel size rounds up and never drops below 1x")
    func pixelSizes() {
        #expect(TileIconRasterCache.pixelSize(pointSize: 56, scale: 2) == 112)
        #expect(TileIconRasterCache.pixelSize(pointSize: 44, scale: 1) == 44)
        #expect(TileIconRasterCache.pixelSize(pointSize: 24, scale: 2) == 48)
        #expect(TileIconRasterCache.pixelSize(pointSize: 18, scale: 1.5) == 27)
        #expect(TileIconRasterCache.pixelSize(pointSize: 56, scale: 0) == 56)
    }

    @Test("The appearance token separates every style and both colour schemes")
    func appearanceTokens() {
        #expect(TileIconRasterCache.appearanceToken(style: .defaultStyle, isDark: false) == "\(IconStyle.defaultStyle.rawValue)-light")
        #expect(TileIconRasterCache.appearanceToken(style: .defaultStyle, isDark: true) == "\(IconStyle.defaultStyle.rawValue)-dark")
        #expect(TileIconRasterCache.appearanceToken(style: .tinted, isDark: true) == "\(IconStyle.tinted.rawValue)-dark")
    }

    @Test("A missing path stamps as zero")
    func missingPathStamp() {
        #expect(AppIconLoader.modificationStamp(atPath: nil) == 0)
        #expect(AppIconLoader.modificationStamp(atPath: "/nonexistent/\(UUID().uuidString).app") == 0)
    }
}
```

Task 2 removed `iconData`, so `AppItem(bundleIdentifier:name:)` is the full initialiser call. If Task 2 has not landed when this task runs, the same call still compiles (the parameter has a default).

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/TileIconRasterCacheTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: build FAILS — `cannot find 'TileIconRasterCache' in scope`.

- [ ] **Step 3: Add the cache**

In `DockTile/Utilities/AppIconLoader.swift`, inside `enum AppIconLoader` just before its closing brace, add:

```swift

    /// Modification time of the bundle at `path` (0 when absent) — part of the raster-cache key, so
    /// an updated app gets a fresh icon without restarting the tile.
    nonisolated static func modificationStamp(atPath path: String?) -> TimeInterval {
        guard let path,
              let date = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        else { return 0 }
        return date.timeIntervalSince1970
    }
```

Then, after the enum's closing brace and before `// MARK: - App Install Checker`, add:

```swift

// MARK: - Tile Icon Raster Cache

/// Process-lifetime cache of RASTERISED app icons for the popover.
///
/// WHY: an `NSImage` from `NSWorkspace.icon(forFile:)` is an IconServices proxy. When SwiftUI draws
/// it, the proxy renders the bitmap over a SYNCHRONOUS XPC call to `iconservicesagent` (~3.5 ms per
/// icon, main thread). The agent caches renders for only a few minutes, and the popover used to
/// rebuild every `NSImage` per open, so the first open after idle paid the whole bill: 201 ms on a
/// 10-app Release tile, ~470 ms on a 102-app tile (docs/performance-baseline-2026-09.md). A plain
/// `CGImage` has no proxy behind it, so holding the bitmaps here removes the XPC from the click path.
///
/// Main-actor only on purpose — no assumption is made about NSWorkspace/NSImage thread-safety. The
/// cost is moved ahead of the click by `prewarm`, one icon per run-loop turn.
@MainActor
final class TileIconRasterCache {
    // A closure literal, NOT `rasterise: TileIconRasterCache.systemRasterise`: the method inherits
    // @MainActor from this class, and Swift 6 refuses to convert that to the plain function type
    // ("loses global actor 'MainActor'").
    static let shared = TileIconRasterCache { item, size in TileIconRasterCache.systemRasterise(item, size) }

    struct Key: Hashable {
        let itemKey: String
        let pixelSize: Int
        let contentStamp: TimeInterval
    }

    private let rasterise: (AppItem, Int) -> CGImage?
    private var images: [Key: CGImage] = [:]
    private var token = ""
    /// How many times the rasteriser actually ran — the tests' observability hook.
    private(set) var rasteriseCount = 0

    init(rasterise: @escaping (AppItem, Int) -> CGImage?) {
        self.rasterise = rasterise
    }

    nonisolated static func pixelSize(pointSize: CGFloat, scale: CGFloat) -> Int {
        Int((pointSize * max(scale, 1)).rounded(.up))
    }

    /// A rasterised bitmap bakes in Light/Dark and the Tahoe icon style, so both are in the token.
    nonisolated static func appearanceToken(style: IconStyle, isDark: Bool) -> String {
        "\(style.rawValue)-\(isDark ? "dark" : "light")"
    }

    nonisolated static func itemKey(for item: AppItem) -> String {
        item.isFolder ? "folder:\(item.folderPath ?? item.name)" : "app:\(item.bundleIdentifier)"
    }

    func image(for item: AppItem, pointSize: CGFloat, scale: CGFloat,
               appearanceToken: String, contentStamp: TimeInterval) -> CGImage? {
        if appearanceToken != token {
            images.removeAll()
            token = appearanceToken
        }
        let key = Key(itemKey: Self.itemKey(for: item),
                      pixelSize: Self.pixelSize(pointSize: pointSize, scale: scale),
                      contentStamp: contentStamp)
        if let hit = images[key] { return hit }
        rasteriseCount += 1
        guard let image = rasterise(item, key.pixelSize) else { return nil }
        images[key] = image
        return image
    }

    /// The ONE derivation of the key's content stamp — cells and prewarm both call it, so a
    /// prewarmed entry can never miss because the two sides looked at different paths.
    nonisolated static func contentStamp(for item: AppItem, resolvedPath: String?) -> TimeInterval {
        AppIconLoader.modificationStamp(atPath: item.isFolder ? item.folderPath : resolvedPath)
    }

    /// Fill the cache ahead of the first click, yielding between icons so no single run-loop turn
    /// carries more than one IconServices round trip. `scales`: every connected display's backing
    /// scale, so the popover hits whichever screen the Dock is on.
    func prewarm(items: [AppItem], pointSize: CGFloat, scales: [CGFloat], appearanceToken: String) async {
        for item in items {
            let stamp = Self.contentStamp(for: item, resolvedPath: AppInstallChecker.resolve(item).resolvedPath)
            for scale in scales {
                _ = image(for: item, pointSize: pointSize, scale: scale, appearanceToken: appearanceToken, contentStamp: stamp)
            }
            await Task.yield()
        }
    }

    private static func systemRasterise(_ item: AppItem, _ pixelSize: Int) -> CGImage? {
        guard let nsImage = AppIconLoader.icon(for: item) else { return nil }
        var rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        var result: CGImage?
        // Rasterise under the app's effective appearance so the bitmap matches what SwiftUI would
        // have drawn for the same colour scheme.
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            result = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return result
    }
}
```

- [ ] **Step 4: Run to verify the tests pass**

Run: the Step 2 command. Expected: 9/9 pass.

- [ ] **Step 5: Render grid cells from the cache**

In `DockTile/UI/NativePopoverViews.swift`, `struct StackAppItem`:

Add beside `@Environment(\.colorScheme) private var colorScheme`:
```swift
    @Environment(\.displayScale) private var displayScale
```

Replace
```swift
        let isMissing = AppInstallChecker.resolve(app).status == .missing
```
with
```swift
        let resolution = AppInstallChecker.resolve(app)
        let isMissing = resolution.status == .missing
```
and change the call `appIconView(isMissing: isMissing)` to `appIconView(isMissing: isMissing, resolvedPath: resolution.resolvedPath)`.

Replace the whole `appIconView` function with:

```swift
    @ViewBuilder
    private func appIconView(isMissing: Bool, resolvedPath: String?) -> some View {
        // Resolved synchronously (no @State/onAppear) so a deleted app never flashes its stale
        // cached icon before the placeholder appears.
        if isMissing {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: iconSize * 0.5))
                .foregroundStyle(.secondary)
        } else if let cgImage = TileIconRasterCache.shared.image(
            for: app, pointSize: iconSize, scale: displayScale,
            appearanceToken: TileIconRasterCache.appearanceToken(
                style: IconStyle.forDisplay(raw: iconStyleManager.rawStyle, colorScheme: colorScheme, fallback: .defaultStyle),
                isDark: colorScheme == .dark),
            contentStamp: TileIconRasterCache.contentStamp(for: app, resolvedPath: resolvedPath)
        ) {
            // A plain bitmap, NOT the IconServices-backed NSImage — see TileIconRasterCache.
            Image(decorative: cgImage, scale: displayScale)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app")
                .font(.system(size: iconSize * 0.5))
                .foregroundStyle(.secondary)
        }
    }
```

- [ ] **Step 6: Render list rows from the cache**

In `struct ListAppRow` (same file):

Add beside `@Environment(\.colorScheme) private var colorScheme`:
```swift
    @Environment(\.displayScale) private var displayScale
```

In `body`, replace
```swift
        let isMissing = AppInstallChecker.resolve(app).status == .missing
```
with
```swift
        let resolution = AppInstallChecker.resolve(app)
        let isMissing = resolution.status == .missing
```
and change `appIconView(isMissing: isMissing)` to `appIconView(isMissing: isMissing, resolvedPath: resolution.resolvedPath)`.

Replace the whole `appIconView` function with:

```swift
    @ViewBuilder
    private func appIconView(isMissing: Bool, resolvedPath: String?) -> some View {
        // Resolved synchronously so a deleted app shows the placeholder, not its stale icon.
        if isMissing {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: metrics.iconSize * 0.75))
                .foregroundStyle(.secondary)
        } else if let cgImage = TileIconRasterCache.shared.image(
            for: app, pointSize: metrics.iconSize, scale: displayScale,
            appearanceToken: TileIconRasterCache.appearanceToken(
                style: IconStyle.forDisplay(raw: iconStyleManager.rawStyle, colorScheme: colorScheme, fallback: .defaultStyle),
                isDark: colorScheme == .dark),
            contentStamp: TileIconRasterCache.contentStamp(for: app, resolvedPath: resolvedPath)
        ) {
            // A plain bitmap, NOT the IconServices-backed NSImage — see TileIconRasterCache.
            Image(decorative: cgImage, scale: displayScale)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: metrics.iconSize * 0.75))
                .foregroundStyle(.secondary)
        }
    }
```

- [ ] **Step 7: Prewarm at helper launch**

In `DockTile/App/HelperAppDelegate.swift`, `applicationDidFinishLaunching`, immediately after `SpinWatchdog.shared.start()` add:

```swift

        // Rasterise this tile's icons BEFORE the first click, one per run-loop turn, so the first
        // popover open doesn't wait on ~3.5 ms of synchronous IconServices XPC per icon.
        if let config = getCurrentConfiguration() {
            let settings = PopoverSettings.load(layout: config.layoutMode)
            let pointSize = config.layoutMode == .list
                ? PopoverMetrics.listIconSize(settings.tileSize)
                : PopoverMetrics.tileIconSize(settings.tileSize)
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let style = IconStyle.forDisplay(raw: IconStyleManager.shared.rawStyle,
                                             colorScheme: isDark ? .dark : .light, fallback: .defaultStyle)
            let token = TileIconRasterCache.appearanceToken(style: style, isDark: isDark)
            let scales = Array(Set(NSScreen.screens.map(\.backingScaleFactor))).sorted()
            Task { @MainActor in
                await TileIconRasterCache.shared.prewarm(items: config.appItems, pointSize: pointSize,
                                                         scales: scales.isEmpty ? [2] : scales, appearanceToken: token)
                DiagnosticsLog.shared.log("helper", "Icon cache prewarmed — \(config.appItems.count) item(s)", verbose: true)
            }
        }
```
`HelperAppDelegate.swift` imports only `AppKit`, and `IconStyle.forDisplay(raw:colorScheme:fallback:)` takes a SwiftUI `ColorScheme` — so **add `import SwiftUI` to that file**. It is required, not conditional.

- [ ] **Step 8: Build + full suite**

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Re-measure — this is the test of the hypothesis**

Rebuild signed; in the dev app press Update on the 102-app `Work` tile and on `Dev Tile` so the helpers carry the new code (compare `md5 -q` of the helper's `Dock Tile Dev.debug.dylib` with the built product — the stub alone is not the code). Then **leave both helpers untouched for at least 10 minutes**, and:

```bash
xcrun xctrace record --template 'Time Profiler' --attach <Work pid> --time-limit 40s --output /tmp/work-idle.trace &
open -b <Work bundle id>
Scripts/perf/analyze.sh /tmp/work-idle.trace 12
grep "Show popover 'Work' (" ~/Library/Application\ Support/DockTile-Dev/diagnostics.log | tail -2
sample <Work pid> 5 -file /tmp/work-open.txt    # run during a second idle open; then:
grep -c "_ISRetryRequest" /tmp/work-open.txt    # expect 0
```
Expected: first-open-after-idle on `Work` < 120 ms (baseline 451–522 ms, Debug); on `Dev Tile` < 60 ms (baseline 129–192 ms); no `_ISRetryRequest` frames under `showPopover`. If the XPC frames are still there the hypothesis is wrong: revert, record it in the ledger, and re-read the stack before trying anything else.

- [ ] **Step 9b: Check the cached bitmaps look like the Dock's icons in every style**

System Settings → Appearance → **Icon & widget style**: step through Default, Dark, Clear and Tinted, and Light/Dark appearance. After each change open the dev popover and compare three apps (one Apple app, one Electron app such as VS Code, one folder) against the same apps in the Dock. Capture by window ID (`Scripts/dev-capture.sh`), never by screen rectangle. Expected: same treatment as the Dock in all combinations, and the change is visible on the first open after switching (the appearance token emptied the cache). If a style renders wrong, the rasterisation assumption is false — stop and report; do not ship a fast popover with wrong icons.

- [ ] **Step 10: Rule + ledger + commit**

Append to `.claude/rules/icon-system.md`, section *App Icon Loading*:

```markdown
- **Popover cells draw a cached bitmap, never the IconServices `NSImage` (critical)**:
  `TileIconRasterCache` holds rasterised `CGImage`s for the process lifetime, keyed by item, pixel
  size, appearance token (icon style + Light/Dark) and the app bundle's modification time, and is
  prewarmed at helper launch. Drawing the `NSImage` directly makes SwiftUI trigger a synchronous
  XPC render per icon; `iconservicesagent` evicts within minutes, so every first open after idle
  paid ~3.5 ms per app on the main thread (201 ms on a 10-app Release tile). Guarded by
  `TileIconRasterCacheTests`.
```

```bash
git add DockTile/Utilities/AppIconLoader.swift DockTile/UI/NativePopoverViews.swift DockTile/App/HelperAppDelegate.swift DockTileTests/Unit/Utilities/TileIconRasterCacheTests.swift .claude/rules/icon-system.md docs/performance-baseline-2026-09.md
git commit -m "perf(popover): cache rasterised icons — first open after idle no longer waits on IconServices"
```

---

### Task 5: Popover close paths remove the global monitor; Reduce Motion and the Animation tier reach AppKit

Two correctness fixes in `FloatingPanel`, deliberately separate from the performance experiment in Task 6 so they survive if that experiment is reverted.

**Root causes (established by code reading):**
1. `show()` installs `NSEvent.addGlobalMonitorForEvents` (`FloatingPanel.swift:341`); only `hide()` and `cleanupPopover()` remove it. `popoverDidClose` (`:420-437`) — the path NSPopover's own `.transient` close takes when the app deactivates — does not. Until the tile is next clicked that helper is woken by every mouse-down on the Mac.
2. `createPopover()` sets `popover.animates = true` unconditionally (`:201`), so the app's Animation tier "None" and system Reduce Motion never reach AppKit's appearance animation (~0.5 s, measured as a parked `-[NSAnimation _runBlocking]` thread).

**Files:**
- Modify: `DockTile/UI/FloatingPanel.swift:196-203`, `:360-383`, `:387-409`, `:420-437`
- Test: `DockTileTests/Unit/UI/FloatingPanelAnimationTests.swift` (new)
- Modify: `.claude/rules/popover-appearance.md` (Pure metrics seam bullet)

**Interfaces:**
- Produces: `nonisolated static func FloatingPanel.shouldAnimate(tier: PopoverAnimationTier, reduceMotion: Bool) -> Bool`; `private func removeEventMonitors()`

- [ ] **Step 1: Write the failing test**

`DockTileTests/Unit/UI/FloatingPanelAnimationTests.swift`:

```swift
import Testing
@testable import Dock_Tile

/// `popover.animates` was hardcoded `true`, so Animation = None and system Reduce Motion both still
/// got AppKit's ~0.5 s appearance animation. Failing value: `true` for either of those inputs.
@Suite("Popover appearance animation")
struct FloatingPanelAnimationTests {

    @Test("Reduce Motion always wins")
    func reduceMotionDisablesAnimation() {
        #expect(FloatingPanel.shouldAnimate(tier: .default, reduceMotion: true) == false)
        #expect(FloatingPanel.shouldAnimate(tier: .fast, reduceMotion: true) == false)
        #expect(FloatingPanel.shouldAnimate(tier: .none, reduceMotion: true) == false)
    }

    @Test("The None tier disables animation; Default and Fast keep it")
    func tierControlsAnimation() {
        #expect(FloatingPanel.shouldAnimate(tier: .none, reduceMotion: false) == false)
        #expect(FloatingPanel.shouldAnimate(tier: .default, reduceMotion: false) == true)
        #expect(FloatingPanel.shouldAnimate(tier: .fast, reduceMotion: false) == true)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/FloatingPanelAnimationTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: build FAILS — `type 'FloatingPanel' has no member 'shouldAnimate'`.

- [ ] **Step 3: Add the seam and use it**

In `DockTile/UI/FloatingPanel.swift`, beside `resolveAnchor` (the pure-seam section), add:

```swift
    /// Whether AppKit's popover appearance animation runs. Reduce Motion means NO motion, not a
    /// shorter one; the app's Animation tier "None" means the same. Guarded by
    /// FloatingPanelAnimationTests.
    nonisolated static func shouldAnimate(tier: PopoverAnimationTier, reduceMotion: Bool) -> Bool {
        !reduceMotion && tier != .none
    }
```

In `createPopover()` replace `popover.animates = true` with:

```swift
        popover.animates = Self.shouldAnimate(
            tier: PopoverSettings.load(layout: configuration?.layoutMode ?? .grid).animation,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
```

- [ ] **Step 4: Remove the monitor on every close path**

Add this method in the `// MARK: - Cleanup` section:

```swift
    /// Idempotent. Called from EVERY path that ends a presentation — `hide()`, `cleanupPopover()`
    /// and `popoverDidClose` — because NSPopover's own transient close never goes through `hide()`,
    /// and a global monitor left installed wakes this process on every click anywhere on the Mac.
    private func removeEventMonitors() {
        if let observer = dismissObserver {
            NotificationCenter.default.removeObserver(observer)
            dismissObserver = nil
        }
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
            DiagnosticsLog.shared.log("helper", "Click-outside monitor removed", verbose: true)
        }
    }
```

In `hide()` replace the two blocks commented `// Remove notification observer first` and `// Remove click outside monitor` with the single line `removeEventMonitors()`.
In `cleanupPopover()` replace its two equivalent blocks with `removeEventMonitors()`.
In `popoverDidClose`, inside `MainActor.assumeIsolated {`, add as the first statement:

```swift
                self.removeEventMonitors()
```

- [ ] **Step 5: Tests + full suite**

Expected: `FloatingPanelAnimationTests` 2/2; `** TEST SUCCEEDED **`.

- [ ] **Step 6: Verify the leak is closed on a real helper**

Rebuild signed, Update a dev tile, then: `open -b <helper id>` (popover shows), `open -a Finder` (the helper deactivates; NSPopover closes itself), and

```bash
grep "Click-outside monitor removed" ~/Library/Application\ Support/DockTile-Dev/diagnostics.log | tail -1
```
Expected: a line stamped within the last few seconds from that helper. Before this task no such line is written on this path.
Then set **Settings → Popover → Animation → None** and **Save** (no Apply — the tier is read from the shared suite on each open, and Apply would rebuild every helper and restart the Dock for nothing). Open the popover: it appears with no scale/fade. Restore the setting and Save.

- [ ] **Step 7: Rule + commit**

In `.claude/rules/popover-appearance.md`, extend the sentence "Animation is forced to 0 when system Reduce Motion is on." with:

```markdown
 The same decision now reaches AppKit: `FloatingPanel.shouldAnimate(tier:reduceMotion:)` sets
  `NSPopover.animates`, which used to be hardcoded `true` (Animation = None and Reduce Motion still
  got the ~0.5 s appearance animation). Guarded by `FloatingPanelAnimationTests`.
```

```bash
git add DockTile/UI/FloatingPanel.swift DockTileTests/Unit/UI/FloatingPanelAnimationTests.swift .claude/rules/popover-appearance.md
git commit -m "fix(popover): remove the global click monitor on every close path; honour Animation=None and Reduce Motion"
```

---

### Task 6: Find what each popover open abandons, then reuse one popover

**Measured symptom:** every open grows the helper and never gives it back — Release `AI Tile` 85 → 97 MB over five opens, IOSurface regions 22 → 44, unchanged ten minutes later; `leaks` reports only 72 KB, so the memory is reachable-but-never-reused.

**Root cause: NOT established.** Do not write the reuse code until Steps 1–2 are done and the finding is written down. Candidate owners, from the code: the per-open `_NSPopoverWindow` and its backing store; the per-open `NSHostingController` view tree; the per-open borderless anchor `NSWindow` (`isReleasedWhenClosed` defaults to `true`, and it is only ever `orderOut`-ed, never closed); the global monitor closure fixed in Task 5.

**Files:**
- Modify: `DockTile/UI/FloatingPanel.swift:196-222`, `:268-282`, `:286-325`, `:387-409`, `:420-437`
- Modify: `DockTile/UI/LauncherView.swift` (add `openGeneration`)
- Modify: `.claude/rules/architecture.md` (NSPopover Positioning section)

**Interfaces:**
- Consumes: `removeEventMonitors()`, `shouldAnimate(tier:reduceMotion:)` from Task 5.
- Produces: `LauncherView(configuration:openGeneration:)`.

- [ ] **Step 1: Gather evidence (Debug dev helper, which is debuggable)**

```bash
PID=<Dev Tile helper pid>
footprint $PID | grep -E "Footprint:|IOSurface"
leaks $PID --outputGraph=/tmp/popover-before.memgraph
# five open/close cycles: `open -b <id>` ten times, a few seconds apart
footprint $PID | grep -E "Footprint:|IOSurface"
leaks $PID --outputGraph=/tmp/popover-after.memgraph
heap --diffFrom=/tmp/popover-before.memgraph /tmp/popover-after.memgraph | head -40
vmmap --summary $PID | grep -i -E "iosurface|CoreAnimation|CG image"
```

- [ ] **Step 2: Write the finding into the spec**

Add a short subsection *Task 6 evidence* to `docs/performance-baseline-2026-09.md` with: the footprint delta, and the classes whose live count rose by ~5 (one per open) in the `heap --diffFrom` output — expect some of `_NSPopoverWindow`, `NSPopover`, `NSHostingView`, `NSWindow`, `CAContext`. State the hypothesis in one sentence: "I think `<class>` is retained per open because `<reason from the code>`." If nothing rises per open and only IOSurface grows, say so: the surfaces are then most likely CoreAnimation backing stores owned by the window server connection, and reuse is still the correct experiment because it stops creating them.

- [ ] **Step 3: Give the launcher an explicit per-open identity**

`.claude/rules/popover-appearance.md` requires that "the popover content is rebuilt on every `show()`" (that is how a running helper re-reads saved settings, and how selection/scroll state resets). Reusing the hosting controller must keep that. In `DockTile/UI/LauncherView.swift` add a property below `let configuration: DockTileConfiguration?`:

```swift
    /// Bumped by FloatingPanel on every show. The panel below is re-identified by it, so a REUSED
    /// hosting controller still rebuilds its content per open: saved Popover settings are re-read,
    /// and selection / keyboard / scroll state starts fresh — exactly as when the controller was
    /// recreated each time.
    var openGeneration: Int = 0
```
and apply `.id(openGeneration)` to the view returned from `body` (wrap the `switch` in a `Group { … }` and put `.id(openGeneration)` on the `Group`).

- [ ] **Step 4: Reuse the popover, hosting controller and anchor window**

In `DockTile/UI/FloatingPanel.swift`:

Add a stored property beside `hostingController`:
```swift
    /// Incremented per show; drives `LauncherView.openGeneration`.
    private var openGeneration = 0
```

Replace `createPopover()` with:

```swift
    /// Created ONCE and reused: building a fresh NSPopover + NSHostingController + window per open
    /// was the fixed ~40 ms of every open and left graphics memory behind each time
    /// (docs/performance-baseline-2026-09.md). Content is still rebuilt per open through
    /// `LauncherView.openGeneration`.
    private func preparePopover() -> NSPopover {
        openGeneration += 1
        let launcherView = LauncherView(configuration: configuration, openGeneration: openGeneration)

        let popover: NSPopover
        if let existing = self.popover, let controller = hostingController {
            controller.rootView = launcherView
            popover = existing
        } else {
            popover = NSPopover()
            popover.behavior = .transient  // Closes when clicking outside
            popover.delegate = self
            let controller = NSHostingController(rootView: launcherView)
            // Let the SwiftUI content drive the popover size (see PopoverMetrics).
            controller.sizingOptions = [.preferredContentSize]
            self.hostingController = controller
            popover.contentViewController = controller
        }
        popover.animates = Self.shouldAnimate(
            tier: PopoverSettings.load(layout: configuration?.layoutMode ?? .grid).animation,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        return popover
    }
```

In `createAnchorWindowAndEdge()`, replace the block from `let window = NSWindow(` through `window.collectionBehavior = […]` with:

```swift
        let window: NSWindow
        if let existing = anchorWindow {
            window = existing
            window.setFrame(windowRect, display: false)
        } else {
            window = NSWindow(contentRect: windowRect, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
        }
        // Set unconditionally: the no-screen fallback above returns a bare 1×1 window that never got
        // these, and it can be the window this branch later reuses.
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .popUpMenu
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

In `show()`, replace
```swift
        // Cleanup any stale state
        cleanupPopover()

        // Create popover and anchor window with appropriate edge
        popover = createPopover()
```
with
```swift
        removeEventMonitors()

        // Reuse the popover and anchor window; only the content is rebuilt.
        popover = preparePopover()
```

In `popoverDidClose`, delete the two lines `self.popover = nil` and `self.hostingController = nil`, and replace `self.cleanupAnchorWindow()` with `self.anchorWindow?.orderOut(nil)`.
Then delete `cleanupPopover()` and `cleanupAnchorWindow()` entirely: `show()` was `cleanupPopover()`'s only caller and `popoverDidClose` was `cleanupAnchorWindow()`'s last, so this change orphans both. (Confirm with `grep -c "cleanupPopover\|cleanupAnchorWindow" DockTile/UI/FloatingPanel.swift` → `0`.)

- [ ] **Step 5: Build, full suite, and check behaviour by hand**

Expected: `** TEST SUCCEEDED **`. Then, on an Updated dev tile, confirm each of these still holds (they are the invariants this file's comments and `.claude/rules/architecture.md` call critical): the popover appears above the clicked icon with its arrow on it; a second Dock click closes it and does not bounce it back; clicking outside closes it; changing **Settings → Popover → Tile Size**, Save (without Apply), then reopening shows the new size; the scroll position and hover/selection start fresh on each open; opening on a second display anchors there.

- [ ] **Step 6: Re-measure — memory and the fixed open cost**

```bash
footprint <pid> | grep -E "Footprint:|IOSurface"      # before
# five open/close cycles
footprint <pid> | grep -E "Footprint:|IOSurface"      # after, and again 10 min later
grep "Show popover 'Dev Tile' (" ~/Library/Application\ Support/DockTile-Dev/diagnostics.log | tail -6
```
Expected: IOSurface region count and footprint flat across the five opens (baseline: +4.4 regions and +2.3 MB per open on Release; +6 MB per open on the 102-app Debug tile). Warm show-call time on `Dev Tile` lower than its pre-task median. **If memory still climbs, stop**: re-run Step 1's `heap --diffFrom`, update the hypothesis, and do not stack another fix on top. If the open time is within noise but memory is flat, the task is kept for the memory result — say so in the ledger.

- [ ] **Step 7: Rule + ledger + commit**

In `.claude/rules/architecture.md`, *NSPopover Positioning*, add a bullet:

```markdown
- **One popover for the helper's lifetime (critical)**: `FloatingPanel` reuses a single `NSPopover`,
  `NSHostingController` and anchor `NSWindow`; per-open freshness comes from
  `LauncherView.openGeneration` (`.id`), which rebuilds the SwiftUI content so saved Popover
  settings are re-read and selection/scroll reset. Recreating the AppKit objects per open cost a
  fixed ~40 ms and abandoned ~2.3 MB of graphics memory per open that never came back. Any new
  per-open AppKit object here reintroduces that growth — verify with `footprint` across five opens.
```

```bash
git add DockTile/UI/FloatingPanel.swift DockTile/UI/LauncherView.swift .claude/rules/architecture.md docs/performance-baseline-2026-09.md
git commit -m "perf(popover): reuse one popover and anchor window — opens stop abandoning graphics memory"
```

---

### Task 7: Icon compile and code signing wait off the main actor

**Root cause (established):** `IconCompiler.compile` runs `docktile-actool` then `assetutil` with synchronous `waitUntilExit()` on the main actor (its own comment says so), and `codesignHelper` does the same with `codesign --deep`. Measured: **957–1021 ms of blocked main thread per helper, six out of six**, with the compile itself logging 842–941 ms. An Update is one proper hang; a migration or "apply" batch is one per tile.

**Approach:** keep both synchronous functions exactly as they are (their pipe-draining order is load-bearing and tested) and call them from a detached task, so the wait happens on a background thread while the main actor stays free. Both call sites are already inside `async` functions.

**This task edits the shipped-update path.** `regenerateHelperBundle` is what the launch migration calls for every stale tile after a version bump, so a mistake here does not merely slow an Update button — it can stop users' tiles from picking up any of these fixes. The failure mode is at least benign by design (`runRegenerationBatch` stamps on success only, and a failed tile retries next launch without restarting the Dock), but Task 11 exercises the real path end-to-end before anything ships.

**Concurrency note:** freeing the main actor means the user — and the Dock plist watcher's sync, and a debounced save — can now run *during* a build, where before they queued behind it. `installHelper` is guarded by `installingBundleIds`, `regenerateBatch` is sequential, and every Dock mutation already verifies itself afterwards, so this is believed safe; it is an assumption, checked in Step 6 by reading the log for a `[sync]` line between a build's `▶` and `✔`.

**Files:**
- Modify: `DockTile/Utilities/DeclarativeIconPipeline.swift` (add after `compile`, inside `enum IconCompiler`)
- Modify: `DockTile/Managers/HelperBundleManager.swift:158`, `:162`, `:813`, `:850`, `:885`, `:1047-1063`, `:1783`, `:1786`
- Test: `DockTileTests/Unit/Utilities/IconCompilerOffMainTests.swift` (new)

**Interfaces:**
- Produces: `static func IconCompiler.compileOffMain(document: URL, outputDir: URL, compilerURL: URL) async throws -> URL`; `private func codesignHelper(at:) async throws`; `private func installTileIcons(for:at:) async throws`; `private func installDeclarativeIcon(for:resourcesPath:) async throws`.

- [ ] **Step 1: Write the failing test**

`DockTileTests/Unit/Utilities/IconCompilerOffMainTests.swift`:

```swift
import Foundation
import Testing
@testable import Dock_Tile

/// The off-main wrapper must surface exactly the errors the synchronous compiler throws — a
/// wrapper that swallowed them would let a helper ship without a validated `Assets.car`.
/// Failing value: no error, or a different error, for a compiler that does not exist.
@Suite("Icon compiler off the main actor")
struct IconCompilerOffMainTests {

    @Test("A missing compiler still throws compilerMissing through the async wrapper")
    func missingCompilerPropagates() async {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("offmain-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        await #expect(throws: IconCompilerError.self) {
            _ = try await IconCompiler.compileOffMain(
                document: scratch.appendingPathComponent("AppIcon.icon"),
                outputDir: scratch.appendingPathComponent("out"),
                compilerURL: URL(fileURLWithPath: "/nonexistent/docktile-actool"))
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/IconCompilerOffMainTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: build FAILS — `type 'IconCompiler' has no member 'compileOffMain'`.

- [ ] **Step 3: Add the wrapper**

In `DockTile/Utilities/DeclarativeIconPipeline.swift`, inside `enum IconCompiler` directly after the closing brace of `compile(document:outputDir:compilerURL:)`:

```swift

    /// `compile`, with its two synchronous subprocess waits moved OFF the main actor. `compile`
    /// blocks its calling thread for ~0.9 s; called on the main actor that was a proper hang per
    /// tile (957–1021 ms, docs/performance-baseline-2026-09.md). The synchronous function is kept
    /// untouched — its pipe-draining order is load-bearing — and simply runs on a background thread.
    static func compileOffMain(document: URL, outputDir: URL, compilerURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try compile(document: document, outputDir: outputDir, compilerURL: compilerURL) })
            }
        }
    }
```
If the compiler reports that `compile` is main-actor-isolated, mark `compile` `nonisolated` (it touches no actor state).

**Structural guard (this is the real regression guard — the unit test only proves errors propagate):** annotate the synchronous function so calling it from any async context is a compile error:

```swift
    @available(*, noasync, message: "blocks ~0.9 s on subprocess waits — call compileOffMain from async code")
    static func compile(document: URL, outputDir: URL, compilerURL: URL) throws -> URL {
```
Every production caller lives in an `async` function on the main actor, so reintroducing the blocking call there now fails to build. `compileOffMain` calls it from a synchronous `DispatchQueue` closure, which is allowed. If an existing `IconCompilerTests` case calls `compile` from an `async` test, make that test function synchronous (it awaits nothing) rather than weakening the annotation.

- [ ] **Step 4: Await it from the helper build**

In `DockTile/Managers/HelperBundleManager.swift`:

- `private func installDeclarativeIcon(for config: DockTileConfiguration, resourcesPath: URL) throws {` → add `async` before `throws`; inside it change `let car = try IconCompiler.compile(` to `let car = try await IconCompiler.compileOffMain(`.
- `private func installTileIcons(for config: DockTileConfiguration, at helperPath: URL) throws {` → add `async`; change its call to `installDeclarativeIcon` to `try await`.
- Both callers (`:158` in `installHelper`, `:1783` in `regenerateHelperBundle`): `try installTileIcons(` → `try await installTileIcons(`.

Replace `codesignHelper` with:

```swift
    private func codesignHelper(at helperPath: URL) async throws {
        // `codesign --deep` waits hundreds of ms; do that wait off the main actor.
        let status = try await Task.detached(priority: .userInitiated) {
            try Self.runCodesign(path: helperPath.path)
        }.value

        guard status == 0 else {
            DiagnosticsLog.shared.log("dock", "codesign FAILED (status \(status)) for \(helperPath.lastPathComponent)")
            throw HelperBundleError.codesignFailed
        }
    }

    private nonisolated static func runCodesign(path: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
```
and change both call sites (`:162`, `:1786`) from `try codesignHelper(at: helperPath)` to `try await codesignHelper(at: helperPath)`.

- [ ] **Step 5: Tests + full suite**

Expected: `IconCompilerOffMainTests` passes; the existing `IconCompilerTests` and `HelperBundleLifecycleTests` still pass; `** TEST SUCCEEDED **`.

- [ ] **Step 6: Re-measure the batch**

Rebuild signed, launch, **Settings → Popover**: change Spacing, Save, Apply, under a recording:

```bash
xcrun xctrace record --template 'Time Profiler' --attach <main pid> --time-limit 60s --output /tmp/batch.trace &
# Save + Apply through Accessibility
Scripts/perf/analyze.sh /tmp/batch.trace 100
```
Expected: no ~1 s block per helper; the Save button's spinner animates throughout (it could not before — the run loop was blocked). Any block still over 250 ms is one of the waits this task did not move (`iconutil`, `killall Dock`) — record it for the Deferred list rather than fixing it here. Also read the log between the batch's `▶` and `✔` lines: a `[sync]` line there is the interleaving the concurrency note describes — confirm the tiles are still pinned and visible afterwards. Baseline: six blocks of 957–1021 ms across two batches. Restore Spacing and Apply again.

- [ ] **Step 7: Ledger + commit**

```bash
git add DockTile/Utilities/DeclarativeIconPipeline.swift DockTile/Managers/HelperBundleManager.swift DockTileTests/Unit/Utilities/IconCompilerOffMainTests.swift docs/performance-baseline-2026-09.md
git commit -m "perf(helper): icon compile and code signing wait off the main actor — no more 1 s hang per tile"
```

---

### Task 8: Re-measure tile selection; profile only if it is still slow

**Status:** not a fix yet. Selecting a tile measured 114–142 ms on release-scale data (optimised build) — over Apple's 100 ms "instant" bar, under its 250 ms hang threshold. Tasks 2 and 4 both remove work from this path (blob-laden struct copies and equality; per-cell IconServices renders in the editor canvas, which draws the same `StackAppItem`). Optimising before re-measuring would be guessing.

- [ ] **Step 1: Re-measure**

Optimised build (see `Scripts/perf/README.md`), release-sized test config, three selections each of two tiles through Accessibility `set selected`, then `Scripts/perf/analyze.sh <trace> 20`.

- [ ] **Step 2: Decide, record, commit**

Median ≤ 100 ms → record in the ledger, done — commit the spec edit:

```bash
git add docs/performance-baseline-2026-09.md
git commit -m "docs(perf): tile selection re-measured after the config and icon changes"
``` Otherwise record the number and take one CPU Profiler trace of a single selection (`xcrun xctrace record --template 'CPU Profiler' --attach <pid> --time-limit 20s --output /tmp/select.trace`), export its `time-profile` table, and write the heaviest **leaf** frames into the spec. That call tree is the input to a follow-up plan; do not fix from this plan.

---

### Task 9: One log line per event; the trim stops keeping orphans

**Root cause (established by code reading):** `DiagnosticsLog.log` writes `message` verbatim, and some messages embed newlines (an `IconCompilerError` carries `assetutil`'s multi-line stderr). `prepareOnLaunch` keeps any line whose first token does not parse as a date (`guard let d = … else { return true }`), so those continuation lines never age out — 65 untimestamped `assetutil:` lines sit at the top of the dev log.

**Files:**
- Modify: `DockTile/Managers/DiagnosticsLog.swift:163-175` (`log`), `:261-272` (`prepareOnLaunch`)
- Test: `DockTileTests/Unit/Managers/DiagnosticsLogTrimTests.swift` (new)

**Interfaces:**
- Produces: `nonisolated static func DiagnosticsLog.singleLine(_ message: String) -> String`; `nonisolated static func DiagnosticsLog.trimmed(_ content: String, cutoff: Date, parse: (String) -> Date?) -> String`

- [ ] **Step 1: Write the failing tests**

`DockTileTests/Unit/Managers/DiagnosticsLogTrimTests.swift`:

```swift
import Foundation
import Testing
@testable import Dock_Tile

/// Multi-line messages used to leave untimestamped continuation lines in the shared log, and the
/// launch trim kept every line it could not date — so they lived forever. Failing values: a
/// message that still contains a newline; an orphan line surviving the trim.
@Suite("Diagnostics log trimming")
struct DiagnosticsLogTrimTests {

    private let cutoff = Date(timeIntervalSince1970: 1_000)
    private func parse(_ token: String) -> Date? {
        guard let seconds = TimeInterval(token) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    @Test("A message is flattened to one line")
    func messagesAreSingleLine() {
        #expect(DiagnosticsLog.singleLine("compile failed:\nassetutil: bad file\r\nexit 1") == "compile failed: ⏎ assetutil: bad file ⏎ exit 1")
        #expect(DiagnosticsLog.singleLine("plain") == "plain")
    }

    @Test("Lines older than the cutoff are dropped, newer ones kept, order preserved")
    func trimsByDate() {
        let content = "500 [main] old\n1500 [main] new-a\n2000 [main] new-b\n"
        #expect(DiagnosticsLog.trimmed(content, cutoff: cutoff, parse: parse) == "1500 [main] new-a\n2000 [main] new-b\n")
    }

    @Test("An undated line shares the fate of the dated line before it; leading orphans are dropped")
    func orphansFollowTheirParent() {
        let content = "assetutil: orphan at top\n500 [main] old\nassetutil: belongs to old\n1500 [main] new\nassetutil: belongs to new\n"
        #expect(DiagnosticsLog.trimmed(content, cutoff: cutoff, parse: parse) == "1500 [main] new\nassetutil: belongs to new\n")
    }

    @Test("Nothing kept yields an empty file, not a lone newline")
    func emptyResult() {
        #expect(DiagnosticsLog.trimmed("500 [main] old\n", cutoff: cutoff, parse: parse) == "")
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/DiagnosticsLogTrimTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: build FAILS — no member `singleLine` / `trimmed`.

- [ ] **Step 3: Add the seams and use them**

In `DockTile/Managers/DiagnosticsLog.swift`, next to `shouldRecord`:

```swift
    /// One event = one line. The launch trim dates a line by its first token; a message with
    /// embedded newlines leaves undatable continuation lines behind.
    nonisolated static func singleLine(_ message: String) -> String {
        message.replacingOccurrences(of: "\r\n", with: " ⏎ ")
            .replacingOccurrences(of: "\n", with: " ⏎ ")
            .replacingOccurrences(of: "\r", with: " ⏎ ")
    }

    /// Pure trim seam. A line is dated by its first space-delimited token; a line that cannot be
    /// dated belongs to the dated line before it and shares its fate (so legacy continuation lines
    /// age out with their parent, and orphans before any dated line are dropped).
    nonisolated static func trimmed(_ content: String, cutoff: Date, parse: (String) -> Date?) -> String {
        var kept: [Substring] = []
        var keepingCurrent = false
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let token = line.firstIndex(of: " ").map { String(line[line.startIndex..<$0]) } ?? String(line)
            if let date = parse(token) { keepingCurrent = date >= cutoff }
            if keepingCurrent { kept.append(line) }
        }
        return kept.isEmpty ? "" : kept.joined(separator: "\n") + "\n"
    }
```

In `log(_:_:verbose:)`, add as the first line after the `guard`: `let message = Self.singleLine(message)`.

In `prepareOnLaunch()`, replace from `let cutoff = …` through `let rebuilt = …` with:

```swift
        let cutoff = Date().addingTimeInterval(-retention)
        let rebuilt = Self.trimmed(content, cutoff: cutoff) { stamp.date(from: $0) }
```

- [ ] **Step 4: Tests + full suite, then verify on the real log**

Expected: 4/4; `** TEST SUCCEEDED **`. Rebuild signed, launch the dev app once, then `grep -c "^assetutil:" ~/Library/Application\ Support/DockTile-Dev/diagnostics.log` → `0` (was 65).

- [ ] **Step 5: Commit**

```bash
git add DockTile/Managers/DiagnosticsLog.swift DockTileTests/Unit/Managers/DiagnosticsLogTrimTests.swift
git commit -m "fix(diagnostics): one line per event, and the launch trim drops orphan continuation lines"
```

---

### Task 10: Does the Dock plist watcher survive an atomic replace?

**Root cause: NOT established — a code-reading suspicion.** `DockPlistWatcher.startWatching` opens one descriptor with `O_EVTONLY` and watches `.write/.delete/.rename/.attrib`; nothing reopens it. `cfprefsd` replaces `com.apple.dock.plist` atomically, so after the first replacement the descriptor may point at an unlinked inode and the watcher would fall silent — leaving "live" visibility sync as the launch-time sweep only. Establish it first.

**Files:**
- Modify: `DockTile/Managers/DockPlistWatcher.swift:31-38` (init), `:68-76` (event handler)
- Test: `DockTileTests/Unit/Managers/DockPlistWatcherReplaceTests.swift` (new)

**Interfaces:**
- Produces: `init(path: String? = nil, debounceInterval: TimeInterval = 0.5)`.

- [ ] **Step 1: Make the path and interval injectable**

Replace `private let debounceInterval: TimeInterval = 0.5` with `private let debounceInterval: TimeInterval`, and replace `init()` with:

```swift
    init(path: String? = nil, debounceInterval: TimeInterval = 0.5) {
        self.debounceInterval = debounceInterval
        dockPlistPath = path ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
            .path

        print("👀 DockPlistWatcher initialized")
        print("   Watching: \(dockPlistPath)")
    }
```
(`DockPlistWatcher()` keeps working for every existing caller and test.)

- [ ] **Step 2: Write the test that settles the question**

`DockTileTests/Unit/Managers/DockPlistWatcherReplaceTests.swift`:

```swift
import Foundation
import Testing
@testable import Dock_Tile

/// cfprefsd rewrites the Dock plist by ATOMIC REPLACE. A watcher holding one descriptor sees the
/// first replacement and then watches a dead inode. Failing value: 1 callback for 2 replacements.
@MainActor
@Suite("DockPlistWatcher across atomic replaces", .serialized)
struct DockPlistWatcherReplaceTests {

    @Test("Two atomic replacements produce two change callbacks")
    func survivesAtomicReplace() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("watcher-\(UUID().uuidString).plist")
        try Data("one".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        // 0.2 s, not 0.05: one atomic replace can emit .write/.attrib/.delete, and a debounce
        // shorter than the gap between them would report a third callback and fail for no real reason.
        let watcher = DockPlistWatcher(path: url.path, debounceInterval: 0.2)
        var callbacks = 0
        watcher.onDockChanged = { callbacks += 1 }
        watcher.startWatching()
        defer { watcher.stopWatching() }

        try Data("two".utf8).write(to: url, options: .atomic)
        try await Task.sleep(nanoseconds: 400_000_000)
        try Data("three".utf8).write(to: url, options: .atomic)
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(callbacks == 2)
    }
}
```

- [ ] **Step 3: Run it — this is the investigation**

Run: `xcodebuild test -project DockTile.xcodeproj -scheme DockTile -configuration Debug -destination 'platform=macOS' -only-testing:DockTileTests/DockPlistWatcherReplaceTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
- **Passes (callbacks == 2):** the suspicion is wrong. Keep Step 1 and the test as a guard, record "watcher survives atomic replace — no fix needed" in the spec, commit, skip Step 4.
- **Fails with callbacks == 1:** root cause confirmed. Continue.

- [ ] **Step 4: Reopen the descriptor when the file is replaced**

Descriptor ownership is the whole difficulty. The existing cancel handler closes `self.fileDescriptor` *when it runs* — asynchronously, after the event handler returns. Re-arming inside the event handler would overwrite that property first, so the old source's cancel handler would close the NEW descriptor and leak the old one: the watcher would go silent again. Each source must therefore close the descriptor it was created with.

In `startWatching()`, replace everything from the `// Create dispatch source to monitor file changes` comment through the end of the `source.setCancelHandler { … }` block with:

```swift
        // Create dispatch source to monitor file changes. `fd` is captured so THIS source closes
        // THIS descriptor, whatever `self.fileDescriptor` has become by the time it is cancelled.
        let fd = fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self, weak source] in
            guard let self else { return }
            let flags = source?.data ?? []
            self.handleFileChange()
            // cfprefsd rewrites the plist by ATOMIC REPLACE: this descriptor now refers to an
            // unlinked inode and every later write goes to a file we are not watching. Re-arm on
            // the path. Clearing `fileDescriptor` first lets `startWatching()` open a fresh one.
            if !flags.isDisjoint(with: [.rename, .delete]) {
                source?.cancel()
                self.dispatchSource = nil
                self.fileDescriptor = -1
                self.startWatching()
            }
        }

        source.setCancelHandler { [weak self] in
            close(fd)
            if self?.fileDescriptor == fd { self?.fileDescriptor = -1 }
        }
```

Run the Step 3 command again. Expected: PASS with `callbacks == 2`. Then the full suite.

- [ ] **Step 5: Commit**

```bash
git add DockTile/Managers/DockPlistWatcher.swift DockTileTests/Unit/Managers/DockPlistWatcherReplaceTests.swift docs/performance-baseline-2026-09.md
git commit -m "fix(dock-watcher): re-arm after an atomic replace so live visibility sync keeps working"
```

---

### Task 11: Prove a shipped update actually updates a user's tiles

Everything in Tasks 3–7 lives in code that gets *copied into* helper bundles. A user who updates gets a new main app and, until the migration regenerates them, tiles still running the old binary. This task proves the regeneration happens, produces working tiles, and leaves them where they were — on the dev tiles, before any of it can reach a real one.

**How the update is simulated:** `CFBundleShortVersionString` is `$(MARKETING_VERSION)` (`DockTile/Resources/Info.plist:19`, `Base.xcconfig:6`), and `classifyForMigration` compares it against each tile's stored `helperAppVersion`. Building the dev app with a bumped `MARKETING_VERSION` therefore reproduces exactly what a Sparkle update does to that comparison, without touching a release build, the production config, or a version-control file.

**Files:** none. This task changes no code; if it finds a defect, that defect is fixed in the task that introduced it.

- [ ] **Step 1: Record the starting state**

```bash
Scripts/perf/prod_fingerprint.sh > /tmp/prod-before-task11.txt
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/Library/Preferences/com.docktile.dev.configs.json'))); print([(c['name'], c.get('helperAppVersion'), c.get('lastDockIndex'), c['isVisibleInDock']) for c in d])"
defaults read com.apple.dock persistent-apps | grep -c "com.docktile.dev"
md5 -q "$HOME/Library/Application Support/DockTile-Dev/Dev Tile.app/Contents/MacOS/Dock Tile Dev.debug.dylib"
```
Note the tile names, their Dock positions, how many dev tiles are pinned, and that dylib checksum — it is how Step 3 proves the helper really got the new binary.

- [ ] **Step 2: Build a "newer version" and let it migrate**

```bash
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug MARKETING_VERSION=2.0.2-perftest build -quiet
codesign --verify "$HOME/Library/Developer/Xcode/DerivedData/DockTile-eogbgouhmcdwdnceyzhaddobxcoy/Build/Products/Debug/Dock Tile Dev.app" && echo SIGNED
swift Scripts/perf/launch_timer.swift "$HOME/Library/Developer/Xcode/DerivedData/DockTile-eogbgouhmcdwdnceyzhaddobxcoy/Build/Products/Debug/Dock Tile Dev.app"
grep -E "\[migration\]|Regenerated|Restarting Dock" "$HOME/Library/Application Support/DockTile-Dev/diagnostics.log" | tail -20
```
Expected: every visible, pinned dev tile is classified stale and regenerated; **one** Dock restart for the whole batch, not one per tile; each regenerated tile relaunched afterwards.

- [ ] **Step 3: Prove the tiles now run the NEW code and still work**

```bash
md5 -q "$HOME/Library/Application Support/DockTile-Dev/Dev Tile.app/Contents/MacOS/Dock Tile Dev.debug.dylib"
md5 -q "$HOME/Library/Developer/Xcode/DerivedData/DockTile-eogbgouhmcdwdnceyzhaddobxcoy/Build/Products/Debug/Dock Tile Dev.debug.dylib"
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/Library/Preferences/com.docktile.dev.configs.json'))); print([(c['name'], c.get('helperAppVersion')) for c in d])"
defaults read com.apple.dock persistent-apps | grep -c "com.docktile.dev"
```
Expected: the two checksums match (the helper carries the new binary — the stub alone is not the code); every regenerated tile is stamped `2.0.2-perftest`; the pinned dev-tile count is unchanged. Then, by hand: each tile's Dock icon looks right and sits where it did, its popover opens, its apps launch, and the icons are the cached bitmaps (Task 4's `Icon cache prewarmed` line appears in the log for each relaunched helper).

- [ ] **Step 4: Prove the mixed-version window is harmless**

This is the state a real user is in between the main app updating and a given tile being regenerated — and the only place Task 2's schema change could bite.

```bash
# A hidden tile is stampOnly, so its bundle keeps the OLD binary while the config is already new.
grep -E "stampOnly|Regenerated|skipUpToDate" "$HOME/Library/Application Support/DockTile-Dev/diagnostics.log" | tail -10
```
With one dev tile hidden before Step 2, confirm it was `stampOnly` (not regenerated), then show it again from Tile Detail and confirm `installHelper` rebuilds it and its popover is correct. Separately, confirm an old-binary helper reading the new blob-less config renders installed apps normally: it is the same helper you just exercised before its rebuild.

- [ ] **Step 5: Restore the real version and re-migrate**

```bash
xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug build -quiet
codesign --verify "$HOME/Library/Developer/Xcode/DerivedData/DockTile-eogbgouhmcdwdnceyzhaddobxcoy/Build/Products/Debug/Dock Tile Dev.app" && echo SIGNED
swift Scripts/perf/launch_timer.swift "$HOME/Library/Developer/Xcode/DerivedData/DockTile-eogbgouhmcdwdnceyzhaddobxcoy/Build/Products/Debug/Dock Tile Dev.app"
```
The dev tiles are now stamped `2.0.2-perftest` against an app reporting `2.0.1`, so they are stale again and regenerate back onto the real build. That asymmetry is the point: the convergent migration heals a *downgrade* too. Confirm one Dock restart and that every tile works.

- [ ] **Step 6: Production untouched**

```bash
Scripts/perf/prod_fingerprint.sh > /tmp/prod-after-task11.txt
diff /tmp/prod-before-task11.txt /tmp/prod-after-task11.txt && echo "PRODUCTION UNTOUCHED"
```
Expected: no diff — same config checksum, same production bundle mtimes and signatures, same Dock entries, same running production helpers. A difference here is a stop-everything finding: two Dock restarts happened in this task, and if either of them re-seated a production entry that is a bug in the Dock code, not a test artefact.

- [ ] **Step 7: Record what a release needs**

Add to the spec, under the results section:

```markdown
### What the release carrying these fixes must do

`MARKETING_VERSION` **must** be bumped in `Base.xcconfig`. Helpers are copies of the main app, and
`classifyForMigration` regenerates a tile only when its stored `helperAppVersion` differs from the
running app's `CFBundleShortVersionString`. Ship the new main app without a version bump and every
existing tile keeps the old popover code — none of these fixes reach a user who already has tiles.
Verified on a simulated bump (Task 11): visible+pinned tiles regenerate in one batch with a single
Dock restart, keep their position and label, and relaunch on the new binary; hidden tiles are
stamped and rebuild when next shown.
```

```bash
git add docs/performance-baseline-2026-09.md
git commit -m "docs(perf): verify the shipped-update path regenerates tiles onto the new code"
```

---

### Task 12: Re-baseline and close the loop

- [ ] **Step 1: Re-run the whole baseline the same way** — plugged in **and** on battery (all three original runs were on battery; record both so later comparisons have a match): dev-helper popover opens after idle and the five-open footprint test; main-app launch / tile select / save / colour drag on the optimised build with the release-sized test config; the batch regeneration. Use `Scripts/perf/README.md`. **Release-helper numbers can only be taken after these fixes ship** (helpers are built by the Release main app, which must not be launched to measure): once Karthik has released and updated, attach to the running Release helpers exactly as the baseline did and add those rows then.

- [ ] **Step 2: Write `docs/performance-baseline-<date>.json`** in the same shape as `docs/performance-baseline-2026-09.json`, and add a *Results after fixes* section to the spec that leads with what moved, then the full table. A change counts only when it exceeds the combined spread of the two runs.

- [ ] **Step 3: Add the new seams to `.claude/rules/testing.md`'s "Existing seams" list**: `SaveDebounce.waitedFullInterval`, `HelperAppDelegate.showInAppSwitcher(inConfigAt:bundleId:)`, `TileIconRasterCache` (+ `pixelSize`, `appearanceToken`, `AppIconLoader.modificationStamp`), `FloatingPanel.shouldAnimate`, `IconCompiler.compileOffMain`, `DiagnosticsLog.singleLine` / `.trimmed`, `DockPlistWatcher(path:debounceInterval:)`. Add a pointer to `Scripts/perf/README.md` from `.claude/rules/diagnostics.md`.

- [ ] **Step 4: Commit the re-baseline**

```bash
git add docs/performance-baseline-2026-09.md docs/performance-baseline-*.json .claude/rules/testing.md .claude/rules/diagnostics.md
git commit -m "docs(perf): post-fix baseline, new seams recorded in the testing rule"
```

- [ ] **Step 5: `stage-gate --dev`, then hand the go/no-go to Karthik** before any tag.

---

## Deferred — not in this plan, and why

Each of these came from source review only (▲ in the spec). None has a measurement, so optimising them now would be guessing; measure first if they matter.

- Dock reads parsing every foreign Dock entry's `Info.plist` (`HelperBundleManager.findInDock` and siblings).
- Smart Add: Spotlight harvest on the main thread at launch; launch log written on every app activation.
- Launch-time helper-folder scans (`findExistingHelper` called twice per pinned tile in self-heal).
- `onChange(of: configManager.configurations)` in Tile Detail comparing whole configs (`DockTileDetailView.swift:239`): Task 2 removes the icon bytes that made that comparison expensive; Task 8's re-measurement shows whether anything is left.
- The other synchronous waits in helper generation (`iconutil`, `killall Dock`, the legacy four-variant bake on macOS 15): the measured ~1 s block is the compile; Task 7 Step 6 records whatever remains.
- Full Firebase initialisation in every helper.
- SpinWatchdog timer leeway.
- The duplicated Launch Services lookup per popover cell (`AppInstallChecker.resolve` then `AppIconLoader.icon`): after Task 4 the loader runs only on a cache miss, so this largely disappears on its own — re-check in Task 11.
- Dock Lock's event tap on the main run loop — unmeasured until the dev app is granted Accessibility.
- The July 2026 helper CPU spin — still no evidence; the SpinWatchdog capture remains the instrument.

## Self-review

- **Spec coverage:** the spec's revised plan order maps as — icon cache → Task 4; reuse one popover / `animates` / monitor leak → Tasks 5–6; cancel Customise debounce → Task 1; compile/sign off main → Task 7; icon blobs out of config → Task 2; helper reads own config path → Task 3 (the single-tile read is dropped as unnecessary once Task 2 lands, stated in the task); re-measure tile selection → Task 8; diagnostics-log stray lines → Task 9; Dock watcher → Task 10. The remaining source-review findings are listed under *Deferred* with their reasons. The Dock watcher is the one source-review item promoted into a task, because it is a suspected correctness bug that a single cheap test settles either way.
- **Root cause before fix:** Tasks 1, 2, 3, 5, 7, 9 cite measured or code-verified causes. Task 4 states a hypothesis and makes its measurement the test of it. Tasks 6 and 10 begin with evidence gathering and have an explicit stop condition. Task 8 forbids fixing from this plan.
- **Type consistency:** `TileIconRasterCache.image(for:pointSize:scale:appearanceToken:contentStamp:)` is used with the same labels in Task 4's tests, grid cell, list row and prewarm. `removeEventMonitors()` and `shouldAnimate(tier:reduceMotion:)` are defined in Task 5 and consumed in Task 6. `LauncherView(configuration:openGeneration:)` is defined and used in Task 6 only. `compileOffMain`, async `codesignHelper`, async `installTileIcons` and async `installDeclarativeIcon` are defined and consumed in Task 7.
- **Ordering:** tasks are independent except 6 → 5. Task 2 before Task 8's re-measurement; Task 0 before everything; Task 11 after every helper-code task (3–7), since it exercises the path they all ship through.
- **Production safety:** stated as a global constraint, given a runnable check in Task 0 (`prod_fingerprint.sh`), and enforced at both ends of Task 11 — the only task that deliberately restarts the Dock.
