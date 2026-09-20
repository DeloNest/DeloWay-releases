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
    }

    margins {
        top: 52
    }

    implicitWidth: 380
    implicitHeight: toastCard.implicitHeight + 10
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
        anchors.horizontalCenter: parent.horizontalCenter
        width: 380
        implicitHeight: contentCol.implicitHeight + 24
        radius: 14
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: root.showing ? 1.0 : 0.0
        transform: Translate {
            y: root.showing ? 0 : -20
            Behavior on y { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // App Name & Close button header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 6
                    color: Theme.notchSurfaceElevated
                    border.color: Theme.notchBorderSubtle
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    AppIcon {
                        anchors.centerIn: parent
                        iconSize: 16
                        source: (root.currentNotif && root.currentNotif.appIcon) ? root.currentNotif.appIcon : "dialog-information"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.currentNotif && root.currentNotif.appName) ? root.currentNotif.appName : "System"
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: Theme.notchText
                    elide: Text.ElideRight
                }

                Text {
                    text: (root.currentNotif && root.currentNotif.timeStr) ? root.currentNotif.timeStr : ""
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.fontSize(10)
                    renderType: Theme.renderType
                    color: Theme.notchTextTertiary
                }

                // Close Button
                Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: 10
                    color: closeMouse.pressed ? Theme.notchSurfaceActive : (closeMouse.containsMouse ? Theme.notchSurfaceHover : "transparent")
                    border.color: closeMouse.containsMouse ? Theme.notchBorderHighlight : "transparent"
                    border.width: 1
                    scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.10 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.fontSize(9)
                        renderType: Theme.renderType
                        color: closeMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary
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
                    font.pixelSize: Theme.fontSize(12)
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: Theme.notchText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.currentNotif && root.currentNotif.body) ? root.currentNotif.body : ""
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.fontSize(11)
                    renderType: Theme.renderType
                    color: Theme.notchTextSecondary
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Screenshot Preview Thumbnail (if present)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                radius: 8
                color: Theme.notchSurfaceElevated
                border.color: Theme.notchBorderSubtle
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
                spacing: 8
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
                color: Theme.notchSurfaceHover

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
