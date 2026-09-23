import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../theme"
import "../services"
import "./quicksettings"
import "./quicksettings/pages"

// Lives inside the unified TopBar window (TopBar.qml) as a plain Item, so its container is
// composed in the same buffer as the Notch: reflow is a pure scene-graph animation with
// no layer-shell margins, no cross-surface repaint timing and no collision.
Item {
    id: root

    required property ShellScreen targetScreen
    anchors.fill: parent

    // Exposed to TopBar for the unified input mask.
    readonly property alias maskItem: capsuleContainer

    readonly property real earRadius: Theme.notchEarRadius
    readonly property real bottomRadius: 26
    readonly property real capsuleGap: Theme.capsuleGap

    // Distance from the screen centre to the capsule body's leading edge. Tracks the
    // Notch's live outer width every animation frame, clamped to the screen edge.
    readonly property real notchSlotOffset: {
        const desired = ShellState.smartNotchCurrentWidth / 2 + root.capsuleGap;
        const bodyWidth = root.currentWidth + root.earRadius * 2 * root.expandProgress;
        const maxOffset = root.width / 2 - Theme.capsuleEdgeMargin - bodyWidth;
        return Math.round(Math.max(0, Math.min(desired, maxOffset)));
    }

    // Escape dismissal (active when capsule has focus)
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

    // ─────────────────────────────────────────────────────────────────────────
    // Dimensions & State (Unified OutCubic single-driver motion)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property bool isExpanded: ShellState.quickSettingsCapsuleExpanded
    readonly property string currentView: ShellState.quickSettingsCapsuleView

    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(108, compactRow.implicitWidth + 36)
    readonly property real expandedWidth: 456
    readonly property int contentTopMargin: 16
    readonly property int contentBottomMargin: 14

    // ── Page model ───────────────────────────────────────────────────────
    // "main" sizes to its content; detail pages share one fixed, scrollable height.
    // pageHeight is the single animated number that morphs the capsule between pages,
    // in lock-step with the horizontal slide (no jumps, no Loader churn).
    readonly property int detailPageHeight: 420
    readonly property real targetPageHeight: root.currentView === "main" ? mainPage.implicitHeight : root.detailPageHeight
    property real pageHeight: targetPageHeight
    Behavior on pageHeight {
        enabled: root.isExpanded
        NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
    }
    readonly property real expandedHeight: root.contentTopMargin + root.contentBottomMargin + root.pageHeight
    readonly property real slideSign: I18n.isRTL ? -1 : 1

    // Single unified motion driver (200ms open, 160ms close)
    property real expandProgress: root.isExpanded ? 1.0 : 0.0
    Behavior on expandProgress {
        NumberAnimation {
            duration: root.isExpanded ? 200 : 160
            easing.type: root.isExpanded ? Easing.OutCubic : Easing.OutQuad
        }
    }

    readonly property real currentWidth: Math.round(root.compactWidth + (root.expandedWidth - root.compactWidth) * root.expandProgress)
    readonly property real currentHeight: Math.round(root.compactHeight + (root.expandedHeight - root.compactHeight) * root.expandProgress)
    readonly property real currentY: Math.round(Theme.topBarMarginTop * (1.0 - root.expandProgress))


    property real _lastPrefetch: 0

    onCurrentViewChanged: {
        if (root.currentView === "hotspot" || root.currentView === "wifi") {
            NetworkService.refresh();
        } else if (root.currentView === "bluetooth") {
            BluetoothService.refresh();
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
    // Network Data Logic (Unified NetworkService Singleton)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property var networkData: NetworkService.networkData
    readonly property bool wifiAvailable: NetworkService.wifiAvailable
    readonly property bool wifiEnabled: NetworkService.wifiEnabled
    readonly property var wifiNetworks: NetworkService.wifiNetworks
    readonly property string connectingSsid: NetworkService.connectingSsid
    readonly property string networkError: NetworkService.networkError
    readonly property string wifiSsid: NetworkService.wifiSsid

    readonly property bool hotspotAvailable: NetworkService.hotspotAvailable
    readonly property bool hotspotEnabled: NetworkService.hotspotEnabled
    readonly property string hotspotSsid: NetworkService.hotspotSsid
    readonly property string hotspotPassword: NetworkService.hotspotPassword
    readonly property string hotspotError: NetworkService.hotspotError
    readonly property string hotspotSaveSuccess: NetworkService.hotspotSaveSuccess
    readonly property var hotspotClients: NetworkService.hotspotClients

    function toggleWifi() {
        NetworkService.toggleWifi();
    }

    function rescanWifi() {
        NetworkService.scanWifi();
    }

    function connectWifi(ssid, password) {
        NetworkService.connectWifi(ssid, password);
    }

    function toggleHotspot() {
        NetworkService.toggleHotspot();
    }

    function configureHotspot(ssid, password) {
        NetworkService.configureHotspot(ssid, password);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bluetooth Data Logic (Unified BluetoothService Singleton)
    // ─────────────────────────────────────────────────────────────────────────
    readonly property var bluetoothData: BluetoothService.bluetoothData
    readonly property bool bluetoothEnabled: BluetoothService.powered
    readonly property var bluetoothDevices: BluetoothService.devices
    readonly property string bluetoothConnectedDevice: BluetoothService.connectedDeviceName
    readonly property string connectingBtAddress: BluetoothService.connectingAddress
    readonly property string bluetoothError: BluetoothService.error

    function toggleBluetooth() {
        BluetoothService.togglePower();
    }

    function refreshBluetooth() {
        BluetoothService.refresh();
    }

    function connectBluetooth(address) {
        BluetoothService.connectDevice(address);
    }

    function disconnectBluetooth(address) {
        BluetoothService.disconnectDevice(address);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Update Strategy (Low Resource Impact)
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Instant fetch upon expanding
    onIsExpandedChanged: {
        if (isExpanded) {
            ShellState.closeSmartNotch();
            ShellState.closeTimeCapsule();
            if (Date.now() - root._lastPrefetch > 2000) {   // hover prefetch already in flight
                NetworkService.refresh();
                BluetoothService.refresh();
            }
            ControlCenterService.refresh();
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
    // Zero polling while collapsed (lazy prefetch on hover / instant fetch on expand)

    // 3. Active Wi-Fi list timer: 10s only when viewing wifi list
    Timer {
        id: wifiViewTimer
        interval: 10000
        running: root.isExpanded && root.currentView === "wifi"
        repeat: true
        onTriggered: {
            NetworkService.refresh();
        }
    }

    // 4. Active Bluetooth list timer: 10s only when viewing bluetooth list
    Timer {
        id: btViewTimer
        interval: 10000
        running: root.isExpanded && root.currentView === "bluetooth"
        repeat: true
        onTriggered: {
            BluetoothService.refresh();
        }
    }

    // 5. Active Hotspot list timer: 10s only when viewing hotspot
    Timer {
        id: hotspotViewTimer
        interval: 10000
        running: root.isExpanded && root.currentView === "hotspot"
        repeat: true
        onTriggered: {
            NetworkService.refresh();
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

    // ── Microphone (default PipeWire source) ─────────────────────────────
    property var audioSource: Pipewire.defaultAudioSource
    PwObjectTracker {
        objects: root.audioSource ? [root.audioSource] : []
    }
    readonly property real micVolume: (audioSource && audioSource.audio) ? audioSource.audio.volume : 0
    readonly property bool micMuted: (audioSource && audioSource.audio) ? audioSource.audio.muted : false

    function setMicVolume(value) {
        if (!root.audioSource || !root.audioSource.audio || !root.audioSource.ready) return;
        const v = Math.max(0, Math.min(1, value));
        root.audioSource.audio.volume = v;
        if (v > 0 && root.audioSource.audio.muted) root.audioSource.audio.muted = false;
    }
    function toggleMicMute() {
        if (!root.audioSource || !root.audioSource.audio || !root.audioSource.ready) return;
        root.audioSource.audio.muted = !root.audioSource.audio.muted;
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
    // DDC writes are slow (~100 ms+) and must not be interrupted mid-transaction:
    // never kill a running write; if the value changed meanwhile, write again after.
    Process {
        id: ddcWriteProcess
        property bool pending: false
        onExited: if (pending) { pending = false; root.applyDdcBrightness(); }
    }
    Timer {
        id: ddcWriteDebounce
        interval: 250
        onTriggered: root.applyDdcBrightness()
    }

    function applyDdcBrightness() {
        if (root.brightnessBackend !== "ddc")
            return;
        if (ddcWriteProcess.running) { ddcWriteProcess.pending = true; return; }
        const pct = Math.max(0, Math.min(100, Math.round(root.screenBrightness * 100)));
        const disp = root.ddcDisplayNum.length > 0 ? ["--display", root.ddcDisplayNum] : [];
        ddcWriteProcess.command = ["ddcutil"].concat(disp, ["setvcp", "10", String(pct)]);
        ddcWriteProcess.running = true;
    }

    function setBrightness(value) {
        root.screenBrightness = Math.max(0, Math.min(1, value));
        if (root.brightnessBackend === "kernel")
            backlightWriteDebounce.restart();
        else if (root.brightnessBackend === "ddc")     // was never written on DDC monitors
            ddcWriteDebounce.restart();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Night Light / Eye Comfort (via hyprsunset daemon + hyprctl)
    // ─────────────────────────────────────────────────────────────────────────
    property bool nightLightEnabled: false

    Process {
        id: nightLightInitialCheckProcess
        command: ["hyprctl", "hyprsunset", "temperature"]
        onExited: (code) => { if (code !== 0) root.nightLightEnabled = false; }
        stdout: SplitParser {
            onRead: data => {
                root.nightLightEnabled = (parseInt(data.trim(), 10) === 4500);
            }
        }
    }

    // Optimistic flip for responsiveness, then read hyprsunset back so the tile
    // reflects what actually happened (e.g. hyprsunset missing or not running).
    Process {
        id: nightLightSetProcess
        onExited: nightLightInitialCheckProcess.running = true
    }
    function toggleNightLight() {
        const next = !root.nightLightEnabled;
        root.nightLightEnabled = next;
        nightLightSetProcess.exec(["hyprctl", "hyprsunset", "temperature", next ? "4500" : "6000"]);
    }

    Component.onCompleted: {
        backlightDetectProcess.running = true;
        Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset temperature >/dev/null 2>&1 || (nohup hyprsunset >/dev/null 2>&1 &)"]);
        nightLightInitialCheckProcess.running = true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Visual Hierarchy
    // ─────────────────────────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    // Visual Hierarchy (Capsule Container + Ears + Body + Input Mask)
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: capsuleContainer
        // Body leading edge stays at notchSlotOffset; the ear (earRadius wide) grows
        // toward the notch as this capsule itself expands, exactly as before.
        x: Math.round(root.width / 2 + root.notchSlotOffset - root.earRadius * root.expandProgress)
        y: root.currentY
        width: Math.round(root.currentWidth + root.earRadius * 2 * root.expandProgress)
        height: Math.round(root.currentHeight + 8 * root.expandProgress)

        // Soft ambient drop shadow
        Rectangle {
            anchors.fill: capsuleBody
            anchors.topMargin: 6
            anchors.bottomMargin: -6
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: capsuleBody.bottomLeftRadius + 2
            color: Theme.notchShadow            // theme-aware (was a fixed 40% black)
            opacity: root.expandProgress
            visible: opacity > 0.01 && Theme.enableShadows
            z: 0
        }

        // Left Ceiling Ear
        Shape {
            anchors.top: capsuleBody.top
            anchors.right: capsuleBody.left
            width: root.earRadius
            height: root.earRadius
            opacity: Math.max(0, (root.expandProgress - 0.3) / 0.7)
            visible: opacity > 0.01
            z: 1

            ShapePath {
                fillColor: Theme.notchBackground
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: root.earRadius; y: 0 }
                PathLine { x: root.earRadius; y: root.earRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: root.earRadius
                    radiusY: root.earRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        // Right Ceiling Ear
        Shape {
            anchors.top: capsuleBody.top
            anchors.left: capsuleBody.right
            width: root.earRadius
            height: root.earRadius
            opacity: Math.max(0, (root.expandProgress - 0.3) / 0.7)
            visible: opacity > 0.01
            z: 1

            ShapePath {
                fillColor: Theme.notchBackground
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: root.earRadius; y: 0 }
                PathArc {
                    x: 0
                    y: root.earRadius
                    radiusX: root.earRadius
                    radiusY: root.earRadius
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }

        // ──────────────────────────────────────────────────────────────────────
        // LIGHT-MODE OUTLINE (attached state)
        // One continuous stroke: left ear arc → left side → bottom → right side → right ear
        // arc. Never along the screen edge, and no seam where the ears meet the body — a
        // plain rectangle border drew both, which read as black lines/corners in light mode.
        // ──────────────────────────────────────────────────────────────────────
        Shape {
            id: attachedOutline
            visible: !Theme.isDark && opacity > 0.01
            opacity: Math.max(0, (root.expandProgress - 0.5) * 2)
            z: 3
            preferredRendererType: Shape.CurveRenderer
            readonly property real er: root.earRadius
            readonly property real bx: capsuleBody.x
            readonly property real bw: capsuleBody.width
            readonly property real bh: capsuleBody.height
            readonly property real br: capsuleBody.bottomLeftRadius

            ShapePath {
                strokeColor: Theme.notchBorder
                strokeWidth: 1
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                startX: attachedOutline.bx - attachedOutline.er
                startY: 0.5
                PathArc {
                    x: attachedOutline.bx + 0.5; y: attachedOutline.er
                    radiusX: attachedOutline.er; radiusY: attachedOutline.er
                    direction: PathArc.Clockwise
                }
                PathLine { x: attachedOutline.bx + 0.5; y: attachedOutline.bh - attachedOutline.br }
                PathArc {
                    x: attachedOutline.bx + attachedOutline.br; y: attachedOutline.bh - 0.5
                    radiusX: attachedOutline.br; radiusY: attachedOutline.br
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: attachedOutline.bx + attachedOutline.bw - attachedOutline.br; y: attachedOutline.bh - 0.5 }
                PathArc {
                    x: attachedOutline.bx + attachedOutline.bw - 0.5; y: attachedOutline.bh - attachedOutline.br
                    radiusX: attachedOutline.br; radiusY: attachedOutline.br
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: attachedOutline.bx + attachedOutline.bw - 0.5; y: attachedOutline.er }
                PathArc {
                    x: attachedOutline.bx + attachedOutline.bw + attachedOutline.er; y: 0.5
                    radiusX: attachedOutline.er; radiusY: attachedOutline.er
                    direction: PathArc.Clockwise
                }
            }
        }

        // Main Capsule Body (Retina/OLED deep surface)
        Rectangle {
            id: capsuleBody
            x: Math.round(root.earRadius * root.expandProgress)
            y: 0
            width: root.currentWidth
            height: root.currentHeight
            color: Theme.notchBackground
            border.color: Theme.notchBorderSubtle
            // Full border only while (mostly) floating; attached state uses attachedOutline.
            border.width: (!Theme.isDark && root.expandProgress < 0.5) ? 1 : 0
            clip: true
            z: 2

            topLeftRadius: Math.round(22 * (1.0 - root.expandProgress))
            topRightRadius: Math.round(22 * (1.0 - root.expandProgress))
            bottomLeftRadius: Math.round(22 + (root.bottomRadius - 22) * root.expandProgress)
            bottomRightRadius: Math.round(22 + (root.bottomRadius - 22) * root.expandProgress)

            // ── Stage 1: Compact View (Fades out quickly on expansion) ──
            Item {
                id: compactView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: root.compactHeight
                opacity: Math.max(0, 1.0 - root.expandProgress * 3.0)
                visible: opacity > 0.01

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    enabled: !root.isExpanded
                    onEntered: {
                        // Prefetch at most every 10 s; the expand path skips a fetch this fresh.
                        const now = Date.now();
                        if (now - root._lastPrefetch < 10000) return;
                        root._lastPrefetch = now;
                        if (SystemMonitor.isWifi) {
                            NetworkService.refresh();
                        }
                        if (root.bluetoothError.length === 0) {
                            BluetoothService.refresh();
                        }
                    }
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

                            SymbolicIcon {
                                iconSize: 16
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
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Medium
                                color: Theme.notchTextSecondary
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
                        implicitWidth: 28; implicitHeight: 28
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.notchRadiusPill
                            color: volumeCompactMa.containsMouse
                                   ? Theme.notchSurfaceHover
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 16
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
                        implicitWidth: (SystemMonitor.isWifi && ssidLabel.visible) ? (netRow.implicitWidth + 14) : 28
                        implicitHeight: 28
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.notchRadiusPill
                            color: networkCompactMa.containsMouse
                                   ? Theme.notchSurfaceHover
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        RowLayout {
                            id: netRow
                            anchors.centerIn: parent
                            spacing: 5

                            SymbolicIcon {
                                iconSize: 16
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
                            id: networkCompactMa
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
                        implicitWidth: langBadgeText.implicitWidth + 12
                        implicitHeight: 22
                        radius: 6
                        color: langBadgeMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                        border.color: Theme.notchBorderSubtle
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            id: langBadgeText
                            anchors.centerIn: parent
                            text: root.activeKeyboardCode
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }

                        MouseArea {
                            id: langBadgeMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                Hyprland.dispatch("switchxkblayout all next");
                            }
                        }
                    }

                    // ── Gear icon (settings trigger) ──
                    Item {
                        implicitWidth: 28; implicitHeight: 28
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.notchRadiusPill
                            color: settingsIconMa.containsMouse
                                   ? Theme.notchSurfaceHover
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 16
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
                anchors.leftMargin: Theme.qsPadding
                anchors.rightMargin: Theme.qsPadding
                anchors.topMargin: root.contentTopMargin
                anchors.bottomMargin: root.contentBottomMargin
                opacity: Math.max(0, (root.expandProgress - 0.2) / 0.8)
                visible: opacity > 0.01

                MouseArea {
                    anchors.fill: parent
                    enabled: root.isExpanded
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0) {
                            ShellState.openQuickSettingsCapsule("main");
                        } else if (wheel.angleDelta.y > 0) {
                            ShellState.closeQuickSettingsCapsule();
                        }
                    }
                }

                // ═════════════════════════════════════════════════════════════
                // PAGE VIEWPORT — main + detail pages slide horizontally (RTL-aware)
                // ═════════════════════════════════════════════════════════════
                Item {
                    id: pageViewport
                    anchors.fill: parent
                    clip: true

                    component PageSlot: Item {
                        property string view: ""
                        readonly property bool current: root.currentView === view
                        readonly property bool isMain: view === "main"
                        width: pageViewport.width
                        height: isMain ? implicitHeight : root.detailPageHeight
                        enabled: current
                        opacity: current ? 1 : 0
                        visible: opacity > 0.01
                        // Main exits toward the reading start; details enter from the reading end.
                        x: current ? 0 : (isMain ? -root.slideSign : root.slideSign) * 36
                        Behavior on x { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
                    }

                    PageSlot {
                        view: "main"
                        implicitHeight: mainPage.implicitHeight
                        MainPage { id: mainPage; width: parent.width; qs: root }
                    }
                    PageSlot {
                        view: "wifi"
                        WifiPage { anchors.fill: parent; qs: root }
                    }
                    PageSlot {
                        view: "bluetooth"
                        BluetoothPage { anchors.fill: parent; qs: root }
                    }
                    PageSlot {
                        view: "audio"
                        AudioPage { anchors.fill: parent; qs: root }
                    }
                    PageSlot {
                        view: "power"
                        PowerPage { anchors.fill: parent; qs: root }
                    }
                    PageSlot {
                        view: "hotspot"
                        HotspotPage {
                            anchors.fill: parent
                            hotspotAvailable: root.hotspotAvailable
                            hotspotEnabled: root.hotspotEnabled
                            hotspotSsid: root.hotspotSsid
                            hotspotPassword: root.hotspotPassword
                            hotspotError: root.hotspotError
                            hotspotSaveSuccess: root.hotspotSaveSuccess
                            hotspotClients: root.hotspotClients
                            actionRunning: NetworkService.hotspotActionRunning
                            configureRunning: NetworkService.hotspotConfigureRunning
                            onBackClicked: ShellState.quickSettingsCapsuleView = "main"
                            onRefreshClicked: NetworkService.refresh()
                            onToggleClicked: root.toggleHotspot()
                            onSaveClicked: (ssid, pwd) => root.configureHotspot(ssid, pwd)
                        }
                    }
                }
            }
        }
    }
}
