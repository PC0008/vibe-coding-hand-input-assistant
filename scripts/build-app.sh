#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Vibe 手持输入助手"
EXECUTABLE_NAME="VibeHandInputAssistant"
VERSION="0.1.0"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/release/VibeHandInputAssistant-$VERSION"

cd "$ROOT_DIR"
python3 "$ROOT_DIR/scripts/generate-icons.py"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/.build/release/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/MenuIconTemplate.png" "$APP_DIR/Contents/Resources/MenuIconTemplate.png"
cp "$ROOT_DIR/Resources/Logo.png" "$APP_DIR/Contents/Resources/Logo.png"

chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
codesign --force --deep --sign - "$APP_DIR"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
cp -R "$APP_DIR" "$RELEASE_DIR/$APP_NAME.app"
ditto -c -k --keepParent "$RELEASE_DIR/$APP_NAME.app" "$ROOT_DIR/release/VibeHandInputAssistant-$VERSION.zip"

echo "$APP_DIR"
echo "$RELEASE_DIR/$APP_NAME.app"
echo "$ROOT_DIR/release/VibeHandInputAssistant-$VERSION.zip"
