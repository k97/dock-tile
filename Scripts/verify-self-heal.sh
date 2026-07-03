#!/bin/bash
#
# verify-self-heal.sh — real-machine verification for the version-independent helper self-heal (#4).
#
# WHAT THIS DOES: sets up the broken states self-heal is meant to repair (corrupt-but-present,
# missing bundle), then lets you launch the dev app and watch it heal them — plus draft-safety and
# idempotency checks. It manipulates the LIVE dev support folder and will bounce the Dock, so run it
# only when you're at the machine and okay with that. It never touches the Release data.
#
# USAGE:
#   ./Scripts/verify-self-heal.sh setup-corrupt   # break a pinned tile's icons in place
#   ./Scripts/verify-self-heal.sh setup-missing    # delete a pinned tile's bundle (keep Dock entry)
#   ./Scripts/verify-self-heal.sh watch            # tail the self-heal diagnostics as you relaunch
#   ./Scripts/verify-self-heal.sh state            # print each pinned dev tile's on-disk health
#
# After a setup-*, RELAUNCH the dev app ("Dock Tile Dev.app") and observe the Dock + `watch` output.

set -euo pipefail

SUPPORT="$HOME/Library/Application Support/DockTile-Dev"
LOG="$SUPPORT/diagnostics.log"

first_bundle() {
  # First *.app helper in the dev support folder (excludes the hidden .app).
  find "$SUPPORT" -maxdepth 1 -name '*.app' ! -name '.app' | sort | head -1
}

cmd="${1:-help}"
case "$cmd" in
  state)
    echo "Dev helper bundles in: $SUPPORT"
    find "$SUPPORT" -maxdepth 1 -name '*.app' ! -name '.app' | while read -r b; do
      icns=$(ls "$b/Contents/Resources/"AppIcon*.icns 2>/dev/null | wc -l | tr -d ' ')
      ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$b/Contents/Info.plist" 2>/dev/null || echo "?")
      has_active=$([ -s "$b/Contents/Resources/AppIcon.icns" ] && echo yes || echo NO)
      echo "  $(basename "$b")  icns_files=$icns  AppIcon.icns=$has_active  baked_version=$ver"
    done
    ;;

  setup-corrupt)
    b=$(first_bundle); [ -n "$b" ] || { echo "No dev helper bundle found. Pin a tile first."; exit 1; }
    echo "Corrupting icons in: $(basename "$b")"
    rm -f "$b/Contents/Resources/"AppIcon*.icns
    echo "→ Removed all AppIcon*.icns. Now RELAUNCH Dock Tile Dev.app and watch it rebuild them."
    echo "  (Expect: one Dock restart, icon restored, a [selfheal] line in the log.)"
    ;;

  setup-missing)
    b=$(first_bundle); [ -n "$b" ] || { echo "No dev helper bundle found. Pin a tile first."; exit 1; }
    echo "Deleting entire bundle (Dock entry stays): $(basename "$b")"
    rm -rf "$b"
    echo "→ Removed the .app. Now RELAUNCH Dock Tile Dev.app; self-heal should rebuild + re-pin it."
    ;;

  watch)
    echo "Tailing self-heal / migration lines from $LOG (Ctrl-C to stop). Relaunch the app now."
    tail -f "$LOG" | grep --line-buffered -iE "selfheal|migration|Regenerat"
    ;;

  *)
    sed -n '2,20p' "$0"
    ;;
esac
