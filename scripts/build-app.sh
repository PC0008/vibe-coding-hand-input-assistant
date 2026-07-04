#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
APP_NAME="Vibe Coding手持输入助手"
EXECUTABLE_NAME="VibeHandInputAssistant"
VERSION="0.1.2"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/release/VibeCodingHandInputAssistant-$VERSION"
FIRMWARE_DIR="$ROOT_DIR/Firmware/sticks3_voice_remote"
FIRMWARE_BUILD_DIR="$FIRMWARE_DIR/.pio/build/m5stack-sticks3"
BOOT_APP0="$WORKSPACE_ROOT/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin"
ESPTOOL_DIR="$WORKSPACE_ROOT/.platformio/packages/tool-esptoolpy"
PYTHON_SITE_PACKAGES="$WORKSPACE_ROOT/.venv/lib/python3.9/site-packages"

cd "$ROOT_DIR"
python3 "$ROOT_DIR/scripts/generate-icons.py"

if [[ -x "$WORKSPACE_ROOT/.venv/bin/pio" ]]; then
  PLATFORMIO_CORE_DIR="$WORKSPACE_ROOT/.platformio" "$WORKSPACE_ROOT/.venv/bin/pio" run -d "$FIRMWARE_DIR"
elif command -v pio >/dev/null 2>&1; then
  pio run -d "$FIRMWARE_DIR"
else
  echo "error: PlatformIO not found. Install PlatformIO or use the workspace .venv." >&2
  exit 1
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p \
  "$APP_DIR/Contents/MacOS" \
  "$APP_DIR/Contents/Resources/Firmware" \
  "$APP_DIR/Contents/Resources/FlashTools/esptoolpy" \
  "$APP_DIR/Contents/Resources/FlashTools/python-libs"

cp "$ROOT_DIR/.build/release/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/MenuIconTemplate.png" "$APP_DIR/Contents/Resources/MenuIconTemplate.png"
cp "$ROOT_DIR/Resources/Logo.png" "$APP_DIR/Contents/Resources/Logo.png"
cp "$FIRMWARE_BUILD_DIR/bootloader.bin" "$APP_DIR/Contents/Resources/Firmware/bootloader.bin"
cp "$FIRMWARE_BUILD_DIR/partitions.bin" "$APP_DIR/Contents/Resources/Firmware/partitions.bin"
cp "$BOOT_APP0" "$APP_DIR/Contents/Resources/Firmware/boot_app0.bin"
cp "$FIRMWARE_BUILD_DIR/firmware.bin" "$APP_DIR/Contents/Resources/Firmware/firmware.bin"
cp "$ESPTOOL_DIR/esptool.py" "$APP_DIR/Contents/Resources/FlashTools/esptoolpy/esptool.py"
cp -R "$ESPTOOL_DIR/esptool" "$APP_DIR/Contents/Resources/FlashTools/esptoolpy/esptool"
cp -R "$ESPTOOL_DIR/_contrib" "$APP_DIR/Contents/Resources/FlashTools/esptoolpy/_contrib"
cp -R "$PYTHON_SITE_PACKAGES/serial" "$APP_DIR/Contents/Resources/FlashTools/python-libs/serial"

chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
codesign --force --deep --sign - "$APP_DIR"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
cp -R "$APP_DIR" "$RELEASE_DIR/$APP_NAME.app"
ditto -c -k --keepParent "$RELEASE_DIR/$APP_NAME.app" "$ROOT_DIR/release/VibeCodingHandInputAssistant-$VERSION.zip"

echo "$APP_DIR"
echo "$RELEASE_DIR/$APP_NAME.app"
echo "$ROOT_DIR/release/VibeCodingHandInputAssistant-$VERSION.zip"
