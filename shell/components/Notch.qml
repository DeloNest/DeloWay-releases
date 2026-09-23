import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// Smart Notch — centre surface of the unified TopBar window (see TopBar.qml).
// This is a plain Item: it owns no layer surface of its own, so its geometry and the
// side capsules' geometry are always composed in the same frame buffer.
Item {
    id: root

    required property ShellScreen targetScreen
    anchors.fill: parent

    // Exposed to TopBar for the unified input mask / exclusive zone.
    readonly property alias maskItem: notchFrame
    readonly property int reservedZone: root.isExpanded ? Theme.topBarReserved : Theme.topBarExclusiveZone

    // Dynamic width & height with smooth physics animations
    property bool isExpanded: ShellState.smartNotchExpanded
    property bool isHovered: false

    // State dimensions — authentic macOS NotchNook dropdown card
    readonly property real compactWidth: {
        if (notchHomeItem.notificationActive) return 440;
        if (notchHomeItem.hasPlayer) return Math.min(520, Math.max(320, notchHomeItem.workspaceContentWidth + notchHomeItem.playerContentWidth + 48));
        return Math.max(110, notchHomeItem.workspaceContentWidth + 24);
    }
    readonly property real compactHeight: 44
    readonly property real expandedWidth: Theme.notchExpandedWidth
    readonly property real baseExpandedHeight: (ShellState.smartNotchTab === 1) ? 400 : 176
    property real expandedHeight: baseExpandedHeight
    Behavior on expandedHeight {
        NumberAnimation {
            duration: root.isExpanded ? 200 : 160
            easing.type: root.isExpanded ? Easing.OutCubic : Easing.OutQuad
        }
    }
    readonly property real earRadius: Theme.notchEarRadius

    Shortcut {
        sequence: "Escape"
        enabled: root.isExpanded
        onActivated: ShellState.closeSmartNotch()
    }

    // Single unified motion driver (200ms open, 160ms close)
    property real expandProgress: root.isExpanded ? 1.0 : 0.0
    Behavior on expandProgress {
        NumberAnimation {
            duration: root.isExpanded ? 200 : 160
            easing.type: root.isExpanded ? Easing.OutCubic : Easing.OutQuad
        }
    }

    // Compact width changes (idle ↔ music ↔ notification banner) morph smoothly; the side
    // capsules follow automatically through smartNotchCurrentWidth.
    property real animatedCompactWidth: compactWidth
    Behavior on animatedCompactWidth {
        NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
    }

    readonly property real currentWidth: Math.round(root.animatedCompactWidth + (root.expandedWidth - root.animatedCompactWidth) * root.expandProgress)
    readonly property real currentHeight: Math.round(root.compactHeight + (root.expandedHeight - root.compactHeight) * root.expandProgress)
    readonly property real currentY: Math.round(Theme.topBarMarginTop * (1.0 - root.expandProgress))

    readonly property real outerWidth: Math.round(currentWidth + root.earRadius * 2 * root.expandProgress)

    onOuterWidthChanged: ShellState.smartNotchCurrentWidth = outerWidth
    Component.onCompleted: ShellState.smartNotchCurrentWidth = outerWidth

    onIsExpandedChanged: {
        if (root.isExpanded) {
            ShellState.closeTimeCapsule();
            ShellState.closeQuickSettingsCapsule();
        }
    }

    NotchFrame {
        id: notchFrame
        y: root.currentY
        anchors.horizontalCenter: parent.horizontalCenter
        width: implicitWidth
        height: implicitHeight
        isExpanded: root.isExpanded
        currentWidth: root.currentWidth
        currentHeight: root.currentHeight
        earRadius: root.earRadius
        bottomRadius: 26
        clipContent: true

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
                    acceptedButtons: Qt.LeftButton
                    z: 0
                    onEntered: root.isHovered = true
                    onExited: root.isHovered = false
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            ShellState.openSmartNotch();
                        }
                    }
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                        if (wheel.angleDelta.y < 0) {
                            ShellState.openSmartNotch();
                        } else if (wheel.angleDelta.y > 0) {
                            ShellState.closeSmartNotch();
                        }
                    }
                }

                NotchHome {
                    id: notchHomeItem
                    anchors.fill: parent
                    expanded: false
                    targetScreen: root.targetScreen
                    z: 1
                }

                // Auto-expand into Tray Tab on file/item drag hover
                DropArea {
                    id: compactDropArea
                    anchors.fill: parent
                    enabled: !root.isExpanded
                    z: 10

                    onEntered: function(drag) {
                        ShellState.setSmartNotchTab(2);
                        ShellState.openSmartNotch();
                    }

                    onDropped: function(drop) {
                        ShellState.setSmartNotchTab(2);
                        ShellState.openSmartNotch();
                        var urls = [];
                        if (drop.hasUrls && drop.urls) {
                            urls = drop.urls;
                        } else if (drop.hasText && drop.text) {
                            urls = [drop.text];
                        }
                        if (urls.length > 0) {
                            LocalSendService.stageFiles(urls);
                            drop.acceptProposedAction();
                        }
                    }
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
                    // (inherits the reading direction from NotchFrame's bodyContent)

                    // ── TIER 1: Header Bar (Tabs centered, ⚙ on trailing edge) ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        implicitHeight: 28

                        MouseArea {
                            anchors.fill: parent
                            onWheel: (wheel) => {
                                wheel.accepted = true;
                                if (wheel.angleDelta.y < 0) {
                                    ShellState.openSmartNotch();
                                } else if (wheel.angleDelta.y > 0) {
                                    ShellState.closeSmartNotch();
                                }
                            }
                        }

                        // Collapse Button on leading edge
                        Rectangle {
                            // Direction via x, not conditional left/right anchors: when the
                            // language flips at runtime both anchors are briefly set, the item
                            // stretches across the header and keeps that width (misplaced icon,
                            // oversized hover area). x + fixed size can't stretch.
                            x: I18n.isRTL ? parent.width - width - 4 : 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 12
                            color: collapseMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "⌃"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(14)
                                font.weight: Font.Bold
                                color: collapseMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                            }

                            MouseArea {
                                id: collapseMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.closeSmartNotch()
                            }
                        }

                        // Expanded Tabs Row — centered independently in the Notch header
                        RowLayout {
                            id: notchTabsRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Tab 1: Nook
                            Rectangle {
                                implicitWidth: tab0Row.implicitWidth + 18
                                implicitHeight: 24
                                radius: 12
                                color: swipeView.currentIndex === 0
                                       ? Theme.notchSurfaceActive
                                       : (tab0Ma.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                RowLayout {
                                    id: tab0Row
                                    anchors.centerIn: parent
                                    spacing: 6

                                    SymbolicIcon {
                                        source: "notch-nook"
                                        iconSize: 13
                                        iconColor: (swipeView.currentIndex === 0 || tab0Ma.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                                    }

                                    Text {
                                        text: I18n.tr("notch_tab_home")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: swipeView.currentIndex === 0 ? Font.DemiBold : Font.Normal
                                        color: (swipeView.currentIndex === 0 || tab0Ma.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
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

                            // Tab 2: Notify
                            Rectangle {
                                implicitWidth: tabNotifyRow.implicitWidth + 18
                                implicitHeight: 24
                                radius: 12
                                color: swipeView.currentIndex === 1
                                       ? Theme.notchSurfaceActive
                                       : (tabNotifyMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                RowLayout {
                                    id: tabNotifyRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    SymbolicIcon {
                                        source: "preferences-system-notifications-symbolic"
                                        iconSize: 13
                                        iconColor: (swipeView.currentIndex === 1 || tabNotifyMa.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                                    }

                                    Text {
                                        text: I18n.tr("notch_tab_notifications")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: swipeView.currentIndex === 1 ? Font.DemiBold : Font.Normal
                                        color: (swipeView.currentIndex === 1 || tabNotifyMa.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                                    }

                                    // Unread count badge
                                    Rectangle {
                                        visible: NotificationManager.unreadCount > 0
                                        implicitWidth: Math.max(16, unreadText.implicitWidth + 6)
                                        implicitHeight: 14
                                        radius: 7
                                        color: Theme.isDark ? "#ffffff" : "#0f172a"
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            id: unreadText
                                            anchors.centerIn: parent
                                            text: String(NotificationManager.unreadCount)
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(9)
                                            font.weight: Font.Bold
                                            color: Theme.isDark ? "#000000" : "#ffffff"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tabNotifyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.setSmartNotchTab(1)
                                }
                            }

                            // Tab 3: Tray / Share
                            Rectangle {
                                implicitWidth: tab1Row.implicitWidth + 18
                                implicitHeight: 24
                                radius: 12
                                color: swipeView.currentIndex === 2
                                       ? Theme.notchSurfaceActive
                                       : (tab1Ma.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                RowLayout {
                                    id: tab1Row
                                    anchors.centerIn: parent
                                    spacing: 6

                                    SymbolicIcon {
                                        source: "notch-tray"
                                        iconSize: 13
                                        iconColor: (swipeView.currentIndex === 2 || tab1Ma.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                                    }

                                    Text {
                                        text: I18n.tr("notch_tab_share")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: swipeView.currentIndex === 2 ? Font.DemiBold : Font.Normal
                                        color: (swipeView.currentIndex === 2 || tab1Ma.containsMouse) ? Theme.notchText : Theme.notchTextSecondary
                                    }
                                }

                                MouseArea {
                                    id: tab1Ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.setSmartNotchTab(2)
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: function(drag) {
                                        ShellState.setSmartNotchTab(2);
                                    }
                                }
                            }
                        }

                        // Settings Icon (⚙) — Decoupled from tabs, anchored to trailing edge
                        Rectangle {
                            // Trailing edge via x (see collapse button note).
                            x: I18n.isRTL ? 4 : parent.width - width - 4
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: gearMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "settings-symbolic"
                                iconSize: 14
                                iconColor: gearMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
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

                            // Page 0: Nook Tab (Music player + Calendar 50/50 split)
                            NotchHome {
                                expanded: true
                                targetScreen: root.targetScreen
                            }

                            // Page 1: Notify Tab (Notification history)
                            NotchNotifications {
                                id: notchNotificationsItem
                            }

                            // Page 2: Tray Tab (Dashed drop container + LocalSend direct inline)
                            NotchLocalSend {
                                id: notchLocalSendItem
                                expanded: true
                            }
                        }
                    }
                }
            }
        }
}
