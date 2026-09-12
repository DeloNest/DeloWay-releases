import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 42
    color: "transparent"

    WlrLayershell.namespace: "deloway:topbar"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Auto

    readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(targetScreen)

    // ── Design tokens (Harmonized with Deloway Theme) ────────────────────────
    readonly property int  cardRadius:   Theme.radiusLarge
    readonly property int  pillRadius:   Theme.radiusSmall
    readonly property int  tileRadius:   Theme.radiusSmall
    readonly property color hoverFill:   Theme.overlayHover
    readonly property color hairline:    Theme.hairline
    readonly property color hairlineSoft: Theme.hairlineSoft

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacing.xsmall

        Rectangle {
            id: barBackground
            anchors.fill: parent
            color: Qt.alpha(Theme.colors.surface, Theme.material.mica)
            radius: root.cardRadius
            border.color: root.hairline
            border.width: 1

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing.medium
                anchors.rightMargin: Theme.spacing.medium
                spacing: Theme.spacing.small

                // ── LEFT: App Launcher (Clean, no text signature) ───────────
                Rectangle {
                    id: brandBtn
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 32
                    Layout.alignment: Qt.AlignVCenter
                    radius: root.pillRadius
                    color: brandMouse.pressed
                           ? Theme.overlayHoverStrong
                           : ((ShellState.appDrawerOpen || brandMouse.containsMouse)
                              ? root.hoverFill : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                    SymbolicIcon {
                        anchors.centerIn: parent
                        iconSize: 16
                        source: "deloway-launcher"
                        iconColor: ShellState.appDrawerOpen ? Theme.colors.accent : (brandMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                    }

                    MouseArea {
                        id: brandMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.toggleAppDrawer()
                    }
                }

                // ── Workspaces (Adjacent to launcher, leaves center clear for Notch) ──
                RowLayout {
                    spacing: Theme.spacing.xsmall
                    visible: ConfigManager.topBarShowWorkspaces

                    Repeater {
                        model: ConfigManager.workspacesCount

                        delegate: Rectangle {
                            id: wsBtn
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool isActive:
                                (root.hyprMonitor && root.hyprMonitor.activeWorkspace
                                 && root.hyprMonitor.activeWorkspace.id === wsId)

                            implicitWidth: 26
                            implicitHeight: 22
                            radius: root.tileRadius

                            // Active = filled accent; inactive = quiet tile
                            color: isActive
                                   ? Theme.colors.primary
                                   : (wsMouse.pressed
                                      ? Theme.overlayHoverStrong
                                      : (wsMouse.containsMouse ? root.hoverFill : "transparent"))
                            border.color: isActive
                                          ? Qt.alpha(Theme.colors.accent, 0.55)
                                          : (wsMouse.pressed
                                             ? root.hairline
                                             : (wsMouse.containsMouse ? root.hairline : root.hairlineSoft))
                            border.width: 1
                            Behavior on color        { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            Text {
                                anchors.centerIn: parent
                                text: wsBtn.wsId.toString()
                                color: wsBtn.isActive ? Theme.colors.accentText : Theme.colors.textSecondary
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.typography.fontSizeSmall
                                font.weight: wsBtn.isActive ? Font.DemiBold : Font.Medium
                                renderType: Theme.renderType
                                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + wsBtn.wsId)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ── RIGHT: Status cluster ────────────────────────────────────
                RowLayout {
                    spacing: Theme.spacing.fine

                    // Status icons — interactive buttons with quick flyout / view triggers
                    RowLayout {
                        spacing: 2

                        // Network button
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: root.tileRadius
                            color: netMouse.pressed ? Theme.overlayHoverStrong : (netMouse.containsMouse ? root.hoverFill : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 14
                                source: SystemMonitor.isWifi ? "network-wireless-symbolic" : "network-wired-symbolic"
                                iconColor: SystemMonitor.isOnline
                                           ? (netMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                                           : Theme.colors.textTertiary
                            }

                            MouseArea {
                                id: netMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.openQuickSettingsWithView("wifi")
                            }
                        }

                        // Bluetooth button
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: root.tileRadius
                            color: btMouse.pressed ? Theme.overlayHoverStrong : (btMouse.containsMouse ? root.hoverFill : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 14
                                source: "bluetooth-active-symbolic"
                                iconColor: SystemMonitor.bluetoothOn
                                           ? (btMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                                           : Theme.colors.textTertiary
                            }

                            MouseArea {
                                id: btMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.openQuickSettingsWithView("bluetooth")
                            }
                        }

                        // Audio volume button (Click to open audio control, scroll to adjust volume)
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: root.tileRadius
                            color: audioMouse.pressed ? Theme.overlayHoverStrong : (audioMouse.containsMouse ? root.hoverFill : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 14
                                source: (Pipewire.defaultAudioSink
                                         && Pipewire.defaultAudioSink.audio
                                         && Pipewire.defaultAudioSink.audio.muted)
                                        ? "audio-volume-muted-symbolic"
                                        : "audio-volume-high-symbolic"
                                iconColor: audioMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
                            }

                            MouseArea {
                                id: audioMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.openQuickSettingsWithView("main")
                                onWheel: (wheel) => {
                                    if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                        var vol = Pipewire.defaultAudioSink.audio.volume;
                                        if (wheel.angleDelta.y > 0) {
                                            Pipewire.defaultAudioSink.audio.volume = Math.min(1.5, vol + 0.05);
                                        } else if (wheel.angleDelta.y < 0) {
                                            Pipewire.defaultAudioSink.audio.volume = Math.max(0.0, vol - 0.05);
                                        }
                                    }
                                }
                            }
                        }

                        // Battery icon (if present)
                        SymbolicIcon {
                            visible: SystemMonitor.hasBattery
                            iconSize: 14
                            source: "battery-level-100-symbolic"
                            iconColor: Theme.colors.textSecondary
                        }
                    }

                    // Hairline separator before clock
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        color: root.hairline
                    }

                    // Clock — quiet pill, accent only on open state
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: clockText.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter
                        radius: root.pillRadius
                        color: clockMouse.pressed
                               ? Theme.overlayHoverStrong
                               : ((ShellState.quickSettingsOpen || clockMouse.containsMouse)
                                  ? root.hoverFill : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        Text {
                            id: clockText
                            anchors.centerIn: parent
                            color: Theme.colors.text
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.typography.scaleBody.size
                            font.weight: Font.Medium
                            renderType: Theme.renderType

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                triggeredOnStart: true
                                onTriggered: {
                                    const now = new Date();
                                    const fmt = ConfigManager.clockFormat === "24h"
                                                ? "ddd d MMM  HH:mm"
                                                : "ddd d MMM  hh:mm A";
                                    clockText.text = Qt.formatDateTime(now, fmt);
                                }
                            }
                        }

                        MouseArea {
                            id: clockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShellState.toggleQuickSettings()
                        }
                    }

                    // Avatar — flat circle, hairline ring
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.radius.pill
                        color: userMouse.pressed
                               ? Theme.overlayHoverStrong
                               : (userMouse.containsMouse ? root.hoverFill : "transparent")
                        border.color: ShellState.quickSettingsOpen
                                      ? Qt.alpha(Theme.colors.accent, 0.65)
                                      : (userMouse.pressed
                                         ? root.hairline
                                         : (userMouse.containsMouse ? root.hairline : root.hairlineSoft))
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 14
                            source: "avatar-default-symbolic"
                            iconColor: ShellState.quickSettingsOpen
                                       ? Theme.colors.accent
                                       : Theme.colors.textSecondary
                        }

                        MouseArea {
                            id: userMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShellState.toggleQuickSettings()
                        }
                    }
                }
            }
        }
    }
}