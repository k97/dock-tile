#!/bin/zsh
# Capture the running dev app's main window to build/captures/<label>.png.
# Usage: Scripts/dev-capture.sh <label> [--row "General"] [--click X,Y] [--dark]
#   --row   selects the sidebar row by its accessibility name via the AX "select" action on the row
#           (AXPress on the row's static-text label is a no-op in this app's SwiftUI List).
#   --click clicks a window-relative point (pt) — the fallback when --row finds nothing; sidebar rows
#           sit at x≈60 and y≈ 84 + 32·index (measure once off a capture).
# Requires: the terminal has Accessibility + Automation (System Events) access.
set -euo pipefail
LABEL=${1:?label}; shift
ROW=""; CLICK=""; DARK=0
while [[ $# -gt 0 ]]; do case "$1" in --row) ROW="$2"; shift 2;; --click) CLICK="$2"; shift 2;; --dark) DARK=1; shift;; *) echo "unknown $1"; exit 2;; esac; done
APP_DIR=$(xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
APP="$APP_DIR/Dock Tile Dev.app"
mkdir -p build/captures
open -a "$APP"; sleep 1.5
# Target this exact bundle's PID, not the bare process name — a second "Dock Tile Dev" (another
# worktree's dev build) can be running concurrently, and System Events' name-based "tell process"
# resolves ambiguously between them, silently landing on the wrong instance's window.
PID=$(pgrep -f "$APP/Contents/MacOS/Dock Tile Dev" | head -1)
# "tell (first process whose unix id is X)" used directly keeps a dynamic AppleScript specifier
# that breaks "entire contents" queries below — resolve it into a plain variable first.
osascript -e "tell application \"System Events\"" -e "set p to first process whose unix id is $PID" -e "tell p to set frontmost to true" -e "end tell" >/dev/null
if [[ -n "$ROW" ]]; then
  ROW_RESULT=$(osascript <<EOS
tell application "System Events"
  set p to first process whose unix id is $PID
  set foundRow to false
  tell p
  set winContents to entire contents of window 1
  set outlineEl to missing value
  repeat with e in winContents
    try
      if (class of e as string) is "outline" then
        set outlineEl to e
        exit repeat
      end if
    end try
  end repeat
  if outlineEl is not missing value then
    set rowCount to count of rows of outlineEl
    repeat with i from 1 to rowCount
      set r to row i of outlineEl
      set rowContents to entire contents of r
      set matched to false
      repeat with elem in rowContents
        try
          if (name of elem as string) is "$ROW" then
            set matched to true
          end if
        end try
      end repeat
      if matched then
        select r
        set foundRow to true
        exit repeat
      end if
    end repeat
  end if
  end tell
  if foundRow then
    "matched"
  else
    "nomatch"
  end if
end tell
EOS
)
  if [[ "$ROW_RESULT" != "matched" ]]; then
    echo "abort: no sidebar row named \"$ROW\""
    exit 4
  fi
  sleep 0.8
fi
if [[ -n "$CLICK" ]]; then
  P=$(osascript -e "tell application \"System Events\"" -e "set p to first process whose unix id is $PID" -e "tell p to get position of window 1" -e "end tell" | tr -d ' ')
  osascript -e "tell application \"System Events\" to click at {$(( ${P%%,*} + ${CLICK%%,*} )), $(( ${P#*,} + ${CLICK#*,} ))}" >/dev/null
  sleep 0.8
fi
restore_dark() { osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" >/dev/null; }
WAS_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
SUFFIX=""
# A trap, not just the explicit calls below: every failure between here and the capture — a dead
# osascript, an unreadable window, a Ctrl-C — used to leave the user's Mac stuck in Dark Mode.
if [[ $DARK -eq 1 && "$WAS_DARK" == "false" ]]; then
  trap 'restore_dark false' EXIT INT TERM
  restore_dark true; SUFFIX="-dark"; sleep 1.2
fi
open -a "$APP"
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID) to set frontmost to true" >/dev/null
sleep 0.4
# Capture by CGWindowID, NOT by screen rectangle. A rect capture races with focus: between reading
# the frame and the shutter firing, anything can come forward, and the shutter then photographs
# whatever sits at those coordinates — which has grabbed unrelated windows, including private ones,
# four times in this project. A frontmost check before the capture does not close that race.
# A window id belongs to one window owned by one PID and cannot photograph another.
WID=$(swift "$(dirname "$0")/window-id.swift" "$PID" 2>/dev/null | tail -1)
if [[ -z "$WID" || "$WID" == "0" ]]; then
  echo "abort: no on-screen window for pid $PID"
  exit 3
fi
screencapture -x -o -l"$WID" "build/captures/$LABEL$SUFFIX.png"
if [[ $DARK -eq 1 && "$WAS_DARK" == "false" ]]; then restore_dark false; fi
echo "build/captures/$LABEL$SUFFIX.png"
