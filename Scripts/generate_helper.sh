#!/bin/bash
#
# generate_helper.sh
# Generate a DockTile helper bundle for multi-instance support
#
# Usage: ./generate_helper.sh <app_name> <bundle_id> <icon_path> <output_dir>
# Example: ./generate_helper.sh "DockTile-Dev" "com.docktile.dev" "/tmp/icon.icns" "~/Applications"
#

set -e  # Exit on error

# Check arguments
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <app_name> <bundle_id> <icon_path> <output_dir>"
    echo "Example: $0 'DockTile-Dev' 'com.docktile.dev' '/tmp/icon.icns' '~/Applications'"
    exit 1
fi

APP_NAME="$1"
BUNDLE_ID="$2"
ICON_PATH="$3"
OUTPUT_DIR=$(eval echo "$4")  # Expand ~ if present

# Validate inputs
if [ ! -f "$ICON_PATH" ]; then
    echo "Error: Icon file not found at $ICON_PATH"
    exit 1
fi

# Find the main DockTile.app (assumes it's in /Applications or build directory)
MAIN_APP_PATH=""
if [ -d "/Applications/DockTile.app" ]; then
    MAIN_APP_PATH="/Applications/DockTile.app"
elif [ -d "$HOME/Library/Developer/Xcode/DerivedData/DockTile-"*"/Build/Products/Debug/DockTile.app" ]; then
    MAIN_APP_PATH=$(ls -d "$HOME/Library/Developer/Xcode/DerivedData/DockTile-"*"/Build/Products/Debug/DockTile.app" 2>/dev/null | head -n 1)
else
    echo "Error: Main DockTile.app not found in /Applications or Xcode DerivedData"
    exit 1
fi

echo "📂 Found main app at: $MAIN_APP_PATH"

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Define helper app path
HELPER_APP_PATH="$OUTPUT_DIR/$APP_NAME.app"

# Remove existing helper if present
if [ -d "$HELPER_APP_PATH" ]; then
    echo "🗑️  Removing existing $APP_NAME.app..."
    rm -rf "$HELPER_APP_PATH"
fi

# Copy main app bundle structure
echo "📋 Copying app bundle structure..."
cp -R "$MAIN_APP_PATH" "$HELPER_APP_PATH"

# Update Info.plist
echo "✏️  Updating Info.plist..."
INFO_PLIST="$HELPER_APP_PATH/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"

# Set LSUIElement to true (dock-only, no window)
/usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$INFO_PLIST"

# Replace app icon
echo "🎨 Installing custom icon..."
RESOURCES_DIR="$HELPER_APP_PATH/Contents/Resources"

# Remove old icon if present
rm -f "$RESOURCES_DIR/AppIcon.icns"

# Copy new icon
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"

# Symlink binary to main app (to save space and ensure code sharing)
echo "🔗 Creating binary symlink..."
BINARY_NAME=$(basename "$MAIN_APP_PATH" .app)
MAIN_BINARY="$MAIN_APP_PATH/Contents/MacOS/$BINARY_NAME"
HELPER_BINARY="$HELPER_APP_PATH/Contents/MacOS/$BINARY_NAME"

if [ -f "$MAIN_BINARY" ]; then
    rm -f "$HELPER_BINARY"
    ln -s "$MAIN_BINARY" "$HELPER_BINARY"
    echo "   ✓ Linked to: $MAIN_BINARY"
else
    echo "   ⚠️  Warning: Main binary not found, using copied binary"
fi

# Ad-hoc code sign (required for macOS to launch)
echo "✍️  Code signing..."
codesign --force --deep --sign - "$HELPER_APP_PATH" 2>&1 | grep -v "replacing existing signature" || true

# Verify bundle
echo "🔍 Verifying bundle..."
if [ -d "$HELPER_APP_PATH/Contents" ] && [ -f "$HELPER_APP_PATH/Contents/Info.plist" ]; then
    echo "✅ Helper bundle created successfully!"
    echo ""
    echo "📍 Location: $HELPER_APP_PATH"
    echo "🆔 Bundle ID: $BUNDLE_ID"
    echo "📦 App Name: $APP_NAME"
    echo ""
    echo "Next steps:"
    echo "  1. Drag $APP_NAME.app to your Dock"
    echo "  2. Click the dock icon to launch"
else
    echo "❌ Error: Bundle verification failed"
    exit 1
fi
