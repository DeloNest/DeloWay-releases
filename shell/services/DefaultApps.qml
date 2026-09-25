pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// DefaultApps: the default application of each role (browser, terminal, file manager,
// editor, system monitor) and the alternatives offered for it.
//
// One catalog, config/default-apps.tsv, is shared with install.sh, so the installer, the
// Setup Wizard and Settings → Apps offer the same choices. Installed apps of a role that
// the catalog does not list are offered too. Choosing an app that is not installed
// installs it (pamac) and selects it once the install succeeds.
Item {
    id: root

    readonly property var roles: ["browser", "terminal", "fileManager", "editor", "monitor"]

    // freedesktop Categories= that identify an installed app of each role
    readonly property var roleCategories: ({
        "browser": "WebBrowser",
        "terminal": "TerminalEmulator",
        "fileManager": "FileManager",
        "editor": "TextEditor",
        "monitor": "Monitor"
    })

    FileView {
        id: catalogFile
        path: ConfigManager.projectDir + "/config/default-apps.tsv"
        blockLoading: true
    }

    // { role: [ { command, desktop, pkg, aur, name, isDefault } ] }
    readonly property var catalog: {
        const out = {};
        for (const r of root.roles) out[r] = [];
        for (const line of (catalogFile.text() || "").split("\n")) {
            if (!line.trim() || line.startsWith("#")) continue;
            const f = line.split("\t");
            if (f.length < 6 || !out[f[0]]) continue;
            out[f[0]].push({ command: f[1], desktop: f[2], pkg: f[3], aur: f[4] === "aur",
                             name: f[5], isDefault: (f[6] || "").trim() === "default" });
        }
        return out;
    }

    // What deloway.json holds for a role: an executable ("brave", from install.sh) or a
    // desktop id (from the wizard / Settings).
    function value(role) {
        switch (role) {
        case "browser": return ConfigManager.defaultBrowser;
        case "terminal": return ConfigManager.defaultTerminal;
        case "fileManager": return ConfigManager.defaultFileManager;
        case "editor": return ConfigManager.defaultEditor;
        case "monitor": return ConfigManager.defaultMonitor;
        }
        return "";
    }

    // Lower-case desktop id of the current choice ("" when it is not installed).
    function currentId(role) {
        return ApplicationManager.resolveAppChoice(root.value(role));
    }

    // The choices for a role: catalog apps (installed or installable), then any other
    // installed app of that kind. Each: { desktop, name, icon, pkg, aur, installed }.
    function options(role) {
        const _rev = ApplicationManager._entriesRevision;
        const list = [];
        const seen = new Set();
        for (const a of (root.catalog[role] || [])) {
            const e = DesktopEntries.byId(a.desktop);
            list.push({ desktop: a.desktop, name: e ? e.name : a.name, icon: (e && e.icon) ? e.icon : a.desktop,
                        pkg: a.pkg, aur: a.aur, installed: !!e });
            seen.add(a.desktop.toLowerCase());
        }
        const kind = root.roleCategories[role];
        const extras = Array.from(DesktopEntries.applications.values)
            .filter(e => e && e.id && !e.noDisplay && !e.runInTerminal
                    && e.categories && e.categories.indexOf(kind) >= 0
                    && !seen.has(e.id.toLowerCase()))
            .sort((x, y) => String(x.name).localeCompare(String(y.name)));
        for (const e of extras) {
            seen.add(e.id.toLowerCase());
            list.push({ desktop: e.id, name: e.name, icon: e.icon || e.id, pkg: "", aur: false, installed: true });
        }
        return list;
    }

    function isSelected(role, option) {
        return !!option && option.desktop.toLowerCase() === root.currentId(role);
    }

    // Role whose chosen app is still being installed: { role: desktop id }
    property var pending: ({})

    function choose(role, option) {
        if (!option) return;
        if (option.installed) {
            ConfigManager.setDefaultApp(role, option.desktop);
            return;
        }
        if (!option.pkg || PackageManager.isInstalling(option.desktop)) return;
        const p = Object.assign({}, root.pending);
        p[role] = option.desktop;
        root.pending = p;
        PackageManager.install(option.desktop, option.pkg, option.aur, option.name);
    }

    function isInstalling(option) {
        return !!option && PackageManager.isInstalling(option.desktop);
    }

    function installProgress(option) {
        return option ? PackageManager.getInstallProgress(option.desktop) : 0;
    }

    Connections {
        target: PackageManager
        function onInstallFinished(key, ok) {
            const p = Object.assign({}, root.pending);
            for (const role of Object.keys(p)) {
                if (p[role] !== key) continue;
                if (ok) ConfigManager.setDefaultApp(role, key);
                delete p[role];
            }
            root.pending = p;
        }
    }
}
