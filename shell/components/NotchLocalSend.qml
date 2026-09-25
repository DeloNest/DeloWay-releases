import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

// Notch → Share: send and receive files with paired phones and computers (LocalSend
// protocol, through LocalSendService — no LocalSend window). One view at a time:
//   empty    no paired device: "Connect a device"
//   pair     the connect flow: nearby LocalSend devices to pair, or an IP address
//   home     drop zone + the paired devices
//   select   files staged: pick who gets them
//   send     an outgoing transfer (waiting for accept, progress, sent, failed)
//   receive  an incoming transfer (accept/decline, progress, received)
//   app      the LocalSend app is open and holds the port: show it, or close it
Item {
    id: root

    property bool expanded: false
    property bool pairing: false

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property string view: {
        if (LocalSendService.receiveStatus !== "idle") return "receive";
        if (LocalSendService.sendStatus !== "idle") return "send";
        if (LocalSendService.appHoldsPort) return "app";
        if (root.pairing) return "pair";
        if (LocalSendService.droppedFiles.length > 0) return "select";
        return LocalSendService.hasPaired ? "home" : "empty";
    }

    Connections {
        target: LocalSendService
        function onFilesStaged(files) { root.pairing = false; }
        function onResetRequested() { root.pairing = false; }
        function onDevicePaired(device) { root.pairing = false; }
    }

    function deviceIcon(dev) {
        const t = dev ? dev.deviceType : "";
        return (t === "mobile" || t === "phone") ? "phone-symbolic" : "computer-symbolic";
    }
    function deviceName(dev) { return dev ? (dev.alias || dev.ip || "") : ""; }
    function fileName(path) {
        const parts = String(path || "").split("/");
        return parts[parts.length - 1] || String(path || "");
    }

    // ── Building blocks ───────────────────────────────────────────────────
    // A pill button. primary = the one action the view is about (inverse fill).
    component Pill: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property bool primary: false
        signal activated()

        implicitHeight: 26
        implicitWidth: pillRow.implicitWidth + 24
        radius: height / 2
        color: primary ? Theme.inverseSurface
                       : (pillMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
        opacity: primary && pillMa.containsMouse ? 0.88 : 1
        border.width: primary ? 0 : 1
        border.color: pillMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            SymbolicIcon {
                visible: pill.icon !== ""
                source: pill.icon
                iconSize: 13
                iconColor: pill.primary ? Theme.inverseText : Theme.notchText
            }
            Text {
                text: pill.label
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: pill.primary ? Font.DemiBold : Font.Medium
                renderType: Theme.renderType
                color: pill.primary ? Theme.inverseText : Theme.notchText
            }
        }
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }

    // A round icon button (back, remove).
    component RoundButton: Rectangle {
        id: rb
        property string icon: ""
        signal activated()
        implicitWidth: 24
        implicitHeight: 24
        radius: 12
        color: rbMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
        SymbolicIcon {
            anchors.centerIn: parent
            source: rb.icon
            iconSize: 13
            iconColor: rbMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
        }
        MouseArea {
            id: rbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.activated()
        }
    }

    // A device as a card: icon, name, online dot. Click = the card's action.
    component DeviceCard: Rectangle {
        id: card
        property var device: null
        property bool online: true
        property string actionLabel: ""       // shown as a pill instead of a whole-card click
        property bool removable: false
        signal activated()
        signal removeRequested()

        implicitHeight: 44
        radius: 12
        color: cardMa.containsMouse && actionLabel === "" ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
        border.width: 1
        border.color: cardMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        MouseArea {
            id: cardMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.actionLabel === "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (card.actionLabel === "") card.activated()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10

            Item {
                implicitWidth: 28
                implicitHeight: 28
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Theme.notchSurfaceActive
                }
                SymbolicIcon {
                    anchors.centerIn: parent
                    source: root.deviceIcon(card.device)
                    iconSize: 15
                    iconColor: card.online ? Theme.notchText : Theme.notchTextTertiary
                }
                // Online: the one status colour, as an 8px dot.
                Rectangle {
                    visible: card.online
                    width: 8; height: 8; radius: 4
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: Theme.colors.success
                    border.width: 1.5
                    border.color: Theme.notchBackground
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.deviceName(card.device)
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignLeft   // reading start, also for Latin names
                    elide: Text.ElideRight
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: card.online ? Theme.notchText : Theme.notchTextSecondary
                }
                Text {
                    Layout.fillWidth: true
                    text: card.online ? I18n.tr("share_online") : I18n.tr("share_offline")
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(9)
                    renderType: Theme.renderType
                    color: Theme.notchTextTertiary
                }
            }

            Pill {
                visible: card.actionLabel !== ""
                label: card.actionLabel
                primary: true
                onActivated: card.activated()
            }
            RoundButton {
                visible: card.removable && cardMa.containsMouse || (card.removable && removeHover.hovered)
                icon: "window-close-symbolic"
                onActivated: card.removeRequested()
                HoverHandler { id: removeHover }
                ToolTip.visible: removeHover.hovered
                ToolTip.text: I18n.tr("share_unpair")
                ToolTip.delay: 400
            }
        }
    }

    // A thin progress bar.
    component Progress: Rectangle {
        id: bar
        property real value: 0
        implicitHeight: 6
        radius: 3
        color: Theme.notchSurfaceElevated
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, bar.value))
            radius: 3
            color: Theme.notchText
            Behavior on width { NumberAnimation { duration: 120 } }
        }
    }

    // Text that starts at the reading start whatever its first letter (mirrored in Arabic).
    component Title: Text {
        horizontalAlignment: Text.AlignLeft
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(13)
        font.weight: Font.DemiBold
        renderType: Theme.renderType
        color: Theme.notchText
        elide: Text.ElideRight
    }
    component Caption: Text {
        horizontalAlignment: Text.AlignLeft
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(10)
        renderType: Theme.renderType
        color: Theme.notchTextSecondary
        elide: Text.ElideRight
    }

    // Files from the file chooser → staged like a drop.
    Process {
        id: chooser
        command: ["zenity", "--file-selection", "--multiple", "--separator=\n",
                  "--title=" + I18n.tr("share_choose_files")]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.split("\n").filter(f => f.length > 0);
                if (files.length > 0) LocalSendService.stageFiles(files);
            }
        }
    }

    // Anything dropped on the page is staged, whatever the view.
    DropArea {
        id: dropArea
        anchors.fill: parent
        enabled: root.view === "home" || root.view === "empty" || root.view === "select"
        onDropped: drop => {
            const urls = drop.hasUrls && drop.urls ? drop.urls : (drop.hasText && drop.text ? [drop.text] : []);
            if (urls.length > 0) {
                LocalSendService.stageFiles(urls);
                drop.acceptProposedAction();
            }
        }
    }

    Item {
        id: page
        anchors.fill: parent
        anchors.margins: 6

        // ── EMPTY: no paired device ──────────────────────────────────────
        RowLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 520)
            spacing: 16
            visible: root.view === "empty"

            Rectangle {
                implicitWidth: 52
                implicitHeight: 52
                radius: 26
                color: Theme.notchSurfaceElevated
                SymbolicIcon {
                    anchors.centerIn: parent
                    source: "phone-symbolic"
                    iconSize: 24
                    iconColor: Theme.notchText
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Title { Layout.fillWidth: true; text: I18n.tr("share_no_device") }
                Caption {
                    Layout.fillWidth: true
                    text: I18n.tr("share_no_device_hint")
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignLeft
                }
            }
            Pill {
                visible: LocalSendService.appInstalled
                label: I18n.tr("share_open_app")
                onActivated: LocalSendService.openApp()
            }
            Pill {
                label: I18n.tr("share_connect")
                icon: "list-add-symbolic"
                primary: true
                onActivated: { root.pairing = true; LocalSendService.scan(); }
            }
        }

        // ── PAIR: connect a device ───────────────────────────────────────
        RowLayout {
            anchors.fill: parent
            spacing: 14
            visible: root.view === "pair"

            // Steps + this computer + manual IP
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.maximumWidth: 250
                Layout.fillHeight: true
                spacing: 3

                RowLayout {
                    spacing: 6
                    RoundButton {
                        icon: I18n.isRTL ? "go-next-symbolic" : "go-previous-symbolic"
                        onActivated: root.pairing = false
                    }
                    Title { text: I18n.tr("share_connect") }
                }
                Repeater {
                    model: [I18n.tr("share_pair_step1"), I18n.tr("share_pair_step2"), I18n.tr("share_pair_step3")]
                    delegate: Caption {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        text: I18n.uiLine(I18n.digits(index + 1) + ". " + modelData)
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    TextField {
                        id: ipField
                        Layout.fillWidth: true
                        implicitHeight: 26
                        placeholderText: I18n.tr("share_ip_placeholder")
                        placeholderTextColor: Theme.notchTextTertiary
                        color: Theme.notchText
                        selectionColor: Theme.textSelection
                        selectedTextColor: color
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        horizontalAlignment: TextInput.AlignLeft
                        LayoutMirroring.enabled: false   // an address reads left to right
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 0
                        bottomPadding: 0
                        validator: RegularExpressionValidator { regularExpression: /[0-9.:]{0,21}/ }
                        background: Rectangle {
                            radius: 13
                            color: Theme.notchSurface
                            border.width: 1
                            border.color: ipField.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        }
                        onAccepted: LocalSendService.probe(text)
                    }
                    Pill {
                        label: I18n.tr("share_add_ip")
                        onActivated: LocalSendService.probe(ipField.text)
                    }
                }
                Caption {
                    Layout.fillWidth: true
                    visible: LocalSendService.probeFailedIp !== ""
                    text: I18n.uiLine(I18n.tr("share_ip_failed") + " " + I18n.ltr(LocalSendService.probeFailedIp))
                    color: Theme.notchTextTertiary
                    font.pixelSize: Theme.fontSize(9)
                }
            }

            // Nearby devices to pair
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Caption {
                    Layout.fillWidth: true
                    text: LocalSendService.localAlias
                          ? I18n.uiLine(I18n.tr("share_this_device") + ": " + I18n.isolate(LocalSendService.localAlias)
                                        + (LocalSendService.localIp ? " · " + I18n.ltr(LocalSendService.localIp) : ""))
                          : ""
                    color: Theme.notchTextTertiary
                    font.pixelSize: Theme.fontSize(9)
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: LocalSendService.nearbyDevices.length > 0
                    clip: true
                    spacing: 6
                    model: LocalSendService.nearbyDevices
                    delegate: DeviceCard {
                        required property var modelData
                        width: ListView.view.width
                        device: modelData
                        actionLabel: I18n.tr("share_pair")
                        onActivated: LocalSendService.pair(modelData)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: LocalSendService.nearbyDevices.length === 0
                    radius: 12
                    color: Theme.notchSurface
                    border.width: 1
                    border.color: Theme.notchBorderSubtle

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        SymbolicIcon {
                            Layout.alignment: Qt.AlignHCenter
                            source: "network-wireless-symbolic"
                            iconSize: 20
                            iconColor: Theme.notchTextSecondary
                            SequentialAnimation on opacity {
                                running: root.view === "pair"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 700 }
                                NumberAnimation { to: 1.0; duration: 700 }
                            }
                        }
                        Caption {
                            Layout.alignment: Qt.AlignHCenter
                            text: I18n.tr("share_searching")
                        }
                    }
                }
            }
        }

        // ── HOME: drop zone + paired devices ─────────────────────────────
        RowLayout {
            anchors.fill: parent
            spacing: 12
            visible: root.view === "home"

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: dropArea.containsDrag ? Theme.notchSurfaceHover : "transparent"
                        strokeColor: dropArea.containsDrag ? Theme.notchBorderHighlight : Theme.notchBorder
                        strokeWidth: 1.5
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [6, 4]
                        startX: 14; startY: 0
                        PathLine { x: dropBox.width - 14; y: 0 }
                        PathArc { x: dropBox.width; y: 14; radiusX: 14; radiusY: 14 }
                        PathLine { x: dropBox.width; y: dropBox.height - 14 }
                        PathArc { x: dropBox.width - 14; y: dropBox.height; radiusX: 14; radiusY: 14 }
                        PathLine { x: 14; y: dropBox.height }
                        PathArc { x: 0; y: dropBox.height - 14; radiusX: 14; radiusY: 14 }
                        PathLine { x: 0; y: 14 }
                        PathArc { x: 14; y: 0; radiusX: 14; radiusY: 14 }
                    }
                }
                Item { id: dropBox; anchors.fill: parent }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 6
                    SymbolicIcon {
                        Layout.alignment: Qt.AlignHCenter
                        source: "notch-tray"
                        iconSize: 22
                        iconColor: Theme.notchTextSecondary
                    }
                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: parent.width
                        text: I18n.tr("share_drop_hint")
                        color: Theme.notchText
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Pill {
                            label: I18n.tr("share_choose_files")
                            onActivated: if (!chooser.running) chooser.running = true
                        }
                        Pill {
                            visible: LocalSendService.appInstalled
                            label: I18n.tr("share_open_app")
                            onActivated: LocalSendService.openApp()
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 230
                Layout.maximumWidth: 230
                Layout.fillHeight: true
                spacing: 6

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: LocalSendService.devices
                    delegate: DeviceCard {
                        required property var modelData
                        width: ListView.view.width
                        device: modelData
                        online: modelData.online
                        removable: true
                        onActivated: if (!chooser.running) chooser.running = true
                        onRemoveRequested: LocalSendService.unpair(modelData.fingerprint)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Caption {
                        Layout.fillWidth: true
                        font.pixelSize: Theme.fontSize(9)
                        color: Theme.notchTextTertiary
                        text: LocalSendService.receiving
                              ? I18n.uiLine(I18n.tr("share_visible_as") + " " + I18n.isolate(LocalSendService.localAlias))
                              : (LocalSendService.ready ? I18n.tr("share_not_visible") : "")
                    }
                    Pill {
                        label: I18n.tr("share_add_device")
                        icon: "list-add-symbolic"
                        implicitHeight: 24
                        onActivated: { root.pairing = true; LocalSendService.scan(); }
                    }
                }
            }
        }

        // ── SELECT: who gets the staged files ────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            visible: root.view === "select"

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                RoundButton {
                    icon: I18n.isRTL ? "go-next-symbolic" : "go-previous-symbolic"
                    onActivated: LocalSendService.resetStage()
                }
                Title {
                    Layout.fillWidth: true
                    text: I18n.uiLine(I18n.tr("share_send_to") + "… · " + I18n.filesCount(LocalSendService.droppedFiles.length))
                }
                Caption {
                    Layout.maximumWidth: 220
                    text: LocalSendService.droppedFiles.map(root.fileName).join("، ")
                    textFormat: Text.PlainText
                    color: Theme.notchTextTertiary
                }
            }

            // Paired devices first (online ones lead), then unpaired devices nearby.
            ListView {
                id: targets
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: count > 0
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: LocalSendService.devices.slice().sort((a, b) => (b.online ? 1 : 0) - (a.online ? 1 : 0))
                       .concat(LocalSendService.nearbyDevices.map(d => Object.assign({ online: true }, d)))
                delegate: DeviceCard {
                    required property var modelData
                    width: Math.max(170, (targets.width - 16) / 3)
                    height: 44
                    y: (targets.height - height) / 2
                    device: modelData
                    online: modelData.online
                    onActivated: LocalSendService.sendFiles(LocalSendService.droppedFiles, modelData)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: targets.count === 0
                spacing: 12
                Caption {
                    Layout.fillWidth: true
                    text: I18n.tr("share_no_device")
                    color: Theme.notchText
                }
                Pill {
                    label: I18n.tr("share_connect")
                    icon: "list-add-symbolic"
                    primary: true
                    onActivated: { root.pairing = true; LocalSendService.scan(); }
                }
            }
        }

        // ── APP: the LocalSend app has the port ─────────────────────────
        RowLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 540)
            spacing: 16
            visible: root.view === "app"

            Rectangle {
                implicitWidth: 52
                implicitHeight: 52
                radius: 26
                color: Theme.notchSurfaceElevated
                SymbolicIcon {
                    anchors.centerIn: parent
                    source: "document-send-symbolic"
                    iconSize: 24
                    iconColor: Theme.notchText
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Title { Layout.fillWidth: true; text: I18n.tr("share_app_open") }
                Caption {
                    Layout.fillWidth: true
                    text: I18n.tr("share_app_open_hint")
                    wrapMode: Text.WordWrap
                }
            }
            Pill {
                label: I18n.tr("share_app_show")
                onActivated: LocalSendService.openApp()
            }
            Pill {
                label: I18n.tr("share_app_back")
                primary: true
                onActivated: LocalSendService.closeApp()
            }
        }

        // ── SEND: an outgoing transfer ───────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 460)
            spacing: 8
            visible: root.view === "send"
            id: sendView

            readonly property string status: LocalSendService.sendStatus
            readonly property string target: root.deviceName(LocalSendService.sendDevice)

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                SymbolicIcon {
                    source: sendView.status === "sent" ? "object-select-symbolic"
                          : (sendView.status === "failed" || sendView.status === "cancelled")
                            ? "dialog-error-symbolic" : root.deviceIcon(LocalSendService.sendDevice)
                    iconSize: 18
                    iconColor: sendView.status === "sent" ? Theme.colors.success
                             : sendView.status === "failed" ? Theme.colors.urgent : Theme.notchText
                }
                Title {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: {
                        const st = sendView.status, name = I18n.isolate(sendView.target);
                        if (st === "sent") return I18n.uiLine(I18n.tr("share_sent_to") + " " + name);
                        if (st === "failed") return I18n.tr("notch_sent_failed");
                        if (st === "cancelled") return I18n.tr("share_cancelled");
                        return I18n.uiLine(I18n.tr("notch_sending_to") + " " + name);
                    }
                }
                Text {
                    visible: sendView.status === "sending"
                    text: I18n.number(Math.round(LocalSendService.sendProgress * 100) + "%")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.DemiBold
                    color: Theme.notchText
                }
            }
            Progress {
                Layout.fillWidth: true
                visible: sendView.status === "sending" || sendView.status === "connecting"
                value: LocalSendService.sendProgress
            }
            Caption {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                visible: text !== ""
                text: sendView.status === "connecting" ? I18n.tr("share_waiting_accept")
                    : sendView.status === "sending" ? LocalSendService.currentSendingFile
                    : sendView.status === "failed" ? LocalSendService.sendErrorText(LocalSendService.sendError)
                    : ""
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Pill {
                    visible: sendView.status === "connecting" || sendView.status === "sending"
                    label: I18n.tr("common_cancel")
                    onActivated: LocalSendService.cancelSend()
                }
                Pill {
                    visible: sendView.status === "failed"
                    label: I18n.tr("notch_try_again")
                    primary: true
                    onActivated: LocalSendService.sendFiles(LocalSendService.droppedFiles, LocalSendService.sendDevice)
                }
                Pill {
                    visible: sendView.status === "sent" || sendView.status === "failed" || sendView.status === "cancelled"
                    label: I18n.tr("share_done")
                    primary: sendView.status === "sent"
                    onActivated: LocalSendService.clearStaged()
                }
            }
        }

        // ── RECEIVE: an incoming transfer ────────────────────────────────
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 14
            visible: root.view === "receive"
            id: recvView

            readonly property string status: LocalSendService.receiveStatus
            readonly property var req: LocalSendService.incoming
            readonly property string from: req && req.sender ? root.deviceName(req.sender) : ""

            Rectangle {
                implicitWidth: 52
                implicitHeight: 52
                radius: 26
                color: Theme.notchSurfaceElevated
                SymbolicIcon {
                    anchors.centerIn: parent
                    source: recvView.status === "received" ? "object-select-symbolic"
                          : recvView.status === "ended" ? "dialog-error-symbolic"
                          : root.deviceIcon(recvView.req ? recvView.req.sender : null)
                    iconSize: 24
                    iconColor: recvView.status === "received" ? Theme.colors.success : Theme.notchText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Title {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: {
                        const r = recvView, name = I18n.isolate(r.from);
                        const n = r.req && r.req.files ? r.req.files.length : 0;
                        if (r.status === "asking")
                            return I18n.uiLine(name + " " + I18n.tr("share_wants_to_send") + " " + I18n.filesCount(n));
                        if (r.status === "receiving") return I18n.uiLine(I18n.tr("share_receiving_from") + " " + name);
                        if (r.status === "received")
                            return I18n.uiLine(I18n.filesCount(LocalSendService.receivedFiles.length) + " — " + I18n.tr("share_received_from") + " " + name);
                        return I18n.tr("share_recv_" + (LocalSendService.receiveEndReason || "failed"));
                    }
                }
                Caption {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    visible: text !== ""
                    text: {
                        const r = recvView;
                        if (r.status === "received") return I18n.tr("share_saved_in_downloads");
                        if (!r.req || !r.req.files || r.status === "ended") return "";
                        return r.req.files.map(f => root.fileName(f.name)).join("، ") + "  ·  " + I18n.fileSize(r.req.totalSize);
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: recvView.status === "receiving"
                    spacing: 8
                    Progress { Layout.fillWidth: true; value: LocalSendService.receiveProgress }
                    Text {
                        text: I18n.number(Math.round(LocalSendService.receiveProgress * 100) + "%")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }
                }
            }

            RowLayout {
                spacing: 8
                Pill {
                    visible: recvView.status === "asking"
                    label: I18n.tr("share_decline")
                    onActivated: LocalSendService.declineIncoming()
                }
                Pill {
                    visible: recvView.status === "asking"
                    label: I18n.tr("share_accept")
                    primary: true
                    onActivated: LocalSendService.acceptIncoming()
                }
                Pill {
                    visible: recvView.status === "receiving"
                    label: I18n.tr("common_cancel")
                    onActivated: LocalSendService.cancelReceive()
                }
                Pill {
                    visible: recvView.status === "received"
                    label: I18n.tr("share_open")
                    onActivated: LocalSendService.openReceived()
                }
                Pill {
                    visible: recvView.status === "received" || recvView.status === "ended"
                    label: I18n.tr("share_done")
                    primary: recvView.status === "received"
                    onActivated: LocalSendService.dismissReceive()
                }
            }
        }
    }
}
