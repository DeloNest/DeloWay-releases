import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        right: I18n.isRTL
        left: !I18n.isRTL
    }

    readonly property real bottomRadius: 22
    readonly property real shadowMargin: 4

    margins {
        top: 0
        right: I18n.isRTL ? (12 - shadowMargin) : 0
        left: !I18n.isRTL ? (12 - shadowMargin) : 0
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:quicksettings-capsule"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────────
    // Dimensions & State (Matching Notch smooth transitions)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property bool isExpanded: ShellState.quickSettingsCapsuleExpanded
    readonly property string currentView: ShellState.quickSettingsCapsuleView

    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(2 * bottomRadius + 20, compactRow.implicitWidth + 2 * bottomRadius + 20)
    readonly property real expandedWidth: 416
    readonly property real expandedHeight: {
        if (root.currentView === "wifi") return 360;
        if (root.currentView === "bluetooth") return 360;
        if (root.currentView === "hotspot") return 390;
        return 320;
    }

    property real currentWidth: isExpanded ? expandedWidth : compactWidth
    property real currentHeight: isExpanded ? expandedHeight : compactHeight
    property bool expandedContentReady: false

    function checkExpansionComplete() {
        if (root.isExpanded && !widthAnim.running && !heightAnim.running) {
            root.expandedContentReady = true;
        }
    }

    Behavior on currentWidth {
        NumberAnimation {
            id: widthAnim
            duration: Theme.motionBase
            easing.type: Theme.easingEnter
            onRunningChanged: {
                if (!running) root.checkExpansionComplete();
            }
        }
    }

    Behavior on currentHeight {
        NumberAnimation {
            id: heightAnim
            duration: Theme.motionBase
            easing.type: Theme.easingEnter
            onRunningChanged: {
                if (!running) root.checkExpansionComplete();
            }
        }
    }

    implicitWidth: Math.round(currentWidth + shadowMargin * 2)
    implicitHeight: Math.round(currentHeight + 8) // Shadow margin

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
            if (!widthAnim.running && !heightAnim.running) {
                root.expandedContentReady = true;
            }
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
            root.expandedContentReady = false;
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
    Item {
        anchors.fill: parent

        // Ambient Drop Shadow (Matches Notch depth)
        Rectangle {
            anchors.fill: capsuleBody
            anchors.topMargin: 4
            anchors.bottomMargin: -4
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: capsuleBody.bottomLeftRadius + 2
            color: Theme.notchShadow
            opacity: root.isExpanded ? 1.0 : 0.0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }
            z: 0
        }

        // Main Capsule Body (Pure solid deep black, OLED notch feel)
        Rectangle {
            id: capsuleBody
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.currentWidth
            height: root.currentHeight
            color: Theme.notchBackground
            border.color: "transparent"
            border.width: 0
            clip: true
            z: 1

            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.isExpanded ? Theme.notchRadiusWindow : root.bottomRadius
            bottomRightRadius: root.isExpanded ? Theme.notchRadiusWindow : root.bottomRadius

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ── Stage 1: Compact View ────────────────────────────────────────
            Item {
                id: compactView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: root.compactHeight
                visible: !root.isExpanded
                opacity: root.isExpanded ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                WheelHandler {
                    enabled: !root.isExpanded
                    onWheel: (wheel) => {
                        if (root.isExpanded) return;
                        if (wheel.angleDelta.y < 0) {
                            ShellState.openAppDrawer();
                        } else if (wheel.angleDelta.y > 0) {
                            ShellState.closeAppDrawer();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        ShellState.openQuickSettingsCapsule("main");
                    }
                    onWheel: (wheel) => {
                        if (root.isExpanded) return;
                        if (wheel.angleDelta.y < 0) {
                            ShellState.openAppDrawer();
                        } else if (wheel.angleDelta.y > 0) {
                            ShellState.closeAppDrawer();
                        }
                    }
                }

                RowLayout {
                    id: compactRow
                    anchors.centerIn: parent
                    spacing: 10

                    // Network display area (Clickable to toggle/expand Wi-Fi & Hotspot)
                    Item {
                        id: networkCompactSection
                        implicitWidth: netRow.implicitWidth
                        implicitHeight: netRow.implicitHeight
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            id: netRow
                            anchors.fill: parent
                            spacing: 6

                            SymbolicIcon {
                                iconSize: 14
                                source: SystemMonitor.isWifi ? "network-wireless-symbolic" : "network-wired-symbolic"
                                iconColor: SystemMonitor.isOnline ? Theme.notchText : Theme.notchTextTertiary
                            }

                            Text {
                                id: ssidLabel
                                visible: SystemMonitor.isWifi && text.length > 0
                                text: root.wifiSsid
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.notchText
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                                renderType: Theme.renderType
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                ShellState.toggleQuickSettingsCapsule("wifi");
                            }
                        }
                    }

                    // Settings icon area (Clickable to toggle/expand Main controls)
                    Item {
                        implicitWidth: 16
                        implicitHeight: 16
                        Layout.alignment: Qt.AlignVCenter

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "settings-symbolic"
                            iconColor: settingsIconMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        }

                        MouseArea {
                            id: settingsIconMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                ShellState.toggleQuickSettingsCapsule("main");
                            }
                        }
                    }
                }
            }

            // ── Stage 2: Expanded View ───────────────────────────────────────
            Item {
                id: expandedView
                width: root.expandedWidth - 24
                height: root.expandedHeight - 24
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.leftMargin: 12
                visible: root.isExpanded && root.expandedContentReady
                opacity: root.expandedContentReady ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.motionFast
                        easing.type: Theme.easingEnter
                    }
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW A: MAIN CONTROLS (Wi-Fi, BT, Volume, Brightness)
                // ═════════════════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    visible: root.currentView === "main"

                    // Header: Quick Settings title + close button
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        Text {
                            text: I18n.isRTL ? "إعدادات سريعة" : "Quick Settings"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: Theme.notchRadiusPill
                            color: closeMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 10
                                color: closeMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    ShellState.closeQuickSettingsCapsule();
                                }
                            }
                        }
                    }

                    // ── Row 1: Wi-Fi Card + Bluetooth Card (2-Column Grid) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        spacing: 8

                        // ── Wi-Fi Card ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            radius: Theme.notchRadiusCard
                            color: wifiTileMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                            border.color: root.wifiEnabled ? Theme.notchBorderHighlight : Theme.notchBorder
                            border.width: 1
                            scale: wifiTileMa.pressed ? 0.98 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            MouseArea {
                                id: wifiTileMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    ShellState.quickSettingsCapsuleView = "wifi";
                                    root.rescanWifi();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Clickable Wi-Fi Icon Circle (Toggle radio on/off)
                                Rectangle {
                                    id: wifiIconCircle
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: 16
                                    color: root.wifiEnabled
                                           ? (root.wifiSsid.length > 0 ? Theme.notchText : Theme.notchBorderHighlight)
                                           : Theme.notchSurfaceElevated

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: "network-wireless-symbolic"
                                        iconSize: 16
                                        iconColor: root.wifiEnabled && root.wifiSsid.length > 0 ? Theme.notchBackground : (root.wifiEnabled ? Theme.notchText : Theme.notchTextTertiary)
                                    }

                                    MouseArea {
                                        id: wifiToggleMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.toggleWifi()
                                    }
                                }

                                // Text details
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Wi-Fi"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
                                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: !root.wifiEnabled
                                              ? (I18n.isRTL ? "معطل" : "Off")
                                              : (root.wifiSsid.length > 0 ? root.wifiSsid : (I18n.isRTL ? "غير متصل" : "Disconnected"))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 10
                                        color: (root.wifiEnabled && root.wifiSsid.length > 0) ? Theme.notchTextSecondary : Theme.notchTextTertiary
                                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Chevron
                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: wifiTileMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // ── Bluetooth Card ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            radius: Theme.notchRadiusCard
                            color: btTileMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                            border.color: root.bluetoothEnabled ? Theme.notchBorderHighlight : Theme.notchBorder
                            border.width: 1
                            scale: btTileMa.pressed ? 0.98 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            MouseArea {
                                id: btTileMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    ShellState.quickSettingsCapsuleView = "bluetooth";
                                    root.refreshBluetooth();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Clickable Bluetooth Icon Circle (Toggle radio on/off)
                                Rectangle {
                                    id: btIconCircle
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: 16
                                    color: root.bluetoothConnectedDevice.length > 0
                                           ? Theme.notchText
                                           : (root.bluetoothEnabled ? Theme.notchBorderHighlight : Theme.notchSurfaceElevated)

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: root.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
                                        iconSize: 16
                                        iconColor: root.bluetoothConnectedDevice.length > 0
                                                   ? Theme.notchBackground
                                                   : (root.bluetoothEnabled ? Theme.notchText : Theme.notchTextTertiary)
                                    }

                                    MouseArea {
                                        id: btToggleMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.toggleBluetooth()
                                    }
                                }

                                // Text details
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Bluetooth"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
                                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: !root.bluetoothEnabled
                                              ? (I18n.isRTL ? "معطل" : "Off")
                                              : (root.bluetoothConnectedDevice.length > 0
                                                 ? root.bluetoothConnectedDevice
                                                 : (I18n.isRTL ? "لا يوجد جهاز" : "No device"))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 10
                                        color: (root.bluetoothEnabled && root.bluetoothConnectedDevice.length > 0) ? Theme.notchTextSecondary : Theme.notchTextTertiary
                                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Chevron
                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: btTileMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }

                    // ── Row 2: Hotspot Card + Circular Quick Toggles ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        spacing: 8

                        // ── Hotspot Card (Status Card with Drilldown) ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            radius: Theme.notchRadiusCard
                            color: hotspotTileMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                            border.color: root.hotspotEnabled ? Theme.notchBorderHighlight : Theme.notchBorder
                            border.width: 1
                            scale: hotspotTileMa.pressed ? 0.98 : 1.0

                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            MouseArea {
                                id: hotspotTileMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    ShellState.quickSettingsCapsuleView = "hotspot";
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Clickable Hotspot Icon Circle (Toggle hotspot on/off)
                                Rectangle {
                                    id: hotspotIconCircle
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: 16
                                    color: root.hotspotEnabled
                                           ? Theme.notchText
                                           : Theme.notchSurfaceElevated

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: "network-wireless-hotspot-symbolic"
                                        iconSize: 16
                                        iconColor: root.hotspotEnabled
                                                   ? Theme.notchBackground
                                                   : Theme.notchTextTertiary
                                    }

                                    MouseArea {
                                        id: hotspotToggleMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        enabled: root.hotspotAvailable && !hotspotActionProcess.running
                                        onClicked: root.toggleHotspot()
                                    }
                                }

                                // Text details
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: I18n.isRTL ? "نقطة اتصال" : "Hotspot"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
                                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: !root.hotspotAvailable
                                              ? (I18n.isRTL ? "غير متوفرة" : "Unavailable")
                                              : (root.hotspotEnabled
                                                 ? (root.hotspotClients.length > 0
                                                    ? (root.hotspotClients.length + (I18n.isRTL ? " متصل" : " connected"))
                                                    : (I18n.isRTL ? "مفعّلة" : "Active"))
                                                 : (I18n.isRTL ? "معطلة" : "Disabled"))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 10
                                        color: root.hotspotEnabled ? Theme.notchTextSecondary : Theme.notchTextTertiary
                                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Chevron
                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: hotspotTileMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // ── Circular Quick Toggles (Night Light + Quick Mute) ──
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            spacing: 8

                            // Night Light Card / Button
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.notchRadiusCard
                                color: eyeComfortMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                                border.color: root.nightLightEnabled ? Qt.rgba(0.95, 0.65, 0.25, 0.45) : Theme.notchBorder
                                border.width: 1
                                scale: eyeComfortMa.pressed ? 0.98 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: root.nightLightEnabled ? Qt.rgba(0.95, 0.65, 0.25, 0.25) : "transparent"

                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            source: "night-light-symbolic"
                                            iconSize: 16
                                            iconColor: root.nightLightEnabled ? Qt.rgba(1.0, 0.78, 0.40, 1.0) : Theme.notchTextSecondary
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: I18n.isRTL ? "إضاءة ليلية" : "Night Light"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: root.nightLightEnabled ? Theme.notchText : Theme.notchTextTertiary
                                    }
                                }

                                MouseArea {
                                    id: eyeComfortMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.toggleNightLight()
                                }
                            }

                            // Quick Mute Card / Button
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.notchRadiusCard
                                color: quickMuteMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                                border.color: root.isMuted ? Qt.rgba(0.94, 0.27, 0.27, 0.45) : Theme.notchBorder
                                border.width: 1
                                scale: quickMuteMa.pressed ? 0.98 : 1.0

                                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: root.isMuted ? Qt.rgba(0.94, 0.27, 0.27, 0.22) : "transparent"

                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            source: root.isMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                                            iconSize: 16
                                            iconColor: root.isMuted ? "#f87171" : Theme.notchTextSecondary
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.isMuted ? (I18n.isRTL ? "مكتوم" : "Muted") : (I18n.isRTL ? "كتم" : "Mute")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: root.isMuted ? "#f87171" : Theme.notchTextTertiary
                                    }
                                }

                                MouseArea {
                                    id: quickMuteMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.toggleMute()
                                }
                            }
                        }
                    }

                    // ── Row 3: Sound Card (Title + Percentage + Details Chevron + Interactive Slider) ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: Theme.notchRadiusCard
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 6

                            // Top Header Row: Icon + Title + Value + Chevron
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                SymbolicIcon {
                                    source: root.volumeIconName + "-symbolic"
                                    iconSize: 14
                                    iconColor: root.isMuted ? Theme.notchTextTertiary : Theme.notchText
                                }

                                Text {
                                    text: I18n.isRTL ? "الصوت" : "Sound"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.notchText
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.isMuted
                                          ? (I18n.isRTL ? "مكتوم" : "Muted")
                                          : (Math.round(root.currentVolume * 100) + "%")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: root.isMuted ? Theme.notchTextTertiary : Theme.notchTextSecondary
                                }

                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Theme.notchTextTertiary
                                }
                            }

                            // Bottom Slider Row: Interactive Volume Slider
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18

                                Rectangle {
                                    id: volumeTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 5
                                    radius: 2.5
                                    color: Qt.rgba(1, 1, 1, 0.12)

                                    Rectangle {
                                        id: volumeFill
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        width: parent.width * Math.max(0, Math.min(1, root.isMuted ? 0 : root.currentVolume))
                                        radius: 2.5
                                        color: root.isMuted ? Theme.notchTextTertiary : Theme.notchText

                                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                    }

                                    Rectangle {
                                        id: volumeThumb
                                        visible: !root.isMuted && root.currentVolume > 0.01
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: Theme.notchText
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(parent.width - width, I18n.isRTL ? (parent.width - volumeFill.width - width / 2) : (volumeFill.width - width / 2)))

                                        border.color: Qt.rgba(0, 0, 0, 0.25)
                                        border.width: 1
                                    }
                                }

                                MouseArea {
                                    id: volumeSliderMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    function updateVolume(mouse) {
                                        const raw = I18n.isRTL ? ((width - mouse.x) / width) : (mouse.x / width);
                                        root.setVolume(Math.max(0, Math.min(1, raw)));
                                    }

                                    onPressed: mouse => updateVolume(mouse)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            updateVolume(mouse);
                                    }
                                }
                            }
                        }
                    }

                    // ── Row 4: Display Card (Title + Percentage + Details Chevron + Interactive Slider) ──
                    Rectangle {
                        visible: root.brightnessBackend !== "none"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: Theme.notchRadiusCard
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 6

                            // Top Header Row: Icon + Title + Value + Chevron
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                SymbolicIcon {
                                    source: "display-brightness-symbolic"
                                    iconSize: 14
                                    iconColor: Theme.notchText
                                }

                                Text {
                                    text: I18n.isRTL ? "السطوع" : "Display"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.notchText
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: Math.round(root.screenBrightness * 100) + "%"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.notchTextSecondary
                                }

                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Theme.notchTextTertiary
                                }
                            }

                            // Bottom Slider Row: Interactive Brightness Slider
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18

                                Rectangle {
                                    id: brightnessTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 5
                                    radius: 2.5
                                    color: Qt.rgba(1, 1, 1, 0.12)

                                    Rectangle {
                                        id: brightnessFill
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        width: parent.width * Math.max(0, Math.min(1, root.screenBrightness))
                                        radius: 2.5
                                        color: Theme.notchText
                                    }

                                    Rectangle {
                                        id: brightnessThumb
                                        visible: root.screenBrightness > 0.01
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: Theme.notchText
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(parent.width - width, I18n.isRTL ? (parent.width - brightnessFill.width - width / 2) : (brightnessFill.width - width / 2)))

                                        border.color: Qt.rgba(0, 0, 0, 0.25)
                                        border.width: 1
                                    }
                                }

                                MouseArea {
                                    id: brightnessSliderMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    function updateBrightness(mouse) {
                                        const raw = I18n.isRTL ? ((width - mouse.x) / width) : (mouse.x / width);
                                        root.setBrightness(Math.max(0, Math.min(1, raw)));
                                    }

                                    onPressed: mouse => updateBrightness(mouse)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            updateBrightness(mouse);
                                    }
                                    onReleased: {
                                        if (root.brightnessBackend === "ddc")
                                            root.applyDdcBrightness();
                                    }
                                    onCanceled: {
                                        if (root.brightnessBackend === "ddc")
                                            root.applyDdcBrightness();
                                    }
                                }
                            }

                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW B: WI-FI NETWORKS LIST (Sub-view)
                // ═════════════════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    visible: root.currentView === "wifi"

                    // Header: Back button + Title + Rescan button
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 6

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: backMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: I18n.isRTL ? "›" : "‹"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: Theme.notchText
                            }

                            MouseArea {
                                id: backMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: ShellState.quickSettingsCapsuleView = "main"
                            }
                        }

                        Text {
                            text: I18n.isRTL ? "شبكات Wi-Fi" : "Wi-Fi Networks"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: rescanMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "⟳"
                                font.pixelSize: 14
                                color: rescanMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: rescanMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.rescanWifi()
                            }
                        }
                    }

                    // Available Networks Title
                    Text {
                        text: I18n.isRTL ? "الشبكات المتاحة" : "Available Networks"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.notchTextSecondary
                        Layout.topMargin: 2
                    }

                    // Available Networks List
                    ListView {
                        id: wifiListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: root.wifiNetworks

                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: wifiListView.contentHeight > wifiListView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            width: 4
                            contentItem: Rectangle {
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.25)
                            }
                        }

                        delegate: Rectangle {
                            id: netItem
                            required property var modelData
                            required property int index

                            readonly property bool isCurrent: netItem.modelData && netItem.modelData.connected
                            readonly property bool isConnecting: root.connectingSsid.length > 0 && netItem.modelData && root.connectingSsid === netItem.modelData.ssid

                            width: wifiListView.width - (wifiListView.contentHeight > wifiListView.height ? 6 : 0)
                            implicitHeight: 34
                            radius: Theme.notchRadiusPill
                            color: isCurrent
                                   ? Qt.rgba(1, 1, 1, 0.14)
                                   : (netMa.containsMouse ? Theme.notchSurfaceHover : "transparent")

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                SymbolicIcon {
                                    source: "network-wireless-symbolic"
                                    iconSize: 14
                                    iconColor: netItem.isCurrent ? Theme.notchText : Theme.notchTextSecondary
                                }

                                Text {
                                    text: netItem.modelData && netItem.modelData.ssid ? netItem.modelData.ssid : ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: netItem.isCurrent ? Font.DemiBold : Font.Normal
                                    color: Theme.notchText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                SymbolicIcon {
                                    visible: netItem.modelData && netItem.modelData.security && netItem.modelData.security !== "Open"
                                    source: "system-lock-screen-symbolic"
                                    iconSize: 11
                                    iconColor: Theme.notchTextTertiary
                                }

                                Text {
                                    text: netItem.isConnecting
                                          ? (I18n.isRTL ? "جارٍ الاتصال..." : "Connecting...")
                                          : (netItem.isCurrent ? "✓" : "")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    color: netItem.isCurrent ? Theme.notchText : Theme.notchTextTertiary
                                }
                            }

                            MouseArea {
                                id: netMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    if (netItem.modelData && netItem.modelData.ssid) {
                                        root.connectWifi(netItem.modelData.ssid, "");
                                    }
                                }
                            }
                        }

                        // Empty State if no networks or on error
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: !root.wifiEnabled || root.wifiNetworks.length === 0

                            SymbolicIcon {
                                Layout.alignment: Qt.AlignHCenter
                                visible: root.networkError.length > 0
                                source: "dialog-warning-symbolic"
                                iconSize: 18
                                iconColor: Theme.notchTextTertiary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.networkError.length > 0
                                      ? root.networkError
                                      : (!root.wifiEnabled
                                         ? (I18n.isRTL ? "Wi-Fi معطل" : "Wi-Fi is disabled")
                                         : (I18n.isRTL ? "لا توجد شبكات متاحة" : "No networks found"))
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                color: Theme.notchTextTertiary
                            }
                        }
                    }
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW C: BLUETOOTH DEVICE LIST
                // ═════════════════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    visible: root.currentView === "bluetooth"

                    // Header: Back button + Title + Refresh button
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 8

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: btBackMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: I18n.isRTL ? "›" : "‹"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: Theme.notchText
                            }

                            MouseArea {
                                id: btBackMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: ShellState.quickSettingsCapsuleView = "main"
                            }
                        }

                        Text {
                            text: I18n.isRTL ? "أجهزة Bluetooth" : "Bluetooth Devices"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: btRescanMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "⟳"
                                font.pixelSize: 14
                                color: btRescanMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: btRescanMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.refreshBluetooth()
                            }
                        }
                    }

                    // Available Bluetooth Devices List
                    ListView {
                        id: btListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: root.bluetoothDevices

                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: btListView.contentHeight > btListView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            width: 4
                            contentItem: Rectangle {
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.25)
                            }
                        }

                        delegate: Rectangle {
                            id: btItem
                            required property var modelData
                            required property int index

                            readonly property bool isCurrent: btItem.modelData && btItem.modelData.connected
                            readonly property bool isConnecting: root.connectingBtAddress.length > 0 && btItem.modelData && root.connectingBtAddress === btItem.modelData.address
                            readonly property bool isPaired: btItem.modelData && btItem.modelData.paired

                            width: btListView.width - (btListView.contentHeight > btListView.height ? 6 : 0)
                            implicitHeight: 34
                            radius: Theme.notchRadiusPill
                            color: isCurrent
                                   ? Qt.rgba(1, 1, 1, 0.14)
                                   : (btItemMa.containsMouse ? Theme.notchSurfaceHover : "transparent")

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                SymbolicIcon {
                                    source: btItem.modelData && btItem.modelData.icon ? btItem.modelData.icon : "bluetooth-active-symbolic"
                                    iconSize: 14
                                    iconColor: btItem.isCurrent ? Theme.notchText : Theme.notchTextSecondary
                                }

                                Text {
                                    text: btItem.modelData && btItem.modelData.name ? btItem.modelData.name : ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: btItem.isCurrent ? Font.DemiBold : Font.Normal
                                    color: Theme.notchText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: btItem.isConnecting
                                          ? (I18n.isRTL ? "جارٍ الاتصال..." : "Connecting...")
                                          : (btItem.isCurrent
                                             ? "✓"
                                             : (btItem.isPaired
                                                ? (I18n.isRTL ? "مقترن" : "Paired")
                                                : (I18n.isRTL ? "يحتاج اقتران من الإعدادات" : "Pair in Settings")))
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    color: btItem.isCurrent ? Theme.notchText : Theme.notchTextTertiary
                                }
                            }

                            MouseArea {
                                id: btItemMa
                                anchors.fill: parent
                                cursorShape: btItem.isPaired ? Qt.PointingHandCursor : Qt.ArrowCursor
                                hoverEnabled: true
                                onClicked: {
                                    if (!btItem.modelData) return;
                                    if (btItem.modelData.connected) {
                                        root.disconnectBluetooth(btItem.modelData.address);
                                    } else if (btItem.modelData.paired) {
                                        root.connectBluetooth(btItem.modelData.address);
                                    }
                                }
                            }
                        }

                        // Empty State if bluetooth off or no devices
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: !root.bluetoothEnabled || root.bluetoothDevices.length === 0

                            SymbolicIcon {
                                Layout.alignment: Qt.AlignHCenter
                                visible: root.bluetoothError.length > 0
                                source: "dialog-warning-symbolic"
                                iconSize: 18
                                iconColor: Theme.notchTextTertiary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.bluetoothError.length > 0
                                      ? root.bluetoothError
                                      : (!root.bluetoothEnabled
                                         ? (I18n.isRTL ? "البلوتوث معطل" : "Bluetooth is disabled")
                                         : (I18n.isRTL ? "لا توجد أجهزة مقترنة" : "No paired devices"))
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                color: Theme.notchTextTertiary
                            }
                        }
                    }
                }

                // ═════════════════════════════════════════════════════════════
                // VIEW D: HOTSPOT CONFIGURATION & CLIENTS (Sub-view)
                // ═════════════════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: root.currentView === "hotspot"

                    // Header: Back button + Title + Refresh
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 8

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: hotspotBackMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchBackground
                            border.color: Theme.notchBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: I18n.isRTL ? "→" : "←"
                                font.pixelSize: 14
                                color: Theme.notchText
                            }

                            MouseArea {
                                id: hotspotBackMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: ShellState.quickSettingsCapsuleView = "main"
                            }
                        }

                        Text {
                            text: I18n.isRTL ? "إعدادات نقطة الاتصال" : "Hotspot Settings"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: hotspotRefreshMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "⟳"
                                font.pixelSize: 14
                                color: hotspotRefreshMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: hotspotRefreshMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: networkStatusProcess.running = true
                            }
                        }
                    }

                    // Large Toggle Switch Card (Hotspot State)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Theme.notchRadiusCard
                        color: Theme.notchSurfaceElevated
                        border.color: root.hotspotEnabled ? Theme.accent : Theme.notchBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            SymbolicIcon {
                                source: "network-wireless-hotspot-symbolic"
                                iconSize: 18
                                iconColor: root.hotspotEnabled ? Theme.accent : Theme.notchTextSecondary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: I18n.isRTL ? "نقطة الاتصال الشخصية" : "Personal Hotspot"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.notchText
                                }

                                Text {
                                    text: {
                                        if (!root.hotspotAvailable) return I18n.isRTL ? "غير متوفرة" : "Unavailable";
                                        if (root.hotspotEnabled) return I18n.isRTL ? ("مفعلة • " + (root.hotspotSsid || "Hotspot")) : ("Active • " + (root.hotspotSsid || "Hotspot"));
                                        return I18n.isRTL ? "معطلة" : "Disabled";
                                    }
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    color: root.hotspotEnabled ? Theme.accent : Theme.notchTextSecondary
                                    elide: Text.ElideRight
                                }
                            }

                            // Switch Pill
                            Rectangle {
                                width: 44
                                height: 24
                                radius: 12
                                color: root.hotspotEnabled ? Theme.accent : Theme.notchBackground
                                border.color: Theme.notchBorder
                                border.width: 1
                                opacity: root.hotspotAvailable && !hotspotActionProcess.running ? 1.0 : 0.5

                                Rectangle {
                                    x: root.hotspotEnabled ? (I18n.isRTL ? 4 : 24) : (I18n.isRTL ? 24 : 4)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: Theme.textOnAccent
                                    Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.hotspotAvailable && !hotspotActionProcess.running
                                    cursorShape: root.hotspotAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.toggleHotspot()
                                }
                            }
                        }
                    }

                    // Configuration Card (SSID, Password, Save)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: hotspotConfigCol.implicitHeight + 16
                        radius: Theme.notchRadiusCard
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        Connections {
                            target: root
                            function onHotspotSsidChanged() {
                                if (!ssidInput.activeFocus) {
                                    ssidInput.text = root.hotspotSsid;
                                }
                            }
                            function onHotspotPasswordChanged() {
                                if (!pwdInput.activeFocus) {
                                    pwdInput.text = root.hotspotPassword;
                                }
                            }
                        }

                        ColumnLayout {
                            id: hotspotConfigCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // SSID Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: I18n.isRTL ? "الاسم:" : "SSID:"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.notchTextSecondary
                                    Layout.preferredWidth: 38
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 26
                                    radius: Theme.notchRadiusPill
                                    color: Theme.notchBackground
                                    border.color: ssidInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorder
                                    border.width: 1

                                    TextInput {
                                        id: ssidInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.notchText
                                        text: root.hotspotSsid
                                        selectByMouse: true
                                        clip: true
                                        onTextChanged: root.hotspotSaveSuccess = ""
                                    }
                                }
                            }

                            // Password Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: I18n.isRTL ? "السر:" : "Pass:"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.notchTextSecondary
                                    Layout.preferredWidth: 38
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 26
                                    radius: Theme.notchRadiusPill
                                    color: Theme.notchBackground
                                    border.color: pwdInput.activeFocus ? Theme.notchBorderHighlight : (pwdInput.text.length < 8 && pwdInput.text.length > 0 ? "#EF4444" : Theme.notchBorder)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 4
                                        spacing: 4

                                        TextInput {
                                            id: pwdInput
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.notchText
                                            text: root.hotspotPassword
                                            echoMode: showPwdBtn.showPassword ? TextInput.Normal : TextInput.Password
                                            selectByMouse: true
                                            clip: true
                                            onTextChanged: root.hotspotSaveSuccess = ""
                                        }

                                        Rectangle {
                                            id: showPwdBtn
                                            property bool showPassword: false
                                            implicitWidth: pwdToggleText.implicitWidth + 10
                                            implicitHeight: 20
                                            radius: 10
                                            color: eyeMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                                            Text {
                                                id: pwdToggleText
                                                anchors.centerIn: parent
                                                text: showPwdBtn.showPassword ? (I18n.isRTL ? "إخفاء" : "Hide") : (I18n.isRTL ? "إظهار" : "Show")
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                color: eyeMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                            }

                                            MouseArea {
                                                id: eyeMa
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: showPwdBtn.showPassword = !showPwdBtn.showPassword
                                            }
                                        }
                                    }
                                }
                            }

                            // Save Button Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (root.hotspotError.length > 0) return root.hotspotError;
                                        if (root.hotspotSaveSuccess.length > 0) return root.hotspotSaveSuccess;
                                        if (pwdInput.text.length < 8) return (I18n.isRTL ? "كلمة المرور 8 خانات كحد أدنى" : "Password must be >= 8 chars");
                                        return "";
                                    }
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    color: {
                                        if (root.hotspotError.length > 0 || (pwdInput.text.length < 8 && pwdInput.text.length > 0)) return "#EF4444";
                                        if (root.hotspotSaveSuccess.length > 0) return "#10B981";
                                        return Theme.notchTextTertiary;
                                    }
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    implicitWidth: 60
                                    implicitHeight: 24
                                    radius: Theme.notchRadiusPill
                                    color: saveBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchBackground
                                    border.color: canSave ? Theme.notchBorderHighlight : Theme.notchBorder
                                    border.width: 1
                                    opacity: canSave && !hotspotConfigureProcess.running ? 1.0 : 0.4

                                    readonly property bool canSave: ssidInput.text.trim().length > 0 && pwdInput.text.length >= 8 && (ssidInput.text.trim() !== root.hotspotSsid || pwdInput.text !== root.hotspotPassword)

                                    Text {
                                        anchors.centerIn: parent
                                        text: hotspotConfigureProcess.running ? "..." : (I18n.isRTL ? "حفظ" : "Save")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: parent.canSave ? Theme.notchText : Theme.notchTextTertiary
                                    }

                                    MouseArea {
                                        id: saveBtnMa
                                        anchors.fill: parent
                                        enabled: parent.canSave && !hotspotConfigureProcess.running
                                        cursorShape: parent.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            root.configureHotspot(ssidInput.text.trim(), pwdInput.text);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Connected Devices Section Title
                    Text {
                        text: I18n.isRTL ? "الأجهزة المتصلة" : "Connected Devices"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.notchTextSecondary
                        Layout.topMargin: 2
                    }

                    // Connected Devices Box / List
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.notchRadiusCard
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1
                        clip: true

                        ListView {
                            id: clientsListView
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4
                            clip: true
                            model: root.hotspotClients

                            delegate: Rectangle {
                                width: clientsListView.width
                                height: 32
                                radius: 6
                                color: clientMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    SymbolicIcon {
                                        source: "computer-symbolic"
                                        iconSize: 14
                                        iconColor: Theme.notchTextSecondary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData.hostname || modelData.ip || modelData.mac
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Theme.notchText
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: (modelData.ip ? modelData.ip + " • " : "") + (modelData.mac || "")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 9
                                            color: Theme.notchTextTertiary
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: clientMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            // Empty State
                            Text {
                                anchors.centerIn: parent
                                visible: clientsListView.count === 0
                                text: !root.hotspotEnabled
                                      ? (I18n.isRTL ? "قم بتفعيل نقطة الاتصال لعرض الأجهزة" : "Enable hotspot to see connected devices")
                                      : (I18n.isRTL ? "لا توجد أجهزة متصلة حالياً" : "No devices currently connected")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 10
                                color: Theme.notchTextTertiary
                            }
                        }
                    }
                }
            }
        }
    }
}
