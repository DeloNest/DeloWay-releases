// Time & Language — interface language, time format and calendar.
import QtQuick
import QtQuick.Layouts
import Quickshell
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

                SettingsChoice {
                    options: [
                        { "value": "ar", "label": "العربية" },
                        { "value": "en", "label": "English" }
                    ]
                    current: ConfigManager.uiLanguage || "ar"
                    onChosen: (v) => ConfigManager.setUiLanguage(v)
                }
            }
        }

        // ── 2. Keyboard Input Layouts (لغات الكيبورد) ───────────────
        SettingsSection {
            title: I18n.isRTL ? "تخطيطات لوحة المفاتيح والإدخال" : "Keyboard Layouts & Input"

            // Active Layouts List
            SettingsRow {
                title: I18n.isRTL ? "اللغات والتخطيطات النشطة" : "Active Input Layouts"
                subtitle: I18n.isRTL ? "تخطيطات لوحة المفاتيح المتاحة للتبديل السريع" : "Configured keyboard layouts available for quick switching"
                icon: "input-keyboard-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space6

                    Repeater {
                        model: ConfigManager.keyboardLayouts || ["us", "ara"]

                        delegate: Rectangle {
                            id: layoutChip
                            required property var modelData

                            function layoutName(code) {
                                switch (code) {
                                    case "us": return I18n.isRTL ? "الإنجليزية (US)" : "English (US)";
                                    case "ara":
                                    case "ar": return I18n.isRTL ? "العربية (Arabic 101)" : "Arabic (101)";
                                    case "fr": return I18n.isRTL ? "الفرنسية (FR)" : "French (FR)";
                                    case "de": return I18n.isRTL ? "الألمانية (DE)" : "German (DE)";
                                    case "es": return I18n.isRTL ? "الإسبانية (ES)" : "Spanish (ES)";
                                    case "tr": return I18n.isRTL ? "التركية (TR)" : "Turkish (TR)";
                                    default: return code.toUpperCase();
                                }
                            }

                            height: 28
                            implicitWidth: chipRow.implicitWidth + Theme.space16
                            radius: 14
                            color: Theme.notchSurfaceActive
                            border.color: Theme.notchBorderHighlight
                            border.width: 1

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: Theme.space6

                                Text {
                                    text: layoutChip.layoutName(layoutChip.modelData)
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                    color: Theme.notchText
                                }

                                Rectangle {
                                    visible: (ConfigManager.keyboardLayouts || []).length > 1
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 8
                                    color: remMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: "window-close-symbolic"
                                        iconSize: 10
                                        iconColor: Theme.notchTextSecondary
                                    }

                                    MouseArea {
                                        id: remMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var cur = (ConfigManager.keyboardLayouts || ["us", "ara"]).slice();
                                            var idx = cur.indexOf(layoutChip.modelData);
                                            if (idx >= 0 && cur.length > 1) {
                                                cur.splice(idx, 1);
                                                ConfigManager.setKeyboardLayouts(cur);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Add Keyboard Language
            SettingsRow {
                title: I18n.isRTL ? "إضافة لغة إدخال جديدة" : "Add Input Language"
                subtitle: I18n.isRTL ? "اختر لغة لإضافتها إلى قائمة التبديل" : "Select a language to add to the input layout switcher"
                icon: "list-add-symbolic"
                showDivider: true

                RowLayout {
                    spacing: Theme.space4

                    Repeater {
                        model: [
                            { code: "ara", label: I18n.isRTL ? "+ العربية" : "+ Arabic" },
                            { code: "us",  label: I18n.isRTL ? "+ الإنجليزية" : "+ English" },
                            { code: "fr",  label: I18n.isRTL ? "+ الفرنسية" : "+ French" },
                            { code: "es",  label: I18n.isRTL ? "+ الإسبانية" : "+ Spanish" }
                        ]

                        delegate: Rectangle {
                            id: addChip
                            required property var modelData
                            readonly property bool isAlreadyAdded: (ConfigManager.keyboardLayouts || []).indexOf(modelData.code) >= 0

                            visible: !isAlreadyAdded
                            height: 26
                            implicitWidth: addChipText.implicitWidth + Theme.space16
                            radius: 13
                            color: addMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                            border.color: Theme.notchBorderSubtle
                            border.width: 1

                            Text {
                                id: addChipText
                                anchors.centerIn: parent
                                text: addChip.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: addMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var cur = (ConfigManager.keyboardLayouts || []).slice();
                                    if (cur.indexOf(addChip.modelData.code) < 0) {
                                        cur.push(addChip.modelData.code);
                                        ConfigManager.setKeyboardLayouts(cur);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Keyboard Layout Switching Shortcut
            SettingsRow {
                title: I18n.isRTL ? "اختصار تبديل لغة الكيبورد" : "Switch Layout Shortcut"
                subtitle: I18n.isRTL ? "مفتاح التبديل السريع بين لغات الإدخال" : "Keyboard shortcut to toggle between configured languages"
                icon: "preferences-desktop-keyboard-shortcuts-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": "alt_shift", "label": "Alt + Shift" },
                        { "value": "win_space", "label": "Super + Space" },
                        { "value": "ctrl_shift", "label": "Ctrl + Shift" }
                    ]
                    current: "alt_shift"
                    onChosen: (v) => {
                        let opt = "grp:alt_shift_toggle";
                        if (v === "win_space") opt = "grp:win_space_toggle";
                        else if (v === "ctrl_shift") opt = "grp:ctrl_shift_toggle";
                        ConfigManager.run(["hyprctl", "keyword", "input:kb_options", opt]);
                    }
                }
            }
        }

        // ── 3. Timezone & Network Time ───────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "المنطقة الزمنية ومزامنة الوقت" : "Timezone & Network Time"

            // Auto-sync NTP
            SettingsRow {
                title: I18n.isRTL ? "ضبط الوقت تلقائياً (NTP)" : "Set Time Automatically (NTP)"
                subtitle: I18n.isRTL ? "مزامنة وقت وتاريخ النظام عبر خوادم الوقت بالإنترنت" : "Synchronize system clock with network time protocol servers"
                icon: "network-wireless-symbolic"
                showDivider: true

                SettingsToggle {
                    checked: true
                    onToggled: (ch) => {
                        ConfigManager.run(["timedatectl", "set-ntp", ch ? "true" : "false"]);
                    }
                }
            }

            // Timezone Preset Selector
            SettingsRow {
                title: I18n.isRTL ? "المنطقة الزمنية" : "Time Zone"
                subtitle: I18n.isRTL ? "تحديد النطاق الزمني والتوقيت المحلي للجهاز" : "Local time zone and UTC offset"
                icon: "preferences-system-time-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": "Asia/Riyadh", "label": I18n.isRTL ? "الرياض (+3)" : "Riyadh (GMT+3)" },
                        { "value": "Africa/Cairo", "label": I18n.isRTL ? "القاهرة (+2)" : "Cairo (GMT+2)" },
                        { "value": "Asia/Dubai", "label": I18n.isRTL ? "دبي (+4)" : "Dubai (GMT+4)" },
                        { "value": "UTC", "label": "UTC" },
                        { "value": "Europe/London", "label": "London" }
                    ]
                    current: "Asia/Riyadh"
                    onChosen: (v) => {
                        ConfigManager.run(["timedatectl", "set-timezone", v]);
                    }
                }
            }
        }

        // ── 4. Time Format ───────────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "تنسيق الوقت" : "Time Format"

            // Clock Format: 12h / 24h
            SettingsRow {
                title: I18n.isRTL ? "تنسيق الوقت" : "Time Format"
                subtitle: I18n.isRTL ? "التبديل بين نظام 12 ساعة و24 ساعة" : "Toggle between 12-hour and 24-hour time format"
                icon: "preferences-system-time-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": "12h", "label": I18n.isRTL ? "12 ساعة (ص/م)" : "12-hour" },
                        { "value": "24h", "label": I18n.isRTL ? "24 ساعة" : "24-hour" }
                    ]
                    current: ConfigManager.clockFormat
                    onChosen: (v) => ConfigManager.setClockFormat(v)
                }
            }
        }

        // ── 5. Calendar & Dates ──────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "التقويم والتواريخ" : "Calendar & Dates"

            // Calendar Week Start
            SettingsRow {
                title: I18n.isRTL ? "بداية الأسبوع في التقويم" : "Calendar Week Start"
                subtitle: I18n.isRTL ? "اليوم الأول في شبكة تقويم الشهر الموسعة" : "First day of the week displayed in the monthly calendar grid"
                icon: "view-calendar-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [
                        { "value": "saturday", "label": I18n.isRTL ? "السبت" : "Saturday" },
                        { "value": "sunday",   "label": I18n.isRTL ? "الأحد" : "Sunday" },
                        { "value": "monday",   "label": I18n.isRTL ? "الاثنين" : "Monday" }
                    ]
                    current: ConfigManager.timeCapsuleWeekStart || "saturday"
                    onChosen: (v) => ConfigManager.setTimeCapsuleWeekStart(v)
                }
            }

            // Show Hijri Date (Umm al-Qura)
            SettingsRow {
                title: I18n.isRTL ? "إظهار التاريخ الهجري (أم القرى)" : "Show Hijri Date (Umm al-Qura)"
                subtitle: I18n.isRTL ? "عرض التاريخ الهجري بدقة فلكية في ترويسة الكبسولة" : "Display astronomical Umm al-Qura Hijri date in expanded header"
                icon: "weather-clear-night-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleShowHijri(!ConfigManager.timeCapsuleShowHijri)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowHijri
                    onToggled: ch => ConfigManager.setTimeCapsuleShowHijri(ch)
                }
            }
        }
    }
}
