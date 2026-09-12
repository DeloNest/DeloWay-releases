# Project Plan: A Cohesive Linux Desktop Experience Built on Hyprland

## Status of this document

This is the authoritative planning document for the project. It will be read by AI coding assistants (and human contributors) who will implement the project incrementally. Every architectural decision below is either marked **DECIDED** (do not relitigate without a strong reason — if you disagree, flag it explicitly instead of silently deviating) or **OPEN** (a real decision point that still needs to be made, with the trade-offs listed).

If a future contributor (human or AI) wants to deviate from a DECIDED item, they must add a note under "Deviation Log" at the bottom of this file explaining why, rather than silently changing direction.

### Current Implementation Status (Updated September 2026)

| Component / Phase | Status | Key Deliverables Completed |
|---|---|---|
| **Phase 1: Core Shell** | **Completed** | Top Bar, Dock, App Drawer, Universal Search, Fluent Mica Token System |
| **Phase 2: System Integration** | **Completed** | Hyprland IPC, in-shell Notifications, Quick Settings, Lock Screen, PipeWire & MPRIS Live Feedback |
| **Phase 3: Configuration Layer** | **Completed** | Settings App (all panels), Unified `deloway.json` Config, First-Run Setup Wizard |
| **Phase 4: App Store & Packages** | **In Progress** | `StoreApp.qml` UI, `ApplicationManager` lifecycle hooks, DeloOS app branding |
| **Phase 5: Desktop Modes** | **Completed** | Clean Mode, Widgets Mode (live weather, system stats, notes), Traditional Mode (grid, drag-and-drop, context menus) |
| **Phase 6: Distribution & Sessions** | **Core Complete** | `DeloWay` LightDM login session, isolated compositor wrapper `deloway-session`, automated installer, complete purge of mock data, live hardware telemetry daemon |
| **Phase 7: Typography & Micro-Interactions** | **Completed** | Native FreeType rendering (`Text.NativeRendering`), subpixel hinting preference, Cairo/Readex font chain, tactile click compression, smooth hover lifts, and floating tooltips |


---

## 1. Vision

Build a modern, cohesive Linux desktop experience on top of **Hyprland**, where the shell, settings, app store, dock, launcher, notifications, and lock screen all feel like **one integrated product**, not a pile of independently configured dotfiles glued together with scripts.

The end user should be able to install the project and start using it immediately, with a guided first-run setup, without spending hours wiring together separate tools (a common pain point with typical "Hyprland dotfiles" repositories). At the same time, the system must not sacrifice the customizability that Linux/Hyprland users expect — config files remain human-editable, not GUI-only.

### 1.1 What this project is NOT

- **Not** a new desktop environment built from scratch (no custom compositor).
- **Not** a fork of KDE, GNOME, or any existing DE.
- **Not** a "Hyprland dotfiles" repo in the traditional sense (waybar + rofi + separate scripts glued together with no shared state).
- **Not** a new package manager.
- **Not**, initially, a custom file manager built from scratch.

### 1.2 What makes this project different from existing Hyprland "rice" projects

Most existing Hyprland customization projects (dotfiles repos) combine independently-developed tools (waybar, rofi/wofi, mako/dunst/swaync, hyprlock, various scripts) that each have their own config format and their own visual style, loosely synced via scripts or color-generation tools like `pywal`/`matugen`.

This project differs by building **one shell application** that owns the bar, dock, app drawer, search, notifications, quick settings, and lock screen as a single codebase, sharing one in-memory state and one configuration file. Visual and behavioral consistency come from architecture, not from post-hoc styling of separate programs.

A secondary but important differentiator: a fully modeled **application lifecycle** (install → appears in drawer → can be pinned to dock → running state reflected everywhere → closes cleanly), driven by a single central `ApplicationManager` model rather than each UI surface tracking its own app list independently.

---

## 2. High-Level Architecture

```
                 YOUR DESKTOP PROJECT
                          │
            ┌─────────────┴─────────────┐
            │                           │
        QML Shell                  System Core
       (Quickshell)              (services / daemon,
            │                     introduced from Phase 4)
            └─────────────┬─────────────┘
                          │
                      Hyprland   (compositor — used, NOT modified)
                          │
                       Wayland
                          │
                        Linux
```

