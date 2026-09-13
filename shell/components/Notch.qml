import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
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

    // Dynamic width & height with smooth physics animations
    property bool isExpanded: ShellState.smartNotchExpanded
    property bool isHovered: false

    // State dimensions — authentic macOS NotchNook dropdown card
    readonly property real compactWidth: {
        if (notchHomeItem.notificationActive) return 420;
        if (notchHomeItem.isMusicPlaying) return 450;
        return 200;
    }
    readonly property real compactHeight: 44
    readonly property real expandedWidth: 600
    readonly property real expandedHeight: 176
    readonly property real earRadius: 18

    property real currentWidth: isExpanded ? expandedWidth : compactWidth
    property real currentHeight: isExpanded ? expandedHeight : compactHeight

    Behavior on currentWidth { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
    Behavior on currentHeight { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

    implicitWidth: Math.round(currentWidth + (isExpanded ? earRadius * 2 : 0))
    implicitHeight: Math.round(currentHeight + 8) // subtle shadow margin
    color: "transparent"

    WlrLayershell.namespace: "deloway:smart-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Item {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: currentWidth + (root.isExpanded ? root.earRadius * 2 : 0)
        height: currentHeight + 8

        // ──────────────────────────────────────────────────────────────────────
        // SOFT AMBIENT DROP SHADOW (macOS card depth)
        // ──────────────────────────────────────────────────────────────────────
        Rectangle {
            anchors.fill: notchBody
            anchors.topMargin: 6
            anchors.bottomMargin: -6
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: 28
            color: Qt.rgba(0, 0, 0, 0.40)
            visible: root.isExpanded
            z: 0
        }

        // ──────────────────────────────────────────────────────────────────────
        // TOP CONCAVE FILLET EARS (macOS camera notch seamless integration)
        // ──────────────────────────────────────────────────────────────────────
        // Left Ear
        Shape {
            anchors.top: parent.top
            anchors.right: notchBody.left
            width: root.isExpanded ? root.earRadius : 0
            height: root.earRadius
            visible: width > 0
            z: 1

            ShapePath {
                fillColor: "#000000"
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: root.earRadius; y: 0 }
                PathLine { x: root.earRadius; y: root.earRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: root.earRadius
                    radiusY: root.earRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        // Right Ear
        Shape {
            anchors.top: parent.top
            anchors.left: notchBody.right
            width: root.isExpanded ? root.earRadius : 0
            height: root.earRadius
            visible: width > 0
            z: 1

            ShapePath {
                fillColor: "#000000"
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: root.earRadius; y: 0 }
                PathArc {
                    x: 0
                    y: root.earRadius
                    radiusX: root.earRadius
                    radiusY: root.earRadius
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }

        // ──────────────────────────────────────────────────────────────────────
        // MAIN NOTCH BODY (Pure solid deep black, macOS Retina/OLED feel)
        // ──────────────────────────────────────────────────────────────────────
        Rectangle {
            id: notchBody
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.currentWidth
            height: root.currentHeight
            color: "#000000"
            border.color: "transparent"
            z: 2

            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: root.isExpanded ? 26 : 22
            bottomRightRadius: root.isExpanded ? 26 : 22

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ──────────────────────────────────────────────────────────────────
            // COMPACT MODE — Click to expand
            // ──────────────────────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: !root.isExpanded
                opacity: root.isExpanded ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    z: 0
                    onEntered: root.isHovered = true
                    onExited: root.isHovered = false
                    onClicked: ShellState.openSmartNotch()
                }

                NotchHome {
                    id: notchHomeItem
                    anchors.fill: parent
                    expanded: false
                    targetScreen: root.targetScreen
                    z: 1
                }
            }

            // ──────────────────────────────────────────────────────────────────
            // EXPANDED MODE — Full 2-tier macOS NotchNook card
            // ──────────────────────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.isExpanded
                opacity: root.isExpanded ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 8
                    anchors.bottomMargin: 12
                    spacing: 4
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true

                    // ── TIER 1: Header Bar (Nook & Tray Tabs on left, ⚙ on right) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 6
                        LayoutMirroring.enabled: false
                        LayoutMirroring.childrenInherit: true

                        // Tab 1: Nook
                        Rectangle {
                            implicitWidth: tab0Row.implicitWidth + 18
                            implicitHeight: 24
                            radius: 12
                            color: swipeView.currentIndex === 0
                                   ? Qt.rgba(1, 1, 1, 0.18)
                                   : (tab0Ma.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: tab0Row
                                anchors.centerIn: parent
                                spacing: 6

                                SymbolicIcon {
                                    source: "notch-nook"
                                    iconSize: 13
                                    iconColor: swipeView.currentIndex === 0 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                }

                                Text {
                                    text: "Nook"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 12
                                    font.weight: swipeView.currentIndex === 0 ? Font.DemiBold : Font.Normal
                                    color: swipeView.currentIndex === 0 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                }
                            }

                            MouseArea {
                                id: tab0Ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.setSmartNotchTab(0)
                            }
                        }

                        // Tab 2: Tray
                        Rectangle {
                            implicitWidth: tab1Row.implicitWidth + 18
                            implicitHeight: 24
                            radius: 12
                            color: swipeView.currentIndex === 1
                                   ? Qt.rgba(1, 1, 1, 0.18)
                                   : (tab1Ma.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: tab1Row
                                anchors.centerIn: parent
                                spacing: 6

                                SymbolicIcon {
                                    source: "notch-tray"
                                    iconSize: 13
                                    iconColor: swipeView.currentIndex === 1 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                }

                                Text {
                                    text: "Tray"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 12
                                    font.weight: swipeView.currentIndex === 1 ? Font.DemiBold : Font.Normal
                                    color: swipeView.currentIndex === 1 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                }
                            }

                            MouseArea {
                                id: tab1Ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.setSmartNotchTab(1)
                            }
                        }

                        // Tab 3: Notify
                        Rectangle {
                            implicitWidth: tabNotifyRow.implicitWidth + 18
                            implicitHeight: 24
                            radius: 12
                            color: swipeView.currentIndex === 2
                                   ? Qt.rgba(1, 1, 1, 0.18)
                                   : (tabNotifyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: tabNotifyRow
                                anchors.centerIn: parent
                                spacing: 6

                                SymbolicIcon {
                                    source: "preferences-system-notifications-symbolic"
                                    iconSize: 13
                                    iconColor: swipeView.currentIndex === 2 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                }

                                Text {
                                    text: "Notify"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 12
                                    font.weight: swipeView.currentIndex === 2 ? Font.DemiBold : Font.Normal
                                    color: swipeView.currentIndex === 2 ? "#ffffff" : Qt.rgba(1, 1, 1, 0.65)
                                }
                            }

                            MouseArea {
                                id: tabNotifyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.setSmartNotchTab(2)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Settings Icon (⚙) — Solitary on right, matching reference
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: gearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "settings-symbolic"
                                iconSize: 14
                                iconColor: gearMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
                            }

                            MouseArea {
                                id: gearMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.closeSmartNotch();
                                    ShellState.openSettingsApp();
                                }
                            }
                        }
                    }

                    // ── TIER 2: Body Content (SwipeView) ──────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StackLayout {
                            id: swipeView
                            anchors.fill: parent
                            currentIndex: ShellState.smartNotchTab
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: true

                            // Page 0: Nook Tab (Music player + Calendar 50/50 split)
                            NotchHome {
                                expanded: true
                                targetScreen: root.targetScreen
                            }

                            // Page 1: Tray Tab (Dashed drop container + LocalSend direct inline)
                            NotchLocalSend {
                                id: notchLocalSendItem
                                expanded: true
                            }

                            // Page 2: Notify Tab (Notification history)
                            NotchNotifications {
                                id: notchNotificationsItem
                            }
                        }
                    }
                }
            }
        }
    }
}
