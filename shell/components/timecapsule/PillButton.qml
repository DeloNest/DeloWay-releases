import QtQuick
import "../../theme"
import ".."

// PillButton — compact rounded action. `primary` = solid high-contrast (white/black in
// dark, slate/white in light); otherwise a translucent neutral surface.
Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property bool primary: false
    property bool selected: false
    property int fontSize: 10
    signal clicked()

    implicitWidth: Math.max(implicitHeight, row.implicitWidth + (text.length > 0 ? 18 : 8))
    implicitHeight: 24
    radius: height / 2

    readonly property bool strong: primary || selected
    color: strong ? (ma.pressed ? Theme.primaryHover : Theme.qsTileActive)
                  : (ma.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated)
    border.color: strong ? "transparent" : Theme.notchBorderSubtle
    border.width: 1
    opacity: enabled ? 1 : 0.4
    scale: ma.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        SymbolicIcon {
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 12
            source: root.iconName
            iconColor: root.strong ? Theme.qsTileIconActive : Theme.notchText
        }
        Text {
            visible: root.text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(root.fontSize)
            font.weight: Font.DemiBold
            color: root.strong ? Theme.qsTileIconActive : Theme.notchText
            renderType: Theme.renderType
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
