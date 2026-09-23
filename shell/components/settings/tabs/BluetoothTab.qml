// Bluetooth — adapter power, paired and discoverable devices.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../theme"
import "../../../services"
import "../common"
import "../../"

Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    property string selectedSsid: ""
    property string wifiPasswordInput: ""

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ═════════════════════════════════════════════════════════════
        // 3. BLUETOOTH MANAGEMENT SECTION
        // ═════════════════════════════════════════════════════════════
        SettingsSection {
            title: I18n.isRTL ? "البلوتوث وإدارة الأجهزة" : "Bluetooth & Devices"

            // Bluetooth Master Toggle
            SettingsRow {
                title: "Bluetooth"
                subtitle: !BluetoothService.powered
                    ? (I18n.isRTL ? "البلوتوث معطل" : "Bluetooth is turned off")
                    : (BluetoothService.connectedDeviceName.length > 0
                        ? (I18n.isRTL ? ("متصل بجهاز: " + I18n.isolate(BluetoothService.connectedDeviceName)) : ("Connected to: " + I18n.isolate(BluetoothService.connectedDeviceName)))
                        : (I18n.isRTL ? "مفعّل — جاهز للاقتران" : "Enabled — Ready to pair"))
                icon: BluetoothService.powered ? "bluetooth-active-symbolic" : "bluetooth-symbolic"
                showDivider: BluetoothService.powered
                clickable: true
                onClicked: BluetoothService.togglePower()

                SettingsToggle {
                    checked: BluetoothService.powered
                    onToggled: ch => {
                        if (ch !== BluetoothService.powered) BluetoothService.togglePower();
                    }
                }
            }

            // If Bluetooth is powered: scan, paired devices, and available devices
            Item {
                visible: BluetoothService.powered
                Layout.fillWidth: true
                implicitHeight: btContentCol.implicitHeight
                Layout.preferredHeight: implicitHeight

                ColumnLayout {
                    id: btContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Theme.space12
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    // Error message if any
                    Rectangle {
                        visible: BluetoothService.error.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16
                        implicitHeight: 32
                        radius: 8
                        color: Qt.rgba(0.9, 0.2, 0.2, 0.15)
                        border.color: Theme.colors.urgent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: BluetoothService.error
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.Medium
                            color: Theme.colors.urgent
                        }
                    }

                    // Section Header: Devices & Scan Button
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.rightMargin: Theme.space16

                        Text {
                            text: I18n.isRTL ? "الأجهزة المقترنة والمعروفة" : "Paired & Known Devices"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                        }

                        // Scan Button
                        Rectangle {
                            height: 26
                            implicitWidth: btScanRow.implicitWidth + Theme.space16
                            radius: 13
                            color: btScanMa.pressed ? Theme.notchSurfaceActive : (btScanMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                            border.color: btScanMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: btScanRow
                                anchors.centerIn: parent
                                spacing: 6
                                LayoutMirroring.enabled: I18n.isRTL
                                LayoutMirroring.childrenInherit: true

                                Text {
                                    text: BluetoothService.isScanning ? "..." : "⟳"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.Bold
                                    color: Theme.notchText
                                }

                                Text {
                                    text: BluetoothService.isScanning ? (I18n.isRTL ? "جارٍ البحث..." : "Searching...") : (I18n.isRTL ? "بحث عن أجهزة" : "Search")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.Medium
                                    color: Theme.notchText
                                }
                            }

                            MouseArea {
                                id: btScanMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BluetoothService.scan()
                            }
                        }
                    }

                    // Paired Devices List
                    Repeater {
                        model: BluetoothService.pairedDevices
                        delegate: SettingsRow {
                            id: btRow
                            required property var modelData
                            required property int index

                            title: modelData.name || modelData.address
                            subtitle: modelData.connected
                                ? (I18n.isRTL ? "متصل حالياً" : "Connected")
                                : (I18n.isRTL ? "مقترن — غير متصل" : "Paired — Disconnected")
                            icon: modelData.icon || (modelData.connected ? "bluetooth-active-symbolic" : "bluetooth-symbolic")
                            showDivider: true

                            RowLayout {
                                spacing: Theme.space6
                                LayoutMirroring.enabled: I18n.isRTL
                                LayoutMirroring.childrenInherit: true

                                // Connect / Disconnect button
                                Rectangle {
                                    height: 26
                                    implicitWidth: btActionText.implicitWidth + Theme.space16
                                    radius: 13
                                    color: btActionMa.pressed ? Theme.notchSurfaceActive : (btActionMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                                    border.color: Theme.notchBorderSubtle
                                    border.width: 1

                                    Text {
                                        id: btActionText
                                        anchors.centerIn: parent
                                        text: btRow.modelData.connected
                                            ? (I18n.isRTL ? "فصل" : "Disconnect")
                                            : (BluetoothService.connectingAddress === btRow.modelData.address
                                                ? (I18n.isRTL ? "جارٍ التوصيل..." : "Connecting...")
                                                : (I18n.isRTL ? "توصيل" : "Connect"))
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.Medium
                                        color: btRow.modelData.connected ? (btActionMa.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary) : Theme.notchText
                                    }

                                    MouseArea {
                                        id: btActionMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (btRow.modelData.connected) {
                                                BluetoothService.disconnectDevice(btRow.modelData.address);
                                            } else {
                                                BluetoothService.connectDevice(btRow.modelData.address);
                                            }
                                        }
                                    }
                                }

                                // Unpair / Remove button
                                Rectangle {
                                    height: 26
                                    width: 26
                                    radius: 13
                                    color: unpairMa.pressed ? Qt.rgba(0.9, 0.2, 0.2, 0.35) : (unpairMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.18) : Theme.notchSurfaceElevated)
                                    border.color: unpairMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.5) : Theme.notchBorderSubtle
                                    border.width: 1

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        iconSize: 12
                                        source: "user-trash-symbolic"
                                        iconColor: unpairMa.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary
                                    }

                                    MouseArea {
                                        id: unpairMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: BluetoothService.removeDevice(btRow.modelData.address)
                                    }
                                }
                            }
                        }
                    }

                    // Empty state for paired devices
                    Text {
                        visible: BluetoothService.pairedDevices.length === 0
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.space16
                        Layout.bottomMargin: Theme.space8
                        text: I18n.isRTL ? "لا توجد أجهزة مقترنة حالياً." : "No paired devices found."
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
                        horizontalAlignment: Text.AlignLeft
                    }

                    // Available (Unpaired Discovered) Devices
                    Item {
                        visible: BluetoothService.availableDevices.length > 0
                        Layout.fillWidth: true
                        implicitHeight: availCol.implicitHeight

                        ColumnLayout {
                            id: availCol
                            anchors.fill: parent
                            spacing: Theme.space8
                            LayoutMirroring.enabled: I18n.isRTL
                            LayoutMirroring.childrenInherit: true

                            Text {
                                text: I18n.isRTL ? "الأجهزة المتاحة للاكتشاف والاقتران" : "Available to Pair"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                                Layout.leftMargin: Theme.space16
                                horizontalAlignment: Text.AlignLeft
                            }

                            Repeater {
                                model: BluetoothService.availableDevices
                                delegate: SettingsRow {
                                    id: availRow
                                    required property var modelData
                                    required property int index

                                    title: modelData.name || modelData.address
                                    subtitle: I18n.isRTL ? "جاهز للاقتران" : "Ready to pair"
                                    icon: modelData.icon || "bluetooth-symbolic"
                                    showDivider: index < (BluetoothService.availableDevices.length - 1)

                                    Rectangle {
                                        height: 26
                                        implicitWidth: pairText.implicitWidth + Theme.space16
                                        radius: 13
                                        color: pairMa.pressed ? Theme.notchSurfaceActive : (pairMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
                                        border.color: pairMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                        border.width: 1

                                        Text {
                                            id: pairText
                                            anchors.centerIn: parent
                                            text: I18n.isRTL ? "اقتران" : "Pair"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            font.weight: Font.DemiBold
                                            color: Theme.notchText
                                        }

                                        MouseArea {
                                            id: pairMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: BluetoothService.pairDevice(availRow.modelData.address)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
