import "."
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Item {
    id: root

    readonly property string projectDir: (typeof ConfigManager !== "undefined" && ConfigManager.projectDir) ? ConfigManager.projectDir : "/home/waleed/Projects/Deloway"
    property var monitors: []
    property int activeMonitorIndex: 0
    property bool loading: false
    property bool identifying: false
    property string primaryMonitorName: ""
    readonly property bool isMultiMonitor: monitors && monitors.length > 1
    readonly property var activeMonitor: (monitors && monitors.length > activeMonitorIndex) ? monitors[activeMonitorIndex] : null
    readonly property string activeMonitorName: activeMonitor ? activeMonitor.name : ""
    readonly property string currentResolution: activeMonitor ? activeMonitor.currentResolution : ""
    readonly property real currentRefreshRate: activeMonitor ? activeMonitor.refreshRate : 60
    readonly property real currentScale: activeMonitor ? activeMonitor.scale : 1
    readonly property int currentTransform: activeMonitor ? activeMonitor.transform : 0
    readonly property bool isPrimary: activeMonitor ? Boolean(activeMonitor.isPrimary) : false
    readonly property string mirrorOf: activeMonitor ? (activeMonitor.mirrorOf || "none") : "none"
    readonly property bool isMirrored: mirrorOf !== "none"
    readonly property bool hdrSupported: activeMonitor ? Boolean(activeMonitor.hdrSupported) : false
    readonly property bool hdrEnabled: activeMonitor ? Boolean(activeMonitor.hdrEnabled) : false
    readonly property bool vrrEnabled: activeMonitor ? Boolean(activeMonitor.vrr) : false
    readonly property string currentFormat: activeMonitor ? (activeMonitor.currentFormat || "") : ""
    readonly property var resolutions: activeMonitor ? (activeMonitor.resolutions || []) : []
    readonly property var availableRates: {
        if (!activeMonitor || !activeMonitor.resolutions)
            return [root.currentRefreshRate];

        for (let i = 0; i < activeMonitor.resolutions.length; i++) {
            const r = activeMonitor.resolutions[i];
            if (r.id === root.currentResolution)
                return r.rates && r.rates.length > 0 ? r.rates : [root.currentRefreshRate];

        }
        return [root.currentRefreshRate];
    }
    // Night Light & Eye Comfort
    property bool nightLightEnabled: false
    property int nightLightTemp: 4500

    signal displaysChanged()

    function toggleNightLight() {
        setNightLight(!nightLightEnabled, nightLightTemp || 4500);
    }

    function setNightLight(enabled, temp) {
        nightLightEnabled = enabled;
        if (temp)
            nightLightTemp = temp;

        const target = enabled ? (temp || nightLightTemp || 4500) : 6000;
        nightLightSetProcess.command = ["hyprctl", "hyprsunset", "temperature", String(target)];
        nightLightSetProcess.running = true;
    }

    function identifyDisplays() {
        root.identifying = true;
        identifyTimer.restart();
    }

    function refresh() {
        if (loading)
            return ;

        loading = true;
        infoProcess.running = true;
    }

    function selectMonitor(index) {
        if (index >= 0 && index < monitors.length) {
            activeMonitorIndex = index;
            displaysChanged();
        }
    }

    function applyCurrent(overrides) {
        if (!activeMonitor)
            return ;

        const o = overrides || {
        };
        const mon = activeMonitor;
        let w = mon.width;
        let h = mon.height;
        let rate = mon.refreshRate;
        if (o.resId) {
            const parts = o.resId.split("x");
            if (parts.length === 2) {
                w = parseInt(parts[0], 10);
                h = parseInt(parts[1], 10);
            }
            if (mon.resolutions) {
                for (let i = 0; i < mon.resolutions.length; i++) {
                    if (mon.resolutions[i].id === o.resId && mon.resolutions[i].rates.length > 0) {
                        rate = mon.resolutions[i].rates[0];
                        break;
                    }
                }
            }
        }
        if (o.rate !== undefined)
            rate = o.rate;

        const scale = o.scale !== undefined ? o.scale : mon.scale;
        const transform = o.transform !== undefined ? o.transform : mon.transform;
        const offset = o.offset !== undefined ? o.offset : (mon.isPrimary ? "0x0" : "auto-right");
        const mirror = o.mirror !== undefined ? o.mirror : (mon.mirrorOf !== "none" ? mon.mirrorOf : "");
        const makePrimary = o.primary !== undefined ? o.primary : mon.isPrimary;
        const hdr = o.hdr !== undefined ? (o.hdr ? 1 : 0) : (mon.hdrEnabled ? 1 : 0);
        const vrr = o.vrr !== undefined ? (o.vrr ? 1 : 0) : (mon.vrr ? 1 : 0);
        const cmd = ["python3", root.projectDir + "/scripts/deloway-display.py", "apply", "--name", mon.name, "--width", String(w), "--height", String(h), "--rate", String(rate), "--scale", String(scale), "--transform", String(transform), "--offset", offset, "--hdr", String(hdr), "--vrr", String(vrr)];
        if (mirror && mirror !== "none")
            cmd.push("--mirror", mirror);

        if (makePrimary)
            cmd.push("--primary");

        loading = true;
        applyProcess.command = cmd;
        applyProcess.running = true;
    }

    function setResolution(resId) {
        applyCurrent({
            "resId": resId
        });
    }

    function setRefreshRate(rate) {
        applyCurrent({
            "rate": rate
        });
    }

    function setScale(scale) {
        applyCurrent({
            "scale": scale
        });
    }

    function setTransform(transform) {
        applyCurrent({
            "transform": transform
        });
    }

    function setHdr(enabled) {
        if (!hdrSupported && enabled)
            return ;

        applyCurrent({
            "hdr": enabled
        });
    }

    function setVrr(enabled) {
        applyCurrent({
            "vrr": enabled
        });
    }

    function setPlacement(pos) {
        let offset = "auto-right";
        if (pos === "left")
            offset = "auto-left";
        else if (pos === "above")
            offset = "auto-up";
        else if (pos === "below")
            offset = "auto-down";
        applyCurrent({
            "offset": offset,
            "mirror": "none"
        });
    }

    function setMirrorMode(enable) {
        if (enable) {
            const target = primaryMonitorName || (monitors.length > 0 ? monitors[0].name : "");
            applyCurrent({
                "mirror": target
            });
        } else {
            applyCurrent({
                "mirror": "none",
                "offset": "auto-right"
            });
        }
    }

    function setAsPrimary() {
        applyCurrent({
            "primary": true,
            "offset": "0x0"
        });
    }

    Component.onCompleted: {
        refresh();
        nightLightCheckProcess.running = true;
    }

    Timer {
        id: identifyTimer

        interval: 2500
        repeat: false
        onTriggered: {
            root.identifying = false;
        }
    }

    // ── Night Light Processes ───────────────────────────────────
    Process {
        id: nightLightCheckProcess

        command: ["hyprctl", "hyprsunset", "temperature"]
        onExited: (code) => {
            if (code !== 0)
                root.nightLightEnabled = false;

        }

        stdout: SplitParser {
            onRead: (data) => {
                const val = parseInt(data.trim(), 10);
                if (!isNaN(val)) {
                    if (val < 6000) {
                        root.nightLightEnabled = true;
                        root.nightLightTemp = val;
                    } else {
                        root.nightLightEnabled = false;
                    }
                }
            }
        }

    }

    Process {
        id: nightLightSetProcess

        command: []
        onExited: (code) => {
            nightLightCheckProcess.running = true;
        }
    }

    // ── Process: Query Display Info ─────────────────────────────
    Process {
        id: infoProcess

        command: ["python3", root.projectDir + "/scripts/deloway-display.py", "info"]
        onExited: (code) => {
            root.loading = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                const trimmed = this.text.trim();
                if (trimmed.length === 0)
                    return ;

                try {
                    const parsed = JSON.parse(trimmed);
                    if (parsed && parsed.monitors) {
                        root.monitors = parsed.monitors;
                        root.primaryMonitorName = parsed.primaryMonitor || "";
                        if (root.activeMonitorIndex >= root.monitors.length)
                            root.activeMonitorIndex = 0;

                        root.displaysChanged();
                    }
                } catch (e) {
                    console.warn("[DisplayService] Failed to parse display info:", e);
                }
            }
        }

    }

    // ── Process: Apply Display Changes ──────────────────────────
    Process {
        id: applyProcess

        command: []
        onExited: (code) => {
            root.loading = false;
            root.refresh();
        }
    }

}
