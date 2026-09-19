import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services"
import "../common"

Item {
    id: root

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight + (Theme.space24 * 2)
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space24
        spacing: Theme.space24
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ── 1. Workspaces Indicator Settings ─────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "مساحات العمل (Workspaces)" : "Workspaces"

            // Style Selector: icons | numbers | dots
            SettingsRow {
                title: I18n.isRTL ? "نمط مؤشر مساحات العمل" : "Workspace Indicator Style"
                subtitle: I18n.isRTL
                    ? "اختر أسلوب عرض مساحات العمل في النوتش (أيقونات التطبيقات، أرقام ثابتة، أو نقاط)"
                    : "Choose how workspaces appear in the smart notch (app icons, fixed numbers, or dots)"
                icon: "view-app-grid-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "icons",   label: I18n.isRTL ? "أيقونات (افتراضي)" : "Icons (Default)" },
                            { id: "numbers", label: I18n.isRTL ? "أرقام فقط" : "Numbers Only" },
                            { id: "dots",    label: I18n.isRTL ? "نقاط فقط" : "Dots Only" }
                        ]
                        delegate: Rectangle {
                            id: stylePill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.workspaceIndicatorStyle || "icons") === modelData.id

                            height: 28
                            implicitWidth: styleText.implicitWidth + Theme.space16
                            radius: 14
                            color: stylePill.isSelected ? Theme.notchSurfaceActive : (styleMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: stylePill.isSelected ? Theme.notchBorderHighlight : (styleMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: styleText
                                anchors.centerIn: parent
                                text: stylePill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: stylePill.isSelected ? Font.DemiBold : Font.Normal
                                color: stylePill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: styleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setWorkspaceIndicatorStyle(stylePill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Fixed Workspaces Count
            SettingsRow {
                title: I18n.isRTL ? "عدد مساحات العمل الثابتة" : "Fixed Workspaces Count"
                subtitle: I18n.isRTL ? "الحد الأدنى لمساحات العمل المعروضة دائماً دون إخفاء" : "Minimum workspace slots shown permanently"
                icon: "view-paged-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [3, 5, 8, 10]
                        delegate: Rectangle {
                            id: countPill
                            required property int modelData
                            readonly property bool isSelected: ConfigManager.workspacesCount === modelData

                            height: 28
                            implicitWidth: countText.implicitWidth + Theme.space16
                            radius: 14
                            color: countPill.isSelected ? Theme.notchSurfaceActive : (countMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: countPill.isSelected ? Theme.notchBorderHighlight : (countMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: countPill.modelData.toString()
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: countPill.isSelected ? Font.DemiBold : Font.Normal
                                color: countPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: countMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setWorkspacesCount(countPill.modelData)
                            }
                        }
                    }
                }
            }

            // Show Workspaces Toggle
            SettingsRow {
                title: I18n.isRTL ? "إظهار مؤشر مساحات العمل" : "Show Workspaces Indicator"
                subtitle: I18n.isRTL ? "عرض قسم مساحات العمل في النوتش والشريط العلوي" : "Display workspace indicator in the smart notch and top bar"
                icon: "view-visible-symbolic"
                showDivider: false
                clickable: true
                onClicked: {
                    ConfigManager.topBarShowWorkspaces = !ConfigManager.topBarShowWorkspaces;
                    ConfigManager.saveConfig();
                }

                SettingsToggle {
                    checked: ConfigManager.topBarShowWorkspaces
                    onToggled: ch => {
                        ConfigManager.topBarShowWorkspaces = ch;
                        ConfigManager.saveConfig();
                    }
                }
            }
        }

        // ── 2. Clock & TopBar Display ────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "الساعة والشريط العلوي" : "Clock & Top Bar"

            // Clock Format: 12h / 24h
            SettingsRow {
                title: I18n.isRTL ? "تنسيق الوقت" : "Time Format"
                subtitle: I18n.isRTL ? "التبديل بين نظام 12 ساعة و24 ساعة" : "Toggle between 12-hour and 24-hour time format"
                icon: "preferences-system-time-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "12h", label: I18n.isRTL ? "12 ساعة (ص/م)" : "12-hour" },
                            { id: "24h", label: I18n.isRTL ? "24 ساعة" : "24-hour" }
                        ]
                        delegate: Rectangle {
                            id: clockPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.clockFormat === modelData.id

                            height: 28
                            implicitWidth: clockText.implicitWidth + Theme.space16
                            radius: 14
                            color: clockPill.isSelected ? Theme.notchSurfaceActive : (clockMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: clockPill.isSelected ? Theme.notchBorderHighlight : (clockMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: clockText
                                anchors.centerIn: parent
                                text: clockPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: clockPill.isSelected ? Font.DemiBold : Font.Normal
                                color: clockPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: clockMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.clockFormat = clockPill.modelData.id;
                                    ConfigManager.saveConfig();
                                }
                            }
                        }
                    }
                }
            }

            // Show Brand / Logo
            SettingsRow {
                title: I18n.isRTL ? "إظهار شعار DeloWay" : "Show DeloWay Brand"
                subtitle: I18n.isRTL ? "عرض شعار النظام في الزاوية العلوية" : "Display brand logo in the top corner"
                icon: "distributor-logo-symbolic"
                showDivider: false
                clickable: true
                onClicked: {
                    ConfigManager.topBarShowBrand = !ConfigManager.topBarShowBrand;
                    ConfigManager.saveConfig();
                }

                SettingsToggle {
                    checked: ConfigManager.topBarShowBrand
                    onToggled: ch => {
                        ConfigManager.topBarShowBrand = ch;
                        ConfigManager.saveConfig();
                    }
                }
            }
        }
    }
}
