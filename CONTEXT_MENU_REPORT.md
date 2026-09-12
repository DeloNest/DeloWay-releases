# Deloway — App Right-Click Context Menu: Handoff Report

This document is a complete technical handoff for fixing / finishing the **app context menu** (right-click on Dock icons and App Drawer cells) in the **DeloWay** shell. It covers the failed attempts, the current architecture/data path, the environment commands, and the remaining open questions. It is written to be given to another AI so it can take over without re-deriving context.

---

## 1. Project & Environment

- **Project root:** `/home/waleed/Projects/Deloway`
- **Shell code root:** `/home/waleed/Projects/Deloway/shell`
- **Framework:** Quickshell (runtime QML — **no build step**). Qt6 / QML. Compositor: Hyprland (wlr-layer-shell + xdg-popup).
- **Deploy (reload the shell):**
  ```bash
  killall quickshell
  hyprctl dispatch exec "quickshell -p /home/waleed/Projects/Deloway/shell"
  ```
- **Validate a QML file:**
  ```bash
  qmllint -I shell shell/components/<file>.qml
  ```
- **IPC (call functions into the running shell from scripts / CLI):**
  ```bash
  quickshell n -p /home/waleed/Projects/Deloway/shell call deloway <function> <args...>
  ```
  Handlers live in `IpcHandler { target: "deloway" ... }` inside `shell/shell.qml`.
- **Logging:** QML `console.log()` output is **not captured** by simply redirecting the launched process (only `ok` appears). Debug logs inside the shell (prefixed `[Deloway][AppCtx]`) are visible in quickshell's own terminal/journal output, not in `/tmp/qs.log`.

---

## 2. Objective

When the user **right-clicks an app**:
- in the **Dock** (bottom bar), or
- in the **App Drawer** (grid overlay opened with Super),

a **context menu should appear directly above/at the clicked icon** with actions:
`Pin to Dock / Unpin from Dock`, `Open`, and (if running) `Close`.

This has **never successfully worked for the user**, despite several rewrites.

### Related, in-flight issues (partly fixed, not user-confirmed)
- App Drawer **did not open with the Super key** → fixed syntactically by keybind changes (see §6), needs user confirmation.
- App Drawer **pushed open windows up** instead of overlaying them → fixed by `exclusionMode: ExclusionMode.Ignore` on AppDrawer, needs user confirmation.

---

## 3. Timeline of FAILED attempts (in order)

### Attempt A — Inline context menu inside the Dock window, dynamic dock height
- Added the menu as an inline component inside `Dock.qml`.
- Made the Dock `PanelWindow` height dynamic: `implicitHeight: ctxVisible ? 280 : 100`.
- Right-click handler called internal state (`root.showCtx`) instead of a shared one.
- **Result: menu did not appear.**
- Likely causes: the dock layer-surface is bottom-anchored and only 100 px tall by default; expanding its height to 280 and relying on an inline child menu clipped/mispositioned, and `anchors.bottom` fixed-height surface resize under layer-shell is unreliable.

### Attempt B — Shared full-screen Overlay `PanelWindow` (THE BIG MISTAKE)
- Added shared state to `ShellState.qml`:
  `appContextMenuVisible / appContextMenuX / appContextMenuY / appContextMenuTarget` + `showAppContextMenu(app, x, y)` / `closeAppContextMenu()`.
- Rewrote `AppContextMenu.qml` as a **full-screen `PanelWindow` on `WlrLayer.Overlay`**, with a full-screen backdrop `MouseArea` (dismiss-on-outside-click) and a positioned menu card at `x/y = ShellState.appContextMenuX/Y`.
- Instantiated one instance per screen in `shell.qml`'s `Variants` delegate (`AppContextMenu { targetScreen: screenScope.modelData }`).
- Removed inline menus from `Dock.qml` and `AppDrawer.qml`; their right-click handlers now call `ShellState.showAppContextMenu(app, mapToItem(root, mouse.x, mouse.y)...)`.
- **Result: still did not appear.**
- **Two root causes, identified later:**
  1. **Coordinate-space mismatch:** The Dock/AppDrawer passed coordinates in the **source window's local space** (e.g. dock y = `0..100`, x = `0..dockWidth`) into a **full-screen** window whose `(0,0)` is the **monitor top-left**. So the card was placed near the *top* of the screen (~y=30-80) instead of at the bottom dock, effectively "not where the user looks".
  2. **Full-screen layer surface over everything = input blocking / unreliable mapping.** A full-screen `Overlay` layer surface either (a) blocked *all* pointer input to the desktop/dock beneath it when always-mapped, or (b) when `visible` was toggled, depended on layer-surface map/unmap semantics that were never proven reliable here.
- Note: a sub-variant with `visible: ShellState.appContextMenuVisible` on the PanelWindow was deployed; user still said it didn't work (same coordinate bug). A later on-disk variant removed the `visible` binding entirely (always-mapped, would block ALL input) — **this was never deployed**.