### 2.1 Layer responsibilities

| Layer | Responsibility | Technology |
|---|---|---|
| Hyprland | Window management, workspaces, compositing, input | Unmodified upstream Hyprland |
| Shell | All visible UI: bar, dock, app drawer, search, notifications, quick settings, lock screen, desktop, settings app, setup wizard | Quickshell + QML |
| System Core | Deeper system logic that shouldn't live in QML: package install/remove, persistent app state, theme generation, file indexing if needed | Introduced later (see Phase 4); language TBD but Rust is the leading candidate — see §6 |
| External applications | File manager, terminal, browser, media player, and (optionally) the app store's actual package backend | Existing, mature Linux applications — not rebuilt from scratch, but themed and rebranded (see §8) |

### 2.2 DECIDED: Do not fork or modify Hyprland itself

Hyprland is explicitly a compositor + toolkit for building your own desktop experience, not a full DE. It exposes:
- An **IPC command socket** for sending commands (workspace switches, window focus, dispatchers, etc.)
- An **IPC event socket** for subscribing to live events (window opened/closed, workspace changed, window minimized, etc.)

The shell should treat these as its primary integration point with window management. Example event flow:

```
Window opened
      ↓
Hyprland fires event on event socket
      ↓
Shell receives event
      ↓
ApplicationManager updates "running" state
      ↓
Dock re-renders running indicator
```

### 2.3 DECIDED: Avoid early dependency on Hyprland plugins

Hyprland plugins run **inside the Hyprland process itself** and are built against a specific Hyprland ABI version. Any Hyprland update can break plugin compatibility, and debugging issues inside the compositor's own process is much riskier than debugging an external shell process. Use IPC (dispatchers, events, window rules) instead of plugins wherever possible. Only consider a plugin if something is truly impossible via IPC, and treat it as an optional/advanced feature, never a hard dependency for core functionality.

---

## 3. Technology Stack

### 3.1 Shell: Quickshell + QML — DECIDED

**Why Quickshell over the alternatives (Astal/AGS on GTK, raw wlroots/Smithay compositor writing, or traditional waybar+rofi+scripts):**

- Quickshell is purpose-built for constructing a full custom desktop shell (bars, widgets, lock screens, launchers, notification centers) on top of Wayland compositors, with native integration points for Hyprland, PipeWire, Bluetooth, power management, and MPRIS.
- It is not "just a bar" — it is a general UI toolkit for the whole shell layer, which matches this project's scope (bar + dock + drawer + search + notifications + quick settings + lock screen + settings app + desktop).
- It can read installed applications directly from XDG Desktop Entries (name, icon, categories), which is the foundation for the App Drawer and Search.
- It supports hot reload during development, which matters a lot for a UI-heavy project like this.
- It has a fast-growing 2026 ecosystem of prior art to study: **Noctalia**, **Caelestia**, **illogical-impulse (end-4/dots-hyprland)**, **Ambxst/Aura**. These prove the "one cohesive shell on Hyprland" pattern works in practice and are valuable references for code structure (not to copy wholesale, but to learn from).

**Rejected alternative:** Astal/AGS (GTK-based) was considered specifically because GTK supports real CSS theming out of the box. This was outweighed by Quickshell's stronger 2026 momentum, performance, and the benefit of aligning the shell's toolkit family (Qt/QML) with the toolkit family of the external apps we plan to bundle (see §8.2). Theming is instead handled via a JSON-based design-token system (see §9), not CSS.

### 3.2 System Core: language TBD, Rust is the leading candidate — OPEN (revisit at Phase 4)

**DECIDED for now:** Do **not** build a system daemon/core service in Phase 1–3. Quickshell already has direct integration for most early needs (network, Bluetooth, audio via PipeWire, power, MPRIS) via existing D-Bus services and its own built-in service objects. Introducing a separate daemon before it's needed adds IPC complexity for no immediate benefit.

