import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"
import "../services"
import "./notifications"

// NotificationToast — fallback popup used when "Notifications in the Notch" is off.
// Drops in under the top bar (slide + fade + slight scale), pauses on hover, drains a
// hairline countdown, then slides back out. The surface has a FIXED size, so nothing
// is re-allocated mid-animation; only the card's transform/opacity change.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors { top: true }
    margins { top: Theme.topBarReserved }

    readonly property int cardWidth: 380
    implicitWidth: cardWidth + 24          // room for the shadow
    implicitHeight: 360
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "deloway:notification-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var currentNotif: null
    property bool showing: false
    property real progress: 1.0

    visible: showing || card.opacity > 0.01
    mask: Region { item: card }

    function hide() { root.showing = false; }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cardWidth
        height: content.implicitHeight + 28 + (screenshotActions.visible ? screenshotActions.implicitHeight + 10 : 0)
        radius: Theme.notchRadiusPanel
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.97
        transform: Translate {
            y: root.showing ? 0 : -14
            Behavior on y { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        NotificationCard {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            variant: "card"
            alwaysShowClose: true
            notif: root.currentNotif
            progress: root.progress
            onCloseRequested: {
                root.hide();
                if (root.currentNotif) NotificationManager.dismiss(root.currentNotif.id);
            }
        }

        RowLayout {
            id: screenshotActions
            visible: Boolean(root.currentNotif && root.currentNotif.imagePath)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 8

            DeloButton {
                Layout.fillWidth: true
                height: 28
                variant: "secondary"
                text: I18n.tr("open_image")
                onClicked: {
                    actionProcess.exec(["xdg-open", root.currentNotif.imagePath]);
                    root.hide();
                }
            }
            DeloButton {
                Layout.fillWidth: true
                height: 28
                variant: "secondary"
                text: I18n.tr("open_folder")
                onClicked: {
                    const p = root.currentNotif.imagePath;
                    actionProcess.exec(["xdg-open", p.substring(0, p.lastIndexOf("/"))]);
                    root.hide();
                }
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 50
        repeat: true
        running: root.showing && !content.hovered
        onTriggered: {
            root.progress -= interval / Math.max(1000, ConfigManager.notificationsTimeout);
            if (root.progress <= 0) root.hide();
        }
    }

    Connections {
        target: NotificationManager
        function onToastRequested(notif) {
            // When the Smart Notch hosts notifications it shows the banner instead.
            if (ConfigManager.notificationsDnd || ConfigManager.notchNotifications) return;
            root.currentNotif = notif;
            root.progress = 1.0;
            root.showing = true;
        }
    }

    Process { id: actionProcess }
}
