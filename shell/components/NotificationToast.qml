import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        right: true
    }

    margins {
        top: 52
        right: 16
    }

    implicitWidth: 350
    implicitHeight: toastCard.implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "deloway:notification-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var currentNotif: null
    property bool showing: false
    property real progress: 1.0

    visible: showing || toastCard.opacity > 0.01

    Rectangle {
        id: toastCard
        anchors.top: parent.top
        anchors.right: I18n.isRTL ? undefined : parent.right
        anchors.left: I18n.isRTL ? parent.left : undefined
        anchors.margins: Theme.space16
        width: 350
        implicitHeight: contentCol.implicitHeight + 20
        radius: Theme.radiusLarge
        color: Theme.colors.surface
        border.color: Theme.hairline
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: root.showing ? 1.0 : 0.0
        transform: Translate {
            x: root.showing ? 0 : (I18n.isRTL ? -30 : 30)
            Behavior on x { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // App Name & Close button header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppIcon {
                    iconSize: 18
                    source: (root.currentNotif && root.currentNotif.appIcon) ? root.currentNotif.appIcon : "dialog-information"
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.currentNotif && root.currentNotif.appName) ? root.currentNotif.appName : "System"
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.typography.scaleCaption.size
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: Theme.colors.textSecondary
                    elide: Text.ElideRight
                }

                Text {
                    text: (root.currentNotif && root.currentNotif.timeStr) ? root.currentNotif.timeStr : ""
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.typography.scaleCaption.size
                    renderType: Theme.renderType
                    color: Theme.colors.textTertiary
                }

                // Close Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouse.pressed ? Theme.colors.surfaceActive : (closeMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                    border.color: closeMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"
                    border.width: 1
                    scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.typography.scaleCaption.size
                        renderType: Theme.renderType
                        color: closeMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showing = false;
                            if (root.currentNotif) NotificationManager.dismiss(root.currentNotif.id);
                        }
                    }
                }
            }

            // Summary & Body
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: (root.currentNotif && root.currentNotif.summary) ? root.currentNotif.summary : ""
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.typography.fontSizeRegular
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: Theme.colors.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.currentNotif && root.currentNotif.body) ? root.currentNotif.body : ""
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.typography.fontSizeSmall
                    renderType: Theme.renderType
                    color: Theme.colors.textSecondary
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Screenshot Preview Thumbnail (if present)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 130
                radius: Theme.radius.medium
                color: Theme.colors.surfaceElevated
                border.color: Theme.colors.border
                border.width: 1
                clip: true
                visible: root.currentNotif && root.currentNotif.imagePath ? true : false

                Image {
                    anchors.fill: parent
                    source: (root.currentNotif && root.currentNotif.imagePath) ? ("file://" + root.currentNotif.imagePath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentNotif && root.currentNotif.imagePath) {
                            actionProcess.exec(["xdg-open", root.currentNotif.imagePath]);
                            root.showing = false;
                        }
                    }
                }
            }

            // Screenshot Actions Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space8
                visible: root.currentNotif && root.currentNotif.imagePath ? true : false

                DeloButton {
                    Layout.fillWidth: true
                    height: 28
                    variant: "secondary"
                    text: I18n.tr("open_image")
                    onClicked: {
                        if (root.currentNotif && root.currentNotif.imagePath) {
                            actionProcess.exec(["xdg-open", root.currentNotif.imagePath]);
                            root.showing = false;
                        }
                    }
                }

                DeloButton {
                    Layout.fillWidth: true
                    height: 28
                    variant: "secondary"
                    text: I18n.tr("open_folder")
                    onClicked: {
                        if (root.currentNotif && root.currentNotif.imagePath) {
                            const dir = root.currentNotif.imagePath.substring(0, root.currentNotif.imagePath.lastIndexOf("/"));
                            actionProcess.exec(["xdg-open", dir]);
                            root.showing = false;
                        }
                    }
                }
            }

            // Dismiss Timer Progress Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                radius: 1
                color: Theme.colors.surfaceHover

                Rectangle {
                    height: parent.height
                    width: parent.width * root.progress
                    radius: 1
                    color: Theme.notchText
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: dismissTimer.stop()
            onExited: if (root.showing) dismissTimer.restart()
            onClicked: {
                root.showing = false;
                if (root.currentNotif) NotificationManager.dismiss(root.currentNotif.id);
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 50
        repeat: true
        running: root.showing
        onTriggered: {
            root.progress -= (50 / ConfigManager.notificationsTimeout);
            if (root.progress <= 0) {
                dismissTimer.stop();
                root.showing = false;
            }
        }
    }

    Connections {
        target: NotificationManager
        function onToastRequested(notif) {
            // When notchNotifications is true, the Smart Notch handles the top banner,
            // avoiding duplicate notifications on the screen.
            if (ConfigManager.notificationsDnd || ConfigManager.notchNotifications) return;
            root.currentNotif = notif;
            root.progress = 1.0;
            root.showing = true;
            dismissTimer.restart();
        }
    }

    Process {
        id: actionProcess
    }
}
