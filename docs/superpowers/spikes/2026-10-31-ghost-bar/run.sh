#!/bin/bash
# THROWAWAY SPIKE run: capture the Dock window (by ID, never a screen rect) before, during and after the bar.
# Usage: run.sh <tag>   (mode comes from mode.txt beside the app: accessory | switch)
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
TAG=$1
# Compile the Dock tool once so capture timing does not drift with `swift` start-up (seconds on CI).
[ -x "$D/dockctl" ] || swiftc -O -o "$D/dockctl" "$D/dock.swift" || exit 1
cap() {
  WID=$("$D/dockctl" wid)
  if [ "$WID" = "-1" ]; then echo "$(date +%T) $1: NO DOCK WINDOW"; return; fi
  screencapture -x -o -l"$WID" "$D/cap-$TAG-$1.png" && echo "$(date +%T) captured $1 (wid $WID)"
}
rm -f "$D/spike.log"
sleep 4
"$D/dockctl" check
cap 0-before
open -g "$D/GhostBarSpike.app"
sleep 6;  cap 1-early      # app waits 3 s, then 1 step/s for 15 s: bar ~3/15
sleep 5;  cap 2-mid        # ~8/15
sleep 5;  cap 3-late       # ~13/15
sleep 6;  cap 4-after      # cleared
pkill -f GhostBarSpike.app/Contents/MacOS/GhostBarSpike
echo "--- log ($TAG)"; cat "$D/spike.log"
echo "--- md5 ($TAG)"; md5 -r "$D"/cap-"$TAG"-*.png
