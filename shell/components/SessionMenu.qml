import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:sessionmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.sessionMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    visible: ShellState.sessionMenuOpen || hostItem.opacity > 0.01

    // Keyboard navigation
    Shortcut {
        sequence: "Escape"
        enabled: ShellState.sessionMenuOpen
        onActivated: ShellState.closeSessionMenu()
    }

    Shortcut {
        sequence: "1"
        enabled: ShellState.sessionMenuOpen
        onActivated: lockSession()
    }

    Shortcut {
        sequence: "2"
        enabled: ShellState.sessionMenuOpen
        onActivated: suspendSystem()
    }

    Shortcut {
        sequence: "3"
        enabled: ShellState.sessionMenuOpen
        onActivated: logoutSession()
    }

    Shortcut {
        sequence: "4"
        enabled: ShellState.sessionMenuOpen
        onActivated: rebootSystem()
    }

    Shortcut {
        sequence: "5"
        enabled: ShellState.sessionMenuOpen
        onActivated: poweroffSystem()
    }

    // System processes
    Process { id: poweroffProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }

    function lockSession() {
        ShellState.closeSessionMenu();
        ShellState.lock();
    }

    function suspendSystem() {
        ShellState.closeSessionMenu();
        suspendProc.running = true;
    }

    function logoutSession() {
        ShellState.closeSessionMenu();
        Hyprland.dispatch("exit");
    }

    function rebootSystem() {
        ShellState.closeSessionMenu();
        rebootProc.running = true;
    }

    function poweroffSystem() {
        ShellState.closeSessionMenu();
        poweroffProc.running = true;
    }

    Item {
        id: hostItem
        anchors.fill: parent

        opacity: ShellState.sessionMenuOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }

        // Dim backdrop with click-to-dismiss
        Rectangle {
            anchors.fill: parent
            color: Theme.modalScrim

            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.closeSessionMenu()
            }
        }

        // Center Fluent Mica Dialog
        Rectangle {
            id: dialogCard
            anchors.centerIn: parent
            width: 520
            implicitHeight: cardCol.implicitHeight + 40
            radius: Theme.radius.xlarge
            color: Theme.colors.surfaceElevated
            border.color: Theme.colors.borderHighlight
            border.width: 1

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            scale: ShellState.sessionMenuOpen ? 1.0 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }

            // Block click propagation through the card
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: cardCol
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: I18n.isRTL ? "جلسة DeloOS" : "DeloOS Session"
                            color: Theme.colors.text
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.fontSize(18)
                            font.weight: Font.Bold
                            renderType: Theme.renderType
                        }

                        Text {
                            text: I18n.isRTL ? "اختر الإجراء المطلوب أو اضغط Esc للإلغاء" : "Select an action or press Esc to cancel"
                            color: Theme.colors.textSecondary
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.typography.scaleCaption.size
                            renderType: Theme.renderType
                        }
                    }

                    DeloButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        variant: "ghost"
                        text: "✕"
                        onClicked: ShellState.closeSessionMenu()
                    }
                }

                // Action Tiles Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 5
                    rowSpacing: 10
                    columnSpacing: 10

                    // 1. Lock
                    SessionTile {
                        Layout.fillWidth: true
                        icon: "system-lock-screen-symbolic"
                        title: I18n.isRTL ? "قفل" : "Lock"
                        keyHint: "1"
                        onTriggered: root.lockSession()
                    }

                    // 2. Suspend
                    SessionTile {
                        Layout.fillWidth: true
                        icon: "media-playback-pause-symbolic"
                        title: I18n.isRTL ? "تعليق" : "Sleep"
                        keyHint: "2"
                        onTriggered: root.suspendSystem()
                    }

                    // 3. Log Out
                    SessionTile {
                        Layout.fillWidth: true
                        // Directional exit arrow: the theme ships an -rtl variant.
                        icon: I18n.isRTL ? "system-log-out-rtl-symbolic" : "system-log-out-symbolic"
                        title: I18n.isRTL ? "خروج" : "Logout"
                        keyHint: "3"
                        onTriggered: root.logoutSession()
                    }

                    // 4. Reboot
                    SessionTile {
                        Layout.fillWidth: true
                        icon: "system-reboot-symbolic"
                        title: I18n.isRTL ? "إعادة تشغيل" : "Reboot"
                        keyHint: "4"
                        onTriggered: root.rebootSystem()
                    }

                    // 5. Power Off
                    SessionTile {
                        Layout.fillWidth: true
                        icon: "system-shutdown-symbolic"
                        title: I18n.isRTL ? "إيقاف" : "Shut Down"
                        keyHint: "5"
                        isDanger: true
                        onTriggered: root.poweroffSystem()
                    }
                }

                // Footer with User & Host Info
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Theme.radius.medium
                    color: Theme.colors.surfaceVariant
                    border.color: Theme.colors.borderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        SymbolicIcon {
                            iconSize: 15
                            source: "avatar-default-symbolic"
                            iconColor: Theme.colors.textSecondary
                        }

                        Text {
                            text: (Quickshell.env("USER") || "user") + " @ DeloOS"
                            color: Theme.colors.textSecondary
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.typography.scaleCaption.size
                            renderType: Theme.renderType
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Hyprland Wayland Compositor"
                            color: Theme.colors.textTertiary
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.fontSize(10)
                            renderType: Theme.renderType
                        }
                    }
                }
            }
        }
    }

    // Component definition for session tiles
    component SessionTile: Rectangle {
        id: tileRoot
        property string icon: ""
        property string title: ""
        property string keyHint: ""
        property bool isDanger: false
        signal triggered()

        Layout.preferredHeight: 82
        radius: Theme.radius.large
        // Danger is signalled by the glyph colour only (semantic colours never fill surfaces).
        color: tileMouse.pressed ? Theme.colors.surfaceActive
               : (tileMouse.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surface)
        border.color: tileMouse.containsMouse ? Theme.colors.borderHighlight : Theme.colors.borderSubtle
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            SymbolicIcon {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 22
                source: tileRoot.icon
                iconColor: tileRoot.isDanger
                           ? Theme.colors.urgent
                           : Theme.colors.text
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tileRoot.title
                color: tileMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.Medium
                renderType: Theme.renderType
            }
        }

        // Key Hint badge (e.g. "1", "2")
        Rectangle {
            // Direction via x: runtime-flipped left/right anchors stretch the item.
            y: 6
            x: I18n.isRTL ? 6 : parent.width - width - 6
            width: 16
            height: 16
            radius: 8
            color: Theme.colors.surfaceVariant
            border.color: Theme.colors.borderSubtle
            border.width: 1
            visible: tileRoot.keyHint.length > 0

            Text {
                font.family: Theme.typography.fontFamily
                anchors.centerIn: parent
                text: tileRoot.keyHint
                color: Theme.colors.textTertiary
                font.pixelSize: Theme.fontSize(9)
                font.weight: Font.Bold
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileRoot.triggered()
        }
    }
}
