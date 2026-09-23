#!/usr/bin/env bash
# ==============================================================================
# DeloWay Screenshot Utility
# Supports: area (freeze + interactive snip), window, fullscreen, gui
# Features:
#   - Single-instance / Toggle: Repeating the shortcut cancels the active snip
#   - Screen Freeze: Visually freezes the display during selection via hyprpicker
#   - Strict Monochrome Identity: Neutral slurp selection colors
#   - Bilingual notifications (Arabic / English)
# ==============================================================================

MODE="${1:-area}"
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

LOCK_FILE="/tmp/deloway-screenshot.lock"

# ── 1. Single-Instance & Toggle Logic ──
# If a capture is already in progress, cancel it and exit cleanly (toggle behavior)
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        pkill -x slurp 2>/dev/null
        pkill -x hyprpicker 2>/dev/null
        rm -f "$LOCK_FILE"
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

if pgrep -x slurp >/dev/null 2>&1; then
    pkill -x slurp 2>/dev/null
    pkill -x hyprpicker 2>/dev/null
    rm -f "$LOCK_FILE"
    exit 0
fi

echo $$ > "$LOCK_FILE"

# ── 2. Screen Freeze Management ──
HYPRPICKER_PID=""

freeze_screen() {
    if command -v hyprpicker >/dev/null 2>&1; then
        hyprpicker -r -z >/dev/null 2>&1 &
        HYPRPICKER_PID=$!
        sleep 0.12
    fi
}

unfreeze_screen() {
    if [ -n "$HYPRPICKER_PID" ]; then
        kill "$HYPRPICKER_PID" 2>/dev/null
        wait "$HYPRPICKER_PID" 2>/dev/null
        HYPRPICKER_PID=""
    fi
    pkill -x hyprpicker 2>/dev/null
}

cleanup() {
    unfreeze_screen
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM HUP

# ── 3. Monochrome Styling for Slurp ──
SLURP_BORDER="ffffffee"
SLURP_BG="00000088"
SLURP_SELECTION="ffffff22"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
FILE_PATH="$SAVE_DIR/Screenshot_${TIMESTAMP}.png"

notify_success() {
    local path="$1"
    local copied="${2:-1}"   # 1 only when wl-copy really succeeded
    if command -v notify-send >/dev/null 2>&1; then
        local is_ar=0
        if [[ "${LANGUAGE:-$LANG}" == ar* ]]; then
            is_ar=1
        fi

        local title="Screenshot Captured"
        local body="Saved to ${path##*/}"
        [ "$copied" = 1 ] && body="$body\nCopied to clipboard"
        if [ $is_ar -eq 1 ]; then
            title="تم التقاط لقطة الشاشة"
            body="تم الحفظ في ${path##*/}"
            [ "$copied" = 1 ] && body="$body\nونُسخت إلى الحافظة"
        fi

        notify-send -a "DeloWay" \
            -i "$path" \
            -h string:x-canonical-private-synchronous:screenshot \
            "$title" \
            "$body"
    fi
}

# ── 4. Execution Modes ──
case "$MODE" in
    gui|menu)
        rm -f "$LOCK_FILE"
        # Toggle Quickshell on-screen Screenshot Toolbar
        if command -v qs >/dev/null 2>&1; then
            qs ipc -p "$(dirname "$(readlink -f "$0")")/../shell" call deloway toggleScreenshot 2>/dev/null && exit 0
        fi
        exec "$0" area
        ;;

    area|snip|region)
        # Freeze screen for precise snip
        freeze_screen

        # Window snapping support on active workspace
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

        # If user cancelled with Esc
        [ -z "$GEOM" ] && exit 0

        # Capture from the screen while frozen
        grim -g "$GEOM" "$FILE_PATH" || exit 1

        # Unfreeze display immediately after capture
        unfreeze_screen

        COPIED=1; wl-copy --type image/png < "$FILE_PATH" 2>/dev/null || COPIED=0
        notify_success "$FILE_PATH" "$COPIED"
        echo "$FILE_PATH"
        ;;

    window|active)
        freeze_screen

        GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [ -z "$GEOM" ] || [ "$GEOM" = "null,null nullxnull" ] || [ "$GEOM" = "0,0 0x0" ]; then
            unfreeze_screen
            rm -f "$LOCK_FILE"   # exec keeps our PID, which the lock check would read as "running"
            exec "$0" area
        fi

        grim -g "$GEOM" "$FILE_PATH" || exit 1
        unfreeze_screen

        COPIED=1; wl-copy --type image/png < "$FILE_PATH" 2>/dev/null || COPIED=0
        notify_success "$FILE_PATH" "$COPIED"
        echo "$FILE_PATH"
        ;;

    full|screen|fullscreen)
        sleep 0.05
        grim "$FILE_PATH" || exit 1
        COPIED=1; wl-copy --type image/png < "$FILE_PATH" 2>/dev/null || COPIED=0
        notify_success "$FILE_PATH" "$COPIED"
        echo "$FILE_PATH"
        ;;

    *)
        echo "Usage: $0 {area|window|full|gui}"
        exit 1
        ;;
esac
