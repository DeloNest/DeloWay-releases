pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

QtObject {
    id: root

    // Active ONLY when TimeCapsule is expanded and hardware section is enabled
    readonly property bool active: ShellState.timeCapsuleExpanded && ConfigManager.timeCapsuleShowHardware

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

    // 30-sample history arrays for sparklines (~60 seconds at 2s intervals)
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []

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
                root.gpuHistory = pushHistory(root.gpuHistory, g, 30);
            } else {
                root.hasGpu = false;
                root.gpuUsage = null;
                root.gpuPercentText = "—";
                root.gpuTemp = null;
                root.gpuTempText = "—";
                root.gpuVramText = "—";
            }
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
