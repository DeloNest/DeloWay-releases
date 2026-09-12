#!/usr/bin/env bash
set -e

# Deloway Desktop - Install SDDM / Wayland session entry
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DESKTOP_FILE="$PROJECT_DIR/assets/deloway.desktop"
TARGET_DIR="/usr/share/wayland-sessions"

if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Error: $DESKTOP_FILE not found!"
    exit 1
fi

echo "Installing Deloway session to $TARGET_DIR..."
sudo cp "$DESKTOP_FILE" "$TARGET_DIR/deloway.desktop"
sudo chmod 644 "$TARGET_DIR/deloway.desktop"

echo "Done! 'Deloway' is now available in your login screen (SDDM)."
