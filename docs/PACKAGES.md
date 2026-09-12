# DeloOS / Deloway Multi-Distro Package Reference

This guide outlines system package names and installation commands across major Linux distributions to ensure a frictionless installation of Deloway.

---

## 1. Distribution Package Matrix

| Component | Arch Linux | Fedora Linux | Debian / Ubuntu (24.04+) | openSUSE Tumbleweed |
|---|---|---|---|---|
| **Compositor** | `hyprland` | `hyprland` | `hyprland` (or PPA) | `hyprland` |
| **Shell Framework** | `quickshell` / `quickshell-git` (AUR) | `quickshell` (Copr) | `quickshell` (cargo / release) | `quickshell` |
| **Terminal Emulator** | `kitty` | `kitty` | `kitty` | `kitty` |
| **File Manager** | `thunar` | `thunar` | `thunar` | `thunar` |
| **Screenshots & Snips**| `grim`, `slurp` | `grim`, `slurp` | `grim`, `slurp` | `grim`, `slurp` |
| **Clipboard Tool** | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` |
| **Brightness Control**| `brightnessctl` | `brightnessctl` | `brightnessctl` | `brightnessctl` |
| **Media Controller** | `playerctl` | `playerctl` | `playerctl` | `playerctl` |
| **Audio Server** | `pipewire`, `wireplumber` | `pipewire`, `wireplumber` | `pipewire`, `wireplumber` | `pipewire`, `wireplumber` |
| **JSON Parser** | `jq` | `jq` | `jq` | `jq` |
| **Monospace Font** | `ttf-jetbrains-mono-nerd` | `jetbrains-mono-fonts` | `fonts-jetbrains-mono` | `jetbrains-mono-fonts` |
| **UI Font** | `ttf-inter` | `inter-fonts` | `fonts-inter` | `inter-fonts` |
| **Icon Theme** | `reversal-icon-theme-git` (AUR) | Manual / git clone | Manual / git clone | Manual / git clone |

---

## 2. One-Command Setup by Distro

### Arch Linux / EndeavourOS / CachyOS
```bash
sudo pacman -S --needed hyprland kitty thunar grim slurp wl-clipboard \
  brightnessctl playerctl wireplumber pipewire jq ttf-jetbrains-mono-nerd ttf-inter

# Using your preferred AUR helper (paru or yay) for Quickshell & Icons:
paru -S --needed quickshell reversal-icon-theme-git
```

### Fedora Linux (Workstation 40+)
```bash
sudo dnf install hyprland kitty thunar grim slurp wl-clipboard \
  brightnessctl playerctl wireplumber pipewire jq jetbrains-mono-fonts inter-fonts

# Enable Quickshell Copr:
sudo dnf copr enable outfoxxed/quickshell
sudo dnf install quickshell
```

### Ubuntu / Debian (24.04 LTS+)
```bash
sudo apt update
sudo apt install hyprland kitty thunar grim slurp wl-clipboard \
  brightnessctl playerctl wireplumber pipewire jq fonts-jetbrains-mono fonts-inter
```

### openSUSE Tumbleweed
```bash
sudo zypper install hyprland kitty thunar grim slurp wl-clipboard \
  brightnessctl playerctl wireplumber pipewire jq
```

---

## 3. Flatpak Support

In accordance with Section 6 of the architecture plan, Flatpak is the recommended application distribution mechanism for universal, distro-agnostic desktop software:

```bash
# Enable Flatpak and Flathub repository if not already enabled:
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```
The **Delo Store** natively indexes Flathub packages and provides immediate one-click installs.
