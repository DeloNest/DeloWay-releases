pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    // Local Device Properties
    property string localAlias: "Deloway"
    property string localIp: "127.0.0.1"
    property string hostname: ""
    property int port: 53317
    property bool isRunning: false
    property var favorites: []

    // Network Discovery State
    property var discoveredDevices: []
    property var allDevices: []
    property var selectedDevice: null
    property bool isScanning: false
    property bool isSending: false
    property real sendProgress: 0.0
    property string sendStatus: "idle"
    property string lastSendError: ""
    property string currentSendingFile: ""

    readonly property string helperScript: ConfigManager.projectDir + "/scripts/deloway-localsend.py"

    signal filesStaged(var files)
    signal resetRequested()

    function resetStage() {
        resetRequested();
    }

    function stageFiles(files) {
        if (!files || files.length === 0) return;
        const clean = [];
        for (let i = 0; i < files.length; i++) {
            let p = String(files[i] || "");
            if (p.startsWith("file://")) {
                p = decodeURIComponent(p.substring(7));
            }
            clean.push(p);
        }
        filesStaged(clean);
    }

    function getDefaultDevice() {
        if (!allDevices || allDevices.length === 0) return null;
        for (let i = 0; i < allDevices.length; i++) {
            if (allDevices[i].isFavorite) return allDevices[i];
        }
        return allDevices[0];
    }

    function selectDevice(device) {
        root.selectedDevice = device;
    }

    function updateAllDevices() {
        const map = {};
        // 1. Add favorites
        if (Array.isArray(root.favorites)) {
            for (let i = 0; i < root.favorites.length; i++) {
                const fav = root.favorites[i];
                const key = fav.id || fav.ip || fav.alias;
                map[key] = Object.assign({}, fav, { isFavorite: true });
            }
        }
        // 2. Merge discovered
        if (Array.isArray(root.discoveredDevices)) {
            for (let i = 0; i < root.discoveredDevices.length; i++) {
                const dev = root.discoveredDevices[i];
                const key = dev.id || dev.ip || dev.alias;
                if (map[key]) {
                    map[key] = Object.assign(map[key], dev, { isFavorite: true });
                } else {
                    map[key] = dev;
                }
            }
        }
        const merged = Object.values(map);
        merged.sort((a, b) => {
            if (a.isFavorite && !b.isFavorite) return -1;
            if (!a.isFavorite && b.isFavorite) return 1;
            if (a.isOnline && !b.isOnline) return -1;
            if (!a.isOnline && b.isOnline) return 1;
            return 0;
        });
        root.allDevices = merged;

        // Auto-select if no selection or previous selection is gone
        if (!root.selectedDevice && merged.length > 0) {
            root.selectedDevice = root.getDefaultDevice();
        } else if (root.selectedDevice && merged.length > 0) {
            const selKey = root.selectedDevice.id || root.selectedDevice.ip;
            const updated = merged.find(d => (d.id && d.id === selKey) || (d.ip && d.ip === selKey));
            if (updated) {
                root.selectedDevice = updated;
            }
        }
    }

    // ── Status Inspector Process ─────────────────────────────────────────────
    Process {
        id: statusProcess
        command: ["python3", root.helperScript, "status"]

        stdout: SplitParser {
            onRead: function(data) {
                try {
                    const info = JSON.parse(data.trim());
                    if (info.alias) root.localAlias = info.alias;
                    if (info.ip) root.localIp = info.ip;
                    if (info.hostname) root.hostname = info.hostname;
                    if (info.port) root.port = info.port;
                    root.isRunning = !!info.isRunning;
                    if (info.favorites) {
                        root.favorites = info.favorites;
                        root.updateAllDevices();
                    }
                } catch (e) {
                    // ignore partial or malformed chunk
                }
            }
        }
    }

    // ── Discovery Process ───────────────────────────────────────────────────
    Process {
        id: discoverProcess
        command: ["python3", root.helperScript, "discover"]

        stdout: SplitParser {
            onRead: function(data) {
                try {
                    const list = JSON.parse(data.trim());
                    if (Array.isArray(list)) {
                        root.discoveredDevices = list;
                        root.updateAllDevices();
                    }
                } catch (e) {
                    // ignore
                }
            }
        }

        onExited: {
            root.isScanning = false;
        }
    }

    // ── Launch Process ──────────────────────────────────────────────────────
    Process {
        id: launchProcess
        command: ["python3", root.helperScript, "launch"]
        onExited: {
            statusTimer.restart();
        }
    }

    // ── Send Process ────────────────────────────────────────────────────────
    Process {
        id: sendProcess

        stdout: SplitParser {
            onRead: function(data) {
                const lines = data.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;
                    try {
                        const ev = JSON.parse(line);
                        if (ev.type === "connecting") {
                            root.sendStatus = "connecting";
                        } else if (ev.type === "progress") {
                            root.sendStatus = "sending";
                            root.sendProgress = ev.progress !== undefined ? ev.progress : 0.0;
                            if (ev.file) root.currentSendingFile = ev.file;
                        } else if (ev.type === "sent") {
                            root.sendStatus = "sent";
                            root.sendProgress = 1.0;
                            root.isSending = false;
                        } else if (ev.type === "failed") {
                            root.sendStatus = "failed";
                            root.lastSendError = root.failureText(ev.error);
                            root.isSending = false;
                        }
                    } catch (e) {
                        // ignore malformed chunk
                    }
                }
            }
        }

        onExited: {
            root.isSending = false;
            if (root.sendStatus === "sending" || root.sendStatus === "connecting") {
                root.sendStatus = "failed";
                if (!root.lastSendError) {
                    root.lastSendError = root.failureText(I18n.tr("ls_err_exited"));
                }
            }
        }
    }

    // Status is only shown on the Notch "Share" tab (index 2): poll and scan only while
    // it is on screen, instead of forking the helper every 3 s for the whole session.
    readonly property bool panelVisible: ShellState.smartNotchExpanded && ShellState.smartNotchTab === 2
    onPanelVisibleChanged: if (panelVisible) root.scanNetwork()

    // Periodic status refresh
    Timer {
        id: statusTimer
        interval: 3000
        running: root.panelVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshStatus();
        }
    }

    // ── Public API ──────────────────────────────────────────────────────────
    function refreshStatus() {
        if (!statusProcess.running) {
            statusProcess.exec(["python3", root.helperScript, "status"]);
        }
    }

    function scanNetwork() {
        if (!discoverProcess.running) {
            root.isScanning = true;
            discoverProcess.exec(["python3", root.helperScript, "discover"]);
        }
    }

    function startLocalSend() {
        if (!launchProcess.running) {
            launchProcess.exec(["python3", root.helperScript, "launch"]);
        }
    }

    function resetSendState() {
        root.isSending = false;
        root.sendProgress = 0.0;
        root.sendStatus = "idle";
        root.lastSendError = "";
        root.currentSendingFile = "";
    }

    // The failure line under a transfer: translated, with the helper's own detail (if
    // any) isolated after it so it still helps diagnose without breaking the Arabic line.
    function failureText(detail) {
        const d = (detail || "").trim();
        return I18n.uiLine(I18n.tr("ls_err_failed") + (d ? " — " + I18n.isolate(d) : ""));
    }

    function sendFiles(files, device) {
        if (!files || files.length === 0) return;
        const target = device || root.selectedDevice || root.getDefaultDevice();
        if (!target) {
            root.sendStatus = "failed";
            root.lastSendError = I18n.tr("ls_err_no_device");
            return;
        }

        const targetIp = target.ip;
        const targetPort = String(target.port || root.port || 53317);

        const cleanPaths = [];
        for (let i = 0; i < files.length; i++) {
            let p = String(files[i] || "");
            if (p.startsWith("file://")) {
                p = decodeURIComponent(p.substring(7));
            }
            cleanPaths.push(p);
        }

        root.isSending = true;
        root.sendProgress = 0.0;
        root.sendStatus = "connecting";
        root.lastSendError = "";
        root.currentSendingFile = "";

        const cmd = ["python3", root.helperScript, "send", targetIp, targetPort].concat(cleanPaths);
        sendProcess.exec(cmd);
    }

    Component.onCompleted: root.refreshStatus()   // one status read; the subnet scan waits for the Share tab
}
