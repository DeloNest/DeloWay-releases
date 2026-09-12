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
  - **App Store**: Curated package store with featured apps, reviews, categories, and one-click installation.
  - **First-Run Setup Wizard**: Onboarding wizard initializing user preferences before first desktop presentation.

---

## 3. The Application Lifecycle Model

Per Section 4.1 of the authoritative plan, **no surface tracks its own independent list of applications**. All surfaces interface with `ApplicationManager.qml`.

```
                    ┌───────────────────────────┐
                    │     Delo App Store        │
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

The shell uses a centralized JSON design token architecture (`theme.json`) rather than hardcoded CSS:

- **Tokens Hierarchy**:
  - `deloos-dark.json`: Calm Mica dark palette (`#161922`, `#1e2330`, `#2a3142`).
  - `deloos-light.json`: Calm Mica light palette (`#f3f4f6`, `#ffffff`, `#e2e8f0`).
- **Accent Parity**:
  - `primary` and `accent` (`#0084ff`) remain identical in both dark and light modes.
  - Folder colors (`#f5aa1e`, `#f08705`, `#ffc841`) remain strictly identical across all themes to preserve visual identity.
- **Cross-Toolkit Propagation**:
  - Whenever `Theme.setMode(mode)` or `ConfigManager.setThemeMode(mode)` is invoked:
    1. Updates `shell/theme/theme.json`.
    2. Dispatches `gsettings set org.gnome.desktop.interface color-scheme (prefer-dark | prefer-light)`.
    3. Updates GTK 3/4 CSS in `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css`.
    4. Dynamically updates Hyprland window border colors via `hyprctl keyword general:col.active_border`.

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
| `openStore(category)` | `category: string` | Opens Delo Store to a specific category |
| `openStoreApp(appId)` | `appId: string` | Opens Delo Store directly to an app's details |
| `setMode(mode)` | `mode: string` (`"dark" \| "light"`) | Switches system theme mode |
| `setDesktopMode(mode)` | `mode: string` (`"clean" \| "widgets" \| "traditional"`) | Switches desktop mode |
| `showDesktopContextMenu(x, y)` | `x: int, y: int` | Displays wallpaper context menu |
| `showItemContextMenu(id, x, y)`| `itemId: string, x: int, y: int` | Displays desktop item context menu |
| `closeContextMenu()` | None | Closes any active context menu |
