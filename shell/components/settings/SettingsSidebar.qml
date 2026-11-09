import "../"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string activeTab: "network"
    property string searchQuery: searchInput.text.trim().toLowerCase()
    readonly property var allPages: {
        const list = [];
        for (const g of ShellState.settingsGroups) {
            for (const p of g.pages) {
                if (list.indexOf(p) < 0)
                    list.push(p);

            }
        }
        return list;
    }
    readonly property var searchResults: {
        const q = root.searchQuery;
        if (!q)
            return [];

        return allPages.filter((p) => {
            const title = I18n.tr("settings_page_" + p).toLowerCase();
            const desc = I18n.tr("settings_page_" + p + "_desc").toLowerCase();
            if (p.indexOf(q) >= 0 || title.indexOf(q) >= 0 || desc.indexOf(q) >= 0)
                return true;

            if ((q === "hdr" || q === "hz" || q === "resolution" || q === "دقة" || q === "شاشة" || q === "عرض") && p === "display")
                return true;

            if ((q === "wifi" || q === "واي فاي" || q === "ethernet" || q === "انترنت" || q === "ip") && p === "network")
                return true;

            if ((q === "bt" || q === "بلوتوث" || q === "سماعة") && p === "bluetooth")
                return true;

            if ((q === "dark" || q === "light" || q === "glass" || q === "داكن" || q === "فاتح" || q === "زجاجي" || q === "خط" || q === "font") && p === "appearance")
                return true;

            if ((q === "wallpaper" || q === "خلفية" || q === "سطح المكتب") && p === "wallpaper")
                return true;

            if ((q === "battery" || q === "power" || q === "بطارية" || q === "طاقة" || q === "سكون" || q === "sleep") && p === "power")
                return true;

            if ((q === "shortcut" || q === "اختصار" || q === "مفاتيح" || q === "keyboard") && p === "shortcuts")
                return true;

            return false;
        });
    }

    signal tabSelected(string tabId)

    implicitWidth: 240
    Layout.fillHeight: true
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space8
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ── Search Input Box ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space8
            Layout.rightMargin: Theme.space8
            Layout.topMargin: Theme.space4
            height: 32
            radius: 16
            color: searchInput.activeFocus ? Theme.notchSurfaceActive : (searchMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
            border.color: searchInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                SymbolicIcon {
                    source: "edit-find-symbolic"
                    iconSize: 13
                    iconColor: searchInput.activeFocus ? Theme.notchText : Theme.notchTextSecondary
                }

                TextInput {
                    id: searchInput

                    Layout.fillWidth: true
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchText
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: I18n.tr("search_settings")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
                        visible: !searchInput.text && !searchInput.activeFocus
                    }

                }

                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 18
                    height: 18
                    radius: 9
                    color: clearMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                    SymbolicIcon {
                        anchors.centerIn: parent
                        source: "edit-clear-symbolic"
                        iconSize: 10
                        iconColor: Theme.notchTextSecondary
                    }

                    MouseArea {
                        id: clearMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }

                }

            }

            MouseArea {
                id: searchMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                acceptedButtons: Qt.NoButton
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.motionFast
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.motionFast
                }

            }

        }

        // ── Scrollable Sidebar Items ──────────────────────────────────
        ScrollView {
            id: sidebarScroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: sidebarScroll.availableWidth
                spacing: Theme.space4
                LayoutMirroring.enabled: I18n.isRTL
                LayoutMirroring.childrenInherit: true

                // Mode A: Grouped navigation when search is empty
                Repeater {
                    visible: root.searchQuery.length === 0
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
                                iconSource: ShellState.settingsPages[modelData] ? ShellState.settingsPages[modelData].icon : ""
                                label: I18n.tr("settings_page_" + modelData)
                                isActive: root.activeTab === modelData
                                onActivated: root.tabSelected(modelData)
                            }

                        }

                    }

                }

                // Mode B: Filtered search results
                Repeater {
                    visible: root.searchQuery.length > 0
                    model: root.searchResults

                    delegate: SidebarItem {
                        required property string modelData

                        tabId: modelData
                        iconSource: ShellState.settingsPages[modelData] ? ShellState.settingsPages[modelData].icon : ""
                        label: I18n.tr("settings_page_" + modelData)
                        isActive: root.activeTab === modelData
                        onActivated: root.tabSelected(modelData)
                    }

                }

                // Empty search state
                Item {
                    visible: root.searchQuery.length > 0 && root.searchResults.length === 0
                    Layout.fillWidth: true
                    implicitHeight: 60

                    Text {
                        anchors.centerIn: parent
                        text: I18n.isRTL ? "لا توجد نتائج مطابقة" : "No matching settings"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
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
            font.letterSpacing: I18n.isRTL ? 0 : 0.8
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
                        ColorAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

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
                        ColorAnimation {
                            duration: Theme.motionFast
                            easing.type: Theme.easingEnter
                        }

                    }

                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easingEnter
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.motionFast
                    easing.type: Theme.easingEnter
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
