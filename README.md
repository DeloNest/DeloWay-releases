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
- **Calm Mica Aesthetic**: Inspired by modern Windows 11 Fluent Design principles but elevated with a distinct, independent identity: deep calm Mica surfaces, 10px rounded corners, subtle translucent borders, and strictly **zero over-saturated neon glow**.
- **Reversal Icon Pack with Amber Folder Uniformity**: Visual clarity with rectangular vector badges and 100% color-unified warm amber folders (`#f5aa1e` / `#f08705` / `#ffc841`) across Home, Trash, Projects, Media, and user folders.
- **Human-Editable JSON Config**: Both the GUI Settings app and hand-edited dotfiles share the exact same `~/.config/deloway/deloway.json` with live reactive hot-reloading.

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
4. Hot-reloads the Quickshell shell live without terminating your open applications.

---

## ⌨️ Essential Keyboard Shortcuts

| Shortcut | Function |
|---|---|
| <kbd>Super</kbd> + <kbd>Space</kbd> / <kbd>Super</kbd> + <kbd>D</kbd> | Open App Drawer & Universal Search |
| <kbd>Super</kbd> + <kbd>I</kbd> | Open DeloOS Settings |
| <kbd>Super</kbd> + <kbd>S</kbd> | Open Delo App Store |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock Screen (`ext-session-lock-v1`) |
| <kbd>Super</kbd> + <kbd>A</kbd> | Quick Settings / Control Center |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Open Terminal (Kitty) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Open File Manager (Thunar) |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close Focused Window |
| <kbd>Super</kbd> + <kbd>F</kbd> | Toggle Fullscreen |
| <kbd>Super</kbd> + <kbd>1</kbd> .. <kbd>5</kbd> | Switch Workspaces |
| <kbd>Print</kbd> / <kbd>Shift</kbd> + <kbd>Print</kbd> | Fullscreen or Area Screenshot |

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
2. Design tokens strictly adhere to `shell/theme/theme.json`.
3. All components interface through central services (`ApplicationManager`, `DesktopManager`, `ConfigManager`).

---

<p align="center">
  <sub>Crafted with passion for the modern Linux desktop.</sub>
</p>
