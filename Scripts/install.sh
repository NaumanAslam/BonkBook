#!/bin/bash
# BonkBook install script
# Installs the passwordless sudoers rule so BonkBook can run spank without a password prompt.

set -e

SPANK_PATH="/usr/local/bin/spank"
SUDOERS_FILE="/etc/sudoers.d/bonkbook"

# Check spank is installed
if [ ! -f "$SPANK_PATH" ]; then
    echo "Error: spank not found at $SPANK_PATH"
    echo "Install it first: go install github.com/taigrr/spank@latest && sudo cp \$(go env GOPATH)/bin/spank /usr/local/bin/spank"
    exit 1
fi

# Install sudoers rule (allows group admin to run spank as root without password)
echo "%admin ALL=(ALL) NOPASSWD: $SPANK_PATH" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

echo "✅ BonkBook setup complete. You can now run BonkBook.app."
