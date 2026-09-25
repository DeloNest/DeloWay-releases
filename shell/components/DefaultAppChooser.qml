import QtQuick
import QtQuick.Layouts
import "../theme"
import "../services"

// The choices for one default-app role as a wrapping row of chips — shared by the Setup
// Wizard and Settings → Apps (DefaultApps is the model). Installed apps are chosen with a
// click; one that is not installed says so, is installed on click (pamac) and becomes
// the choice once the install succeeds. The current choice is the inverse (white on
// black / slate on white) chip.
Flow {
    id: root

    property string role: ""

    spacing: Theme.space8
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    Repeater {
        model: DefaultApps.options(root.role)

        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool selected: DefaultApps.isSelected(root.role, chip.modelData)
            readonly property bool installing: DefaultApps.isInstalling(chip.modelData)

            height: Math.max(34, Theme.fontSize(12) + 20)
            width: chipRow.implicitWidth + Theme.space16 + 4
            radius: height / 2
            color: chip.selected ? Theme.inverseSurface
                                 : (chipMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
            border.color: chip.selected ? Theme.inverseSurface
                                        : (chipMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6

                AppIcon {
                    iconSize: 18
                    source: chip.modelData.icon
                    opacity: chip.modelData.installed ? 1.0 : 0.55
                }

                Text {
                    text: chip.modelData.name
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.weight: chip.selected ? Font.DemiBold : Font.Normal
                    color: chip.selected ? Theme.inverseText
                                         : (chip.modelData.installed ? Theme.notchText : Theme.notchTextSecondary)
                }

                // Not installed yet: "Install", or the progress while it installs
                Text {
                    visible: !chip.modelData.installed
                    text: chip.installing ? I18n.digits(Math.round(DefaultApps.installProgress(chip.modelData) * 100) + "%")
                                          : I18n.tr("install_short")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(10)
                    color: chip.selected ? Theme.inverseText : Theme.notchTextSecondary
                }
            }

            // Install progress along the chip's bottom edge
            Rectangle {
                visible: chip.installing
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: chip.radius / 2
                height: 2
                radius: 1
                width: (parent.width - chip.radius) * Math.max(0.05, DefaultApps.installProgress(chip.modelData))
                color: Theme.notchText
                Behavior on width { NumberAnimation { duration: Theme.motionFast } }
            }

            MouseArea {
                id: chipMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DefaultApps.choose(root.role, chip.modelData)
            }
        }
    }
}
