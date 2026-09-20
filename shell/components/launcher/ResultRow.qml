import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../"

Rectangle {
    id: root

    property var resultData: null
    property bool isSelected: false
    property bool isHovered: false

    signal clicked(var mouse)
    signal hovered()

    height: 52
    width: ListView.view ? ListView.view.width : (parent ? parent.width : 616)
    radius: Theme.notchRadiusCard

    color: isSelected
           ? Theme.notchSurfaceActive
           : (isHovered ? Theme.notchSurfaceHover : "transparent")

    border.color: isSelected ? Theme.notchBorderHighlight : "transparent"
    border.width: 1

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // Icon container (32x32)
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter

            AppIcon {
                anchors.centerIn: parent
                iconSize: 32
                source: (root.resultData && root.resultData.icon) ? root.resultData.icon : ""
                visible: root.resultData && root.resultData.isAppIcon
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.notchRadiusPill
                color: root.isSelected ? Theme.notchSurfaceActive : Theme.notchSurface
                visible: root.resultData && !root.resultData.isAppIcon

                SymbolicIcon {
                    anchors.centerIn: parent
                    iconSize: 18
                    source: (root.resultData && root.resultData.icon) ? root.resultData.icon : ""
                    iconColor: (root.resultData && (root.resultData.id === "shutdown" || root.resultData.id === "restart"))
                               ? Theme.colors.urgent
                               : (root.isSelected ? Theme.notchText : Theme.notchTextSecondary)
                }
            }
        }

        // Titles Column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: (root.resultData && root.resultData.name) ? root.resultData.name : ""
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(14)
                font.weight: root.isSelected ? Font.DemiBold : Font.Medium
                color: Theme.notchText
                renderType: Theme.renderType
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (root.resultData && root.resultData.desc) ? root.resultData.desc : ""
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.Normal
                color: Theme.notchTextSecondary
                renderType: Theme.renderType
                elide: Text.ElideRight
            }
        }

        // Selection Enter hint (↵) visible only when selected
        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: root.isSelected
            text: "↵"
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(14)
            font.weight: Font.DemiBold
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
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
