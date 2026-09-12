#!/usr/bin/env bash
# ==============================================================================
# DeloWay Screenshot Utility (end-4 / Fluent standard)
# Supports: area (interactive snip with window snap), active window, full screen
# ==============================================================================

MODE="${1:-area}"
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
FILE_PATH="$SAVE_DIR/Screenshot_${TIMESTAMP}.png"

# Fluent DeloWay accent colors for slurp
SLURP_BORDER="60cdffee"
SLURP_BG="10131888"
SLURP_SELECTION="2f7cf633"

notify_success() {
    local path="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "DeloWay" \
            -i "$path" \
            -h string:x-canonical-private-synchronous:screenshot \
            "Screenshot Captured" \
            "Saved to ${path##*/}\nCopied to clipboard"
    fi
}

case "$MODE" in
    gui|menu)
        # Toggle Quickshell on-screen Screenshot Toolbar
        if command -v qs >/dev/null 2>&1; then
            qs ipc call deloway toggleScreenshot 2>/dev/null && exit 0
        fi
        # Fallback to interactive area if Quickshell IPC fails
        exec "$0" area
        ;;

    area|snip|region)
        # Snap to window on hover, or drag arbitrary region (end-4 standard)
        WS_ID=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')
        if [ -n "$WS_ID" ]; then
            BOXES=$(hyprctl clients -j 2>/dev/null | jq -r --arg ws "$WS_ID" '.[] | select(.workspace.id == ($ws | tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        else
            BOXES=""
        fi

        if [ -n "$BOXES" ]; then
            GEOM=$(echo "$BOXES" | slurp -d -c "$SLURP_BORDER" -b "$SLURP_BG" -B "$SLURP_SELECTION" 2>/dev/null)
        else
            GEOM=$(slurp -d -c "$SLURP_BORDER" -b "$SLURP_BG" -B "$SLURP_SELECTION" 2>/dev/null)
        fi

        [ -z "$GEOM" ] && exit 0 # User cancelled with Esc

        sleep 0.05
        grim -g "$GEOM" "$FILE_PATH" || exit 1
        wl-copy --type image/png < "$FILE_PATH"
        notify_success "$FILE_PATH"
        echo "$FILE_PATH"
        ;;

    window|active)
        # Capture the currently focused window
        GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [ -z "$GEOM" ] || [ "$GEOM" = "null,null nullxnull" ] || [ "$GEOM" = "0,0 0x0" ]; then
            # Fallback to interactive area selection
            exec "$0" area
        fi

        sleep 0.05
        grim -g "$GEOM" "$FILE_PATH" || exit 1
        wl-copy --type image/png < "$FILE_PATH"
        notify_success "$FILE_PATH"
        echo "$FILE_PATH"
        ;;

    full|screen|fullscreen)
        # Capture the entire screen
        sleep 0.05
        grim "$FILE_PATH" || exit 1
        wl-copy --type image/png < "$FILE_PATH"
        notify_success "$FILE_PATH"
        echo "$FILE_PATH"
        ;;

    *)
        echo "Usage: $0 {area|window|full|gui}"
        exit 1
        ;;
esac
