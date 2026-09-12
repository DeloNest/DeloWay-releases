import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "deloway:quicksettings"
    WlrLayershell.keyboardFocus: ShellState.quickSettingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore

    visible: ShellState.quickSettingsOpen || panelHost.opacity > 0.01

    Shortcut {
        sequence: "Escape"
        enabled: ShellState.quickSettingsOpen
        onActivated: {
            if (root.currentView !== "main") {
                root.currentView = "main";
            } else {
                ShellState.closeQuickSettings();
            }
        }
    }

    readonly property string fontFamily: Theme.typography.fontFamily

    // ------------------------------------------------------------
    // Views & State
    // ------------------------------------------------------------

    property string currentView: ShellState.quickSettingsInitialView

    Connections {
        target: ShellState
        function onQuickSettingsInitialViewChanged() {
            root.currentView = ShellState.quickSettingsInitialView;
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.currentView = ShellState.quickSettingsInitialView;
            networkStatusProcess.running = true;
            btStatusProcess.running = true;
        }
    }

    property bool wifiEnabled: true
    property bool btEnabled: false
    property bool nightLightEnabled: false

    // Network & Wi-Fi state
    property var networkData: null
    property var wifiNetworks: []
    property string connectingSsid: ""
    property string wifiPasswordInput: ""
    property string selectedSsid: ""

    // Bluetooth state
    property var btDevices: []
    property bool btPowered: false

    // Canonical (non-localized) power-profile ids, as understood by
    // powerprofilesctl / power-profiles-daemon.
    property string powerProfile: "balanced"
    readonly property var powerProfileLabels: ({
        "power-saver": I18n.isRTL ? "توفير الطاقة" : "Power Saver",
        "balanced": I18n.isRTL ? "متوازن" : "Balanced",
        "performance": I18n.isRTL ? "أداء" : "Performance"
    })
    readonly property string powerModeLabel: powerProfileLabels[powerProfile] || powerProfile

    property real screenBrightness: 0.75
    property bool hasBacklight: false
    property string backlightDevice: ""

    property var audioSink: Pipewire.defaultAudioSink

    property var activePlayer: {
        if (!Mpris.players || !Mpris.players.values)
            return null

        const values = Mpris.players.values
        return values.length > 0 ? values[0] : null
    }

    readonly property real currentVolume: {
        if (!audioSink || !audioSink.audio)
            return 0

        return audioSink.audio.volume
    }

    readonly property bool isMuted: {
        if (!audioSink || !audioSink.audio)
            return false

        return audioSink.audio.muted
    }

    // ------------------------------------------------------------
    // Theme
    // ------------------------------------------------------------
    readonly property color background: Theme.colors.surfaceElevated
    readonly property color surface: Theme.colors.surface
    readonly property color surface2: Theme.colors.surfaceVariant
    readonly property color surface3: Theme.colors.surfaceHover

    readonly property color border: Theme.colors.border
    readonly property color borderLight: Theme.colors.borderHighlight

    readonly property color textPrimary: Theme.colors.text
    readonly property color textSecondary: Theme.colors.textSecondary
    readonly property color textMuted: Theme.colors.textTertiary

    readonly property color accent: Theme.colors.accent
    readonly property color accentText: Theme.textOnAccent

    readonly property color danger: Theme.colors.urgent

    // ------------------------------------------------------------
    // Network — Wi-Fi & Ethernet (via deloway-network.py)
    // ------------------------------------------------------------

    Process {
        id: networkStatusProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.networkData = parsed;
                    if (parsed.wifi) {
                        root.wifiEnabled = parsed.wifi.enabled;
                        root.wifiNetworks = parsed.wifi.networks || [];
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: wifiToggleProcess
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

    function connectWifi(ssid, password) {
        root.connectingSsid = ssid;
        let cmd = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "connect", ssid];
        if (password && password.length > 0) {
            cmd.push(password);
        }
        wifiConnectProcess.command = cmd;
        wifiConnectProcess.running = true;
    }

    // ------------------------------------------------------------
    // Network — Bluetooth (via deloway-bluetooth.py)
    // ------------------------------------------------------------

    Process {
        id: btStatusProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "list"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.btPowered = parsed.powered;
                    root.btEnabled = parsed.powered;
                    root.btDevices = parsed.devices || [];
                } catch(e) {}
            }
        }
    }

    Process {
        id: btToggleProcess
        onExited: btStatusProcess.running = true
    }

    Process {
        id: btActionProcess
        onExited: btStatusProcess.running = true
    }

    function toggleBluetooth() {
        const next = !root.btEnabled;
        btToggleProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "toggle"];
        btToggleProcess.running = true;
        root.btEnabled = next;
    }

    function connectBt(addr) {
        btActionProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "connect", addr];
        btActionProcess.running = true;
    }

    function disconnectBt(addr) {
        btActionProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "disconnect", addr];
        btActionProcess.running = true;
    }

    function scanBt() {
        btActionProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "scan"];
        btActionProcess.running = true;
    }

    // Periodic polling to keep status fresh
    Timer {
        interval: 4000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            networkStatusProcess.running = true;
            btStatusProcess.running = true;
        }
    }

    // ------------------------------------------------------------
    // Backlight (real brightness, via brightnessctl)
    // ------------------------------------------------------------

    Process {
        id: backlightDetectProcess
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: SplitParser {
            onRead: data => {
                const device = data.trim()
                root.hasBacklight = device.length > 0
                root.backlightDevice = device
                if (root.hasBacklight)
                    backlightReadProcess.running = true
            }
        }
    }

    Process {
        id: backlightReadProcess
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                const pct = parseInt(data.trim(), 10)
                if (!isNaN(pct))
                    root.screenBrightness = Math.max(0, Math.min(1, pct / 100))
            }
        }
    }

    Process {
        id: backlightWriteProcess
    }

    // Debounce hardware writes while the user is dragging the slider —
    // one brightnessctl call per frame would otherwise spam a subprocess.
    Timer {
        id: backlightWriteDebounce
        interval: 80
        onTriggered: {
            const pct = Math.round(root.screenBrightness * 100)
            backlightWriteProcess.command = ["sh", "-c", "brightnessctl set " + pct + "%"]
            backlightWriteProcess.running = true
        }
    }

    function setBrightness(value) {
        root.screenBrightness = Math.max(0, Math.min(1, value))
        if (root.hasBacklight)
            backlightWriteDebounce.restart()
    }

    Component.onCompleted: backlightDetectProcess.running = true

    // ------------------------------------------------------------
    // Night light (hyprsunset)
    // ------------------------------------------------------------

    Process {
        id: nightLightStatusProcess
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => { root.nightLightEnabled = data.trim() === "1" }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: nightLightStartProcess
        command: ["sh", "-c", "hyprsunset -t 4000 & disown"]
    }

    Process {
        id: nightLightStopProcess
        command: ["sh", "-c", "pkill -x hyprsunset"]
    }

    function toggleNightLight() {
        const next = !root.nightLightEnabled
        if (next)
            nightLightStartProcess.running = true
        else
            nightLightStopProcess.running = true
        root.nightLightEnabled = next
    }

    // ------------------------------------------------------------
    // Power profile (power-profiles-daemon)
    // ------------------------------------------------------------

    Process {
        id: powerProfileReadProcess
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const value = data.trim()
                if (value.length > 0)
                    root.powerProfile = value
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: powerProfileWriteProcess
    }

    Process {
        id: moreAudioProc
    }

    function cyclePowerProfile() {
        const order = ["power-saver", "balanced", "performance"]
        const idx = order.indexOf(root.powerProfile)
        const next = order[(idx + 1) % order.length]
        powerProfileWriteProcess.command = ["sh", "-c", "powerprofilesctl set " + next]
        powerProfileWriteProcess.running = true
        root.powerProfile = next
    }

    // ------------------------------------------------------------
    // Audio
    // ------------------------------------------------------------

    function setVolume(value) {
        if (!root.audioSink || !root.audioSink.audio || !root.audioSink.ready)
            return

        root.audioSink.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMute() {
        if (!root.audioSink || !root.audioSink.audio || !root.audioSink.ready)
            return

        root.audioSink.audio.muted = !root.audioSink.audio.muted
    }

    // Media player timer (lightweight)
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.activePlayer !== null && root.activePlayer.isPlaying
    }

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------

    function playerTitle() {
        if (!root.activePlayer)
            return "لا يوجد تشغيل"

        if (root.activePlayer.trackTitle)
            return root.activePlayer.trackTitle

        return "لا يوجد تشغيل"
    }

    function playerArtist() {
        if (!root.activePlayer)
            return "—"

        if (root.activePlayer.trackArtist)
            return root.activePlayer.trackArtist

        return "—"
    }

    // ------------------------------------------------------------
    // UI
    // ------------------------------------------------------------

    // Dismiss on clicking backdrop
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeQuickSettings()
    }

    Item {
        id: panelHost
        anchors.top: parent.top
        anchors.topMargin: 52
        anchors.right: I18n.isRTL ? undefined : parent.right
        anchors.left: I18n.isRTL ? parent.left : undefined
        anchors.rightMargin: I18n.isRTL ? 0 : 16
        anchors.leftMargin: I18n.isRTL ? 16 : 0
        width: 400
        height: Math.min(640, parent.height - 70)

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: ShellState.quickSettingsOpen ? 1.0 : 0.0
        scale: ShellState.quickSettingsOpen ? 1.0 : 0.96
        transformOrigin: I18n.isRTL ? Item.TopLeft : Item.TopRight

        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        // Block click-through to backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            id: panelShadow
            anchors.fill: panel
            anchors.margins: -1
            radius: 18
            color: Theme.colors.background
            opacity: 0.18
            z: -2
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 18
            color: root.background
            border.width: 1
            border.color: root.border

            ScrollView {
                id: scrollView
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                visible: root.currentView === "main"
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: contentColumn
                    width: scrollView.availableWidth
                    spacing: 10

                    // ====================================================
                    // Header
                    // ====================================================

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: I18n.isRTL ? "الإعدادات السريعة" : "Quick Settings"
                                color: root.textPrimary
                                font.family: root.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: I18n.isRTL ? "التحكم بالنظام" : "Control Center"
                                color: root.textMuted
                                font.family: root.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 10
                            color: settingsButtonArea.containsMouse ? root.surface3 : root.surface2
                            border.width: 1
                            border.color: root.border

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "settings-symbolic"
                                iconSize: 16
                                iconColor: root.textSecondary
                            }

                            MouseArea {
                                id: settingsButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.toggleSettingsApp()
                            }
                        }
                    }

                    // ====================================================
                    // Media Player
                    // ====================================================

                    Rectangle {
                        id: mediaCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: 118
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 72
                                    Layout.preferredHeight: 72
                                    radius: 10
                                    color: root.surface3
                                    clip: true

                                    Image {
                                        id: coverImage
                                        anchors.fill: parent
                                        source: root.activePlayer && root.activePlayer.trackArtUrl
                                                ? root.activePlayer.trackArtUrl
                                                : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                        opacity: visible ? 1 : 0
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "♪"
                                        color: root.textMuted
                                        font.pixelSize: 24
                                        visible: coverImage.status !== Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.playerTitle()
                                        color: root.textPrimary
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.playerArtist()
                                        color: root.textMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    Item { Layout.fillHeight: true }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 8
                                            color: "transparent"
                                            enabled: root.activePlayer !== null

                                            Text {
                                                anchors.centerIn: parent
                                                text: "‹"
                                                color: root.textSecondary
                                                font.pixelSize: 21
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.activePlayer)
                                                        root.activePlayer.previous()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 34
                                            height: 34
                                            radius: 9
                                            color: root.accent
                                            enabled: root.activePlayer !== null
                                            opacity: enabled ? 1 : 0.4

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.activePlayer && root.activePlayer.isPlaying
                                                      ? "Ⅱ"
                                                      : "▶"
                                                color: root.accentText
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!root.activePlayer)
                                                        return

                                                    if (root.activePlayer.isPlaying)
                                                        root.activePlayer.pause()
                                                    else
                                                        root.activePlayer.play()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 8
                                            color: "transparent"
                                            enabled: root.activePlayer !== null

                                            Text {
                                                anchors.centerIn: parent
                                                text: "›"
                                                color: root.textSecondary
                                                font.pixelSize: 21
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.activePlayer)
                                                        root.activePlayer.next()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                radius: 2
                                color: root.surface3

                                Rectangle {
                                    width: root.activePlayer &&
                                           root.activePlayer.length > 0
                                           ? parent.width * (root.activePlayer.position / root.activePlayer.length)
                                           : 0
                                    height: parent.height
                                    radius: 2
                                    color: root.textSecondary
                                }
                            }
                        }
                    }

                    // ====================================================
                    // Quick Settings
                    // ====================================================

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: "الاتصال والنظام"
                                    color: root.textPrimary
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }

                                Text {
                                    text: "4"
                                    color: root.textMuted
                                    font.pixelSize: 10
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8

                                // ── Wi-Fi Tile (Split Button) ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 11
                                    color: root.wifiEnabled ? root.surface3 : root.background
                                    border.width: 1
                                    border.color: root.wifiEnabled ? root.borderLight : root.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 0

                                        // Left Clickable Toggle Area
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                spacing: 8

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 7
                                                    color: root.wifiEnabled ? root.accent : root.surface2

                                                    SymbolicIcon {
                                                        anchors.centerIn: parent
                                                        source: "wifi"
                                                        iconSize: 15
                                                        iconColor: root.wifiEnabled ? root.accentText : root.textMuted
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: "Wi-Fi"
                                                        color: root.textPrimary
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Medium
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: root.wifiEnabled
                                                              ? (root.networkData && root.networkData.wifi && root.networkData.wifi.ssid ? root.networkData.wifi.ssid : (I18n.isRTL ? "مفعل" : "On"))
                                                              : (I18n.isRTL ? "متوقف" : "Off")
                                                        color: root.textMuted
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 9
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleWifi()
                                            }
                                        }

                                        // Subtle vertical divider
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 20
                                            Layout.alignment: Qt.AlignVCenter
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                        }

                                        // Right Clickable Chevron Area
                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.fillHeight: true
                                            radius: 8
                                            color: wifiChevMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: I18n.isRTL ? "‹" : "›"
                                                color: wifiChevMouse.containsMouse ? root.textPrimary : root.textSecondary
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                id: wifiChevMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.currentView = "wifi"
                                            }
                                        }
                                    }
                                }

                                // ── Bluetooth Tile (Split Button) ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 11
                                    color: root.btEnabled ? root.surface3 : root.background
                                    border.width: 1
                                    border.color: root.btEnabled ? root.borderLight : root.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 0

                                        // Left Clickable Toggle Area
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                spacing: 8

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 7
                                                    color: root.btEnabled ? root.accent : root.surface2

                                                    SymbolicIcon {
                                                        anchors.centerIn: parent
                                                        source: "bluetooth"
                                                        iconSize: 15
                                                        iconColor: root.btEnabled ? root.accentText : root.textMuted
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: "Bluetooth"
                                                        color: root.textPrimary
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Medium
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: root.btEnabled
                                                              ? (root.btDevices.filter(d => d.connected).length > 0 ? (I18n.isRTL ? "متصل" : "Connected") : (I18n.isRTL ? "مفعل" : "On"))
                                                              : (I18n.isRTL ? "متوقف" : "Off")
                                                        color: root.textMuted
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 9
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleBluetooth()
                                            }
                                        }

                                        // Subtle vertical divider
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 20
                                            Layout.alignment: Qt.AlignVCenter
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                        }

                                        // Right Clickable Chevron Area
                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.fillHeight: true
                                            radius: 8
                                            color: btChevMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: I18n.isRTL ? "‹" : "›"
                                                color: btChevMouse.containsMouse ? root.textPrimary : root.textSecondary
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                id: btChevMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.currentView = "bluetooth"
                                            }
                                        }
                                    }
                                }

                                // ── Night light ──────────────────────────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 11
                                    color: root.nightLightEnabled ? root.surface3 : root.background
                                    border.width: 1
                                    border.color: root.nightLightEnabled ? root.borderLight : root.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 9

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 8
                                            color: root.nightLightEnabled ? root.accent : root.surface2

                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: "night-light-symbolic"
                                                iconSize: 16
                                                iconColor: root.nightLightEnabled ? root.accentText : root.textMuted
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.isRTL ? "الإضاءة الليلية" : "Night Light"
                                                color: root.textPrimary
                                                font.family: root.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.nightLightEnabled ? (I18n.isRTL ? "مفعلة" : "On") : (I18n.isRTL ? "متوقفة" : "Off")
                                                color: root.textMuted
                                                font.family: root.fontFamily
                                                font.pixelSize: 9
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleNightLight()
                                    }
                                }

                                // ── Power profile ────────────────────────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 11
                                    color: root.surface3
                                    border.width: 1
                                    border.color: root.borderLight

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 9

                                        Rectangle {
                                            width: 30
                                            height: 30
                                            radius: 8
                                            color: root.surface2

                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: "power-profile-balanced-symbolic"
                                                iconSize: 16
                                                iconColor: root.textSecondary
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.isRTL ? "الأداء" : "Power"
                                                color: root.textPrimary
                                                font.family: root.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.powerModeLabel
                                                color: root.textMuted
                                                font.family: root.fontFamily
                                                font.pixelSize: 9
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cyclePowerProfile()
                                    }
                                }
                            }
                        }
                    }

                    // ====================================================
                    // Brightness — hidden only when no backlight device
                    // was actually detected (was previously hidden always,
                    // because hasBacklight was never set from anywhere).
                    // ====================================================

                    Rectangle {
                        visible: root.hasBacklight
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            SymbolicIcon {
                                source: "display-brightness"
                                iconSize: 16
                                iconColor: root.textSecondary
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 5
                                    radius: 3
                                    color: root.surface3

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, root.screenBrightness))
                                        height: parent.height
                                        radius: 3
                                        color: root.accent
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: mouse => root.setBrightness(mouse.x / width)
                                        onPositionChanged: mouse => {
                                            if (pressed)
                                                root.setBrightness(mouse.x / width)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: Math.round(root.screenBrightness * 100) + "%"
                                color: root.textSecondary
                                font.pixelSize: 10
                                Layout.preferredWidth: 34
                            }
                        }
                    }

                    // ====================================================
                    // Volume
                    // ====================================================

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 8
                                    color: root.surface2

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: root.isMuted ? "audio-volume-muted" : "audio-volume-high"
                                        iconSize: 16
                                        iconColor: root.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleMute()
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 5
                                        radius: 3
                                        color: root.surface3

                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, root.currentVolume))
                                            height: parent.height
                                            radius: 3
                                            color: root.accent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onPressed: mouse => root.setVolume(mouse.x / width)
                                            onPositionChanged: mouse => {
                                                if (pressed)
                                                    root.setVolume(mouse.x / width)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: Math.round(root.currentVolume * 100) + "%"
                                    color: root.textSecondary
                                    font.pixelSize: 10
                                    Layout.preferredWidth: 34
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: root.border
                            }

                            // Dedicated pwvucontrol launcher
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 6
                                color: audioSettingsMouse.containsMouse ? root.surface2 : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    SymbolicIcon {
                                        iconSize: 12
                                        source: "preferences-system-sound-symbolic"
                                        iconColor: audioSettingsMouse.containsMouse ? root.accent : root.textSecondary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.tr("more_audio_settings")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        color: audioSettingsMouse.containsMouse ? root.textPrimary : root.textSecondary
                                    }

                                    Text {
                                        text: "↗"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        color: audioSettingsMouse.containsMouse ? root.accent : root.textSecondary
                                    }
                                }

                                MouseArea {
                                    id: audioSettingsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ShellState.closeQuickSettings();
                                        moreAudioProc.exec(["bash", "-c", "command -v pwvucontrol >/dev/null && pwvucontrol || pavucontrol"]);
                                    }
                                }
                            }
                        }
                    }

                    // ====================================================
                    // Notifications
                    // ====================================================

                    Rectangle {
                        id: notificationsCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.border

                        // Whether a real notification service is wired up.
                        // Assumed API shape based on the NotificationManager
                        // reference already used elsewhere in this project
                        // (NotificationToast, IpcHandler); adjust the property
                        // names below (`list`, `.count`) to match its actual
                        // model if they differ.
                        readonly property bool hasService: typeof NotificationManager !== "undefined"
                        readonly property var latest: hasService && NotificationManager.notifications && NotificationManager.notifications.length > 0
                                                       ? NotificationManager.notifications[0]
                                                       : null

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: I18n.isRTL ? "الإشعارات" : "Notifications"
                                    color: root.textPrimary
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }

                                Rectangle {
                                    width: 28
                                    height: 24
                                    radius: 7
                                    color: "transparent"
                                    visible: notificationsCard.hasService

                                    Text {
                                        anchors.centerIn: parent
                                        text: I18n.isRTL ? "مسح" : "Clear"
                                        color: root.textMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 9
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (typeof NotificationManager !== "undefined")
                                                NotificationManager.clearAll()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: root.border
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                spacing: 10

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 9
                                    color: root.surface2

                                    Text {
                                        anchors.centerIn: parent
                                        text: "i"
                                        color: root.textSecondary
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: notificationsCard.latest
                                              ? (notificationsCard.latest.summary || notificationsCard.latest.appName)
                                              : (I18n.isRTL ? "النظام يعمل بشكل طبيعي" : "System running normally")
                                        color: root.textPrimary
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: notificationsCard.latest
                                              ? notificationsCard.latest.body
                                              : (I18n.isRTL ? "لا توجد إشعارات جديدة" : "No new notifications")
                                        color: root.textMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: notificationsCard.latest
                                          ? (notificationsCard.latest.timeStr || (I18n.isRTL ? "الآن" : "Now"))
                                          : (I18n.isRTL ? "الآن" : "Now")
                                    color: root.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 9
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }

            // ====================================================
            // Wi-Fi Drill-down Sub-Page
            // ====================================================
            Item {
                id: wifiView
                anchors.fill: parent
                anchors.margins: 14
                visible: root.currentView === "wifi"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    // ── Header ──────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        spacing: 8

                        // Back Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: wifiBackArea.containsMouse ? root.surface3 : root.surface2
                            border.width: 1
                            border.color: root.border

                            Text {
                                anchors.centerIn: parent
                                text: I18n.isRTL ? "→" : "←"
                                color: root.textPrimary
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: wifiBackArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentView = "main"
                            }
                        }

                        SymbolicIcon {
                            source: "wifi"
                            iconSize: 18
                            iconColor: root.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: I18n.isRTL ? "شبكات Wi-Fi" : "Wi-Fi Networks"
                            color: root.textPrimary
                            font.family: root.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Switch Pill (On/Off)
                        Rectangle {
                            width: 44
                            height: 24
                            radius: 12
                            color: root.wifiEnabled ? root.accent : root.surface3
                            border.width: 1
                            border.color: root.border

                            Rectangle {
                                x: root.wifiEnabled ? (I18n.isRTL ? 4 : 24) : (I18n.isRTL ? 24 : 4)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: Theme.textOnAccent
                                Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleWifi()
                            }
                        }

                        // Rescan Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: wifiRefreshArea.containsMouse ? root.surface3 : root.surface2
                            border.width: 1
                            border.color: root.border

                            Text {
                                anchors.centerIn: parent
                                text: "↻"
                                color: root.textSecondary
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: wifiRefreshArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wifiRescanProcess.running = true;
                                    networkStatusProcess.running = true;
                                }
                            }
                        }
                    }

                    // ── Ethernet Card (if active) ────────────────────────
                    Rectangle {
                        visible: Boolean(root.networkData && root.networkData.ethernet && root.networkData.ethernet.connected)
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 10
                        color: root.surface
                        border.width: 1
                        border.color: root.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            SymbolicIcon {
                                source: "network-wireless"
                                iconSize: 18
                                iconColor: root.accent
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: I18n.isRTL ? "اتصال سلكي (Ethernet)" : "Wired Connection (Ethernet)"
                                    color: root.textPrimary
                                    font.family: root.fontFamily
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 12
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (root.networkData && root.networkData.ethernet ? root.networkData.ethernet.ip : "") || (I18n.isRTL ? "متصل" : "Connected")
                                    color: root.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    // ── Wi-Fi Networks List ──────────────────────────────
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            width: parent.width
                            spacing: 6

                            // Off state message
                            Item {
                                visible: !root.wifiEnabled
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.isRTL ? "تم إيقاف تشغيل Wi-Fi" : "Wi-Fi is turned off"
                                    color: root.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            // Scanning / Empty state message
                            Item {
                                visible: root.wifiEnabled && root.wifiNetworks.length === 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.isRTL ? "جاري البحث عن الشبكات المتاحة..." : "Searching for networks..."
                                    color: root.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            Repeater {
                                model: root.wifiEnabled ? root.wifiNetworks : []
                                delegate: Rectangle {
                                    id: netCard
                                    Layout.fillWidth: true
                                    implicitHeight: netContent.implicitHeight + 16
                                    radius: 10
                                    color: modelData.connected ? root.surface3 : (netItemMouse.containsMouse ? root.surface2 : root.surface)
                                    border.width: 1
                                    border.color: modelData.connected ? root.accent : root.border

                                    ColumnLayout {
                                        id: netContent
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            SymbolicIcon {
                                                source: "wifi"
                                                iconSize: 16
                                                iconColor: modelData.connected ? root.accent : root.textSecondary
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.ssid || (I18n.isRTL ? "شبكة غير معلنة" : "Hidden Network")
                                                    color: root.textPrimary
                                                    font.family: root.fontFamily
                                                    font.weight: modelData.connected ? Font.Bold : Font.Medium
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.connected
                                                          ? (I18n.isRTL ? "متصل وآمن" : "Connected, secured")
                                                          : (modelData.security && modelData.security !== "Open" ? (I18n.isRTL ? "آمنة" : "Secured") : (I18n.isRTL ? "مفتوحة" : "Open"))
                                                    color: modelData.connected ? root.accent : root.textMuted
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                }
                                            }

                                            // Action Button
                                            Rectangle {
                                                width: 70
                                                height: 28
                                                radius: 6
                                                color: modelData.connected ? root.surface2 : root.accent
                                                border.width: modelData.connected ? 1 : 0
                                                border.color: root.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.connected
                                                          ? (I18n.isRTL ? "قطع" : "Disconnect")
                                                          : (root.connectingSsid === modelData.ssid ? "..." : (I18n.isRTL ? "اتصال" : "Connect"))
                                                    color: modelData.connected ? root.textPrimary : root.accentText
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            wifiToggleProcess.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "toggle-wifi"];
                                                            wifiToggleProcess.running = true;
                                                        } else {
                                                            if (modelData.security && modelData.security !== "Open" && root.selectedSsid !== modelData.ssid) {
                                                                root.selectedSsid = modelData.ssid;
                                                                root.wifiPasswordInput = "";
                                                            } else {
                                                                root.connectWifi(modelData.ssid, root.wifiPasswordInput);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Inline Password Input Box (when selected and secured)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: root.selectedSsid === modelData.ssid && !modelData.connected && modelData.security && modelData.security !== "Open"
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 32
                                                    radius: 6
                                                    color: root.background
                                                    border.width: 1
                                                    border.color: pwField.activeFocus ? root.accent : root.border

                                                    TextInput {
                                                        id: pwField
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        echoMode: TextInput.Password
                                                        color: root.textPrimary
                                                        font.pixelSize: 12
                                                        onTextChanged: root.wifiPasswordInput = text
                                                        onAccepted: root.connectWifi(modelData.ssid, text)
                                                    }

                                                    Text {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: I18n.isRTL ? "أدخل كلمة المرور..." : "Enter password..."
                                                        color: root.textMuted
                                                        font.family: root.fontFamily
                                                        font.pixelSize: 11
                                                        visible: pwField.text.length === 0
                                                    }
                                                }

                                                Rectangle {
                                                    width: 54
                                                    height: 32
                                                    radius: 6
                                                    color: root.accent

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: I18n.isRTL ? "دخول" : "Join"
                                                        color: root.accentText
                                                        font.family: root.fontFamily
                                                        font.weight: Font.Medium
                                                        font.pixelSize: 11
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.connectWifi(modelData.ssid, root.wifiPasswordInput)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: netItemMouse
                                        anchors.fill: parent
                                        z: -1
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.selectedSsid === modelData.ssid) root.selectedSsid = "";
                                            else root.selectedSsid = modelData.ssid;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── More Network Settings Link ───────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: moreNetArea.containsMouse ? root.surface2 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            SymbolicIcon {
                                source: "settings-symbolic"
                                iconSize: 15
                                iconColor: root.accent
                            }

                            Text {
                                Layout.fillWidth: true
                                text: I18n.isRTL ? "المزيد من إعدادات الشبكة..." : "More network settings..."
                                color: root.accent
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Text {
                                text: I18n.isRTL ? "‹" : "›"
                                color: root.accent
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: moreNetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ShellState.closeQuickSettings();
                                ShellState.openSettingsTab("network");
                            }
                        }
                    }
                }
            }

            // ====================================================
            // Bluetooth Drill-down Sub-Page
            // ====================================================
            Item {
                id: bluetoothView
                anchors.fill: parent
                anchors.margins: 14
                visible: root.currentView === "bluetooth"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    // ── Header ──────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        spacing: 8

                        // Back Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: btBackArea.containsMouse ? root.surface3 : root.surface2
                            border.width: 1
                            border.color: root.border

                            Text {
                                anchors.centerIn: parent
                                text: I18n.isRTL ? "→" : "←"
                                color: root.textPrimary
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: btBackArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentView = "main"
                            }
                        }

                        SymbolicIcon {
                            source: "bluetooth"
                            iconSize: 18
                            iconColor: root.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: I18n.isRTL ? "أجهزة Bluetooth" : "Bluetooth Devices"
                            color: root.textPrimary
                            font.family: root.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        // Switch Pill (On/Off)
                        Rectangle {
                            width: 44
                            height: 24
                            radius: 12
                            color: root.btEnabled ? root.accent : root.surface3
                            border.width: 1
                            border.color: root.border

                            Rectangle {
                                x: root.btEnabled ? (I18n.isRTL ? 4 : 24) : (I18n.isRTL ? 24 : 4)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: Theme.textOnAccent
                                Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleBluetooth()
                            }
                        }

                        // Scan Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: btScanArea.containsMouse ? root.surface3 : root.surface2
                            border.width: 1
                            border.color: root.border

                            Text {
                                anchors.centerIn: parent
                                text: "↻"
                                color: root.textSecondary
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: btScanArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.scanBt();
                                    btStatusProcess.running = true;
                                }
                            }
                        }
                    }

                    // ── Devices List ────────────────────────────────────
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            width: parent.width
                            spacing: 6

                            Item {
                                visible: !root.btEnabled
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.isRTL ? "تم إيقاف تشغيل Bluetooth" : "Bluetooth is turned off"
                                    color: root.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            Item {
                                visible: root.btEnabled && root.btDevices.length === 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.isRTL ? "لا توجد أجهزة متصلة أو مقترنة" : "No devices found"
                                    color: root.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            Repeater {
                                model: root.btEnabled ? root.btDevices : []
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    radius: 10
                                    color: modelData.connected ? root.surface3 : (devMouse.containsMouse ? root.surface2 : root.surface)
                                    border.width: 1
                                    border.color: modelData.connected ? root.accent : root.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        SymbolicIcon {
                                            source: modelData.icon || "bluetooth"
                                            iconSize: 18
                                            iconColor: modelData.connected ? root.accent : root.textSecondary
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name || modelData.address
                                                color: root.textPrimary
                                                font.family: root.fontFamily
                                                font.weight: modelData.connected ? Font.Bold : Font.Medium
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.connected
                                                      ? (I18n.isRTL ? "متصل" : "Connected")
                                                      : (modelData.paired ? (I18n.isRTL ? "مقترن" : "Paired") : (I18n.isRTL ? "متاح" : "Available"))
                                                color: modelData.connected ? root.accent : root.textMuted
                                                font.family: root.fontFamily
                                                font.pixelSize: 10
                                            }
                                        }

                                        // Connect / Disconnect button
                                        Rectangle {
                                            width: 78
                                            height: 28
                                            radius: 6
                                            color: modelData.connected ? root.surface2 : root.accent
                                            border.width: modelData.connected ? 1 : 0
                                            border.color: root.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.connected
                                                      ? (I18n.isRTL ? "قطع الاتصال" : "Disconnect")
                                                      : (I18n.isRTL ? "اتصال" : "Connect")
                                                color: modelData.connected ? root.textPrimary : root.accentText
                                                font.family: root.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.connected) {
                                                        root.disconnectBt(modelData.address);
                                                    } else {
                                                        root.connectBt(modelData.address);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: devMouse
                                        anchors.fill: parent
                                        z: -1
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }

                    // ── More Bluetooth Settings Link ────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: moreBtArea.containsMouse ? root.surface2 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            SymbolicIcon {
                                source: "settings-symbolic"
                                iconSize: 15
                                iconColor: root.accent
                            }

                            Text {
                                Layout.fillWidth: true
                                text: I18n.isRTL ? "المزيد من إعدادات Bluetooth..." : "More Bluetooth settings..."
                                color: root.accent
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Text {
                                text: I18n.isRTL ? "‹" : "›"
                                color: root.accent
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: moreBtArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ShellState.closeQuickSettings();
                                ShellState.openSettingsTab("bluetooth");
                            }
                        }
                    }
                }
            }
        }
    }
}
    