**Introduce the System Core starting at Phase 4**, when the project needs logic that shouldn't live in QML: package installation/removal (talking to PackageKit or libflatpak), persistent application state, and theme file generation. At that point, evaluate:
- **Rust** (leading candidate): strong D-Bus bindings, safe systems programming, good for async/process/permission-sensitive code.
- Alternative: a lighter-weight approach (e.g., a Python or Go service) if development speed matters more than raw robustness at that stage.

This decision should be revisited explicitly when Phase 4 begins, not assumed.

### 3.3 UI library conventions within the shell

Prefer QtQuick Controls (and consider Kirigami if bundled apps are KDE/Kirigami-based — see §8.2) for consistency between the shell's own widgets and the external apps it launches.

---

## 4. Core Data Model: the Application Manager

### 4.1 DECIDED: A single, central Application Manager — not per-surface app lists

Do **not** let the App Drawer, Dock, Search, and App Store each maintain their own independent list of applications. All of them read from and write to one shared model.

```
ApplicationManager

Firefox
├── installed: true
├── desktopEntry: firefox.desktop
├── pinned: true
├── favorite: true
├── category: Internet
├── running: true
├── windows: 2
├── needsAttention: false
└── icon: firefox
```

Data flow:

```
App Store  →  ApplicationManager  →  App Drawer
                                  →  Dock
                                  →  Search
```

### 4.2 Dock states the model must represent

- Installed but not running
- Running
- Running with multiple windows
- Minimized
- Needs user attention

### 4.3 Canonical application lifecycle (this is the flow every implementation must satisfy)

**Install:**
```
User opens App Store
   → installs an app (via PackageKit/Flatpak backend, see §7)
   → install completes, a .desktop entry appears on disk
   → ApplicationManager detects the new entry
   → App Drawer updates
   → Search index updates
```

**Pin to Dock:**
```
User → "Pin to Dock" (from App Drawer or App Store)
     → ApplicationManager updates pinned = true
     → Dock config/state persists this
```

**Launch:**
```
App launched
   → Hyprland reports a new window (via event socket)
   → ApplicationManager sets running = true, increments windows
   → Dock shows running indicator
```

**Close:**
```
Window closed
   → Hyprland event
   → ApplicationManager decrements windows / sets running = false
   → Dock removes running indicator
```

This lifecycle — App Store → App Drawer → Pin to Dock → Running state → Window close — is a core UX requirement, not an optional nice-to-have. Any component that bypasses the ApplicationManager to track app state independently is a bug.

---

## 5. Shell Components

### 5.1 Top Bar
Displays: logo/launcher button, active workspace indicator, system tray, network/audio/battery status, clock, user menu. Should be a thin, mostly presentational component driven by shell services (network, audio, battery, workspaces).

### 5.2 Dock (bottom)
Not just an app pinning bar — a visual reflection of ApplicationManager state (see §4.2 for the states it must render). Supports pinning/unpinning, reordering, position configuration (bottom/left/right/top — see §10), and auto-hide vs. always-visible modes.

### 5.3 App Drawer
Central place for all installed applications.
- Lists apps from ApplicationManager (backed by XDG Desktop Entries)
- Search/filter within the drawer
- Category browsing
- Favorite/pin actions
- Right-click / long-press for app info, uninstall shortcut (delegates to App Store backend)

### 5.4 Universal Search
Triggered by a global shortcut (e.g., Super key). Must search across:
- Applications
- Files (consider using an existing indexer rather than building one — e.g., leveraging `plocate`/`fd` or a lightweight index, decide at implementation time; not a Phase 1 priority)
- Settings pages (e.g., typing "Bluetooth" jumps directly into the Bluetooth settings panel)
- System actions (lock, log out, restart, shut down)
- Running processes/windows (optional, later phase)

### 5.5 Notifications
Standard desktop notification daemon behavior (implements the `org.freedesktop.Notifications` D-Bus spec) rendered natively inside the shell rather than via a separate notification daemon like `mako`/`dunst`, so styling stays consistent with the rest of the shell.

### 5.6 Quick Settings / Control Center
Toggles and quick access for: Wi-Fi, Bluetooth, audio output/input, brightness, do-not-disturb, power profile, night light, and a shortcut into full Settings.

