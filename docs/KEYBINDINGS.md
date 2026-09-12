# DeloOS / Deloway Keybindings Cheatsheet

All standard keyboard shortcuts mapped in Deloway's Hyprland compositor and Quickshell shell.

---

## 1. Shell & Desktop Navigation

| Key Combination | Action | Description |
|---|---|---|
| <kbd>Super</kbd> + <kbd>Space</kbd> | **App Drawer & Search** | Toggles the universal search and application launcher |
| <kbd>Super</kbd> + <kbd>D</kbd> | **App Drawer** | Secondary shortcut for the application drawer |
| <kbd>Super</kbd> + <kbd>I</kbd> | **DeloOS Settings** | Opens the native Deloway Settings app |
| <kbd>Super</kbd> + <kbd>S</kbd> | **Delo Store** | Opens the Delo App Store |
| <kbd>Super</kbd> + <kbd>L</kbd> | **Lock Screen** | Engages the hardware session lock (`ext-session-lock-v1`) |
| <kbd>Super</kbd> + <kbd>A</kbd> | **Quick Settings** | Toggles the Quick Settings / Control Center flyout |
| <kbd>Super</kbd> + <kbd>Escape</kbd> | **Close Overlay** | Dismisses any open drawer, store, settings, or menu |

---

## 2. Default Applications

| Key Combination | Action | Description |
|---|---|---|
| <kbd>Super</kbd> + <kbd>Return</kbd> | **Terminal** | Launches Kitty terminal |
| <kbd>Super</kbd> + <kbd>E</kbd> | **File Manager** | Launches Thunar file manager |
| <kbd>Super</kbd> + <kbd>B</kbd> | **Web Browser** | Launches default browser (Firefox) |

---

## 3. Window Management (Hyprland Tiling)

| Key Combination | Action | Description |
|---|---|---|
| <kbd>Super</kbd> + <kbd>Q</kbd> | **Close Window** | Closes the currently active window |
| <kbd>Super</kbd> + <kbd>F</kbd> | **Toggle Fullscreen** | Toggles fullscreen on the active window |
| <kbd>Super</kbd> + <kbd>V</kbd> | **Toggle Floating** | Switches between tiled and floating mode |
| <kbd>Super</kbd> + <kbd>H</kbd> / <kbd>←</kbd> | **Focus Left** | Moves focus to the left window |
| <kbd>Super</kbd> + <kbd>L</kbd> / <kbd>→</kbd> | **Focus Right** | Moves focus to the right window |
| <kbd>Super</kbd> + <kbd>K</kbd> / <kbd>↑</kbd> | **Focus Up** | Moves focus to the window above |
| <kbd>Super</kbd> + <kbd>J</kbd> / <kbd>↓</kbd> | **Focus Down** | Moves focus to the window below |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> / <kbd>←</kbd> | **Swap Left** | Swaps position with window on left |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> / <kbd>→</kbd> | **Swap Right** | Swaps position with window on right |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>K</kbd> / <kbd>↑</kbd> | **Swap Up** | Swaps position with window above |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>J</kbd> / <kbd>↓</kbd> | **Swap Down** | Swaps position with window below |

---

## 4. Workspaces

| Key Combination | Action | Description |
|---|---|---|
| <kbd>Super</kbd> + <kbd>1</kbd> .. <kbd>5</kbd> | **Switch Workspace** | Switches to workspace 1 through 5 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> .. <kbd>5</kbd> | **Move to Workspace** | Moves active window to target workspace |
| <kbd>Super</kbd> + <kbd>Scroll Up/Down</kbd> | **Cycle Workspaces** | Scrolls through active workspaces |

---

## 5. Media & Hardware Keys

| Key Combination | Action | Description |
|---|---|---|
| <kbd>Print</kbd> | **Full Screenshot** | Captures full screen to `~/Pictures/Screenshots` |
| <kbd>Shift</kbd> + <kbd>Print</kbd> | **Area Snippet** | Interactive area selection via `slurp` + `grim` |
| <kbd>XF86AudioRaiseVolume</kbd> | **Volume Up** | Increases master audio volume by 5% |
| <kbd>XF86AudioLowerVolume</kbd> | **Volume Down** | Decreases master audio volume by 5% |
| <kbd>XF86AudioMute</kbd> | **Mute Audio** | Toggles master audio mute |
| <kbd>XF86MonBrightnessUp</kbd> | **Brightness Up** | Increases screen backlight by 5% |
| <kbd>XF86MonBrightnessDown</kbd> | **Brightness Down** | Decreases screen backlight by 5% |
| <kbd>XF86AudioPlay</kbd> | **Play / Pause** | Toggles MPRIS media playback |
| <kbd>XF86AudioNext</kbd> | **Next Track** | Skips to next track via `playerctl` |
| <kbd>XF86AudioPrev</kbd> | **Previous Track** | Rewinds to previous track via `playerctl` |
