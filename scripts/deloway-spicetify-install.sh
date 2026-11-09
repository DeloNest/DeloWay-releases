#!/bin/bash
set -euo pipefail

# DeloWay Spicetify Extension Installer
# Generates a persistent secure token ONCE in ~/.config/deloway/spotify-token (0600)
# and installs the deloway-bridge.js extension for Spicetify.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
EXT_SRC="$ROOT_DIR/extras/spicetify/deloway-bridge.js"
CONFIG_DIR="${DELOWAY_CONFIG_DIR:-$HOME/.config/deloway}"
CONFIG_TOKEN_FILE="$CONFIG_DIR/spotify-token"
SPICETIFY_EXT_DIR="$HOME/.config/spicetify/Extensions"

echo "=== DeloWay Spicetify Bridge Setup ==="

# 1. Ensure config dir exists with strict permissions (0700)
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# 2. Read or generate secure token ONCE in persistent config dir (never XDG_RUNTIME_DIR)
if [[ -f "$CONFIG_TOKEN_FILE" ]]; then
    TOKEN="$(cat "$CONFIG_TOKEN_FILE" | tr -d '[:space:]')"
    echo "✔ Found existing persistent token at $CONFIG_TOKEN_FILE"
else
    TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
    # Create file with 0600 permissions
    (
        umask 077
        echo "$TOKEN" > "$CONFIG_TOKEN_FILE"
    )
    chmod 600 "$CONFIG_TOKEN_FILE"
    echo "✔ Generated new persistent secure token at $CONFIG_TOKEN_FILE (permissions 0600)"
fi

# 3. Ensure target Spicetify Extensions directory exists
mkdir -p "$SPICETIFY_EXT_DIR"

# 4. Inject token into extension and copy
sed "s/__DELOWAY_TOKEN__/$TOKEN/g" "$EXT_SRC" > "$SPICETIFY_EXT_DIR/deloway-bridge.js"
chmod 644 "$SPICETIFY_EXT_DIR/deloway-bridge.js"
echo "✔ Extension installed to $SPICETIFY_EXT_DIR/deloway-bridge.js"

echo ""
echo "Next steps to activate in Spotify:"
echo "1. Run: spicetify config extensions deloway-bridge.js"
echo "2. Run: spicetify apply"
echo "3. Enable in DeloWay: deloway setSetting spotifyBridgeEnabled true"
echo "======================================="
