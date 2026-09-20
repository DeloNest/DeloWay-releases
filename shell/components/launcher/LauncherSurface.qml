import QtQuick
import "../../theme"
import "../../services"

Rectangle {
    id: root

    default property alias content: contentItem.data

    radius: Theme.notchRadiusWindow
    color: Theme.notchBackground
    border.color: Theme.notchBorder
    border.width: 1

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
