#!/usr/bin/env bash
# ==============================================================================
# DeloOS / Deloway Desktop Experience - Comprehensive System Installer
# ==============================================================================
# Grounded in SYSTEM-REQUIREMENTS.md:
#   - Arch Linux-first native automation (Quickshell, Hyprland, Wayland stack)
#   - Hardware-conditional driver detection (RTL8188EUS, Nvidia/AMD, DDC/CI)
#   - Interactive application selection with centralized configuration
#   - Abstraction dispatcher deployment (delo-app)
#   - Zero hardcoded passwords; interactive sudo privilege elevation
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELOWAY_DIR="$SCRIPT_DIR"
USER_CONFIG_DIR="$HOME/.config/deloway"
USER_BIN_DIR="$HOME/.local/bin"
SESSIONS_DIR="$HOME/.local/share/wayland-sessions"

# ── ANSI Text Styling ─────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ── Flags ─────────────────────────────────────────────────────────────────────
DRY_RUN=false
SKIP_DEPS=false
AUTO_YES=false

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
    echo "  --dry-run      Simulate installation without making system changes"
    echo "  --no-deps      Skip package manager dependency checks/install"
    echo "  -y, --yes      Accept default selections without interactive prompts"
    echo "  -h, --help     Show this help message"
    echo ""
    exit 0
}

# Parse CLI Arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --no-deps) SKIP_DEPS=true ;;
        -y|--yes) AUTO_YES=true ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
    shift
done

log_info()    { echo -e "${BLUE}${BOLD}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}${BOLD}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}${BOLD}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$1${NC}"; }

# ── 1. Sanity Checks & Privilege Validation ───────────────────────────────────
check_sanity() {
    log_step "1. Checking System Environment"

    # Prevent running as root directly
    if [ "$EUID" -eq 0 ]; then
        log_error "Do not run this script directly with sudo or as root!"
        echo "The script must be run as your regular user. It will request sudo privileges when needed."
        exit 1
    fi

    # Distro Verification
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_LIKE="${ID_LIKE:-$ID}"
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE="unknown"
    fi

    log_info "Detected OS: ${BOLD}$NAME ($DISTRO_ID)${NC}"

    case "$DISTRO_LIKE" in
        *arch*)
            log_success "Arch-based distribution confirmed. Full native automation supported."
            ;;
        *)
            log_warn "===================================================================="
            log_warn "الدعم التلقائي متوفر حالياً على Arch Linux فقط."
            log_warn "الدعم الرسمي لتوزيعات أخرى ($NAME) مخطط له مستقبلاً."
            log_warn "===================================================================="
            if [ "$SKIP_DEPS" = false ]; then
                echo -e "${YELLOW}التثبيت التلقائي للتبعيات متوفر حالياً على Arch Linux فقط.${NC}"
                echo -e "يمكنك المتابعة باستخدام خيار ${BOLD}--no-deps${NC} إذا كانت بيئة Hyprland و Quickshell مجهزة مسبقاً."
                exit 1
            fi
            ;;
    esac

    # Validate / Refresh Sudo Session (Interactive, no hardcoded passwords)
    if [ "$DRY_RUN" = false ] && [ "$SKIP_DEPS" = false ]; then
        log_info "Validating administrative privileges..."
        if ! sudo -v; then
            log_error "Sudo authorization failed. Exiting."
            exit 1
        fi
        # Keep sudo timestamp alive in background during installation
        while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
        SUDO_KEEP_ALIVE_PID=$!
        trap 'kill $SUDO_KEEP_ALIVE_PID 2>/dev/null || true' EXIT
    fi
}

