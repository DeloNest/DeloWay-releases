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

        // ── 1. Window Gaps ───────────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "فجوات النوافذ" : "Window Gaps"

            SettingsRow {
                title: I18n.isRTL ? "تباعد النوافذ (Gaps)" : "Window Gaps"
                subtitle: I18n.isRTL ? "التحكم في المسافة الفاصلة بين النوافذ وحواف الشاشة" : "Control spacing between tiled windows and screen edges"
                icon: "view-fullscreen-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { gIn: 0,  gOut: 0,  label: I18n.isRTL ? "معدومة (0px)" : "None (0px)" },
                            { gIn: 6,  gOut: 10, label: I18n.isRTL ? "متوازنة (6px)" : "Balanced (6px)" },
                            { gIn: 12, gOut: 18, label: I18n.isRTL ? "واسعة (12px)" : "Wide (12px)" }
                        ]
                        delegate: Rectangle {
                            id: gapPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.windowGapsIn === modelData.gIn

                            height: 28
                            implicitWidth: gapText.implicitWidth + Theme.space16
                            radius: 14
                            color: gapPill.isSelected ? Theme.notchSurfaceActive : (gapMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: gapPill.isSelected ? Theme.notchBorderHighlight : (gapMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: gapText
                                anchors.centerIn: parent
                                text: gapPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: gapPill.isSelected ? Font.DemiBold : Font.Normal
                                color: gapPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: gapMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setWindowGaps(gapPill.modelData.gIn, gapPill.modelData.gOut)
                            }
                        }
                    }
                }
            }
        }

        // ── 2. Focus & Dimming (System Behavior) ─────────────────────
        SettingsSection {
            title: I18n.isRTL ? "سلوك النوافذ والتركيز" : "Window Focus & Dimming"

            // Focus Follows Mouse
            SettingsRow {
                title: I18n.isRTL ? "تتبع مؤشر الفأرة" : "Focus Follows Mouse"
                subtitle: I18n.isRTL ? "نقل التركيز تلقائياً للنافذة بمجرد تحريك المؤشر فوقها" : "Automatically focus window when moving cursor over it"
                icon: "system-search-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setFollowMouse(!ConfigManager.followMouse)

                SettingsToggle {
                    checked: ConfigManager.followMouse
                    onToggled: ch => ConfigManager.setFollowMouse(ch)
                }
            }

            // Dim Inactive Windows
            SettingsRow {
                title: I18n.isRTL ? "تعتيم النوافذ الخلفية" : "Dim Inactive Windows"
                subtitle: I18n.isRTL ? "خفض سطوع النوافذ غير النشطة للتركيز على النافذة الحالية" : "Dim inactive background windows to emphasize current task"
                icon: "display-brightness-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setDimInactive(!ConfigManager.dimInactive)

                SettingsToggle {
                    checked: ConfigManager.dimInactive
                    onToggled: ch => ConfigManager.setDimInactive(ch)
                }
            }
        }

        // ── 3. Workspaces Management ─────────────────────────────────
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
                showDivider: false

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
        }

        // ── 4. Advanced Settings (Collapsible) ────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "إعدادات متقدمة (Advanced)" : "Advanced Settings"
            collapsible: true
            isExpanded: false

            // Show Workspaces Toggle
            SettingsRow {
                title: I18n.isRTL ? "إظهار مؤشر مساحات العمل" : "Show Workspaces Indicator"
                subtitle: I18n.isRTL ? "عرض قسم مساحات العمل في النوتش والشريط العلوي" : "Display workspace indicator in the smart notch and top bar"
                icon: "view-visible-symbolic"
                showDivider: true
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

            // Window Rounding
            SettingsRow {
                title: I18n.isRTL ? "استدارة حواف النوافذ (Hyprland)" : "Window Rounding (Hyprland)"
                subtitle: I18n.isRTL ? "نصف قطر زوايا النوافذ العائمة والمصفصفة بالبكسل" : "Corner radius of tiled and floating windows in pixels"
                icon: "view-fullscreen-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 0,  label: I18n.isRTL ? "0px (حادة)" : "0px (Sharp)" },
                            { val: 8,  label: I18n.isRTL ? "8px" : "8px" },
                            { val: 12, label: I18n.isRTL ? "12px" : "12px" },
                            { val: 16, label: I18n.isRTL ? "16px" : "16px" }
                        ]
                        delegate: Rectangle {
                            id: roundPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.windowRounding === modelData.val

                            height: 28
                            implicitWidth: roundText.implicitWidth + Theme.space16
                            radius: 14
                            color: roundPill.isSelected ? Theme.notchSurfaceActive : (roundMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: roundPill.isSelected ? Theme.notchBorderHighlight : (roundMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: roundText
                                anchors.centerIn: parent
                                text: roundPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: roundPill.isSelected ? Font.DemiBold : Font.Normal
                                color: roundPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: roundMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.setWindowRounding(roundPill.modelData.val);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
