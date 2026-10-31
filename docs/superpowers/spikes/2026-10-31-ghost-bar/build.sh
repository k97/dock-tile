#!/bin/bash
# THROWAWAY SPIKE build: GhostBarSpike.app (LSUIElement, ad-hoc signed). Not a Dock Tile bundle id.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
APP="$D/GhostBarSpike.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.k97.spike.ghostbar</string>
  <key>CFBundleName</key><string>GhostBarSpike</string>
  <key>CFBundleExecutable</key><string>GhostBarSpike</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
swiftc -O -o "$APP/Contents/MacOS/GhostBarSpike" "$D/main.swift" -framework AppKit
codesign --force --sign - "$APP"
codesign --verify "$APP" && echo "BUILT+SIGNED $APP"
