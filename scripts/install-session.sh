#!/usr/bin/env bash
# ==============================================================================
# DeloWay Session Installer for LightDM / Wayland Sessions
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Installing DeloWay Wayland Session..."

# Link (not copy) the wrapper, so repo updates reach the session the display manager starts.
echo "--> Linking /usr/local/bin/deloway-session -> $REPO_DIR/bin/deloway-session"
sudo ln -sfn "$REPO_DIR/bin/deloway-session" /usr/local/bin/deloway-session

# Install wayland-session desktop file
echo "--> Installing /usr/share/wayland-sessions/deloway.desktop"
sudo install -d -m 755 /usr/share/wayland-sessions
sudo install -m 644 "$REPO_DIR/system/deloway.desktop" /usr/share/wayland-sessions/deloway.desktop

echo "==> Successfully installed DeloWay session!"
echo "    LightDM will now list 'DeloWay' in its session list."
