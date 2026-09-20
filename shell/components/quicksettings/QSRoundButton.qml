import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import ".."

Rectangle {
    id: root

    property real buttonSize: Theme.qsRoundButtonSize
    property string icon: ""
    property string text: ""
    property real iconSize: 20
    property bool active: false
    property color activeColor: Theme.qsTileActive
    property color activeIconColor: Theme.qsTileIconActive
    property color normalColor: Theme.qsTileBackground
    property color hoverColor: Theme.qsTileBackgroundHover
    property color textColor: Theme.notchText
    property color hoverTextColor: Theme.notchText

    signal clicked()

    implicitWidth: buttonSize
    implicitHeight: buttonSize
    Layout.preferredWidth: buttonSize
    Layout.preferredHeight: buttonSize
    radius: buttonSize / 2
    color: root.active ? activeColor : (ma.containsMouse ? hoverColor : normalColor)
    border.color: root.active ? Theme.notchBorderHighlight : Theme.qsTileBorder
    border.width: 1
    scale: ma.pressed ? 0.94 : (ma.containsMouse ? 1.02 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    SymbolicIcon {
        id: symIcon
        visible: root.icon.length > 0
        anchors.centerIn: parent
        source: root.icon
        iconSize: root.iconSize
        iconColor: root.active
                   ? root.activeIconColor
                   : (ma.containsMouse ? root.hoverTextColor : root.textColor)
    }

    Text {
        visible: root.icon.length === 0 && root.text.length > 0
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.typography.fontFamily
        font.pixelSize: root.iconSize
        font.weight: Font.DemiBold
        color: root.active
               ? root.activeIconColor
               : (ma.containsMouse ? root.hoverTextColor : root.textColor)
        renderType: Theme.renderType
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
