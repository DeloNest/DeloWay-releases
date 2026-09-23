import QtQuick
import "../../theme"

// MonoSwitch — monochrome toggle: "on" is a solid high-contrast track, never a hue.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 34
    implicitHeight: 20
    radius: 10
    color: checked ? Theme.qsTileActive : Theme.notchSurfaceHover
    border.color: checked ? "transparent" : Theme.notchBorder
    border.width: 1
    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.qsTileIconActive : Theme.notchTextSecondary
        Behavior on x { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
