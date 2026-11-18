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

        // ── 1. General Notification Behavior ─────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "سلوك التنبيهات العامة" : "General Notifications"

            // Do Not Disturb
            SettingsRow {
                title: I18n.isRTL ? "وضع عدم الإزعاج (Do Not Disturb)" : "Do Not Disturb"
                subtitle: ConfigManager.notificationsDnd
                    ? (I18n.isRTL ? "مفعّل — كتم كافة التنبيهات المنبثقة والأصوات" : "Enabled — Silence all popups and sounds")
                    : (I18n.isRTL ? "معطّل — استقبال التنبيهات بشكل طبيعي" : "Disabled — Receive all notifications normally")
                icon: ConfigManager.notificationsDnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setNotificationsDnd(!ConfigManager.notificationsDnd)

                SettingsToggle {
                    checked: ConfigManager.notificationsDnd
                    onToggled: ch => ConfigManager.setNotificationsDnd(ch)
                }
            }

            // Notification Sounds
            SettingsRow {
                title: I18n.isRTL ? "أصوات الإشعارات" : "Notification Sounds"
                subtitle: I18n.isRTL ? "تشغيل صوت تنبيه خفيف عند وصول إشعار جديد" : "Play subtle sound chime when a notification arrives"
                icon: "audio-volume-high-symbolic"
                showDivider: true
                clickable: true
                onClicked: ConfigManager.setNotificationsSound(!ConfigManager.notificationsSound)

                SettingsToggle {
                    checked: ConfigManager.notificationsSound
                    onToggled: ch => ConfigManager.setNotificationsSound(ch)
                }
            }

            // Notification Timeout
            SettingsRow {
                title: I18n.isRTL ? "مهلة بقاء الإشعار" : "Notification Timeout"
                subtitle: I18n.isRTL ? "المدة الزمنية قبل اختفاء بطاقة التنبيه المنبثقة تلقائياً" : "Time before a popup toast banner dismisses automatically"
                icon: "preferences-system-time-symbolic"
                showDivider: false

                SettingsChoice {
                    options: [
                        { "value": 3000,  "label": I18n.isRTL ? "3 ثوانٍ" : "3s" },
                        { "value": 5000,  "label": I18n.isRTL ? "5 ثوانٍ" : "5s" },
                        { "value": 10000, "label": I18n.isRTL ? "10 ثوانٍ" : "10s" }
                    ]
                    current: ConfigManager.notificationsTimeout
                    onChosen: (v) => ConfigManager.setNotificationsTimeout(v)
                }
            }
        }

        // ── 2. Shell & Notch Integration ─────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "تكامل شل DeloWay والنوتش الذكي" : "Shell & Notch Integration"

            // Notch Notifications Integration
            SettingsRow {
                title: I18n.isRTL ? "تكامل إشعارات النوتش الذكي" : "Smart Notch Notifications"
                subtitle: I18n.isRTL
                    ? "إدراج الإشعارات وتنبيهاتها ضمن مركز إشعارات النوتش العلوي"
                    : "Integrate incoming toasts into the smart notch notification center"
                icon: "preferences-system-notifications-symbolic"
                showDivider: false
                clickable: true
                onClicked: ConfigManager.setNotchNotifications(!ConfigManager.notchNotifications)

                SettingsToggle {
                    checked: ConfigManager.notchNotifications
                    onToggled: ch => {
                        ConfigManager.setNotchNotifications(ch);
                    }
                }
            }
        }

        // ── 3. Application Permissions ───────────────────────────────
        SettingsSection {
            title: I18n.isRTL ? "أذونات التطبيقات" : "App Permissions"

            SettingsRow {
                title: I18n.isRTL ? "إدارة إشعارات التطبيقات الفردية" : "Manage Per-App Notifications"
                subtitle: I18n.isRTL ? "تحديد التطبيقات المسموح لها بعرض الإشعارات والتنبيهات" : "Control which installed apps can send desktop notifications"
                icon: "preferences-system-notifications-symbolic"
                showDivider: false
                clickable: true
                onClicked: ShellState.settingsCurrentPage = "apps"

                Rectangle {
                    height: 28
                    implicitWidth: appPermText.implicitWidth + Theme.space24
                    radius: 14
                    color: appPermMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        Text {
                            id: appPermText
                            text: I18n.isRTL ? "عرض التطبيقات" : "Configure Apps"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                        }

                        SymbolicIcon {
                            source: "pan-end-symbolic"
                            iconSize: 10
                            isDirectional: true
                            iconColor: Theme.notchTextSecondary
                        }
                    }

                    MouseArea {
                        id: appPermMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.settingsCurrentPage = "apps"
                    }
                }
            }
        }
    }
}
