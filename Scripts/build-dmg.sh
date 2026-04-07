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

echo "==> Signing spank with Developer ID + timestamp..."
codesign --force --sign "$IDENTITY" \
  --options runtime \
  --timestamp \
  "$SPANK_DEST"

echo "==> Re-signing app bundle (outer only, with timestamp)..."
codesign --force --sign "$IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$PROJECT_DIR/BonkBook/BonkBook.entitlements" \
  "$APP_PATH"

echo "==> Verifying..."
codesign --verify --deep --strict "$APP_PATH" && echo "    Signature OK"
spctl --assess --type execute "$APP_PATH" && echo "    Gatekeeper OK"

echo "==> Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo ""
echo "✅ Done! DMG at: $DMG_PATH"
echo ""
echo "Next: notarize with:"
echo "  xcrun notarytool submit $DMG_PATH --keychain-profile BonkBook --wait"
