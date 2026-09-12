#!/usr/bin/env bash
# DeloWay Smart Close
# If an overlay shell component (Settings, AppDrawer, CheatSheet, etc.) is open, close it cleanly via Quickshell IPC.
# Otherwise, dispatch standard Hyprland killactive.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS=$(quickshell ipc -p "$DIR/shell" call deloway handleClose 2>/dev/null)
if [ "$STATUS" != "true" ]; then
    hyprctl dispatch killactive
fi
