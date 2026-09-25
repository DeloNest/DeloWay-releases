pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// PackageManager: installs packages through pamac (polkit prompt, repo and AUR), one at a
// time, with live progress. Callers name what they install with a key (the desktop id of
// the app it provides) and get installFinished(key, ok) back. Used by DefaultApps
// (Setup Wizard, Settings → Apps); uninstalling lives in AppActions.
Item {
    id: root

    signal installFinished(string key, bool ok)

    // pamac is the only package front end the shell drives (install.sh installs pamac-aur).
    property bool available: false
    Process {
        running: true
        command: ["sh", "-c", "command -v pamac"]
        onExited: (code) => root.available = (code === 0)
    }

    // key → { progress: 0..1, status: string }
    property var installingMap: ({})
    // Queue of pending installs: [ { key, pkg, aur, name } ]
    property var installQueue: []

    function isInstalling(key) {
        return !!key && Boolean(installingMap[key]);
    }

    function getInstallProgress(key) {
        return (key && installingMap[key]) ? (installingMap[key].progress || 0.0) : 0.0;
    }

    function getInstallStatus(key) {
        return (key && installingMap[key]) ? (installingMap[key].status || "") : "";
    }

    function _setState(key, progress, status) {
        const m = Object.assign({}, root.installingMap);
        if (progress < 0) delete m[key];
        else m[key] = { progress: progress, status: status };
        root.installingMap = m;
    }

    // Install `pkg` (from the AUR when `aur`), tracked as `key`; `name` is for messages.
    function install(key, pkg, aur, name) {
        if (!key || !pkg || root.isInstalling(key)) return;
        if (!root.available) {
            NotificationManager.postNotification("DeloWay", I18n.tr("install_failed_title"),
                I18n.tr("install_no_pamac").replace("%1", I18n.isolate(pkg)), "dialog-warning-symbolic");
            root.installFinished(key, false);
            return;
        }
        root._setState(key, 0.05, I18n.tr("install_state_starting"));
        root.installQueue = root.installQueue.concat([{ key: key, pkg: pkg, aur: !!aur, name: name || pkg }]);
        root.processNextQueueItem();
    }

    Process {
        id: installProc
        property var job: null

        stdout: SplitParser { onRead: (data) => root.parseProcessOutput(installProc.job, data) }
        stderr: SplitParser { onRead: (data) => root.parseProcessOutput(installProc.job, data) }

        onExited: (exitCode) => {
            const job = installProc.job;
            installProc.job = null;
            if (!job) return;
            root._setState(job.key, -1, "");

            if (exitCode === 0) {
                // The desktop entry reaches the Dock, App Drawer and search through
                // DesktopEntries' own rescan.
                NotificationManager.postNotification("DeloWay", I18n.tr("install_done_title"),
                    I18n.tr("install_done_body").replace("%1", I18n.isolate(job.name)), job.key);
            } else {
                console.warn("[PackageManager] Installing " + job.pkg + " failed (exit " + exitCode + ")");
                NotificationManager.postNotification("DeloWay", I18n.tr("install_failed_title"),
                    I18n.tr("install_failed_body").replace("%1", I18n.isolate(job.name)), "dialog-error-symbolic");
            }
            root.installFinished(job.key, exitCode === 0);
            root.processNextQueueItem();
        }
    }

    function parseProcessOutput(job, line) {
        if (!job || !line) return;
        const text = line.trim();
        if (text.length === 0) return;

        let progress = root.getInstallProgress(job.key);
        let status = root.getInstallStatus(job.key);

        const percentMatch = text.match(/(\d+)%/);
        if (percentMatch) {
            const pct = parseInt(percentMatch[1], 10);
            if (!isNaN(pct)) progress = Math.min(0.98, Math.max(0.05, pct / 100.0));
        }

        if (text.includes("downloading") || text.includes("Retrieving packages") || text.includes("Cloning")) {
            status = I18n.tr("install_state_downloading");
            if (!percentMatch) progress = Math.max(progress, 0.20);
        } else if (text.includes("Building") || text.includes("==> Making package")) {
            status = I18n.tr("install_state_building");
            if (!percentMatch) progress = Math.max(progress, 0.40);
        } else if (text.includes("checking keys") || text.includes("checking package integrity") || text.includes("verifying")) {
            status = I18n.tr("install_state_verifying");
            if (!percentMatch) progress = Math.max(progress, 0.60);
        } else if (text.includes("installing") || text.includes("Processing package changes")) {
            status = I18n.tr("install_state_installing");
            if (!percentMatch) progress = Math.max(progress, 0.80);
        } else if (text.includes("running post-transaction hooks")) {
            status = I18n.tr("install_state_finishing");
            progress = 0.95;
        }
        root._setState(job.key, progress, status);
    }

    function processNextQueueItem() {
        if (installProc.running || installQueue.length === 0) return;
        const job = installQueue[0];
        installQueue = installQueue.slice(1);
        installProc.job = job;
        // pamac build: AUR packages; pamac install: repositories.
        installProc.command = ["env", "LC_ALL=C", "pamac", job.aur ? "build" : "install", "--no-confirm", job.pkg];
        installProc.running = true;
    }
}
