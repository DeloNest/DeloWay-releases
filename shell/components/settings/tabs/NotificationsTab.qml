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

                RowLayout {
                    spacing: Theme.space4
                    LayoutMirroring.enabled: I18n.isRTL
                    LayoutMirroring.childrenInherit: true

                    Repeater {
                        model: [
                            { ms: 3000,  label: I18n.isRTL ? "3 ثوانٍ" : "3s" },
                            { ms: 5000,  label: I18n.isRTL ? "5 ثوانٍ" : "5s" },
                            { ms: 10000, label: I18n.isRTL ? "10 ثوانٍ" : "10s" }
                        ]
                        delegate: Rectangle {
                            id: toPill
                            required property var modelData
                            readonly property bool isSelected: ConfigManager.notificationsTimeout === modelData.ms

                            height: 28
                            implicitWidth: toText.implicitWidth + Theme.space16
                            radius: 14
                            color: toPill.isSelected ? Theme.notchSurfaceActive : (toMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: toPill.isSelected ? Theme.notchBorderHighlight : (toMa.containsMouse ? Theme.notchBorder : Theme.notchBorderSubtle)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                id: toText
                                anchors.centerIn: parent
                                text: toPill.modelData.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: toPill.isSelected ? Font.DemiBold : Font.Normal
                                color: toPill.isSelected ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: toMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.setNotificationsTimeout(toPill.modelData.ms)
                            }
                        }
                    }
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
    }
}
