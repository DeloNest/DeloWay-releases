// Appearance — theme, typography, interface shape and visual effects.
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

        // ── 1. Theme Mode (Dark / Light) ──────────────────────────
        SettingsSection {
            title: I18n.tr("theme_mode")

            SettingsRow {
                title: I18n.isRTL ? "المظهر الداكن (Dark Mode)" : "Dark Mode"
                subtitle: ConfigManager.themeMode === "dark"
                          ? (I18n.isRTL ? "مفعّل — أسطح داكنة نقية لتقليل استهلاك الطاقة وإراحة العين" : "Enabled — Deep dark surfaces for low eye strain")
                          : (I18n.isRTL ? "معطّل — أسطح فاتحة ناصعة (Light Mode)" : "Disabled — Clean light surfaces (Light Mode)")
                icon: ConfigManager.themeMode === "dark" ? "weather-clear-night-symbolic" : "weather-sunny-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setThemeMode(ConfigManager.themeMode === "dark" ? "light" : "dark")

                SettingsToggle {
                    checked: ConfigManager.themeMode === "dark"
                    onToggled: ch => ConfigManager.setThemeMode(ch ? "dark" : "light")
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "الخطوط" : "Typography"

            // Font Family
            SettingsRow {
                title: I18n.isRTL ? "خط الواجهة" : "Font Family"
                subtitle: I18n.isRTL ? "اختيار نوع الخط لكامل الواجهة وتطبيقات النظام" : "Select the desktop and application typeface"
                icon: "preferences-desktop-font-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { family: "Cairo",            label: "Cairo" },
                            { family: "Readex Pro",       label: "Readex Pro" },
                            { family: "Rubik",            label: "Rubik" },
                            { family: "Noto Kufi Arabic", label: "Noto Kufi" },
                            { family: "Inter",            label: "Inter" }
                        ]
                        delegate: Rectangle {
                            id: fontFamPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.fontFamily || "Cairo") === modelData.family

                            height: 28
                            implicitWidth: fontFamText.implicitWidth + Theme.space16
                            radius: 14
                            color: fontFamPill.isSelected ? Theme.notchSurfaceActive : (fontFamMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: fontFamPill.isSelected ? Theme.notchBorderHighlight : (fontFamMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: fontFamText
                                anchors.centerIn: parent
                                text: fontFamPill.modelData.label
                                font.family: fontFamPill.modelData.family
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: fontFamPill.isSelected ? Font.DemiBold : Font.Normal
                                color: fontFamPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: fontFamMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setFontFamily(fontFamPill.modelData.family)
                            }
                        }
                    }
                }
            }

            // Font Scale
            SettingsRow {
                title: I18n.isRTL ? "حجم الخط" : "Font Size"
                subtitle: I18n.isRTL ? "ضبط مقياس حجم الخطوط في الواجهة" : "Adjust user interface text scaling"
                icon: "preferences-desktop-font-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 0.85, label: I18n.isRTL ? "صغير" : "Small" },
                            { val: 1.0,  label: I18n.isRTL ? "قياسي" : "Standard" },
                            { val: 1.15, label: I18n.isRTL ? "كبير" : "Large" }
                        ]
                        delegate: Rectangle {
                            id: fontPill
                            required property var modelData
                            readonly property bool isSelected: Math.abs(ConfigManager.fontSizeScale - modelData.val) < 0.05

                            height: 28
                            implicitWidth: fontText.implicitWidth + Theme.space16
                            radius: 14
                            color: fontPill.isSelected ? Theme.notchSurfaceActive : (fontMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: fontPill.isSelected ? Theme.notchBorderHighlight : (fontMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: fontText
                                anchors.centerIn: parent
                                text: fontPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: fontPill.isSelected ? Font.DemiBold : Font.Normal
                                color: fontPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: fontMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setFontSizeScale(fontPill.modelData.val)
                            }
                        }
                    }
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "الواجهة والتأثيرات" : "Interface & Effects"

            // Corner Radius (Shell Elements)
            SettingsRow {
                title: I18n.isRTL ? "استدارة حواف الواجهة (Shell)" : "Shell Corner Radius"
                subtitle: I18n.isRTL ? "نصف قطر زوايا بطاقات وكبسولات وأزرار شل DeloWay" : "Corner radius of DeloWay shell cards, capsules, and buttons"
                icon: "view-fullscreen-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 4,  label: I18n.isRTL ? "حادة (4px)" : "Sharp (4px)" },
                            { val: 8,  label: I18n.isRTL ? "قياسية (8px)" : "Standard (8px)" },
                            { val: 14, label: I18n.isRTL ? "دائرية (14px)" : "Rounded (14px)" }
                        ]
                        delegate: Rectangle {
                            id: radPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.elementRadius === modelData.val

                            height: 28
                            implicitWidth: radText.implicitWidth + Theme.space16
                            radius: 14
                            color: radPill.isSelected ? Theme.notchSurfaceActive : (radMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: radPill.isSelected ? Theme.notchBorderHighlight : (radMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: radText
                                anchors.centerIn: parent
                                text: radPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: radPill.isSelected ? Font.DemiBold : Font.Normal
                                color: radPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: radMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setElementRadius(radPill.modelData.val)
                            }
                        }
                    }
                }
            }

            // Performance Tier
            SettingsRow {
                title: I18n.isRTL ? "مستوى التأثيرات الرسومية" : "Graphics & Visual Effects"
                subtitle: I18n.isRTL ? "التحكم بتأثيرات الزجاج والبلور والظلال وسلاسة الحركة" : "Control blur, acrylic glass, and layered shadow fidelity"
                icon: "power-profile-balanced-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { val: 0, label: I18n.isRTL ? "خفيف" : "Efficient" },
                            { val: 1, label: I18n.isRTL ? "متوازن" : "Balanced" },
                            { val: 2, label: I18n.isRTL ? "فائق" : "High" }
                        ]
                        delegate: Rectangle {
                            id: tierPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.performanceTier === modelData.val

                            height: 28
                            implicitWidth: tierText.implicitWidth + Theme.space16
                            radius: 14
                            color: tierPill.isSelected ? Theme.notchSurfaceActive : (tierMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: tierPill.isSelected ? Theme.notchBorderHighlight : (tierMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: tierText
                                anchors.centerIn: parent
                                text: tierPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.DemiBold
                                color: tierPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: tierMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setPerformanceTier(tierPill.modelData.val)
                            }
                        }
                    }
                }
            }
        }
    }
}
