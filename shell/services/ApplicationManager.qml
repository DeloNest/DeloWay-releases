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

    // Dynamically registered apps (§4.3)
    property var dynamicApps: []

    function registerInstalledApp(appData) {
        if (!appData || !appData.id) return;
        const cleanId = appData.id.toLowerCase().replace(/\.desktop$/, "");
        if (dynamicApps.some(a => a.id === cleanId)) return;
        const updated = dynamicApps.concat([{
            id: cleanId,
            name: appData.name,
            icon: appData.icon || "application-x-executable",
            category: appData.category || "All",
            exec: appData.exec || cleanId,
            comment: appData.comment || appData.name
        }]);
        dynamicApps = updated;
    }

    function unregisterApp(appId) {
        if (!appId) return;
        const cleanId = appId.toLowerCase().replace(/\.desktop$/, "");
        dynamicApps = dynamicApps.filter(a => a.id !== cleanId);
    }

    // Check if an application is installed on the system
    function isInstalled(identifier) {
        if (!identifier) return false;
        const _rev = _entriesRevision;
        const cleanId = identifier.toLowerCase().replace(/\.desktop$/, "");
        if (cleanId === "settings" || cleanId === "deloway-settings"
            || cleanId === "store" || cleanId === "app-store" || cleanId === "pamac") return true;
        if (dynamicApps.some(d => d.id === cleanId)) return true;
        if (allApps && allApps.some(a => a && (
            a.id.toLowerCase().replace(/\.desktop$/, "") === cleanId ||
            a.id.toLowerCase() === identifier.toLowerCase()
        ))) return true;
        const app = DesktopEntries.byId(identifier) || DesktopEntries.byId(cleanId) || DesktopEntries.heuristicLookup(cleanId);
        return app !== null;
    }

    // Helper to find an app by ID
    function findApp(identifier) {
        if (!identifier) return null;
        const cleanId = identifier.toLowerCase().replace(/\.desktop$/, "");
        if (cleanId === "settings" || cleanId === "deloway-settings") {
            return {
                id: "settings",
                name: "Settings",
                icon: "settings",
                categories: ["System", "All"],
                comment: "DeloWay System Settings",
                execute: function() { ShellState.toggleSettingsApp(); }
            };
        }
        if (cleanId === "store" || cleanId === "app-store" || cleanId === "pamac") {
            return {
                id: "store",
                name: "App Store",
                icon: "store",
                categories: ["System", "All"],
                comment: "Install, remove and update packages with pamac",
                execute: function() { Hyprland.dispatch("exec pamac-manager"); }
            };
        }
        const dynamic = dynamicApps.find(d => d.id === cleanId);
        if (dynamic) return dynamic;
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

    // Pinned application IDs for the Dock synced with ConfigManager (strictly filtered to installed apps)
    property var pinnedAppIds: {
        const _rev = _entriesRevision;
        const configured = (ConfigManager.pinnedApps && ConfigManager.pinnedApps.length > 0)
            ? ConfigManager.pinnedApps
            : ConfigManager.defaultPinnedApps;
        return configured.filter(id => root.isInstalled(id));
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
        if (!isPinned(cleanId)) {
            const updated = pinnedAppIds.concat([cleanId]);
            pinnedAppIds = updated;
            ConfigManager.setPinnedApps(updated);
        }
    }

    // Unpin an application
    function unpinApp(appId) {
        if (!appId) return;
        const cleanId = appId.toLowerCase().replace(/\.desktop$/, "");
        if (isPinned(cleanId)) {
            const updated = pinnedAppIds.filter(id => id.toLowerCase().replace(/\.desktop$/, "") !== cleanId);
            pinnedAppIds = updated;
            ConfigManager.setPinnedApps(updated);
        }
    }

    // Toggle pin status
    function togglePin(appId) {
        if (isPinned(appId)) unpinApp(appId);
        else pinApp(appId);
    }

    // All installed applications from DesktopEntries
    readonly property var allApps: {
        const _rev = _entriesRevision;
        const raw = Array.from(DesktopEntries.applications.values);
        const seen = new Set();
        const list = [];

        // Internal DeloWay System Applications (Settings & App Store)
        list.push({
            id: "settings",
            name: "Settings",
            icon: "settings",
            categories: ["System", "All"],
            comment: "System settings and desktop configuration",
            execute: function() { ShellState.toggleSettingsApp(); }
        });
        seen.add("settings");

        // App Store backed by pamac (the real system package manager)
        list.push({
            id: "store",
            name: "App Store",
            icon: "store",
            categories: ["System", "All"],
            comment: "Install, remove and update packages with pamac",
            execute: function() { Hyprland.dispatch("exec pamac-manager"); }
        });
        seen.add("store");

        // Real installed applications registered by system tools
        for (let i = 0; i < dynamicApps.length; i++) {
            const da = dynamicApps[i];
            if (seen.has(da.id)) continue;
            seen.add(da.id);
            list.push({
                id: da.id,
                name: da.name,
                icon: da.icon,
                categories: [da.category, "All"],
                comment: da.comment || da.name,
                execute: function() { root.launchApp(da); }
            });
        }

        // All system desktop entries actually installed on disk
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
    readonly property var dockApps: {
        const _rev = _entriesRevision;
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
            const isLiveActive = wins.some(w => w.activated);

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
                "isActive": isLiveActive
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
                "isActive": wins.some(w => w.activated)
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
