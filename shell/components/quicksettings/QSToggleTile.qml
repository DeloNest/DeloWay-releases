import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool active: false
    property bool connected: false
    property bool hasChevron: true
    property color activeColor: Theme.accent
    property color activeIconColor: "#FFFFFF"
    property bool toggleEnabled: true

    signal clicked()
    signal toggleClicked()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.fillHeight: true
    radius: Theme.notchRadiusCard

    color: tileMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
    border.color: (root.active && root.connected)
                  ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.5)
                  : (root.active ? Theme.notchBorderHighlight : Theme.notchBorderSubtle)
    border.width: 1
    scale: tileMa.pressed ? 0.96 : (tileMa.containsMouse ? 1.01 : 1.0)

    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    MouseArea {
        id: tileMa
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 9

        // Clickable Icon Circle
        Rectangle {
            id: iconCircle
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            color: root.connected
                   ? root.activeColor
                   : (root.active ? Theme.notchBorderHighlight : Theme.notchSurfaceElevated)

            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

            SymbolicIcon {
                anchors.centerIn: parent
                source: root.icon
                iconSize: 17
                iconColor: root.connected
                           ? root.activeIconColor
                           : (root.active ? Theme.notchText : Theme.notchTextTertiary)
            }

            MouseArea {
                id: toggleMa
                anchors.fill: parent
                enabled: root.toggleEnabled
                cursorShape: root.toggleEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onClicked: {
                    if (root.hasChevron) {
                        root.toggleClicked();
                    } else {
                        root.clicked();
                    }
                }
            }
        }

        // Text details
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.DemiBold
                color: Theme.notchText
                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
                color: (root.active && root.connected) ? Theme.notchTextSecondary : Theme.notchTextTertiary
                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Chevron
        Text {
            visible: root.hasChevron
            text: I18n.isRTL ? "‹" : "›"
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.DemiBold
            color: tileMa.containsMouse ? Theme.notchTextSecondary : Theme.notchTextTertiary
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
