#!/usr/bin/env bash
set -e

# Deloway Desktop - Nested Launch Script for Safe Development
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="$PROJECT_DIR/config/hyprland.conf"

echo "=========================================================="
echo " Starting Deloway Desktop in Nested Window"
echo " Config: $CONFIG_PATH"
echo " Press Super+M inside the window or close it to exit."
echo "=========================================================="

# Check if we are inside a Wayland or X11 session
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
    echo "Error: No graphical session (Wayland/X11) detected to run nested."
    exit 1
fi

# Fast startup on Wayland nested backend
export AQ_BACKEND=wayland
export AQ_NO_MODIFIERS=1
export QS_ICON_THEME=Reversal-dark
export XDG_DATA_DIRS="$HOME/.local/share:$XDG_DATA_DIRS"

# Run nested Hyprland
exec Hyprland -c "$CONFIG_PATH"
