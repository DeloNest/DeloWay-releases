import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../theme"
import "../services"
import "./notifications"

// NotchNotifications — history tab of the Smart Notch.
// One header line, then a list of shared NotificationCards. Items fade/slide in,
// slide out toward the reading-end edge on dismiss, and the rest glide up (displaced)
// so the list never jumps.
Item {
    id: root

    LayoutMirroring.enabled: I18n.isRTL
    LayoutMirroring.childrenInherit: true

    readonly property int notifCount: NotificationManager.notifications ? NotificationManager.notifications.length : 0
    readonly property real exitSign: I18n.isRTL ? -1 : 1

    // ── Empty state ──────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 10
        opacity: root.notifCount === 0 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

        SymbolicIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "preferences-system-notifications-symbolic"
            iconSize: 26
            iconColor: Theme.notchTextTertiary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.isRTL ? "لا توجد إشعارات" : "No notifications"
            font.family: Theme.typography.fontFamily
            font.pixelSize: Theme.fontSize(12)
            color: Theme.notchTextSecondary
            renderType: Theme.renderType
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 4
        spacing: 8
        opacity: root.notifCount > 0 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

        // ── Header: count · clear all ────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: I18n.notificationsCount(root.notifCount)
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.Medium
                color: Theme.notchTextMeta
                renderType: Theme.renderType
            }

            Rectangle {
                implicitWidth: clearTxt.implicitWidth + 20
                implicitHeight: 24
                radius: 12
                color: clearMa.pressed ? Theme.notchSurfaceActive : (clearMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface)
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                Text {
                    id: clearTxt
                    anchors.centerIn: parent
                    text: I18n.isRTL ? "مسح الكل" : "Clear all"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.Medium
                    color: clearMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                    renderType: Theme.renderType
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

        // ── List ─────────────────────────────────────────────────────────
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: NotificationManager.notifications

            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 4
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.notchBorderHighlight }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motionBase; easing.type: Theme.easingEnter }
                    NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.motionBase; easing.type: Theme.easingEnter }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.motionFast; easing.type: Theme.easingExit }
                    NumberAnimation { property: "x"; to: root.exitSign * 40; duration: Theme.motionFast; easing.type: Theme.easingExit }
                }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: Theme.motionBase; easing.type: Theme.easingEnter }
                NumberAnimation { property: "opacity"; to: 1; duration: Theme.motionFast }
                NumberAnimation { property: "scale"; to: 1; duration: Theme.motionFast }
            }

            // Full-width delegate; the scrollbar gutter is an anchor margin, which the
            // inherited mirroring moves to the scrollbar's side (left in Arabic).
            delegate: Item {
                id: row
                required property var modelData
                width: list.width
                implicitHeight: card.implicitHeight + 24

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: vbar.visible ? 8 : 0
                    radius: Theme.notchRadiusCard
                    color: card.hovered ? Theme.notchSurfaceElevated : Theme.notchSurface
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    NotificationCard {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 12
                        variant: "card"
                        notif: row.modelData
                        onCloseRequested: NotificationManager.dismiss(row.modelData.id)
                    }
                }
            }
        }
    }
}
