import QtQuick
import "../../theme"
import ".."

// QSIconButton — round neutral action (header actions, page actions).
Rectangle {
    id: root
    property string iconName: ""
    property real size: 32
    property bool highlighted: false
    property bool spinning: false
    signal clicked()

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: root.highlighted ? Theme.qsTileActive
           : (ma.pressed ? Theme.notchSurfaceActive : (ma.containsMouse ? Theme.qsTileBackgroundHover : Theme.qsTileBackground))
    border.color: root.highlighted ? "transparent" : Theme.qsTileBorder
    border.width: 1
    scale: ma.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast } }

    SymbolicIcon {
        id: glyph
        anchors.centerIn: parent
        iconSize: Math.round(root.size * 0.45)
        source: root.iconName
        iconColor: root.highlighted ? Theme.qsTileIconActive : (ma.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
        RotationAnimation on rotation {
            running: root.spinning
            loops: Animation.Infinite
            from: 0; to: 360; duration: 900
        }
        onRotationChanged: if (!root.spinning && rotation !== 0) rotation = 0
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
