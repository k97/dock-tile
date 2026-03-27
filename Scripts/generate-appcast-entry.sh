#!/bin/bash
#
# generate-appcast-entry.sh
# Generates or updates the Sparkle appcast.xml with a new release entry.
# Inserts newest entry at the TOP of the channel (after <language>).
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

# Write the new item to a temp file
ITEM_FILE=$(mktemp)
cat > "$ITEM_FILE" << ITEM_EOF
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url="${DMG_URL}"
        sparkle:edSignature="${SIGNATURE}"
        length="${SIZE}"
        type="application/octet-stream" />
    </item>
ITEM_EOF

if [[ -f "$OUTPUT" ]] && grep -q "<language>" "$OUTPUT"; then
    # Insert new item after the <language> line (newest first)
    # Uses awk with file read to handle multi-line content correctly
    awk -v itemfile="$ITEM_FILE" '
        /<language>/ {
            print
            while ((getline line < itemfile) > 0) print line
            close(itemfile)
            next
        }
        { print }
    ' "$OUTPUT" > "${OUTPUT}.tmp"
    mv "${OUTPUT}.tmp" "$OUTPUT"
else
    # Create new appcast from scratch
    cat > "$OUTPUT" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>DockTile Updates</title>
    <link>https://docktile.rkarthik.co/appcast.xml</link>
    <description>Most recent changes with links to updates for DockTile.</description>
    <language>en</language>
$(cat "$ITEM_FILE")
  </channel>
</rss>
APPCAST_EOF
fi

rm -f "$ITEM_FILE"

# Validate XML structure
if command -v xmllint &> /dev/null; then
    if xmllint --noout "$OUTPUT" 2>/dev/null; then
        echo "XML validation: OK"
    else
        echo "WARNING: XML validation failed"
    fi
fi

echo "Appcast updated: ${OUTPUT}"
echo "  Version: ${VERSION} (build ${BUILD})"
echo "  URL: ${DMG_URL}"
echo "  Size: ${SIZE} bytes"
