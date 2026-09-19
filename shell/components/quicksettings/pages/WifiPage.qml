import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../theme"
import "../../../services"
import "../.."
import ".."

ColumnLayout {
    id: root

    property var networks: []
    property bool wifiEnabled: false
    property string connectingSsid: ""
    property string networkError: ""

    signal backClicked()
    signal rescanClicked()
    signal connectClicked(string ssid, string password)

    spacing: 8

    // Header: Back button + Title + Rescan button
    QSPageHeader {
        title: I18n.isRTL ? "شبكات Wi-Fi" : "Wi-Fi Networks"
        hasAction: true
        actionText: "⟳"
        onBackClicked: root.backClicked()
        onActionClicked: root.rescanClicked()
    }

    // Available Networks Title
    Text {
        text: I18n.isRTL ? "الشبكات المتاحة" : "Available Networks"
        font.family: Theme.typography.fontFamily
        font.pixelSize: Theme.fontSize(10)
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
        model: root.networks

        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: wifiListView.contentHeight > wifiListView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 4
            contentItem: Rectangle {
                radius: 2
                color: Theme.notchBorderHighlight
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
                   ? Theme.notchSurfaceActive
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
                    font.pixelSize: Theme.fontSize(11)
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
                    font.pixelSize: Theme.fontSize(10)
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
                        root.connectClicked(netItem.modelData.ssid, "");
                    }
                }
            }
        }

        // Empty State if no networks or on error
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: !root.wifiEnabled || root.networks.length === 0

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
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextTertiary
            }
        }
    }
}
