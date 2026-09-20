import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins {
        bottom: 0
        left: 0
        right: 0
    }

    readonly property string dockMode: ConfigManager.dockMode
    readonly property bool isAutoHide: dockMode === "autohide"
    property bool dockHovered: false
    property bool isMenuOpen: Boolean(dockContextMenu && dockContextMenu.visible)
    property bool dockVisible: !isAutoHide || dockHovered || isMenuOpen

    exclusionMode: isAutoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: isAutoHide ? 0 : Theme.dockExclusiveZoneFor(dockH)

    readonly property int iconSz:     ConfigManager.dockIconSize > 0 ? ConfigManager.dockIconSize : 48
    readonly property int dockH:      iconSz + 20
    readonly property int cardRadius: Theme.radiusDock
    readonly property int itemPad:    8

    implicitHeight: dockH + 36
    color: "transparent"

    WlrLayershell.namespace: "deloway:dock"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        item: (!root.isAutoHide || root.dockVisible) ? dockHitBox : triggerStrip
    }

    // ── Timers for Auto-hide hysteresis (220ms show delay, 400ms hide delay) ──
    Timer {
        id: showTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (root.isAutoHide) {
                root.dockVisible = true;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (root.isAutoHide && !root.dockHovered && !triggerHover.hovered && !root.isMenuOpen) {
                root.dockVisible = false;
            }
        }
    }

    onIsAutoHideChanged: {
        showTimer.stop();
        hideTimer.stop();
        root.dockVisible = !root.isAutoHide;
    }

    onIsMenuOpenChanged: {
        if (!isMenuOpen && root.isAutoHide && !root.dockHovered && !triggerHover.hovered) {
            hideTimer.restart();
        }
    }

    // ── 2px Trigger Strip at bottom edge (entire screen width) ─────────────
    Item {
        id: triggerStrip
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        visible: root.isAutoHide

        HoverHandler {
            id: triggerHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    if (!root.dockVisible) {
                        showTimer.restart();
                    }
                } else {
                    showTimer.stop();
                    if (root.isAutoHide && !root.dockHovered && !root.isMenuOpen) {
                        hideTimer.restart();
                    }
                }
            }
        }
    }

    // ── HitBox for Dock Card & Gap (Centered at bottom) ─────────────────────
    Item {
        id: dockHitBox
        anchors.top: slideWrapper.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dockCard.implicitWidth + 32

        HoverHandler {
            id: dockHoverHandler
            onHoveredChanged: {
                root.dockHovered = hovered;
                if (hovered) {
                    showTimer.stop();
                    hideTimer.stop();
                    if (root.isAutoHide) root.dockVisible = true;
                } else {
                    if (root.isAutoHide && !triggerHover.hovered && !root.isMenuOpen) {
                        hideTimer.restart();
                    }
                }
            }
        }
    }

    // ── Auto-hide slide ─────────────────────────────────────────────────────
    Item {
        id: slideWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: dockCard.implicitWidth + 24
        height: root.dockH + 12

        transform: Translate {
            y: (root.isAutoHide && !root.dockVisible) ? (root.dockH + 30) : 0
            Behavior on y { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }

        // ─── Ambient Drop Shadow (Depth Layer) ──────────────────────────────
        Rectangle {
            id: dockShadow
            anchors.fill: dockCard
            anchors.topMargin: 4
            anchors.bottomMargin: -4
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: root.cardRadius + 2
            color: Theme.notchShadow
            z: -1
        }

        // ─── Floating Deep Black Capsule ────────────────────────────────────
        Rectangle {
            id: dockCard
            implicitWidth: dockLayout.implicitWidth + 24
            implicitHeight: root.dockH
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6

            color: Theme.notchBackground
            radius: root.cardRadius
            border.color: Theme.notchBorder
            border.width: 1

            // Subtle inner light sheen on top rim
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Theme.notchBorderSubtle
                border.width: 1
                anchors.margins: 1
            }

            MouseArea {
                id: dockWheelMa
                anchors.fill: parent
                hoverEnabled: false
                z: 0
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y < 0) {
                        ShellState.openAppDrawer();
                    } else if (wheel.angleDelta.y > 0) {
                        ShellState.closeAppDrawer();
                    }
                }
            }

            RowLayout {
                id: dockLayout
                anchors.centerIn: parent
                spacing: 8

                // ── 1. Pinned & Running Apps ─────────────────────────────────
                Repeater {
                    model: ApplicationManager.dockApps
                    delegate: Item {
                        id: appItem
                        required property var modelData

                        readonly property bool isHov:    itemMouse.containsMouse
                        readonly property bool running:  Boolean(modelData && modelData.running)
                        readonly property bool active:   Boolean(modelData && modelData.isActive)

                        implicitWidth: root.iconSz + root.itemPad
                        implicitHeight: root.dockH
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        Layout.alignment: Qt.AlignVCenter
                        z: appItem.isHov ? 100 : 1

                        Item {
                            anchors.centerIn: parent
                            width: root.iconSz
                            height: root.iconSz

                            scale: itemMouse.pressed ? 0.90 : (appItem.isHov ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                            transform: Translate {
                                y: appItem.isHov ? -2 : 0
                                Behavior on y { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            }

                            AppIcon {
                                anchors.fill: parent
                                iconSize: root.iconSz
                                source: appItem.modelData.icon
                            }
                        }

                        // Tooltip
                        Item {
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            z: 99
                            visible: appItem.isHov && Boolean(modelData && modelData.name)
                            width: ttBgApp.implicitWidth
                            height: ttBgApp.implicitHeight
                            opacity: appItem.isHov ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            transform: Translate {
                                y: appItem.isHov ? 0 : 4
                                Behavior on y { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            }

                            Rectangle {
                                id: ttBgApp
                                implicitWidth: Math.min(ttApp.implicitWidth + 16, 220)
                                implicitHeight: 24
                                radius: Theme.notchRadiusPill
                                color: Theme.notchBackground
                                border.color: Theme.notchBorder
                                border.width: 1
                                Text {
                                    id: ttApp
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, 204)
                                    elide: Text.ElideRight
                                    text: (modelData && modelData.name) ? modelData.name : ""
                                    color: Theme.notchText
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    renderType: Theme.renderType
                                }
                            }
                        }

                        // Authentic macOS Running Indicator Dot
                        Rectangle {
                            visible: ConfigManager.showUnderline && appItem.running
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.dockDot
                            opacity: appItem.active ? 1.0 : 0.70
                            Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    var iconCenterInDock = appItem.mapToItem(root.contentItem, appItem.width / 2, 0).x;
                                    dockContextMenu.show(modelData, appItem, iconCenterInDock);
                                } else {
                                    dockContextMenu.hide();
                                    ApplicationManager.activateOrLaunch(modelData);
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y < 0) {
                                    ShellState.openAppDrawer();
                                } else if (wheel.angleDelta.y > 0) {
                                    ShellState.closeAppDrawer();
                                }
                            }
                        }
                    }
                }

                // ── macOS Divider ────────────────────────────────────────────
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 32
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    color: Theme.notchBorderHighlight
                    radius: 1
                }

                // ── 3. Trash ─────────────────────────────────────────────────
                Item {
                    id: trashBtn
                    implicitWidth: root.iconSz + root.itemPad
                    implicitHeight: root.dockH
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    z: trashMouse.containsMouse ? 100 : 1

                    Item {
                        anchors.centerIn: parent
                        width: root.iconSz
                        height: root.iconSz

                        scale: trashMouse.pressed ? 0.90
                             : (trashMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        transform: Translate {
                            y: trashMouse.containsMouse ? -2 : 0
                            Behavior on y { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.92)
                            height: width
                            source: "file://" + ConfigManager.projectDir + "/assets/icons/apps/deloway-trash.svg"
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    // Tooltip
                    Item {
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        z: 99
                        width: ttBgTrash.implicitWidth
                        height: ttBgTrash.implicitHeight
                        opacity: trashMouse.containsMouse ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        transform: Translate {
                            y: trashMouse.containsMouse ? 0 : 4
                            Behavior on y { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }

                        Rectangle {
                            id: ttBgTrash
                            implicitWidth: Math.min(ttTrash.implicitWidth + 16, 220)
                            implicitHeight: 24
                            radius: Theme.notchRadiusPill
                            color: Theme.notchBackground
                            border.color: Theme.notchBorder
                            border.width: 1
                            Text {
                                id: ttTrash
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, 204)
                                elide: Text.ElideRight
                                text: I18n.tr("trash_title")
                                color: Theme.notchText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                renderType: Theme.renderType
                            }
                        }
                    }

                    MouseArea {
                        id: trashMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("exec xdg-open trash://")
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y < 0) {
                                ShellState.openAppDrawer();
                            } else if (wheel.angleDelta.y > 0) {
                                ShellState.closeAppDrawer();
                            }
                        }
                    }
                }
            }
        }
    }

    DockContextMenu {
        id: dockContextMenu
        dockWindow: root
    }
}