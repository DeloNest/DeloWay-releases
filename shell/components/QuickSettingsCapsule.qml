import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        right: !I18n.isRTL
        left: I18n.isRTL
    }

    margins {
        top: 0
        right: !I18n.isRTL ? 12 : 0
        left: I18n.isRTL ? 12 : 0
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:quicksettings-capsule"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────────
    // Dimensions & State (Matching Notch smooth transitions)
    // ─────────────────────────────────────────────────────────────────────────
    property bool isExpanded: false

    readonly property real compactHeight: 44
    readonly property real compactWidth: Math.max(44, compactRow.implicitWidth + 24)
    readonly property real expandedWidth: 360
    readonly property real expandedHeight: 240

    property real currentWidth: isExpanded ? expandedWidth : compactWidth
    property real currentHeight: isExpanded ? expandedHeight : compactHeight

    Behavior on currentWidth  { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on currentHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    implicitWidth: Math.round(currentWidth)
    implicitHeight: Math.round(currentHeight + 8) // Shadow margin

    // ─────────────────────────────────────────────────────────────────────────
    // Network Data Logic (Reusing deloway-network.py logic from QuickSettings)
    // ─────────────────────────────────────────────────────────────────────────
    property var networkData: null
    readonly property string wifiSsid: (networkData && networkData.wifi && networkData.wifi.ssid) ? networkData.wifi.ssid : ""

    Process {
        id: networkStatusProcess
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.networkData = parsed;
                } catch(e) {}
            }
        }
    }

    Timer {
        id: networkPollTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (SystemMonitor.isWifi) {
                networkStatusProcess.running = true;
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Visual Hierarchy
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // Ambient Drop Shadow (Matches Notch depth)
        Rectangle {
            anchors.fill: capsuleBody
            anchors.topMargin: 4
            anchors.bottomMargin: -4
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: capsuleBody.bottomLeftRadius + 2
            color: Theme.notchShadow
            visible: root.isExpanded
            z: 0
        }

        // Main Capsule Body (Pure solid deep black, OLED notch feel)
        Rectangle {
            id: capsuleBody
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.currentWidth
            height: root.currentHeight
            color: Theme.notchBackground
            border.color: Theme.notchBorder
            border.width: 1
            z: 1

            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.isExpanded ? Theme.notchRadiusWindow : 22
            bottomRightRadius: root.isExpanded ? Theme.notchRadiusWindow : 22

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ── Stage 1: Compact View ────────────────────────────────────────
            Item {
                id: compactView
                anchors.fill: parent
                visible: !root.isExpanded
                opacity: root.isExpanded ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                RowLayout {
                    id: compactRow
                    anchors.centerIn: parent
                    spacing: 6

                    SymbolicIcon {
                        iconSize: 14
                        source: SystemMonitor.isWifi ? "network-wireless-symbolic" : "network-wired-symbolic"
                        iconColor: SystemMonitor.isOnline ? Theme.notchText : Theme.notchTextTertiary
                    }

                    Text {
                        id: ssidLabel
                        visible: SystemMonitor.isWifi && text.length > 0
                        text: root.wifiSsid
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.notchText
                        elide: Text.ElideRight
                        Layout.maximumWidth: 120
                        renderType: Theme.renderType
                    }
                }
            }

            // ── Stage 2: Expanded View (Placeholder for future commit) ───────
            Item {
                id: expandedView
                anchors.fill: parent
                visible: root.isExpanded
                opacity: root.isExpanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
            }
        }
    }
}
