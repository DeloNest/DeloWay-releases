# DeloWay — Performance & Graphics Optimization Plan

> **Scope**: QML Shell, Services, Theme Engine, Compositor Configuration, Startup, Memory, GPU, Power.  
> **Target Environment**: Arch Linux x86_64, Hyprland 0.56.2 (Aquamarine backend), Quickshell 0.3.1, Qt 6.8+, NVIDIA GTX 1660 Ti.  
> **Constraint Invariant**: Zero degradation of visual fidelity, layout, theme aesthetics (Dark / Glass / Light), animation feel/curves, or Arabic/RTL bidirectionality.

---

## 1. Executive Summary & Baseline Metrics

Measurements were captured inside an isolated nested session (`1600x1000`, 60Hz, instance `efb5099378007946...`, `wayland-3`), with a 10s warmup per test, 3x30s sampling intervals per theme, 10-cycle animation stress tests, and a 5-minute continuous window toggle soak test.

### 1.1 Idle Baseline by Theme (Mean / Min / Max over 3 x 30s)

| Metric | Dark (OLED Solid) | Glass (Acrylic 38%) | Light (Clean Light) |
| :--- | :--- | :--- | :--- |
| **Quickshell CPU%** | 0.08% (0.03 / 0.13) | 0.18% (0.07 / 0.33) | 0.14% (0.10 / 0.16) |
| **Quickshell RSS** | 635.4 MiB (635.4 / 635.5) | 635.6 MiB (635.6 / 635.6) | 636.6 MiB (636.5 / 636.8) |
| **Quickshell PSS** | 401.2 MiB (401.2 / 401.3) | 401.4 MiB (401.4 / 401.4) | 402.4 MiB (402.3 / 402.6) |
| **Quickshell Ctxt Sw/s** | 0.78 (0.72 / 0.88) | 1.19 (0.55 / 2.19) | 0.79 (0.72 / 0.91) |
| **Hyprland CPU%** | 0.05% (0.03 / 0.07) | 0.12% (0.10 / 0.16) | 0.05% (0.03 / 0.07) |
| **Hyprland RSS** | 382.0 MiB (382.0 / 382.0) | 382.0 MiB (382.0 / 382.0) | 382.0 MiB (382.0 / 382.0) |
| **Hyprland PSS** | 183.5 MiB (183.5 / 183.5) | 183.5 MiB (183.5 / 183.5) | 183.5 MiB (183.5 / 183.5) |
| **Hyprland Ctxt Sw/s** | 3.87 (3.79 / 4.01) | 4.26 (3.56 / 5.22) | 3.94 (3.72 / 4.12) |
| **GPU Utilization** | 0.72% (0.59 / 0.83) | 1.13% (0.79 / 1.59) | 0.69% (0.52 / 0.93) |
| **GPU Power Draw** | 11.73 W (11.64 / 11.82) | 12.06 W (11.71 / 12.54) | 11.76 W (11.72 / 11.81) |
| **GPU VRAM Used** | 772.3 MiB (765.0 / 776.0) | 807.1 MiB (805.2 / 808.0) | 762.6 MiB (759.4 / 768.3) |

> **Key Takeaway**: Idle CPU across both Quickshell (<0.2%) and Hyprland (<0.15%) is remarkably low. However, Quickshell's memory footprint at idle (~635 MiB RSS / ~401 MiB PSS) is large due to eager instantiation of full-screen application overlays at startup.

---

### 1.2 Animation Render Cost (10 Repetitions Each)

| Action | Duration | Quickshell CPU% | Hyprland CPU% | Quickshell Ctxt/s | Hyprland Ctxt/s | GPU Util (Avg / Max) | GPU Power | Quickshell RSS |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Notch Expand/Collapse** | 11.0s | 19.50% | 5.89% | 137.4 | 199.7 | 20.4% / 30.0% | 21.26 W | 638.1 MiB |
| **App Drawer Open/Close** | 11.1s | 17.78% | 5.75% | 102.3 | 183.0 | 17.8% / 25.0% | 18.54 W | 645.1 MiB |
| **Settings Open/Close** | 12.1s | 18.30% | 14.01% | 66.4 | 808.3 | 25.8% / 32.0% | 30.03 W | 668.1 MiB |
| **Theme Switch (Dark/Glass)**| 12.2s | 15.46% | 30.02% | 122.2 | 147.2 | 16.7% / 29.0% | 24.54 W | 653.3 MiB |
| **Wallpaper Crossfade** | 13.1s | 16.50% | 4.56% | 132.3 | 164.5 | 22.7% / 39.0% | 19.32 W | 655.9 MiB |

> **Key Takeaway**:
> 1. Opening Settings generates high compositor context switches (~808/s) and jumps Quickshell RSS by +32 MiB.
> 2. Theme switching triggers significant compositor work (~30% Hyprland CPU) due to live shader reconfiguration and keyword updates.

