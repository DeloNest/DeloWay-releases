# DeloOS / Deloway Desktop Architecture

This document details the software architecture, design patterns, data flows, and subsystem responsibilities of the **Deloway** desktop experience.

---

## 1. High-Level Architecture Overview

Deloway is designed from the ground up as a **single, cohesive desktop shell** atop the **Hyprland** Wayland compositor. Rather than gluing together disparate third-party utilities (e.g. Waybar, Rofi, Dunst, SwayNC, Hyprlock) with conflicting configuration files and out-of-sync styling, Deloway implements all visible desktop surfaces in a single codebase sharing one unified in-memory state and one central configuration file.

```
                  ┌──────────────────────────────────────────────┐
                  │                 USER DISPLAY                 │
                  └──────────────────────┬───────────────────────┘
                                         │
        ┌────────────────────────────────┴────────────────────────────────┐
        │                 DELOWAY FLUENT QML SHELL (Quickshell)           │
        │                                                                 │
        │   ┌───────────────┐  ┌───────────────┐  ┌───────────────────┐  │
        │   │    TopBar     │  │     Dock      │  │     AppDrawer     │  │
        │   └───────┬───────┘  └───────┬───────┘  └─────────┬─────────┘  │
        │   ┌───────┴───────┐  ┌───────┴───────┐  ┌─────────┴─────────┐  │
        │   │ QuickSettings │  │ Notifications │  │    UniversalSearch │  │
        │   └───────┬───────┘  └───────┬───────┘  └─────────┬─────────┘  │
        │   ┌───────┴───────┐  ┌───────┴───────┐  ┌─────────┴─────────┐  │
        │   │    Desktop    │  │  SettingsApp  │  │     AppStore      │  │
        │   │(Clean/Widgets/│  │               │  │                   │  │
        │   │  Traditional) │  │               │  │                   │  │
        │   └───────┬───────┘  └───────┬───────┘  └─────────┬─────────┘  │
        │           │                  │                    │            │
        │   ════════╪══════════════════╪════════════════════╪═════════   │
        │           │           CORE SERVICES LAYER         │            │
        │           ▼                  ▼                    ▼            │
        │   ┌───────────────┐  ┌───────────────┐  ┌───────────────────┐  │
        │   │DesktopManager │  │ ConfigManager │  │ApplicationManager │  │
        │   └───────────────┘  └───────┬───────┘  └─────────┬─────────┘  │
        │   ┌───────────────┐          │          ┌─────────┴─────────┐  │
        │   │PackageManager │          │          │    Theme / Tokens │  │
        │   └───────────────┘          │          └───────────────────┘  │
        └──────────────────────────────┼──────────────────────────────────┘
                                       │ (Hyprland IPC Socket & Events)
                                       ▼
                  ┌──────────────────────────────────────────────┐
                  │          HYPRLAND WAYLAND COMPOSITOR         │
                  │  (Window Management, Workspaces, Input, DRM)  │
                  └──────────────────────┬───────────────────────┘
                                         │
                  ┌──────────────────────────────────────────────┐
                  │             LINUX SYSTEM & HARDWARE          │
                  │  (PipeWire, BlueZ, NetworkManager, UPower)   │
                  └──────────────────────────────────────────────┘
```

---

## 2. Core Subsystems & Responsibilities

### 2.1 Hyprland Compositor (Unmodified Upstream)
- **Role**: Window management, tiling algorithms, workspace management, layer-shell compositing, input handling, and Wayland protocol dispatching.
- **DECIDED Principle**: Hyprland is used strictly as an upstream compositor. No C++ forks or internal plugins are used. Communication happens exclusively over Hyprland's UNIX command socket (`hyprctl` / `hl.dsp.*`) and event socket (`submap`, `workspace`, `openwindow`, `closewindow`, `activewindow`).

### 2.2 Shell Layer (Quickshell + QML)
- **Role**: Renders all visual surfaces:
  - **TopBar**: Status indicators, workspace pills, clock, network, and battery icons.
  - **Dock**: Fluid macOS/Windows-style dock with running indicators, badge counters, and auto-hide support.
  - **App Drawer & Universal Search**: Multi-category application launcher with real-time fuzzy filtering.
  - **Quick Settings**: Fluent Mica flyout panel for Wi-Fi, Bluetooth, volume, brightness, power profiles, and DND.
  - **Notifications**: Wayland native `org.freedesktop.Notifications` implementation.
  - **Lock Screen**: Hardware-secure Wayland session lock via `ext-session-lock-v1`.
  - **Desktop Surface**: Three distinct selectable modes (Clean, Widgets, and Traditional).
  - **Settings App**: Complete native GUI for system and shell customizations.
  - **App Store**: there is no in-shell store UI. The "App Store" launcher entry and "View in Store" open `pamac-manager` (AUR `pamac-aur`); installs and uninstalls go through `pamac`.
  - **First-Run Setup Wizard**: Onboarding wizard initializing user preferences before first desktop presentation.

---

## 3. The Application Lifecycle Model

Per Section 4.1 of the authoritative plan, **no surface tracks its own independent list of applications**. All surfaces interface with `ApplicationManager.qml`.

