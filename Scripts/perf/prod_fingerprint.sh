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
plutil -convert json -o - "$HOME/Library/Preferences/com.apple.dock.plist" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("dock       UNREADABLE")
    raise SystemExit(0)
for e in d.get("persistent-apps", []):
    td = e.get("tile-data", {})
    bid = td.get("bundle-identifier", "")
    if bid.startswith("com.docktile.") and not bid.startswith("com.docktile.dev."):
        url = td.get("file-data", {}).get("_CFURLString", "")
        print("dock       " + bid + "  GUID=" + str(e.get("GUID")) + "  label=" + str(td.get("file-label")) + "  url=" + url)
'
echo "helpers    $(pgrep -f 'Application Support/DockTile/' | tr '\n' ' ')"
