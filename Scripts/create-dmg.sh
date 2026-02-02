#!/bin/bash
#
# create-dmg.sh - Create a DMG installer for DockTile
#
# Usage: ./Scripts/create-dmg.sh [--app-path PATH] [--output-dir DIR] [--version VERSION]
#
# This script creates a distributable DMG file with the app and an Applications symlink.
# For a prettier DMG with background image, consider using create-dmg npm package.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Defaults
APP_NAME="DockTile"
APP_PATH=""
OUTPUT_DIR="./build"
VERSION=""
VOLUME_NAME="DockTile"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--app-path PATH] [--output-dir DIR] [--version VERSION]"
            echo ""
            echo "Options:"
            echo "  --app-path    Path to DockTile.app (default: auto-detect from DerivedData)"
            echo "  --output-dir  Output directory for DMG (default: ./build)"
            echo "  --version     Version string for DMG filename (default: from Info.plist)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}=== DockTile DMG Creator ===${NC}"

# Find app if not specified
if [[ -z "$APP_PATH" ]]; then
    echo "Searching for DockTile.app..."

    # Try common locations
    DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "DockTile-*" -type d 2>/dev/null | head -1)

    if [[ -n "$DERIVED_DATA_PATH" ]]; then
        APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
    fi

    # Try local build directory
    if [[ ! -d "$APP_PATH" ]]; then
        APP_PATH="./build/Build/Products/Release/$APP_NAME.app"
    fi
fi

# Verify app exists
if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${RED}Error: Cannot find $APP_NAME.app${NC}"
    echo "Please specify path with --app-path or build the app first:"
    echo "  xcodebuild -project DockTile.xcodeproj -scheme DockTile -configuration Release build"
    exit 1
fi

echo -e "Found app: ${GREEN}$APP_PATH${NC}"

# Get version from Info.plist if not specified
if [[ -z "$VERSION" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0")
fi

echo "Version: $VERSION"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Set up DMG filename and temp directory
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
TEMP_DIR=$(mktemp -d)
DMG_CONTENTS="$TEMP_DIR/dmg-contents"

echo "Creating DMG contents..."

# Create directory structure
mkdir -p "$DMG_CONTENTS"

# Copy app
cp -R "$APP_PATH" "$DMG_CONTENTS/"

# Create Applications symlink
ln -s /Applications "$DMG_CONTENTS/Applications"

# Remove existing DMG if present
rm -f "$DMG_PATH"

echo "Creating DMG..."

# Create DMG using hdiutil
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_CONTENTS" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Cleanup temp directory
rm -rf "$TEMP_DIR"

# Generate checksum
echo "Generating checksum..."
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

# Print results
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo -e "${GREEN}=== DMG Created Successfully ===${NC}"
echo "  File: $DMG_PATH"
echo "  Size: $DMG_SIZE"
echo "  SHA256: $(cat "$DMG_PATH.sha256" | cut -d' ' -f1)"
echo ""
echo "Next steps:"
echo "  1. Sign the DMG (if not already signed)"
echo "  2. Notarize with: ./Scripts/notarize.sh --dmg-path $DMG_PATH"
