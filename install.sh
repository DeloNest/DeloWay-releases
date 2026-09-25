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
        echo -e "Some DeloWay packages (Cairo font, LocalSend, pamac) come from the AUR and need a helper."
        
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
                if [ "$DRY_RUN" = true ]; then
                    echo -e "${CYAN}[DRY-RUN]${NC} git clone https://aur.archlinux.org/paru-bin.git && makepkg -si --noconfirm"
                else
                    local tmp_dir
                    tmp_dir=$(mktemp -d)
                    git clone https://aur.archlinux.org/paru-bin.git "$tmp_dir/paru-bin"
                    (cd "$tmp_dir/paru-bin" && makepkg -si --noconfirm)
                    rm -rf "$tmp_dir"
                    log_success "paru installed successfully!"
                fi
                AUR_HELPER="paru"
                ;;
            2)
                log_info "Bootstrapping yay-bin from AUR..."
                if [ "$DRY_RUN" = true ]; then
                    echo -e "${CYAN}[DRY-RUN]${NC} git clone https://aur.archlinux.org/yay-bin.git && makepkg -si --noconfirm"
                else
                    local tmp_dir
                    tmp_dir=$(mktemp -d)
                    git clone https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"
                    (cd "$tmp_dir/yay-bin" && makepkg -si --noconfirm)
                    rm -rf "$tmp_dir"
                    log_success "yay installed successfully!"
                fi
                AUR_HELPER="yay"
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
# Built from packaging/<name>/PKGBUILD with makepkg: pinned upstream sources DeloWay
# needs that no repo or AUR package ships in the required form.
LOCAL_PKGS_TO_BUILD=()
FOUND_RTL8188EUS=""   # USB id of a detected RTL8188EUS adapter (detect_hardware_deps)

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
            PKGS_TO_INSTALL+=("mission-center")   # in extra, not the AUR
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
# Headers for every installed kernel (DKMS builds a module per kernel). Arch kernels record
# their package name in /usr/lib/modules/<version>/pkgbase (linux, linux-lts, linux-zen…).
queue_kernel_headers() {
    local f
    for f in /usr/lib/modules/*/pkgbase; do
        [ -r "$f" ] && PKGS_TO_INSTALL+=("$(<"$f")-headers")
    done
}

detect_hardware_deps() {
    log_step "4. Inspecting Hardware & Drivers"

    if [ "$SKIP_DEPS" = true ]; then
        log_info "Skipping hardware driver checks (--no-deps)."
        return
    fi

    # 1. Wi-Fi: USB adapters whose in-kernel driver cannot run a hotspot. Read from sysfs:
    # lsusb needs usbutils, which a fresh Arch lacks, and the check used to skip silently.
    # IDs are the USB aliases of the 8188eu module (packaging/rtl8188eus-dkms).
    local rtl8188eus_ids=" 0bda:8179 0bda:0179 056e:4008 07b8:8179 0df6:0076 2001:330f 2001:3310 2001:3311 2001:331b 2357:010c 7392:b811 "
    local usb id
    for usb in /sys/bus/usb/devices/*; do
        [ -r "$usb/idVendor" ] && [ -r "$usb/idProduct" ] || continue
        id="$(<"$usb/idVendor"):$(<"$usb/idProduct")"
        [[ "$rtl8188eus_ids" == *" $id "* ]] && FOUND_RTL8188EUS="$id"
    done
    if [ -n "$FOUND_RTL8188EUS" ]; then
        log_warn "Detected a Realtek RTL8188EUS USB Wi-Fi adapter ($FOUND_RTL8188EUS)."
        log_info "The in-kernel rtl8xxxu driver has no hotspot (AP) mode for it and its firmware start fails intermittently."
        if pacman -Q rtl8188eus-dkms &>/dev/null; then
            log_success "rtl8188eus-dkms already installed."
        else
            log_info "Queuing the rtl8188eus DKMS driver (packaging/rtl8188eus-dkms) with kernel headers."
            PKGS_TO_INSTALL+=("dkms")
            queue_kernel_headers
            LOCAL_PKGS_TO_BUILD+=("rtl8188eus-dkms")
        fi
    else
        log_info "No USB Wi-Fi adapter that needs an out-of-tree driver detected."
    fi

    # 2. GPU: NVIDIA needs a kernel module package. Arch ships the open modules
    # (nvidia-open / nvidia-open-dkms, Turing and newer); nvidia-dkms is no longer in the
    # repos, and queuing it aborted the whole pacman transaction. `pacman -Qs nvidia` also
    # matched unrelated packages (egl-wayland), so an installed driver is checked by name.
    local gpu has_nvidia=false
    for gpu in /sys/bus/pci/devices/*; do
        [[ "$(<"$gpu/class")" == 0x03* ]] && [ "$(<"$gpu/vendor")" = "0x10de" ] && has_nvidia=true
    done
    if [ "$has_nvidia" = true ]; then
        log_info "NVIDIA GPU detected."
        # (process substitution, not a pipe: under pipefail `pacman … | grep -q` fails
        #  whenever pacman exits non-zero or grep closes the pipe early)
        if grep -qE '^(nvidia-open|nvidia-open-dkms|nvidia-open-lts|nvidia|nvidia-dkms|nvidia-lts|nvidia-[0-9]+xx-dkms)$' \
                <(pacman -Qq 2>/dev/null); then
            log_success "NVIDIA kernel driver already installed."
        else
            log_info "Queuing 'nvidia-open-dkms' and 'nvidia-utils' (GPUs older than Turing need a legacy driver from the AUR)."
            PKGS_TO_INSTALL+=("nvidia-open-dkms" "nvidia-utils")
            queue_kernel_headers
        fi
    else
        log_info "Non-NVIDIA (AMD/Intel) GPU detected; ensuring standard Mesa drivers."
        PKGS_TO_INSTALL+=("mesa")
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
        # Called unconditionally by the shell / helpers (missing = silently broken feature):
        "python"                 # every scripts/*.py helper (stdlib only)
        "base-devel"             # makepkg: packaging/* (icon theme, drivers) and AUR builds
        "git"                    #   … and their git sources
        "hyprsunset"             # Quick Settings → Night Light
        "power-profiles-daemon"  # Quick Settings → power profile
        "hyprpolkitagent"        # polkit prompts (hyprland.conf exec-once, package actions)
        "wireplumber"            # wpctl: volume keys / audio page
        "gvfs"                   # trash:// for the Dock / desktop Trash
        # QML modules the shell imports (missing = components fail to load):
        "kirigami"               # org.kde.kirigami (AppIcon)
        "qt6-5compat"            # Qt5Compat.GraphicalEffects
        "qt6-svg"                # SVG icons and assets
        "qt6-imageformats"       # WebP wallpapers
        # Tools the helpers and binds call:
        "python-gobject"         # deloway-bluetooth.py scan (Gio / BlueZ discovery)
        "bluez-utils"            # bluetoothctl (restores power after airplane mode)
        "iw"                     # Wi-Fi / hotspot capability checks
        "dnsmasq"                # hotspot: NetworkManager's shared mode runs it for DHCP/DNS
        "wireless-regdb"         # Wi-Fi regulatory database (country channels / TX power)
        "usbutils"               # lsusb, for diagnosing USB Wi-Fi adapters
        "pciutils"               # lspci
        "psmisc"                 # killall (binds, shell restart)
        "pipewire-pulse"         # PipeWire audio server (pw-play / paplay alarm sound)
        "hyprlock"               # Super+L fallback when the shell is not running
        "xdg-utils"              # xdg-open / xdg-mime / xdg-settings (default apps)
        "gtk3"                   # gtk-launch (delo-app, desktop shortcuts)
        "zenity"                 # "Browse…" file picker for wallpapers
        # Fonts: Arabic coverage and the Settings → Appearance font choices
        "noto-fonts"
        "inter-font"
    )

    for pkg in "${core_tools[@]}"; do
        PKGS_TO_INSTALL+=("$pkg")
    done

    # Quickshell: an installed quickshell-git (or any provider) conflicts with extra/quickshell
    # and would abort the whole pacman transaction, so only queue it when nothing provides it.
    if command -v quickshell &>/dev/null || pacman -Qq quickshell quickshell-git &>/dev/null; then
        log_info "Quickshell already installed ($(pacman -Qqo "$(command -v quickshell)" 2>/dev/null || echo present)); not queuing it."
    else
        PKGS_TO_INSTALL+=("quickshell")
    fi

    # Icon theme: the session uses Reversal-black / Reversal-black-dark (QS_ICON_THEME,
    # theme-apply switches them by mode). The AUR's reversal-icon-theme-git installs only
    # the default blue variant (its PKGBUILD passes -a, "--alternative"), so without this
    # every app icon falls back to a letter; packaging/deloway-icon-theme builds the black one.
    if ! pacman -Q deloway-icon-theme &>/dev/null \
       && [ ! -f "/usr/share/icons/Reversal-black-dark/index.theme" ] \
       && [ ! -f "$HOME/.local/share/icons/Reversal-black-dark/index.theme" ]; then
        log_info "Queuing 'deloway-icon-theme' (Reversal, black variant) to build locally."
        LOCAL_PKGS_TO_BUILD+=("deloway-icon-theme")
    fi

    # AUR packages the shell depends on:
    #   ttf-cairo      — the default UI font (Theme.qml falls back to "Cairo")
    #   localsend-bin  — Notch → Share (LocalSend)
    #   pamac-aur      — App Store entry, "View in Store", package install / uninstall
    # fc-list -q: exit status only. `fc-list | grep -qi` was always "missing" under
    # pipefail (grep -q exits early, fc-list dies of SIGPIPE), so ttf-cairo was re-queued.
    if ! fc-list -q "Cairo" 2>/dev/null; then
        AUR_PKGS_TO_INSTALL+=("ttf-cairo")
    fi
    command -v localsend &>/dev/null || command -v localsend_app &>/dev/null || [ -x "$HOME/.local/bin/localsend" ] \
        || AUR_PKGS_TO_INSTALL+=("localsend-bin")
    command -v pamac &>/dev/null || AUR_PKGS_TO_INSTALL+=("pamac-aur")

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

    build_local_packages

    # Enable essential system services
    if [ "$DRY_RUN" = false ]; then
        log_info "Enabling essential system services..."
        sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
        sudo systemctl enable --now bluetooth.service 2>/dev/null || true
        sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

        # If ddcutil was installed, load i2c-dev module and add user to i2c group
        if [[ " ${PKGS_TO_INSTALL[*]} " =~ " ddcutil " ]]; then
            log_info "Configuring DDC/CI permissions for monitor brightness..."
            echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 || true
            sudo modprobe i2c-dev 2>/dev/null || true
            sudo usermod -aG i2c "$USER" 2>/dev/null || true
        fi
    fi
}

# Build and install each queued packaging/<name>/PKGBUILD. makepkg -s pulls the repo
# dependencies; pacman then owns the files, so removal and updates work normally.
build_local_packages() {
    [ ${#LOCAL_PKGS_TO_BUILD[@]} -eq 0 ] && return
    local name dir work
    for name in "${LOCAL_PKGS_TO_BUILD[@]}"; do
        dir="$DELOWAY_DIR/packaging/$name"
        log_info "Building $name from packaging/$name..."
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} (cd $dir && makepkg -si --needed --noconfirm)"
            continue
        fi
        work=$(mktemp -d)
        cp -r "$dir/." "$work/"
        if (cd "$work" && makepkg -si --needed --noconfirm); then
            log_success "Installed $name."
        else
            log_error "Building $name failed (see the makepkg output above)."
        fi
        rm -rf "$work"
    done
}

# ── 6b. Wi-Fi & Hotspot ───────────────────────────────────────────────────────
# Everything a hotspot needs beyond the packages: the Wi-Fi country (without it the
# kernel stays on the restrictive "world" domain 00) and, with Docker, forwarding for
# shared connections.
configure_networking() {
    log_step "6b. Configuring Wi-Fi & Hotspot"

    local has_wifi=false w
    for w in /sys/class/net/*/wireless /sys/class/net/*/phy80211; do
        [ -e "$w" ] && has_wifi=true
    done
    [ -n "$FOUND_RTL8188EUS" ] && has_wifi=true   # driver may only bind after install

    # Regulatory domain from the configured time zone (zone.tab maps zones to countries).
    if [ "$has_wifi" = true ]; then
        if grep -qs 'ieee80211_regdom' /etc/modprobe.d/*.conf; then
            log_info "Wi-Fi country already configured in /etc/modprobe.d."
        else
            local tz cc
            tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
            cc=$(awk -F'\t' -v tz="$tz" '!/^#/ && $3 == tz { print $1; exit }' /usr/share/zoneinfo/zone.tab 2>/dev/null)
            if [ -n "$cc" ]; then
                log_info "Setting the Wi-Fi country to $cc (from time zone $tz)."
                if [ "$DRY_RUN" = true ]; then
                    echo -e "${CYAN}[DRY-RUN]${NC} echo 'options cfg80211 ieee80211_regdom=$cc' | sudo tee /etc/modprobe.d/deloway-wifi-country.conf"
                else
                    echo "options cfg80211 ieee80211_regdom=$cc" | sudo tee /etc/modprobe.d/deloway-wifi-country.conf >/dev/null \
                        && sudo iw reg set "$cc" 2>/dev/null || true
                fi
            else
                log_warn "Could not tell the Wi-Fi country from the time zone; set it with: sudo iw reg set <CC>"
            fi
        fi
    else
        log_info "No Wi-Fi adapter present; skipping Wi-Fi country setup."
    fi

    # Docker drops forwarded traffic (FORWARD policy DROP), so hotspot clients connect but
    # get no internet. The dispatcher script allows forwarding for shared connections
    # while they are up (DOCKER-USER chain).
    if command -v docker &>/dev/null; then
        log_info "Docker found: installing the hotspot forwarding hook for NetworkManager."
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} sudo install -Dm755 system/NetworkManager/dispatcher.d/90-deloway-hotspot-forward /etc/NetworkManager/dispatcher.d/"
        else
            sudo install -Dm755 "$DELOWAY_DIR/system/NetworkManager/dispatcher.d/90-deloway-hotspot-forward" \
                /etc/NetworkManager/dispatcher.d/90-deloway-hotspot-forward \
                || log_warn "Could not install the hotspot forwarding hook."
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
        local fresh_cfg=0
        if [ ! -f "$target_cfg" ]; then
            cp "$DELOWAY_DIR/config/deloway.json" "$target_cfg"
            fresh_cfg=1
        fi

        # Inject defaultApps using jq or python3
        python3 - << EOF
import json, os

cfg_path = os.path.expanduser("$target_cfg")
fresh = $fresh_cfg == 1
try:
    with open(cfg_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

chosen = {
    "browser": "$SELECTED_BROWSER",
    "terminal": "$SELECTED_TERMINAL",
    "fileManager": "$SELECTED_FILEMANAGER",
    "editor": "$SELECTED_EDITOR",
    "monitor": "$SELECTED_MONITOR"
}
# A fresh config takes the installer answers; on re-runs (repairs/updates) only
# missing keys are filled so Settings → Apps choices are never overwritten.
apps = data.get("defaultApps") if isinstance(data.get("defaultApps"), dict) else {}
for k, v in chosen.items():
    if fresh or not apps.get(k):
        apps[k] = v
data["defaultApps"] = apps
# Backward compatibility keys
for k in ("browser", "terminal", "fileManager"):
    if fresh or not data.get(k):
        data[k] = apps[k]

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

    # 4. Link Shell directory. A real directory there (e.g. a customised copy) is
    # moved to backups/, never deleted; an existing symlink is simply replaced.
    local target_shell="$USER_CONFIG_DIR/shell"
    if [ "$DRY_RUN" = false ]; then
        if [ -d "$target_shell" ] && [ ! -L "$target_shell" ]; then
            local bk="$USER_CONFIG_DIR/backups/shell-$(date +%Y%m%d-%H%M%S)"
            mv "$target_shell" "$bk"
            log_warn "Existing $target_shell moved to $bk"
        fi
        ln -sfn "$DELOWAY_DIR/shell" "$target_shell"
    fi

    # 4b. Per-user compositor config (deloway-session loads ~/.config/deloway/hyprland.conf).
    # At the default clone location it is a link to the repo file; elsewhere it is a copy
    # with $delowayDir pointing at this clone (update.sh regenerates it). A hand-edited
    # real file is left alone.
    local user_hypr="$USER_CONFIG_DIR/hyprland.conf"
    local marker="# Generated by DeloWay install.sh"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} set up $user_hypr for $DELOWAY_DIR"
    elif [ -e "$user_hypr" ] && [ ! -L "$user_hypr" ] && [[ "$(head -1 "$user_hypr")" != *"$marker"* ]]; then
        log_warn "$user_hypr is a customised file; leaving it unchanged."
    elif [ "$DELOWAY_DIR" = "$HOME/Projects/Deloway" ]; then
        ln -sfn "$DELOWAY_DIR/config/hyprland.conf" "$user_hypr"
    else
        rm -f "$user_hypr"
        { echo "$marker for $DELOWAY_DIR — edits are overwritten by update.sh"
          sed "s|^\\\$delowayDir = .*|\\\$delowayDir = $DELOWAY_DIR|" "$DELOWAY_DIR/config/hyprland.conf"; } > "$user_hypr"
        log_success "Generated $user_hypr for $DELOWAY_DIR"
    fi

    # 5. Register the session with the display manager. SDDM / GDM / LightDM only read the
    # system session folders, so this needs sudo: link the wrapper into /usr/local/bin (a
    # link, so updates reach it) and install the .desktop entry pointing at it.
    log_info "Registering the DeloWay session for the display manager..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} sudo ln -sfn $DELOWAY_DIR/bin/deloway-session /usr/local/bin/deloway-session"
        echo -e "${CYAN}[DRY-RUN]${NC} sudo install -Dm644 $DELOWAY_DIR/system/deloway.desktop /usr/share/wayland-sessions/deloway.desktop"
    elif sudo ln -sfn "$DELOWAY_DIR/bin/deloway-session" /usr/local/bin/deloway-session \
         && sudo install -Dm644 "$DELOWAY_DIR/system/deloway.desktop" /usr/share/wayland-sessions/deloway.desktop; then
        SESSION_REGISTERED=true
        rm -f "$SESSIONS_DIR/deloway.desktop"   # old per-user entry no display manager reads
        log_success "Session registered: pick 'DeloWay' on the login screen."
    else
        log_warn "Could not register the session. Run ./scripts/install-session.sh later."
    fi

    # 6. PAM service for the shell's lock screen (LockScreen.qml uses "deloway";
    # without it the lock screen falls back to hyprlock's or login's PAM file).
    log_info "Installing lock-screen PAM service to /etc/pam.d/deloway..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} sudo install -Dm644 $DELOWAY_DIR/system/pam.d/deloway /etc/pam.d/deloway"
    elif ! sudo install -Dm644 "$DELOWAY_DIR/system/pam.d/deloway" /etc/pam.d/deloway; then
        log_warn "Could not install /etc/pam.d/deloway (the lock screen will use the 'login' PAM service)."
    fi

    # 7. Icon theme: verify it really landed (apps show letters instead of icons without
    # it), then set it for GTK.
    if [ "$DRY_RUN" = false ]; then
        if [ -f "/usr/share/icons/Reversal-black-dark/index.theme" ] \
           || [ -f "$HOME/.local/share/icons/Reversal-black-dark/index.theme" ]; then
            command -v gsettings &>/dev/null \
                && gsettings set org.gnome.desktop.interface icon-theme "Reversal-black-dark" 2>/dev/null || true
        elif [ "$SKIP_DEPS" = false ]; then
            log_error "Icon theme Reversal-black-dark is missing: app icons will show as letters."
            log_error "Build it with: (cd $DELOWAY_DIR/packaging/deloway-icon-theme && makepkg -si)"
        fi
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
    if [ "${SESSION_REGISTERED:-false}" = true ]; then
        echo -e "  2. Pick ${BOLD}DeloWay${NC} in the session menu of your login screen (SDDM/GDM/LightDM)."
    else
        echo -e "  2. Register the session first: ${BOLD}./scripts/install-session.sh${NC}, then pick ${BOLD}DeloWay${NC} at login."
    fi
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
    configure_networking
    configure_deloway
    print_completion_summary
}

main "$@"
