# DeloOS / Deloway Configuration Guide

This document explains the unified configuration model of Deloway, detailing the schema of `deloway.json` and hand-editing best practices.

---

## 1. Unified Configuration Philosophy

In accordance with Section 9 of the project plan, Deloway rejects the idea of a GUI-only configuration model. Hyprland and Linux power users expect their systems to be version-controllable, readable, and human-editable.

- **Primary Path**: `~/.config/deloway/deloway.json`
- **Fallback / Template**: `<repo>/config/deloway.json` (copied for new users; `update.sh` back-fills new keys)
- **One Source of Truth**: The exact same file is read and written by:
  1. The **Settings App** (`SettingsApp.qml`)
  2. The **First-Run Setup Wizard** (`SetupWizard.qml`)
  3. The **Quick Settings** panel (`QuickSettings.qml`)
  4. The user editing the file in Vim, Nano, or VS Code.
- **Applying changes**: changes made through Settings / Quick Settings apply instantly. Hand edits to `deloway.json` are read on the next shell start — restart the shell with <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>R</kbd> (a clean restart; DeloWay never hot-reloads QML).

---

## 2. Complete Schema Reference

Below is an annotated example of a complete `deloway.json` file:

```json
{
  "theme": {
    "mode": "dark",
    "wallpaper": ""
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
    "activeBorder": "#ffffff",
    "inactiveBorder": "#444444",
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
    "fileManager": "org.kde.dolphin",
    "editor": "org.gnome.TextEditor",
    "monitor": "missioncenter"
  },
  "setupCompleted": true
}
```

---

## 3. Detailed Property Breakdown

### 3.1 `theme`
- `mode` *(string)*: `"dark"` or `"light"`. The single source of the theme mode: the shell's tokens, GTK apps, the icon theme (Reversal-black / Reversal-black-dark), Hyprland borders and the DeloWay kitty profile all follow it. There is no accent color.
- `wallpaper` *(string, path)*: Absolute path to the desktop wallpaper image (JPEG, PNG, WebP). Empty, or a file that no longer exists, falls back to `assets/wallpaper.jpg`.

### 3.2 `desktop`
- `mode` *(string)*: Selects the desktop presentation style:
  - `"clean"`: Minimalist wallpaper view without file or widget clutter.
  - `"widgets"`: Draggable Fluent Mica widgets.
  - `"traditional"`: Full desktop icon grid with files, folders, and rubber-band selection.
- `showIcons` *(boolean)*: Toggles visibility of desktop shortcut icons in traditional mode.
- `widgetPositions` *(object)*: Map of widget IDs (`"clock"`, `"weather"`, `"system_monitor"`, `"notes"`) to their desktop coordinate objects `{ "x": number, "y": number }`.
- `enabledWidgets` *(array of strings)*: List of active widgets rendered on the desktop in widgets mode.

### 3.3 `dock`
- `position` *(string)*: Dock placement: `"bottom"`, `"left"`, or `"right"`.
- `autoHide` *(boolean)*: When `true`, dock slides out of view when windows overlap its area.
- `iconSize` *(integer, px)*: App icon dimensions inside the dock (default: `38`).
- `showUnderline` *(boolean)*: Toggles running dot / indicator under active apps.
- `pinnedApps` *(array of strings, optional)*: Desktop-entry IDs pinned to the dock, in display order. While the key is absent (or `null`) the Dock shows the chosen browser, terminal and file manager (`defaultApps`); `[]` is an empty Dock. Settings → Dock → Reset goes back to the defaults. Apps that are not installed are never shown.

### 3.4 `topBar`
- `showBrand` *(boolean)*: Shows or hides the DeloOS brand badge and quick launcher button.
- `showWorkspaces` *(boolean)*: Displays workspace indicator pills.
- `clockFormat` *(string)*: `"12h"` (e.g. `09:30 AM`) or `"24h"` (e.g. `21:30`).
- `workspacesCount` *(integer)*: Number of workspace numbers to show in the bar (default: `5`).

### 3.5 `windows`
- `activeBorder` / `inactiveBorder` *(string, hex)*: kept for compatibility. Hyprland borders are derived from the theme mode (white / light gray in Dark, slate / light gray in Light); colored values are not applied.
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
- Maps the roles `browser`, `terminal`, `fileManager`, `editor` and `monitor` to an app: an executable (`brave`, as `install.sh` writes it) or a desktop-entry ID (`org.kde.dolphin`, as the Setup Wizard and Settings → Apps write it). `bin/delo-app` launches either form.
- The alternatives offered for each role (installer menus, Setup Wizard, Settings → Apps) come from one catalog, `config/default-apps.tsv`; installed apps of the role that it does not list are offered too.

---

## 4. Backups and Safe Editing

The `update.sh` engine maintains automatic versioned backups under:
```
~/.config/deloway/backups/deloway.json.bak.<timestamp>
```

If hand-editing ever produces invalid JSON syntax, Quickshell will log a warning and safely continue operating using cached in-memory values until the syntax is corrected.