### Attempt C — CURRENT, UNVERIFIED: `PopupWindow` (matches the reference project's proven pattern)
- Rewrote `AppContextMenu.qml` as a **`PopupWindow`** (xdg-popup) anchored to the **source window**:
  - `anchor.window` = the Dock/AppDrawer `PanelWindow` that was right-clicked.
  - `anchor.rect.x/y` = the click point **in that window's own coordinates** (exactly what `mapToItem(root, mouse.x, mouse.y)` already returns) → **no screen-coordinate math needed.**
  - `anchor.gravity: Edges.Top | Edges.Right` → menu **opens UPWARD** from the click point.
  - `anchor.adjustment: PopupAdjustment.Slide` → keeps it on-screen.
  - `visible: ShellState.appContextMenuVisible && ShellState.appContextMenuAnchorScreen === targetScreen` (only the per-screen instance whose screen hosts the anchor window shows).
  - Removed the full-screen backdrop + dismiss timer.
  - `Connections { onClosed → ShellState.closeAppContextMenu() }` keeps state in sync on native outside-click dismissal.
- `ShellState.showAppContextMenu(app, window, x, y)` now also records `appContextMenuAnchorWindow` and `appContextMenuAnchorScreen` (from `window.screen`).
- Updated callers to pass the window: `Dock.qml:252`, `AppDrawer.qml:538` and `:635`.
- **Status:** `qmllint` clean, deployed, shell restarts cleanly. **Has NOT been verified by the user.**

---

## 4. Current data path ("the menu path") — file-by-file

### Trigger (right-click)
- **Dock:** `shell/components/Dock.qml` — app icon `MouseArea` at ~lines 242-257;
  ```qml
  onClicked: mouse => {
    if (mouse.button === Qt.RightButton) {
      var pos = mapToItem(root, mouse.x, mouse.y);                    // dock-window local coords
      ShellState.showAppContextMenu(appItem.modelData, root, pos.x, pos.y);  // Dock.qml:252
    } else { ApplicationManager.activateOrLaunch(appItem.modelData); }
  }
  ```
- **App Drawer — "Recent/All" cells:** `shell/components/AppDrawer.qml` `cellMouse` at ~line 528-548 → call at `AppDrawer.qml:538`.
- **App Drawer — "More Applications" cells:** `moreCellMouse` at ~line 625-645 → call at `AppDrawer.qml:635`.

### State bridge
- **`shell/services/ShellState.qml`** (Singleton, lines ~163-190):
  ```qml
  property bool appContextMenuVisible
  property real appContextMenuX / appContextMenuY
  property var appContextMenuTarget
  property var appContextMenuAnchorWindow
  property var appContextMenuAnchorScreen
  function showAppContextMenu(app, window, x, y) { ... logs "[Deloway][AppCtx] ..." }
  function closeAppContextMenu() { ... }
  ```

### The menu UI
- **`shell/components/AppContextMenu.qml`** — `PopupWindow` (see §3 Attempt C for anchors). Content = `Rectangle` menu card with:
  - Header (app name),
  - **Pin/Unpin** → `ApplicationManager.togglePin(app.id)` (`AppContextMenu.qml:95`),
  - **Open** → `app.execute()` or `ApplicationManager.activateOrLaunch(app)` (`AppContextMenu.qml:109`),
  - **Close** (only when `app.running === true`) → closes `app.windows[]` (`AppContextMenu.qml:115-124`).
  - Each action calls `root.hide()` → `ShellState.closeAppContextMenu()`.

### Instantiation
- **`shell/shell.qml`** `Variants { model: Quickshell.screens }` delegate, ~line 302-304:
  ```qml
  AppContextMenu { targetScreen: screenScope.modelData }
  ```
  → **one PopupWindow instance per monitor.** Both instances bind to the same ShellState anchor; visibility is gated by screen identity.

### Keybindings (drawer)
- **`config/hyprland.conf`** lines 107-110:
  ```conf
  bindr = $mainMod, $mainMod_L, global, quickshell:drawerToggle   # Super alone
  bind  = $mainMod, Space,    global, quickshell:drawerToggle
  bind  = $mainMod, D,        global, quickshell:drawerToggle
  ```
  (Removed the old `bind = $mainMod, D, fullscreen, 1`.) `GlobalShortcut { name: "drawerToggle" }` → `ShellState.toggleAppDrawer()` lives at `shell/shell.qml:16-20`.

---

## 5. Why the current approach is expected to work (evidence)

