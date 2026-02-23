#!/bin/bash
#
# build.sh - Compiles CameraToggle.swift and packages it into a .app bundle.
#
# Prerequisites:
#   - macOS 11.0+ (Big Sur or later)
#   - Xcode Command Line Tools  (xcode-select --install)
#
# Usage:
#   chmod +x build.sh
#   ./build.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CameraToggle"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME ..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Compile Swift source
swiftc \
    -framework Cocoa \
    -O \
    -o "$BUILD_DIR/$APP_NAME" \
    "$SCRIPT_DIR/Sources/CameraToggle.swift"

# Create .app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME"               "$APP_BUNDLE/Contents/MacOS/"
cp "$SCRIPT_DIR/Resources/Info.plist"    "$APP_BUNDLE/Contents/"

echo ""
echo "Build successful: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "If macOS blocks the app (unidentified developer), run:"
echo "  xattr -cr $APP_BUNDLE"
echo "  open $APP_BUNDLE"
echo ""
echo "To auto-start on login:"
echo "  System Settings > General > Login Items > '+' > select CameraToggle.app"
