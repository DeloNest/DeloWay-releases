// Windows & Workspaces — Hyprland tiling behaviour and workspace count.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../theme"
import "../../../services"
import "../common"
import "../../"

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

        // ── 4. Window Management ─────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "إدارة النوافذ (Hyprland)" : "Window Management"

            // Window Gaps
            SettingsRow {
                title: I18n.isRTL ? "تباعد النوافذ (Gaps)" : "Window Gaps"
                subtitle: I18n.isRTL ? "التحكم في المسافة الفاصلة بين النوافذ وحواف الشاشة" : "Control spacing between tiled windows and screen edges"
                icon: "view-fullscreen-symbolic"
                showDivider: true

                // Inner gap; the outer one follows it
                SettingsChoice {
                    readonly property var outer: ({ 0: 0, 6: 10, 12: 18 })
                    options: [
                        { value: 0,  label: I18n.isRTL ? "معدومة" : "None" },
                        { value: 6,  label: I18n.isRTL ? "متوازنة" : "Balanced" },
                        { value: 12, label: I18n.isRTL ? "واسعة" : "Wide" }
                    ]
                    current: ConfigManager.windowGapsIn
                    onChosen: v => ConfigManager.setWindowGaps(v, outer[v])
                }
            }

            // Window Rounding (Hyprland - Independent from Shell radius)
            SettingsRow {
                title: I18n.isRTL ? "استدارة حواف النوافذ (Hyprland)" : "Window Rounding (Hyprland)"
                subtitle: I18n.isRTL ? "نصف قطر زوايا النوافذ العائمة والمصفصفة بالبكسل" : "Corner radius of tiled and floating windows in pixels"
                icon: "view-fullscreen-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [
                        { value: 0,  label: I18n.isRTL ? "حادة" : "Sharp" },
                        { value: 8,  label: "8px" },
                        { value: 12, label: "12px" },
                        { value: 16, label: "16px" }
                    ]
                    current: ConfigManager.windowRounding
                    onChosen: v => ConfigManager.setWindowRounding(v)
                }
            }

            // Active window border: monochrome steps, each shown with its own colour
            SettingsRow {
                title: I18n.tr("win_border")
                subtitle: I18n.tr("win_border_desc")
                icon: "window-new-symbolic"

                SettingsChoice {
                    readonly property bool dark: ConfigManager.themeMode !== "light"
                    options: ["contrast", "soft", "subtle", "off"].map(v => ({
                        value: v,
                        label: I18n.tr("win_border_" + v),
                        swatch: ConfigManager.borderColor(v, dark)
                    }))
                    current: ConfigManager.activeBorderStyle
                    onChosen: v => ConfigManager.setActiveBorderStyle(v)
                }
            }

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

        SettingsSection {
            title: I18n.isRTL ? "مساحات العمل" : "Workspaces"

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
        }
    }
}