- The **reference production config** (`dots-hyprland`, at `/home/waleed/dots-hyprland/dots/.config/quickshell/ii/`) solves the *identical* problem — a popup near the dock — with **`PopupWindow` anchored to the dock's window**:
  - `.../ii/modules/ii/dock/DockApps.qml` — `previewPopup`: PopupWindow anchored via `anchor { window: root.QsWindow.window; adjustment: PopupAdjustment.None; gravity: Edges.Top | Edges.Right; edges: Edges.Top | Edges.Left }`, and positions content in that space using `root.QsWindow.mapFromItem(...)`.
  - `.../ii/modules/ii/bar/SysTrayMenu.qml` — same pattern for system tray menus.
  This proves PopupWindow anchoring to a layer-surface panel **works** on this exact stack.
- **Quickshell internals (confirmed from source):**
  - `ProxyPopupWindow::deleteOnInvisible() → true` (`src/window/popupwindow.cpp:147`). On hide, the backing QWindow is **destroyed**; on show it is re-created and **repositioned on every show**. → No persistent surface ⇒ **no input blocking** and position is always fresh.
  - Popup positioner (`src/core/popupanchor.cpp:221-249`): with `edges: Top|Left` the anchor point = rect top-left; `gravity: Right` puts the popup's left edge at the anchor; `gravity: Top` puts the popup's top at `anchorY - height`, i.e. **extends upward** from the click point.
- Deloway's own *working* context menu — **desktop** right-click (`ShellState`-free) — uses an `Item` inside the always-mapped full-screen `Background.qml` PanelWindow (`shell/components/desktop/DesktopContextMenu.qml` + `Background.qml:72-75`); the background layer sits at the bottom so it never blocks input. This confirms the general "menu lives somewhere already-mapped" principle; PopupWindow is the proper variant for a menu that must sit ABOVE other panels.

---

## 6. What still needs verification / open questions

1. **Primary:** Does right-click in Dock and App Drawer now show the menu above the icon? (Last change NOT user-tested.)
2. If the menu appears but is misplaced/offset: adjust `anchor.gravity`, add a small offset to `anchor.rect.y`, or switch to `anchor.margins`.
3. If it appears on the FIRST right-click but not a second time: the issue is mVisible/toggle handling in `ProxyPopupWindow` — confirm `showAppContextMenu` is re-emitting correct values and `onClosed` isn't racing it. (The `visible` binding is declarative, so this should not regress.)
4. Multi-monitor: confirm only the screen you right-click on shows the menu (per-instance gate `appContextMenuAnchorScreen === targetScreen`).
5. **Separately:** confirm Super / Super+Space / Super+D opens the App Drawer, and that the Drawer overlays windows instead of pushing them (`ExclusionMode.Ignore`).
6. If debugging is desired, add an IPC test entry in `shell.qml`'s `IpcHandler` (e.g. `function testAppMenu()` that calls `ShellState.showAppContextMenu(<an app>, <a window>, X, Y)`) and observe `[Deloway][AppCtx]` logs in quickshell's real output.

---

## 7. Key files & line references (current state)

| File | Relevance |
|---|---|
| `shell/components/AppContextMenu.qml` | The menu UI — now a `PopupWindow` (lines 7-30 anchors; 95/109/124 actions). |
| `shell/services/ShellState.qml` | Singleton state + `show/closeAppContextMenu` (lines 163-190). |
| `shell/components/Dock.qml` | Right-click trigger (line 242-257; call at 252). Dock is a `PanelWindow`, height 100, `WlrLayer.Top`. |
| `shell/components/AppDrawer.qml` | Right-click triggers (lines 528-548; 625-645; calls at 538, 635). `exclusionMode: Ignore` (line 34). |
| `shell/shell.qml` | Per-screen instantiation (302-304); `drawerToggle` GlobalShortcut (16-20); `IpcHandler` (79+). |
| `shell/components/Background.qml` + `shell/components/desktop/DesktopContextMenu.qml` | WORKING reference: Item-menu inside an always-mapped **full-screen** PanelWindow on `WlrLayer.Background`. |
| `config/hyprland.conf` | Drawer keybinds (107-110). |

---

## 8. Red flags / gotchas for whoever takes over

- **Never make the context menu a full-screen always-mapped layer surface on `Overlay`/`Top`** — it will swallow the entire desktop's input. An `Item`-menu is only safe inside a window on a *low* layer (`Background`).
- The Dock/AppDrawer `mapToItem(root, mouse.x, mouse.y)` values are **window-local**, not screen coordinates. Only meaningful when the menu is anchored to that same window (PopupWindow), OR add the monitor/geometry offset.
- `console.log` isn't visible via a plain stdout redirect; check quickshell's terminal/journal.
- The shell is runtime QML — any saved change only applies after the restart command in §1.
- The project honors existing style: menus use `Rectangle`+`MouseArea` (no `QtQuick.Controls` Menu), `Theme.*` tokens, `SymbolicIcon`, Cairo-regular `font.family: Theme.typography.fontFamily`, integer `pixelSize`.