```
                    ┌───────────────────────────┐
                    │        App Store          │
                    │   (Install / Uninstall)   │
                    └─────────────┬─────────────┘
                                  │ 1. Package Installed
                                  ▼
                    ┌───────────────────────────┐
                    │  XDG Desktop Entry on disk│
                    │(~/.local/share/applications)
                    └─────────────┬─────────────┘
                                  │ 2. Detected by FileWatch
                                  ▼
      ┌───────────────────────────────────────────────────────────────┐
      │                     ApplicationManager.qml                    │
      │   - Maintains central app models                             │
      │   - Matches window titles / classes to app metadata           │
      │   - Manages 'pinned', 'running', 'windows', 'needsAttention'  │
      └───────┬───────────────────────┬───────────────────────┬───────┘
              │                       │                       │
              ▼                       ▼                       ▼
      ┌───────────────┐       ┌───────────────┐       ┌───────────────┐
      │   App Drawer  │       │  Dock State   │       │UniversalSearch│
      │  (Categorized)│       │(Running Dots) │       │ (Fuzzy Match) │
      └───────────────┘       └───────────────┘       └───────────────┘
```

### Application State Machine:
1. **Installed**: Recognized from `/usr/share/applications` or `~/.local/share/applications`.
2. **Pinned**: Persisted in `config/deloway.json` under `dock.pinnedApps`.
3. **Running**: Updated live when Hyprland emits `openwindow`. The window's class is resolved to an app ID, setting `running = true` and incrementing `windowCount`.
4. **Focused / Multi-window**: Active window indicators reflect across Dock and TopBar.
5. **Closed**: When Hyprland emits `closewindow`, `windowCount` decrements. When it reaches 0, `running = false`.

---

## 4. Desktop Modes Subsystem (§5.8)

Deloway supports three distinct desktop operating modes, managed by `DesktopManager.qml` and `Background.qml`:

```
                           ConfigManager.desktopMode
                                      │
               ┌──────────────────────┼──────────────────────┐
               ▼                      ▼                      ▼
         [Clean Mode]          [Widgets Mode]       [Traditional Mode]
      Minimalist backdrop      Draggable Fluent      Grid of files/folders
      with status pills        Mica cards with       with Reversal icons,
      only.                    persisted (x, y).     rubber-band select,
                                                     and inline rename.
```

1. **Clean Mode (`CleanDesktop.qml`)**:
   - Focus on visual calm and zero distraction.
   - Right-click invokes the wallpaper context menu.
   - Retains the bottom-left `[⊞ Desktop]` indicator and bottom-right power pill.

2. **Widgets Mode (`WidgetsDesktop.qml`)**:
   - Four interactive Fluent Mica cards:
     - **Clock & Date**: High-resolution typography, AM/PM, weekday, and date.
     - **Weather & Forecast**: Temperature, conditions, humidity, wind, and UV index.
     - **System Hardware Monitor**: Live CPU, RAM, and Battery consumption gauges.
     - **Quick Notes**: Persistent scratchpad for daily tasks and checklists.
   - All widget positions `(x, y)` are saved in real-time to `deloway.json`.

3. **Traditional Mode (`TraditionalDesktop.qml`)**:
   - Live scanning of `~/Desktop`.
   - Unified amber folder icons from `Reversal-icon-theme`.
   - Rubber-band multi-select rectangle with dynamic bounding box intersection testing.
   - Inline rename `TextField`.
   - Trash integration (`user-trash-empty` vs `user-trash-full`).

---

## 5. Design Token System & Theming Architecture

DeloWay is strictly monochrome (see `CLAUDE.md`): two modes, no accent color, and red / amber /
green only as tiny status indicators.

- **Tokens**: `shell/theme/Theme.qml` is the only source of colors. It holds the dark and light
  palettes (pure neutral grays) and the mode-aware tokens components use (`notch*`, `inverseSurface`,
  `textSelection`, `modalScrim`, `onImageText`, …). Components never contain hex colors;
  `./scripts/check-theme.sh` enforces it.
- **Mode**: `ConfigManager.themeMode` (persisted as `theme.mode` in `deloway.json`) is the single
  source of truth. `Theme.mode`, `Theme.isDark` and `Theme.colors` are pure bindings on it.
- **Propagation**: `ConfigManager.setThemeMode(mode)`:
  1. saves `deloway.json` (the shell restyles through bindings);
  2. pushes the Hyprland border colors for the mode (`general:col.active_border` / `col.inactive_border`);
  3. runs `scripts/deloway-theme-apply.py`, which sets `color-scheme`, the DeloWay-Dark/Light GTK
     theme and GTK 3/4 CSS, and switches the icon theme between Reversal-black-dark and Reversal-black.
  kitty launched through `delo-app` follows the system scheme itself (`config/kitty/*-theme.auto.conf`).

---

## 6. IPC Interface Reference

Quickshell exposes an `IpcHandler` target named `deloway` that permits external scripting and test automation:

| IPC Method | Arguments | Purpose |
|---|---|---|
| `toggleDrawer()` | None | Toggles the App Drawer / Search overlay |
| `openDrawer()` | None | Opens the App Drawer |
| `setSearchQuery(q)` | `query: string` | Opens Drawer with pre-filled search term |
| `toggleSettings()` | None | Toggles the DeloOS Settings app |
| `openSettingsTab(tab)` | `tabId: string` | Directly jumps to a specific settings tab |
| `toggleQuickSettings()` | None | Toggles the Quick Settings flyout |
| `showSetup()` | None | Spawns the First-Run Setup Wizard |
| `setMode(mode)` | `mode: string` (`"dark" \| "light"`) | Switches system theme mode |
| `setDesktopMode(mode)` | `mode: string` (`"clean" \| "widgets" \| "traditional"`) | Switches desktop mode |
| `showDesktopContextMenu(x, y)` | `x: int, y: int` | Displays wallpaper context menu |
| `showItemContextMenu(id, x, y)`| `itemId: string, x: int, y: int` | Displays desktop item context menu |
| `closeContextMenu()` | None | Closes any active context menu |
