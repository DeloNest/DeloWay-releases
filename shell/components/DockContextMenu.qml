import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

PopupWindow {
    id: root

    property var dockWindow: null
    property var targetApp: null
    property Item anchorItem: null
    property real iconCenterInDock: 0
    property bool _cardVisible: false

    color: "transparent"
    visible: false
    grabFocus: true

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.visible
        onCleared: root.hide()
    }

    anchor {
        window: root.dockWindow
        item: root.anchorItem
        gravity: Edges.Top
        edges: Edges.Top
        adjustment: PopupAdjustment.SlideX
    }

    implicitWidth: menuCard.width + 16
    implicitHeight: menuCard.height + 6 + 10

    function show(app, item, centerInDock) {
        targetApp = app;
        anchorItem = item;
        iconCenterInDock = centerInDock || 0;
        anchor.updateAnchor();
        visible = true;
        _cardVisible = true;
        menuCard.forceActiveFocus();
    }

    function hide() {
        _cardVisible = false;
        visible = false;
        targetApp = null;
        anchorItem = null;
    }

    onVisibleChanged: {
        if (!visible) {
            _cardVisible = false;
            targetApp = null;
            anchorItem = null;
        }
    }

    readonly property real caretX: {
        if (root.anchor.rect.x !== 0 && root.iconCenterInDock !== 0) {
            var rel = root.iconCenterInDock - root.anchor.rect.x - ((root.width - menuCard.width) / 2);
            return Math.max(20, Math.min(menuCard.width - 20, rel));
        }
        return menuCard.width / 2;
    }

    // Ambient Drop Shadow
    Rectangle {
        id: menuShadow
        z: 0
        anchors.fill: menuCard
        anchors.topMargin: 3
        anchors.bottomMargin: -3
        anchors.leftMargin: -2
        anchors.rightMargin: -2
        radius: menuCard.radius + 2
        color: Theme.notchShadow
        opacity: menuCard.opacity
        scale: menuCard.scale
        transformOrigin: menuCard.transformOrigin
    }

    // Menu Card with scale+fade animation
    Rectangle {
        id: menuCard
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: 210
        height: menuCol.implicitHeight + 14
        radius: Theme.radiusMedium
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1

        focus: true
        Keys.onEscapePressed: root.hide()

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Entry/exit animation
        opacity: root._cardVisible ? 1.0 : 0.0
        scale: root._cardVisible ? 1.0 : 0.92
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingExit } }
        Behavior on scale   { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingExit } }

        // Top luminous rim
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.topMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
            height: 1; radius: parent.radius
            color: Theme.notchBorderSubtle
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
                    font.family: Theme.typography.fontFamily; font.pixelSize: Theme.fontSize(12); font.weight: Font.DemiBold
                    color: Theme.notchText; elide: Text.ElideRight; maximumLineCount: 1
                }
                Rectangle {
                    visible: Boolean(root.targetApp &&
                              (root.targetApp.running ||
                               (root.targetApp.windows && root.targetApp.windows.length > 0)))
                    width: 7; height: 7; radius: 3.5
                    color: Theme.colors.success
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 1
                Layout.leftMargin: 2; Layout.rightMargin: 2
                color: Theme.notchBorderSubtle
            }

            // Pin / Unpin
            Rectangle {
                id: pinBg; Layout.fillWidth: true; Layout.preferredHeight: 32; radius: Theme.radiusSmall
                color: pinMouse.pressed ? Theme.notchSurfaceActive : (pinMouse.containsMouse ? Theme.notchSurfaceHover : "transparent")
                border.color: "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                readonly property bool isPinned: root.targetApp ? ApplicationManager.isPinned(root.targetApp.id) : false
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: pinBg.isPinned?"list-remove":"list-add"; iconSize: 14
                        iconColor: pinMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        scale: pinMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }
                    Text { Layout.fillWidth:true; text: pinBg.isPinned ? I18n.tr("unpin_from_dock") : I18n.tr("pin_to_dock")
                        font.family:Theme.typography.fontFamily; font.pixelSize:Theme.fontSize(12)
                        font.weight: pinMouse.containsMouse ? Font.DemiBold : Font.Normal
                        color:Theme.notchText; elide:Text.ElideRight }
                }
                MouseArea { id: pinMouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; z:3
                    onClicked: { var a=root.targetApp; root.hide(); if(a&&a.id) ApplicationManager.togglePin(a.id); }
                }
            }

            // Open / New Window
            Rectangle {
                id: openBg; Layout.fillWidth: true; Layout.preferredHeight: 32; radius: Theme.radiusSmall
                color: openMouse.pressed ? Theme.notchSurfaceActive : (openMouse.containsMouse ? Theme.notchSurfaceHover : "transparent")
                border.color: "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                readonly property bool isRunning: Boolean(root.targetApp &&
                    (root.targetApp.running || (root.targetApp.windows && root.targetApp.windows.length > 0)))
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: "document-open-symbolic"; iconSize: 14
                        iconColor: openMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                        scale: openMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }
                    Text { Layout.fillWidth:true; text: openBg.isRunning ? "New Window" : I18n.tr("open_app")
                        font.family:Theme.typography.fontFamily; font.pixelSize:Theme.fontSize(12)
                        font.weight: openMouse.containsMouse ? Font.DemiBold : Font.Normal
                        color:Theme.notchText; elide:Text.ElideRight }
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
                id: closeBg; Layout.fillWidth: true; Layout.preferredHeight: 32; radius: Theme.radiusSmall
                visible: Boolean(root.targetApp &&
                          (root.targetApp.running || (root.targetApp.windows && root.targetApp.windows.length > 0)))
                color: closeMouse.pressed ? Qt.alpha(Theme.colors.urgent,0.22) : (closeMouse.containsMouse ? Qt.alpha(Theme.colors.urgent,0.12) : "transparent")
                border.color: closeMouse.containsMouse ? Qt.alpha(Theme.colors.urgent,0.40) : "transparent"; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    SymbolicIcon { source: "window-close"; iconSize: 14
                        iconColor: closeMouse.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary
                        scale: closeMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    }
                    Text { Layout.fillWidth:true; text: I18n.tr("close_app")
                        font.family:Theme.typography.fontFamily; font.pixelSize:Theme.fontSize(12)
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

    // Connecting Caret (macOS Notch/Indicator pointing down to the dock icon)
    Shape {
        id: caretShape
        z: 2
        anchors.top: menuCard.bottom
        anchors.topMargin: -1
        x: menuCard.x + root.caretX - 7
        width: 14
        height: 7
        visible: root._cardVisible

        ShapePath {
            strokeColor: Theme.notchBorder
            strokeWidth: 1
            fillColor: Theme.notchBackground
            startX: 0
            startY: 0
            PathLine { x: 7; y: 6 }
            PathLine { x: 14; y: 0 }
        }
    }
}
