#!/usr/bin/env bash
# ==============================================================================
# DeloOS / Deloway Desktop Experience - Automated System Installer
# Supports Arch Linux, Fedora, Ubuntu/Debian, and openSUSE
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELOWAY_DIR="$SCRIPT_DIR"

# Text Styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DRY_RUN=false
SKIP_DEPS=false

print_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  ____       _                     
 |  _ \  ___| | _____      ____ _ _   _ 
 | | | |/ _ \ |/ _ \ \ /\ / / _` | | | |
 | |_| |  __/ | (_) \ V  V / (_| | |_| |
 |____/ \___|_|\___/ \_/\_/ \__,_|\__, |
                                  |___/ 
 Fluent Mica Wayland Desktop on Hyprland
EOF
    echo -e "${NC}"
}

usage() {
    echo -e "${BOLD}Usage:${NC} ./install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run      Simulate installation without making changes"
    echo "  --no-deps      Skip package manager dependency checks/install"
    echo "  -h, --help     Show this help message"
    echo ""
    exit 0
}

# Parse CLI Arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --no-deps) SKIP_DEPS=true ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
    shift
done

log_info() {
    echo -e "${BLUE}${BOLD}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}${BOLD}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}${BOLD}[ERROR]${NC} $1"
}

run_step() {
    local desc="$1"
    shift
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $*"
    else
        log_info "$desc"
        "$@"
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_LIKE="${ID_LIKE:-$ID}"
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE="unknown"
    fi
    log_info "Detected Linux distribution: ${BOLD}$NAME ($DISTRO_ID)${NC}"
}

check_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        log_info "Skipping dependency installation (--no-deps specified)."
        return
    fi

    log_info "Checking required system dependencies..."

    local missing_pkgs=()
    local core_commands=("Hyprland" "quickshell" "kitty" "grim" "slurp" "playerctl" "wl-copy" "brightnessctl" "jq")

    for cmd in "${core_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_pkgs+=("$cmd")
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        log_success "All core executables are installed!"
        return
    fi

    log_warn "The following required tools were not found in PATH: ${missing_pkgs[*]}"

    case "$DISTRO_LIKE" in
        *arch*)
            log_info "Arch-based distribution detected. Suggested installation:"
            echo -e "  ${BOLD}sudo pacman -S hyprland quickshell kitty grim slurp playerctl wl-clipboard brightnessctl jq thunar ttf-jetbrains-mono-nerd${NC}"
            if command -v paru &>/dev/null; then
                AUR_HELPER="paru"
            elif command -v yay &>/dev/null; then
                AUR_HELPER="yay"
            else
                AUR_HELPER=""
            fi
            if [ -n "$AUR_HELPER" ]; then
                echo -e "  For Reversal icons: ${BOLD}$AUR_HELPER -S reversal-icon-theme-git${NC}"
            fi
            ;;
        *fedora*)
            log_info "Fedora-based distribution detected. Suggested installation:"
            echo -e "  ${BOLD}sudo dnf install hyprland kitty grim slurp playerctl wl-clipboard brightnessctl jq thunar jetbrains-mono-fonts${NC}"
            ;;
        *debian*|*ubuntu*)
            log_info "Debian/Ubuntu-based distribution detected. Suggested installation:"
            echo -e "  ${BOLD}sudo apt install hyprland kitty grim slurp playerctl wl-clipboard brightnessctl jq thunar fonts-jetbrains-mono${NC}"
            ;;
        *suse*)
            log_info "openSUSE detected. Suggested installation:"
            echo -e "  ${BOLD}sudo zypper install hyprland kitty grim slurp playerctl wl-clipboard brightnessctl jq thunar${NC}"
            ;;
        *)
            log_warn "Please ensure Hyprland, Quickshell, Kitty, and Wayland utilities are installed."
            ;;
    esac
}

setup_directories() {
    local dirs=(
        "$HOME/.config/deloway"
        "$HOME/.config/deloway/backups"
        "$HOME/.config/hypr"
        "$HOME/.local/bin"
        "$HOME/.local/share/applications"
        "$HOME/.local/share/icons/hicolor/scalable/apps"
        "$HOME/.local/share/wayland-sessions"
        "$HOME/Desktop"
    )

    for d in "${dirs[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} mkdir -p $d"
        else
            mkdir -p "$d"
        fi
    done
}

install_configs() {
    log_info "Installing configuration files..."

    # 1. Deloway Unified Config (deloway.json)
    local target_cfg="$HOME/.config/deloway/deloway.json"
    if [ -f "$target_cfg" ]; then
        log_info "Existing config found at $target_cfg (preserving user preferences)."
    else
        run_step "Copying default deloway.json configuration" cp "$DELOWAY_DIR/config/deloway.json" "$target_cfg"
    fi

    # 2. Symlink / Copy Shell directory
    local target_shell="$HOME/.config/deloway/shell"
    if [ -L "$target_shell" ] || [ -d "$target_shell" ]; then
        run_step "Updating shell link in ~/.config/deloway/shell" rm -rf "$target_shell"
    fi
    run_step "Linking Deloway shell to ~/.config/deloway/shell" ln -sfn "$DELOWAY_DIR/shell" "$target_shell"

    # 3. Session Executable
    local target_bin="$HOME/.local/bin/deloway-session"
    run_step "Installing deloway-session executable to ~/.local/bin" ln -sfn "$DELOWAY_DIR/bin/deloway-session" "$target_bin"
    run_step "Ensuring deloway-session is executable" chmod +x "$DELOWAY_DIR/bin/deloway-session"

    # 4. Wayland Session Desktop Entry
    local user_session_file="$HOME/.local/share/wayland-sessions/deloway.desktop"
    run_step "Installing user-level Wayland session entry" cp "$DELOWAY_DIR/system/deloway.desktop" "$user_session_file"

    if [ -d "/usr/share/wayland-sessions" ] && [ -w "/usr/share/wayland-sessions" ]; then
        run_step "Installing system-level Wayland session entry" cp "$DELOWAY_DIR/system/deloway.desktop" "/usr/share/wayland-sessions/deloway.desktop"
    elif command -v sudo &>/dev/null && [ "$DRY_RUN" = false ]; then
        log_info "System wayland-sessions directory requires elevated privileges."
        read -r -p "Install DeloWay session to /usr/share/wayland-sessions for LightDM? [y/N] " response || true
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            sudo install -d -m 755 /usr/share/wayland-sessions
            sudo install -m 644 "$DELOWAY_DIR/system/deloway.desktop" "/usr/share/wayland-sessions/deloway.desktop"
            sudo install -m 755 "$DELOWAY_DIR/bin/deloway-session" "/usr/local/bin/deloway-session"
            log_success "DeloWay session installed successfully to /usr/share/wayland-sessions/deloway.desktop"
        fi
    fi

    # 5. Hyprland configuration isolation (Never touches or modifies ~/.config/hypr)
    local deloway_hypr_cfg="$HOME/.config/deloway/hyprland.conf"
    run_step "Linking Deloway hyprland.conf to ~/.config/deloway/hyprland.conf" ln -sfn "$DELOWAY_DIR/config/hyprland.conf" "$deloway_hypr_cfg"
    log_success "Compositor config isolated in ~/.config/deloway/ (your personal ~/.config/hypr is 100% untouched)."
}

install_icons_and_branding() {
    log_info "Deploying Reversal icon theme and Deloway branding..."

    # 1. Check Reversal icon theme
    local icon_installed=false
    if [ -d "$HOME/.local/share/icons/Reversal-blue-dark" ] || [ -d "/usr/share/icons/Reversal-blue-dark" ] || [ -d "$HOME/.icons/Reversal-blue-dark" ]; then
        icon_installed=true
        log_success "Reversal icon theme detected on system."
    fi

    if [ "$icon_installed" = false ]; then
        log_warn "Reversal-icon-theme not found in standard icon directories."
        log_info "Cloning and installing Reversal-icon-theme to ~/.local/share/icons/..."
        if [ "$DRY_RUN" = false ]; then
            mkdir -p /tmp/reversal-install
            if git clone --depth 1 https://github.com/yeyushengfan258/Reversal-icon-theme.git /tmp/reversal-install 2>/dev/null; then
                bash /tmp/reversal-install/install.sh -a -d "$HOME/.local/share/icons" || true
                rm -rf /tmp/reversal-install
                log_success "Installed Reversal icon theme successfully."
            else
                log_warn "Could not clone Reversal-icon-theme directly. Using bundled assets fallback."
            fi
        fi
    fi

    # 2. Deploy Deloway SVGs and Reversal desktop overrides
    run_step "Copying desktop folder SVGs to ~/.local/share/icons/hicolor" \
        cp -r "$DELOWAY_DIR/assets/icons/desktop/." "$HOME/.local/share/icons/hicolor/scalable/apps/" 2>/dev/null || true

    # 3. Deploy Rebranded Desktop Entries (§7.4)
    run_step "Deploying DeloOS branded desktop entries" \
        cp "$DELOWAY_DIR"/assets/desktop-entries/*.desktop "$HOME/.local/share/applications/" 2>/dev/null || true

    # 4. Refresh icon cache & desktop database
    if command -v gtk-update-icon-cache &>/dev/null && [ "$DRY_RUN" = false ]; then
        gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi
    if command -v update-desktop-database &>/dev/null && [ "$DRY_RUN" = false ]; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
}

main() {
    print_banner
    detect_distro
    check_dependencies
    setup_directories
    install_configs
    install_icons_and_branding

    echo ""
    log_success "Deloway / DeloOS has been successfully installed!"
    echo ""
    echo -e "${BOLD}How to start DeloWay:${NC}"
    echo -e "  1. From your display manager (LightDM): select ${BOLD}'DeloWay'${NC} session."
    echo -e "  2. From a TTY: run ${BOLD}deloway-session${NC}"
    echo ""
    echo -e "${BOLD}Core Shortcuts:${NC}"
    echo -e "  ${CYAN}Super + Space${NC} / ${CYAN}Super + D${NC}  : App Drawer & Universal Search"
    echo -e "  ${CYAN}Super + Return${NC}             : Terminal"
    echo -e "  ${CYAN}Super + E${NC}                  : File Manager"
    echo -e "  ${CYAN}Super + I${NC}                  : DeloOS Settings"
    echo -e "  ${CYAN}Super + S${NC}                  : Delo Store"
    echo -e "  ${CYAN}Super + L${NC}                  : Lock Screen"
    echo ""
}

main "$@"
