import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../"

Rectangle {
    id: root

    property var appData: null
    property bool isSelected: false
    property bool isHovered: false

    signal clicked(var mouse)
    signal hovered()

    width: 120
    height: 108
    radius: Theme.notchRadiusCard

    color: isSelected
           ? Theme.notchSurfaceActive
           : (isHovered ? Theme.notchSurfaceHover : "transparent")

    border.color: isSelected ? Theme.notchBorderHighlight : "transparent"
    border.width: 1

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48

            AppIcon {
                anchors.centerIn: parent
                iconSize: 48
                source: (root.appData && root.appData.icon) ? root.appData.icon : "application-x-executable"
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: (root.appData && root.appData.name) ? root.appData.name : ""
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            font.weight: root.isSelected ? Font.DemiBold : Font.Medium
            color: Theme.notchText
            renderType: Theme.renderType
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.15
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered()
        onClicked: mouse => root.clicked(mouse)
    }
}