---

### 1.3 Soak Test (5-Minute Continuous Window Toggle)

- **Duration**: 300 seconds (toggling SmartNotch, AppDrawer, Launcher, Clipboard, Settings every ~700ms).
- **Initial Quickshell RSS**: 656.0 MiB (PSS: 421.8 MiB)
- **Final Quickshell RSS**: 659.8 MiB (PSS: 425.6 MiB)
- **Net Growth**: **+3.8 MiB** (+0.58%) over 300 seconds.
- **Hyprland RSS**: 384.2 MiB -> 384.5 MiB (+0.3 MiB).
- **Conclusion**: **NO runaway memory leak**. The QML scene graph and texture memory stabilize, recycling allocations across opens and closes.

---

## 2. Quality Guard List (Invariants to Protect)

The following behaviors, styling, and geometry are **sacred** and must not change:

1. **Theme Identity & Compliance**:
   - Strict monochrome palette compliance (`./scripts/check-theme.sh` 100% pass, 0 violations).
   - Exact Dark (OLED black #000000), Glass (38% acrylic rgba), and Light aesthetics.
   - Dual-Kawase blur parameters (size: 8, passes: 2) in Glass mode.
2. **Layout & Geometry**:
   - Top capsule geometry, notch dimensions, padding, borders, and corner radii tokens.
   - Dock position, icon size, bounce indicators, and autohide margins.
3. **Animation Physics**:
   - Standardized cubic beziers (`md3_decel`, `menu_decel`, `easeOutCubic`).
   - Standard motion durations (120ms fast, 220ms base).
4. **Arabic / RTL Support**:
   - Layout mirroring (`isRTL ? Qt.RightToLeft : Qt.LeftToRight`).
   - Unicode Bidi isolation (`I18n.isolate()` using `\u2068` and `\u2069`).
   - Cairo font rendering, Arabic glyph shaping, and directional icon lookups (`-rtl` variants).
5. **IPC & External Contracts**:
   - All `IpcHandler` calls in `shell/shell.qml` (`openSmartNotch`, `toggleDrawer`, `setTheme`, `setWallpaper`, etc.) must maintain identical signatures and behavior.
6. **Multi-Monitor Safe**:
   - Hotplug-safe behavior via `Variants { model: Quickshell.screens }`.

---

## 3. Prioritized Backlog & Implementation Batches

### Batch 1: Lazy Loading for Infrequently Used Heavy Overlays [SAFE / HIGH IMPACT]
- **Target File**: [`shell/shell.qml`](file:///home/waleed/Projects/Deloway/shell/shell.qml#L435-L442)
- **Problem**: `SetupWizard`, `SettingsAppV2`, `CheatSheet`, `ScreenshotTool`, and `SessionMenu` are eagerly instantiated on every physical monitor inside `Variants { model: Quickshell.screens }` at startup.
  - `SetupWizard` is only ever needed on fresh install / setup.
  - `SettingsAppV2` has dozens of sub-tabs and controls.
  - `CheatSheet`, `ScreenshotTool`, and `SessionMenu` are only opened on specific hotkeys.
- **Proposed Solution**:
  Wrap these 5 components in `Loader { active: ...; sourceComponent: Component { ... } }`:
  - `SetupWizard`: `active: ShellState.setupWizardOpen || !ConfigManager.setupCompleted`
  - `SettingsAppV2`: `active: ShellState.settingsAppOpen`
  - `CheatSheet`: `active: ShellState.cheatSheetOpen`
  - `ScreenshotTool`: `active: ShellState.screenshotOpen`
  - `SessionMenu`: `active: ShellState.sessionMenuOpen`
- **Expected Gain**:
  - ~40 to 65 MiB RSS reduction at startup / idle.
  - Faster shell initial boot time.
  - Reduced memory footprint on multi-monitor configurations.
- **Verification Plan**:
  - Nested session verification: test opening Super+I (Settings), Super+T (CheatSheet), Print (Screenshot), Ctrl+Alt+Del (SessionMenu).
  - Verify `qmllint shell/shell.qml` and `./scripts/check-theme.sh`.
  - Measure before/after RSS and startup time.

---

### Batch 2: Background Sysinfo Smart Polling [SAFE / LOW RISK]
- **Target File**: [`shell/services/SystemMonitor.qml`](file:///home/waleed/Projects/Deloway/shell/services/SystemMonitor.qml#L136-L145)
- **Problem**: `sysTimer` runs every 10 seconds (or 3s if widgets are visible) and spawns `deloway-sysinfo.py` via `Process`. On desktop systems with no battery and when desktop widgets are hidden, polling CPU/RAM/Battery every 10s runs a Python subprocess 360 times/hour with no visual consumer on the top bar.
- **Proposed Solution**:
  - If `root.widgetsVisible` is true, continue polling at 3000ms.
  - If QuickSettings capsule or TimeCapsule is expanded, poll at 3000ms.
  - If collapsed, desktop widgets hidden, and system is a desktop (`!hasBattery`), back off interval to 60s (or pause until capsule expands).
- **Expected Gain**:
  - Eliminates ~300 Python process forks per hour at idle.
  - Reduces CPU wakeups and context switches at idle.
- **Verification Plan**:
  - Test widget updates on desktop and QuickSettings/TimeCapsule expand.
  - Verify battery and network state remain accurate.

---

### Batch 3: Compositor Configuration Tuning [SAFE / COMPOSITOR]
- **Target File**: [`config/hyprland.conf`](file:///home/waleed/Projects/Deloway/config/hyprland.conf)
- **Problem**: `render:direct_scanout` is currently `false` (0) in Hyprland. Fullscreen games/media players incur compositor compositing overhead.
- **Proposed Solution**:
  - Test `render:direct_scanout = 1` in nested Hyprland.
  - Verify layer rules for overlays: ensure `no_anim on` on screenshot tool and app drawer prevent conflicting compositor animations.
- **Expected Gain**: Reduced GPU load and latency for fullscreen windows.
- **Verification Plan**: Verify in nested session with `hyprctl -i <sig> getoption render:direct_scanout`.

---

## 4. Ideas for Further Gains (Backlog / Future Exploration)

1. **Native / C++ or direct sysfs telemetry**:
   Replace Python invocations in `deloway-sysinfo.py` with direct `FileView` reads of `/proc/stat` and `/proc/meminfo` in QML/Quickshell, eliminating subprocess invocation entirely.
2. **Icon Texture Atlasing / Quickshell Caching**:
   Investigate Quickshell image provider cache tuning for application icons in AppDrawer.
3. **AppDrawer / SearchLauncher Deferred Async Warmup**:
   Pre-warm `AppDrawer` 2 seconds after boot during idle time using `asynchronous: true` on its `Loader` so the first Super tap is instantaneous without paying the cost during boot.

---

## 5. Not-Worth-It List (Analyzed & Rejected)

1. **Dynamically resizing `TopBar.qml` PanelWindow height (from 620px to 44px)**:
   - *Reason for Rejection*: Changing layer-shell surface geometry on Wayland forces buffer renegotiation, frame buffer reallocations in Aquamarine, and asynchronous compositor roundtrips during animation. This induces visible stutter during Notch expansion. Keeping the static 620px transparent masked window costs negligible VRAM (~4 MB) and guarantees 60 FPS fluid motion.
2. **Replacing custom bezier curves with linear or native animations**:
   - *Reason for Rejection*: The fluid Apple/MD3 motion feel is a core design requirement of DeloWay. Hard cuts or linear easing degrade visual premium quality.
3. **Removing `Background.qml` crossfade or double buffering**:
   - *Reason for Rejection*: Crossfading wallpapers looks gorgeous and `Background.qml` already zeroes out the inactive image source on animation finish.
4. **Rewriting `deloway-theme-apply.py` in C / Rust**:
   - *Reason for Rejection*: Theme switching is user-initiated and happens in ~80ms. The Python script already uses `atomic_write_if_changed` and `get_gsettings_value` caching. Not a performance bottleneck.

---

## 6. Performance Budgets

| Target Metric | Baseline (Idle) | Budget Goal (Post-Optimization) |
| :--- | :--- | :--- |
| **Quickshell Idle RSS** | 635.4 MiB | **< 580.0 MiB** (-55 MiB) |
| **Quickshell Idle PSS** | 401.2 MiB | **< 360.0 MiB** (-41 MiB) |
| **Quickshell Idle CPU** | 0.08% | **< 0.10%** |
| **Hyprland Idle CPU** | 0.05% | **< 0.08%** |
| **Soak Test 5-min Growth** | +3.8 MiB | **< 5.0 MiB** |
| **Monochrome Compliance**| 100% (0 violations) | **100% (0 violations)** |
| **Animation Frame Rate** | 60 FPS locked | **60 FPS locked** |

---

## 7. Quality Guard Checklist (Must Pass for Every Batch)

- [ ] `qmllint` passes with 0 errors across all QML files.
- [ ] `./scripts/check-theme.sh` reports 100% monochrome compliance.
- [ ] Nested Hyprland & Quickshell logs report 0 warnings or errors.
- [ ] Dark, Glass, and Light themes switch cleanly with identical styling.
- [ ] Arabic / RTL text and icons layout correctly with zero clipping or direction reversal.
- [ ] All IPC methods maintain backward compatibility.
- [ ] Measured before/after metrics confirm memory or CPU improvements under identical conditions.
