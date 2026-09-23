import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"
import "../../services"
import "../"

Item {
    id: root

    property string activeTab: "network"
    signal tabSelected(string tabId)

    implicitWidth: 240
    Layout.fillHeight: true
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    // Background - transparent to reveal OLED black windowCard
    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    ScrollView {
        id: sidebarScroll
        anchors.fill: parent
        anchors.topMargin: Theme.space8
        anchors.bottomMargin: Theme.space8
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: sidebarScroll.availableWidth
            spacing: Theme.space4
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // Grouped navigation: Connectivity · Personalization · System
            Repeater {
                model: ShellState.settingsGroups
                delegate: ColumnLayout {
                    id: groupCol
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.topMargin: index === 0 ? 0 : Theme.space12
                    spacing: Theme.space4

                    SidebarSectionHeader {
                        text: I18n.tr("settings_group_" + groupCol.modelData.id)
                    }

                    Repeater {
                        model: groupCol.modelData.pages
                        delegate: SidebarItem {
                            required property string modelData
                            tabId: modelData
                            iconSource: ShellState.settingsPages[modelData].icon
                            label: I18n.tr("settings_page_" + modelData)
                            isActive: root.activeTab === modelData
                            onActivated: root.tabSelected(modelData)
                        }
                    }
                }
            }
        }
    }

    // Inline components for clean encapsulation
    component SidebarSectionHeader: Item {
        property alias text: headerText.text
        Layout.fillWidth: true
        implicitHeight: 28
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        Text {
            id: headerText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.space16
            anchors.rightMargin: Theme.space16
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(11)
            font.weight: Font.DemiBold
            font.letterSpacing: I18n.isRTL ? 0 : 0.8   // tracking breaks Arabic joining
            color: Theme.notchTextTertiary
            horizontalAlignment: Text.AlignLeft
        }
    }

    component SidebarItem: Item {
        id: itemRoot
        property string tabId: ""
        property string iconSource: ""
        property string label: ""
        property bool isActive: false
        signal activated()

        Layout.fillWidth: true
        Layout.leftMargin: Theme.space8
        Layout.rightMargin: Theme.space8
        implicitHeight: 38
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        Rectangle {
            id: itemBg
            anchors.fill: parent
            radius: 19
            color: itemRoot.isActive ? Theme.notchSurfaceActive : (itemMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
            border.color: itemRoot.isActive ? Theme.notchBorder : "transparent"
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
            }
            Behavior on border.color {
                ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space8
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                SymbolicIcon {
                    source: itemRoot.iconSource
                    iconSize: 16
                    iconColor: (itemRoot.isActive || itemMa.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on iconColor {
                        ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
                    }
                }

                Text {
                    text: itemRoot.label
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.weight: (itemRoot.isActive || itemMa.containsMouse) ? Font.DemiBold : Font.Normal
                    color: (itemRoot.isActive || itemMa.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    Behavior on color {
                        ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
                    }
                }
            }
        }

        MouseArea {
            id: itemMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: itemRoot.activated()
        }
    }
}
