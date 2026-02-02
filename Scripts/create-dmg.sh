#!/bin/bash
#
# create-dmg.sh - Create a professional DMG installer for Dock Tile
#
# Usage: ./Scripts/create-dmg.sh [--app-path PATH] [--output-dir DIR] [--version VERSION]
#
# This script creates a distributable DMG file with:
# - Custom background image with drag-to-Applications guidance
# - Properly positioned icons
# - Applications symlink for easy installation
#
# Requires: create-dmg (brew install create-dmg)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Defaults
APP_NAME="Dock Tile"
APP_NAME_NO_SPACE="DockTile"  # For DMG filename (no spaces)
APP_PATH=""
OUTPUT_DIR="./build"
VERSION=""
VOLUME_NAME="Dock Tile"

# Script directory for finding resources
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKGROUND_IMAGE="$PROJECT_ROOT/DockTile/Resources/dmg-background.png"

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

echo -e "${GREEN}=== Dock Tile DMG Creator ===${NC}"

# Check for create-dmg tool
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}create-dmg not found. Installing via Homebrew...${NC}"
    if command -v brew &> /dev/null; then
        brew install create-dmg
    else
        echo -e "${RED}Error: Homebrew not found. Please install create-dmg manually:${NC}"
        echo "  brew install create-dmg"
        exit 1
    fi
fi

# Find app if not specified
if [[ -z "$APP_PATH" ]]; then
    echo "Searching for DockTile.app..."

    # Try common locations
    DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "DockTile-*" -type d 2>/dev/null | head -1)

    if [[ -n "$DERIVED_DATA_PATH" ]]; then
        APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/${APP_NAME}.app"
    fi

    # Try local build directory
    if [[ ! -d "$APP_PATH" ]]; then
        APP_PATH="./build/Build/Products/Release/${APP_NAME}.app"
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

# Verify background image exists
if [[ ! -f "$BACKGROUND_IMAGE" ]]; then
    echo -e "${YELLOW}Warning: Background image not found at $BACKGROUND_IMAGE${NC}"
    echo "Attempting to generate it..."

    if [[ -f "$SCRIPT_DIR/generate-dmg-background.swift" ]]; then
        cd "$PROJECT_ROOT"
        swift "$SCRIPT_DIR/generate-dmg-background.swift"
        cd - > /dev/null
    else
        echo -e "${RED}Error: Cannot find generate-dmg-background.swift${NC}"
        echo "Creating DMG without background image..."
        BACKGROUND_IMAGE=""
    fi
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Set up DMG filename (use no-space version for filename)
DMG_NAME="${APP_NAME_NO_SPACE}-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Remove existing DMG if present
rm -f "$DMG_PATH"

echo "Creating DMG with professional layout..."

# Build create-dmg command
CREATE_DMG_ARGS=(
    --volname "$VOLUME_NAME"
    --window-pos 200 120
    --window-size 800 400
    --icon-size 128
    --icon "${APP_NAME}.app" 200 190
    --hide-extension "${APP_NAME}.app"
    --app-drop-link 600 190
    --no-internet-enable
)

# Add background if available
if [[ -n "$BACKGROUND_IMAGE" && -f "$BACKGROUND_IMAGE" ]]; then
    CREATE_DMG_ARGS+=(--background "$BACKGROUND_IMAGE")
    echo "Using background image: $BACKGROUND_IMAGE"
fi

# Create the DMG
# Note: create-dmg expects the source to be a directory containing the app
TEMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TEMP_DIR/"

create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_PATH" "$TEMP_DIR/" || {
    # create-dmg returns non-zero if there are warnings but still succeeds
    if [[ -f "$DMG_PATH" ]]; then
        echo -e "${YELLOW}create-dmg completed with warnings${NC}"
    else
        echo -e "${RED}create-dmg failed${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

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
echo "  1. Sign the DMG (if not already signed):"
echo "     codesign --sign \"Developer ID Application: ...\" \"$DMG_PATH\""
echo "  2. Notarize with: ./Scripts/notarize.sh --dmg-path \"$DMG_PATH\""
echo "  3. Test by mounting: hdiutil attach \"$DMG_PATH\""
