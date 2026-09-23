pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Active ONLY while the System tab of the expanded TimeCapsule is on screen.
    readonly property bool active: ShellState.timeCapsuleExpanded
                                   && ShellState.timeCapsuleTab === 1
                                   && ConfigManager.timeCapsuleShowHardware

    // Real-time Metrics
    property real cpuUsage: 0.0
    property string cpuPercentText: "—"
    property var cpuTemp: null
    property string cpuTempText: "—"

    property real ramUsage: 0.0
    property string ramPercentText: "—"
    property string ramText: "—"

    property bool hasGpu: false
    property var gpuUsage: null
    property string gpuPercentText: "—"
    property var gpuTemp: null
    property string gpuTempText: "—"
    property string gpuVramText: "—"

    // GPU extras (NVIDIA only; null elsewhere)
    property string gpuName: ""
    property var gpuPower: null      // watts
    property var gpuClock: null      // MHz
    property var gpuVramUsed: null   // GB
    property var gpuVramTotal: null  // GB

    // CPU extras
    property var cores: []           // per-logical-CPU load, 0..100
    property var cpuFreq: null       // average MHz
    property var loadAvg: [0, 0, 0]
    property int runningTasks: 0
    property int totalTasks: 0

    // RAM (numeric)
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    // Storage (root filesystem) + NVMe temperature
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property real diskUsage: 0.0
    property var nvmeTemp: null

    // Network throughput (bytes/second, physical interfaces only)
    property real netRx: 0
    property real netTx: 0
    property string netIface: ""

    // System
    property int uptimeSec: 0
    property string kernel: ""
    property var topProcs: []        // [{ name, cpu }] — cpu in htop convention (100 = one core)

    // 30-sample history arrays for sparklines (~60 seconds at 2s intervals)
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property var netRxHistory: []
    property var netTxHistory: []

    // ── Formatting helpers (shared by every telemetry surface) ──
    function formatRate(bytesPerSec) {
        const b = Math.max(0, bytesPerSec || 0);
        if (b >= 1048576) return (b / 1048576).toFixed(b >= 10485760 ? 0 : 1) + " MB/s";
        if (b >= 1024) return (b / 1024).toFixed(b >= 10240 ? 0 : 1) + " KB/s";
        return Math.round(b) + " B/s";
    }

    function formatUptime(sec, rtl) {
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const U = rtl ? { d: "ي", h: "س", m: "د" } : { d: "d", h: "h", m: "m" };
        if (d > 0) return d + U.d + " " + h + U.h;
        if (h > 0) return h + U.h + " " + m + U.m;
        return m + U.m;
    }

    function pushHistory(arr, val, maxLen) {
        var a = (arr && arr.slice) ? arr.slice() : [];
        a.push(val);
        if (a.length > maxLen) {
            a.shift();
        }
        return a;
    }

    function parseTelemetry(line) {
        if (!line || line.trim().length === 0) return;
        try {
            var d = JSON.parse(line.trim());

            // CPU
            if (d.cpu !== undefined) {
                var c = Math.max(0.0, Math.min(1.0, d.cpu / 100.0));
                root.cpuUsage = c;
                root.cpuPercentText = Math.round(d.cpu) + "%";
                root.cpuHistory = pushHistory(root.cpuHistory, c, 30);
            }
            if (d.cpuTemp !== undefined && d.cpuTemp !== null) {
                root.cpuTemp = d.cpuTemp;
                root.cpuTempText = Math.round(d.cpuTemp) + "°C";
            } else {
                root.cpuTemp = null;
                root.cpuTempText = "—";
            }

            // RAM
            if (d.ramPercent !== undefined) {
                var r = Math.max(0.0, Math.min(1.0, d.ramPercent / 100.0));
                root.ramUsage = r;
                root.ramPercentText = Math.round(d.ramPercent) + "%";
                root.ramText = d.ramUsed + " / " + d.ramTotal + " GB";
                root.ramHistory = pushHistory(root.ramHistory, r, 30);
                root.ramUsedGb = d.ramUsed || 0;
                root.ramTotalGb = d.ramTotal || 0;
            }

            // GPU
            if (d.hasGpu && d.gpu !== undefined && d.gpu !== null) {
                root.hasGpu = true;
                var g = Math.max(0.0, Math.min(1.0, d.gpu / 100.0));
                root.gpuUsage = g;
                root.gpuPercentText = Math.round(d.gpu) + "%";
                root.gpuTemp = d.gpuTemp;
                root.gpuTempText = (d.gpuTemp !== null && d.gpuTemp !== undefined) ? (Math.round(d.gpuTemp) + "°C") : "—";
                root.gpuVramText = (d.gpuVramUsed !== null && d.gpuVramTotal !== null) ? (d.gpuVramUsed + " / " + d.gpuVramTotal + " GB") : "—";
                root.gpuVramUsed = (d.gpuVramUsed !== undefined) ? d.gpuVramUsed : null;
                root.gpuVramTotal = (d.gpuVramTotal !== undefined) ? d.gpuVramTotal : null;
                root.gpuName = d.gpuName || "";
                root.gpuPower = (d.gpuPower !== undefined) ? d.gpuPower : null;
                root.gpuClock = (d.gpuClock !== undefined) ? d.gpuClock : null;
                root.gpuHistory = pushHistory(root.gpuHistory, g, 30);
            } else {
                root.hasGpu = false;
                root.gpuUsage = null;
                root.gpuPercentText = "—";
                root.gpuTemp = null;
                root.gpuTempText = "—";
                root.gpuVramText = "—";
            }

            // CPU extras
            if (d.cores !== undefined) root.cores = d.cores || [];
            root.cpuFreq = (d.cpuFreq !== undefined) ? d.cpuFreq : null;
            if (d.loadAvg !== undefined) root.loadAvg = d.loadAvg;
            if (d.running !== undefined) root.runningTasks = d.running;
            if (d.tasks !== undefined) root.totalTasks = d.tasks;

            // Storage
            if (d.diskTotal !== undefined) {
                root.diskUsedGb = d.diskUsed || 0;
                root.diskTotalGb = d.diskTotal || 0;
                root.diskUsage = Math.max(0.0, Math.min(1.0, (d.diskPercent || 0) / 100.0));
            }
            root.nvmeTemp = (d.nvmeTemp !== undefined) ? d.nvmeTemp : null;

            // Network
            if (d.netRx !== undefined) {
                root.netRx = d.netRx;
                root.netTx = d.netTx || 0;
                root.netIface = d.netIface || "";
                root.netRxHistory = pushHistory(root.netRxHistory, d.netRx, 30);
                root.netTxHistory = pushHistory(root.netTxHistory, d.netTx || 0, 30);
            }

            // System
            if (d.uptime !== undefined) root.uptimeSec = d.uptime;
            if (d.kernel !== undefined) root.kernel = d.kernel;
            if (d.topProcs !== undefined) root.topProcs = d.topProcs || [];
        } catch (e) {
            // ignore malformed JSON
        }
    }

    // Continuous streaming process: runs only when active
    property var hwProcess: Process {
        id: procHw
        command: [ConfigManager.projectDir + "/scripts/deloway-hardware.py"]
        running: root.active
        stdout: SplitParser {
            onRead: function(line) {
                root.parseTelemetry(line);
            }
        }
    }
}