### 5.7 Lock Screen
Implemented as part of the shell itself using the Wayland `ext-session-lock-v1` protocol, not by shelling out to a separate program like `hyprlock`. This keeps the lock screen visually and behaviorally consistent with the rest of the shell (same theme, same clock/notification widgets if desired).

### 5.8 Desktop
Three modes, user-selectable (see §10 for setup wizard tie-in):
- **Clean** (DECIDED default for Phase 1): wallpaper + optional widgets only. No file/folder rendering.
- **Widgets**: user-placed, resizable/movable widgets (clock, weather, notes, etc.)
- **Traditional** (explicitly deferred — see §12, Phase 5): full desktop icon grid with files/folders, drag & drop, context menu (rename/delete/create folder/move), multi-select, trash integration. This is a substantial feature in its own right and must not be attempted before the core shell is solid.

### 5.9 Settings App
A page within the same shell application (not a separate program), covering: Appearance/Theme, Dock, Top Bar, Windows, Desktop, Keyboard shortcuts, Notifications, Network, Bluetooth, Power, Applications. All settings read from and write to the single unified config file (§10).

### 5.10 First-Run Setup Wizard
Shown on first login (detected via a marker file, e.g. presence/absence of the config file or a dedicated flag). Lets the user choose, before ever seeing the desktop:
- Desktop mode (Clean / Widgets / Traditional)
- Dock position and behavior (position, auto-hide vs. fixed)
- Top bar position and behavior
- Window management style/preferences (basic tiling preferences, if exposed)
- Theme (light/dark to start — see §9)
- App Drawer style
- Keyboard shortcuts
- A handful of core system settings

All wizard choices are written to the **same** unified config file that the Settings app later reads/writes. There must be exactly one schema for this file, not a separate "first-run format" that gets migrated later.

---

## 6. App Store Strategy

### 6.1 DECIDED: Do not build a new package manager

Wrap existing, mature infrastructure instead of reinventing dependency resolution and repo management.

**Two acceptable approaches (pick one as the primary path; the other can be a fallback/secondary backend later):**

1. **PackageKit** (`org.freedesktop.PackageKit` D-Bus interface): a standardized, cross-distro package management API already used by GNOME Software and KDE Discover, with backends maintained by each distro (apt, dnf, pacman, etc.). Building an App Store UI against PackageKit gives install/remove/update/search/list-installed for free, distro-agnostic.
2. **Flatpak-first via `libflatpak`**: since Flatpak is identical across distros (Arch/Fedora/Ubuntu/etc.), this sidesteps the multi-backend problem entirely rather than solving it via abstraction. Native package support (via PackageKit) can be added later as a secondary backend if truly needed.

**OPEN decision:** Which of the two is the default/primary backend for v1. Recommendation: start Flatpak-first for simplicity and distro-portability, add a PackageKit backend later if native package coverage becomes a real user need.

### 6.2 Backend abstraction (once more than one backend exists)

```
PackageBackend (interface)
  install()
  remove()
  update()
  search()
  listInstalled()

FlatpakBackend : PackageBackend
PackageKitBackend : PackageBackend   (covers apt/dnf/pacman/etc. via one interface)
```

### 6.3 Architectural note

Since Quickshell (QML/Qt) is the shell technology, and KDE Discover is itself built with QtQuick/Kirigami on top of PackageKit and libflatpak, there is an opportunity to draw directly on the same underlying Qt bindings (PackageKit-Qt, AppStream-Qt) that Discover uses, rather than embedding or shelling out to Discover as a whole separate app. This keeps the App Store visually native to the shell while reusing battle-tested backend code. Evaluate feasibility during Phase 4 implementation.

### 6.4 App Store ↔ ApplicationManager integration

The App Store must not maintain its own separate notion of "installed apps." Every install/remove action goes through the ApplicationManager (§4) so the App Drawer, Dock, and Search stay in sync automatically, per the canonical lifecycle in §4.3.

---

## 7. Bundled External Applications (File Manager, Terminal, Browser, etc.)

