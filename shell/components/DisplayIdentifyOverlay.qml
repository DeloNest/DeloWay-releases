import "../services"
import "../theme"
// DeloWay Display Identification Overlay
// Displays a bold, high-contrast identifier on each screen when identifying displays
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    readonly property int screenIndex: {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i] === targetScreen)
                return i + 1;

        }
        return 1;
    }

    screen: targetScreen
    color: "transparent"
    WlrLayershell.namespace: "deloway:display-identify"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 180
        height: 180
        radius: Theme.radiusLarge
        color: Theme.colors.surfaceElevated
        border.color: Theme.notchBorderHighlight
        border.width: 2

        // Subtle OLED drop shadow simulation
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.margins: -4
            radius: Theme.radiusLarge + 4
            color: Theme.colors.background
            opacity: 0.8
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.space8

            // Giant Screen Number
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: String(root.screenIndex)
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(64)
                font.weight: Font.Black
                color: Theme.notchText
            }

            // Port Name Badge (e.g. DP-1, HDMI-A-1)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 26
                implicitWidth: portText.implicitWidth + Theme.space20
                radius: 13
                color: Theme.inverseSurface

                Text {
                    id: portText

                    anchors.centerIn: parent
                    text: root.targetScreen.name || ("Display " + root.screenIndex)
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    font.weight: Font.Bold
                    color: Theme.inverseText
                }

            }

        }

    }

}
