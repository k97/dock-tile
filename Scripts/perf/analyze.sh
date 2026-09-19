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
