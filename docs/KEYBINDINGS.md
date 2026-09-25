# DeloWay Keybindings

Every shortcut below is bound in `config/hyprland.conf` (the Super-tap Start menu lives in the
generated `config/hypr-startmenu.conf`). The in-shell overlay (<kbd>Super</kbd> + <kbd>/</kbd>)
shows the same list in Arabic or English. When you change a bind, update this file and
`shell/components/CheatSheet.qml` together.

---

## 1. Shell

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> (tap) | Start menu (App Drawer) |
| <kbd>Super</kbd> + <kbd>A</kbd> / <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>A</kbd> | App Drawer |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Search |
| <kbd>Super</kbd> + <kbd>N</kbd> / <kbd>Super</kbd> + <kbd>M</kbd> | Quick Settings |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>N</kbd> | Smart Notch |
| <kbd>Super</kbd> + <kbd>I</kbd> | DeloWay Settings |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history (cliphist picker) |
| <kbd>Super</kbd> + <kbd>/</kbd> / <kbd>Super</kbd> + <kbd>T</kbd> | Keyboard shortcuts overlay |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | Hide / show the top bar and Dock |
| <kbd>Super</kbd> + <kbd>K</kbd> | On-screen keyboard |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>Delete</kbd> | Session menu |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>T</kbd> | Settings → Wallpaper |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>R</kbd> | Restart the shell (clean restart) |

## 2. Session

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock screen (the shell's `ext-session-lock` screen; `hyprlock` if the shell is not running) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> | Suspend |

## 3. Applications

These open the defaults chosen in Settings → Apps (through `bin/delo-app`) where noted.

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>Return</kbd> | Terminal (`delo-app terminal`) |
| <kbd>Super</kbd> + <kbd>E</kbd> | File manager (`delo-app files`) |
| <kbd>Super</kbd> + <kbd>W</kbd> | Browser (`delo-app browser`) |
| <kbd>Super</kbd> + <kbd>C</kbd> | Code editor |
| <kbd>Super</kbd> + <kbd>X</kbd> | Text editor (`delo-app editor`) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Office suite |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Escape</kbd> | System monitor (`delo-app monitor`) |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>V</kbd> | Volume control (`delo-app mixer`) |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>/</kbd> | Edit `hyprland.conf` in the text editor |

## 4. Windows

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Alt</kbd> + <kbd>Q</kbd> | Force-kill a window (click it) |
| <kbd>Super</kbd> + <kbd>←</kbd>/<kbd>↑</kbd>/<kbd>→</kbd>/<kbd>↓</kbd> | Focus in direction |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + arrows | Move window in direction |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + arrows | Resize window |
| <kbd>Super</kbd> + <kbd>;</kbd> / <kbd>'</kbd> | Adjust split ratio |
| <kbd>Super</kbd> + <kbd>\</kbd> | Toggle split direction |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>Space</kbd> | Float / tile |
| <kbd>Super</kbd> + <kbd>D</kbd> | Maximize |
| <kbd>Super</kbd> + <kbd>F</kbd> | Fullscreen |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>F</kbd> | Fake fullscreen (window thinks it is fullscreen) |
| <kbd>Super</kbd> + <kbd>P</kbd> | Pin (show on every workspace) |
| <kbd>Super</kbd> + <kbd>G</kbd> / <kbd>Super</kbd> + <kbd>Tab</kbd> | Group / next window in group |
| <kbd>Super</kbd> + left drag / right drag | Move / resize with the mouse |

## 5. Workspaces

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>1</kbd> .. <kbd>0</kbd> | Go to workspace 1–10 |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>1</kbd> .. <kbd>0</kbd> | Send window to workspace 1–10 (stay here) |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>←</kbd>/<kbd>→</kbd>, <kbd>Super</kbd> + <kbd>Page Up</kbd>/<kbd>Page Down</kbd>, <kbd>Super</kbd> + scroll | Previous / next workspace |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Page Up</kbd>/<kbd>Page Down</kbd>, <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Ctrl</kbd> + <kbd>←</kbd>/<kbd>→</kbd> | Move window to previous / next workspace |
| <kbd>Super</kbd> + <kbd>S</kbd> | Toggle scratchpad |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>S</kbd> | Send window to scratchpad |

## 6. Screenshots & recording

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Screenshot a region |
| <kbd>Print</kbd> / <kbd>Ctrl</kbd> + <kbd>Print</kbd> | Screenshot the full screen |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>C</kbd> | Pick a color (hex) to the clipboard |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> | Record a region (no sound) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> | Record a region with sound |
| <kbd>Super</kbd> + <kbd>-</kbd> / <kbd>=</kbd> | Cursor zoom: reset / zoom in |

Screenshots are saved to `~/Pictures/Screenshots` and copied to the clipboard.

## 7. Media & hardware keys

| Key Combination | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> / <kbd>XF86AudioPlay</kbd> | Play / pause |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>N</kbd> / <kbd>XF86AudioNext</kbd> | Next track |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd> / <kbd>XF86AudioPrev</kbd> | Previous track |
| <kbd>XF86AudioStop</kbd> | Stop |
| <kbd>XF86AudioRaiseVolume</kbd> / <kbd>XF86AudioLowerVolume</kbd> | Volume ±5% (`wpctl`) |
| <kbd>XF86AudioMute</kbd> / <kbd>XF86AudioMicMute</kbd> | Mute output / microphone |
| <kbd>XF86MonBrightnessUp</kbd> / <kbd>XF86MonBrightnessDown</kbd> | Backlight ±5% (`brightnessctl`; DDC monitors use the Quick Settings slider) |

---

**Removed in the final review:** the vim-style <kbd>Super</kbd> + <kbd>H</kbd>/<kbd>J</kbd>/<kbd>K</kbd>/<kbd>L</kbd>
focus and move binds (they collided with Lock, the on-screen keyboard and Suspend), and the
duplicate <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>N</kbd> Quick Settings bind (it fired together
with "next track"). Keyboard resizing moved to <kbd>Super</kbd> + <kbd>Alt</kbd> + arrows.
