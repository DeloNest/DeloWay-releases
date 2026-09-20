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

    margins {
        top: 0
    }

    // Dynamic width & height with smooth physics animations
    property bool isExpanded: ShellState.smartNotchExpanded
    property bool isHovered: false

    // State dimensions — authentic macOS NotchNook dropdown card
    readonly property real compactWidth: {
        if (notchHomeItem.notificationActive) return 420;
        if (notchHomeItem.hasPlayer) return 490;
        return 200;
    }
    readonly property real compactHeight: 44
    readonly property real expandedWidth: 600
    readonly property real expandedHeight: 176
    readonly property real earRadius: 18

    // Fixed PanelWindow bounds to eliminate dynamic Wayland surface reallocations
    readonly property real fixedWindowWidth: 640
    readonly property real fixedWindowHeight: 200

    implicitWidth: fixedWindowWidth
    implicitHeight: fixedWindowHeight
    color: "transparent"

    WlrLayershell.namespace: "deloway:smart-notch"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.isExpanded ? Theme.topBarReserved : Theme.topBarExclusiveZone

    mask: Region {
        item: notchFrame
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.isExpanded
        onActivated: ShellState.closeSmartNotch()
    }

    // Single unified motion driver (220ms, OutCubic)
    property real expandProgress: root.isExpanded ? 1.0 : 0.0
    Behavior on expandProgress {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property real currentWidth: Math.round(root.compactWidth + (root.expandedWidth - root.compactWidth) * root.expandProgress)
    readonly property real currentHeight: Math.round(root.compactHeight + (root.expandedHeight - root.compactHeight) * root.expandProgress)
    readonly property real currentY: Math.round(Theme.topBarMarginTop * (1.0 - root.expandProgress))

    onCurrentWidthChanged: ShellState.smartNotchCurrentWidth = currentWidth
    Component.onCompleted: ShellState.smartNotchCurrentWidth = currentWidth

    onIsExpandedChanged: {
        if (root.isExpanded) {
            // Check collision on narrow screens (< 1500px)
            if (targetScreen.width < 1500 && ShellState.quickSettingsCapsuleExpanded) {
                ShellState.closeQuickSettingsCapsule();
            }
        }
    }

    NotchFrame {
        id: notchFrame
        y: root.currentY
        anchors.horizontalCenter: parent.horizontalCenter
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
                        ShellState.setSmartNotchTab(1);
                        ShellState.openSmartNotch();
                    }

                    onDropped: function(drop) {
                        ShellState.setSmartNotchTab(1);
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
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true

                    // ── TIER 1: Header Bar (Tabs centered, ⚙ on trailing edge) ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        implicitHeight: 28

                        MouseArea {
                            anchors.fill: parent
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    wheel.accepted = true;
                                    ShellState.closeSmartNotch();
                                }
                            }
                        }

                        // Collapse Button on leading edge
                        Rectangle {
                            anchors.left: I18n.isRTL ? undefined : parent.left
                            anchors.right: I18n.isRTL ? parent.right : undefined
                            anchors.leftMargin: I18n.isRTL ? 0 : 4
                            anchors.rightMargin: I18n.isRTL ? 4 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 24
                            implicitHeight: 24
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
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: true

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
                            anchors.right: I18n.isRTL ? undefined : parent.right
                            anchors.left: I18n.isRTL ? parent.left : undefined
                            anchors.rightMargin: I18n.isRTL ? 0 : 4
                            anchors.leftMargin: I18n.isRTL ? 4 : 0
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
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: true

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
