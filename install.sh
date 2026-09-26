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
        echo -e "Some DeloWay packages (Cairo font, pamac) come from the AUR and need a helper."
        
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
# The menus come from config/default-apps.tsv — the same catalog the Setup Wizard and
# Settings → Apps offer — so every place shows the same alternatives. An empty selection
# (Skip) leaves the role to the shell's default.
DEFAULT_APPS_TSV="$DELOWAY_DIR/config/default-apps.tsv"
SELECTED_BROWSER=""
SELECTED_TERMINAL=""
SELECTED_FILEMANAGER=""
SELECTED_EDITOR=""
SELECTED_MONITOR=""

PKGS_TO_INSTALL=()
AUR_PKGS_TO_INSTALL=()
# Built from packaging/<name>/PKGBUILD with makepkg: pinned upstream sources DeloWay
# needs that no repo or AUR package ships in the required form.
LOCAL_PKGS_TO_BUILD=()
FOUND_RTL8188EUS=""   # USB id of a detected RTL8188EUS adapter (detect_hardware_deps)

# select_default_app ROLE LABEL STEP — prints the role's menu (or takes its default with
# -y), queues the package when the chosen app is missing and sets REPLY_APP to its command.
select_default_app() {
    local role="$1" label="$2" step="$3"
    local -a cmds=() names=() pkgs=() srcs=()
    local def=1 n=0 r cmd desktop pkg src name flag
    while IFS=$'\t' read -r r cmd desktop pkg src name flag; do
        [[ -z "$r" || "$r" == \#* || "$r" != "$role" ]] && continue
        cmds+=("$cmd"); names+=("$name"); pkgs+=("$pkg"); srcs+=("$src")
        n=$((n + 1))
        [ "${flag:-}" = "default" ] && def=$n
    done < "$DEFAULT_APPS_TSV"

    local choice="$def" i tag mark
    if [ "$AUTO_YES" != true ]; then
        echo ""
        echo -e "${CYAN}${BOLD}[$step/5] $label:${NC}"
        for ((i = 0; i < n; i++)); do
            tag="[Official Repo]"; [ "${srcs[i]}" = "aur" ] && tag="[AUR]"
            mark=""
            [ $((i + 1)) -eq "$def" ] && mark=" (Default)"
            command -v "${cmds[i]}" &>/dev/null && mark="$mark (installed)"
            echo "  $((i + 1))) ${names[i]}$mark $tag"
        done
        echo "  $((n + 1))) Skip"
        read -r -p "Choice [1-$((n + 1))] (Default: $def): " choice
        choice="${choice:-$def}"
    fi

    REPLY_APP=""
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$n" ]; then
        i=$((choice - 1))
        REPLY_APP="${cmds[i]}"
        if ! command -v "${cmds[i]}" &>/dev/null; then
            # shellcheck disable=SC2206  # the column may list companions: split on spaces
            if [ "${srcs[i]}" = "aur" ]; then AUR_PKGS_TO_INSTALL+=(${pkgs[i]})
            else PKGS_TO_INSTALL+=(${pkgs[i]}); fi
        fi
        # KDE apps need the Breeze style to look right (deloway-theme-apply.py), also
        # when the app itself was installed before.
        if [ "${cmds[i]}" = "dolphin" ] && command -v dolphin &>/dev/null && ! pacman -Q breeze &>/dev/null; then
            PKGS_TO_INSTALL+=("breeze")
        fi
    fi
}

interactive_app_selection() {
    log_step "3. Default Applications Selection"
    echo -e "Choose your default applications. DeloWay's ${BOLD}delo-app${NC} dispatcher routes"
    echo -e "keyboard shortcuts and the shell to them; the Setup Wizard and Settings → Apps"
    echo -e "offer the same choices later."

    select_default_app browser "Default Web Browser" 1;       SELECTED_BROWSER="$REPLY_APP"
    select_default_app terminal "Default Terminal" 2;         SELECTED_TERMINAL="$REPLY_APP"
    select_default_app fileManager "Default File Manager" 3;  SELECTED_FILEMANAGER="$REPLY_APP"
    select_default_app editor "Default Text Editor" 4;        SELECTED_EDITOR="$REPLY_APP"
    select_default_app monitor "Default System Monitor" 5;    SELECTED_MONITOR="$REPLY_APP"
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
        "adw-gtk-theme"          # adw-gtk3: the base the DeloWay GTK3 themes are built on
        "zenity"                 # file pickers: wallpaper "Browse…", Notch → Share "Choose files…"
        # Fonts: Arabic coverage and the Settings → Appearance font choices
        "noto-fonts"
        "noto-fonts-emoji"       # emoji in titles, notifications, chat apps (else tofu boxes)
        "ttf-dejavu"             # DejaVu Sans Mono: Arabic in terminals, never the UI font
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
    #   pamac-aur      — App Store entry, "View in Store", package install / uninstall
    # fc-list -q: exit status only. `fc-list | grep -qi` was always "missing" under
    # pipefail (grep -q exits early, fc-list dies of SIGPIPE), so ttf-cairo was re-queued.
    if ! fc-list -q "Cairo" 2>/dev/null; then
        AUR_PKGS_TO_INSTALL+=("ttf-cairo")
    fi
    # (Notch → Share needs no LocalSend app: scripts/deloway-localsend.py speaks the protocol.)

    # Default viewers by file type (config/default-apps.tsv): images, videos, PDFs. The
    # shell makes them the defaults on first run (scripts/deloway-default-app.py);
    # Settings → Apps offers the alternatives and the browser.
    pacman -Q loupe &>/dev/null || PKGS_TO_INSTALL+=("loupe")
    pacman -Q papers &>/dev/null || PKGS_TO_INSTALL+=("papers")
    pacman -Q cine &>/dev/null || AUR_PKGS_TO_INSTALL+=("cine")

    # Archives: Ark gives the file manager its Compress / Extract menus (Dolphin through
    # Ark's own plugins, Thunar through thunar-archive-plugin, which drives Ark) and opens
    # archives. Backends: libarchive (tar, tar.gz/xz/bz2/zst — already a dependency),
    # libzip (zip, an Ark dependency), 7zip (7z; the 7z command) and unrar (RAR
    # extraction; freeware, Ark does not read RAR through 7zip). zip/unzip for scripts.
    local archive_pkg
    for archive_pkg in ark 7zip unrar zip unzip; do
        pacman -Q "$archive_pkg" &>/dev/null || PKGS_TO_INSTALL+=("$archive_pkg")
    done
    if pacman -Q thunar &>/dev/null && ! pacman -Q thunar-archive-plugin &>/dev/null; then
        PKGS_TO_INSTALL+=("thunar-archive-plugin")
    fi
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

# ── 6a. Locales ───────────────────────────────────────────────────────────────
# DeloWay is Arabic-first. Without a generated Arabic locale LANG cannot switch to
# Arabic (glibc falls back to "C"), so app names in the Dock/App Drawer/search stay
# English in the Arabic UI and GTK/Qt apps stay LTR. deloway-locale-apply.py switches
# LANG on a language change only when the locale exists; this makes sure it does.
configure_locales() {
    log_step "6a. Generating Locales"
    local want=("en_US.UTF-8 UTF-8" "ar_SA.UTF-8 UTF-8") missing=() l
    for l in "${want[@]}"; do
        grep -qE "^${l%% *}[[:space:]]" /etc/locale.gen 2>/dev/null || missing+=("$l")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        log_success "English and Arabic locales are enabled."
        return
    fi
    log_info "Enabling locales: ${missing[*]%% *}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} enable ${missing[*]%% *} in /etc/locale.gen && sudo locale-gen"
        return
    fi
    for l in "${missing[@]}"; do
        # Uncomment the stock line, or append it when the file does not have one
        if grep -qE "^#[[:space:]]*${l%% *}[[:space:]]" /etc/locale.gen; then
            sudo sed -i -E "s|^#[[:space:]]*(${l%% *}[[:space:]].*)|\1|" /etc/locale.gen
        else
            echo "$l" | sudo tee -a /etc/locale.gen >/dev/null
        fi
    done
    sudo locale-gen || log_warn "locale-gen failed; Arabic app names need the ar_SA.UTF-8 locale."
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

    # A host firewall (ufw, Docker) drops what hotspot clients need: ufw their DHCP/DNS
    # requests and forwarding (phones join but never get an address), Docker their
    # forwarding (no internet). The dispatcher script opens exactly that, for the hotspot
    # interface, while a shared connection is up.
    if command -v ufw &>/dev/null || command -v docker &>/dev/null; then
        log_info "Firewall found: installing the hotspot hook for NetworkManager."
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} sudo install -Dm755 system/NetworkManager/dispatcher.d/90-deloway-hotspot-forward /etc/NetworkManager/dispatcher.d/"
        else
            sudo install -Dm755 "$DELOWAY_DIR/system/NetworkManager/dispatcher.d/90-deloway-hotspot-forward" \
                /etc/NetworkManager/dispatcher.d/90-deloway-hotspot-forward \
                || log_warn "Could not install the hotspot hook."
        fi
    fi

    # Notch → Share (LocalSend): nearby devices find this computer and send to it on port
    # 53317 (multicast UDP + HTTPS). ufw drops both by default. The rule is added even
    # while ufw is disabled, so it is in place when it gets enabled.
    if command -v ufw &>/dev/null; then
        log_info "ufw found: allowing LocalSend (port 53317) for Notch sharing."
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} sudo install -Dm644 system/ufw/applications.d/deloway-localsend /etc/ufw/applications.d/"
            echo -e "${CYAN}[DRY-RUN]${NC} sudo ufw allow LocalSend"
        else
            sudo install -Dm644 "$DELOWAY_DIR/system/ufw/applications.d/deloway-localsend" \
                /etc/ufw/applications.d/deloway-localsend \
                && sudo ufw allow LocalSend >/dev/null \
                || log_warn "Could not allow LocalSend through ufw; nearby devices will not find this computer."
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
    if v and (fresh or not apps.get(k)):   # skipped roles keep the shell's default
        apps[k] = v
data["defaultApps"] = apps
# Backward compatibility keys
for k in ("browser", "terminal", "fileManager"):
    if apps.get(k) and (fresh or not data.get(k)):
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
    configure_locales
    configure_networking
    configure_deloway
    print_completion_summary
}

main "$@"
