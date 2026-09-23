import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../theme"
import "../../../services"
import "../.."
import ".."
import "../../timecapsule"

// BluetoothPage — paired devices first, then discoverable ones.
// Row tap: connected → disconnect · paired → connect · new → pair.
ColumnLayout {
    id: root

    required property var qs
    spacing: 10

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true
    function t(ar, en) { return I18n.isRTL ? ar : en; }

    function activate(d) {
        if (d.connected) BluetoothService.disconnectDevice(d.address);
        else if (d.paired) BluetoothService.connectDevice(d.address);
        else BluetoothService.pairDevice(d.address);
    }

    QSPageHeader {
        title: root.t("بلوتوث", "Bluetooth")
        subtitle: !BluetoothService.powered ? root.t("متوقف", "Off")
                  : (BluetoothService.connectedDeviceName ? root.t("متصل بـ ", "Connected to ") + BluetoothService.connectedDeviceName
                     : root.t("مشغّل", "On"))
        hasAction: BluetoothService.powered
        actionBusy: BluetoothService.isScanning
        hasSwitch: BluetoothService.available
        switchOn: BluetoothService.powered
        onBackClicked: ShellState.quickSettingsCapsuleView = "main"
        onActionClicked: BluetoothService.scan()
        onSwitchToggled: root.qs.toggleBluetooth()
    }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        visible: BluetoothService.powered
        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 4
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.notchBorderHighlight }
        }

        ColumnLayout {
            id: col
            width: flick.width - (flick.contentHeight > flick.height ? 8 : 0)
            spacing: 2

            Repeater {
                model: [
                    { key: "paired", label: root.t("الأجهزة المقترنة", "Paired devices"), items: BluetoothService.pairedDevices },
                    { key: "avail",  label: root.t("أجهزة قريبة", "Nearby devices"),     items: BluetoothService.availableDevices }
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    visible: modelData.items.length > 0

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 2
                        Layout.leftMargin: 10
                        text: parent.modelData.label
                        horizontalAlignment: Text.AlignLeft
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(10)
                        font.weight: Font.DemiBold
                        color: Theme.notchTextTertiary
                        renderType: Theme.renderType
                    }

                    Repeater {
                        model: parent.modelData.items
                        delegate: QSRow {
                            required property var modelData
                            Layout.fillWidth: true
                            iconName: modelData.icon || "bluetooth-active-symbolic"
                            title: modelData.name || modelData.address
                            subtitle: BluetoothService.connectingAddress === modelData.address ? root.t("جارٍ الاتصال…", "Connecting…")
                                      : (modelData.connected ? root.t("متصل · اضغط لقطع الاتصال", "Connected · tap to disconnect")
                                         : (modelData.paired ? root.t("مقترن", "Paired") : root.t("اضغط للاقتران", "Tap to pair")))
                            selected: modelData.connected
                            busy: BluetoothService.connectingAddress === modelData.address
                            onClicked: root.activate(modelData)
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !BluetoothService.powered || (BluetoothService.pairedDevices.length + BluetoothService.availableDevices.length === 0)
        Column {
            anchors.centerIn: parent
            spacing: 8
            SymbolicIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                iconSize: 26
                source: BluetoothService.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
                iconColor: Theme.notchTextTertiary
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !BluetoothService.powered ? root.t("البلوتوث متوقف", "Bluetooth is off")
                      : (BluetoothService.isScanning ? root.t("جارٍ البحث…", "Searching…") : root.t("لا توجد أجهزة · اضغط بحث", "No devices · tap scan"))
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                color: Theme.notchTextSecondary
                renderType: Theme.renderType
            }
        }
    }

    RowLayout {
        visible: BluetoothService.error.length > 0
        Layout.fillWidth: true
        spacing: 8
        StatusDot { level: 2; Layout.alignment: Qt.AlignVCenter }
        Text {
            Layout.fillWidth: true
            text: NotificationManager.bidi(BluetoothService.error)
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(10)
            color: Theme.notchTextSecondary
            renderType: Theme.renderType
        }
    }
}
