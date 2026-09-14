import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    property bool isExpanded: false
    property string currentView: "main"

    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(2 * bottomRadius + 20, compactRow.implicitWidth + 2 * bottomRadius + 20)
    readonly property real expandedWidth: 400
    readonly property real expandedHeight: 250

    property real currentWidth: isExpanded ? expandedWidth : compactWidth
    property real currentHeight: isExpanded ? expandedHeight : compactHeight

    Behavior on currentWidth  { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on currentHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    implicitWidth: Math.round(currentWidth + shadowMargin * 2)
    implicitHeight: Math.round(currentHeight + 8) // Shadow margin

    Shortcut {
        sequence: "Escape"
        enabled: root.isExpanded
        onActivated: {
            if (root.currentView !== "main") {
                root.currentView = "main";
            } else {
                root.isExpanded = false;
            }
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
        } else {
            currentView = "main";
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
            visible: root.isExpanded
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
                anchors.fill: parent
                visible: !root.isExpanded
                opacity: root.isExpanded ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.isExpanded = true;
                        root.currentView = "main";
                    }
                }

                RowLayout {
                    id: compactRow
                    anchors.centerIn: parent
                    spacing: 10

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

                    SymbolicIcon {
                        iconSize: 14
                        source: "settings-symbolic"
                        iconColor: Theme.notchTextSecondary
                    }
                }
            }

            // ── Stage 2: Expanded View ───────────────────────────────────────
            Item {
                id: expandedView
                anchors.fill: parent
                anchors.margins: 12
                visible: root.isExpanded
                opacity: root.isExpanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

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
                                    root.isExpanded = false;
                                    root.currentView = "main";
                                }
                            }
                        }
                    }

                    // Row 1: Wi-Fi Tile + Bluetooth Tile (Side by Side)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        spacing: 8

                        // ── Wi-Fi Tile ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            radius: 12
                            color: wifiTileMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                            border.color: root.wifiEnabled ? Theme.notchBorderHighlight : Theme.notchBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            MouseArea {
                                id: wifiTileMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.currentView = "wifi";
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
                                           ? (SystemMonitor.isOnline ? Theme.notchText : Theme.notchBorderHighlight)
                                           : Theme.notchSurfaceElevated

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: "network-wireless-symbolic"
                                        iconSize: 16
                                        iconColor: root.wifiEnabled && SystemMonitor.isOnline ? Theme.notchBackground : (root.wifiEnabled ? Theme.notchText : Theme.notchTextTertiary)
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
                                    spacing: 1

                                    Text {
                                        text: "Wi-Fi"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: !root.wifiEnabled
                                              ? (I18n.isRTL ? "معطل" : "Off")
                                              : (root.wifiSsid.length > 0 ? root.wifiSsid : (I18n.isRTL ? "غير متصل" : "Disconnected"))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 10
                                        color: root.wifiEnabled ? Theme.notchTextSecondary : Theme.notchTextTertiary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Chevron
                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: wifiTileMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // ── Bluetooth Tile ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            radius: 12
                            color: btTileMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                            border.color: root.bluetoothEnabled ? Theme.notchBorderHighlight : Theme.notchBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            MouseArea {
                                id: btTileMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.currentView = "bluetooth";
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

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

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
                                    spacing: 1

                                    Text {
                                        text: "Bluetooth"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
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
                                        color: root.bluetoothEnabled ? Theme.notchTextSecondary : Theme.notchTextTertiary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Chevron
                                Text {
                                    text: I18n.isRTL ? "‹" : "›"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: btTileMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }

                    // Row 2: Volume Slider (Placeholder)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 10
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            SymbolicIcon {
                                source: "audio-volume-high-symbolic"
                                iconSize: 14
                                iconColor: Theme.notchTextTertiary
                            }

                            Text {
                                text: I18n.isRTL ? "الصوت (قريباً)" : "Volume (Placeholder)"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                color: Theme.notchTextTertiary
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Row 3: Brightness Slider (Placeholder)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 10
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            SymbolicIcon {
                                source: "display-brightness-symbolic"
                                iconSize: 14
                                iconColor: Theme.notchTextTertiary
                            }

                            Text {
                                text: I18n.isRTL ? "السطوع (قريباً)" : "Brightness (Placeholder)"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                color: Theme.notchTextTertiary
                                Layout.fillWidth: true
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
                                onClicked: root.currentView = "main"
                            }
                        }

                        Text {
                            text: I18n.isRTL ? "شبكات Wi-Fi" : "Wi-Fi Networks"
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
                                onClicked: root.currentView = "main"
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
            }
        }
    }
}
