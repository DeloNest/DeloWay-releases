import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
        top: 32
    }

    implicitWidth: pillContainer.implicitWidth + 32
    implicitHeight: pillContainer.implicitHeight + 16
    color: "transparent"

    WlrLayershell.namespace: "deloway:screenshot-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.screenshotToolOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: ShellState.screenshotToolOpen || pillContainer.opacity > 0.01

    Timer {
        id: triggerTimer
        interval: 150
        repeat: false
        property string mode: "area"
        onTriggered: {
            if (mode === "area") {
                ScreenshotManager.captureArea();
            } else if (mode === "window") {
                ScreenshotManager.captureWindow();
            } else if (mode === "fullscreen") {
                ScreenshotManager.captureFullScreen();
            }
        }
    }

    function triggerCapture(captureMode) {
        ShellState.closeScreenshot();
        triggerTimer.mode = captureMode;
        triggerTimer.start();
    }

    Item {
        anchors.fill: parent
        focus: ShellState.screenshotToolOpen

        Keys.onEscapePressed: {
            ShellState.closeScreenshot();
        }

        Rectangle {
            id: pillContainer
            anchors.centerIn: parent
            implicitWidth: contentRow.implicitWidth + 24
            implicitHeight: 52
            radius: 26
            color: Theme.colors.surface
            border.color: Theme.colors.borderHighlight
            border.width: 1

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            opacity: ShellState.screenshotToolOpen ? 1.0 : 0.0
            scale: ShellState.screenshotToolOpen ? 1.0 : 0.92
            transform: Translate {
                y: ShellState.screenshotToolOpen ? 0 : -16
                Behavior on y { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }
            Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 6

                // Mode 1: Area Selection
                Rectangle {
                    implicitWidth: areaRow.implicitWidth + 18
                    implicitHeight: 38
                    radius: 19
                    color: areaMouse.pressed ? Theme.colors.surfaceActive : (areaMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                    border.color: areaMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"
                    border.width: 1

                    scale: areaMouse.pressed ? 0.95 : (areaMouse.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                    RowLayout {
                        id: areaRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰆞"
                            font.pixelSize: 17
                            font.family: Theme.typography.fontFamily
                            color: Theme.colors.accent
                            renderType: Theme.renderType
                        }

                        Text {
                            text: I18n.tr("screenshot_selection")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                            renderType: Theme.renderType
                        }
                    }

                    MouseArea {
                        id: areaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerCapture("area")
                    }
                }

                // Mode 2: Active Window
                Rectangle {
                    implicitWidth: winRow.implicitWidth + 18
                    implicitHeight: 38
                    radius: 19
                    color: winMouse.pressed ? Theme.colors.surfaceActive : (winMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                    border.color: winMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"
                    border.width: 1

                    scale: winMouse.pressed ? 0.95 : (winMouse.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                    RowLayout {
                        id: winRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰖲"
                            font.pixelSize: 17
                            font.family: Theme.typography.fontFamily
                            color: Theme.colors.accent
                            renderType: Theme.renderType
                        }

                        Text {
                            text: I18n.tr("screenshot_window")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                            renderType: Theme.renderType
                        }
                    }

                    MouseArea {
                        id: winMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerCapture("window")
                    }
                }

                // Mode 3: Full Screen
                Rectangle {
                    implicitWidth: fullRow.implicitWidth + 18
                    implicitHeight: 38
                    radius: 19
                    color: fullMouse.pressed ? Theme.colors.surfaceActive : (fullMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                    border.color: fullMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"
                    border.width: 1

                    scale: fullMouse.pressed ? 0.95 : (fullMouse.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                    RowLayout {
                        id: fullRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰍹"
                            font.pixelSize: 17
                            font.family: Theme.typography.fontFamily
                            color: Theme.colors.accent
                            renderType: Theme.renderType
                        }

                        Text {
                            text: I18n.tr("screenshot_fullscreen")
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                            renderType: Theme.renderType
                        }
                    }

                    MouseArea {
                        id: fullMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerCapture("fullscreen")
                    }
                }

                // Separator
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 22
                    color: Theme.colors.border
                }

                // Close Button
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: closeMouse.pressed ? Theme.colors.surfaceActive : (closeMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                    border.color: closeMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"
                    border.width: 1

                    scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: closeMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
                        renderType: Theme.renderType
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeScreenshot()
                    }
                }
            }
        }
    }
}
