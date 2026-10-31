#!/bin/bash
# THROWAWAY SPIKE run: capture the Dock window (by ID, never a screen rect) before, during and after the bar.
# Usage: run.sh <tag>
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
TAG=$1
cap() {
  WID=$(swift "$D/dock.swift" wid)
  if [ "$WID" = "-1" ]; then echo "$(date +%T) $1: NO DOCK WINDOW"; return; fi
  screencapture -x -o -l"$WID" "$D/cap-$TAG-$1.png" && echo "$(date +%T) captured $1 (wid $WID)"
}
sleep 4
swift "$D/dock.swift" check
cap 0-before
open -g "$D/GhostBarSpike.app"
sleep 6;  cap 1-early      # bar ~3/15
sleep 5;  cap 2-mid        # bar ~8/15
sleep 5;  cap 3-late       # bar ~13/15
sleep 6;  cap 4-after      # cleared
osascript -e 'tell application id "com.k97.spike.ghostbar" to quit' >/dev/null 2>&1
sleep 1; pkill -f GhostBarSpike.app/Contents/MacOS/GhostBarSpike
echo "--- log"; cat "$D/spike.log"
