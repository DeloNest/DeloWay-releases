import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    color: "transparent"
    visible: _menuVisible

    WlrLayershell.namespace: "deloway:dock-context-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; top: true; right: true; bottom: true }

    property var targetApp: null
    property real globalCenterX: 0
    property bool _menuVisible: false
    property bool _open: false

    function show(app, centerX) {
        targetApp = app;
        globalCenterX = centerX;
        _menuVisible = true;
        _open = true;
    }

    function hide() {
        _open = false;
        _menuVisible = false;
        targetApp = null;
    }

    // Backdrop — clicks outside close menu
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.hide()
    }

    // Menu Card with scale+fade animation
    Rectangle {
        id: menuCard
        z: 9
        x: Math.max(12, Math.min(root.width - width - 12, root.globalCenterX - (width / 2)))
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 84
        width: 210
        height: menuCol.implicitHeight + 14
        radius: Theme.radiusMedium
        color: Theme.colors.surface
        border.color: Theme.hairline
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Entry/exit animation
        opacity: root._open ? 1.0 : 0.0
        scale: root._open ? 1.0 : 0.90
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }
        Behavior on scale   { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingExit } }

        // Top luminous rim
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.topMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
            height: 1; radius: parent.radius
            color: Theme.hairlineSoft
        }

        // Block backdrop from stealing clicks inside card
        MouseArea {
            anchors.fill: parent; z: 1
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => mouse.accepted = true
            onPressed: mouse => mouse.accepted = true
        }

        ColumnLayout {
            id: menuCol
            z: 2
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 7
            spacing: 2

            // Header: Icon + Name + Running Dot
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6; Layout.rightMargin: 6
                Layout.topMargin: 5; Layout.bottomMargin: 4
                spacing: 8

                AppIcon {
                    iconSize: 22
                    source: root.targetApp ? root.targetApp.icon : ""
                    visible: Boolean(root.targetApp && root.targetApp.icon)
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: root.targetApp ? (root.targetApp.name || root.targetApp.id || "") : ""
                    font.family: Theme.typography.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                    color: Theme.colors.text; elide: Text.ElideRight; maximumLineCount: 1
                }
                Rectangle {
                    visible: Boolean(root.targetApp &&
                              (root.targetApp.running ||
                               (root.targetApp.windows && root.targetApp.windows.length > 0)))
                    width: 7; height: 7; radius: 3.5
                    color: Theme.colors.accent
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 1
                Layout.leftMargin: 2; Layout.rightMargin: 2
                color: Theme.hairline
            }

            // Pin / Unpin
            Rectangle {
                id: pinBg; Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSmall
                color: pinMouse.pressed ? Theme.overlayHoverStrong : (pinMouse.containsMouse ? Theme.overlayHover : "transparent")
                border.color: pinMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                readonly property bool isPinned: root.targetApp ? ApplicationManager.isPinned(root.targetApp.id) : false
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: pinBg.isPinned?"list-remove":"list-add"; iconSize: 15
                        iconColor: pinMouse.containsMouse ? Theme.colors.accent : Theme.colors.textSecondary
                        scale: pinMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }
                    Text { Layout.fillWidth:true; text: pinBg.isPinned ? I18n.tr("unpin_from_dock") : I18n.tr("pin_to_dock")
                        font.family:Theme.typography.fontFamily; font.pixelSize:Theme.typography.scaleBody.size
                        font.weight: pinMouse.containsMouse ? Font.DemiBold : Font.Normal
                        color:Theme.colors.text; elide:Text.ElideRight }
                }
                MouseArea { id: pinMouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; z:3
                    onClicked: { var a=root.targetApp; root.hide(); if(a&&a.id) ApplicationManager.togglePin(a.id); }
                }
            }

            // Open / New Window
            Rectangle {
                id: openBg; Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSmall
                color: openMouse.pressed ? Theme.overlayHoverStrong : (openMouse.containsMouse ? Theme.overlayHover : "transparent")
                border.color: openMouse.containsMouse ? Theme.colors.borderHighlight : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                readonly property bool isRunning: Boolean(root.targetApp &&
                    (root.targetApp.running || (root.targetApp.windows && root.targetApp.windows.length > 0)))
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: "document-open-symbolic"; iconSize: 15
                        iconColor: openMouse.containsMouse ? Theme.colors.accent : Theme.colors.textSecondary
                        scale: openMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }
                    Text { Layout.fillWidth:true; text: openBg.isRunning ? "New Window" : I18n.tr("open_app")
                        font.family:Theme.typography.fontFamily; font.pixelSize:Theme.typography.scaleBody.size
                        font.weight: openMouse.containsMouse ? Font.DemiBold : Font.Normal
                        color:Theme.colors.text; elide:Text.ElideRight }
                }
                MouseArea { id: openMouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; z:3
                    onClicked: {
                        var app=root.targetApp; root.hide();
                        if(app) {
                            if(app.id==="settings") ShellState.openSettingsApp();
                            else if(app.id==="store"||app.id==="software-store"||app.id==="delo-store") ShellState.openAppStore();
                            else if(app.desktopEntry&&typeof app.desktopEntry.execute==="function") app.desktopEntry.execute();
                            else if(typeof app.execute==="function") app.execute();
                            else ApplicationManager.launchApp(app);
                        }
                    }
                }
            }

            // Close (if running)
            Rectangle {
                id: closeBg; Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSmall
                visible: Boolean(root.targetApp &&
                          (root.targetApp.running || (root.targetApp.windows && root.targetApp.windows.length > 0)))
                color: closeMouse.pressed ? Qt.alpha(Theme.colors.urgent,0.22) : (closeMouse.containsMouse ? Qt.alpha(Theme.colors.urgent,0.12) : "transparent")
                border.color: closeMouse.containsMouse ? Qt.alpha(Theme.colors.urgent,0.40) : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: "window-close"; iconSize: 15
                        iconColor: closeMouse.containsMouse ? Theme.colors.urgent : Theme.colors.textSecondary
                        scale: closeMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }
                    Text { Layout.fillWidth:true; text: I18n.tr("close_app")
                        font.family:Theme.typography.fontFamily; font.pixelSize:Theme.typography.scaleBody.size
                        font.weight: closeMouse.containsMouse ? Font.DemiBold : Font.Normal
                        color:Theme.colors.urgent; elide:Text.ElideRight }
                }
                MouseArea { id: closeMouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; z:3
                    onClicked: {
                        var app=root.targetApp; root.hide();
                        if(app) {
                            if(app.id==="settings") ShellState.closeSettingsApp();
                            else if(app.id==="store"||app.id==="software-store"||app.id==="delo-store") ShellState.closeAppStore();
                            else {
                                var wins=(app.windows&&app.windows.length>0)?app.windows:ApplicationManager.getWindowsForApp(app.id);
                                for(var i=0;i<wins.length;i++) if(wins[i]&&typeof wins[i].close==="function") wins[i].close();
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 2 }
        }
    }
}
