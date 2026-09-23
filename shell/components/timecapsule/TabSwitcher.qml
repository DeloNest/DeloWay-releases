import QtQuick
import "../../theme"
import ".."

// TabSwitcher — segmented control with a sliding active pill (same surface language as
// the Notch tab row). The pill animates between segments; labels never re-layout.
Rectangle {
    id: root

    property var tabs: []            // [{ label, icon }]
    property int currentIndex: 0
    signal activated(int index)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 28
    radius: height / 2
    color: Theme.notchSurface
    border.color: Theme.notchBorderSubtle
    border.width: 1

    // Sliding indicator — follows the active segment's geometry.
    Rectangle {
        id: pill
        readonly property Item target: rep.count > root.currentIndex ? rep.itemAt(root.currentIndex) : null
        x: target ? row.x + target.x : 3
        width: target ? target.width : 0
        y: 3
        height: root.height - 6
        radius: height / 2
        color: Theme.notchSurfaceActive
        Behavior on x { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on width { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            id: rep
            model: root.tabs

            delegate: Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool active: index === root.currentIndex
                implicitWidth: segRow.implicitWidth + 22
                implicitHeight: root.height - 6
                width: implicitWidth
                height: implicitHeight

                Row {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: 5
                    SymbolicIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 12
                        source: seg.modelData.icon
                        iconColor: seg.active ? Theme.notchText : Theme.notchTextTertiary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.modelData.label
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        font.weight: seg.active ? Font.DemiBold : Font.Normal
                        color: seg.active ? Theme.notchText : Theme.notchTextSecondary
                        renderType: Theme.renderType
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(seg.index)
                }
            }
        }
    }
}
