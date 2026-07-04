#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Vibe Coding手持输入助手"
VERSION="0.1.2"
RELEASE_DIR="$ROOT_DIR/release"
RELEASE_BASENAME="VibeCodingHandInputAssistant-$VERSION"
APP_PATH="$RELEASE_DIR/$RELEASE_BASENAME/$APP_NAME.app"
DMG_WORK_DIR="$ROOT_DIR/.build/dmg"
DMG_STAGING="$DMG_WORK_DIR/staging"
DMG_MOUNT="$DMG_WORK_DIR/mount"
DMG_RW="$DMG_WORK_DIR/$RELEASE_BASENAME-rw.dmg"
DMG_PATH="$RELEASE_DIR/$RELEASE_BASENAME.dmg"
BACKGROUND_NAME="DmgBackground.png"

"$ROOT_DIR/scripts/build-app.sh"
python3 "$ROOT_DIR/scripts/generate-dmg-background.py"

rm -rf "$DMG_STAGING" "$DMG_MOUNT" "$DMG_RW" "$DMG_PATH"
mkdir -p "$DMG_STAGING/.background"
cp -R "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
cp "$ROOT_DIR/Resources/$BACKGROUND_NAME" "$DMG_STAGING/.background/$BACKGROUND_NAME"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDRW \
  "$DMG_RW"

mkdir -p "$DMG_MOUNT"
hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen -mountpoint "$DMG_MOUNT" >/dev/null
VOLUME_PATH="$DMG_MOUNT"

osascript <<APPLESCRIPT
set dmgFolder to POSIX file "$VOLUME_PATH" as alias
set bgFile to POSIX file "$VOLUME_PATH/.background/$BACKGROUND_NAME" as alias
tell application "Finder"
  open dmgFolder
  set containerWindow to container window of dmgFolder
  tell containerWindow
    set current view to icon view
    set toolbar visible to false
    set statusbar visible to false
    set bounds to {120, 120, 1040, 640}
  end tell
  set viewOptions to the icon view options of containerWindow
  set icon size of viewOptions to 112
  set text size of viewOptions to 13
  set background picture of viewOptions to bgFile
  try
    set position of item ".background" of dmgFolder to {1280, 760}
  end try
  try
    set position of item ".fseventsd" of dmgFolder to {1460, 760}
  end try
  set position of item "$APP_NAME.app" of dmgFolder to {250, 260}
  set position of item "Applications" of dmgFolder to {670, 260}
  select item "$APP_NAME.app" of dmgFolder
  update dmgFolder without registering applications
  delay 1
  close containerWindow
end tell
APPLESCRIPT

sync
hdiutil detach "$VOLUME_PATH"

hdiutil convert "$DMG_RW" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

codesign --force --sign - "$DMG_PATH"

echo "$DMG_PATH"
