pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

// ControlCenterService — backends for Quick Settings toggles that have no other home:
// airplane mode (rfkill), keep-awake (systemd-inhibit), power profile (power-profiles-daemon)
// plus the identity shown in the control-center header. Everything is event/refresh
// driven: nothing polls while the capsule is closed.
Item {
    id: root

    // ── Identity ─────────────────────────────────────────────────────────
    readonly property string userName: Quickshell.env("USER") || ""
    property string hostName: ""
    FileView {
        path: "/etc/hostname"
        preload: true
        printErrors: false
        onLoaded: root.hostName = (text() || "").trim()
    }

    // ── Chassis (desktop vs. portable) ───────────────────────────────────
    // Detected once at startup, three layers, first confident answer wins:
    //   1. `hostnamectl chassis` — systemd-hostnamed's verdict (DMI + ACPI + device-tree,
    //      honours a manual CHASSIS= override in /etc/machine-info).
    //   2. /sys/class/dmi/id/chassis_type — SMBIOS code: 8 Portable, 9 Laptop,
    //      10 Notebook, 11 Hand Held, 14 Sub Notebook, 30 Tablet, 31 Convertible,
    //      32 Detachable → portable.
    //   3. Battery present under /sys/class/power_supply (type "Battery").
    property string chassis: "unknown"      // "laptop" | "desktop" | … (hostnamectl vocabulary)
    property bool hasBattery: false
    property bool chassisKnown: false
    readonly property bool isPortable: {
        if (["laptop", "convertible", "tablet", "handset", "watch"].indexOf(root.chassis) >= 0) return true;
        if (["desktop", "server", "vm", "container", "embedded"].indexOf(root.chassis) >= 0) return false;
        return root.hasBattery;
    }

    Process {
        id: chassisProbe
        running: true
        command: ["sh", "-c",
            "c=$(LC_ALL=C hostnamectl chassis 2>/dev/null); " +
            "if [ -z \"$c\" ] && [ -r /sys/class/dmi/id/chassis_type ]; then " +
            "  case $(cat /sys/class/dmi/id/chassis_type) in 8|9|10|11|14|30|31|32) c=laptop;; 3|4|5|6|7|13|15|16|17|23|24|35|36) c=desktop;; esac; fi; " +
            "b=0; for d in /sys/class/power_supply/*; do [ \"$(cat $d/type 2>/dev/null)\" = Battery ] && b=1; done; " +
            "echo \"${c:-unknown} $b\""]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/);
                root.chassis = parts[0] || "unknown";
                root.hasBattery = parts[1] === "1";
                root.chassisKnown = true;
            }
        }
    }

    // ── Airplane mode ────────────────────────────────────────────────────
    property bool airplaneAvailable: false
    property bool airplaneMode: false
    // Shown on portables only. On a desktop the tile still appears while airplane mode is
    // ON, so a desktop that got blocked (e.g. via rfkill / IPC) can always be unblocked.
    readonly property bool showAirplaneToggle: root.airplaneAvailable && (root.isPortable || root.airplaneMode)

    Process {
        id: rfkillRead
        // LC_ALL=C: the session runs in Arabic, and rfkill localises its states
        // ("محظور" instead of "blocked"), which silently broke the comparison.
        command: ["env", "LC_ALL=C", "rfkill", "-n", "-o", "SOFT"]
        // StdioCollector fires after the stream is fully drained. (Parsing in onExited
        // raced the last stdout lines and could read an empty buffer → "off".)
        stdout: StdioCollector {
            onStreamFinished: {
                const states = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root.airplaneAvailable = states.length > 0;
                root.airplaneMode = states.length > 0 && states.every(s => s === "blocked");
            }
        }
    }
    Process {
        id: rfkillWrite
        onExited: {
            rfkillRead.running = true;
            NetworkService.refresh();
            BluetoothService.refresh();
        }
    }
    // Radio states captured when airplane mode is switched on, so switching it off
    // restores exactly what the user had (rfkill unblock alone leaves BlueZ powered
    // down and may leave NetworkManager's Wi-Fi radio disabled).
    property bool _restoreWifi: true
    property bool _restoreBluetooth: false

    function setAirplaneMode(on) {
        if (on) {
            root._restoreWifi = NetworkService.wifiEnabled;
            root._restoreBluetooth = BluetoothService.powered;
            rfkillWrite.command = ["rfkill", "block", "all"];
        } else {
            const cmds = ["rfkill unblock all", "sleep 0.5"];
            if (root._restoreWifi) cmds.push("nmcli radio wifi on");
            if (root._restoreBluetooth) cmds.push("bluetoothctl power on >/dev/null");
            rfkillWrite.command = ["sh", "-c", cmds.join("; ")];
        }
        root.airplaneMode = on;   // optimistic; corrected by the read-back
        rfkillWrite.running = true;
    }

    // ── Keep awake (blocks idle + sleep while enabled) ───────────────────
    property bool keepAwake: false
    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=DeloWay",
                  "--why=Keep awake (Quick Settings)", "--mode=block", "sleep", "infinity"]
    }

    // ── Power profile ────────────────────────────────────────────────────
    property bool powerProfilesAvailable: false
    property string powerProfile: ""        // "power-saver" | "balanced" | "performance"
    readonly property var powerProfiles: ["power-saver", "balanced", "performance"]

    Process {
        id: ppRead
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && LC_ALL=C powerprofilesctl get"]
        stdout: SplitParser { onRead: line => root.powerProfile = line.trim() }
        onExited: (code) => root.powerProfilesAvailable = code === 0
    }
    Process { id: ppWrite; onExited: ppRead.running = true }
    function setPowerProfile(p) {
        if (!root.powerProfilesAvailable) return;
        root.powerProfile = p;
        ppWrite.command = ["powerprofilesctl", "set", p];
        ppWrite.running = true;
    }
    function cyclePowerProfile() {
        const i = root.powerProfiles.indexOf(root.powerProfile);
        root.setPowerProfile(root.powerProfiles[(i + 1) % root.powerProfiles.length]);
    }

    // ── Screen sleep (Settings → Power & Display → Screen Sleep Timeout) ──
    // Wayland idle notification; honours idle inhibitors (video players …) and the
    // Quick Settings "Keep Awake" toggle. Displays go DPMS-off, any input wakes them.
    IdleMonitor {
        id: screenIdle
        enabled: ConfigManager.sleepTimeout > 0 && !root.keepAwake
        timeout: Math.max(60, ConfigManager.sleepTimeout * 60)
        respectInhibitors: true
        onIsIdleChanged: Hyprland.dispatch(isIdle ? "dpms off" : "dpms on")
    }
    readonly property bool displayAsleep: screenIdle.isIdle
    readonly property bool screenSleepArmed: screenIdle.enabled
    readonly property int screenSleepTimeoutSec: screenIdle.timeout

    function refresh() {
        rfkillRead.running = true;
        ppRead.running = true;
    }

    Component.onCompleted: refresh()
}
