import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

Item {
    id: root

    property string text: ""
    property int count: -1

    implicitWidth: labelRow.implicitWidth
    implicitHeight: 28

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
            font.pixelSize: Theme.fontSize(11)
            font.weight: Font.DemiBold
            color: Theme.notchTextTertiary
            renderType: Theme.renderType
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            visible: root.count >= 0
            height: 18
            implicitWidth: countText.implicitWidth + 10
            radius: Theme.notchRadiusPill
            color: Theme.notchSurface

            Text {
                id: countText
                anchors.centerIn: parent
                text: root.count.toString()
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(10)
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
