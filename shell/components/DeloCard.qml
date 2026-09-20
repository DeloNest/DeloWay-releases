import QtQuick
import "../theme"

Rectangle {
    id: root

    property bool hoverable: false
    property bool selected: false
    property color surfaceColor: Theme.colors.surfaceCard
    property color surfaceHoverColor: Theme.colors.surfaceHover
    property color borderColor: Theme.hairline
    property color borderHoverColor: Theme.colors.borderHighlight
    property color selectedColor: Theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    property color selectedBorderColor: Theme.isDark ? "#ffffff" : "#0f172a"
    property int cardRadius: Theme.radiusMedium
    property int borderWidth: 1
    property int selectedBorderWidth: 2

    signal clicked()

    radius: root.cardRadius
    color: root.selected ? root.selectedColor : ((root.hoverable && mouseArea.containsMouse) ? root.surfaceHoverColor : root.surfaceColor)
    border.color: root.selected ? root.selectedBorderColor : ((root.hoverable && mouseArea.containsMouse) ? root.borderHoverColor : root.borderColor)
    border.width: root.selected ? root.selectedBorderWidth : root.borderWidth

    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.hoverable
        hoverEnabled: root.hoverable
        cursorShape: root.hoverable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
