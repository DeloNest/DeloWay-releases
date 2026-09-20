import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../theme"
import "../services"

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property int notifCount: NotificationManager.notifications ? NotificationManager.notifications.length : 0

    Item {
        anchors.fill: parent
        anchors.margins: 8
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // ═════════════════════════════════════════════════════════════════════
        // 1. حالة الفراغ (EMPTY STATE — 0 Notifications)
        // ═════════════════════════════════════════════════════════════════════
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            visible: root.notifCount === 0

            Rectangle {
                implicitWidth: 48
                implicitHeight: 48
                radius: 24
                color: Theme.notchSurfaceElevated
                border.color: Theme.notchBorderSubtle
                border.width: 1
                Layout.alignment: Qt.AlignHCenter

                SymbolicIcon {
                    anchors.centerIn: parent
                    source: "preferences-system-notifications-symbolic"
                    iconSize: 24
                    iconColor: Theme.notchTextSecondary
                }
            }

            Text {
                text: I18n.isRTL ? "لا توجد إشعارات جديدة" : "No new notifications"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: I18n.isRTL ? "سجل الإشعارات فارغ وجميع التنبيهات مقروءة" : "All notifications have been cleared"
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextSecondary
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 2. قائمة الإشعارات وسجل التاريخ (HEADER + LIST VIEW)
        // ═════════════════════════════════════════════════════════════════════
        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            visible: root.notifCount > 0

            // ── ترويسة تبويب الإشعارات مع زر مسح الكل ──────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 8

                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    SymbolicIcon {
                        source: "preferences-system-notifications-symbolic"
                        iconSize: 13
                        iconColor: Theme.notchText
                    }

                    Text {
                        text: I18n.isRTL ? "الإشعارات" : "Notifications"
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                    }

                    Rectangle {
                        implicitWidth: Math.max(18, countTxt.implicitWidth + 8)
                        implicitHeight: 16
                        radius: 8
                        color: Theme.notchSurfaceElevated
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: String(root.notifCount)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(9)
                            font.weight: Font.Bold
                            color: Theme.notchTextSecondary
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // زر مسح الكل المدمج بالترويسة
                Rectangle {
                    implicitWidth: clearContent.implicitWidth + 14
                    implicitHeight: 22
                    radius: 6
                    color: clearMa.pressed
                           ? Theme.notchSurfaceActive
                           : (clearMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                    border.color: clearMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    RowLayout {
                        id: clearContent
                        anchors.centerIn: parent
                        spacing: 4

                        SymbolicIcon {
                            source: "user-trash-symbolic"
                            iconSize: 11
                            iconColor: clearMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        }

                        Text {
                            text: I18n.isRTL ? "مسح الكل" : "Clear All"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Medium
                            color: clearMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        }
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationManager.clearAll()
                    }
                }
            }

            // ── قائمة الإشعارات القابلة للتمرير ───────────────────────────────
            ListView {
                id: notifListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: NotificationManager.notifications

                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    active: notifListView.moving || notifListView.flicking
                    policy: notifListView.contentHeight > notifListView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    width: 4

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.notchBorderHighlight
                    }
                }

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    width: notifListView.width - (vbar.visible ? 8 : 0)
                    implicitHeight: cardContent.implicitHeight + 16
                    radius: 10
                    color: cardMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurfaceElevated
                    border.color: cardMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    RowLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // 1. أيقونة التطبيق (واضحة بحجم 30x30)
                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: Theme.notchSurface
                            border.color: Theme.notchBorderSubtle
                            border.width: 1
                            Layout.alignment: Qt.AlignTop

                            AppIcon {
                                anchors.centerIn: parent
                                iconSize: 18
                                source: card.modelData && card.modelData.appIcon ? card.modelData.appIcon : "dialog-information"
                            }
                        }

                        // 2. النصوص والتفاصيل بتسلسل بصري عالي الوضوح
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            // الصف الأول: اسم التطبيق + الوقت
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: card.modelData && card.modelData.appName ? card.modelData.appName : "System"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                    color: Theme.notchText
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 160
                                }

                                Text {
                                    text: "•"
                                    font.pixelSize: Theme.fontSize(9)
                                    color: Theme.notchTextTertiary
                                }

                                Text {
                                    text: card.modelData && card.modelData.timeStr ? card.modelData.timeStr : ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    color: Theme.notchTextSecondary
                                    Layout.fillWidth: true
                                }
                            }

                            // عنوان الإشعار (واضح وبارز)
                            Text {
                                text: card.modelData && card.modelData.summary ? card.modelData.summary : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                font.weight: Font.DemiBold
                                color: Theme.notchText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // تفاصيل الإشعار (متعدد الأسطر بمسافة قراءة مريحة)
                            Text {
                                visible: card.modelData && (card.modelData.body || "").length > 0
                                text: card.modelData && card.modelData.body ? card.modelData.body : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                color: Theme.notchTextSecondary
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                lineHeight: 1.25
                                Layout.fillWidth: true
                            }
                        }

                        // 3. معاينة مصغرة للقطات الشاشة (إذا وجدت)
                        Rectangle {
                            visible: Boolean(card.modelData && card.modelData.isScreenshot && card.modelData.imagePath && card.modelData.imagePath.length > 0)
                            implicitWidth: 50
                            implicitHeight: 34
                            radius: 6
                            clip: true
                            color: Theme.notchSurface
                            border.color: Theme.notchBorderSubtle
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                source: (card.modelData && card.modelData.imagePath) ? ("file://" + card.modelData.imagePath) : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (card.modelData && card.modelData.imagePath) {
                                        Qt.openUrlExternally("file://" + card.modelData.imagePath);
                                    }
                                }
                            }
                        }

                        // 4. زر الحذف الفردي (✕)
                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: delMa.pressed ? Theme.notchSurfaceActive : (delMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                            border.color: delMa.containsMouse ? Theme.notchBorderHighlight : "transparent"
                            border.width: 1
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: Theme.fontSize(9)
                                color: delMa.containsMouse ? Theme.notchText : Theme.notchTextTertiary
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (card.modelData && card.modelData.id !== undefined) {
                                        NotificationManager.dismiss(card.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
