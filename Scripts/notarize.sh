#!/bin/bash
#
# notarize.sh - Notarize Dock Tile DMG with Apple
#
# Usage: ./Scripts/notarize.sh --dmg-path PATH [--apple-id ID] [--team-id ID] [--password PWD]
#
# This script submits the DMG to Apple for notarization and staples the result.
# Credentials can be provided via arguments or environment variables.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Defaults from environment or empty
DMG_PATH=""
APPLE_ID="${APPLE_ID:-}"
TEAM_ID="${APPLE_TEAM_ID:-}"
APP_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dmg-path)
            DMG_PATH="$2"
            shift 2
            ;;
        --apple-id)
            APPLE_ID="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --password)
            APP_PASSWORD="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --dmg-path PATH [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dmg-path   Path to DMG file to notarize (required)"
            echo "  --apple-id   Apple ID email (or set APPLE_ID env var)"
            echo "  --team-id    Apple Team ID (or set APPLE_TEAM_ID env var)"
            echo "  --password   App-specific password (or set APPLE_APP_SPECIFIC_PASSWORD env var)"
            echo ""
            echo "Environment variables:"
            echo "  APPLE_ID                      Apple ID email"
            echo "  APPLE_TEAM_ID                 Apple Team ID"
            echo "  APPLE_APP_SPECIFIC_PASSWORD   App-specific password from appleid.apple.com"
            echo ""
            echo "To create an app-specific password:"
            echo "  1. Go to https://appleid.apple.com"
            echo "  2. Sign in and go to Security > App-Specific Passwords"
            echo "  3. Generate a new password for 'DockTile Notarization'"
            echo ""
            echo "You can also store the password in Keychain:"
            echo "  xcrun notarytool store-credentials 'DockTile-Notarization' \\"
            echo "    --apple-id YOUR_EMAIL \\"
            echo "    --team-id YOUR_TEAM_ID \\"
            echo "    --password YOUR_APP_SPECIFIC_PASSWORD"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}=== Dock Tile Notarization ===${NC}"

# Verify DMG path
if [[ -z "$DMG_PATH" ]]; then
    echo -e "${RED}Error: --dmg-path is required${NC}"
    exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
    echo -e "${RED}Error: DMG file not found: $DMG_PATH${NC}"
    exit 1
fi

echo "DMG: $DMG_PATH"

# Check for stored credentials first
if xcrun notarytool history --keychain-profile "DockTile-Notarization" >/dev/null 2>&1; then
    echo "Using stored keychain credentials..."
    CRED_ARGS="--keychain-profile DockTile-Notarization"
else
    # Verify credentials
    if [[ -z "$APPLE_ID" ]]; then
        echo -e "${RED}Error: Apple ID not provided${NC}"
        echo "Set APPLE_ID environment variable or use --apple-id"
        exit 1
    fi

    if [[ -z "$TEAM_ID" ]]; then
        echo -e "${RED}Error: Team ID not provided${NC}"
        echo "Set APPLE_TEAM_ID environment variable or use --team-id"
        exit 1
    fi

    if [[ -z "$APP_PASSWORD" ]]; then
        echo -e "${RED}Error: App-specific password not provided${NC}"
        echo "Set APPLE_APP_SPECIFIC_PASSWORD environment variable or use --password"
        exit 1
    fi

    CRED_ARGS="--apple-id $APPLE_ID --team-id $TEAM_ID --password $APP_PASSWORD"
fi

echo ""
echo -e "${YELLOW}Submitting for notarization...${NC}"
echo "This may take several minutes."
echo ""

# Submit for notarization
if ! xcrun notarytool submit "$DMG_PATH" $CRED_ARGS --wait; then
    echo -e "${RED}Notarization failed!${NC}"
    echo ""
    echo "To see detailed logs, run:"
    echo "  xcrun notarytool log <submission-id> $CRED_ARGS"
    exit 1
fi

echo ""
echo -e "${GREEN}Notarization successful!${NC}"

# Staple the notarization ticket
echo ""
echo "Stapling notarization ticket..."

if ! xcrun stapler staple "$DMG_PATH"; then
    echo -e "${RED}Stapling failed!${NC}"
    echo "The DMG is notarized but the ticket could not be stapled."
    echo "Users will need an internet connection to verify the notarization."
    exit 1
fi

echo ""
echo -e "${GREEN}=== Notarization Complete ===${NC}"
echo "  File: $DMG_PATH"
echo "  Status: Notarized and stapled"
echo ""
echo "The DMG is ready for distribution!"
