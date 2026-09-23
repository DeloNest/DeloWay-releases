pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Item {
    id: root

    // Signals for application lifecycle
    signal appInstalled(string appId)
    signal appUninstalled(string appId)
    signal installProgress(string appId, real progress, string statusText)
    signal updatesChecked(int count)

    // Curated catalog of essential utilities used by SetupWizard
    readonly property var rawCatalog: [
        {
            "id": "thunar",
            "package": "thunar",
            "name": "Thunar File Manager",
            "summary": "Modern, fast, and lightweight file manager",
            "category": "System",
            "icon": "system-file-manager"
        },
        {
            "id": "org.gnome.TextEditor",
            "package": "gnome-text-editor",
            "name": "GNOME Text Editor",
            "summary": "Clean, modern text and code editor",
            "category": "Utility",
            "icon": "text-editor"
        },
        {
            "id": "pwvucontrol",
            "package": "pwvucontrol",
            "name": "PipeWire Volume Control",
            "summary": "Full audio device and volume mixer",
            "category": "AudioVideo",
            "icon": "audio-card"
        },
        {
            "id": "io.missioncenter.MissionCenter",
            "package": "mission-center",
            "name": "Mission Center",
            "summary": "Real-time hardware and resource monitor",
            "category": "System",
            "icon": "utilities-system-monitor"
        }
    ]

    // Lookup full app record by ID
    function getApp(appId) {
        if (!appId) return null;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        // Catalog ids are mixed-case (org.gnome.TextEditor); callers pass lower-case ids.
        return rawCatalog.find(a => a.id.toLowerCase() === clean) || null;
    }

    // Dynamic catalog view enriched with live installation flags
    readonly property var catalog: {
        return rawCatalog.map(app => {
            const copy = Object.assign({}, app);
            copy.installed = root.isInstalled(app.id);
            copy.isInstalling = root.isInstalling(app.id);
            copy.progress = root.getInstallProgress(app.id);
            copy.statusText = root.getInstallStatus(app.id);
            copy.hasUpdate = root.updatableIds.includes(app.id);
            return copy;
        });
    }

    // State tracking
    property var installedIds: []
    property var updatableIds: []
    property var installingMap: ({})

    function isInstalled(appId) {
        if (!appId) return false;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        if (installedIds.includes(clean)) return true;
        return ApplicationManager.isInstalled(clean);
    }

    function isInstalling(appId) {
        if (!appId) return false;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return Boolean(installingMap[clean]);
    }

    function getInstallProgress(appId) {
        if (!appId) return 0.0;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return installingMap[clean] ? (installingMap[clean].progress || 0.0) : 0.0;
    }

    function getInstallStatus(appId) {
        if (!appId) return "";
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return installingMap[clean] ? (installingMap[clean].status || "") : "";
    }

    // Queue of pending installs: [ { appId: string, pkg: string, provider: string } ]
    property var installQueue: []

    // Real Process Wrapper for pamac / pacman
    Process {
        id: installProc
        property string activeAppId: ""
        property string activePkg: ""
        property string activeProvider: "native"

        stdout: SplitParser {
            onRead: function(data) {
                root.parseProcessOutput(installProc.activeAppId, data);
            }
        }
        stderr: SplitParser {
            onRead: function(data) {
                root.parseProcessOutput(installProc.activeAppId, data);
            }
        }
        onExited: function(exitCode, exitStatus) {
            const currentId = installProc.activeAppId;
            installProc.activeAppId = "";
            installProc.activePkg = "";
            installProc.activeProvider = "native";

            const newMap = Object.assign({}, root.installingMap);
            delete newMap[currentId];
            root.installingMap = newMap;

            if (exitCode === 0) {
                root.completeInstallation(currentId);
            } else {
                console.warn("[PackageManager] Installation failed for " + currentId + " with exit code " + exitCode);
                NotificationManager.postNotification(
                    "System",
                    "Installation Failed",
                    "Failed to install package for " + currentId + " (code " + exitCode + ")",
                    "dialog-error"
                );
            }

            root.processNextQueueItem();
        }
    }

    function parseProcessOutput(appId, line) {
        if (!appId || !line) return;
        const text = line.trim();
        if (text.length === 0) return;

        let progress = root.getInstallProgress(appId);
        let status = root.getInstallStatus(appId) || "Processing...";

        const percentMatch = text.match(/(\d+)%/);
        if (percentMatch) {
            const pct = parseInt(percentMatch[1], 10);
            if (!isNaN(pct)) {
                progress = Math.min(0.98, Math.max(0.05, pct / 100.0));
            }
        }

        if (text.includes("downloading") || text.includes("Retrieving packages")) {
            status = "Downloading package...";
            if (!percentMatch) progress = Math.max(progress, 0.20);
        } else if (text.includes("checking keys") || text.includes("checking package integrity") || text.includes("verifying")) {
            status = "Verifying package integrity...";
            if (!percentMatch) progress = Math.max(progress, 0.50);
        } else if (text.includes("checking for file conflicts") || text.includes("checking available disk space")) {
            status = "Checking dependencies...";
            if (!percentMatch) progress = Math.max(progress, 0.65);
        } else if (text.includes("installing") || text.includes("installing ") || text.includes("Processing package changes")) {
            status = "Installing binaries...";
            if (!percentMatch) progress = Math.max(progress, 0.80);
        } else if (text.includes("running post-transaction hooks")) {
            status = "Finalizing configuration...";
            progress = 0.95;
        }

        const newMap = Object.assign({}, root.installingMap);
        newMap[appId] = { progress: progress, status: status };
        root.installingMap = newMap;
        root.installProgress(appId, progress, status);
    }

    function processNextQueueItem() {
        if (installProc.running || installQueue.length === 0) return;
        const item = installQueue[0];
        installQueue = installQueue.slice(1);

        installProc.activeAppId = item.appId;
        installProc.activePkg = item.pkg;
        installProc.activeProvider = item.provider;

        installProc.command = ["env", "LC_ALL=C", "pamac", "install", "--no-confirm", item.pkg];
        installProc.running = true;
    }

    function installApp(appId, provider) {
        provider = provider || "native";
        if (!appId || isInstalled(appId) || isInstalling(appId)) return;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        const app = getApp(clean);
        if (!app) {
            NotificationManager.postNotification("System", I18n.isRTL ? "تعذّر التثبيت" : "Installation Failed",
                (I18n.isRTL ? "تطبيق غير معروف: " : "Unknown application: ") + appId, "dialog-warning-symbolic");
            return;
        }

        const pkgName = app.package || clean;

        const newMap = Object.assign({}, root.installingMap);
        newMap[clean] = { progress: 0.05, status: "Starting installation..." };
        root.installingMap = newMap;
        root.installProgress(clean, 0.05, "Starting installation...");

        installQueue = installQueue.concat([{
            appId: clean,
            pkg: pkgName,
            provider: provider
        }]);

        processNextQueueItem();
    }

    function completeInstallation(cleanId) {
        if (!installedIds.includes(cleanId)) {
            installedIds = installedIds.concat([cleanId]);
        }

        const app = getApp(cleanId);
        if (app) {
            ApplicationManager.registerInstalledApp({
                id: app.id,
                name: app.name,
                icon: app.icon,
                category: app.category,
                exec: app.id,
                comment: app.summary
            });

            NotificationManager.postNotification(
                "System",
                app.name + " Installed",
                "The application has been installed successfully and is ready to launch.",
                app.icon
            );

            root.appInstalled(cleanId);
        }
    }

    function uninstallApp(appId) {
        if (!appId || !isInstalled(appId)) return;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        const app = getApp(clean);

        installedIds = installedIds.filter(id => id !== clean);
        updatableIds = updatableIds.filter(id => id !== clean);

        if (ApplicationManager.isPinned(clean)) {
            ApplicationManager.unpinApp(clean);
        }

        ApplicationManager.unregisterApp(clean);

        if (app) {
            NotificationManager.postNotification(
                "System",
                app.name + " Uninstalled",
                "The application has been removed from your system.",
                app.icon
            );
        }

        root.appUninstalled(clean);
        console.log("[PackageManager] Successfully uninstalled app:", clean);
    }
}