# ── 2. AUR Helper Detection & Bootstrap ───────────────────────────────────────
AUR_HELPER=""
check_aur_helper() {
    log_step "2. Checking AUR Helper"

    if [ "$SKIP_DEPS" = true ]; then
        log_info "Skipping AUR helper check (--no-deps)."
        return
    fi

    if command -v paru &>/dev/null; then
        AUR_HELPER="paru"
        log_success "Found AUR helper: ${BOLD}paru${NC}"
    elif command -v yay &>/dev/null; then
        AUR_HELPER="yay"
        log_success "Found AUR helper: ${BOLD}yay${NC}"
    else
        log_warn "No AUR helper (paru/yay) was found in PATH."
        echo -e "Essential DeloWay packages (e.g. Reversal icon theme) require an AUR helper."
        
        if [ "$AUTO_YES" = true ]; then
            CHOICE=1
        else
            echo ""
            echo "How would you like to proceed?"
            echo "  1) Install paru-bin automatically (Recommended)"
            echo "  2) Install yay-bin automatically"
            echo "  3) Skip AUR packages (Manual installation required later)"
            read -r -p "Enter choice [1-3] (Default: 1): " CHOICE
            CHOICE="${CHOICE:-1}"
        fi

        case "$CHOICE" in
            1)
                log_info "Bootstrapping paru-bin from AUR..."
                local tmp_dir
                tmp_dir=$(mktemp -d)
                git clone https://aur.archlinux.org/paru-bin.git "$tmp_dir/paru-bin"
                (cd "$tmp_dir/paru-bin" && makepkg -si --noconfirm)
                rm -rf "$tmp_dir"
                AUR_HELPER="paru"
                log_success "paru installed successfully!"
                ;;
            2)
                log_info "Bootstrapping yay-bin from AUR..."
                local tmp_dir
                tmp_dir=$(mktemp -d)
                git clone https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"
                (cd "$tmp_dir/yay-bin" && makepkg -si --noconfirm)
                rm -rf "$tmp_dir"
                AUR_HELPER="yay"
                log_success "yay installed successfully!"
                ;;
            *)
                log_warn "Proceeding without an AUR helper. AUR-dependent packages will be skipped."
                AUR_HELPER=""
                ;;
        esac
    fi
}

# ── 3. Interactive Default Applications Selection ─────────────────────────────
SELECTED_BROWSER="brave"
SELECTED_TERMINAL="kitty"
SELECTED_FILEMANAGER="thunar"
SELECTED_EDITOR="gnome-text-editor"
SELECTED_MONITOR="mission-center"

PKGS_TO_INSTALL=()
AUR_PKGS_TO_INSTALL=()

