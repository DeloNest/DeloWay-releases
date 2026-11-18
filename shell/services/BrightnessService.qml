import "."
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Brightness State (0.0 to 1.0)
    // ─────────────────────────────────────────────────────────────────────────
    property real screenBrightness: 0.75
    readonly property int brightnessPercent: Math.round(screenBrightness * 100)
    property string brightnessBackend: "none" // "kernel" | "ddc" | "none"
    readonly property bool hasBacklight: brightnessBackend !== "none"
    property string backlightDevice: ""
    property string ddcDisplayNum: "1"

    signal brightnessChanged(real value)

    function setBrightness(val) {
        const clamped = Math.max(0.05, Math.min(1.0, val));
        root.screenBrightness = clamped;
        root.brightnessChanged(clamped);

        if (root.brightnessBackend === "kernel") {
            backlightWriteDebounce.restart();
        } else if (root.brightnessBackend === "ddc") {
            ddcWriteDebounce.restart();
        }
    }

    function increaseBrightness(step) {
        const s = (typeof step === "number" && step > 0) ? step : 0.05;
        setBrightness(root.screenBrightness + s);
    }

    function decreaseBrightness(step) {
        const s = (typeof step === "number" && step > 0) ? step : 0.05;
        setBrightness(root.screenBrightness - s);
    }

    function refresh() {
        if (root.brightnessBackend === "kernel") {
            backlightReadProcess.running = true;
        } else if (root.brightnessBackend === "ddc") {
            const dispArg = root.ddcDisplayNum.length > 0 ? ("--display " + root.ddcDisplayNum + " ") : "";
            ddcReadProcess.command = ["sh", "-c", "ddcutil " + dispArg + "getvcp 10 2>/dev/null || true"];
            ddcReadProcess.running = true;
        } else {
            backlightDetectProcess.running = true;
        }
    }

    function applyDdcBrightness() {
        if (root.brightnessBackend !== "ddc")
            return ;

        if (ddcWriteProcess.running) {
            ddcWriteProcess.pending = true;
            return ;
        }
        const pct = Math.max(5, Math.min(100, Math.round(root.screenBrightness * 100)));
        const disp = root.ddcDisplayNum.length > 0 ? ["--display", root.ddcDisplayNum] : [];
        ddcWriteProcess.command = ["ddcutil"].concat(disp, ["setvcp", "10", String(pct)]);
        ddcWriteProcess.running = true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Hardware Detection & Read / Write Processes
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Kernel Backlight Detect (Laptops / Sysfs)
    Process {
        id: backlightDetectProcess

        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f1 || true"]
        onExited: (exitCode, exitStatus) => {
            if (root.brightnessBackend === "none" && !ddcDetectProcess.running && root.backlightDevice.length === 0)
                ddcDetectProcess.running = true;

        }

        stdout: SplitParser {
            onRead: (data) => {
                const device = data.trim();
                if (device.length > 0) {
                    root.backlightDevice = device;
                    root.brightnessBackend = "kernel";
                    backlightReadProcess.running = true;
                } else {
                    ddcDetectProcess.running = true;
                }
            }
        }

    }

    // 2. DDC/CI Detect (Desktops: DisplayPort / HDMI external monitors)
    Process {
        id: ddcDetectProcess

        command: ["sh", "-c", "disp=$(command -v ddcutil >/dev/null 2>&1 && ddcutil detect 2>/dev/null | grep -m1 -E '^Display [0-9]+' | awk '{print $2}'); echo \"$disp\""]

        onExited: (exitCode, exitStatus) => {
            if (root.brightnessBackend !== "ddc" && root.brightnessBackend !== "kernel") {
                root.brightnessBackend = "none";
            }
        }

        stdout: SplitParser {
            onRead: (data) => {
                const disp = data.trim();
                if (disp.length > 0 && !isNaN(parseInt(disp, 10))) {
                    root.ddcDisplayNum = disp;
                    root.brightnessBackend = "ddc";
                    const dispArg = "--display " + disp + " ";
                    ddcReadProcess.command = ["sh", "-c", "ddcutil " + dispArg + "getvcp 10 2>/dev/null || true"];
                    ddcReadProcess.running = true;
                } else {
                    root.brightnessBackend = "none";
                }
            }
        }

    }

    // 3. Kernel Backlight Read
    Process {
        id: backlightReadProcess

        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]

        stdout: SplitParser {
            onRead: (data) => {
                const pct = parseInt(data.trim(), 10);
                if (!isNaN(pct) && pct >= 0 && pct <= 100)
                    root.screenBrightness = Math.max(0.05, Math.min(1, pct / 100));

            }
        }

    }

    // 4. DDC/CI Backlight Read
    Process {
        id: ddcReadProcess

        command: ["sh", "-c", "ddcutil --display 1 getvcp 10 2>/dev/null || true"]

        stdout: SplitParser {
            onRead: (data) => {
                const match = data.match(/current value\s*=\s*(\d+)/);
                if (match) {
                    const pct = parseInt(match[1], 10);
                    if (!isNaN(pct) && pct >= 0 && pct <= 100)
                        root.screenBrightness = Math.max(0.05, Math.min(1, pct / 100));

                }
            }
        }

    }

    // 5. Kernel Backlight Write (Debounced by 80ms)
    Process {
        id: backlightWriteProcess
    }

    Timer {
        id: backlightWriteDebounce

        interval: 80
        onTriggered: {
            const pct = Math.max(5, Math.min(100, Math.round(root.screenBrightness * 100)));
            backlightWriteProcess.command = ["sh", "-c", "brightnessctl set " + pct + "% 2>/dev/null || true"];
            backlightWriteProcess.running = true;
        }
    }

    // 6. DDC/CI Backlight Write (Debounced by 200ms with serialized pending queue)
    Process {
        id: ddcWriteProcess

        property bool pending: false

        onExited: {
            if (pending) {
                pending = false;
                root.applyDdcBrightness();
            }
        }
    }

    Timer {
        id: ddcWriteDebounce

        interval: 200
        onTriggered: root.applyDdcBrightness()
    }

    Component.onCompleted: {
        backlightDetectProcess.running = true;
    }
}
