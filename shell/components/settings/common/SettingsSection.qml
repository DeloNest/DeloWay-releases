import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"

Item {
    id: root

    property string title: ""
    property real contentSpacing: 0
    property alias cardRadius: card.radius
    property alias cardColor: card.color

    default property alias content: contentLayout.data

    Layout.fillWidth: true
    implicitWidth: 300
    implicitHeight: mainCol.implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        spacing: Theme.space8
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Section Title
        Text {
            visible: root.title.length > 0
            text: root.title
            font.family: Theme.typography.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.notchTextSecondary
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space4
            Layout.rightMargin: Theme.space4
            horizontalAlignment: Text.AlignLeft
        }

        // Floating Card Container
        Rectangle {
            id: card
            Layout.fillWidth: true
            implicitHeight: contentLayout.implicitHeight
            radius: Theme.notchRadiusPanel
            color: Theme.notchSurface
            border.color: Theme.notchBorderSubtle
            border.width: 1
            clip: true
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            ColumnLayout {
                id: contentLayout
                width: parent.width
                spacing: root.contentSpacing
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true
            }
        }
    }
}
