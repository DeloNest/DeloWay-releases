import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Item {
    id: root

    property bool expanded: false

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    // State: "idle" | "selecting" | "sending" | "sent"
    property string stage: "idle"
    property var droppedUrls: []
    property var selectedDevice: null
    property real sendProgress: 0.0

    // Sending Progress Timer
    Timer {
        id: sendTimer
        interval: 40
        repeat: true
        running: root.stage === "sending"
        property int elapsed: 0
        readonly property int totalDuration: 1200

        onRunningChanged: {
            if (running) {
                elapsed = 0;
                root.sendProgress = 0.0;
            }
        }

        onTriggered: {
            elapsed += interval;
            root.sendProgress = Math.min(1.0, elapsed / totalDuration);
            if (elapsed >= totalDuration) {
                stop();
                root.stage = "sent";
            }
        }
    }

    function startSending(device) {
        root.selectedDevice = device;
        root.stage = "sending";
        // Trigger real transfer via LocalSendService
        LocalSendService.sendFiles(root.droppedUrls);
    }

    function resetToIdle() {
        root.stage = "idle";
        root.droppedUrls = [];
        root.selectedDevice = null;
        root.sendProgress = 0.0;
    }

    // Trigger status & network scan on expanded
    onExpandedChanged: {
        if (expanded) {
            LocalSendService.refreshStatus();
            LocalSendService.scanNetwork();
        }
    }

    // =========================================================================
    // VIEW 1: COMPACT MODE (!expanded)
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        visible: !root.expanded

        SymbolicIcon {
            iconSize: 15
            source: "network-wireless-symbolic"
            iconColor: LocalSendService.isRunning ? Theme.colors.success : Theme.colors.accent
        }

        Text {
            text: LocalSendService.localAlias || "LocalSend"
            font.family: Theme.typography.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            renderType: Theme.renderType
            color: Theme.colors.text
        }

        Text {
            text: "•"
            font.pixelSize: 10
            color: Theme.colors.textTertiary
        }

        Text {
            text: {
                if (root.stage === "sending")
                    return I18n.tr("notch_sending_to") + " " + (root.selectedDevice ? (root.selectedDevice.alias || root.selectedDevice.ip) : "") + " (" + Math.round(root.sendProgress * 100) + "%)";
                if (root.stage === "sent")
                    return I18n.tr("notch_sent_success");
                if (root.stage === "selecting")
                    return (root.droppedUrls.length || 1) + " " + I18n.tr("notch_files_ready");
                if (!LocalSendService.isRunning)
                    return I18n.tr("notch_status_stopped");
                return LocalSendService.localIp;
            }
            font.family: Theme.typography.fontFamily
            font.pixelSize: 10
            renderType: Theme.renderType
            color: root.stage === "sent" ? Theme.colors.success : (LocalSendService.isRunning ? Theme.colors.textSecondary : Theme.colors.textTertiary)
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Status / Send Indicator Dot
        Rectangle {
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: root.stage === "sending"
                   ? Theme.colors.accent
                   : (root.stage === "sent" ? Theme.colors.success : (LocalSendService.isRunning ? Theme.colors.success : Theme.colors.textTertiary))

            SequentialAnimation on opacity {
                running: root.stage === "sending" || LocalSendService.isScanning
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 400 }
                NumberAnimation { to: 1.0; duration: 400 }
            }
        }
    }

    // =========================================================================
    // VIEW 2: EXPANDED MODE — Authentic Tray (matches media_1789172255469.png)
    // =========================================================================
    Item {
        anchors.fill: parent
        anchors.margins: 4
        visible: root.expanded
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        // ── Dashed Tray Box (100% NotchNook Tray match) ──
        Item {
            id: trayDashedBox
            anchors.fill: parent
            visible: root.stage === "idle"

            DropArea {
                id: dropArea
                anchors.fill: parent

                onDropped: drop => {
                    let urls = [];
                    if (drop.hasUrls && drop.urls) {
                        urls = drop.urls;
                    } else if (drop.hasText && drop.text) {
                        urls = [drop.text];
                    }
                    if (urls.length > 0) {
                        root.droppedUrls = urls;
                        root.stage = "selecting";
                        LocalSendService.scanNetwork();
                        drop.acceptProposedAction();
                    }
                }
            }

            // Dashed border Shape (Exact NotchNook dashed rectangle)
            Shape {
                anchors.fill: parent
                ShapePath {
                    fillColor: dropArea.containsDrag ? Theme.notchSurfaceHover : "transparent"
                    strokeColor: dropArea.containsDrag ? Theme.colors.accent : Theme.notchBorder
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [6, 4]
                    startX: 16; startY: 0
                    PathLine { x: trayDashedBox.width - 16; y: 0 }
                    PathArc { x: trayDashedBox.width; y: 16; radiusX: 16; radiusY: 16 }
                    PathLine { x: trayDashedBox.width; y: trayDashedBox.height - 16 }
                    PathArc { x: trayDashedBox.width - 16; y: trayDashedBox.height; radiusX: 16; radiusY: 16 }
                    PathLine { x: 16; y: trayDashedBox.height }
                    PathArc { x: 0; y: trayDashedBox.height - 16; radiusX: 16; radiusY: 16 }
                    PathLine { x: 0; y: 16 }
                    PathArc { x: 16; y: 0; radiusX: 16; radiusY: 16 }
                }
            }

            // Case 1: Empty Tray (Prompt to drop files)
            RowLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: root.droppedUrls.length === 0

                SymbolicIcon {
                    source: "notch-tray"
                    iconSize: 22
                    iconColor: Theme.notchTextTertiary
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: I18n.isRTL ? "اسحب الملفات هنا للحفظ أو الإرسال السريع" : "Drop files here to hold or share via LocalSend"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.notchText
                    }
                    Text {
                        text: "LocalSend: " + LocalSendService.localAlias + " • " + (LocalSendService.isRunning ? I18n.tr("notch_status_ready") : I18n.tr("notch_status_stopped"))
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 10
                        color: LocalSendService.isRunning ? Theme.colors.success : Theme.notchTextTertiary
                    }
                }
            }

            // Case 2: Files in Tray (matches media_1789172255469.png horizontal row of file previews)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14
                visible: root.droppedUrls.length > 0
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true

                ListView {
                    id: trayFilesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 16
                    clip: true
                    model: root.droppedUrls

                    delegate: ColumnLayout {
                        id: fileItem
                        required property var modelData
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        // File Preview Card (Exact macOS file thumbnail / document shape)
                        Rectangle {
                            width: 48
                            height: 40
                            radius: 4
                            color: Theme.notchSurfaceElevated
                            border.color: Theme.notchBorderHighlight
                            border.width: 1.5
                            clip: true
                            Layout.alignment: Qt.AlignHCenter

                            // Image Preview if image
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: {
                                    let s = (fileItem.modelData || "");
                                    if (s.startsWith("/") && !s.startsWith("file://")) return "file://" + s;
                                    return s;
                                }
                                fillMode: Image.PreserveAspectCrop
                                visible: {
                                    let s = (fileItem.modelData || "").toLowerCase();
                                    return s.endsWith(".png") || s.endsWith(".jpg") || s.endsWith(".jpeg") || s.endsWith(".webp") || s.endsWith(".svg");
                                }
                            }

                            // PDF / Document styling
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1
                                visible: {
                                    let s = (fileItem.modelData || "").toLowerCase();
                                    return s.endsWith(".pdf") || (!s.endsWith(".png") && !s.endsWith(".jpg") && !s.endsWith(".jpeg") && !s.endsWith(".webp") && !s.endsWith(".svg"));
                                }

                                Text {
                                    text: {
                                        let s = (fileItem.modelData || "").toLowerCase();
                                        if (s.endsWith(".pdf")) return "📄";
                                        if (s.endsWith(".zip") || s.endsWith(".tar") || s.endsWith(".gz")) return "📦";
                                        return "📁";
                                    }
                                    font.pixelSize: 16
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 10
                                    radius: 2
                                    color: Theme.danger
                                    visible: (fileItem.modelData || "").toLowerCase().endsWith(".pdf")
                                    Layout.alignment: Qt.AlignHCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "PDF"
                                        font.pixelSize: 7
                                        font.bold: true
                                        color: Theme.accentText
                                    }
                                }
                            }
                        }

                        // File Name Label (100% NotchNook format)
                        Text {
                            text: {
                                let raw = fileItem.modelData || "";
                                let parts = raw.split("/");
                                let name = parts[parts.length - 1] || raw;
                                return name;
                            }
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.notchText
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: 64
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Send Button (LocalSend Fast Dispatch)
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderHighlight
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    SymbolicIcon {
                        anchors.centerIn: parent
                        source: "network-wireless"
                        iconSize: 14
                        iconColor: Theme.notchText
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.stage = "selecting";
                            LocalSendService.scanNetwork();
                        }
                    }
                }
            }
        }

        // ── STAGE B: SELECT TARGET DEVICE (REAL NETWORK DEVICES) ──
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: root.stage === "selecting"

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Back button
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 11
                        color: backHover.containsMouse ? Theme.colors.surfaceHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: I18n.isRTL ? "→" : "←"
                            font.pixelSize: 12
                            color: Theme.colors.textSecondary
                        }

                        MouseArea {
                            id: backHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetToIdle()
                        }
                    }

                    Text {
                        text: I18n.tr("notch_select_device")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.colors.text
                    }

                    Rectangle {
                        implicitWidth: countTxt.implicitWidth + 10
                        implicitHeight: 16
                        radius: 8
                        color: Qt.alpha(Theme.colors.accent, 0.15)

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: (root.droppedUrls.length || 1) + " " + (root.droppedUrls.length === 1 ? I18n.tr("notch_file_ready") : I18n.tr("notch_files_ready"))
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                            color: Theme.colors.accent
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Rescan button
                    Rectangle {
                        implicitWidth: rescanTxt.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: rescanHover.containsMouse ? Theme.colors.surfaceHover : "transparent"
                        border.color: Theme.colors.borderSubtle
                        border.width: 1

                        Text {
                            id: rescanTxt
                            anchors.centerIn: parent
                            text: LocalSendService.isScanning ? I18n.tr("notch_scanning") : "🔄 " + I18n.tr("notch_scan_network")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 8
                            color: Theme.colors.accent
                        }

                        MouseArea {
                            id: rescanHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LocalSendService.scanNetwork()
                        }
                    }
                }

                // Devices Content
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // CASE 1: REAL DEVICES DISCOVERED
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        visible: LocalSendService.discoveredDevices.length > 0

                        Repeater {
                            model: LocalSendService.discoveredDevices

                            delegate: Rectangle {
                                id: realDeviceCard
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 8
                                color: rdevHover.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceVariant
                                border.color: rdevHover.containsMouse ? Theme.colors.accent : Theme.colors.borderSubtle
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    SymbolicIcon {
                                        iconSize: 18
                                        source: (realDeviceCard.modelData.deviceType === "mobile" || realDeviceCard.modelData.deviceType === "phone")
                                                ? "phone-symbolic"
                                                : "computer-symbolic"
                                        iconColor: rdevHover.containsMouse ? Theme.colors.accent : Theme.colors.text
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: realDeviceCard.modelData.alias || realDeviceCard.modelData.ip
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: Theme.colors.text
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 100
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: realDeviceCard.modelData.ip
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 8
                                        color: Theme.colors.textTertiary
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: rdevHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.startSending(realDeviceCard.modelData)
                                }
                            }
                        }
                    }

                    // CASE 2: NO REAL DEVICES DETECTED (HONEST REAL STATE)
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.alpha(Theme.colors.surface, 0.3)
                        border.color: Theme.colors.borderSubtle
                        border.width: 1
                        visible: LocalSendService.discoveredDevices.length === 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12

                            // Radar scanning pulse
                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: Qt.alpha(Theme.colors.accent, 0.12)

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    iconSize: 18
                                    source: "network-wireless-symbolic"
                                    iconColor: Theme.colors.accent
                                }

                                SequentialAnimation on opacity {
                                    running: LocalSendService.isScanning
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: 500 }
                                    NumberAnimation { to: 1.0; duration: 500 }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: I18n.tr("notch_no_devices")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.colors.text
                                }

                                Text {
                                    text: I18n.tr("notch_no_devices_hint")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 8
                                    color: Theme.colors.textSecondary
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            // Direct open LocalSend button
                            Rectangle {
                                implicitWidth: fallbackOpenTxt.implicitWidth + 14
                                implicitHeight: 24
                                radius: 12
                                color: fallbackOpenHover.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceVariant
                                border.color: Theme.colors.borderHighlight
                                border.width: 1

                                Text {
                                    id: fallbackOpenTxt
                                    anchors.centerIn: parent
                                    text: I18n.tr("notch_open_app")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    color: Theme.colors.text
                                }

                                MouseArea {
                                    id: fallbackOpenHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        LocalSendService.sendFiles(root.droppedUrls);
                                        root.resetToIdle();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── STAGE C: SENDING IN PROGRESS ──
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: root.stage === "sending"
                width: parent.width - 40

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    SymbolicIcon {
                        iconSize: 18
                        source: "network-wireless-symbolic"
                        iconColor: Theme.colors.accent
                    }

                    Text {
                        text: I18n.tr("notch_sending_to") + " " + (root.selectedDevice ? (root.selectedDevice.alias || root.selectedDevice.ip) : "")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.colors.text
                    }
                }

                // Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.colors.surfaceVariant

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * root.sendProgress
                        radius: 3
                        color: Theme.colors.accent

                        Behavior on width { NumberAnimation { duration: 60 } }
                    }
                }

                Text {
                    text: Math.round(root.sendProgress * 100) + "%"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.colors.accent
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // ── STAGE D: SENT SUCCESSFULLY ──
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                visible: root.stage === "sent"

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: Theme.colors.success
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.textOnAccent
                    }
                }

                Text {
                    text: I18n.tr("notch_sent_success")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.colors.text
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    implicitWidth: sendMoreTxt.implicitWidth + 18
                    implicitHeight: 22
                    radius: 11
                    color: sendMoreHover.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceVariant
                    border.color: Theme.colors.borderSubtle
                    border.width: 1
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        id: sendMoreTxt
                        anchors.centerIn: parent
                        text: I18n.tr("notch_send_more")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: Theme.colors.text
                    }

                    MouseArea {
                        id: sendMoreHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToIdle()
                    }
                }
            }
        }
    }

