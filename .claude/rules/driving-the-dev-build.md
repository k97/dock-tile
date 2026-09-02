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

## AX: use the single-`to` form

System Events answers `tell application "System Events" to tell (first process whose unix id is N)
to <one statement>` reliably. The multi-statement `tell p … end tell` block form intermittently
fails with *"Can't get window 1 … Invalid index (-1719)"* on the same window it just resolved.
Prefer one statement per `osascript` call and parse in the shell.

Useful reads (all read-only, no clicking needed):
`position/size of window 1` · `description of every UI element of toolbar 1 of window 1` ·
`size of every checkbox of scroll area 1 of group 2 of splitter group 1 of group 1 of window 1` ·
`set selected of row N of outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of
window 1 to true` (selects a sidebar row — `click at {x,y}` frequently does nothing here).

## The test host is the dev app

`xcodebuild test` launches the real Debug app against the user's **live dev** config and Dock.
Tests that construct a `ConfigurationManager` create and delete real tiles (cleanup rides on a
`defer`). Expect dev tiles to appear and vanish during a test run; never point a test at the
Release config. See [testing.md](testing.md) "Test-host guard".