interactive_app_selection() {
    log_step "3. Default Applications Selection"
    echo -e "Choose your preferred default applications. DeloWay's ${BOLD}delo-app${NC} dispatcher"
    echo -e "will dynamically route keyboard shortcuts and interface actions to your selections."
    echo ""

    # ── A. Web Browser ────────────────────────────────────────────────────────
    if [ "$AUTO_YES" = true ]; then
        CHOICE_BROWSER=1
    else
        echo -e "${CYAN}${BOLD}[1/5] Select Default Web Browser:${NC}"
        echo "  1) Brave Browser (Default - Recommended) [AUR]"
        echo "  2) Mozilla Firefox [Official Repo]"
        echo "  3) Zen Browser [AUR]"
        echo "  4) Chromium [Official Repo]"
        echo "  5) Skip (Use existing system browser)"
        read -r -p "Choice [1-5] (Default: 1): " CHOICE_BROWSER
        CHOICE_BROWSER="${CHOICE_BROWSER:-1}"
    fi

    case "$CHOICE_BROWSER" in
        1)
            SELECTED_BROWSER="brave"
            AUR_PKGS_TO_INSTALL+=("brave-bin")
            ;;
        2)
            SELECTED_BROWSER="firefox"
            PKGS_TO_INSTALL+=("firefox")
            ;;
        3)
            SELECTED_BROWSER="zen-browser"
            AUR_PKGS_TO_INSTALL+=("zen-browser-bin")
            ;;
        4)
            SELECTED_BROWSER="chromium"
            PKGS_TO_INSTALL+=("chromium")
            ;;
        *)
            SELECTED_BROWSER="xdg-open"
            log_info "Skipping browser installation; defaulting to xdg-open."
            ;;
    esac

    # ── B. Terminal Emulator ──────────────────────────────────────────────────
    if [ "$AUTO_YES" = true ]; then
        CHOICE_TERM=1
    else
        echo ""
        echo -e "${CYAN}${BOLD}[2/5] Select Default Terminal Emulator:${NC}"
        echo "  1) Kitty (Default - Fully themed for DeloWay) [Official Repo]"
        echo "  2) Ghostty (Modern GPU-accelerated terminal) [Official Repo]"
        echo "  3) Alacritty (Fast, lightweight terminal) [Official Repo]"
        echo "  4) Foot (Wayland-native fast terminal) [Official Repo]"
        echo "  5) Skip"
        read -r -p "Choice [1-5] (Default: 1): " CHOICE_TERM
        CHOICE_TERM="${CHOICE_TERM:-1}"
    fi

    case "$CHOICE_TERM" in
        1)
            SELECTED_TERMINAL="kitty"
            PKGS_TO_INSTALL+=("kitty")
            ;;
        2)
            SELECTED_TERMINAL="ghostty"
            PKGS_TO_INSTALL+=("ghostty")
            ;;
        3)
            SELECTED_TERMINAL="alacritty"
            PKGS_TO_INSTALL+=("alacritty")
            ;;
        4)
            SELECTED_TERMINAL="foot"
            PKGS_TO_INSTALL+=("foot")
            ;;
        *)
            SELECTED_TERMINAL="kitty"
            ;;
    esac

    # ── C. File Manager ───────────────────────────────────────────────────────
    if [ "$AUTO_YES" = true ]; then
        CHOICE_FM=1
    else
        echo ""
        echo -e "${CYAN}${BOLD}[3/5] Select Default File Manager:${NC}"
        echo "  1) Thunar (Default - Lightweight XFCE) [Official Repo]"
        echo "  2) Nautilus (GNOME Files) [Official Repo]"
        echo "  3) PCManFM-Qt [Official Repo]"
        echo "  4) Skip"
        read -r -p "Choice [1-4] (Default: 1): " CHOICE_FM
        CHOICE_FM="${CHOICE_FM:-1}"
    fi

    case "$CHOICE_FM" in
        1)
            SELECTED_FILEMANAGER="thunar"
            PKGS_TO_INSTALL+=("thunar")
            ;;
        2)
            SELECTED_FILEMANAGER="nautilus"
            PKGS_TO_INSTALL+=("nautilus")
            ;;
        3)
            SELECTED_FILEMANAGER="pcmanfm-qt"
            PKGS_TO_INSTALL+=("pcmanfm-qt")
            ;;
        *)
            SELECTED_FILEMANAGER="thunar"
            ;;
    esac

    # ── D. Text Editor ────────────────────────────────────────────────────────
    if [ "$AUTO_YES" = true ]; then
        CHOICE_ED=1
    else
        echo ""
        echo -e "${CYAN}${BOLD}[4/5] Select Default Text Editor:${NC}"
        echo "  1) GNOME Text Editor (Default) [Official Repo]"
        echo "  2) Mousepad [Official Repo]"
        echo "  3) Kate [Official Repo]"
        echo "  4) Skip"
        read -r -p "Choice [1-4] (Default: 1): " CHOICE_ED
        CHOICE_ED="${CHOICE_ED:-1}"
    fi

    case "$CHOICE_ED" in
        1)
            SELECTED_EDITOR="gnome-text-editor"
            PKGS_TO_INSTALL+=("gnome-text-editor")
            ;;
        2)
            SELECTED_EDITOR="mousepad"
            PKGS_TO_INSTALL+=("mousepad")
            ;;
        3)
            SELECTED_EDITOR="kate"
            PKGS_TO_INSTALL+=("kate")
            ;;
        *)
            SELECTED_EDITOR="gnome-text-editor"
            ;;
    esac

    # ── E. System Monitor ─────────────────────────────────────────────────────
    if [ "$AUTO_YES" = true ]; then
        CHOICE_MON=1
    else
        echo ""
        echo -e "${CYAN}${BOLD}[5/5] Select Default System Monitor:${NC}"
        echo "  1) Mission Center (Default - Modern GUI) [AUR / Flatpak]"
        echo "  2) Btop (Terminal TUI monitor) [Official Repo]"
        echo "  3) GNOME System Monitor [Official Repo]"
        echo "  4) Skip"
        read -r -p "Choice [1-4] (Default: 1): " CHOICE_MON
        CHOICE_MON="${CHOICE_MON:-1}"
    fi

    case "$CHOICE_MON" in
        1)
            SELECTED_MONITOR="mission-center"
            AUR_PKGS_TO_INSTALL+=("mission-center")
            ;;
        2)
            SELECTED_MONITOR="btop"
            PKGS_TO_INSTALL+=("btop")
            ;;
        3)
            SELECTED_MONITOR="gnome-system-monitor"
            PKGS_TO_INSTALL+=("gnome-system-monitor")
            ;;
        *)
            SELECTED_MONITOR="btop"
            ;;
    esac
}