### 7.1 DECIDED: Use existing, mature applications — do not rebuild them

File manager, terminal, browser, and media player are treated as **external applications**, not components built from scratch. This applies to Phase 1–4 at minimum; a custom file manager (if ever pursued) would be a much later, optional effort — not a blocker for anything else.

### 7.2 Toolkit alignment preference — DECIDED

Given the shell is Qt/QML (Quickshell), **prefer Qt/KDE applications over GTK applications** where a reasonable choice exists (e.g., Dolphin over Thunar/Nemo for the file manager). Rationale: theming consistency is easier to achieve within one toolkit family (see §9), and visual "seams" between the shell and bundled apps are minimized.

This is a preference, not an absolute rule — pick whichever specific application is most maintainable and functional for a given role, and theme it as described below.

### 7.3 Theming external applications without modifying their source

**GTK applications:** apply a system-wide GTK theme (CSS-based). Use `adw-gtk3` as a base (it preserves the modern GNOME look but remains genuinely themeable, unlike stock Libadwaita/GTK4 apps which increasingly resist deep theming and only expose an accent-color API). Apply via `gsettings` and/or `~/.config/gtk-4.0/gtk.css` / `~/.config/gtk-3.0/gtk.css`. No source modification required.

**Qt/KDE applications:** apply theming via `qt6ct`/`qt5ct` (or the Hyprland-specific `hyprqt6engine`) for base colors/fonts, plus **Kvantum** (an SVG-based Qt theme engine) for deeper visual control. Known caveat (verify early, don't assume): some KDE apps (e.g., Dolphin, Gwenview, Okular) have had inconsistent Kvantum compliance depending on setup — test this with the actual target apps before committing.

**Single source of truth for color generation:** use a `matugen`-style pipeline — one base palette (from a wallpaper or a manually defined color set) generates, via templates, all of: the GTK theme override, the qt6ct/Kvantum config, Hyprland's own border/accent colors, the shell's `theme.json` (§9), and terminal color schemes. This is what makes "one unified theme across completely different toolkits" actually true in practice, not just aspirational.

```
Single color source (matugen-style)
        │
   ┌────┼────┬─────────┬──────────┐
   ▼    ▼    ▼         ▼          ▼
 GTK  Qt/Kvantum  Hyprland   theme.json   Terminal
```

### 7.4 Rebranding external applications (name + icon) without touching their code

Create an override `.desktop` file for each bundled app and place it in `~/.local/share/applications/` — this path takes precedence over the system-wide `/usr/share/applications/` entry, so it is picked up everywhere (app menus, search, the shell's own ApplicationManager) without modifying the underlying package at all.

In the override file, customize:
- `Name=` — the branded display name shown throughout the shell
- `Icon=` — a custom icon shipped as part of the project's own icon pack

Because the ApplicationManager (§4) is built on top of Desktop Entries in the first place, this rebranding is picked up automatically everywhere — there is no separate "branding layer" to maintain.

---

## 8. Theming System

### 8.1 DECIDED: JSON-based design tokens, not CSS, for the shell itself

Since the shell is QML (not a CSS-native toolkit), theming the shell's own components is done via a `theme.json` design-token file, not CSS:

```json
{
  "colors": {
    "background": "...",
    "surface": "...",
    "text": "...",
    "accent": "..."
  },
  "radius": { "small": 6, "medium": 10, "large": 16 },
  "spacing": { "small": 6, "medium": 12, "large": 20 }
}
```

QML components read from this file/object at runtime. Themes live under a `themes/` directory (e.g., `default-dark/`, `default-light/`, and community themes like `nord/`, `catppuccin/`, `custom/`).

### 8.2 Default themes for v1 — DECIDED

Ship exactly two built-in themes at launch: **Light** and **Dark**. A pluggable theme system (additional theme packs, and eventually a way for advanced users/developers to define custom themes without touching core shell code) is a stated goal but not a Phase 1 requirement.

### 8.3 Cross-toolkit propagation

See §7.3 — the same color source that drives `theme.json` also drives GTK/Qt/Kvantum/Hyprland/terminal theming for bundled external apps, so the whole desktop (not just the shell) shares one palette.

---

## 9. Configuration System

### 9.1 DECIDED: One unified config file, both human-editable and GUI-editable

Reject the idea of a GUI-only config model. Hyprland's own user base strongly favors config-file sharing (dotfiles repos, "rices" shared on GitHub), so the config file must remain:
- A plain, well-documented format (JSON or TOML — pick one and be consistent; TOML is slightly more human-friendly for hand-editing, JSON is simpler to reason about programmatically — **OPEN**, decide before Phase 3)
- Fully editable by hand
- The exact same file read and written by: the Settings app, the First-Run Setup Wizard, and any given shell component that needs a persisted preference

Example shape:

```json
{
  "dock": {
    "position": "bottom",
    "autoHide": true,
    "size": 64
  }
}
```

### 9.2 Reactive config reload

Changes to the config file (whether made via the Settings UI or by hand) should be picked up live by the shell (file-watch + reactive reload), matching the pattern seen in comparable Quickshell-based projects.

---

## 10. Development Phases

Do not reorder these phases. Each phase should produce something runnable/demoable before moving to the next; do not start a later phase's work as a way of avoiding a hard problem in the current phase.

### Phase 1 — Core Shell Prototype [COMPLETED]
- [x] Hyprland (unmodified) + Quickshell wired together
- [x] Theme system (`theme.json`, Light/Dark Fluent Mica design tokens)
- [x] Top Bar (dynamic workspace indicators, focused window title, system tray, real-time clock, status indicators)
- [x] Dock (dynamic pinned apps, running indicators, auto-hide, hover animations)
- [x] App Drawer (reading real XDG Desktop Entries, category filtering)
- [x] Universal Search (real system applications, settings shortcuts)

**Goal:** a usable, visually coherent prototype — proves the "one shell, one theme" concept end to end.

### Phase 2 — System Integration [COMPLETED]
- [x] Full Hyprland window/workspace event integration (`HyprlandIpc.qml`, window tracking, running state)
- [x] Notifications (native, in-shell, zero fake alerts, D-Bus freedesktop spec compliant)
- [x] Quick Settings (real PipeWire volume control, Ethernet/Wi-Fi telemetry, real Bluetooth state, MPRIS media player card dynamically shown only when playing)
- [x] Lock Screen (via `ext-session-lock-v1` with PAM authentication)

### Phase 3 — Configuration Layer [COMPLETED]
- [x] Settings App (`SettingsApp.qml` with Appearance, Dock, Top Bar, Windows, Desktop, Network, Bluetooth, Apps)
- [x] Unified config backend (`deloway.json` and `ConfigManager.qml`), including reactive reload and live updates
- [x] First-Run Setup Wizard (`SetupWizard.qml`), writing to the same unified config schema

### Phase 4 — App Store & Package Management [IN PROGRESS]
- [x] App Store UI (`StoreApp.qml` with categories, installed app detection via `ApplicationManager`, search)
- [x] Full App Store ↔ ApplicationManager integration (satisfying canonical lifecycle without dummy IDs)
- [x] Bundled external app configurations (Kitty, Thunar, Brave, Antigravity) + DeloOS branded desktop entries
- [ ] Direct libflatpak / PackageKit daemon bridge for native background installation transactions

### Phase 5 — Desktop Modes [COMPLETED]
- [x] Clean desktop mode (wallpaper + clean layout)
- [x] Widgets desktop mode (`WidgetsDesktop.qml` with live weather from `deloway-weather.py`, system CPU/RAM telemetry from `deloway-sysinfo.py`, and persistent notes in `~/.config/deloway/notes.txt`)
- [x] Traditional desktop mode (`DesktopManager.qml` with real desktop files/folders, icon grid, drag & drop, context menu, Reversal icon theme integration)

### Phase 6 — Distribution & Polish [IN PROGRESS / CORE COMPLETE]
- [x] Automated Installer (`install.sh`) with dependency checking and configuration deployment
- [x] Dedicated LightDM Wayland Login Session (`DeloWay`) installed in `/usr/share/wayland-sessions/deloway.desktop`
- [x] Isolated session wrapper `deloway-session` (`/usr/local/bin/deloway-session`) keeping user's personal `~/.config/hypr` completely untouched
- [x] Dedicated standalone session installer `scripts/install-session.sh`
- [x] Complete purge of all mock/dummy data across the entire desktop environment (Launcher, Dock, Desktop, Quick Settings, Notifications, Top Bar, Settings)
- [x] Real-time hardware telemetry daemon (`scripts/deloway-sysinfo.py`) providing live CPU, RAM, network, battery, and bluetooth data to `SystemMonitor.qml` singleton
- [x] Live weather service (`scripts/deloway-weather.py`)
- [x] Safe update & recovery script (`update.sh`)
- [ ] Multi-distro package packaging (PKGBUILD, RPM spec, deb)
- [x] Comprehensive documentation (`README.md`, `docs/ARCHITECTURE.md`, `docs/INSTALLATION.md`)

---

## 11. Explicit Non-Goals (things to actively resist doing)

- Do not fork KDE, GNOME, or any existing DE's compositor/shell codebase.
- Do not write a new Wayland compositor. Hyprland is the compositor, full stop.
- Do not write a new package manager. Wrap PackageKit and/or libflatpak.
- Do not build a custom file manager in Phases 1–4. Reuse and reskin an existing one.
- Do not depend on Hyprland plugins for core functionality (§2.3).
- Do not introduce the System Core/daemon before Phase 4 "just in case."
- Do not let any shell surface (Dock, Drawer, Search, Store) maintain its own independent app list — everything flows through the ApplicationManager (§4).
- Do not attempt the Traditional desktop mode (icons/files on desktop) before Phase 5.
- Do not theme the shell itself with CSS — it's QML; use the `theme.json` token system (§8).

---

## 12. Prior Art to Study (not to copy wholesale)

- **Omarchy** — an opinionated Hyprland-based Linux distribution/setup (by DHH)
- **Noctalia** — minimalist Quickshell-based shell
- **Caelestia** — Quickshell-based shell project
- **illogical-impulse / end-4/dots-hyprland** — extensive Quickshell/Hyprland dotfiles with a mature matugen-based theming pipeline (GTK, qt5ct/qt6ct, Kvantum, kde-material-you-colors)
- **Ambxst/Aura** — a full Arch-based distro built around a Quickshell environment, including its own first-run setup script — directly relevant prior art for §5.10

Study these primarily for **code organization patterns** (how they structure services, how they wire Hyprland IPC into QML, how their theming pipelines are organized), not to copy their specific visual design.

---

## 13. Deviation Log

*(Add an entry here any time an implementation deviates from a DECIDED item above, with a one-paragraph justification. Keep this list append-only.)*

- **2026-09-10 — Isolated Compositor Wrapper (`deloway-session`) & Display Manager Integration**:
  To guarantee zero disruption to existing user configurations, DeloWay does not modify or overwrite `~/.config/hypr/hyprland.conf`. Instead, it provides a dedicated Wayland session (`/usr/share/wayland-sessions/deloway.desktop` named "DeloWay") and a binary launcher (`/usr/local/bin/deloway-session`). The wrapper launches Hyprland with an isolated config argument (`Hyprland -c ~/.config/deloway/hyprland.conf`), fully coexisting with any pre-existing Hyprland environment on the host and integrating cleanly with the host's active display manager (LightDM).

- **2026-09-10 — Lightweight Hardware Telemetry Bridge (`deloway-sysinfo.py` / `deloway-weather.py`)**:
  Rather than waiting for a full Rust daemon in Phase 4 or displaying mock telemetry, real hardware metrics (CPU delta from `/proc/stat`, memory from `/proc/meminfo`, battery state from `/sys/class/power_supply/`, active network interface/IP, and live weather) are retrieved via lightweight Python worker scripts and exposed to QML through the `SystemMonitor.qml` singleton. This enabled an immediate, complete purge of all placeholder and mock data across the Top Bar, Quick Settings, Widgets, and Settings panels without introducing heavy daemon dependencies.
