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
    property bool isScanning: false
    property bool isSending: false
    property string lastSendError: ""

    readonly property string helperScript: ConfigManager.projectDir + "/scripts/deloway-localsend.py"

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
                    if (info.favorites) root.favorites = info.favorites;
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
            // refresh status shortly after launch
            statusTimer.restart();
        }
    }

    // ── Send Process ────────────────────────────────────────────────────────
    Process {
        id: sendProcess
        onExited: {
            root.isSending = false;
        }
    }

    // Periodic status refresh
    Timer {
        id: statusTimer
        interval: 3000
        running: true
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

    function sendFiles(files) {
        if (!files || files.length === 0) return;
        const cleanPaths = [];
        for (let i = 0; i < files.length; i++) {
            let p = files[i];
            if (p.startsWith("file://")) {
                p = decodeURIComponent(p.substring(7));
            }
            cleanPaths.push(p);
        }

        root.isSending = true;
        const cmd = ["python3", root.helperScript, "send"].concat(cleanPaths);
        sendProcess.exec(cmd);
    }

    Component.onCompleted: {
        root.refreshStatus();
    }
}
