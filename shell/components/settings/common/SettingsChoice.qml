import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"

// One choice out of a few, as a row of pills (Settings rows). The selected pill takes the
// identity's active surface; the others stay outlined.
//
//   SettingsChoice {
//       options: [{ value: "all", label: "…" }, …]
//       current: ConfigManager.dockIndicator
//       onChosen: v => ConfigManager.setDockIndicator(v)
//   }
//
// mirror: false keeps a physical order (Left · Bottom · Right) in both languages.
RowLayout {
    id: root

    property var options: []
    property var current
    property bool mirror: true

    signal chosen(var value)

    spacing: Theme.space4
    LayoutMirroring.enabled: root.mirror && I18n.isRTL
    LayoutMirroring.childrenInherit: true

    Repeater {
        model: root.options

        delegate: Rectangle {
            id: pill
            required property var modelData
            readonly property bool selected: root.current === pill.modelData.value

            implicitHeight: 28
            implicitWidth: label.implicitWidth + Theme.space16
            radius: 14
            color: pill.selected ? Theme.inverseSurface
                 : (ma.containsMouse ? Theme.notchSurfaceHover : "transparent")
            border.width: 1
            border.color: pill.selected ? Theme.inverseSurface
                        : (ma.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            Text {
                id: label
                anchors.centerIn: parent
                text: pill.modelData.label
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: pill.selected ? Font.DemiBold : Font.Normal
                color: pill.selected ? Theme.inverseText : Theme.notchTextSecondary
                renderType: Theme.renderType
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!pill.selected) root.chosen(pill.modelData.value)
            }
        }
    }
}
