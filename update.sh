#!/usr/bin/env bash
# ==============================================================================
# DeloOS / Deloway Desktop Experience - Update & Schema Migration Engine
# Gracefully updates repository, migrates configuration schemas, and reloads shell
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELOWAY_DIR="$SCRIPT_DIR"

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}${BOLD}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}${BOLD}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}${BOLD}[ERROR]${NC} $1"; }

USER_CONFIG="$HOME/.config/deloway/deloway.json"
TEMPLATE_CONFIG="$DELOWAY_DIR/config/deloway.json"
BACKUP_DIR="$HOME/.config/deloway/backups"

print_header() {
    echo -e "${CYAN}${BOLD}==> Deloway Update & Schema Migration Engine${NC}"
}

sync_git_repo() {
    log_info "Checking for repository updates..."
    if [ -d "$DELOWAY_DIR/.git" ]; then
        cd "$DELOWAY_DIR"
        local status
        status=$(git status --porcelain || true)
        if [ -n "$status" ]; then
            log_warn "Local repository has uncommitted modifications. Skipping git pull to preserve local edits."
        else
            log_info "Pulling latest upstream changes..."
            git pull --ff-only 2>/dev/null || log_warn "Could not fast-forward git pull (offline or detached head). Continuing with local version."
        fi
    fi
}

backup_config() {
    if [ -f "$USER_CONFIG" ]; then
        mkdir -p "$BACKUP_DIR"
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_file="$BACKUP_DIR/deloway.json.bak.$timestamp"
        cp "$USER_CONFIG" "$backup_file"
        log_success "Configuration backed up to: $backup_file"
    fi
}

migrate_schema() {
    log_info "Checking configuration schema migration..."

    if [ ! -f "$USER_CONFIG" ]; then
        if [ -f "$TEMPLATE_CONFIG" ]; then
            mkdir -p "$(dirname "$USER_CONFIG")"
            cp "$TEMPLATE_CONFIG" "$USER_CONFIG"
            log_success "Initialized configuration at $USER_CONFIG"
        fi
        return
    fi

    # Python-powered deep schema migration:
    # Recursively adds missing keys from template into user config while preserving existing values
    python3 - << 'EOF'
import json
import os
import sys

user_cfg_path = os.path.expanduser("~/.config/deloway/deloway.json")
template_cfg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config/deloway.json")

if not os.path.exists(user_cfg_path) or not os.path.exists(template_cfg_path):
    sys.exit(0)

with open(user_cfg_path, 'r', encoding='utf-8') as f:
    try:
        user_cfg = json.load(f)
    except Exception as e:
        print(f"[ERROR] Corrupted JSON in {user_cfg_path}: {e}", file=sys.stderr)
        sys.exit(1)

with open(template_cfg_path, 'r', encoding='utf-8') as f:
    template_cfg = json.load(f)

migrated_keys = []

def deep_merge(target, source, prefix=""):
    for key, val in source.items():
        full_key = f"{prefix}.{key}" if prefix else key
        if key not in target:
            target[key] = val
            migrated_keys.append(full_key)
        elif isinstance(val, dict) and isinstance(target.get(key), dict):
            deep_merge(target[key], val, full_key)

deep_merge(user_cfg, template_cfg)

if migrated_keys:
    # Atomic write back
    tmp_path = user_cfg_path + ".tmp"
    with open(tmp_path, 'w', encoding='utf-8') as f:
        json.dump(user_cfg, f, indent=2, ensure_ascii=False)
    os.replace(tmp_path, user_cfg_path)
    print(f"[SUCCESS] Migrated {len(migrated_keys)} new schema keys into user config: {', '.join(migrated_keys)}")
else:
    print("[INFO] Configuration schema is fully up-to-date. No migration required.")
EOF
}

sync_assets() {
    log_info "Syncing desktop assets and icon caches..."

    mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps" "$HOME/.local/share/applications"

    # Re-sync desktop folder icons
    if [ -d "$DELOWAY_DIR/assets/icons/desktop" ]; then
        cp -r "$DELOWAY_DIR/assets/icons/desktop/." "$HOME/.local/share/icons/hicolor/scalable/apps/" 2>/dev/null || true
    fi

    # Re-sync branded desktop entries
    if [ -d "$DELOWAY_DIR/assets/desktop-entries" ]; then
        cp "$DELOWAY_DIR"/assets/desktop-entries/*.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
    fi

    # Update caches
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
}

reload_shell() {
    log_info "Attempting live reload of Quickshell..."

    if command -v quickshell &>/dev/null; then
        # Find active Deloway quickshell instance
        local qs_inst
        qs_inst=$(quickshell list --all 2>/dev/null | grep -B 3 "Deloway" | grep "^Instance:" | head -n 1 | awk '{print $2}' | tr -d ' ' || true)
        if [ -n "$qs_inst" ]; then
            # Touch shell.qml to trigger Quickshell's internal hot-reload watcher
            touch "$DELOWAY_DIR/shell/shell.qml"
            log_success "Triggered hot-reload on Quickshell instance ($qs_inst)!"
        else
            log_info "Quickshell is not currently running. Changes will take effect on next login."
        fi
    fi
}

main() {
    print_header
    sync_git_repo
    backup_config
    migrate_schema
    sync_assets
    reload_shell
    echo ""
    log_success "Deloway has been successfully updated and migrated!"
}

main "$@"
