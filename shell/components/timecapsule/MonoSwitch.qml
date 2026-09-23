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

    // Anchored (not x): anchors follow LayoutMirroring, so "on" sits at the reading
    // end in both directions (left in Arabic), matching SettingsToggle.
    Rectangle {
        width: 14; height: 14; radius: 7
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.qsTileIconActive : Theme.notchTextSecondary
        Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
