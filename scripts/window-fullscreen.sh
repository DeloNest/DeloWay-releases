#!/usr/bin/env bash
# DeloWay Smart Fullscreen
# If Deloway Settings is open, toggle its fullscreen/minimal state.
# Otherwise, dispatch standard Hyprland fullscreen 0.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS=$(quickshell ipc -p "$DIR/shell" call deloway handleFullscreen 2>/dev/null)
if [ "$STATUS" != "true" ]; then
    hyprctl dispatch fullscreen 0
fi
