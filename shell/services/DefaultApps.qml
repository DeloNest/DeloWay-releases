pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// DefaultApps: the default application of each role (browser, terminal, file manager,
// editor, system monitor, and by file type: images, videos, PDFs) and the alternatives
// offered for it.
//
// One catalog, config/default-apps.tsv, is shared with install.sh, so the installer, the
// Setup Wizard and Settings → Apps offer the same choices. Installed apps of a role that
// the catalog does not list are offered too. Choosing an app that is not installed
// installs it (pamac) and selects it once the install succeeds.
Item {
    id: root

    readonly property var roles: ["browser", "terminal", "fileManager", "editor", "monitor", "image", "video", "pdf"]
    // Defaults by file type: the real current app is read from the system (xdg-mime), the
    // installed apps come from their MimeType= (scripts/deloway-default-app.py), and the
    // browser is offered as a choice too.
    readonly property var fileTypeRoles: ["image", "video", "pdf"]
    function isFileTypeRole(role) { return root.fileTypeRoles.indexOf(role) >= 0; }
    readonly property string helper: ConfigManager.projectDir + "/scripts/deloway-default-app.py"

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
        case "image": return ConfigManager.defaultImageViewer;
        case "video": return ConfigManager.defaultVideoPlayer;
        case "pdf": return ConfigManager.defaultPdfViewer;
        }
        return "";
    }

    // Lower-case desktop id of the current choice ("" when it is not installed). For file
    // types: what the system opens them with now, "@browser" when that is the browser.
    function currentId(role) {
        if (root.isFileTypeRole(role)) {
            const cur = String((root.fileStatus.current || {})[role] || "").toLowerCase();
            return (cur && cur === root.browserId()) ? "@browser" : cur;
        }
        return ApplicationManager.resolveAppChoice(root.value(role));
    }

    function browserEntry() { return ApplicationManager.resolveAppEntry(ConfigManager.defaultBrowser); }
    function browserId() {
        const e = root.browserEntry();
        return e ? e.id.replace(/\.desktop$/, "").toLowerCase() : "";
    }

    // The choices for a role: catalog apps (installed or installable), then any other
    // installed app of that kind. Each: { desktop, name, icon, pkg, aur, installed }.
    function options(role) {
        const _rev = ApplicationManager._entriesRevision;
        const list = [];
        const seen = new Set();
        if (root.isFileTypeRole(role)) seen.add(root.browserId());   // offered as "Browser" below
        for (const a of (root.catalog[role] || [])) {
            const e = DesktopEntries.byId(a.desktop);
            list.push({ desktop: a.desktop, name: e ? e.name : a.name, icon: (e && e.icon) ? e.icon : a.desktop,
                        pkg: a.pkg, aur: a.aur, installed: !!e });
            seen.add(a.desktop.toLowerCase());
        }
        const kind = root.roleCategories[role];
        const typeApps = (root.fileStatus.apps || {})[role] || [];
        const extras = Array.from(DesktopEntries.applications.values)
            .filter(e => e && e.id && !e.noDisplay && !e.runInTerminal
                    && (root.isFileTypeRole(role) ? typeApps.indexOf(e.id) >= 0
                                                  : (e.categories && e.categories.indexOf(kind) >= 0))
                    && !seen.has(e.id.toLowerCase()))
            .sort((x, y) => String(x.name).localeCompare(String(y.name)));
        for (const e of extras) {
            seen.add(e.id.toLowerCase());
            list.push({ desktop: e.id, name: e.name, icon: e.icon || e.id, pkg: "", aur: false, installed: true });
        }
        const browser = root.browserEntry();
        if (root.isFileTypeRole(role) && browser) {
            list.push({ desktop: "@browser", name: I18n.tr("default_app_in_browser").replace("%1", browser.name),
                        icon: browser.icon || browser.id, pkg: "", aur: false, installed: true });
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

    // ── By file type ──────────────────────────────────────────────────────
    property var fileStatus: ({ apps: {}, current: {} })

    function refreshFileStatus() {
        if (!statusProc.running) statusProc.running = true;
        else statusRefresh.restart();
    }
    Process {
        id: statusProc
        command: ["python3", root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.fileStatus = JSON.parse(text); } catch (e) { return; }
                root._firstRunDefaults();
            }
        }
    }
    Timer { id: statusRefresh; interval: 800; onTriggered: root.refreshFileStatus() }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { statusRefresh.restart(); }   // an app was (un)installed
    }
    Component.onCompleted: root.refreshFileStatus()

    // One xdg-mime change at a time; the status is re-read after the last.
    property var _applyQueue: []
    function applyFileType(role, id) {
        let app = id;
        let web = false;
        if (id === "@browser") {
            app = root.browserId();
            web = true;
        }
        if (!app) return;
        root._applyQueue = root._applyQueue.concat([["python3", root.helper, "set", role, app].concat(web ? ["--web"] : [])]);
        root._applyNext();
    }
    function _applyNext() {
        if (applyProc.running || root._applyQueue.length === 0) return;
        applyProc.command = root._applyQueue[0];
        root._applyQueue = root._applyQueue.slice(1);
        applyProc.running = true;
    }
    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (!r.ok) console.warn("[DefaultApps] could not set the default:", text.trim());
                } catch (e) {}
            }
        }
        onExited: {
            if (root._applyQueue.length > 0) root._applyNext();
            else root.refreshFileStatus();
        }
    }

    // First run of the by-type defaults: the catalog defaults that are installed become
    // the defaults (images opened in the browser only because nothing else was set), and
    // scripts / source files go to the text editor. Roles whose default is not installed
    // yet stay empty and are set when it is installed from Settings.
    function _firstRunDefaults() {
        if (ConfigManager.fileTypeDefaultsApplied) return;
        for (const role of root.fileTypeRoles) {
            if (root.value(role)) continue;
            const def = (root.catalog[role] || []).find(a => a.isDefault);
            const installed = ((root.fileStatus.apps || {})[role] || []).indexOf(def ? def.desktop : "") >= 0;
            if (installed) ConfigManager.setDefaultApp(role, def.desktop);
        }
        ConfigManager.setDefaultApp("editor", ConfigManager.defaultEditor);
        ConfigManager.setFileTypeDefaultsApplied();
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
