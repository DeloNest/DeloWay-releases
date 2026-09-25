#!/usr/bin/env bash
# ==============================================================================
# DeloWay — nested development session
#
# Runs Hyprland in a window on the current desktop with this repo's shell, isolated
# from the real session:
#   * HOME points at a throw-away sandbox, so ~/.config/deloway, GTK settings,
#     fontconfig and the shell's state files are written there, not to your home;
#   * GSETTINGS_BACKEND=memory, so gsettings writes (theme, fonts, icons) never
#     reach your dconf database;
#   * only the shell is autostarted: no second polkit agent, LocalSend or wallpaper
#     daemon competing with the real session.
#
# Usage: scripts/launch-nested.sh [--fresh] [--size WxH]
#   --fresh      empty the sandbox first (first run: Setup Wizard, default config)
#   --size WxH   nested output size (default 1600x1000)
#
# Env: DELOWAY_NESTED_HOME  sandbox directory (default $XDG_RUNTIME_DIR/deloway-nested)
#
# Closing the window (or Ctrl+Alt+Delete → Log out inside it) ends the session. The nested
# compositor's instance signature is written to $DELOWAY_NESTED_HOME/instance, so
#   HYPRLAND_INSTANCE_SIGNATURE=$(cat …/instance) hyprctl …
# and  WAYLAND_DISPLAY=$(cat …/wayland-display) grim shot.png  reach the nested session.
# ==============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SANDBOX="${DELOWAY_NESTED_HOME:-${XDG_RUNTIME_DIR:-/tmp}/deloway-nested}"
SIZE="1600x1000"
FRESH=false

while [ $# -gt 0 ]; do
    case "$1" in
        --fresh) FRESH=true ;;
        --size) SIZE="${2:?--size needs WxH}"; shift ;;
        -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    echo "Error: no graphical session (Wayland/X11) to nest into." >&2
    exit 1
fi

# Never let --fresh empty anything but a sandbox this script created.
if [ "$FRESH" = true ] && [ -d "$SANDBOX" ]; then
    if [ ! -f "$SANDBOX/.deloway-nested" ]; then
        echo "Refusing to empty $SANDBOX: not a DeloWay nested sandbox." >&2
        exit 1
    fi
    rm -rf -- "$SANDBOX"
fi
mkdir -p "$SANDBOX/.config/deloway" "$SANDBOX/Desktop"
touch "$SANDBOX/.deloway-nested"

# Nested config: the real hyprland.conf with the repo path pinned (HOME changes below),
# a fixed output size and only the shell autostarted.
CONF="$SANDBOX/hyprland-nested.conf"
{
    sed -E \
        -e "s|^\\\$delowayDir = .*|\$delowayDir = $PROJECT_DIR|" \
        -e 's|^monitor = .*|monitor = , '"$SIZE"', auto, 1|' \
        -e '/^exec-once/d' \
        "$PROJECT_DIR/config/hyprland.conf"
    echo ""
    echo "# nested session: shell only, and tell the caller how to reach this instance"
    echo "exec-once = quickshell -p \$delowayDir/shell"
    # printenv, not $VAR: Hyprland expands $VARs in its config at parse time, before it
    # sets WAYLAND_DISPLAY to its own socket.
    echo "exec-once = sh -c 'printenv HYPRLAND_INSTANCE_SIGNATURE > \"$SANDBOX/instance\"; printenv WAYLAND_DISPLAY > \"$SANDBOX/wayland-display\"'"
} > "$CONF"
rm -f "$SANDBOX/instance" "$SANDBOX/wayland-display"

echo "=========================================================="
echo " DeloWay nested session"
echo "   repo:    $PROJECT_DIR"
echo "   sandbox: $SANDBOX"
echo "   output:  $SIZE"
echo "=========================================================="

export HOME="$SANDBOX"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
export GSETTINGS_BACKEND=memory
export DELOWAY_DIR="$PROJECT_DIR"
export DELOWAY_CONFIG="$SANDBOX/.config/deloway/deloway.json"
export AQ_NO_MODIFIERS=1

exec Hyprland -c "$CONF"
