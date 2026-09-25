import QtQuick
import QtQuick.Layouts
import "../../theme"

// Separator between groups of a DeloWay context menu (as in AppContextMenu).
Item {
    Layout.fillWidth: true
    implicitHeight: 9

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        width: parent.width - 16
        height: 1
        color: Theme.notchBorderSubtle
    }
}
