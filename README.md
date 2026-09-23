# DeloOS / Deloway Desktop Experience

<p align="center">
  <img src="assets/wallpaper.jpg" alt="Deloway Desktop" width="800" style="border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.5);" />
</p>

<p align="center">
  <b>A modern, cohesive Linux desktop experience built on Hyprland and Quickshell.</b><br/>
  Fluent Mica elegance • Integrated Application Lifecycle • 3 Selectable Desktop Modes • Zero Neon AI Glow
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Wayland-100%25-blue?style=flat-square" alt="Wayland" />
  <img src="https://img.shields.io/badge/Compositor-Hyprland-00a8ff?style=flat-square" alt="Hyprland" />
  <img src="https://img.shields.io/badge/Shell-Quickshell%20%2B%20QML-41cd52?style=flat-square" alt="Quickshell" />
  <img src="https://img.shields.io/badge/Toolkit-Qt6%20%2F%20Fluent-blueviolet?style=flat-square" alt="Qt6" />
  <img src="https://img.shields.io/badge/Icons-Reversal-ffaa00?style=flat-square" alt="Reversal Icons" />
  <img src="https://img.shields.io/badge/License-GPLv3-lightgrey?style=flat-square" alt="License" />
</p>

---

## 🌟 Vision & Design Principles

Deloway is **not** a traditional "Hyprland dotfiles rice" where disparate utilities (Waybar, Rofi, Dunst, SwayNC, Hyprlock) are glued together with fragile shell scripts and inconsistent color palettes.

Instead, Deloway delivers:
- **One Integrated Shell Application**: The top bar, dock, app drawer, search, notifications, quick settings, lock screen, desktop, and settings app live inside **one cohesive codebase** sharing a single in-memory state and unified configuration file.
- **Strict Monochrome, OLED-first**: exactly two modes — **Dark** (pure black, neutral grays) and **Light** (crisp high-contrast neutrals) — switched in Settings → Appearance. There is no accent color; hierarchy comes from luminance, weight and layering. Red / amber / green appear only as tiny status indicators.
- **Reversal-black Icons**: the icon theme follows the mode (Reversal-black in Light, Reversal-black-dark in Dark), together with GTK apps, window borders and the DeloWay kitty profile.
- **Human-Editable JSON Config**: the Settings app and hand edits share `~/.config/deloway/deloway.json`. Settings changes apply instantly; hand edits apply on the next shell restart.

---

## 🖥️ Desktop Modes (§5.8)

Choose the desktop experience that fits your workflow directly from the Settings App or desktop right-click menu:

| Clean Mode | Widgets Mode | Traditional Mode |
|:---:|:---:|:---:|
| Minimalist wallpaper view without file or widget clutter. Includes bottom status pills. | Movable, draggable Fluent Mica cards (Clock/Date, Weather, Hardware Monitor, Quick Notes). | Full desktop grid with files, folders, rubber-band multi-select, and inline rename. |

---

## 🚀 Quick Start & Installation

Deloway includes an automated installer that detects your Linux distribution and configures all components:

### 1. Clone the repository
```bash
git clone https://github.com/DeloOS/Deloway.git
cd Deloway
```

### 2. Run the automated installer
```bash
./install.sh
```

*(Options: `--dry-run` to inspect commands without modifying the system; `--no-deps` to skip package manager checks).*

### 3. Log into Deloway
- From your display manager (**SDDM**, **GDM**, **LightDM**, or **greetd**), select the **"Deloway"** session.
- Or launch directly from a TTY:
  ```bash
  deloway-session
  ```

---

## 🔄 Updates & Safe Migration

Upgrade Deloway seamlessly with the built-in migration engine:

```bash
./update.sh
```

**What `update.sh` does:**
1. Pulls latest upstream improvements.
2. Creates an automatic timestamped backup of your user configuration in `~/.config/deloway/backups/`.
3. Performs non-destructive deep schema migration, backfilling any newly introduced features without overwriting your custom settings.
4. Detects the running shell and prints the clean-restart command (`./update.sh --restart` runs it). DeloWay never hot-reloads QML: live reloads can crash Quickshell.

---

## ⌨️ Essential Keyboard Shortcuts

| Shortcut | Function |
|---|---|
| <kbd>Super</kbd> (tap) / <kbd>Super</kbd> + <kbd>A</kbd> | Start menu (App Drawer) |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Search |
| <kbd>Super</kbd> + <kbd>N</kbd> / <kbd>Super</kbd> + <kbd>M</kbd> | Quick Settings |
| <kbd>Super</kbd> + <kbd>I</kbd> | DeloWay Settings |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock screen (the shell's `ext-session-lock` screen; hyprlock if the shell is not running) |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Super</kbd> + <kbd>/</kbd> | Keyboard shortcuts overlay |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Terminal |
| <kbd>Super</kbd> + <kbd>E</kbd> | File manager |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close focused window |
| <kbd>Super</kbd> + <kbd>F</kbd> | Fullscreen |
| <kbd>Super</kbd> + <kbd>1</kbd> .. <kbd>0</kbd> | Switch workspace |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> / <kbd>Print</kbd> | Area / full-screen screenshot |

*See [`docs/KEYBINDINGS.md`](docs/KEYBINDINGS.md) for the complete reference.*

---

## 📚 Documentation Index

- [**System Architecture**](docs/ARCHITECTURE.md): Deep dive into the QML shell architecture, services layer, and Hyprland IPC bridge.
- [**Configuration Guide**](docs/CONFIGURATION.md): Complete schema reference for `config/deloway.json` and hand-editing tips.
- [**Multi-Distro Packaging**](docs/PACKAGES.md): Package installation guides for Arch, Fedora, Debian/Ubuntu, and openSUSE.
- [**Keybindings Cheatsheet**](docs/KEYBINDINGS.md): Full compositor and shell shortcut reference.

---

## 👥 Contributing

Contributions are welcome! Please ensure that:
1. All QML changes pass `qmllint` cleanly:
   ```bash
   qmllint -I shell/ -I /usr/lib/qt6/qml shell/shell.qml shell/components/*.qml
   ```
2. Colors come only from tokens in `shell/theme/Theme.qml` (strict monochrome, see `CLAUDE.md`), and `./scripts/check-theme.sh` passes.
3. All components interface through central services (`ApplicationManager`, `DesktopManager`, `ConfigManager`).

---

<p align="center">
  <sub>Crafted with passion for the modern Linux desktop.</sub>
</p>
