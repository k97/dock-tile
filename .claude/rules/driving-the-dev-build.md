# Driving & Capturing the Dev Build

How to verify UI work against the running Debug app. Both rules below were paid for in real
incidents, not theory.

## Capture the window by ID, never by screen rect (critical — privacy)

`screencapture -R "$X,$Y,$W,$H"` races with focus: between reading the window's frame and the
shutter firing, anything can come forward, and the shutter photographs whatever occupies those
coordinates. In this project that has grabbed unrelated windows **four times**, once the user's
private messaging app and once an editor full of unrelated text. A frontmost-PID check before the
capture does **not** close the race.

Capture by `CGWindowID` instead — it targets one window owned by one PID and cannot photograph
another, whatever is in front:

```bash
WID=$(swift Scripts/window-id.swift "$PID")   # largest on-screen window for that PID
screencapture -x -o -l"$WID" out.png
```

`Scripts/dev-capture.sh` does this. Delete any mis-capture immediately and never read it.

## Never bring the app frontmost while the owner may be typing

`Scripts/dev-capture.sh` sets the dev app frontmost. On 2026-10-17 that moved the owner's live
keystrokes into the focused tile-name field (they did not save, luckily). A window-ID capture
does not need the app in front: select sidebar rows through AX (`set selected of row N …`) and
capture by `CGWindowID` with the app in the background. Bring it forward only when the owner
says they are away from the keyboard.

A dev window on another Space (2026-10-28) has no AX window (`count windows` = 0) and is missing
from `Scripts/window-id.swift`'s on-screen list, yet `screencapture -l<id>` still captures it: find
the id with `CGWindowListCopyWindowInfo([.optionAll], …)` filtered by PID. Switching
`AppleLanguages` to a non-English language shows the one-time translation alert, which blocks
`quit` (-128); with the alert unreachable, `kill -TERM` the dev instance (no pending edits) instead.

## Press NSAlert buttons by name, never by index

An NSAlert with long button titles stacks its buttons vertically, and the accessibility order
changes with it: the invitation alert lists Later first in Chinese/Japanese (side by side) but
"Help Improve" first in German/Russian/French (stacked). A capture script that pressed
`button 1 of window 1` opened GitHub in the owner's browser three times on 2026-10-18. Read
`name of every button of window 1` and click the one you mean by its localized name.

## AX: use the single-`to` form

System Events answers `tell application "System Events" to tell (first process whose unix id is N)
to <one statement>` reliably. The multi-statement `tell p … end tell` block form intermittently
fails with *"Can't get window 1 … Invalid index (-1719)"* on the same window it just resolved.
Prefer one statement per `osascript` call and parse in the shell.

Paths (re-measured 2026-10-30 — the inspector added a split level, so the 2.4-era paths fail with
-1719). With `S` = `splitter group 1 of group 1 of splitter group 1 of group 1 of window 1`:
- sidebar rows: `row N of outline 1 of scroll area 1 of group 1 of S`; read labels with
  `value of static text 1 of UI element 1 of every row of …` and pick N by label — indices shift as
  tiles are added or deleted (`set selected of row N … to true` selects; `click at {x,y}` often does nothing);
- detail pane: `scroll area 1 of group 2 of S` (tile name = `text field 1`, Show Tile = `checkbox 1`);
  a Settings pane nests one `group 1` deeper;
- toolbar: `UI element N of toolbar 1 of window 1`, chosen by `description` (Update / Add to Dock /
  Remove from Dock is the 5th, Delete Tile the 4th); a confirmation sheet's buttons are matched by
  `description` (`whose description is "Delete"`), never by index.

Quirks paid for in the 2.6.2 hands-on:
- **The window drops out of AX** (`count windows` = 0) right after launch and after some Dock restarts,
  while CG still lists it on screen. Re-count before every click; a click in that state is silently lost.
