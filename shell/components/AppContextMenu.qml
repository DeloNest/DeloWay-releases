import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../services"

PopupWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    color: "transparent"

    // Only the instance on the screen that owns the anchor window becomes visible.
    visible: ShellState.appContextMenuVisible && ShellState.appContextMenuAnchorScreen === targetScreen

    property var targetApp: ShellState.appContextMenuTarget

    // Positioned relative to whichever window (Dock or AppDrawer) opened the menu.
    // x/y are the click point in that window's own coordinate space, so no screen
    // coordinate math is required. The menu opens UPWARD from the click point.
    anchor.window: ShellState.appContextMenuAnchorWindow
    anchor.rect.x: ShellState.appContextMenuX
    anchor.rect.y: ShellState.appContextMenuY
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: 200
    implicitHeight: menuCol.implicitHeight + 16

    function hide() {
        ShellState.closeAppContextMenu();
    }

    // Sync state when the popup is dismissed natively (outside click, parent closed).
    Connections {
        target: root
        function onClosed() {
            ShellState.closeAppContextMenu();
        }
    }

    // Menu Card
    Rectangle {
        id: menuCard
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.colors.surfaceElevated
        border.color: Theme.hairline
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Prevent clicks inside menu from propagating
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // App Name Header
            Text {
                text: root.targetApp ? (root.targetApp.name || root.targetApp.id) : ""
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.typography.scaleCaption.size
                font.weight: Font.DemiBold
                color: Theme.colors.textSecondary
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 6; Layout.rightMargin: 6; color: Theme.colors.borderSubtle }

            // Pin / Unpin
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; Layout.leftMargin: 4; Layout.rightMargin: 4; radius: Theme.radiusSmall
                color: pinMouse.pressed ? Theme.colors.surfaceActive : (pinMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                border.color: pinMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: pinRow.isPinned ? "list-remove" : "list-add"; iconSize: 15; iconColor: pinMouse.containsMouse ? Theme.colors.accent : Theme.colors.textSecondary; scale: pinMouse.containsMouse ? 1.10 : 1.0; Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } } }
                    Text { Layout.fillWidth: true; text: pinRow.isPinned ? I18n.tr("unpin_from_dock") : I18n.tr("pin_to_dock"); font.family: Theme.typography.fontFamily; font.pixelSize: Theme.typography.scaleBody.size; font.weight: pinMouse.containsMouse ? Font.DemiBold : Font.Normal; color: Theme.colors.text; elide: Text.ElideRight }
                }
                property bool isPinned: root.targetApp ? ApplicationManager.isPinned(root.targetApp.id) : false
                id: pinRow
                MouseArea { id: pinMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.targetApp) ApplicationManager.togglePin(root.targetApp.id); root.hide(); } }
            }

            // Open
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; Layout.leftMargin: 4; Layout.rightMargin: 4; radius: Theme.radiusSmall
                color: openMouse.pressed ? Theme.colors.surfaceActive : (openMouse.containsMouse ? Theme.colors.surfaceHover : "transparent")
                border.color: openMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: "document-open-symbolic"; iconSize: 15; iconColor: openMouse.containsMouse ? Theme.colors.accent : Theme.colors.textSecondary; scale: openMouse.containsMouse ? 1.10 : 1.0; Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } } }
                    Text { Layout.fillWidth: true; text: I18n.tr("open_app"); font.family: Theme.typography.fontFamily; font.pixelSize: Theme.typography.scaleBody.size; font.weight: openMouse.containsMouse ? Font.DemiBold : Font.Normal; color: Theme.colors.text; elide: Text.ElideRight }
                }
                MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.targetApp) { if (root.targetApp.execute && typeof root.targetApp.execute === "function") root.targetApp.execute(); else ApplicationManager.activateOrLaunch(root.targetApp); } root.hide(); } }
            }

            // Close (if running)
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; Layout.leftMargin: 4; Layout.rightMargin: 4; radius: Theme.radiusSmall
                visible: root.targetApp && root.targetApp.running === true
                color: closeMouse.pressed ? Qt.alpha(Theme.colors.urgent, 0.2) : (closeMouse.containsMouse ? Qt.alpha(Theme.colors.urgent, 0.1) : "transparent")
                border.color: closeMouse.containsMouse ? Qt.alpha(Theme.colors.urgent, 0.4) : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: "window-close"; iconSize: 15; iconColor: closeMouse.containsMouse ? Theme.colors.urgent : Theme.colors.textSecondary; scale: closeMouse.containsMouse ? 1.10 : 1.0; Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } } }
                    Text { Layout.fillWidth: true; text: I18n.tr("close_app"); font.family: Theme.typography.fontFamily; font.pixelSize: Theme.typography.scaleBody.size; font.weight: closeMouse.containsMouse ? Font.DemiBold : Font.Normal; color: Theme.colors.urgent; elide: Text.ElideRight }
                }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.targetApp && root.targetApp.windows) { for (var i = 0; i < root.targetApp.windows.length; i++) { var w = root.targetApp.windows[i]; if (w && typeof w.close === "function") w.close(); } } root.hide(); } }
            }
        }
    }
}