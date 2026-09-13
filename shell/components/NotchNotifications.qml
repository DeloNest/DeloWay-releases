import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../theme"
import "../services"

Item {
    id: root

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    readonly property int notifCount: NotificationManager.notifications ? NotificationManager.notifications.length : 0

    Item {
        anchors.fill: parent
        anchors.margins: 4
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        // ═════════════════════════════════════════════════════════════════════
        // 1. حالة الفراغ (EMPTY STATE — 0 Notifications)
        // ═════════════════════════════════════════════════════════════════════
        RowLayout {
            anchors.centerIn: parent
            spacing: 12
            visible: root.notifCount === 0

            SymbolicIcon {
                source: "preferences-system-notifications-symbolic"
                iconSize: 22
                iconColor: Qt.rgba(1, 1, 1, 0.40)
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: I18n.isRTL ? "لا توجد إشعارات جديدة" : "No notifications"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.85)
                }

                Text {
                    text: I18n.isRTL ? "سجل الإشعارات فارغ حالياً" : "All caught up"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.40)
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 2. قائمة الإشعارات وسجل التاريخ (LIST VIEW + PINNED CLEAR ALL)
        // ═════════════════════════════════════════════════════════════════════
        ColumnLayout {
            anchors.fill: parent
            spacing: 4
            visible: root.notifCount > 0

            // ── قائمة الإشعارات القابلة للتمرير ───────────────────────────────
            ListView {
                id: notifListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
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
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    width: notifListView.width - (vbar.visible ? 8 : 0)
                    implicitHeight: cardContent.implicitHeight + 10
                    radius: 8
                    color: cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
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
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 5
                        anchors.bottomMargin: 5
                        spacing: 8

                        // 1. أيقونة التطبيق
                        AppIcon {
                            iconSize: 20
                            source: card.modelData && card.modelData.appIcon ? card.modelData.appIcon : "dialog-information"
                            Layout.alignment: Qt.AlignTop
                        }

                        // 2. النصوص والتفاصيل
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            // الصف العلوي: اسم التطبيق + الوقت
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: card.modelData && card.modelData.appName ? card.modelData.appName : "System"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 140
                                }

                                Text {
                                    text: "•"
                                    font.pixelSize: 9
                                    color: Qt.rgba(1, 1, 1, 0.30)
                                }

                                Text {
                                    text: card.modelData && card.modelData.timeStr ? card.modelData.timeStr : ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 9
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                    Layout.fillWidth: true
                                }
                            }

                            // عنوان الإشعار
                            Text {
                                text: card.modelData && card.modelData.summary ? card.modelData.summary : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // تفاصيل الإشعار
                            Text {
                                visible: card.modelData && (card.modelData.body || "").length > 0
                                text: card.modelData && card.modelData.body ? card.modelData.body : ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 10
                                color: Qt.rgba(1, 1, 1, 0.55)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // 3. معاينة مصغرة للقطات الشاشة (إذا وجدت)
                        Rectangle {
                            visible: card.modelData && card.modelData.isScreenshot && (card.modelData.imagePath || "").length > 0
                            implicitWidth: 36
                            implicitHeight: 24
                            radius: 4
                            clip: true
                            color: Qt.rgba(0, 0, 0, 0.40)
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                source: (card.modelData && card.modelData.imagePath) ? ("file://" + card.modelData.imagePath) : ""
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        // 4. زر الحذف الفردي (✕)
                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 9
                            color: delMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 9
                                color: delMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.40)
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

            // ── زر "مسح الكل" الثابت بأسفل القائمة (Pinned Clear All) ─────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                color: "transparent"

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: clearContent.implicitWidth + 16
                    implicitHeight: 20
                    radius: 10
                    color: clearMa.pressed
                           ? Qt.rgba(1, 1, 1, 0.16)
                           : (clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    RowLayout {
                        id: clearContent
                        anchors.centerIn: parent
                        spacing: 4

                        SymbolicIcon {
                            source: "user-trash-symbolic"
                            iconSize: 10
                            iconColor: clearMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.60)
                        }

                        Text {
                            text: I18n.isRTL ? "مسح الكل" : "Clear All"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: clearMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
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
        }
    }
}
