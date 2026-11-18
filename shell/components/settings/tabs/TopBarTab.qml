// Top Bar — Smart Notch workspaces, time capsule and hardware monitor.
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

        SettingsSection {
            title: I18n.isRTL ? "ترتيب الكبسولات" : "Capsule Layout"

            // Which side of the Notch the clock and Quick Settings sit on. Physical and
            // language-independent, so the two choices are drawn in screen order.
            SettingsRow {
                title: I18n.isRTL ? "موضع الساعة والإعدادات السريعة" : "Clock and Quick Settings position"
                subtitle: I18n.isRTL
                    ? "على جانبي النوتش؛ الكبسولة الأخرى تأخذ الجانب المقابل، ولا يتغير الترتيب مع اللغة"
                    : "On either side of the Notch; the other capsule takes the opposite side, in every language"
                icon: "view-dual-symbolic"
                showDivider: false

                SettingsChoice {
                    mirror: false
                    options: [
                        { "value": "clockLeft",  "label": I18n.isRTL ? "الساعة يساراً (افتراضي)" : "Clock left (Default)" },
                        { "value": "clockRight", "label": I18n.isRTL ? "الساعة يميناً" : "Clock right" }
                    ]
                    current: ConfigManager.capsuleOrder
                    onChosen: (v) => ConfigManager.setCapsuleOrder(v)
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "النوتش الذكي" : "Smart Notch"

            // Show Workspaces Indicator
            SettingsRow {
                title: I18n.isRTL ? "إظهار مؤشر مساحات العمل" : "Show Workspaces Indicator"
                subtitle: I18n.isRTL ? "عرض قسم مساحات العمل في النوتش والشريط العلوي" : "Display workspace indicator in the smart notch and top bar"
                icon: "view-visible-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setTopBarShowWorkspaces(!ConfigManager.topBarShowWorkspaces)

                SettingsToggle {
                    checked: ConfigManager.topBarShowWorkspaces
                    onToggled: ch => {
                        ConfigManager.setTopBarShowWorkspaces(ch);
                    }
                }
            }

            // Style Selector: icons | numbers | dots
            SettingsRow {
                title: I18n.isRTL ? "نمط مؤشر مساحات العمل" : "Workspace Indicator Style"
                subtitle: I18n.isRTL
                    ? "اختر أسلوب عرض مساحات العمل في النوتش (أيقونات التطبيقات، أرقام ثابتة، أو نقاط)"
                    : "Choose how workspaces appear in the smart notch (app icons, fixed numbers, or dots)"
                icon: "view-app-grid-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [
                        { "value": "icons",   "label": I18n.isRTL ? "أيقونات (افتراضي)" : "Icons (Default)" },
                        { "value": "numbers", "label": I18n.isRTL ? "أرقام فقط" : "Numbers Only" },
                        { "value": "dots",    "label": I18n.isRTL ? "نقاط فقط" : "Dots Only" }
                    ]
                    current: ConfigManager.workspaceIndicatorStyle || "icons"
                    onChosen: (v) => ConfigManager.setWorkspaceIndicatorStyle(v)
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "كبسولة الوقت" : "Time Capsule"

            // Show Time & Date Capsule
            SettingsRow {
                title: I18n.isRTL ? "إظهار كبسولة الوقت في النوتش" : "Show Time & Date Capsule in Notch"
                subtitle: I18n.isRTL
                    ? "عرض كبسولة الوقت في الشريط العلوي مع التقويم وقراءات الهاردوير عند التوسع"
                    : "Display time capsule in the top bar with calendar and hardware info on expand"
                icon: "preferences-system-time-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleEnabled(!ConfigManager.timeCapsuleEnabled)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleEnabled
                    onToggled: ch => ConfigManager.setTimeCapsuleEnabled(ch)
                }
            }

            // Show Seconds in Expanded Clock
            SettingsRow {
                title: I18n.isRTL ? "إظهار الثواني في الساعة الموسعة" : "Show Seconds in Expanded Clock"
                subtitle: I18n.isRTL ? "عرض عداد الثواني مع الساعات والدقائق" : "Display seconds counter alongside hours and minutes"
                icon: "appointment-soon-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleShowSeconds(!ConfigManager.timeCapsuleShowSeconds)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowSeconds
                    onToggled: ch => ConfigManager.setTimeCapsuleShowSeconds(ch)
                }
            }

            // Show Short Date in Compact Capsule
            SettingsRow {
                title: I18n.isRTL ? "إظهار التاريخ في الكبسولة المصغّرة" : "Show Date in Compact Capsule"
                subtitle: I18n.isRTL ? "عرض اليوم والشهر المختصر بجانب الوقت في النوتش" : "Display short day and month next to time in notch"
                icon: "x-office-calendar-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleShowShortDate(!ConfigManager.timeCapsuleShowShortDate)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowShortDate
                    onToggled: ch => ConfigManager.setTimeCapsuleShowShortDate(ch)
                }
            }
        }

        SettingsSection {
            title: I18n.isRTL ? "مراقبة العتاد" : "Hardware Monitor"

            // Show Hardware Telemetry
            SettingsRow {
                title: I18n.isRTL ? "إظهار قسم الهاردوير" : "Show Hardware Telemetry"
                subtitle: I18n.isRTL ? "عرض بطاقات مراقبة المعالج والذاكرة وكرت الشاشة أسفل التقويم" : "Display CPU, RAM, and GPU usage cards below calendar"
                icon: "utilities-system-monitor-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setTimeCapsuleShowHardware(!ConfigManager.timeCapsuleShowHardware)

                SettingsToggle {
                    checked: ConfigManager.timeCapsuleShowHardware
                    onToggled: ch => ConfigManager.setTimeCapsuleShowHardware(ch)
                }
            }
        }
    }
}
