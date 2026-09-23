#!/usr/bin/env bash
# Deloway Wallpaper Switcher / Shortcut Handler

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$1" = "--browse" ]; then
    "$DIR/scripts/deloway-wallpaper.py" --browse
elif [ -n "$1" ]; then
    "$DIR/scripts/deloway-wallpaper.py" "$1"
else
    # Default behavior: open Settings at the wallpaper page
    quickshell ipc -p "$DIR/shell" call deloway openSettings wallpaper 2>/dev/null || true
fi
