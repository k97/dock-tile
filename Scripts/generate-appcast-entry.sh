#!/bin/bash
#
# generate-appcast-entry.sh
# Generates or updates the Sparkle appcast.xml with a new release entry.
#
# Usage:
#   ./Scripts/generate-appcast-entry.sh \
#     --version 1.1.0 \
#     --build 2 \
#     --dmg-url "https://github.com/k97/dock-tile/releases/download/v1.1.0/DockTile-1.1.0.dmg" \
#     --signature "BASE64_EDDSA_SIGNATURE" \
#     --size 12345678 \
#     --pub-date "Wed, 01 Apr 2026 12:00:00 +0000" \
#     --output website/public/appcast.xml

set -euo pipefail

VERSION=""
BUILD=""
DMG_URL=""
SIGNATURE=""
SIZE=""
PUB_DATE=""
OUTPUT="website/public/appcast.xml"
MIN_OS="15.0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --build) BUILD="$2"; shift 2 ;;
        --dmg-url) DMG_URL="$2"; shift 2 ;;
        --signature) SIGNATURE="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        --pub-date) PUB_DATE="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --min-os) MIN_OS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$VERSION" || -z "$BUILD" || -z "$DMG_URL" || -z "$SIGNATURE" || -z "$SIZE" ]]; then
    echo "Error: --version, --build, --dmg-url, --signature, and --size are required"
    exit 1
fi

if [[ -z "$PUB_DATE" ]]; then
    PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
fi

# Generate the new item XML
NEW_ITEM="    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url=\"${DMG_URL}\"
        sparkle:edSignature=\"${SIGNATURE}\"
        length=\"${SIZE}\"
        type=\"application/octet-stream\" />
    </item>"

# Check if the appcast file exists and has items
if [[ -f "$OUTPUT" ]] && grep -q "</channel>" "$OUTPUT"; then
    # Insert new item before </channel> (newest first)
    # Use a temp file for portable sed
    TEMP_FILE=$(mktemp)
    awk -v item="$NEW_ITEM" '
        /<\/channel>/ { print item; }
        { print; }
    ' "$OUTPUT" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$OUTPUT"
else
    # Create new appcast
    cat > "$OUTPUT" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>DockTile Updates</title>
    <link>https://docktile.rkarthik.co/appcast.xml</link>
    <description>Most recent changes with links to updates for DockTile.</description>
    <language>en</language>
${NEW_ITEM}
  </channel>
</rss>
APPCAST_EOF
fi

echo "Appcast updated: ${OUTPUT}"
echo "  Version: ${VERSION} (build ${BUILD})"
echo "  URL: ${DMG_URL}"
echo "  Size: ${SIZE} bytes"
