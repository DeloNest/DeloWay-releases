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

    anchors { bottom: true }
    margins { bottom: 10 }

    property bool autoHide: ConfigManager.dockAutoHide
    property bool dockHovered: false
    property bool dockVisible: !autoHide || dockHovered

    exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto

    readonly property int dockH:      68
    readonly property int cardRadius: Theme.radiusDock
    readonly property int itemPad:    8
    readonly property int iconSz:     48

    implicitHeight: dockH + 46
    implicitWidth: dockCard.implicitWidth + 120
    color: "transparent"

    WlrLayershell.namespace: "deloway:dock"
    WlrLayershell.layer: WlrLayer.Top

    // ── Auto-hide slide ─────────────────────────────────────────────────────
    Item {
        id: slideWrapper
        anchors.fill: parent

        transform: Translate {
            y: (root.autoHide && !root.dockVisible) ? 90 : 0
            Behavior on y { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }

        HoverHandler { onHoveredChanged: root.dockHovered = hovered }

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

            HoverHandler { onHoveredChanged: root.dockHovered = hovered }

            RowLayout {
                id: dockLayout
                anchors.centerIn: parent
                spacing: 8

                // ── 1. App Drawer / Launcher ─────────────────────────────────
                Item {
                    id: drawerBtn
                    implicitWidth: root.iconSz + root.itemPad
                    implicitHeight: root.dockH
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    z: drawerMouse.containsMouse ? 100 : 1

                    Item {
                        anchors.centerIn: parent
                        width: root.iconSz
                        height: root.iconSz

                        scale: drawerMouse.pressed ? 0.90
                             : (drawerMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        transform: Translate {
                            y: drawerMouse.containsMouse ? -2 : 0
                            Behavior on y { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + ConfigManager.projectDir + "/assets/icons/apps/deloway-launcher.svg"
                            sourceSize.width: parent.width * 2
                            sourceSize.height: parent.height * 2
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    // Open indicator (White dot matching macOS)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.dockDot
                        visible: ShellState.appDrawerOpen
                        opacity: ShellState.appDrawerOpen ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }

                    // Tooltip
                    Item {
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        z: 99
                        width: ttBg1.implicitWidth
                        height: ttBg1.implicitHeight
                        opacity: drawerMouse.containsMouse ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        transform: Translate {
                            y: drawerMouse.containsMouse ? 0 : 4
                            Behavior on y { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        }

                        Rectangle {
                            id: ttBg1
                            implicitWidth: Math.min(tt1.implicitWidth + 16, 220)
                            implicitHeight: 24
                            radius: Theme.notchRadiusPill
                            color: Theme.notchBackground
                            border.color: Theme.notchBorder
                            border.width: 1
                            Text {
                                id: tt1
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, 204)
                                elide: Text.ElideRight
                                text: I18n.tr("all_apps")
                                color: Theme.notchText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                renderType: Theme.renderType
                            }
                        }
                    }

                    MouseArea {
                        id: drawerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.toggleAppDrawer()
                    }
                }

                // ── 2. Pinned & Running Apps ─────────────────────────────────
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