- **Setting a text field's value reaches the SwiftUI binding only when the field is focused**: `set
  focused of text field 1 … to true` first, then read the SAVED config before pressing anything — an
  unfocused set changed the field's text while Update built the old name.
- **`open -g` on the running app reopens the SAME `Window`**, so the window `.task` does not re-run;
  closing + reopening this way cannot exercise once-per-launch logic.
- Compound shell commands with `$(…)` captures are refused by the permission layer; put such
  sequences in a scratch script with literal paths and run that.

## Find the dev app's PID by its .app path

Every dev Dock tile's helper is a copy of the dev app with the same executable name (`Dock Tile
Dev`), so `pgrep -f "/MacOS/Dock Tile Dev"` can return a helper — a process with no window. Match
`pgrep -f "Dock Tile Dev\.app/Contents/MacOS/Dock Tile Dev( |$)"` (launch arguments follow the
path). On 2026-10-22 a whole benchmark race drove a helper and every run came back NO SIDEBAR —
that, not the launch, is the likely source of an older "`open -g` restores no window" note: on
2026-10-23 every `open -g` launch (saved state, `-ApplePersistenceIgnoreState YES`, after a
windowless quit) presented the window (#29). Count windows by PID with `CGWindowListCopyWindowInfo`.

## Hands-on evidence comes from the dev log, not the owner's eyes

- **Prod and dev windows look alike.** The owner runs prod (Dock Lock on) beside dev; on 2026-10-23
  two "done" steps landed in the prod window. Confirm each step from the dev log's `[main <pid>] [ui]`
  lines (Release drops `ui` lines, so a click in prod leaves no trace), or quit prod first.
- **Prove a timing race with an uncommitted experiment build**, not human speed: stretch the interval
  (the 300 ms save debounce → 5 s), add log lines, act, read the log and the config, then
  `git checkout` the experiment away. A human ⌘Q "instantly" is ~300 ms and proved nothing for #30.
  Gate each experiment behind a `defaults write com.docktile.dev.app <key>` read at the call site, so
  one build serves several cases (2.6.3: an 8 s build stretch and a forced signing failure); delete
  the keys with the checkout.
- **The dev log also holds test-run lines.** The test host is the dev app, so a suite run writes
  deliberate failures ("Swap FAILED … /T/HelperSwapTests-…", "compile tile car FAILED") into the same
  `diagnostics.log`, and a relaunch's trim replays them to a `tail -F`. Read only lines from the
  running dev app's `[main <pid>]` / helper pids.

## The test host is the dev app

`xcodebuild test` launches the real Debug app against the user's **live dev** config and Dock.
Tests that construct a `ConfigurationManager` create and delete real tiles (cleanup rides on a
`defer`). Expect dev tiles to appear and vanish during a test run; never point a test at the
Release config. See [testing.md](testing.md) "Test-host guard".

## Rebuild SIGNED after any test run (SMAppService)

`xcodebuild test` (per CLAUDE.md) passes `CODE_SIGNING_ALLOWED=NO`, and tests share the Debug
product with the app you launch — so after a test run the product is only **linker-signed**
(`codesign --verify` fails: "code has no resources…"). `SMAppService` then refuses to register
the login launcher agent with error **-67056**: "Start tiles at login" reads OFF, toggling it
silently snaps back, and `reconcileOnLaunch` fails every launch (found 2026-09-02). Before
launching or handing over a dev build: rebuild **without** that flag and gate on

```bash
codesign --verify "$APP" || echo "UNSIGNED — do not launch"
```

## Delete a worktree's DerivedData when you delete the worktree

Every git worktree gets its own `DockTile-<hash>` DerivedData, and a leftover product is live
ammunition: the popover gear's deep link scans `DockTile-*` for a dev build, and on 2026-09-06 it
launched a weeks-old worktree product whose self-heal "repaired" current-format helpers into its
own older format — a regeneration ping-pong that restarted the Dock on every launch. The picker
now resolves the newest product by binary mtime (`findDockTileInDerivedData`), but stale products
still waste gigabytes and can be resolved by Launch Services elsewhere. When removing a worktree:
`rm -rf ~/Library/Developer/Xcode/DerivedData/DockTile-<its hash>`.

## The Debug binary is a stub — app code lives in the debug dylib

The Debug product's executable (`Contents/MacOS/Dock Tile Dev`, ~58 KB) is a thin loader; all
app code is in `Dock Tile Dev.debug.dylib` beside it (Xcode's debug-dylib linking). Hand-patching
a dev helper bundle by copying only the executable silently runs the OLD code — the 2026-09-07
issue-#12 live verification "failed" exactly this way until both files were copied (then
`codesign --force --sign -` to re-seal). Copy stub + dylib together, and verify with
`md5 -q` against the built product, not by assuming `cp` sufficed.

## A rebuild does not reach existing dev tiles

Launch migration regenerates a helper only when `CFBundleShortVersionString` changes
(`HelperBundleManager.currentAppVersion`), so a code-only rebuild leaves every dev tile on old code.
Use the tile's **Update**, or swap stub + dylib as above, then confirm with `nm … | grep <new symbol>`
(rebuilds are not byte-identical, so `md5` against an older copy proves nothing). Look the helper up
with `ls` first: renaming a tile renames its folder (`Dev Tile.app` → `Dev.app`), and a hard-coded
path silently misses it.

## Read hands-on evidence before relaunching the main app

The main app trims `diagnostics.log` to the last hour on every launch (`prepareOnLaunch`), so a
gate run's `ui` lines vanish once the dev app is relaunched or a day passes — the #17 G6/G7 evidence
was lost this way. Tail the log (a Monitor on `tail -F`) while the user tests, or read it right
after. TCC behaviour is the exception: tccd's history stays in `/usr/bin/log show` (`log` alone is
a zsh builtin and fails).
