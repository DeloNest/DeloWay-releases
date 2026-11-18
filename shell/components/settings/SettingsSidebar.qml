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
    readonly property var pageKeywords: ({
        "sound": ["sound", "audio", "mic", "microphone", "speaker", "speakers", "volume", "headphone", "headset", "صوت", "ميكروفون", "مايك", "سماعة", "سماعات", "مكبر صوت"],
        "display": ["hdr", "hz", "resolution", "scale", "dpi", "night light", "vrr", "دقة", "شاشة", "عرض", "إضاءة ليلية", "سطوع", "brightness"],
        "network": ["wifi", "wi-fi", "واي فاي", "ethernet", "انترنت", "internet", "ip", "hotspot", "شبكة", "نقطة اتصال", "lan", "dns"],
        "bluetooth": ["bt", "بلوتوث", "سماعة", "headphone", "device", "أجهزة", "اقتران", "pair"],
        "appearance": ["dark", "light", "glass", "داكن", "فاتح", "زجاجي", "خط", "font", "typography", "radius", "استدارة", "أداء", "performance", "theme", "ثيم", "مظهر"],
        "wallpaper": ["wallpaper", "خلفية", "سطح المكتب", "desktop", "widgets", "أدوات", "icons", "أيقونات"],
        "topbar": ["capsule", "كبسولة", "notch", "نوتش", "seconds", "ثواني", "workspaces", "مساحات العمل", "شريط علوي", "top bar", "clock"],
        "dock": ["dock", "taskbar", "شريط المهام", "شريط", "pinned", "مثبت", "icon size", "حجم الأيقونة", "autohide", "إخفاء تلقائي"],
        "windows": ["windows", "نوافذ", "workspaces", "مساحات العمل", "touchpad", "لوحة اللمس", "mouse", "ماوس", "gestures", "إيماءات", "gaps", "فجوات", "rounding", "borders", "حواف"],
        "shortcuts": ["shortcut", "shortcuts", "اختصار", "اختصارات", "مفاتيح", "keyboard", "لوحة المفاتيح", "keybinding", "bindings", "أزرار"],
        "notifications": ["notifications", "إشعارات", "إشعار", "dnd", "عدم الإزعاج", "toast", "sound", "صوت", "timeout", "مهلة"],
        "power": ["battery", "power", "بطارية", "طاقة", "سكون", "sleep", "saver", "توفير", "balanced", "متوازن", "performance", "أداء", "suspend", "lid"],
        "apps": ["apps", "applications", "تطبيقات", "default", "افتراضي", "browser", "متصفح", "terminal", "طرفية", "file manager", "مدير الملفات", "music", "موسيقى", "permissions", "صلاحيات"],
        "time_language": ["time", "language", "وقت", "لغة", "clock", "ساعة", "hijri", "هجري", "calendar", "تقويم", "timezone", "منطقة زمنية", "keyboard layout", "لوحة مفاتيح", "input", "إدخال", "format", "تنسيق"],
        "updates": ["updates", "update", "تحديث", "تحديثات", "git", "changelog", "سجل التغييرات", "version", "إصدار", "channel", "قناة"],
        "about": ["about", "حول", "system", "نظام", "os", "specs", "مواصفات", "hardware", "عتاد", "cpu", "معالج", "gpu", "ram", "ذاكرة", "reset", "إعادة ضبط"]
    })

    readonly property var searchResults: {
        const q = root.searchQuery;
        if (!q)
            return [];

        return allPages.filter((p) => {
            const title = I18n.tr("settings_page_" + p).toLowerCase();
            const desc = I18n.tr("settings_page_" + p + "_desc").toLowerCase();
            if (p.indexOf(q) >= 0 || title.indexOf(q) >= 0 || desc.indexOf(q) >= 0)
                return true;

            const kw = pageKeywords[p];
            if (kw) {
                for (let i = 0; i < kw.length; i++) {
                    if (kw[i].indexOf(q) >= 0 || q.indexOf(kw[i]) >= 0)
                        return true;
                }
            }

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
            height: Math.max(32, searchRow.implicitHeight + 8)
            radius: height / 2
            color: searchInput.activeFocus ? Theme.notchSurfaceActive : (searchMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
            border.color: searchInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
            border.width: 1

            RowLayout {
                id: searchRow
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
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

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
                        Layout.topMargin: index === 0 ? 0 : Theme.space8
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
                        text: I18n.tr("search_no_results")
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
        implicitHeight: Math.max(26, headerText.implicitHeight + 6)
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
        implicitHeight: Math.max(36, itemRow.implicitHeight + 10)
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        Rectangle {
            id: itemBg

            anchors.fill: parent
            radius: height / 2
            color: itemRoot.isActive ? Theme.notchSurfaceActive : (itemMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
            border.color: itemRoot.isActive ? Theme.notchBorder : "transparent"
            border.width: 1

            RowLayout {
                id: itemRow
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
