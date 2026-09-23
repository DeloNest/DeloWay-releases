import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

// AppContextMenu: the ONE right-click menu for application icons, shared by the Dock
// and the App Drawer (same rows, same logic, same look).
//
//   ┌──────────────────────────────┐
//   │ [icon] Firefox               │  header: name · live status · source
//   │        2 windows · AUR       │
//   │ • Window title A             │  window list (≥ 2 windows) → focus / restore
//   │ ○ Window title B             │
//   │ ───────────────────────────  │
//   │ New Window                   │  launch
//   │ Maximize · Minimize          │  window ops (running only)
//   │ ───────────────────────────  │
//   │ Unpin from Dock              │  app
//   │ App Info                     │
//   │ Uninstall…                   │  → in-menu confirmation step
//   │ ───────────────────────────  │
//   │ Close All Windows            │  (running only; red glyph only, ≤ 14px)
//   └──────────────────────────────┘
//
// Hosting: `openFor(app, item, placement)` anchors to an item's rect ("above" | "left" |
// "right"; the Dock), `openAt(app, x, y)` anchors at the pointer (the App Drawer).
// Coordinates are captured at open time; the popup never holds a pointer to the item
// (PopupAnchor keeps a raw pointer and delegates may be destroyed → SIGSEGV).
PopupWindow {
    id: root

    property var hostWindow: null
    signal actionTriggered(string action)  // host hook (the drawer closes itself on launch)

    // ── State ────────────────────────────────────────────────────────────
    property var appRef: null               // what the host passed (entry/DesktopEntry/id)
    property string placement: "above"      // above | left | right | pointer
    property string view: "main"            // main | confirm
    property bool _cardVisible: false
    property int _ax: 0
    property int _ay: 0
    property int _aw: 1
    property int _ah: 1

    readonly property var app: appRef ? AppActions.entryFor(appRef) : null
    readonly property var info: (app && !app.internal) ? AppActions.infoFor(app.desktopId) : null
    readonly property var windows: (app && app.windows) ? app.windows.filter(w => !!w) : []
    readonly property bool running: windows.length > 0
    readonly property bool uninstallBusy: app ? AppActions.isUninstalling(app.desktopId) : false

    color: "transparent"
    visible: false
    grabFocus: true

    // Grab ONLY the popup. Adding the host surface (dock / drawer layer) makes Hyprland
    // clear the grab the instant it activates, so the menu would never be seen.
    // Any click outside — including on the host — closes the menu.
    HyprlandFocusGrab {
        windows: [ root ]
        active: root.visible
        onCleared: root.hide()
    }

    anchor {
        window: root.hostWindow
        rect.x: root._ax
        rect.y: root._ay
        rect.width: root._aw
        rect.height: root._ah
        edges: root.placement === "right" ? Edges.Right
             : root.placement === "left" ? Edges.Left
             : root.placement === "pointer" ? (Edges.Bottom | (I18n.isRTL ? Edges.Left : Edges.Right))
             : Edges.Top
        gravity: root.placement === "right" ? Edges.Right
               : root.placement === "left" ? Edges.Left
               : root.placement === "pointer" ? (Edges.Bottom | (I18n.isRTL ? Edges.Left : Edges.Right))
               : Edges.Top
        adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    }

    // Shadow room around the card, plus a gap toward the anchor for edge placements.
    readonly property int pad: 8
    readonly property int gap: placement === "pointer" ? 0 : 6
    implicitWidth: menuCard.width + pad * 2 + ((placement === "left" || placement === "right") ? gap : 0)
    implicitHeight: menuCard.height + pad * 2 + (placement === "above" ? gap : 0)

    // ── API ──────────────────────────────────────────────────────────────
    function openFor(appOrId, item, where) {
        if (!appOrId || !item || !hostWindow || !hostWindow.contentItem) return;
        const p = item.mapToItem(hostWindow.contentItem, 0, 0);
        _open(appOrId, where || "above", Math.round(p.x), Math.round(p.y),
              Math.max(1, Math.round(item.width)), Math.max(1, Math.round(item.height)));
    }
    function openAt(appOrId, x, y) {
        _open(appOrId, "pointer", Math.round(x), Math.round(y), 1, 1);
    }
    function _open(appOrId, where, x, y, w, h) {
        appRef = (typeof appOrId === "string") ? appOrId : Object.assign({}, appOrId);
        placement = where;
        _ax = x; _ay = y; _aw = w; _ah = h;
        view = "main";
        hoverIndex = -1;
        const a = AppActions.entryFor(appRef);
        if (a && !a.internal) AppActions.requestInfo(a.desktopId);
        anchor.updateAnchor();
        visible = true;
        _cardVisible = true;
    }
    function hide() {
        _cardVisible = false;
        visible = false;
    }
    onVisibleChanged: {
        if (!visible) {
            _cardVisible = false;
            appRef = null;
            view = "main";
            hoverIndex = -1;
        }
    }

    // ── Rows ─────────────────────────────────────────────────────────────
    // { kind: "window" | "action" | "sep", … } — separators only between non-empty groups.
    readonly property var rows: {
        const _r = ApplicationManager._windowStateRevision;
        const a = root.app;
        if (!a) return [];
        const groups = [];

        if (root.windows.length >= 2) {
            groups.push(root.windows.slice(0, 6).map(w => ({
                kind: "window", win: w,
                label: NotificationManager.plainText(w.title || a.name || a.id, true),
                active: ApplicationManager.isActiveWindow(w),
                minimized: ApplicationManager.isMinimized(w)
            })));
        }

        const launchGroup = [root.running
            ? { kind: "action", id: "new", label: I18n.tr("dock_new_window"), icon: "window-new-symbolic" }
            : { kind: "action", id: "open", label: I18n.tr("open_app"), icon: "media-playback-start-symbolic" }];
        if (root.running) {
            const prim = ApplicationManager.primaryWindow(a);
            const maxed = prim ? ApplicationManager.isMaximized(prim) : false;
            launchGroup.push({ kind: "action", id: "max",
                               icon: maxed ? "window-restore-symbolic" : "window-maximize-symbolic",
                               label: I18n.tr(maxed ? "dock_unmaximize" : "dock_maximize") });
            launchGroup.push({ kind: "action", id: "min",
                               icon: a.allMinimized ? "window-restore-symbolic" : "window-minimize-symbolic",
                               label: I18n.tr(a.allMinimized ? "dock_restore" : "dock_minimize") });
        }
        groups.push(launchGroup);

        const appGroup = [{ kind: "action", id: "pin",
                            icon: a.pinned ? "list-remove-symbolic" : "view-pin-symbolic",
                            label: I18n.tr(a.pinned ? "unpin_from_dock" : "pin_to_dock") }];
        if (!a.internal) {
            appGroup.push({ kind: "action", id: "info", icon: "help-about-symbolic", label: I18n.tr("app_info") });
            // Hidden once the backend says it can't be removed; shown while still checking.
            if (!root.info || root.info.removable || !root.info.ok)
                appGroup.push({ kind: "action", id: "uninstall", icon: "user-trash-symbolic",
                                label: root.uninstallBusy ? I18n.tr("app_uninstalling") : I18n.tr("app_uninstall"),
                                disabled: root.uninstallBusy });
        }
        groups.push(appGroup);

        if (root.running)
            groups.push([{ kind: "action", id: "close", danger: true, icon: "window-close-symbolic",
                           label: I18n.tr(root.windows.length > 1 ? "dock_close_all" : "dock_close_window") }]);

        const out = [];
        for (let g = 0; g < groups.length; g++) {
            if (groups[g].length === 0) continue;
            if (out.length > 0) out.push({ kind: "sep" });
            for (const r of groups[g]) out.push(r);
        }
        return out;
    }

    function trigger(row) {
        const a = root.app;
        if (!row || !a || row.disabled) return;
        if (row.kind === "window") {
            root.hide();
            ApplicationManager.focusWindow(row.win);
            root.actionTriggered("window");
            return;
        }
        if (row.id === "uninstall") { root.view = "confirm"; root.hoverIndex = -1; return; }
        root.hide();
        switch (row.id) {
        case "open":
        case "new":       AppActions.launch(a); break;
        case "pin":       AppActions.togglePin(a); break;
        case "info":      AppActions.openInfo(a); break;
        case "max": {
            const p = ApplicationManager.primaryWindow(a);
            if (p) ApplicationManager.toggleMaximize(p);
            break;
        }
        case "min":
            if (a.allMinimized) ApplicationManager.restoreAll(a);
            else ApplicationManager.minimizeAll(a);
            break;
        case "close":     AppActions.closeAll(a); break;
        }
        root.actionTriggered(row.id);
    }

    function confirmUninstall() {
        const a = root.app;
        if (!a || !root.info || !root.info.removable) return;
        root.hide();
        AppActions.uninstall(a);
        root.actionTriggered("uninstall");
    }

    property int hoverIndex: -1

    // ── Shadow ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: menuCard
        anchors.topMargin: 3
        anchors.bottomMargin: -4
        anchors.leftMargin: -2
        anchors.rightMargin: -2
        radius: menuCard.radius + 2
        color: Theme.notchShadow
        visible: Theme.enableShadows
        opacity: menuCard.opacity
        scale: menuCard.scale
        transformOrigin: menuCard.transformOrigin
    }

    // ── Card ─────────────────────────────────────────────────────────────
    Rectangle {
        id: menuCard
        width: 248
        height: (root.view === "main" ? mainCol.implicitHeight : confirmCol.implicitHeight) + 12
        x: root.placement === "right" ? root.pad + root.gap : root.pad
        y: root.pad
        radius: Theme.radiusLarge
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Fade + short slide out of the anchor side.
        readonly property real slideFrom: 6
        opacity: root._cardVisible ? 1.0 : 0.0
        scale: root._cardVisible ? 1.0 : 0.96
        transformOrigin: root.placement === "right" ? Item.Left
                       : root.placement === "left" ? Item.Right
                       : root.placement === "pointer" ? (I18n.isRTL ? Item.TopRight : Item.TopLeft)
                       : Item.Bottom
        transform: Translate {
            x: root._cardVisible ? 0 : (root.placement === "right" ? -menuCard.slideFrom : root.placement === "left" ? menuCard.slideFrom : 0)
            y: root._cardVisible ? 0 : (root.placement === "above" ? menuCard.slideFrom : root.placement === "pointer" ? -menuCard.slideFrom / 2 : 0)
            Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        // Inner sheen rim
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.color: Theme.notchBorderSubtle
            border.width: 1
        }

        // ── Main view ────────────────────────────────────────────────────
        ColumnLayout {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            spacing: 1
            visible: opacity > 0.01
            opacity: root.view === "main" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MenuHeader { Layout.fillWidth: true }

            Repeater {
                model: root.rows
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    required property int index

                    readonly property bool isSep: modelData.kind === "sep"
                    readonly property bool isWindow: modelData.kind === "window"
                    readonly property bool highlighted: root.hoverIndex === index && !modelData.disabled

                    Layout.fillWidth: true
                    Layout.preferredHeight: isSep ? 9 : (isWindow ? 30 : 32)

                    Rectangle {
                        visible: rowItem.isSep
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: Theme.notchBorderSubtle
                    }

                    Rectangle {
                        visible: !rowItem.isSep
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: rowMouse.pressed && !rowItem.modelData.disabled ? Theme.notchSurfaceActive
                             : rowItem.highlighted ? Theme.notchSurfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            opacity: rowItem.modelData.disabled ? 0.5 : 1

                            // Window rows: filled dot = focused, ring = minimized
                            Item {
                                visible: rowItem.isWindow
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                Layout.alignment: Qt.AlignVCenter
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: rowItem.modelData.minimized ? "transparent"
                                         : (rowItem.modelData.active ? Theme.dockIndicator : Theme.dockIndicatorIdle)
                                    border.color: rowItem.modelData.minimized ? Theme.dockIndicatorIdle : "transparent"
                                    border.width: 1
                                }
                            }

                            SymbolicIcon {
                                visible: !rowItem.isWindow
                                source: rowItem.modelData.icon || ""
                                iconSize: 14
                                iconColor: rowItem.modelData.danger ? Theme.colors.urgent
                                         : (rowItem.highlighted ? Theme.notchText : Theme.notchTextSecondary)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: NotificationManager.bidi(rowItem.modelData.label || "")
                                textFormat: Text.PlainText
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(rowItem.isWindow ? 12 : 13)
                                font.weight: (rowItem.highlighted || (rowItem.isWindow && rowItem.modelData.active))
                                             ? Font.DemiBold : Font.Normal
                                color: (rowItem.isWindow && rowItem.modelData.minimized) ? Theme.notchTextMeta
                                     : (rowItem.isWindow ? Theme.notchTextBody : Theme.notchText)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignLeft
                                renderType: Theme.renderType
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        enabled: !rowItem.isSep && root.view === "main"
                        hoverEnabled: true
                        cursorShape: rowItem.modelData.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse) root.hoverIndex = rowItem.index;
                            else if (root.hoverIndex === rowItem.index) root.hoverIndex = -1;
                        }
                        onClicked: root.trigger(rowItem.modelData)
                    }
                }
            }
        }

        // ── Uninstall confirmation view ──────────────────────────────────
        ColumnLayout {
            id: confirmCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            spacing: 8
            visible: opacity > 0.01
            opacity: root.view === "confirm" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MenuHeader { Layout.fillWidth: true }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                text: NotificationManager.bidi(I18n.tr("app_uninstall_confirm").replace("%1", root.app ? (root.app.name || root.app.id) : ""))
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: -6
                text: NotificationManager.bidi(AppActions.uninstallSummary(root.info))
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextMeta
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                Layout.bottomMargin: 2
                spacing: 6

                MenuButton {
                    Layout.fillWidth: true
                    label: I18n.tr("app_cancel")
                    onClicked: { root.view = "main"; root.hoverIndex = -1; }
                }
                MenuButton {
                    Layout.fillWidth: true
                    primary: true
                    glyph: "user-trash-symbolic"
                    label: I18n.tr("app_uninstall_action")
                    enabled: !!(root.info && root.info.ok && root.info.removable) && !root.uninstallBusy
                    onClicked: root.confirmUninstall()
                }
            }
        }
    }

    // Header shared by both views: icon · name · live status (· source once known)
    component MenuHeader: RowLayout {
        spacing: 10
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 5
        Layout.bottomMargin: 5

        AppIcon {
            iconSize: 28
            source: root.app ? root.app.icon : ""
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: -3
            Text {
                Layout.fillWidth: true
                text: root.app ? NotificationManager.bidi(root.app.name || root.app.id || "") : ""
                textFormat: Text.PlainText
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
            Text {
                Layout.fillWidth: true
                text: {
                    let s = !root.running ? I18n.tr("app_not_running")
                          : (root.app && root.app.allMinimized && root.windows.length === 1)
                              ? I18n.tr("dock_minimized") : I18n.windowsCount(root.windows.length);
                    if (root.info && root.info.ok) s += " · " + AppActions.sourceLabel(root.info);
                    return NotificationManager.bidi(s);
                }
                textFormat: Text.PlainText
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextMeta
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                renderType: Theme.renderType
            }
        }
    }

    // Compact pill button for the confirmation step (monochrome; primary = inverted).
    component MenuButton: Rectangle {
        id: mb
        property string label: ""
        property string glyph: ""
        property bool primary: false
        signal clicked()

        implicitHeight: 32
        radius: Theme.radiusSmall
        opacity: enabled ? 1 : 0.45
        color: mb.primary ? (mbMa.pressed ? Theme.notchTextSecondary : Theme.notchText)
             : (mbMa.pressed ? Theme.notchSurfaceActive : mbMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
        border.color: mb.primary ? "transparent" : Theme.notchBorder
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        Row {
            anchors.centerIn: parent
            spacing: 6
            SymbolicIcon {
                visible: mb.glyph.length > 0
                anchors.verticalCenter: parent.verticalCenter
                source: mb.glyph
                iconSize: 12
                iconColor: Theme.colors.urgent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mb.label
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.DemiBold
                color: mb.primary ? Theme.notchBackground : Theme.notchText
                renderType: Theme.renderType
            }
        }
        MouseArea {
            id: mbMa
            anchors.fill: parent
            enabled: mb.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }
}
