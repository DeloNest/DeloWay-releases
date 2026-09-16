import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import "../../"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color iconColor: Theme.notchTextSecondary
    property bool showDivider: true
    property bool clickable: false
    signal clicked()

    default property alias control: controlLayout.data

    Layout.fillWidth: true
    implicitWidth: 300
    implicitHeight: Math.max(52, contentRow.implicitHeight + Theme.space16)

    color: (root.clickable && rowMa.containsMouse) ? Theme.notchSurfaceHover : "transparent"
    Behavior on color {
        ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Theme.space16
        anchors.rightMargin: Theme.space16
        spacing: 12
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Optional Leading Icon
        SymbolicIcon {
            visible: root.icon.length > 0
            source: root.icon
            iconSize: 16
            iconColor: (root.clickable && rowMa.containsMouse) ? Theme.notchText : root.iconColor
            Layout.alignment: Qt.AlignVCenter
            Behavior on iconColor {
                ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
            }
        }

        // Title and Subtitle
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.notchText
                Layout.fillWidth: true
                elide: Text.ElideRight
                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
            }

            Text {
                visible: root.subtitle.length > 0
                text: root.subtitle
                font.family: Theme.typography.fontFamily
                font.pixelSize: 11
                color: Theme.notchTextSecondary
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
            }
        }

        // Trailing Control Area (Switches, buttons, badges, selectors)
        RowLayout {
            id: controlLayout
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.space8
        }
    }

    // Bottom Subtle Divider
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space16
        anchors.rightMargin: Theme.space16
        height: 1
        color: Theme.notchBorderSubtle
        visible: root.showDivider
    }

    MouseArea {
        id: rowMa
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
