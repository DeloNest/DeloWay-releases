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

    // Background
    Rectangle {
        anchors.fill: parent
        color: Theme.colors.backgroundAlt
    }

    // Border separating sidebar from content (RTL / LTR aware)
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: I18n.isRTL ? parent.left : undefined
        anchors.right: I18n.isRTL ? undefined : parent.right
        width: 1
        color: Theme.borderSubtle
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

        Text {
            id: headerText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.space16
            anchors.rightMargin: Theme.space16
            font.family: Theme.typography.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            color: Theme.colors.textTertiary
            horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
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
        implicitHeight: 36

        Rectangle {
            id: itemBg
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: itemRoot.isActive ? Theme.colors.surfaceElevated : (itemMa.containsMouse ? Theme.colors.surfaceHover : "transparent")
            border.color: itemRoot.isActive ? Theme.borderSubtle : "transparent"
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Theme.motionFast }
            }

            // Active accent indicator bar on the outer edge
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: I18n.isRTL ? undefined : parent.left
                anchors.right: I18n.isRTL ? parent.right : undefined
                anchors.margins: 3
                width: 3
                height: 18
                radius: 2
                color: Theme.colors.accent
                visible: itemRoot.isActive
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space16
                anchors.rightMargin: Theme.space16
                spacing: Theme.space8
                layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight

                SymbolicIcon {
                    source: itemRoot.iconSource
                    iconSize: 16
                    iconColor: itemRoot.isActive ? Theme.colors.accent : (itemMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: itemRoot.label
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 13
                    font.weight: itemRoot.isActive ? Font.DemiBold : Font.Normal
                    color: itemRoot.isActive ? Theme.colors.text : (itemMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                    horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
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
