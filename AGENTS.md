# DeloWay Architecture & Development Guidelines for AI Agents

> **CRITICAL ARCHITECTURAL DIRECTIVE: STRICT MONOCHROME IDENTITY**
> DeloWay is an OLED-first, high-contrast monochrome desktop shell. It strictly possesses only two theme modes: **Dark** (pure OLED blacks and neutral grays) and **Light** (crisp high-contrast neutrals).
>
> **There is NO accent color system.** No purple, blue, teal, or customizable highlight palette is permitted in the UI, stylesheets, or configurations. Any appearance of decorative colored accents is an architectural bug.

---

## 1. Visual Identity & Contrast Rules

1. **Monochrome Hierarchy**:
   - Visual hierarchy, elevation, and focus are established strictly through **luminance (brightness)**, **font weights**, **layering**, and **opacity/alpha**, NEVER through decorative colors.
   - Active/selected states use neutral contrast:
     - In **Dark Mode**: Solid white (`#ffffff`) or high-luminance surface with black text (`#000000`).
     - In **Light Mode**: Solid dark slate (`#0f172a` / `#111827`) with white text (`#ffffff`).

2. **Semantic Colors Strictly Restricted**:
   - Only three semantic colors are permitted across the entire system:
     - **Danger / Urgent**: Red (`#ef4444` / `Theme.colors.urgent`) for destructive actions, errors, and removal.
     - **Warning**: Amber / Yellow (`#f59e0b` / `Theme.colors.warning`) for alerts and cautions.
     - **Success / Online**: Green (`#10b981` / `Theme.colors.success`) for connectivity and task completion.
   - **Scale Restriction**: Semantic colors must ONLY be used in tiny indicators (status dots $\le 8\text{px}$, warning badges, icon glyphs). They must **NEVER** be used as large surface fills or dominant container backgrounds.

3. **No Hardcoded Hex Colors in Components**:
   - All colors must reference tokens from `shell/theme/Theme.qml` (e.g., `Theme.notchText`, `Theme.notchBackground`, `Theme.colors.surface`, `Theme.colors.borderHighlight`).
   - Adding or modifying tokens must occur exclusively in `Theme.qml` and the official theme palettes (`shell/theme/themes/deloos-dark.json`, `deloos-light.json`).

---

## 2. Process & Runtime Constraints

1. **Zero Hot-Reload Policy**:
   - Never rely on or trigger Quickshell hot-reloading (`qs -r` or saving while watching). Quickshell has a registered upstream multi-threaded crash trace during live QML reloads.
   - Always perform a clean process restart:
     ```bash
     killall quickshell; sleep 1.5; hyprctl dispatch exec "quickshell -p /home/waleed/Projects/Deloway/shell"
     ```
   - Verify logs after restart with:
     ```bash
     qs log -p /home/waleed/Projects/Deloway/shell
     ```
     Ensure **zero new warnings or error stack traces**.

2. **Mandatory Theme Pre-flight Validation**:
   - Before committing any changes, you MUST run:
     ```bash
     ./scripts/check-theme.sh
     ```
   - The test must report `100% Monochrome compliance. Zero accent violations found.` with exit code `0`.

3. **Sequential Execution & Verification**:
   - Implement tasks sequentially. Stop and provide empirical evidence (clean `qs log`, screenshots via `grim`) after modifying major components.
   - Keep git commits atomic and well-documented.
