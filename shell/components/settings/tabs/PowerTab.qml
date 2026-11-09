import "../../"
import "../../../services"
import "../../../theme"
import "../common"
// Power & Display — power profile and screen sleep.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

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

        // ── 1. Power & Display ───────────────────────────────────────
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

                RowLayout {
                    enabled: ControlCenterService.powerProfilesAvailable
                    opacity: enabled ? 1 : 0.4
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [{
                            "id": "power-saver",
                            "label": I18n.isRTL ? "توفير الطاقة" : "Saver"
                        }, {
                            "id": "balanced",
                            "label": I18n.isRTL ? "متوازن" : "Balanced"
                        }, {
                            "id": "performance",
                            "label": I18n.isRTL ? "أداء فائق" : "Performance"
                        }]

                        delegate: Rectangle {
                            id: pwrPill

                            required property var modelData
                            // Reflect the real system profile when power-profiles-daemon is present.
                            readonly property bool isSelected: (ControlCenterService.powerProfilesAvailable ? ControlCenterService.powerProfile : (ConfigManager.powerProfile || "balanced")) === modelData.id

                            height: 28
                            implicitWidth: pwrText.implicitWidth + Theme.space16
                            radius: 14
                            color: pwrPill.isSelected ? Theme.notchSurfaceActive : (pwrMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: pwrPill.isSelected ? Theme.notchBorderHighlight : (pwrMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1

                            Text {
                                id: pwrText

                                anchors.centerIn: parent
                                text: pwrPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: pwrPill.isSelected ? Font.DemiBold : Font.Normal
                                color: pwrPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: pwrMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.setPowerProfile(pwrPill.modelData.id);
                                }
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

            // Screen Sleep Timeout
            SettingsRow {
                title: I18n.isRTL ? "مهلة سكون الشاشة" : "Screen Sleep Timeout"
                subtitle: I18n.isRTL ? "إيقاف تشغيل الشاشات تلقائياً عند انعدام النشاط" : "Automatically turn off displays when idle"
                icon: "preferences-system-time-symbolic"
                showDivider: false

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [{
                            "min": 15,
                            "label": I18n.isRTL ? "15 دقيقة" : "15m"
                        }, {
                            "min": 30,
                            "label": I18n.isRTL ? "30 دقيقة" : "30m"
                        }, {
                            "min": 60,
                            "label": I18n.isRTL ? "ساعة" : "1h"
                        }, {
                            "min": 0,
                            "label": I18n.isRTL ? "مطلقاً" : "Never"
                        }]

                        delegate: Rectangle {
                            id: slpPill

                            required property var modelData
                            readonly property bool isSelected: (ConfigManager.sleepTimeout !== undefined ? ConfigManager.sleepTimeout : 30) === modelData.min

                            height: 28
                            implicitWidth: slpText.implicitWidth + Theme.space16
                            radius: 14
                            color: slpPill.isSelected ? Theme.notchSurfaceActive : (slpMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: slpPill.isSelected ? Theme.notchBorderHighlight : (slpMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1

                            Text {
                                id: slpText

                                anchors.centerIn: parent
                                text: slpPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: slpPill.isSelected ? Font.DemiBold : Font.Normal
                                color: slpPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: slpMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.setSleepTimeout(slpPill.modelData.min);
                                }
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

        }

    }

}
