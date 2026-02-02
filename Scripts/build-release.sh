#!/bin/bash
#
# build-release.sh - Build a complete release of Dock Tile
#
# Usage: ./Scripts/build-release.sh [--version VERSION] [--sign] [--notarize]
#
# This script builds the app, creates a DMG, and optionally signs/notarizes.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project settings
PROJECT="DockTile.xcodeproj"
SCHEME="DockTile"
APP_NAME="DockTile"
BUILD_DIR="./build"

# Options
VERSION=""
SIGN=false
NOTARIZE=false
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --sign)
            SIGN=true
            shift
            ;;
        --notarize)
            NOTARIZE=true
            SIGN=true  # Notarization requires signing
            shift
            ;;
        --identity)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version VERSION   Override version number"
            echo "  --sign              Code sign the app with Developer ID"
            echo "  --notarize          Sign and notarize the DMG"
            echo "  --identity NAME     Signing identity (default: auto-detect Developer ID)"
            echo ""
            echo "Environment variables for signing/notarization:"
            echo "  SIGNING_IDENTITY              Code signing identity"
            echo "  APPLE_ID                      Apple ID email"
            echo "  APPLE_TEAM_ID                 Apple Team ID"
            echo "  APPLE_APP_SPECIFIC_PASSWORD   App-specific password"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Dock Tile Release Builder         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

cd "$PROJECT_DIR"

# Step 1: Clean previous build
echo -e "${BLUE}[1/5] Cleaning previous build...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 2: Build Release
echo -e "${BLUE}[2/5] Building Release configuration...${NC}"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build \
    2>&1 | xcpretty --color || {
        echo -e "${RED}Build failed!${NC}"
        exit 1
    }

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${RED}Error: App bundle not found at $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"

# Get version from built app
if [[ -z "$VERSION" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
fi
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")

echo "  Version: $VERSION ($BUILD_NUMBER)"
echo "  App: $APP_PATH"

# Step 3: Code Sign (if requested)
if [[ "$SIGN" == true ]]; then
    echo ""
    echo -e "${BLUE}[3/5] Signing app bundle...${NC}"

    # Auto-detect signing identity if not provided
    if [[ -z "$SIGNING_IDENTITY" ]]; then
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
    fi

    if [[ -z "$SIGNING_IDENTITY" ]]; then
        echo -e "${RED}Error: No Developer ID Application certificate found${NC}"
        echo "Install a Developer ID certificate or specify with --identity"
        exit 1
    fi

    echo "  Identity: $SIGNING_IDENTITY"

    # Sign with hardened runtime and entitlements
    codesign --force --deep --sign "$SIGNING_IDENTITY" \
        --options runtime \
        --entitlements "DockTile/DockTile.entitlements" \
        "$APP_PATH"

    # Verify signature
    codesign --verify --deep --strict "$APP_PATH" || {
        echo -e "${RED}Signature verification failed!${NC}"
        exit 1
    }

    echo -e "${GREEN}Signing successful!${NC}"
else
    echo ""
    echo -e "${YELLOW}[3/5] Skipping code signing (use --sign to enable)${NC}"
fi

# Step 4: Create DMG
echo ""
echo -e "${BLUE}[4/5] Creating DMG installer...${NC}"

"$SCRIPT_DIR/create-dmg.sh" \
    --app-path "$APP_PATH" \
    --output-dir "$BUILD_DIR" \
    --version "$VERSION"

DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

# Step 5: Notarize (if requested)
if [[ "$NOTARIZE" == true ]]; then
    echo ""
    echo -e "${BLUE}[5/5] Notarizing DMG...${NC}"

    "$SCRIPT_DIR/notarize.sh" --dmg-path "$DMG_PATH"
else
    echo ""
    echo -e "${YELLOW}[5/5] Skipping notarization (use --notarize to enable)${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Build Complete!                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "  Version:  $VERSION ($BUILD_NUMBER)"
echo "  App:      $APP_PATH"
echo "  DMG:      $DMG_PATH"
if [[ "$SIGN" == true ]]; then
    echo "  Signed:   Yes ($SIGNING_IDENTITY)"
fi
if [[ "$NOTARIZE" == true ]]; then
    echo "  Notarized: Yes"
fi
echo ""

if [[ "$SIGN" == false ]]; then
    echo -e "${YELLOW}Note: The app is not signed. For distribution, run:${NC}"
    echo "  $0 --sign --notarize"
fi
