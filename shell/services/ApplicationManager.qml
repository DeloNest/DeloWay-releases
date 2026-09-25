pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    // Revision counter to force reactivity across lists when DesktopEntries scans complete or change
    property int _entriesRevision: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root._entriesRevision++;
        }
    }

    // ── Built-in entries ────────────────────────────────────────────────────
    // DeloWay's own apps have no .desktop file. The App Store is pamac-manager rebranded:
    // it exists only while pamac-manager is installed, and it stands in for pamac's own
    // entry ("Add/Remove Software") instead of listing the same program twice.
    readonly property string storeEntryId: "org.manjaro.pamac.manager"
    readonly property bool storeAvailable: {
        const _rev = _entriesRevision;
        return !!DesktopEntries.byId(root.storeEntryId);
    }
    readonly property var builtinApps: {
        const list = [{
            id: "settings",
            name: I18n.tr("settings"),
            icon: "settings",
            categories: ["System", "All"],
            comment: I18n.tr("settings_app_desc"),
            startupClass: "deloway-settings",
            execute: function() { ShellState.toggleSettingsApp(); }
        }];
        if (root.storeAvailable) list.push({
            id: "store",
            name: I18n.tr("app_store"),
            icon: "store",
            categories: ["System", "All"],
            comment: I18n.tr("app_store_desc"),
            startupClass: "pamac-manager",
            execute: function() { Hyprland.dispatch("exec pamac-manager"); }
        });
        return list;
    }
    // "settings" / "store" and their historical aliases → the built-in entry, or null.
    function builtinApp(cleanId) {
        const id = (cleanId === "deloway-settings") ? "settings"
                 : (cleanId === "app-store" || cleanId === "pamac" || cleanId === "pamac-manager") ? "store"
                 : cleanId;
        return root.builtinApps.find(a => a.id === id) || null;
    }

    // Installed = a built-in entry or a real desktop entry with that id. No heuristic
    // matching here: a fuzzy hit made pins of apps that are not installed look installed.
    function isInstalled(identifier) {
        if (!identifier) return false;
        const _rev = _entriesRevision;
        const cleanId = identifier.toLowerCase().replace(/\.desktop$/, "");
        if (root.builtinApp(cleanId)) return true;
        if (allApps && allApps.some(a => a && a.id.toLowerCase().replace(/\.desktop$/, "") === cleanId)) return true;
        return !!(DesktopEntries.byId(identifier) || DesktopEntries.byId(cleanId));
    }

    // Helper to find an app by ID
    function findApp(identifier) {
        if (!identifier) return null;
        const cleanId = identifier.toLowerCase().replace(/\.desktop$/, "");
        const builtin = root.builtinApp(cleanId);
        if (builtin) return builtin;
        if (allApps) {
            const found = allApps.find(a => a && (
                a.id.toLowerCase().replace(/\.desktop$/, "") === cleanId ||
                a.id.toLowerCase() === identifier.toLowerCase() ||
                (a.startupClass && a.startupClass.toLowerCase().replace(/\.desktop$/, "") === cleanId)
            ));
            if (found) return found;
        }
        return DesktopEntries.byId(identifier) || DesktopEntries.byId(cleanId) || DesktopEntries.heuristicLookup(cleanId);
    }

    // ── Dock pins ───────────────────────────────────────────────────────────
    // A default-app choice (an executable such as "brave" / "nautilus", or a desktop id)
    // → the lower-case id of the installed desktop entry that launches it, or "".
    function resolveAppChoice(choice) {
        const e = root.resolveAppEntry(choice);
        return e ? e.id.toLowerCase().replace(/\.desktop$/, "") : "";
    }

    // … and the desktop entry itself (exact-case id, for xdg-mime / gtk-launch), or null.
    function resolveAppEntry(choice) {
        if (!choice) return null;
        const _rev = _entriesRevision;
        const c = choice.toLowerCase().replace(/\.desktop$/, "");
        const entries = Array.from(DesktopEntries.applications.values).filter(e => e && e.id && !e.noDisplay);
        const byId = entries.find(e => {
            const id = e.id.toLowerCase().replace(/\.desktop$/, "");
            return id === c || id.endsWith("." + c);
        });
        if (byId) return byId;
        return entries.find(e => e.command && e.command.length > 0
                                 && String(e.command[0]).replace(/.*\//, "").toLowerCase() === c) || null;
    }

    // Pins until the user customises the Dock: the browser, terminal and file manager they
    // chose (installer / Setup Wizard), resolved to installed entries — never a fixed list
    // of apps that may not exist on this machine.
    readonly property var defaultPinnedAppIds: {
        const out = [];
        for (const choice of [ConfigManager.defaultBrowser, ConfigManager.defaultTerminal, ConfigManager.defaultFileManager]) {
            const id = root.resolveAppChoice(choice);
            if (id && out.indexOf(id) < 0) out.push(id);
        }
        return out;
    }

    // The configured list (incl. pins of apps that are not installed right now).
    // ConfigManager.pinnedApps is null until the user pins or unpins something; an empty
    // list is a real choice (an empty Dock) and is kept.
    function _configuredPins() {
        return (Array.isArray(ConfigManager.pinnedApps) ? ConfigManager.pinnedApps : root.defaultPinnedAppIds).slice();
    }

    // Pinned application IDs for the Dock, strictly filtered to installed apps.
    // Pure binding on ConfigManager.pinnedApps (assigning this property used to break the
    // binding, so Dock resets/external edits stopped applying).
    readonly property var pinnedAppIds: {
        const _rev = _entriesRevision;
        return root._configuredPins().filter(id => root.isInstalled(id));
    }

    // Checks if an appId is pinned
    function isPinned(appId) {
        if (!appId) return false;
        const target = appId.toLowerCase().replace(/\.desktop$/, "");
        for (let i = 0; i < pinnedAppIds.length; i++) {
            if (pinnedAppIds[i].toLowerCase().replace(/\.desktop$/, "") === target) return true;
        }
        return false;
    }

    // Pin an application
    function pinApp(appId) {
        if (!appId) return;
        const cleanId = appId.toLowerCase().replace(/\.desktop$/, "");
        if (!root.isInstalled(cleanId)) return;
        if (!isPinned(cleanId)) ConfigManager.setPinnedApps(root._configuredPins().concat([cleanId]));
    }

    // Unpin an application
    function unpinApp(appId) {
        if (!appId) return;
        const cleanId = appId.toLowerCase().replace(/\.desktop$/, "");
        if (isPinned(cleanId))
            ConfigManager.setPinnedApps(root._configuredPins().filter(id => id.toLowerCase().replace(/\.desktop$/, "") !== cleanId));
    }

    // Toggle pin status
    function togglePin(appId) {
        if (isPinned(appId)) unpinApp(appId);
        else pinApp(appId);
    }

    // All installed applications: the built-ins, then every desktop entry on disk.
    // Newly installed packages appear through DesktopEntries' own rescan.
    readonly property var allApps: {
        const _rev = _entriesRevision;
        const raw = Array.from(DesktopEntries.applications.values);
        const seen = new Set();
        const list = root.builtinApps.slice();
        for (const b of list) seen.add(b.id);
        if (root.storeAvailable) seen.add(root.storeEntryId.toLowerCase());

        for (let i = 0; i < raw.length; i++) {
            const app = raw[i];
            if (!app || !app.name || !app.id || app.noDisplay) continue;
            const cleanId = app.id.toLowerCase().replace(/\.desktop$/, "");
            if (seen.has(cleanId) || seen.has(app.id)) continue;
            if (app.id.includes("geo-handler") || app.id.includes("breezestyleconfig") || app.id.includes("darklystyleconfig") || app.id.includes("kcm_")) continue;
            seen.add(cleanId);
            seen.add(app.id);
            list.push({
                id: app.id,
                name: app.name,
                icon: app.icon || "application-x-executable",
                categories: app.categories || ["All"],
                comment: app.comment || "",
                startupClass: app.startupClass || "",
                execute: function() { app.execute(); }
            });
        }

        return list;
    }

    // List of active toplevel windows
    readonly property var toplevels: ToplevelManager.toplevels.values

    // Currently focused toplevel
    readonly property var activeToplevel: ToplevelManager.activeToplevel

    // Checks whether two application identifiers or window classes refer to the same app
    function matchesAppId(idA, idB) {
        if (!idA || !idB) return false;
        const a = idA.toLowerCase().replace(/\.desktop$/, "");
        const b = idB.toLowerCase().replace(/\.desktop$/, "");
        if (a === b) return true;

        // Strict boundary: Antigravity AI (orchestrator/assistant) and Antigravity IDE (code editor) are strictly separate applications
        const isAntigravityAI = (x) => (x === "antigravity" || x === "antigravity-2.0" || x === "google-antigravity");
        const isAntigravityIDE = (x) => (x === "antigravity-ide" || x === "antigravity_ide");
        if ((isAntigravityAI(a) && isAntigravityIDE(b)) || (isAntigravityIDE(a) && isAntigravityAI(b))) {
            return false;
        }

        // Match StartupWMClass if available in desktop entry
        const entryA = findApp(a);
        if (entryA && entryA.startupClass && entryA.startupClass.toLowerCase().replace(/\.desktop$/, "") === b) return true;
        const entryB = findApp(b);
        if (entryB && entryB.startupClass && entryB.startupClass.toLowerCase().replace(/\.desktop$/, "") === a) return true;

        // Match reverse domain suffixes (e.g. org.gnome.TextEditor <=> texteditor)
        const aParts = a.split(".");
        const bParts = b.split(".");
        const aLast = aParts[aParts.length - 1];
        const bLast = bParts[bParts.length - 1];
        if (aLast === bLast && aLast.length > 2) return true;

        // Explicit known aliases
        if ((a === "brave-browser" && b === "brave") || (a === "brave" && b === "brave-browser")) return true;
        if ((a === "store" && b === "pamac-manager") || (a === "pamac-manager" && b === "store")) return true;
        if ((a === "code-oss" && b === "code") || (a === "code" && b === "code-oss")) return true;
        if ((a === "google-chrome" && b === "chrome") || (a === "chrome" && b === "google-chrome")) return true;

        return false;
    }

    // Check if a toplevel belongs to an already pinned app
    function isToplevelPinned(top) {
        if (!top || !top.appId) return false;
        for (let i = 0; i < pinnedAppIds.length; i++) {
            if (matchesAppId(pinnedAppIds[i], top.appId)) return true;
        }
        return false;
    }

    // ── Window state (Hyprland-backed) ───────────────────────────────────
    // Hyprland ignores foreign-toplevel minimize requests, so "minimized" = parked on
    // the special workspace below; restore moves the window back to the focused
    // workspace.
    //
    // Minimized + focused state is tracked HERE from Hyprland's own event payloads
    // (movewindowv2 / activewindowv2 / closewindow), seeded once from `hyprctl -j`.
    // Quickshell's cached HyprlandToplevel.workspace and Toplevel.activated lag behind
    // (or never update) after moves to special workspaces, which made a second dock
    // click act on stale state.
    readonly property string minimizedWorkspace: "special:minimized"
    property var _minimized: ({})        // normalized address → true
    property string activeAddress: ""     // normalized address of Hyprland's active window

    function normAddr(a) {
        const s = String(a || "").toLowerCase();
        return s.startsWith("0x") ? s.substring(2) : s;
    }
    function hyprToplevelFor(t) {
        if (!t) return null;
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].wayland === t) return list[i];
        }
        return null;
    }
    function addressOf(t) {
        const hl = hyprToplevelFor(t);
        return (hl && hl.address) ? "0x" + normAddr(hl.address) : "";
    }
    function isMinimized(t) {
        const a = normAddr(addressOf(t));
        return a.length > 0 && root._minimized[a] === true;
    }
    function isActiveWindow(t) {
        const a = normAddr(addressOf(t));
        if (a.length > 0 && root.activeAddress.length > 0) return a === root.activeAddress;
        return !!(t && t.activated);
    }
    function isUrgent(t) {
        const hl = hyprToplevelFor(t);
        return !!(hl && hl.urgent);
    }
    function currentWorkspaceId() {
        const ws = Hyprland.focusedWorkspace;
        return ws ? ws.id : 1;
    }
    function _setMinimized(addr, on) {
        const a = normAddr(addr);
        if (!a) return;
        if (on === (root._minimized[a] === true)) return;
        const m = Object.assign({}, root._minimized);
        if (on) m[a] = true; else delete m[a];
        root._minimized = m;
        root._windowStateRevision++;
    }

    function minimizeWindow(t) {
        const a = addressOf(t);
        if (!a) return;
        // After parking it, hand focus to another window on this workspace so typing
        // doesn't keep going into the hidden window.
        const wsId = root.currentWorkspaceId();
        const self = normAddr(a);
        const list = Hyprland.toplevels.values;
        let next = "";
        for (let i = 0; i < list.length; i++) {
            const h = list[i];
            if (!h || !h.address || !h.workspace || h.workspace.id !== wsId) continue;
            const ha = normAddr(h.address);
            if (ha === self || root._minimized[ha]) continue;
            next = "0x" + ha;
            if (h.wayland && h.wayland.activated) continue;   // prefer not the one we hide
            break;
        }
        root._setMinimized(a, true);                           // optimistic; event confirms
        Hyprland.dispatch("movetoworkspacesilent " + root.minimizedWorkspace + ",address:" + a);
        if (next) Hyprland.dispatch("focuswindow address:" + next);
    }
    function restoreWindow(t) {
        const a = addressOf(t);
        if (!a) return;
        root._setMinimized(a, false);
        Hyprland.dispatch("movetoworkspacesilent " + root.currentWorkspaceId() + ",address:" + a);
        Hyprland.dispatch("focuswindow address:" + a);
    }
    function focusWindow(t) {
        if (!t) return;
        if (isMinimized(t)) { restoreWindow(t); return; }
        const a = addressOf(t);
        if (a) Hyprland.dispatch("focuswindow address:" + a);   // also switches workspace
        else if (typeof t.activate === "function") t.activate();
    }
    function toggleMaximize(t) {
        const a = addressOf(t);
        if (!a) return;
        if (isMinimized(t)) restoreWindow(t);
        Hyprland.dispatch("focuswindow address:" + a);
        Hyprland.dispatch("fullscreen 1");                      // Hyprland "maximize" (keeps gaps/bar)
    }
    // Hyprland "maximize" = fullscreen mode 1; reported via foreign-toplevel `maximized`
    // and, as a fallback, the IPC snapshot.
    function isMaximized(t) {
        if (!t) return false;
        if (t.maximized) return true;
        const hl = hyprToplevelFor(t);
        const ipc = hl ? hl.lastIpcObject : null;
        return !!(ipc && (ipc.fullscreen === 1 || ipc.fullscreenClient === 1));
    }
    // The window a per-app action (maximize, minimize…) should target.
    function primaryWindow(item) {
        const wins = (item && item.windows) ? item.windows.filter(w => !!w) : [];
        return wins.find(w => root.isActiveWindow(w)) || wins.find(w => !root.isMinimized(w)) || wins[0] || null;
    }
    function minimizeAll(item) {
        for (const w of ((item && item.windows) || [])) if (w && !root.isMinimized(w)) root.minimizeWindow(w);
    }
    function restoreAll(item) {
        const wins = ((item && item.windows) || []).filter(w => w && root.isMinimized(w));
        for (const w of wins) root.restoreWindow(w);
    }
    function closeAllWindows(item) {
        const wins = (item && item.windows) ? item.windows : [];
        for (const w of wins) if (w && typeof w.close === "function") w.close();
    }

    // Dock click semantics (Windows-taskbar style):
    //   not running           → launch
    //   one window, focused   → minimize        one window, minimized → restore + focus
    //   one window, elsewhere → focus (switches workspace if needed)
    //   several windows       → focused one? cycle to the next : bring the most relevant up
    function clickDockApp(item) {
        if (!item) return;
        const wins = (item.windows || []).filter(w => !!w);
        if (wins.length === 0) { root.activateOrLaunch(item); return; }
        if (wins.length === 1) {
            const w = wins[0];
            if (root.isMinimized(w)) root.restoreWindow(w);
            else if (root.isActiveWindow(w)) root.minimizeWindow(w);
            else root.focusWindow(w);
            return;
        }
        const activeIdx = wins.findIndex(w => root.isActiveWindow(w));
        if (activeIdx !== -1) {
            // cycle among non-minimized windows first
            for (let k = 1; k < wins.length; k++) {
                const cand = wins[(activeIdx + k) % wins.length];
                if (!root.isMinimized(cand)) { root.focusWindow(cand); return; }
            }
            root.minimizeWindow(wins[activeIdx]);
            return;
        }
        const visible = wins.find(w => !root.isMinimized(w));
        root.focusWindow(visible || wins[0]);
    }

    function newWindow(item) {
        if (!item) return;
        if (item.desktopEntry && typeof item.desktopEntry.execute === "function") item.desktopEntry.execute();
        else root.launchApp(root.findApp(item.id) || item);
    }

    // Seed minimized/active state once (e.g. after a shell restart with parked windows).
    Process {
        id: windowStateSeed
        running: true
        command: ["sh", "-c", "hyprctl -j clients; echo @@; hyprctl -j activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("@@");
                try {
                    const m = {};
                    for (const c of JSON.parse(parts[0]))
                        if (c.workspace && c.workspace.name === root.minimizedWorkspace) m[root.normAddr(c.address)] = true;
                    root._minimized = m;
                } catch (e) {}
                try {
                    const aw = JSON.parse(parts[1] || "{}");
                    if (aw && aw.address) root.activeAddress = root.normAddr(aw.address);
                } catch (e) {}
                root._windowStateRevision++;
            }
        }
    }

    // Get open windows matching an application ID
    function getWindowsForApp(appId) {
        if (!appId) return [];
        const cleanId = appId.toLowerCase().replace(/\.desktop$/, "");
        return toplevels.filter(t => {
            if (!t || !t.appId) return false;
            return matchesAppId(cleanId, t.appId);
        });
    }

    // Dynamic list for the Dock: all pinned apps + any currently running apps
    // Bumped on Hyprland window events that change minimized/urgent state.
    property int _windowStateRevision: 0
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            const d = String(event.data || "");
            if (n === "movewindowv2") {                         // ADDR,WSID,WSNAME
                const f = d.split(",");
                root._setMinimized(f[0], f.slice(2).join(",") === root.minimizedWorkspace);
            } else if (n === "activewindowv2") {                // ADDR (empty when none)
                root.activeAddress = root.normAddr(d);
            } else if (n === "closewindow") {                   // ADDR
                root._setMinimized(d, false);
            }
            if (n === "urgent" || n === "movewindow" || n === "movewindowv2" || n === "workspace"
                || n === "workspacev2" || n === "activewindowv2" || n === "closewindow" || n === "openwindow"
                || n === "fullscreen") {
                root._windowStateRevision++;
                if (n === "urgent" || n === "fullscreen") Hyprland.refreshToplevels();
            }
        }
    }

    readonly property var dockApps: {
        const _rev = _entriesRevision;
        const _ws = _windowStateRevision;
        const _all = allApps;
        const list = [];
        const seen = new Set();

        // 1. Add all pinned apps (only those actually installed!)
        for (let i = 0; i < pinnedAppIds.length; i++) {
            const id = pinnedAppIds[i];
            const cleanId = id.toLowerCase().replace(/\.desktop$/, "");
            seen.add(cleanId);

            const app = findApp(cleanId);
            const wins = getWindowsForApp(cleanId);

            const hasLiveWin = wins.length > 0;
            const isLiveActive = wins.some(w => root.isActiveWindow(w) && !root.isMinimized(w));
            const minCount = wins.filter(w => root.isMinimized(w)).length;

            list.push({
                "id": cleanId,
                "name": app ? app.name : cleanId,
                "icon": app ? app.icon : cleanId,
                "exec": "",
                "desktopEntry": (app && app.execute) ? app : null,
                "pinned": true,
                "running": hasLiveWin,
                "windowCount": wins.length,
                "windows": wins,
                "isActive": isLiveActive,
                "urgent": wins.some(w => root.isUrgent(w)),
                "allMinimized": hasLiveWin && minCount === wins.length
            });
        }

        // 2. Add running apps that are not pinned
        for (let i = 0; i < toplevels.length; i++) {
            const top = toplevels[i];
            if (!top || !top.appId) continue;
            if (root.isToplevelPinned(top)) continue;
            const cleanId = top.appId.toLowerCase().replace(/\.desktop$/, "");
            if (seen.has(cleanId)) continue;
            seen.add(cleanId);

            const app = findApp(cleanId);
            const wins = getWindowsForApp(cleanId);
            list.push({
                "id": cleanId,
                "name": app ? app.name : (top.title || cleanId),
                "icon": app ? app.icon : cleanId,
                "exec": "",
                "desktopEntry": (app && app.execute) ? app : null,
                "pinned": false,
                "running": true,
                "windowCount": wins.length,
                "windows": wins,
                "isActive": wins.some(w => root.isActiveWindow(w) && !root.isMinimized(w)),
                "urgent": wins.some(w => root.isUrgent(w)),
                "allMinimized": wins.length > 0 && wins.every(w => root.isMinimized(w))
            });
        }

        return list;
    }

    // Launch or activate an app
    function activateOrLaunch(item) {
        if (!item) return;
        if (item.windows && item.windows.length > 0) {
            const activeIdx = item.windows.findIndex(w => w && w.activated);
            if (activeIdx !== -1 && item.windows.length > 1) {
                // Multiple windows: cycle through them smoothly
                const nextWin = item.windows[(activeIdx + 1) % item.windows.length];
                if (nextWin) {
                    nextWin.activate();
                    return;
                }
            }
            const target = item.windows.find(w => !w.activated) || item.windows[0];
            if (target) {
                target.activate();
                return;
            }
        }
        if (item.id === "settings") {
            ShellState.toggleSettingsApp();
            return;
        }
        if (item.desktopEntry && typeof item.desktopEntry.execute === "function") {
            item.desktopEntry.execute();
            return;
        }
        if (item.exec) {
            Hyprland.dispatch("exec " + item.exec);
            return;
        }
        Hyprland.dispatch("exec " + item.id);
    }

    function launchApp(app) {
        if (!app) return;
        if (app.id === "settings") {
            ShellState.toggleSettingsApp();
            return;
        }
        if (typeof app.execute === "function") {
            app.execute();
            return;
        }
        if (app.exec) {
            Hyprland.dispatch("exec " + app.exec);
            return;
        }
        Hyprland.dispatch("exec " + app.id);
    }
}
