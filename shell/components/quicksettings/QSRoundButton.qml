import QtQuick
import "../../theme"
import ".."

Rectangle {
    id: root

    property real buttonSize: 28
    property string icon: ""
    property string text: ""
    property real iconSize: 14
    property color normalColor: "transparent"
    property color hoverColor: Theme.notchSurfaceHover
    property color textColor: Theme.notchText
    property color hoverTextColor: Theme.notchText

    signal clicked()

    implicitWidth: buttonSize
    implicitHeight: buttonSize
    radius: buttonSize / 2
    color: ma.containsMouse ? hoverColor : normalColor
    scale: ma.pressed ? 0.92 : 1.0

    Behavior on color { ColorAnimation { duration: 80 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

    SymbolicIcon {
        id: symIcon
        visible: root.icon.length > 0
        anchors.centerIn: parent
        source: root.icon
        iconSize: root.iconSize
        iconColor: ma.containsMouse ? root.hoverTextColor : root.textColor
    }

    Text {
        visible: root.icon.length === 0 && root.text.length > 0
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.typography.fontFamily
        font.pixelSize: root.iconSize
        font.weight: Font.DemiBold
        color: ma.containsMouse ? root.hoverTextColor : root.textColor
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
