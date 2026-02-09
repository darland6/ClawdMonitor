#!/bin/bash
set -e

APP_NAME="OpenClawWatcher"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🦞 Building OpenClawWatcher..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile
echo "Compiling Swift..."
swiftc -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -parse-as-library \
    -D DEBUG \
    -framework Cocoa \
    -framework UserNotifications \
    -framework ServiceManagement \
    -target arm64-apple-macos13.0 \
    OpenClawWatcher.swift

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/"

# Sign (ad-hoc for local use)
echo "Signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Build complete: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
