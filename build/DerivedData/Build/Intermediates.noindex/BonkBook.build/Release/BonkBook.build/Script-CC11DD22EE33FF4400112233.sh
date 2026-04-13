#!/bin/sh
DEST="$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/MacOS/spank"
cp "$PROJECT_DIR/BonkBook/spank" "$DEST"
chmod +x "$DEST"

