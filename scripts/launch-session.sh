#!/usr/bin/env bash
# Deloway Desktop - Standalone Session Launcher for SDDM / Display Managers
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${DELOWAY_DIR:-$DIR}"
CONFIG_PATH="$PROJECT_DIR/config/hyprland.conf"

export XDG_CURRENT_DESKTOP="Hyprland"
export XDG_SESSION_DESKTOP="Deloway"
export XDG_SESSION_TYPE="wayland"
export QS_ICON_THEME=Reversal-dark
export XDG_DATA_DIRS="$HOME/.local/share:$XDG_DATA_DIRS"

exec start-hyprland -- -c "$CONFIG_PATH"
