#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="AirBattery"
CONFIG="Release"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="AirBattery Swoosh.app"
DMG_NAME="AirBattery-Swoosh.dmg"

echo "==> Building $SCHEME ($CONFIG)..."
xcodebuild \
    -project "$PROJECT_DIR/AirBattery.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=37SCFKRLNW \
    2>&1 | tail -20

APP_PATH="$(find "$BUILD_DIR" -name "$APP_NAME" -type d | head -1)"

if [ -z "$APP_PATH" ]; then
    echo "ERROR: Build failed — $APP_NAME not found in $BUILD_DIR"
    exit 1
fi

# Install to /Applications
if [ "${1:-}" = "--install" ] || [ "${1:-}" = "--launch" ]; then
    echo "==> Installing to /Applications..."
    if [ -d "/Applications/$APP_NAME" ]; then
        rm -rf "/Applications/$APP_NAME"
    fi
    cp -R "$APP_PATH" /Applications/
    echo "==> Installed /Applications/$APP_NAME"
fi

# Launch
if [ "${1:-}" = "--launch" ]; then
    echo "==> Launching AirBattery Swoosh..."
    open "/Applications/$APP_NAME"
fi

# Create DMG
if [ "${1:-}" = "--dmg" ] || [ "${1:-}" = "" ]; then
    DMG_PATH="$PROJECT_DIR/$DMG_NAME"
    DMG_STAGING="$BUILD_DIR/dmg-staging"

    echo "==> Creating DMG..."
    rm -rf "$DMG_STAGING" "$DMG_PATH"
    mkdir -p "$DMG_STAGING"
    cp -R "$APP_PATH" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"

    hdiutil create \
        -volname "AirBattery Swoosh" \
        -srcfolder "$DMG_STAGING" \
        -ov -format UDZO \
        "$DMG_PATH" \
        2>&1 | tail -5

    rm -rf "$DMG_STAGING"
    echo "==> DMG created: $DMG_PATH"
fi

echo "==> Done."
