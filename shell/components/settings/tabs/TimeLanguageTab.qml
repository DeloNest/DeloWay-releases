// Time & Language — interface language, time format and calendar.
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

        // ── 1. Interface Language ────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "لغة النظام والواجهة" : "Interface Language"

            SettingsRow {
                title: I18n.tr("ui_language_title")
                subtitle: I18n.tr("ui_language_desc")
                icon: "preferences-desktop-locale-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "ar", label: "العربية" },
                            { id: "en", label: "English" }
                        ]
                        delegate: Rectangle {
                            id: langPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.uiLanguage || "ar") === modelData.id

                            height: 28
                            implicitWidth: langText.implicitWidth + Theme.space16
                            radius: 14
                            color: langPill.isSelected ? Theme.notchSurfaceActive : (langMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: langPill.isSelected ? Theme.notchBorderHighlight : (langMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: langText
                                anchors.centerIn: parent
                                text: langPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: langPill.isSelected ? Font.DemiBold : Font.Normal
                                color: langPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: langMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setUiLanguage(langPill.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "تنسيق الوقت" : "Time Format"

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
                                    ConfigManager.setClockFormat(clockPill.modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Calendar & Dates ──────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "التقويم والتواريخ" : "Calendar & Dates"

            // Calendar Week Start
            SettingsRow {
                title: I18n.isRTL ? "بداية الأسبوع في التقويم" : "Calendar Week Start"
                subtitle: I18n.isRTL ? "اليوم الأول في شبكة تقويم الشهر الموسعة" : "First day of the week displayed in the monthly calendar grid"
                icon: "view-calendar-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { id: "saturday", label: I18n.isRTL ? "السبت" : "Saturday" },
                            { id: "sunday",   label: I18n.isRTL ? "الأحد" : "Sunday" },
                            { id: "monday",   label: I18n.isRTL ? "الاثنين" : "Monday" }
                        ]
                        delegate: Rectangle {
                            id: weekStartPill
                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.timeCapsuleWeekStart || "saturday") === modelData.id

                            height: 28
                            implicitWidth: weekStartText.implicitWidth + Theme.space16
                            radius: 14
                            color: weekStartPill.isSelected ? Theme.notchSurfaceActive : (weekStartMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: weekStartPill.isSelected ? Theme.notchBorderHighlight : (weekStartMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: weekStartText
                                anchors.centerIn: parent
                                text: weekStartPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: weekStartPill.isSelected ? Font.DemiBold : Font.Normal
                                color: weekStartPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: weekStartMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setTimeCapsuleWeekStart(weekStartPill.modelData.id)
                            }
                        }
                    }
                }
            }

            // Show Hijri Date (Umm al-Qura)
            SettingsRow {
                title: I18n.isRTL ? "إظهار التاريخ الهجري (أم القرى)" : "Show Hijri Date (Umm al-Qura)"
                subtitle: I18n.isRTL ? "عرض التاريخ الهجري بدقة فلكية في ترويسة الكبسولة" : "Display astronomical Umm al-Qura Hijri date in expanded header"
                icon: "weather-clear-night-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleShowHijri(!ConfigManager.timeCapsuleShowHijri)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowHijri
                    onToggled: ch => ConfigManager.setTimeCapsuleShowHijri(ch)
                }
            }

            // Eastern Arabic Numerals (٠١٢)
            SettingsRow {
                title: I18n.isRTL ? "الأرقام المشرقية (٠١٢٣٤)" : "Eastern Arabic Numerals (٠١٢)"
                subtitle: I18n.isRTL ? "استخدام الأرقام العربية المشرقية للأوقات والتواريخ" : "Use Eastern Arabic digits for times and dates in Arabic UI"
                icon: "format-text-bold-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleArabicDigits(!ConfigManager.timeCapsuleArabicDigits)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleArabicDigits
                    onToggled: ch => ConfigManager.setTimeCapsuleArabicDigits(ch)
                }
            }
        }
    }
}
