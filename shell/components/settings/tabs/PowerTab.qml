import "../../"
import "../../../services"
import "../../../theme"
import "../common"
// Power & Battery — power profile, sleep, suspend, lid and power button behavior.
import QtQuick
import QtQuick.Layouts

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

        // ── 1. Power & Battery ───────────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "الطاقة والبطارية" : "Power & Battery"

            // Power Supply / Battery Overview
            SettingsRow {
                title: I18n.tr("power_source")
                subtitle: SystemMonitor.hasBattery ? (SystemMonitor.batteryPercent + "% · " + (SystemMonitor.batteryStatusText || I18n.tr("power_source_battery_desc"))) : I18n.tr("power_source_ac_desc")
                icon: SystemMonitor.hasBattery ? "battery-symbolic" : "ac-adapter-symbolic"
                showDivider: true

                Rectangle {
                    implicitHeight: 28
                    implicitWidth: pwrSourceText.implicitWidth + Theme.space24
                    radius: 14
                    color: Theme.notchSurfaceActive
                    border.color: Theme.notchBorderHighlight
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.colors.success
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            id: pwrSourceText

                            text: SystemMonitor.hasBattery ? (SystemMonitor.batteryPercent + "%") : I18n.tr("power_source_ac")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                        }

                    }

                }

            }

            // Power Profile
            SettingsRow {
                title: I18n.isRTL ? "وضع استهلاك الطاقة" : "Power Management Profile"
                subtitle: ControlCenterService.powerProfilesAvailable ? (I18n.isRTL ? "الموازنة بين أداء المعالج وسرعة النظام وعمر البطارية" : "Balance CPU throughput, system responsiveness, and battery life") : (I18n.isRTL ? "غير متاح: ثبّت power-profiles-daemon لتفعيل هذا الخيار" : "Unavailable: install power-profiles-daemon to enable this")
                icon: "power-profile-balanced-symbolic"
                showDivider: true

                SettingsChoice {
                    enabled: ControlCenterService.powerProfilesAvailable
                    opacity: enabled ? 1 : 0.4
                    options: [
                        { "value": "power-saver", "label": I18n.isRTL ? "توفير الطاقة" : "Saver" },
                        { "value": "balanced",    "label": I18n.isRTL ? "متوازن" : "Balanced" },
                        { "value": "performance", "label": I18n.isRTL ? "أداء فائق" : "Performance" }
                    ]
                    current: ControlCenterService.powerProfilesAvailable ? ControlCenterService.powerProfile : (ConfigManager.powerProfile || "balanced")
                    onChosen: (v) => ConfigManager.setPowerProfile(v)
                }

            }

            // Screen Sleep Timeout
            SettingsRow {
                title: I18n.isRTL ? "مهلة سكون الشاشة" : "Screen Sleep Timeout"
                subtitle: I18n.isRTL ? "إيقاف تشغيل الشاشات تلقائياً عند انعدام النشاط" : "Automatically turn off displays when idle"
                icon: "preferences-system-time-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [
                        { "value": 15, "label": I18n.isRTL ? "15 دقيقة" : "15m" },
                        { "value": 30, "label": I18n.isRTL ? "30 دقيقة" : "30m" },
                        { "value": 60, "label": I18n.isRTL ? "ساعة" : "1h" },
                        { "value": 0,  "label": I18n.isRTL ? "مطلقاً" : "Never" }
                    ]
                    current: ConfigManager.sleepTimeout !== undefined ? ConfigManager.sleepTimeout : 30
                    onChosen: (v) => ConfigManager.setSleepTimeout(v)
                }

            }

            // System Suspend Timeout
            SettingsRow {
                title: I18n.isRTL ? "مهلة تعليق النظام (Suspend)" : "System Suspend Timeout"
                subtitle: I18n.isRTL ? "تعليق النظام في الذاكرة لتوفير الطاقة عند عدم الاستخدام" : "Suspend machine to RAM to conserve power when idle"
                icon: "preferences-system-time-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": 30,  "label": I18n.isRTL ? "30 دقيقة" : "30m" },
                        { "value": 60,  "label": I18n.isRTL ? "ساعة" : "1h" },
                        { "value": 120, "label": I18n.isRTL ? "ساعتان" : "2h" },
                        { "value": 0,   "label": I18n.isRTL ? "مطلقاً" : "Never" }
                    ]
                    current: ConfigManager.suspendTimeout !== undefined ? ConfigManager.suspendTimeout : 60
                    onChosen: (v) => ConfigManager.setSuspendTimeout(v)
                }

            }

        }

        // ── 2. Hardware Buttons & Lid ─────────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "أزرار الطاقة والغطاء" : "Hardware Buttons & Lid"

            // Laptop Lid Close Action
            SettingsRow {
                title: I18n.isRTL ? "إجراء إغلاق غطاء اللابتوب" : "Laptop Lid Close Action"
                subtitle: I18n.isRTL ? "السلوك المتخذ عند إغلاق غطاء الجهاز المحمول" : "Action performed when closing the laptop lid"
                icon: "computer-symbolic"
                showDivider: true

                SettingsChoice {
                    options: [
                        { "value": "suspend", "label": I18n.isRTL ? "تعليق" : "Suspend" },
                        { "value": "lock",    "label": I18n.isRTL ? "قفل" : "Lock" },
                        { "value": "ignore",  "label": I18n.isRTL ? "لا شيء" : "Do Nothing" }
                    ]
                    current: ConfigManager.lidAction || "suspend"
                    onChosen: (v) => ConfigManager.setLidAction(v)
                }
            }

            // Power Button Action
            SettingsRow {
                title: I18n.isRTL ? "سلوك زر الطاقة" : "Power Button Action"
                subtitle: I18n.isRTL ? "الإجراء المتخذ عند الضغط على زر التشغيل الفعلي" : "Action performed when pressing the physical power button"
                icon: "system-shutdown-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": "prompt",   "label": I18n.isRTL ? "قائمة الطاقة" : "Prompt" },
                        { "value": "suspend",  "label": I18n.isRTL ? "تعليق" : "Suspend" },
                        { "value": "poweroff", "label": I18n.isRTL ? "إيقاف" : "Power Off" }
                    ]
                    current: ConfigManager.powerButtonAction || "prompt"
                    onChosen: (v) => ConfigManager.setPowerButtonAction(v)
                }
            }
        }

    }

}
