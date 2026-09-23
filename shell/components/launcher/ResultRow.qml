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
    // Overridable type scale (App Drawer uses larger text than the Spotlight launcher).
    property real nameSize: 13.5
    property real descSize: 11.5

    signal clicked(var mouse)
    signal hovered()

    height: 48
    width: ListView.view ? ListView.view.width : (parent ? parent.width : 500)
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
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        // Icon container (30x30)
        Item {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter

            AppIcon {
                anchors.centerIn: parent
                iconSize: 28
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
                    iconSize: 16
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
            // Cairo carries tall built-in leading; tighten so title + subtitle sit inside
            // the 48px row instead of crowding the next result.
            spacing: -4

            Text {
                Layout.fillWidth: true
                text: (root.resultData && root.resultData.name) ? root.resultData.name : ""
                horizontalAlignment: Text.AlignLeft
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(root.nameSize)
                font.weight: root.isSelected ? Font.DemiBold : Font.Medium
                color: Theme.notchText
                renderType: Theme.renderType
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (root.resultData && root.resultData.desc) ? root.resultData.desc : ""
                horizontalAlignment: Text.AlignLeft
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(root.descSize)
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
            // ↵ points back to the line start: flip it in Arabic (glyphs are not mirrored).
            transform: Scale { origin.x: width / 2; xScale: I18n.isRTL ? -1 : 1 }
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(13)
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
