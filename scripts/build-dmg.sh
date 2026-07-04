#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Vibe Coding手持输入助手"
VERSION="0.1.0"
RELEASE_DIR="$ROOT_DIR/release"
RELEASE_BASENAME="VibeCodingHandInputAssistant-$VERSION"
APP_PATH="$RELEASE_DIR/$RELEASE_BASENAME/$APP_NAME.app"
DMG_STAGING="$ROOT_DIR/.build/dmg/$APP_NAME"
DMG_PATH="$RELEASE_DIR/$RELEASE_BASENAME.dmg"

"$ROOT_DIR/scripts/build-app.sh"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

codesign --force --sign - "$DMG_PATH"

echo "$DMG_PATH"
