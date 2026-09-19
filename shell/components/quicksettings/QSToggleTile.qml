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
    property bool hasChevron: false
    property color activeColor: Theme.accent
    property color activeIconColor: Theme.qsTileIconActive
    property bool toggleEnabled: true

    signal clicked()
    signal toggleClicked()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: Theme.qsTileHeight
    implicitHeight: Theme.qsTileHeight
    radius: Theme.qsTileRadius

    color: tileMa.containsMouse
           ? Theme.qsTileBackgroundHover
           : (root.active ? Theme.qsTileBackgroundActive : Theme.qsTileBackground)
    border.color: root.active ? Theme.notchBorderHighlight : Theme.qsTileBorder
    border.width: 1
    scale: tileMa.pressed ? 0.97 : (tileMa.containsMouse ? 1.01 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    MouseArea {
        id: tileMa
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            if (root.toggleEnabled) {
                root.toggleClicked();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Icon Circle (40px)
        Rectangle {
            id: iconCircle
            implicitWidth: Theme.qsIconCircleSize
            implicitHeight: Theme.qsIconCircleSize
            radius: Theme.qsIconCircleRadius
            color: root.active
                   ? root.activeColor
                   : Theme.qsTileIconCircleInactive

            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

            SymbolicIcon {
                anchors.centerIn: parent
                source: root.icon
                iconSize: 18
                iconColor: root.active
                           ? root.activeIconColor
                           : Theme.qsTileIconInactive
            }
        }

        // Text details
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                elide: Text.ElideRight
                Layout.fillWidth: true
                renderType: Theme.renderType
            }

            Text {
                text: root.subtitle
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.Normal
                color: Theme.notchTextTertiary
                elide: Text.ElideRight
                Layout.fillWidth: true
                renderType: Theme.renderType
            }
        }

        // Chevron to open subpage
        Item {
            visible: root.hasChevron
            implicitWidth: 14
            implicitHeight: 36
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: I18n.isRTL ? "‹" : "›"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(14)
                font.weight: Font.Bold
                color: chevronMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
                renderType: Theme.renderType
            }

            MouseArea {
                id: chevronMa
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: (mouse) => {
                    mouse.accepted = true;
                    root.clicked();
                }
            }
        }
    }
}
