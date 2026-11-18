import "../../"
import "../../../services"
import "../../../theme"
import "../common"
// Appearance — theme, typography, interface shape and visual effects.
import QtQuick
import QtQuick.Layouts
import Quickshell

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
                title: I18n.isRTL ? "المظهر" : "Appearance"
                subtitle: ConfigManager.themeName === "dark" ? (I18n.isRTL ? "داكن — أسطح سوداء نقية لشاشات OLED" : "Dark — pure black OLED surfaces") : (ConfigManager.themeName === "glass" ? (I18n.isRTL ? "زجاجي — أسطح زجاجية شبه شفافة مع تمويه عميق" : "Glass — translucent frosted glass with deep blur") : (I18n.isRTL ? "فاتح — أسطح محايدة عالية التباين" : "Light — crisp high-contrast neutrals"))
                icon: ConfigManager.themeName === "dark" ? "weather-clear-night-symbolic" : (ConfigManager.themeName === "glass" ? "applications-graphics-symbolic" : "weather-sunny-symbolic")
                showDivider: false

                // Dark | Glass | Light — the three theme choices; everything else (GTK, icons,
                // kitty, window borders) follows it via ConfigManager.setTheme.
                SettingsChoice {
                    options: [
                        { "value": "dark", "label": I18n.isRTL ? "داكن" : "Dark" },
                        { "value": "glass", "label": I18n.isRTL ? "زجاجي" : "Glass" },
                        { "value": "light", "label": I18n.isRTL ? "فاتح" : "Light" }
                    ]
                    current: ConfigManager.themeName
                    onChosen: (v) => ConfigManager.setTheme(v)
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
                        // Only fonts that are installed (Readex Pro and Rubik were offered
                        // without being installed: picking one silently fell back).
                        model: [{
                            "family": "Cairo",
                            "label": "Cairo"
                        }, {
                            "family": "SF Pro",
                            "label": "SF Pro"
                        }, {
                            "family": "SF Arabic",
                            "label": "SF Arabic"
                        }, {
                            "family": "Readex Pro",
                            "label": "Readex Pro"
                        }, {
                            "family": "Rubik",
                            "label": "Rubik"
                        }, {
                            "family": "Noto Kufi Arabic",
                            "label": "Noto Kufi"
                        }, {
                            "family": "Inter",
                            "label": "Inter"
                        }].filter((f) => {
                            return Qt.fontFamilies().indexOf(f.family) >= 0;
                        })

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

                    }

                }

            }

            // Font Scale
            SettingsRow {
                title: I18n.isRTL ? "حجم الخط" : "Font Size"
                subtitle: I18n.isRTL ? "ضبط مقياس حجم الخطوط في الواجهة" : "Adjust user interface text scaling"
                icon: "preferences-desktop-font-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [
                        { "value": 0.85, "label": I18n.isRTL ? "صغير" : "Small" },
                        { "value": 1.0, "label": I18n.isRTL ? "قياسي" : "Standard" },
                        { "value": 1.15, "label": I18n.isRTL ? "كبير" : "Large" }
                    ]
                    current: Math.abs(ConfigManager.fontSizeScale - 0.85) < 0.05 ? 0.85 : (Math.abs(ConfigManager.fontSizeScale - 1.15) < 0.05 ? 1.15 : 1.0)
                    onChosen: (v) => ConfigManager.setFontSizeScale(v)
                }

            }

            // Number Format: the digits of every DeloWay surface and of Qt/KDE apps
            SettingsRow {
                title: I18n.tr("number_format_title")
                subtitle: I18n.tr("number_format_desc")
                icon: "preferences-desktop-font-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": "western", "label": "0123" },
                        { "value": "eastern", "label": "٠١٢٣" }
                    ]
                    current: ConfigManager.numberFormat
                    onChosen: (v) => ConfigManager.setNumberFormat(v)
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

                SettingsChoice {
                    options: [
                        { "value": 4, "label": I18n.isRTL ? "حادة (4px)" : "Sharp (4px)" },
                        { "value": 8, "label": I18n.isRTL ? "قياسية (8px)" : "Standard (8px)" },
                        { "value": 14, "label": I18n.isRTL ? "دائرية (14px)" : "Rounded (14px)" }
                    ]
                    current: ConfigManager.elementRadius
                    onChosen: (v) => ConfigManager.setElementRadius(v)
                }

            }

            // Performance Tier
            SettingsRow {
                title: I18n.isRTL ? "مستوى التأثيرات الرسومية" : "Graphics & Visual Effects"
                subtitle: I18n.isRTL ? "التحكم بتأثيرات الزجاج والبلور والظلال وسلاسة الحركة" : "Control blur, acrylic glass, and layered shadow fidelity"
                icon: "power-profile-balanced-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": 0, "label": I18n.isRTL ? "خفيف" : "Efficient" },
                        { "value": 1, "label": I18n.isRTL ? "متوازن" : "Balanced" },
                        { "value": 2, "label": I18n.isRTL ? "فائق" : "High" }
                    ]
                    current: ConfigManager.performanceTier
                    onChosen: (v) => ConfigManager.setPerformanceTier(v)
                }

            }

        }

    }

}
