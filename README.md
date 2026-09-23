# Deloway

Deloway is a desktop shell for Hyprland, written in QML on top of [Quickshell](https://quickshell.outfoxxed.me/).
The top bar, dock, app drawer, search, notifications, quick settings, lock screen, desktop and
settings app all come from one QML codebase. They share their state and a single config file.

The look is deliberately plain: black and neutral grays, with a light variant. There is no accent
color. Hierarchy comes from brightness, weight and spacing, and red, amber and green only show up as
small status dots. The interface is built Arabic-first and mirrors fully for right-to-left. English
works too.

<!--
  Screenshots go here once they are captured on a clean desktop, e.g.
  ![Dark](docs/screenshots/dark.png)  ![Light](docs/screenshots/light.png)
-->

## What's in it

- **Top bar**: three capsules, one each for the clock/calendar, the notch (home, notifications, LocalSend sharing) and quick settings (Wi-Fi, Bluetooth, hotspot, audio, brightness, night light, power).
- **Dock**: pinned and running apps, with an intellihide mode and a right-click menu for app info and uninstall.
- **Start menu / app drawer and search**: app search with a built-in calculator.
- **Settings app**: network, Bluetooth, appearance, wallpaper, dock, top bar, windows, notifications, power, apps, time and language.
- **Lock screen**: uses `ext-session-lock` with PAM.
- **Three desktop modes**: clean, widgets and a traditional icon desktop.
- **Dark / Light switch**: also carries GTK apps, the icon theme, window borders and the bundled kitty profile.

## Requirements

Arch Linux (or an Arch-based distro) with:

- Hyprland
- an AUR helper, `yay` or `paru`. The installer offers to bootstrap one if neither is present.
- a display manager that reads Wayland sessions (SDDM, GDM, LightDM), or a TTY login

Everything else is installed by `install.sh`.

## Install

```bash
git clone https://github.com/IWLED/Deloway.git ~/Projects/Deloway
cd ~/Projects/Deloway
./install.sh
```

The installer asks for your default terminal, browser, file manager, editor and system monitor,
then:

- **Packages:** installs everything the shell and its helper scripts call, from pacman and the AUR (Quickshell, Qt modules, fonts, the Reversal icon theme, NetworkManager, BlueZ, PipeWire, and so on).
- **Hardware:** detects it and adds what's needed, such as `ddcutil` for external monitors without a backlight, or GPU drivers.
- **Config and commands:** links the shell into `~/.config/deloway`, writes `~/.config/deloway/deloway.json`, and puts `delo-app` and `deloway-session` in `~/.local/bin`.
- **System files (sudo):** registers the session in `/usr/share/wayland-sessions` and installs the lock screen's PAM file in `/etc/pam.d/deloway`.

Useful flags:

| Flag | |
|---|---|
| `--dry-run` | print what would happen without changing anything |
| `-y` | accept the default choices |
| `--no-deps` | skip package installation |

Run it as your normal user. It asks for sudo when it needs it.

The repo can live anywhere. Outside `~/Projects/Deloway`, the installer writes a
`~/.config/deloway/hyprland.conf` that points at your clone.

## Logging in

Log out and pick **DeloWay** from the session list on the login screen. From a TTY, run:

```bash
deloway-session
```

The first start opens a short setup wizard for language, theme and apps.

## Updating

```bash
cd ~/Projects/Deloway
./update.sh            # pull, back up the config, add new config keys
./update.sh --restart  # same, then restart the shell
```

The shell never hot-reloads QML, because live reloads can crash Quickshell. After changing files,
restart the shell with <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>R</kbd>.

## Keys you'll want first

| | |
|---|---|
| <kbd>Super</kbd> (tap) | start menu |
| <kbd>Super</kbd>+<kbd>Space</kbd> | search |
| <kbd>Super</kbd>+<kbd>N</kbd> | quick settings |
| <kbd>Super</kbd>+<kbd>I</kbd> | settings |
| <kbd>Super</kbd>+<kbd>L</kbd> | lock |
| <kbd>Super</kbd>+<kbd>Return</kbd> | terminal |
| <kbd>Super</kbd>+<kbd>/</kbd> | every shortcut, in the shell |

The full list is in [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md).

## Configuration

Settings live in `~/.config/deloway/deloway.json`. The settings app writes the same file, so you can
use either. Hand edits are picked up on the next shell restart. The schema is documented in
[docs/CONFIGURATION.md](docs/CONFIGURATION.md).

Hyprland reads `config/hyprland.conf` from the repo, isolated from `~/.config/hypr`.

## Layout

```
shell/
  shell.qml          entry point: windows per screen, global shortcuts, IPC
  components/        top bar capsules, dock, drawer, settings, lock screen, desktop…
  services/          singletons: config, apps, network, bluetooth, notifications, i18n…
  theme/Theme.qml    every color and size token; components never hardcode colors
scripts/             Python and shell helpers the services call (network, bluetooth,
                     theme apply, wallpaper, screenshots, LocalSend…)
config/              hyprland.conf, kitty profile, default deloway.json
bin/                 deloway-session (session wrapper), delo-app (default-app launcher)
system/              session .desktop entry, PAM file
```

The QML side keeps to one rule: components talk to services, services own the state and the
processes. The shell also answers `qs ipc` calls, e.g.:

```bash
qs ipc -p ~/Projects/Deloway/shell call deloway setMode light
```

More detail is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Contributing

- Colors come from `shell/theme/Theme.qml` only. `./scripts/check-theme.sh` has to pass.
- Restart the shell cleanly to test (`killall quickshell`, then start it again) and keep
  `qs log -p shell` free of new warnings.
