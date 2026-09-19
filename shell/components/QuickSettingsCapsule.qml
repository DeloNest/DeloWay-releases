import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../theme"
import "../services"
import "./quicksettings"
import "./quicksettings/pages"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        left: true
    }

    readonly property real earRadius: 18
    readonly property real bottomRadius: 26
    readonly property real capsuleGap: 10

    margins {
        top: root.isExpanded ? 0 : 10
        left: Math.round(targetScreen.width / 2 + ShellState.smartNotchCurrentWidth / 2 + capsuleGap - (root.isExpanded ? root.earRadius : 0))
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:quicksettings-capsule"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────────
    // Dimensions & State (Matching Notch smooth transitions)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property bool isExpanded: ShellState.quickSettingsCapsuleExpanded
    readonly property string currentView: ShellState.quickSettingsCapsuleView

    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(108, compactRow.implicitWidth + 48)
    readonly property real expandedWidth: 440
    readonly property real expandedHeight: {
        if (root.currentView === "wifi") return 390;
        if (root.currentView === "bluetooth") return 390;
        if (root.currentView === "hotspot") return 430;
        return 400;
    }

    // Animated intermediates — same pattern as Notch.qml currentWidth/currentHeight
    property real currentWidth: root.isExpanded ? root.expandedWidth : root.compactWidth
    property real currentHeight: root.isExpanded ? root.expandedHeight : root.compactHeight

    Behavior on currentWidth  { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on currentHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    // PanelWindow dimensions driven by animated intermediates (shadow and ears preserved)
    implicitWidth:  Math.round(root.currentWidth  + (root.isExpanded ? root.earRadius * 2 : 0))
    implicitHeight: Math.round(root.currentHeight + 8)

    Shortcut {
        sequence: "Escape"
        enabled: root.isExpanded
        onActivated: {
            if (root.currentView !== "main") {
                ShellState.quickSettingsCapsuleView = "main";
            } else {
                ShellState.closeQuickSettingsCapsule();
            }
        }
    }

    onCurrentViewChanged: {
        if (root.currentView === "hotspot" || root.currentView === "wifi") {
            networkStatusProcess.running = true;
        } else if (root.currentView === "bluetooth") {
            bluetoothStatusProcess.running = true;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Keyboard Layout Logic (Event-driven via Hyprland socket2 & initial process)
    // ─────────────────────────────────────────────────────────────────────────
    property string activeKeyboardCode: "EN"

    function layoutToCode(name) {
        if (!name) return "EN";
        const lower = name.toLowerCase();
        if (lower.indexOf("arab") !== -1 || lower.indexOf("ara") !== -1) return "AR";
        if (lower.indexOf("engl") !== -1 || lower.indexOf("us") !== -1) return "EN";
        if (lower.indexOf("fren") !== -1 || lower.indexOf("fr") !== -1) return "FR";
        if (lower.indexOf("germ") !== -1 || lower.indexOf("de") !== -1) return "DE";
        if (lower.indexOf("span") !== -1 || lower.indexOf("es") !== -1) return "ES";
        if (lower.indexOf("turk") !== -1 || lower.indexOf("tr") !== -1) return "TR";
        if (lower.indexOf("russ") !== -1 || lower.indexOf("ru") !== -1) return "RU";
        return name.slice(0, 2).toUpperCase();
    }

    function updateLayoutFromEvent(data) {
        if (!data) return;
        const parts = data.split(",");
        const layoutName = parts.length > 1 ? parts.slice(1).join(",").trim() : parts[0].trim();
        root.activeKeyboardCode = root.layoutToCode(layoutName);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name === "activelayout") {
                root.updateLayoutFromEvent(event.data);
            }
        }
    }

    Process {
        id: keyboardInitProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-keyboard.py", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    if (parsed.code) {
                        root.activeKeyboardCode = parsed.code;
                    } else if (parsed.active) {
                        root.activeKeyboardCode = root.layoutToCode(parsed.active);
                    }
                } catch (e) {}
            }
        }
        Component.onCompleted: running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Network Data Logic (deloway-network.py)
    // ─────────────────────────────────────────────────────────────────────────
    property var networkData: null
    property bool wifiEnabled: false
    property var wifiNetworks: []
    property string connectingSsid: ""
    property string networkError: ""
    readonly property string wifiSsid: (networkData && networkData.wifi && networkData.wifi.ssid) ? networkData.wifi.ssid : ""

    property bool hotspotAvailable: false
    property bool hotspotEnabled: false
    property string hotspotSsid: ""
    property string hotspotPassword: ""
    property string hotspotError: ""
    property string hotspotSaveSuccess: ""
    property var hotspotClients: []

    Process {
        id: networkStatusProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.networkData = parsed;
                    root.networkError = "";
                    if (parsed.wifi) {
                        root.wifiEnabled = parsed.wifi.enabled;
                        root.wifiNetworks = parsed.wifi.networks || [];
                    }
                    if (parsed.hotspot) {
                        root.hotspotAvailable = !!parsed.hotspot.available;
                        root.hotspotEnabled = !!parsed.hotspot.enabled;
                        if (parsed.hotspot.ssid) root.hotspotSsid = parsed.hotspot.ssid;
                        if (parsed.hotspot.password) root.hotspotPassword = parsed.hotspot.password;
                        if (parsed.hotspot.clients !== undefined) root.hotspotClients = parsed.hotspot.clients;
                    }
                } catch(e) {
                    root.networkError = I18n.isRTL ? "تعذر قراءة بيانات الشبكة" : "Failed to parse network data";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.networkError = I18n.isRTL ? "تعذر جلب بيانات الشبكة" : "Failed to fetch network data";
            }
        }
    }

    Process {
        id: wifiToggleProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "toggle-wifi"]
        onExited: networkStatusProcess.running = true
    }

    Process {
        id: wifiRescanProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "rescan"]
        onExited: networkStatusProcess.running = true
    }

    Process {
        id: wifiConnectProcess
        onExited: {
            root.connectingSsid = "";
            networkStatusProcess.running = true;
        }
    }

    function toggleWifi() {
        const next = !root.wifiEnabled;
        wifiToggleProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "toggle-wifi"];
        wifiToggleProcess.running = true;
        root.wifiEnabled = next;
    }

    function rescanWifi() {
        wifiRescanProcess.running = true;
    }

    function connectWifi(ssid, password) {
        root.connectingSsid = ssid;
        let cmd = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "connect", ssid];
        if (password && password.length > 0) {
            cmd.push(password);
        }
        wifiConnectProcess.command = cmd;
        wifiConnectProcess.running = true;
    }

    Process {
        id: hotspotActionProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const res = JSON.parse(data.trim());
                    if (res.enabled !== undefined) {
                        root.hotspotEnabled = res.enabled;
                    }
                    if (res.error) {
                        root.hotspotError = res.error;
                    } else {
                        root.hotspotError = "";
                    }
                } catch(e) {}
            }
        }
        onExited: networkStatusProcess.running = true
    }

    Process {
        id: hotspotConfigureProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const res = JSON.parse(data.trim());
                    if (res.success) {
                        root.hotspotError = "";
                        root.hotspotSaveSuccess = I18n.isRTL ? "تم حفظ إعدادات نقطة الاتصال" : "Hotspot saved successfully";
                        if (res.ssid) root.hotspotSsid = res.ssid;
                        if (res.password) root.hotspotPassword = res.password;
                    } else {
                        root.hotspotError = res.error || (I18n.isRTL ? "فشل حفظ الإعدادات" : "Failed to save configuration");
                        root.hotspotSaveSuccess = "";
                    }
                } catch(e) {
                    root.hotspotError = I18n.isRTL ? "خطأ في قراءة النتيجة" : "Error parsing response";
                }
            }
        }
        onExited: networkStatusProcess.running = true
    }

    function toggleHotspot() {
        root.hotspotError = "";
        root.hotspotSaveSuccess = "";
        const action = root.hotspotEnabled ? "hotspot-stop" : "hotspot-start";
        hotspotActionProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", action];
        hotspotActionProcess.running = true;
    }

    function configureHotspot(ssid, password) {
        root.hotspotError = "";
        root.hotspotSaveSuccess = "";
        if (!ssid || ssid.trim().length === 0) {
            root.hotspotError = I18n.isRTL ? "اسم الشبكة لا يمكن أن يكون فارغاً" : "SSID cannot be empty";
            return;
        }
        if (!password || password.length < 8) {
            root.hotspotError = I18n.isRTL ? "كلمة المرور يجب ألا تقل عن 8 خانات" : "Password must be at least 8 characters";
            return;
        }
        hotspotConfigureProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "hotspot-configure", ssid.trim(), password];
        hotspotConfigureProcess.running = true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bluetooth Data Logic (deloway-bluetooth.py)
    // ─────────────────────────────────────────────────────────────────────────
    property var bluetoothData: null
    property bool bluetoothEnabled: false
    property var bluetoothDevices: []
    property string bluetoothConnectedDevice: ""
    property string connectingBtAddress: ""
    property string bluetoothError: ""

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

    Process {
        id: bluetoothStatusProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "list"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.bluetoothData = parsed;
                    root.bluetoothError = "";
                    root.bluetoothEnabled = !!parsed.powered;
                    const devs = parsed.devices || [];
                    root.bluetoothDevices = root.sortedBluetoothDevices(devs);
                    const connected = devs.find(d => d.connected);
                    root.bluetoothConnectedDevice = connected ? (connected.name || connected.address) : "";
                } catch(e) {
                    root.bluetoothError = I18n.isRTL ? "تعذر قراءة بيانات البلوتوث" : "Failed to parse bluetooth data";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.bluetoothError = I18n.isRTL ? "تعذر جلب بيانات البلوتوث" : "Failed to fetch bluetooth data";
            }
        }
    }

    Process {
        id: bluetoothToggleProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "toggle"]
        onExited: bluetoothStatusProcess.running = true
    }

    Process {
        id: bluetoothConnectProcess
        onExited: {
            root.connectingBtAddress = "";
            bluetoothStatusProcess.running = true;
        }
    }

    Process {
        id: bluetoothDisconnectProcess
        onExited: {
            bluetoothStatusProcess.running = true;
        }
    }

    function toggleBluetooth() {
        const next = !root.bluetoothEnabled;
        bluetoothToggleProcess.running = true;
        root.bluetoothEnabled = next;
    }

    function refreshBluetooth() {
        bluetoothStatusProcess.running = true;
    }

    function connectBluetooth(address) {
        root.connectingBtAddress = address;
        bluetoothConnectProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "connect", address];
        bluetoothConnectProcess.running = true;
    }

    function disconnectBluetooth(address) {
        bluetoothDisconnectProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "disconnect", address];
        bluetoothDisconnectProcess.running = true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Update Strategy (Low Resource Impact)
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Instant fetch upon expanding
    onIsExpandedChanged: {
        if (isExpanded) {
            networkStatusProcess.running = true;
            root.bluetoothError = "";
            bluetoothStatusProcess.running = true;
            if (root.brightnessBackend === "kernel") {
                backlightReadProcess.running = true;
            } else if (root.brightnessBackend === "ddc") {
                const dispArg = root.ddcDisplayNum.length > 0 ? ("--display " + root.ddcDisplayNum + " ") : "";
                ddcReadProcess.command = ["sh", "-c", "ddcutil " + dispArg + "getvcp 10 2>/dev/null || true"];
                ddcReadProcess.running = true;
            } else {
                backlightDetectProcess.running = true;
            }
        } else {
            ShellState.quickSettingsCapsuleHotspotSettingsOpen = false;
            ShellState.quickSettingsCapsuleView = "main";
        }
    }

    // 2. Idle timer: 60s
    Timer {
        id: idlePollTimer
        interval: 60000
        running: !root.isExpanded
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (SystemMonitor.isWifi) {
                networkStatusProcess.running = true;
            }
            if (root.bluetoothError.length === 0) {
                bluetoothStatusProcess.running = true;
            }
        }
    }

    // 3. Active Wi-Fi list timer: 10s only when viewing wifi list
    Timer {
        id: wifiViewTimer
        interval: 10000
        running: root.isExpanded && root.currentView === "wifi"
        repeat: true
        onTriggered: {
            networkStatusProcess.running = true;
        }
    }

    // 4. Active Bluetooth list timer: 10s only when viewing bluetooth list
    Timer {
        id: btViewTimer
        interval: 10000
        running: root.isExpanded && root.currentView === "bluetooth"
        repeat: true
        onTriggered: {
            bluetoothStatusProcess.running = true;
        }
    }

    // 5. Active Hotspot list timer: 10s only when viewing hotspot
    Timer {
        id: hotspotViewTimer
        interval: 10000
        running: root.isExpanded && root.currentView === "hotspot"
        repeat: true
        onTriggered: {
            networkStatusProcess.running = true;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Audio State & Logic (Pipewire)
    // ─────────────────────────────────────────────────────────────────────────
    property var audioSink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.audioSink ? [root.audioSink] : []
    }

    readonly property real currentVolume: {
        if (!audioSink || !audioSink.audio)
            return 0;
        return audioSink.audio.volume;
    }

    readonly property bool isMuted: {
        if (!audioSink || !audioSink.audio)
            return false;
        return audioSink.audio.muted;
    }

    readonly property string volumeIconName: {
        if (root.isMuted || root.currentVolume <= 0.001)
            return "audio-volume-muted";
        if (root.currentVolume < 0.33)
            return "audio-volume-low";
        if (root.currentVolume < 0.66)
            return "audio-volume-medium";
        return "audio-volume-high";
    }

    function setVolume(value) {
        if (!root.audioSink || !root.audioSink.audio || !root.audioSink.ready)
            return;

        const clamped = Math.max(0, Math.min(1, value));
        root.audioSink.audio.volume = clamped;
        if (clamped > 0 && root.audioSink.audio.muted) {
            root.audioSink.audio.muted = false;
        }
    }

    function toggleMute() {
        if (!root.audioSink || !root.audioSink.audio || !root.audioSink.ready)
            return;

        root.audioSink.audio.muted = !root.audioSink.audio.muted;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Screen Brightness (Hybrid: kernel backlight / DDC/CI via ddcutil)
    // ─────────────────────────────────────────────────────────────────────────
    property real screenBrightness: 0.75
    property string brightnessBackend: "none" // "kernel" | "ddc" | "none"
    property bool hasBacklight: brightnessBackend !== "none"
    property string backlightDevice: ""
    property string ddcDisplayNum: ""

    // 1. Kernel Backlight Detect
    Process {
        id: backlightDetectProcess
        command: ["sh", "-c", "dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); echo \"$dev\""]
        stdout: SplitParser {
            onRead: data => {
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
        onExited: (exitCode, exitStatus) => {
            if (root.brightnessBackend === "none" && !ddcDetectProcess.running && root.backlightDevice.length === 0) {
                ddcDetectProcess.running = true;
            }
        }
    }

    // 2. DDC/CI Detect (Fallback for external desktop monitors)
    Process {
        id: ddcDetectProcess
        command: ["sh", "-c", "disp=$(command -v ddcutil >/dev/null 2>&1 && ddcutil detect 2>/dev/null | grep -m1 -E '^Display [0-9]+' | awk '{print $2}'); echo \"$disp\""]
        stdout: SplitParser {
            onRead: data => {
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
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                const pct = parseInt(data.trim(), 10);
                if (!isNaN(pct))
                    root.screenBrightness = Math.max(0, Math.min(1, pct / 100));
            }
        }
    }

    // 4. DDC/CI Backlight Read
    Process {
        id: ddcReadProcess
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/current value\s*=\s*(\d+)/);
                if (match) {
                    const pct = parseInt(match[1], 10);
                    if (!isNaN(pct))
                        root.screenBrightness = Math.max(0, Math.min(1, pct / 100));
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
            const pct = Math.round(root.screenBrightness * 100);
            backlightWriteProcess.command = ["sh", "-c", "brightnessctl set " + pct + "%"];
            backlightWriteProcess.running = true;
        }
    }

    // 6. DDC/CI Backlight Write (Single command executed on released)
    Process {
        id: ddcWriteProcess
    }

    function applyDdcBrightness() {
        if (root.brightnessBackend !== "ddc")
            return;
        const pct = Math.max(0, Math.min(100, Math.round(root.screenBrightness * 100)));
        const dispArg = root.ddcDisplayNum.length > 0 ? ("--display " + root.ddcDisplayNum + " ") : "";
        ddcWriteProcess.command = ["sh", "-c", "ddcutil " + dispArg + "setvcp 10 " + pct + " >/dev/null 2>&1 || true"];
        if (ddcWriteProcess.running)
            ddcWriteProcess.running = false;
        ddcWriteProcess.running = true;
    }

    function setBrightness(value) {
        root.screenBrightness = Math.max(0, Math.min(1, value));
        if (root.brightnessBackend === "kernel")
            backlightWriteDebounce.restart();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Night Light / Eye Comfort (via hyprsunset daemon + hyprctl)
    // ─────────────────────────────────────────────────────────────────────────
    property bool nightLightEnabled: false

    Process {
        id: nightLightInitialCheckProcess
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: SplitParser {
            onRead: data => {
                root.nightLightEnabled = (data.trim() === "4500");
            }
        }
    }

    function toggleNightLight() {
        const next = !root.nightLightEnabled;
        root.nightLightEnabled = next;
        if (next) {
            Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset temperature 4500"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset temperature 6000"]);
        }
    }

    Component.onCompleted: {
        backlightDetectProcess.running = true;
        Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset temperature >/dev/null 2>&1 || (nohup hyprsunset >/dev/null 2>&1 &)"]);
        nightLightInitialCheckProcess.running = true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Visual Hierarchy
    // ─────────────────────────────────────────────────────────────────────────
    NotchFrame {
        id: capsuleFrame
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        isExpanded: root.isExpanded
        currentWidth: root.currentWidth
        currentHeight: root.currentHeight
        earRadius: root.earRadius
        bottomRadius: root.bottomRadius
        clipContent: true

        // ── Stage 1: Compact View ────────────────────────────────────────
            Item {
                id: compactView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: root.compactHeight
                opacity: root.isExpanded ? 0.0 : 1.0
                visible: !root.isExpanded
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    enabled: !root.isExpanded
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            ShellState.openQuickSettingsCapsule("main");
                        }
                    }
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0) {
                            ShellState.openQuickSettingsCapsule("main");
                        } else if (wheel.angleDelta.y > 0) {
                            ShellState.closeQuickSettingsCapsule();
                        }
                    }
                }

                RowLayout {
                    id: compactRow
                    anchors.centerIn: parent
                    spacing: 8

                    // ── Battery Indicator (hidden on desktop) ──
                    Item {
                        visible: SystemMonitor.hasBattery
                        implicitWidth: batteryCompactRow.implicitWidth
                        implicitHeight: batteryCompactRow.implicitHeight
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            id: batteryCompactRow
                            spacing: 3

                            // Battery icon
                            SymbolicIcon {
                                iconSize: 14
                                source: {
                                    const p = SystemMonitor.batteryPercent;
                                    if (SystemMonitor.batteryStatusText === "Charging") return "battery-good-charging-symbolic";
                                    if (p <= 10) return "battery-empty-symbolic";
                                    if (p <= 25) return "battery-low-symbolic";
                                    if (p <= 60) return "battery-good-symbolic";
                                    return "battery-full-symbolic";
                                }
                                iconColor: {
                                    if (SystemMonitor.batteryStatusText === "Charging") return Theme.colors.success;
                                    if (SystemMonitor.batteryPercent <= 20) return Theme.colors.danger;
                                    return Theme.notchText;
                                }
                            }

                            Text {
                                text: SystemMonitor.batteryPercent + "%"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.Medium
                                color: {
                                    if (SystemMonitor.batteryStatusText === "Charging") return Theme.colors.success;
                                    if (SystemMonitor.batteryPercent <= 20) return Theme.colors.danger;
                                    return Theme.notchTextSecondary;
                                }
                                renderType: Theme.renderType
                            }
                        }
                    }

                    // ── Separator dot ──
                    Rectangle {
                        visible: SystemMonitor.hasBattery
                        width: 3; height: 3; radius: 1.5
                        color: Theme.notchTextTertiary
                        Layout.alignment: Qt.AlignVCenter
                        opacity: 0.5
                    }

                    // ── Background Apps (System Tray) ──
                    SystemTrayIndicators {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // ── Volume icon (mutable, clickable to mute) ──
                    Item {
                        implicitWidth: 22; implicitHeight: 22
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: volumeCompactMa.containsMouse
                                   ? Theme.notchSurfaceHover
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: root.volumeIconName + "-symbolic"
                            iconColor: root.isMuted ? Theme.colors.danger : Theme.notchText
                        }

                        MouseArea {
                            id: volumeCompactMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.toggleMute()
                        }
                    }

                    // ── Network icon + SSID ──
                    Item {
                        id: networkCompactSection
                        implicitWidth: netRow.implicitWidth
                        implicitHeight: netRow.implicitHeight
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            id: netRow
                            spacing: 4

                            SymbolicIcon {
                                iconSize: 14
                                source: SystemMonitor.isWifi
                                        ? "network-wireless-symbolic"
                                        : "network-wired-symbolic"
                                iconColor: SystemMonitor.isOnline
                                           ? Theme.notchText
                                           : Theme.notchTextTertiary
                            }

                            Text {
                                id: ssidLabel
                                visible: SystemMonitor.isWifi && text.length > 0
                                text: root.wifiSsid
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Medium
                                color: Theme.notchText
                                elide: Text.ElideRight
                                Layout.maximumWidth: 90
                                renderType: Theme.renderType
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton)
                                    ShellState.toggleQuickSettingsCapsule("wifi");
                            }
                        }
                    }

                    // ── Language badge capsule ──
                    Rectangle {
                        implicitWidth: langBadgeText.implicitWidth + 10
                        implicitHeight: 18
                        radius: 5
                        color: Theme.notchSurfaceElevated
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: langBadgeText
                            anchors.centerIn: parent
                            text: root.activeKeyboardCode
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Medium
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                    }

                    // ── Gear icon (settings trigger) ──
                    Item {
                        implicitWidth: 22; implicitHeight: 22
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: settingsIconMa.containsMouse
                                   ? Theme.notchSurfaceHover
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "settings-symbolic"
                            iconColor: Theme.notchText
                        }

                        MouseArea {
                            id: settingsIconMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton)
                                    ShellState.toggleQuickSettingsCapsule("main");
                            }
                        }
                    }
                }
            }


            // ── Stage 2: Expanded Content ────────────────────────────────────
            Item {
                id: expandedContent
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 8
                anchors.bottomMargin: 12
                opacity: root.isExpanded ? 1.0 : 0.0
                visible: root.isExpanded

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motionFast }
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW A: MAIN CONTROLS (Wi-Fi, BT, Volume, Brightness)
                // ═════════════════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4
                    visible: root.currentView === "main"

                    // ── Rich Header: Clock + Battery + Close ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48

                        // Live clock timer
                        Timer {
                            id: clockTimer
                            interval: 30000
                            repeat: true
                            running: root.isExpanded
                            triggeredOnStart: true
                            onTriggered: {
                                headerTimeText.text = Qt.formatDateTime(new Date(), "hh:mm");
                                headerDayText.text = Qt.formatDateTime(new Date(), I18n.isRTL ? "dddd" : "dddd");
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    wheel.accepted = true;
                                    ShellState.closeQuickSettingsCapsule();
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Left: Day + Time stack
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    id: headerDayText
                                    text: Qt.formatDateTime(new Date(), I18n.isRTL ? "dddd" : "dddd")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Medium
                                    color: Theme.notchTextTertiary
                                    renderType: Theme.renderType
                                }

                                Text {
                                    id: headerTimeText
                                    text: Qt.formatDateTime(new Date(), "hh:mm")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(22)
                                    font.weight: Font.Bold
                                    color: Theme.notchText
                                    renderType: Theme.renderType
                                    lineHeight: 1.0
                                }
                            }

                            // Right: Battery + Close
                            ColumnLayout {
                                spacing: 4
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                // Close button
                                QSRoundButton {
                                    buttonSize: 24
                                    text: "✕"
                                    iconSize: 11
                                    normalColor: Theme.notchSurface
                                    hoverColor: Theme.notchSurfaceHover
                                    textColor: Theme.notchTextTertiary
                                    hoverTextColor: Theme.notchText
                                    Layout.alignment: Qt.AlignRight
                                    onClicked: ShellState.closeQuickSettingsCapsule()
                                }

                                // Battery row
                                RowLayout {
                                    visible: SystemMonitor.hasBattery
                                    spacing: 4
                                    Layout.alignment: Qt.AlignRight

                                    SymbolicIcon {
                                        iconSize: 13
                                        source: {
                                            const p = SystemMonitor.batteryPercent;
                                            if (SystemMonitor.batteryStatusText === "Charging") return "battery-good-charging-symbolic";
                                            if (p <= 10) return "battery-empty-symbolic";
                                            if (p <= 25) return "battery-low-symbolic";
                                            if (p <= 60) return "battery-good-symbolic";
                                            return "battery-full-symbolic";
                                        }
                                        iconColor: {
                                            if (SystemMonitor.batteryStatusText === "Charging") return Theme.colors.success;
                                            if (SystemMonitor.batteryPercent <= 20) return Theme.colors.danger;
                                            return Theme.notchTextSecondary;
                                        }
                                    }

                                    Text {
                                        text: SystemMonitor.batteryPercent + "%"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.Medium
                                        color: {
                                            if (SystemMonitor.batteryStatusText === "Charging") return Theme.colors.success;
                                            if (SystemMonitor.batteryPercent <= 20) return Theme.colors.danger;
                                            return Theme.notchTextSecondary;
                                        }
                                        renderType: Theme.renderType
                                    }
                                }
                            }
                        }
                    }

                    // ── Thin separator ──
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.notchBorderSubtle
                        opacity: 0.7
                    }

                    // ── Row 1: Wi-Fi Card + Bluetooth Card (2-Column Grid) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        spacing: 8

                        QSToggleTile {
                            title: "Wi-Fi"
                            subtitle: !root.wifiEnabled
                                      ? (I18n.isRTL ? "معطل" : "Off")
                                      : (root.wifiSsid.length > 0 ? root.wifiSsid : (I18n.isRTL ? "غير متصل" : "Disconnected"))
                            icon: "network-wireless-symbolic"
                            active: root.wifiEnabled
                            connected: root.wifiEnabled && root.wifiSsid.length > 0
                            onClicked: {
                                ShellState.quickSettingsCapsuleView = "wifi";
                                root.rescanWifi();
                            }
                            onToggleClicked: root.toggleWifi()
                        }

                        QSToggleTile {
                            title: "Bluetooth"
                            subtitle: !root.bluetoothEnabled
                                      ? (I18n.isRTL ? "معطل" : "Off")
                                      : (root.bluetoothConnectedDevice.length > 0
                                         ? root.bluetoothConnectedDevice
                                         : (I18n.isRTL ? "لا يوجد جهاز" : "No device"))
                            icon: root.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
                            active: root.bluetoothEnabled
                            connected: root.bluetoothConnectedDevice.length > 0
                            onClicked: {
                                ShellState.quickSettingsCapsuleView = "bluetooth";
                                root.refreshBluetooth();
                            }
                            onToggleClicked: root.toggleBluetooth()
                        }
                    }

                    // ── Row 2: Hotspot Card + Night Light Card (2-Column Symmetrical Grid) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        spacing: 8

                        QSToggleTile {
                            title: I18n.isRTL ? "نقطة اتصال" : "Hotspot"
                            subtitle: !root.hotspotAvailable
                                      ? (I18n.isRTL ? "غير متوفرة" : "Unavailable")
                                      : (root.hotspotEnabled
                                         ? (root.hotspotClients.length > 0
                                            ? (root.hotspotClients.length + (I18n.isRTL ? " متصل" : " connected"))
                                            : (I18n.isRTL ? "مفعّلة" : "Active"))
                                         : (I18n.isRTL ? "معطلة" : "Disabled"))
                            icon: "network-wireless-hotspot-symbolic"
                            active: root.hotspotEnabled
                            connected: root.hotspotEnabled
                            toggleEnabled: root.hotspotAvailable && !hotspotActionProcess.running
                            onClicked: {
                                ShellState.quickSettingsCapsuleView = "hotspot";
                            }
                            onToggleClicked: root.toggleHotspot()
                        }

                        QSToggleTile {
                            title: I18n.isRTL ? "إضاءة ليلية" : "Night Light"
                            subtitle: root.nightLightEnabled
                                      ? (I18n.isRTL ? "مفعّلة" : "Active")
                                      : (I18n.isRTL ? "معطلة" : "Disabled")
                            icon: "night-light-symbolic"
                            active: root.nightLightEnabled
                            connected: root.nightLightEnabled
                            hasChevron: false
                            activeColor: Qt.rgba(0.95, 0.65, 0.25, 0.35)
                            activeIconColor: Qt.rgba(1.0, 0.78, 0.40, 1.0)
                            onClicked: root.toggleNightLight()
                        }
                    }

                    // ── Row 3: Sound Card (Title + Percentage + Mute Toggle + Interactive Slider) ──
                    QSSliderCard {
                        title: I18n.isRTL ? "الصوت" : "Sound"
                        icon: root.volumeIconName + "-symbolic"
                        iconColor: root.isMuted ? Theme.colors.danger : Theme.notchText
                        iconClickable: true
                        isMuted: root.isMuted
                        value: root.currentVolume
                        valueText: root.isMuted
                                   ? (I18n.isRTL ? "مكتوم" : "Muted")
                                   : (Math.round(root.currentVolume * 100) + "%")
                        onSliderMoved: (newVal) => root.setVolume(newVal)
                        onIconClicked: root.toggleMute()
                    }

                    // ── Row 4: Display Card (Title + Percentage + Interactive Slider) ──
                    QSSliderCard {
                        visible: root.brightnessBackend !== "none"
                        title: I18n.isRTL ? "السطوع" : "Display"
                        icon: "display-brightness-symbolic"
                        iconColor: Theme.notchText
                        value: root.screenBrightness
                        valueText: Math.round(root.screenBrightness * 100) + "%"
                        onSliderMoved: (newVal) => root.setBrightness(newVal)
                        onSliderReleased: {
                            if (root.brightnessBackend === "ddc")
                                root.applyDdcBrightness();
                        }
                    }


                    Item { Layout.fillHeight: true }
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW B: WI-FI NETWORKS LIST (Sub-view)
                // ═════════════════════════════════════════════════════════════
                WifiPage {
                    anchors.fill: parent
                    visible: root.currentView === "wifi"
                    networks: root.wifiNetworks
                    wifiEnabled: root.wifiEnabled
                    connectingSsid: root.connectingSsid
                    networkError: root.networkError
                    onBackClicked: ShellState.quickSettingsCapsuleView = "main"
                    onRescanClicked: root.rescanWifi()
                    onConnectClicked: (ssid, pwd) => root.connectWifi(ssid, pwd)
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW C: BLUETOOTH DEVICE LIST (Sub-view)
                // ═════════════════════════════════════════════════════════════
                BluetoothPage {
                    anchors.fill: parent
                    visible: root.currentView === "bluetooth"
                    devices: root.bluetoothDevices
                    bluetoothEnabled: root.bluetoothEnabled
                    connectingBtAddress: root.connectingBtAddress
                    bluetoothError: root.bluetoothError
                    onBackClicked: ShellState.quickSettingsCapsuleView = "main"
                    onRefreshClicked: root.refreshBluetooth()
                    onConnectClicked: (addr) => root.connectBluetooth(addr)
                    onDisconnectClicked: (addr) => root.disconnectBluetooth(addr)
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW D: HOTSPOT CONFIGURATION & CLIENTS (Sub-view)
                // ═════════════════════════════════════════════════════════════
                HotspotPage {
                    anchors.fill: parent
                    visible: root.currentView === "hotspot"
                    hotspotAvailable: root.hotspotAvailable
                    hotspotEnabled: root.hotspotEnabled
                    hotspotSsid: root.hotspotSsid
                    hotspotPassword: root.hotspotPassword
                    hotspotError: root.hotspotError
                    hotspotSaveSuccess: root.hotspotSaveSuccess
                    hotspotClients: root.hotspotClients
                    actionRunning: hotspotActionProcess.running
                    configureRunning: hotspotConfigureProcess.running
                    onBackClicked: ShellState.quickSettingsCapsuleView = "main"
                    onRefreshClicked: networkStatusProcess.running = true
                    onToggleClicked: root.toggleHotspot()
                    onSaveClicked: (ssid, pwd) => root.configureHotspot(ssid, pwd)
                }
            }
        }
}
