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
    // A Bluetooth adapter exists (deloway-bluetooth.py list → /sys/class/bluetooth). False
    // until the first answer, so Bluetooth never shows up and then vanishes at startup.
    property bool available: false
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
                    root.available = parsed.available !== undefined ? !!parsed.available : true;
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

    // ── Actions: one queue, one process, real results ───────────────────────
    // Each action runs to completion before the next starts (starting a busy Process
    // silently dropped or mixed up requests), and its JSON result is read: failures
    // (device off, PIN needed, timeout) surface in `error` instead of vanishing.
    readonly property string helper: ConfigManager.projectDir + "/scripts/deloway-bluetooth.py"
    property var _queue: []
    property var _current: null

    function _enqueue(verb, address) {
        root._queue = root._queue.concat([{ verb: verb, address: address || "" }]);
        if (!actionProc.running) root._next();
    }
    function _next() {
        if (root._queue.length === 0) return;
        const job = root._queue[0];
        root._queue = root._queue.slice(1);
        root._current = job;
        if (job.verb === "connect") root.connectingAddress = job.address;
        if (job.verb === "scan") root.isScanning = true;
        actionProc.command = job.address ? ["python3", root.helper, job.verb, job.address]
                                         : ["python3", root.helper, job.verb];
        actionProc.running = true;
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null;
                try { r = JSON.parse(this.text); } catch (e) { r = { success: false, error: this.text.trim() }; }
                // Translated, with the helper's detail (BlueZ error) isolated after it
                const d = (r.error || "").trim();
                root.error = r.success ? "" : I18n.uiLine(I18n.tr("bt_action_failed") + (d ? " — " + I18n.isolate(d) : ""));
            }
        }
        onExited: (code) => {
            const job = root._current;
            if (job && job.verb === "connect") root.connectingAddress = "";
            if (job && job.verb === "scan") root.isScanning = false;
            root._current = null;
            root.refresh();
            root._next();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API Methods
    // ─────────────────────────────────────────────────────────────────────────

    function refresh() {
        statusProc.running = true;
    }

    function togglePower() {
        root.powered = !root.powered;          // optimistic; refresh() corrects it
        root._enqueue("toggle");
    }
    function scan() { root._enqueue("scan"); }
    function connectDevice(address) { if (address) root._enqueue("connect", address); }
    function disconnectDevice(address) { if (address) root._enqueue("disconnect", address); }
    function pairDevice(address) { if (address) root._enqueue("pair", address); }
    function removeDevice(address) { if (address) root._enqueue("remove", address); }

    // Periodic & Lifecycle
    Component.onCompleted: {
        root.refresh();
    }
}
