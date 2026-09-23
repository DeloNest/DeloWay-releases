import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

Item {
    id: root

    property string text: ""
    property int count: -1
    // Sizes are overridable per host (the App Drawer uses a larger scale).
    property real labelSize: 11
    property real countSize: 10

    implicitWidth: labelRow.implicitWidth
    implicitHeight: Math.max(28, labelSize + 16)

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    RowLayout {
        id: labelRow
        anchors.fill: parent
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.text
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(root.labelSize)
            font.weight: Font.DemiBold
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            visible: root.count >= 0
            height: Math.round(root.countSize + 8)
            implicitWidth: countText.implicitWidth + 12
            radius: Theme.notchRadiusPill
            color: Theme.notchSurface

            Text {
                id: countText
                anchors.centerIn: parent
                text: root.count.toString()
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(root.countSize)
                font.weight: Font.Medium
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