# ── 4. Hardware-Conditional Dependency Detection ──────────────────────────────
detect_hardware_deps() {
    log_step "4. Inspecting Hardware & Drivers"

    if [ "$SKIP_DEPS" = true ]; then
        log_info "Skipping hardware driver checks (--no-deps)."
        return
    fi

    # 1. WiFi: Realtek RTL8188EUS Check
    if command -v lsusb &>/dev/null; then
        if lsusb | grep -qi "0bda:8179"; then
            log_warn "Detected Realtek RTL8188EUS USB WiFi adapter (0bda:8179)."
            log_info "The default in-kernel driver lacks AP mode and suffers stability issues."
            log_info "Queuing '8188eu-aircrack-dkms-git' and 'linux-headers' for AP mode and full stability."
            PKGS_TO_INSTALL+=("linux-headers")
            AUR_PKGS_TO_INSTALL+=("8188eu-aircrack-dkms-git")
        else
            log_info "No legacy RTL8188EUS USB adapter detected; using standard in-kernel WiFi drivers."
        fi
    fi

    # 2. GPU: Nvidia Proprietary Check
    if command -v lspci &>/dev/null; then
        if lspci -nn | grep -E "VGA|3D" | grep -qi "10de"; then
            log_info "Nvidia GPU detected."
            if ! pacman -Qs nvidia &>/dev/null; then
                log_info "Queuing 'nvidia-dkms' and 'nvidia-utils' for Wayland hardware acceleration."
                PKGS_TO_INSTALL+=("nvidia-dkms" "nvidia-utils" "linux-headers")
            else
                log_success "Nvidia drivers already installed."
            fi
        else
            log_info "Non-Nvidia (AMD/Intel) GPU detected; ensuring standard Mesa drivers."
            PKGS_TO_INSTALL+=("mesa")
        fi
    fi

    # 3. Brightness: Laptop vs Desktop DDC/CI
    local has_backlight=false
    if [ -d /sys/class/backlight ] && [ "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
        has_backlight=true
    fi

    if [ "$has_backlight" = true ]; then
        log_info "Internal display backlight detected (/sys/class/backlight). Queuing 'brightnessctl'."
        PKGS_TO_INSTALL+=("brightnessctl")
    else
        log_info "No internal backlight detected (Desktop/External Monitor). Queuing 'ddcutil' for DDC/CI control."
        PKGS_TO_INSTALL+=("ddcutil")
    fi
}

# ── 5. Core Packages & Optional Tools ─────────────────────────────────────────
queue_core_packages() {
    log_step "5. Queuing Core System Tools"

    if [ "$SKIP_DEPS" = true ]; then
        return
    fi

    # Mandatory Wayland / Hyprland / DeloWay tools from SYSTEM-REQUIREMENTS.md
    local core_tools=(
        "hyprland"
        "quickshell"
        "grim"
        "slurp"
        "hyprpicker"
        "wf-recorder"
        "playerctl"
        "wl-clipboard"
        "networkmanager"
        "bluez"
        "jq"
        "libnotify"
        "cliphist"
        "fuzzel"
        "ttf-jetbrains-mono-nerd"
        "pavucontrol"
    )

    for pkg in "${core_tools[@]}"; do
        PKGS_TO_INSTALL+=("$pkg")
    done

    # Reversal Icon Theme
    if [ ! -d "/usr/share/icons/Reversal-dark" ] && [ ! -d "$HOME/.local/share/icons/Reversal-dark" ]; then
        log_info "Queuing 'reversal-icon-theme-git' from AUR."
        AUR_PKGS_TO_INSTALL+=("reversal-icon-theme-git")
    fi

    # Optional Tools: Satty & SwayOSD (Explicitly separated from code integration)
    if [ "$AUTO_YES" = true ]; then
        INSTALL_OPTIONAL=1
    else
        echo ""
        echo -e "${YELLOW}${BOLD}Optional Productivity Tools:${NC}"
        echo -e "  - ${BOLD}satty${NC}: Modern screenshot annotation and crop tool"
        echo -e "  - ${BOLD}swayosd${NC}: Visual on-screen display for volume and brightness"
        echo -e "  (Note: Installing them now prepares the packages; hotkey integration is handled separately)"
        read -r -p "Install satty and swayosd now? [y/N]: " RESP_OPT
        if [[ "$RESP_OPT" =~ ^[yY] ]]; then
            PKGS_TO_INSTALL+=("satty" "swayosd")
            log_info "Queued satty and swayosd."
        fi
    fi
}

# ── 6. Package Installation Execution ─────────────────────────────────────────
install_packages() {
    log_step "6. Installing System Packages"

    if [ "$SKIP_DEPS" = true ]; then
        log_info "Skipping package installation (--no-deps)."
        return
    fi

    # Remove duplicates from arrays
    read -ra PKGS_TO_INSTALL <<< "$(printf '%s\n' "${PKGS_TO_INSTALL[@]}" | sort -u | tr '\n' ' ')"
    read -ra AUR_PKGS_TO_INSTALL <<< "$(printf '%s\n' "${AUR_PKGS_TO_INSTALL[@]}" | sort -u | tr '\n' ' ')"

    # Official packages via pacman
    if [ ${#PKGS_TO_INSTALL[@]} -gt 0 ]; then
        log_info "Installing official packages via pacman: ${PKGS_TO_INSTALL[*]}"
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} sudo pacman -S --needed ${PKGS_TO_INSTALL[*]}"
        else
            sudo pacman -S --needed --noconfirm "${PKGS_TO_INSTALL[@]}"
        fi
    fi

    # AUR packages via helper
    if [ ${#AUR_PKGS_TO_INSTALL[@]} -gt 0 ]; then
        if [ -n "$AUR_HELPER" ]; then
            log_info "Installing AUR packages via $AUR_HELPER: ${AUR_PKGS_TO_INSTALL[*]}"
            if [ "$DRY_RUN" = true ]; then
                echo -e "${CYAN}[DRY-RUN]${NC} $AUR_HELPER -S --needed ${AUR_PKGS_TO_INSTALL[*]}"
            else
                "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS_TO_INSTALL[@]}"
            fi
        else
            log_warn "AUR helper not available. Please install manually: ${AUR_PKGS_TO_INSTALL[*]}"
        fi
    fi

    # Enable essential system services
    if [ "$DRY_RUN" = false ]; then
        log_info "Enabling essential system services..."
        sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
        sudo systemctl enable --now bluetooth.service 2>/dev/null || true

        # If ddcutil was installed, load i2c-dev module and add user to i2c group
        if [[ " ${PKGS_TO_INSTALL[*]} " =~ " ddcutil " ]]; then
            log_info "Configuring DDC/CI permissions for monitor brightness..."
            echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 || true
            sudo modprobe i2c-dev 2>/dev/null || true
            sudo usermod -aG i2c "$USER" 2>/dev/null || true
        fi
    fi
}

# ── 7. Centralized Configuration & Dispatcher Deployment ──────────────────────
configure_deloway() {
    log_step "7. Configuring DeloWay Environment"

    local dirs=(
        "$USER_CONFIG_DIR"
        "$USER_CONFIG_DIR/backups"
        "$USER_BIN_DIR"
        "$HOME/.config/hypr"
        "$SESSIONS_DIR"
        "$HOME/Desktop"
    )

    for d in "${dirs[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} mkdir -p $d"
        else
            mkdir -p "$d"
        fi
    done

    # 1. Update / Generate ~/.config/deloway/deloway.json with defaultApps
    local target_cfg="$USER_CONFIG_DIR/deloway.json"
    log_info "Configuring centralized application settings in $target_cfg..."

    if [ "$DRY_RUN" = false ]; then
        if [ ! -f "$target_cfg" ]; then
            cp "$DELOWAY_DIR/config/deloway.json" "$target_cfg"
        fi

        # Inject defaultApps using jq or python3
        python3 - << EOF
import json, os

cfg_path = os.path.expanduser("$target_cfg")
try:
    with open(cfg_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

data["defaultApps"] = {
    "browser": "$SELECTED_BROWSER",
    "terminal": "$SELECTED_TERMINAL",
    "fileManager": "$SELECTED_FILEMANAGER",
    "editor": "$SELECTED_EDITOR",
    "monitor": "$SELECTED_MONITOR"
}
# Backward compatibility keys
data["browser"] = "$SELECTED_BROWSER"
data["terminal"] = "$SELECTED_TERMINAL"
data["fileManager"] = "$SELECTED_FILEMANAGER"

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
EOF
        log_success "Application defaults saved to deloway.json"
    fi

    # 2. Deploy Abstraction Dispatcher (delo-app)
    local target_dispatcher="$USER_BIN_DIR/delo-app"
    log_info "Installing Abstraction Dispatcher to $target_dispatcher..."
    if [ "$DRY_RUN" = false ]; then
        ln -sfn "$DELOWAY_DIR/bin/delo-app" "$target_dispatcher"
        chmod +x "$DELOWAY_DIR/bin/delo-app"
        log_success "delo-app linked successfully."
    fi

    # 3. Deploy deloway-session
    local target_session_bin="$USER_BIN_DIR/deloway-session"
    log_info "Installing Session Runner to $target_session_bin..."
    if [ "$DRY_RUN" = false ]; then
        ln -sfn "$DELOWAY_DIR/bin/deloway-session" "$target_session_bin"
        chmod +x "$DELOWAY_DIR/bin/deloway-session"
    fi

    # 4. Link Shell directory
    local target_shell="$USER_CONFIG_DIR/shell"
    if [ "$DRY_RUN" = false ]; then
        rm -rf "$target_shell"
        ln -sfn "$DELOWAY_DIR/shell" "$target_shell"
    fi

    # 5. Install Wayland Desktop Session Entry
    local session_desktop="$SESSIONS_DIR/deloway.desktop"
    log_info "Registering Wayland session in $session_desktop..."
    if [ "$DRY_RUN" = false ]; then
        cat > "$session_desktop" << EOF
[Desktop Entry]
Name=DeloWay
Comment=Fluent Mica Wayland Desktop Environment on Hyprland
Exec=$USER_BIN_DIR/deloway-session
Type=Application
DesktopNames=DeloWay;Hyprland
EOF
    fi

    # 6. Apply Icon Theme
    if command -v gsettings &>/dev/null && [ "$DRY_RUN" = false ]; then
        gsettings set org.gnome.desktop.interface icon-theme "Reversal-dark" 2>/dev/null || true
    fi
}

# ── 8. Summary & Next Steps ───────────────────────────────────────────────────
print_completion_summary() {
    log_step "Installation Complete!"
    echo -e "${GREEN}${BOLD}DeloWay Desktop Environment is ready!${NC}\n"
    echo -e "Summary of configured default applications:"
    echo -e "  - ${BOLD}Terminal:${NC}     $SELECTED_TERMINAL (Invoked via 'delo-app terminal')"
    echo -e "  - ${BOLD}Browser:${NC}      $SELECTED_BROWSER (Invoked via 'delo-app browser')"
    echo -e "  - ${BOLD}File Manager:${NC} $SELECTED_FILEMANAGER (Invoked via 'delo-app files')"
    echo -e "  - ${BOLD}Text Editor:${NC}  $SELECTED_EDITOR (Invoked via 'delo-app editor')"
    echo -e "  - ${BOLD}Monitor:${NC}      $SELECTED_MONITOR (Invoked via 'delo-app monitor')"
    echo ""
    echo -e "To start your DeloWay session:"
    echo -e "  1. Log out of your current session."
    echo -e "  2. Select ${BOLD}DeloWay${NC} from your display manager (SDDM/GDM/Greetd)."
    echo -e "  3. Or launch directly from TTY with: ${BOLD}$USER_BIN_DIR/deloway-session${NC}"
    echo ""
}

main() {
    print_banner
    check_sanity
    check_aur_helper
    interactive_app_selection
    detect_hardware_deps
    queue_core_packages
    install_packages
    configure_deloway
    print_completion_summary
}

main "$@"
