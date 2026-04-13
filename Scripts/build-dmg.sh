#!/bin/bash
set -e

APP_NAME="BonkBook"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
SPANK_SRC="$PROJECT_DIR/BonkBook/spank"

# Find Developer ID Application certificate
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
if [ -z "$IDENTITY" ]; then
  echo "ERROR: No 'Developer ID Application' certificate found in keychain."
  echo "Make sure you have a Developer ID Application certificate, not just Apple Development."
  exit 1
fi
echo "==> Signing identity: $IDENTITY"

echo "==> Cleaning build folder..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building $APP_NAME (Release)..."
xcodebuild \
  -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM=92X99MPMUT \
  build 2>&1 | grep -E "(error:|BUILD|CodeSign)"

echo "==> Injecting spank binary..."
SPANK_DEST="$APP_PATH/Contents/MacOS/spank"
cp "$SPANK_SRC" "$SPANK_DEST"
chmod +x "$SPANK_DEST"

sign_with_retry() {
  local max=5
  for i in $(seq 1 $max); do
    if codesign "$@"; then
      return 0
    fi
    echo "    Timestamp server unavailable, retrying ($i/$max)..."
    sleep 3
  done
  echo "ERROR: Signing failed after $max attempts."
  exit 1
}

echo "==> Signing spank with Developer ID + timestamp..."
sign_with_retry --force --sign "$IDENTITY" \
  --options runtime \
  --timestamp \
  "$SPANK_DEST"

echo "==> Re-signing app bundle (outer only, with timestamp)..."
sign_with_retry --force --sign "$IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$PROJECT_DIR/BonkBook/BonkBook.entitlements" \
  "$APP_PATH"

echo "==> Verifying signature..."
codesign --verify --deep --strict "$APP_PATH" && echo "    Signature OK"
# Note: spctl Gatekeeper check is skipped here — it will pass after notarization.

echo "==> Creating DMG with drag-to-install UI..."
rm -f "$DMG_PATH"
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 130 160 \
  --app-drop-link 410 160 \
  --hide-extension "$APP_NAME.app" \
  "$DMG_PATH" \
  "$APP_PATH"

echo ""
echo "✅ Done! DMG at: $DMG_PATH"
echo ""
echo "Next: notarize with:"
echo "  xcrun notarytool submit $DMG_PATH --keychain-profile BonkBook --wait"
