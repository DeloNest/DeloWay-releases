import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../theme"
import "../../../services"
import "../.."
import ".."

ColumnLayout {
    id: root

    property var devices: []
    property bool bluetoothEnabled: false
    property string connectingBtAddress: ""
    property string bluetoothError: ""

    signal backClicked()
    signal refreshClicked()
    signal connectClicked(string address)
    signal disconnectClicked(string address)

    spacing: 8

    // Header: Back button + Title + Refresh button
    QSPageHeader {
        title: I18n.isRTL ? "أجهزة Bluetooth" : "Bluetooth Devices"
        hasAction: true
        actionText: "⟳"
        onBackClicked: root.backClicked()
        onActionClicked: root.refreshClicked()
    }

    // Available Bluetooth Devices List
    ListView {
        id: btListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: root.devices

        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: btListView.contentHeight > btListView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: Theme.notchBorderHighlight
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
                   ? Theme.notchSurfaceActive
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
                    font.pixelSize: Theme.fontSize(11)
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
                    font.pixelSize: Theme.fontSize(10)
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
                        root.disconnectClicked(btItem.modelData.address);
                    } else if (btItem.modelData.paired) {
                        root.connectClicked(btItem.modelData.address);
                    }
                }
            }
        }

        // Empty State if bluetooth off or no devices
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: !root.bluetoothEnabled || root.devices.length === 0

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
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextTertiary
            }
        }
    }
}
