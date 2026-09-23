pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Reactive Properties
    // ─────────────────────────────────────────────────────────────────────────
    property var bluetoothData: null
    property bool available: true
    property bool powered: false
    property bool isScanning: false
    property var devices: []
    property var pairedDevices: []
    property var availableDevices: []
    property string connectedDeviceName: ""
    property string connectingAddress: ""
    property string error: ""

    function sortedBluetoothDevices(devs) {
        if (!devs || !Array.isArray(devs)) return [];
        return devs.slice().sort((a, b) => {
            if (a.connected && !b.connected) return -1;
            if (!a.connected && b.connected) return 1;
            if (a.paired && !b.paired) return -1;
            if (!a.paired && b.paired) return 1;
            return (a.name || "").localeCompare(b.name || "");
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Backend Processes
    // ─────────────────────────────────────────────────────────────────────────

    // Status process (list)
    Process {
        id: statusProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "list"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.bluetoothData = parsed;
                    root.error = "";
                    root.powered = !!parsed.powered;
                    const allDevs = parsed.devices || [];
                    root.devices = root.sortedBluetoothDevices(allDevs);

                    const paired = [];
                    const avail = [];
                    let connectedName = "";

                    for (let i = 0; i < allDevs.length; i++) {
                        const d = allDevs[i];
                        if (d.connected) {
                            connectedName = d.name || d.address;
                        }
                        if (d.paired || d.connected) {
                            paired.push(d);
                        } else {
                            avail.push(d);
                        }
                    }

                    root.pairedDevices = root.sortedBluetoothDevices(paired);
                    root.availableDevices = root.sortedBluetoothDevices(avail);
                    root.connectedDeviceName = connectedName;
                } catch (e) {
                    root.error = I18n.isRTL ? "تعذر قراءة بيانات البلوتوث" : "Failed to parse bluetooth data";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = I18n.isRTL ? "تعذر جلب بيانات البلوتوث" : "Failed to fetch bluetooth data";
            }
        }
    }

    // Toggle power process
    Process {
        id: toggleProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "toggle"]
        onExited: root.refresh()
    }

    // Scan process
    Process {
        id: scanProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "scan"]
        onStarted: root.isScanning = true
        onExited: {
            root.isScanning = false;
            root.refresh();
        }
    }

    // Connect process
    Process {
        id: connectProc
        onExited: {
            root.connectingAddress = "";
            root.refresh();
        }
    }

    // Disconnect process
    Process {
        id: disconnectProc
        onExited: root.refresh()
    }

    // Pair process
    Process {
        id: pairProc
        onExited: root.refresh()
    }

    // Remove / Unpair process
    Process {
        id: removeProc
        onExited: root.refresh()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API Methods
    // ─────────────────────────────────────────────────────────────────────────

    function refresh() {
        statusProc.running = true;
    }

    function togglePower() {
        const next = !root.powered;
        toggleProc.running = true;
        root.powered = next;
    }

    function scan() {
        scanProc.running = true;
    }

    function connectDevice(address) {
        if (!address) return;
        root.connectingAddress = address;
        connectProc.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "connect", address];
        connectProc.running = true;
    }

    function disconnectDevice(address) {
        if (!address) return;
        disconnectProc.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "disconnect", address];
        disconnectProc.running = true;
    }

    function pairDevice(address) {
        if (!address) return;
        pairProc.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "pair", address];
        pairProc.running = true;
    }

    function removeDevice(address) {
        if (!address) return;
        removeProc.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "remove", address];
        removeProc.running = true;
    }

    // Periodic & Lifecycle
    Component.onCompleted: {
        root.refresh();
    }
}
