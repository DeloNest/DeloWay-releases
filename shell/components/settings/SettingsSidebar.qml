import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme"
import "../../services"
import "../"

Item {
    id: root

    property string activeTab: "appearance"
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

            // Category 1: SYSTEM
            SidebarSectionHeader {
                text: I18n.isRTL ? "النظام" : "SYSTEM"
            }
            Repeater {
                model: [
                    { id: "appearance", icon: "applications-graphics-symbolic" },
                    { id: "language",   icon: "preferences-desktop-locale-symbolic" },
                    { id: "desktop",    icon: "user-home-symbolic" },
                    { id: "dock",       icon: "view-app-grid-symbolic" },
                    { id: "topbar",     icon: "preferences-system-symbolic" },
                    { id: "windows",    icon: "view-fullscreen-symbolic" }
                ]
                delegate: SidebarItem {
                    tabId: modelData.id
                    iconSource: modelData.icon
                    label: I18n.tr("tab_" + modelData.id)
                    isActive: root.activeTab === modelData.id
                    onActivated: root.tabSelected(modelData.id)
                }
            }

            Item { Layout.preferredHeight: Theme.space8 }

            // Category 2: CONNECTIVITY
            SidebarSectionHeader {
                text: I18n.isRTL ? "الاتصالات" : "CONNECTIVITY"
            }
            Repeater {
                model: [
                    { id: "network",   icon: "network-wireless-symbolic" },
                    { id: "bluetooth", icon: "bluetooth-active-symbolic" },
                    { id: "power",     icon: "power-profile-balanced-symbolic" }
                ]
                delegate: SidebarItem {
                    tabId: modelData.id
                    iconSource: modelData.icon
                    label: I18n.tr("tab_" + modelData.id)
                    isActive: root.activeTab === modelData.id
                    onActivated: root.tabSelected(modelData.id)
                }
            }

            Item { Layout.preferredHeight: Theme.space8 }

            // Category 3: PREFERENCES
            SidebarSectionHeader {
                text: I18n.isRTL ? "التفضيلات" : "PREFERENCES"
            }
            Repeater {
                model: [
                    { id: "notifications", icon: "preferences-system-notifications-symbolic" },
                    { id: "shortcuts",     icon: "preferences-desktop-keyboard-shortcuts-symbolic" },
                    { id: "applications",  icon: "applications-other-symbolic" }
                ]
                delegate: SidebarItem {
                    tabId: modelData.id
                    iconSource: modelData.icon
                    label: I18n.tr("tab_" + modelData.id)
                    isActive: root.activeTab === modelData.id
                    onActivated: root.tabSelected(modelData.id)
                }
            }

            Item { Layout.preferredHeight: Theme.space8 }

            // Category 4: ABOUT
            SidebarSectionHeader {
                text: I18n.isRTL ? "حول" : "ABOUT"
            }
            SidebarItem {
                tabId: "about"
                iconSource: "dialog-information-symbolic"
                label: I18n.tr("tab_about")
                isActive: root.activeTab === "about"
                onActivated: root.tabSelected("about")
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
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
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
                    font.pixelSize: 13
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
