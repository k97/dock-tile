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
# Dock entries for production tiles: id, on-disk path and tooltip label — all three are
# documented invariants (architecture.md: same-name disambiguation, `dockFileLabel`).
defaults read com.apple.dock persistent-apps 2>/dev/null | grep -A8 '"com.docktile\.[0-9A-F]' | grep -E '"bundle-identifier"|"file-label"|_CFURLString' | sed 's/^ *//' | sed 's/^/dock       /'
echo "helpers    $(pgrep -f 'Application Support/DockTile/' | tr '\n' ' ')"
