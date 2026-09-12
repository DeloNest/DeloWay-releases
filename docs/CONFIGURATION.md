# DeloOS / Deloway Configuration Guide

This document explains the unified configuration model of Deloway, detailing the schema of `deloway.json`, hand-editing best practices, and reactive hot-reloading.

---

## 1. Unified Configuration Philosophy

In accordance with Section 9 of the project plan, Deloway rejects the idea of a GUI-only configuration model. Hyprland and Linux power users expect their systems to be version-controllable, readable, and human-editable.

- **Primary Path**: `~/.config/deloway/deloway.json`
- **Fallback / Template**: `/home/waleed/Projects/Deloway/config/deloway.json`
- **One Source of Truth**: The exact same file is read and written by:
  1. The **Settings App** (`SettingsApp.qml`)
  2. The **First-Run Setup Wizard** (`SetupWizard.qml`)
  3. The **Quick Settings** panel (`QuickSettings.qml`)
  4. The user editing the file in Vim, Nano, or VS Code.
- **Reactive Hot-Reload**: Changes made to `deloway.json` on disk are immediately detected via file-watching (`FileView`) and applied live to the running desktop without dropping windows or restarting the compositor.

---

## 2. Complete Schema Reference

Below is an annotated example of a complete `deloway.json` file:

```json
{
  "theme": {
    "mode": "dark",
    "accentColor": "#0084ff",
    "wallpaper": "/home/waleed/Projects/Deloway/assets/wallpaper.jpg"
  },
  "desktop": {
    "mode": "clean",
    "showIcons": true,
    "widgetPositions": {
      "clock": { "x": 60, "y": 70 },
      "weather": { "x": 380, "y": 70 },
      "system_monitor": { "x": 60, "y": 280 },
      "notes": { "x": 380, "y": 280 }
    },
    "enabledWidgets": [
      "clock",
      "weather",
      "system_monitor",
      "notes"
    ]
  },
  "dock": {
    "position": "bottom",
    "autoHide": false,
    "iconSize": 38,
    "showUnderline": true,
    "pinnedApps": [
      "firefox",
      "code",
      "files",
      "terminal",
      "spotify",
      "discord"
    ]
  },
  "topBar": {
    "showBrand": true,
    "showWorkspaces": true,
    "clockFormat": "12h",
    "workspacesCount": 5
  },
  "windows": {
    "activeBorder": "#0084ff",
    "inactiveBorder": "#2a3142",
    "gapsIn": 5,
    "gapsOut": 10,
    "rounding": 10
  },
  "notifications": {
    "dnd": false,
    "timeout": 5000,
    "sound": false
  },
  "power": {
    "profile": "balanced",
    "sleepTimeout": 30
  },
  "defaultApps": {
    "browser": "firefox",
    "terminal": "kitty",
    "fileManager": "thunar",
    "editor": "code"
  },
  "setupCompleted": true
}
```

---

## 3. Detailed Property Breakdown

### 3.1 `theme`
- `mode` *(string)*: `"dark"` or `"light"`. Swaps active design tokens between dark and light Mica surfaces.
- `accentColor` *(string, hex)*: Primary system highlight color (e.g. `"#0084ff"` or `"#64748b"`). Drives window borders, active tabs, buttons, and sliders.
- `wallpaper` *(string, path)*: Absolute path to the desktop wallpaper image. Supports JPEG, PNG, and WebP.

### 3.2 `desktop`
- `mode` *(string)*: Selects the desktop presentation style:
  - `"clean"`: Minimalist wallpaper view without file or widget clutter.
  - `"widgets"`: Draggable Fluent Mica widgets.
  - `"traditional"`: Full desktop icon grid with files, folders, and rubber-band selection.
- `showIcons` *(boolean)*: Toggles visibility of desktop shortcut icons in traditional mode.
- `widgetPositions` *(object)*: Map of widget IDs (`"clock"`, `"weather"`, `"system_monitor"`, `"notes"`) to their desktop coordinate objects `{ "x": number, "y": number }`.
- `enabledWidgets` *(array of strings)*: List of active widgets rendered on the desktop in widgets mode.

### 3.3 `dock`
- `position` *(string)*: Dock placement: `"bottom"`, `"top"`, `"left"`, or `"right"`.
- `autoHide` *(boolean)*: When `true`, dock slides out of view when windows overlap its area.
- `iconSize` *(integer, px)*: App icon dimensions inside the dock (default: `38`).
- `showUnderline` *(boolean)*: Toggles running dot / indicator under active apps.
- `pinnedApps` *(array of strings)*: List of application IDs pinned to the dock in display order.

### 3.4 `topBar`
- `showBrand` *(boolean)*: Shows or hides the DeloOS brand badge and quick launcher button.
- `showWorkspaces` *(boolean)*: Displays workspace indicator pills.
- `clockFormat` *(string)*: `"12h"` (e.g. `09:30 AM`) or `"24h"` (e.g. `21:30`).
- `workspacesCount` *(integer)*: Number of workspace numbers to show in the bar (default: `5`).

### 3.5 `windows`
- `activeBorder` *(string, hex)*: Hyprland border color for focused windows.
- `inactiveBorder` *(string, hex)*: Border color for inactive windows.
- `gapsIn` *(integer, px)*: Inner spacing between adjacent tiled windows.
- `gapsOut` *(integer, px)*: Outer margins between windows and screen edges.
- `rounding` *(integer, px)*: Corner curvature radius for Hyprland windows.

### 3.6 `notifications`
- `dnd` *(boolean)*: Do Not Disturb mode. Mutes notification popups when `true`.
- `timeout` *(integer, ms)*: Automatic dismissal timer for notification banners (default: `5000`).
- `sound` *(boolean)*: Whether to play an audible chime on incoming alerts.

### 3.7 `power`
- `profile` *(string)*: Power governor mode: `"performance"`, `"balanced"`, or `"power-saver"`.
- `sleepTimeout` *(integer, minutes)*: Idle delay before screen blanking.

### 3.8 `defaultApps`
- Maps standard system roles (`browser`, `terminal`, `fileManager`, `editor`) to their respective commands.

---

## 4. Backups and Safe Editing

The `update.sh` engine maintains automatic versioned backups under:
```
~/.config/deloway/backups/deloway.json.bak.<timestamp>
```

If hand-editing ever produces invalid JSON syntax, Quickshell will log a warning and safely continue operating using cached in-memory values until the syntax is corrected.
