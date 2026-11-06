#!/bin/bash
set -euo pipefail

# DeloWay Spicetify Extension Installer
# Prepares and copies the deloway-bridge.js extension with a generated secure token.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
EXT_SRC="$ROOT_DIR/extras/spicetify/deloway-bridge.js"
SPICETIFY_EXT_DIR="$HOME/.config/spicetify/Extensions"

echo "=== DeloWay Spicetify Bridge Setup ==="

# 1. Generate or read existing secure token
TOKEN_FILE="${XDG_RUNTIME_DIR:-/tmp}/deloway/spotify-token"
CONFIG_TOKEN_FILE="$HOME/.config/deloway/spotify-token"

if [[ -f "$CONFIG_TOKEN_FILE" ]]; then
    TOKEN="$(cat "$CONFIG_TOKEN_FILE")"
elif [[ -f "$TOKEN_FILE" ]]; then
    TOKEN="$(cat "$TOKEN_FILE")"
else
    mkdir -p "$HOME/.config/deloway"
    chmod 700 "$HOME/.config/deloway"
    TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
    echo "$TOKEN" > "$CONFIG_TOKEN_FILE"
    chmod 600 "$CONFIG_TOKEN_FILE"
fi

# Ensure runtime directory copy is synchronized
if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
    mkdir -p "$XDG_RUNTIME_DIR/deloway"
    chmod 700 "$XDG_RUNTIME_DIR/deloway"
    echo "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
fi

echo "✔ Secure token generated and saved (permissions 0600)."

# 2. Prepare target directory
mkdir -p "$SPICETIFY_EXT_DIR"

# 3. Inject token and copy extension
sed "s/__DELOWAY_TOKEN__/$TOKEN/g" "$EXT_SRC" > "$SPICETIFY_EXT_DIR/deloway-bridge.js"
chmod 644 "$SPICETIFY_EXT_DIR/deloway-bridge.js"
echo "✔ Extension installed to $SPICETIFY_EXT_DIR/deloway-bridge.js"

# 4. Instructions
echo ""
echo "Next steps to apply in Spotify:"
echo "1. Run: spicetify config extensions deloway-bridge.js"
echo "2. Run: spicetify apply"
echo "3. Enable in DeloWay: deloway setSetting spotifyBridgeEnabled true"
echo "======================================="
