import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Dock: Apps button + pinned favourites + running apps + trash, on the bottom, left or right edge.
//
// Layout contract: every slot has a FIXED size; hover magnification, lift, press and
// launch-bounce are transforms only, so the row never reflows and can't jitter.
// Delegates are keyed by app id (ScriptModel of strings), so they survive window
// events and state changes (focus, minimize, urgent) animate instead of re-creating.
//
// Modes (Settings → Dock): always | autohide | intellihide | disabled
//   autohide     hidden unless the pointer reaches the edge or the dock
//   intellihide  visible until a window on this monitor's active workspace overlaps the
//                dock area (or goes fullscreen); edge-reveal works like autohide
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    // ── Placement (Settings → Dock → Position) ───────────────────────────
    readonly property string edge: ["left", "right"].indexOf(ConfigManager.dockPosition) >= 0 ? ConfigManager.dockPosition : "bottom"
    readonly property bool isVertical: edge !== "bottom"
    // Unit vector pointing *away* from the screen edge (into the screen).
    readonly property int inwardX: edge === "left" ? 1 : (edge === "right" ? -1 : 0)
    readonly property int inwardY: edge === "bottom" ? -1 : 0

    anchors {
        bottom: true
        top: root.isVertical
        left: root.edge !== "right"
        right: root.edge !== "left"
    }

    // ── Visibility state machine ─────────────────────────────────────────
    readonly property string dockMode: ConfigManager.dockMode
    readonly property bool isAutoHide: dockMode === "autohide"
    readonly property bool isIntelli: dockMode === "intellihide"
    readonly property bool hidesItself: isAutoHide || isIntelli

    property bool revealed: false          // edge/dock hover reveal (auto modes)
    property bool dockHovered: false
    property bool windowOverlaps: false    // intellihide: something covers the dock area
    readonly property bool isMenuOpen: dockContextMenu.visible
    readonly property bool dockVisible: !ShellState.shellHidden
        && (!hidesItself || revealed || dockHovered || isMenuOpen || (isIntelli && !windowOverlaps))

    visible: !ShellState.shellHidden
    exclusionMode: (hidesItself || ShellState.shellHidden) ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: (hidesItself || ShellState.shellHidden) ? 0 : Theme.dockExclusiveZoneFor(dockH)

    // ── Geometry ─────────────────────────────────────────────────────────
    readonly property int iconSz: ConfigManager.dockIconSize > 0 ? ConfigManager.dockIconSize : 48
    readonly property int dockH: iconSz + 20
    readonly property int slotLen: iconSz + 8            // slot length along the dock axis
    readonly property int slotGap: 6
    // Follows Settings → Appearance → corner radius, capped at a full pill.
    readonly property int cardRadius: Math.round(Math.min(dockH / 2, Theme.radiusDock * Theme.radiusScale))

    // The surface is taller (or wider) than the card so tooltips never clip; the input
    // mask keeps the extra area click-through.
    implicitHeight: dockH + 20 + Theme.dockTooltipRoom
    implicitWidth: root.isVertical ? dockH + 20 + 280 : 0
    color: "transparent"

    WlrLayershell.namespace: "deloway:dock"
    WlrLayershell.layer: WlrLayer.Top
    // Never takes keyboard focus. (Toggling layer keyboard interactivity at runtime
    // re-creates the surface and would destroy the context-menu popup.)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Union: the dock card while shown, plus (auto modes) a 2px reveal strip on the
    // edge that stays live while shown, so there's no reveal/hide feedback loop.
    mask: Region {
        item: root.dockVisible ? dockHitBox : triggerStrip
        regions: [ Region { item: triggerStrip } ]
    }

    // ── Reveal / hide hysteresis ─────────────────────────────────────────
    Timer {
        id: showTimer
        interval: 160
        onTriggered: if (root.hidesItself) root.revealed = true
    }
    Timer {
        id: hideTimer
        interval: 420
        onTriggered: {
            if (!root.dockHovered && !triggerHover.hovered && !root.isMenuOpen)
                root.revealed = false;
        }
    }
    onDockModeChanged: {
        showTimer.stop();
        hideTimer.stop();
        root.revealed = false;
        root.windowOverlaps = false;
        if (root.isIntelli) intelliDebounce.restart();
    }
    onIsMenuOpenChanged: {
        if (!isMenuOpen && !root.dockHovered && !triggerHover.hovered) hideTimer.restart();
    }
    onDockVisibleChanged: if (!dockVisible) root.hideTip(true)

    // ── Intellihide: window-overlap detection ────────────────────────────
    readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)

    // Dock card rect in global layout coordinates (ignores the slide transform, so it
    // is the rect the dock occupies when shown).
    function dockGlobalRect() {
        const s = root.screen;
        const winX = s.x + (root.edge === "right" ? s.width - root.width : 0);
        const winY = s.y + (root.edge === "bottom" ? s.height - root.height : 0);
        return {
            x: winX + slideWrapper.x + dockCard.x,
            y: winY + slideWrapper.y + dockCard.y,
            w: dockCard.width,
            h: dockCard.height
        };
    }

    function evaluateOverlap(json) {
        let clients;
        try { clients = JSON.parse(json); } catch (e) { return; }
        const mon = root.hyprMonitor;
        const wsId = (mon && mon.activeWorkspace) ? mon.activeWorkspace.id : null;
        if (wsId === null || !Array.isArray(clients)) return;
        const r = root.dockGlobalRect();
        let hit = false;
        for (const c of clients) {
            if (!c || !c.mapped || c.hidden || !c.workspace || c.workspace.id !== wsId) continue;
            if (c.fullscreen === 2 || c.fullscreen === 3) { hit = true; break; }
            const x = c.at[0], y = c.at[1], w = c.size[0], h = c.size[1];
            if (x < r.x + r.w && x + w > r.x && y < r.y + r.h && y + h > r.y) { hit = true; break; }
        }
        if (hit) {
            // Short confirmation delay: a window merely passing by doesn't flick the dock.
            if (!root.windowOverlaps && !overlapConfirm.running) overlapConfirm.start();
        } else {
            overlapConfirm.stop();
            root.windowOverlaps = false;
        }
    }

    Timer {
        id: overlapConfirm
        interval: 180
        onTriggered: root.windowOverlaps = true
    }

    Process {
        id: clientsProc
        property bool pending: false
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: if (root.isIntelli) root.evaluateOverlap(this.text)
        }
        onExited: if (pending) { pending = false; running = true; }
    }
    Timer {
        id: intelliDebounce
        interval: 80
        onTriggered: {
            if (!root.isIntelli) return;
            if (clientsProc.running) clientsProc.pending = true;
            else clientsProc.running = true;
        }
    }
    // Safety net for changes Hyprland emits no event for (dragging/resizing floats).
    Timer {
        interval: 1000
        repeat: true
        running: root.isIntelli && root.visible
        onTriggered: intelliDebounce.restart()
    }
    Connections {
        target: Hyprland
        enabled: root.isIntelli
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow": case "closewindow": case "movewindow": case "movewindowv2":
            case "workspace": case "workspacev2": case "fullscreen": case "changefloatingmode":
            case "activewindowv2": case "focusedmon": case "moveworkspace": case "moveworkspacev2":
                intelliDebounce.restart();
                break;
            }
        }
    }
    Component.onCompleted: if (root.isIntelli) intelliDebounce.restart()

    // ── Models (keyed by app id → delegates persist across window events) ─
    readonly property var entryById: {
        const m = {};
        for (const e of ApplicationManager.dockApps) m[e.id] = e;
        return m;
    }
    ScriptModel {
        id: pinnedModel
        values: ApplicationManager.dockApps.filter(e => e.pinned).map(e => e.id)
    }
    ScriptModel {
        id: runningModel
        values: ApplicationManager.dockApps.filter(e => !e.pinned).map(e => e.id)
    }

    // ── Magnification (shared by every slot) ────────────────────────────
    property string hoveredKey: ""
    property real pointerAlong: 0          // pointer position along the dock axis (dockLayout coords)
    readonly property real magMax: Theme.performanceTier === 0 ? 0.08 : 0.14
    property real magAmount: hoveredKey !== "" && !isMenuOpen ? 1 : 0
    Behavior on magAmount { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // 0..1 bell curve of the pointer's distance to a slot centre.
    function magnification(center) {
        if (root.magAmount <= 0.001) return 0;
        const d = root.pointerAlong - center;
        const sigma = root.slotLen * 0.85;
        return root.magAmount * Math.exp(-(d * d) / (2 * sigma * sigma));
    }
    function trackPointer(area, mouse) {
        const p = area.mapToItem(dockLayout, mouse.x, mouse.y);
        root.pointerAlong = root.isVertical ? p.y : p.x;
    }
    function setHovered(key, on) {
        if (on) root.hoveredKey = key;
        else if (root.hoveredKey === key) root.hoveredKey = "";
    }

    // ── Shared tooltip (one bubble that glides between icons) ────────────
    property Item tipOwner: null
    property string tipText: ""
    property string tipMeta: ""
    property bool tipShown: false
    property real tipAnchorX: 0
    property real tipAnchorY: 0

    function requestTip(owner, text, meta) {
        root.tipOwner = owner;
        root.tipText = text || "";
        root.tipMeta = meta || "";
        const p = owner.mapToItem(root.contentItem, owner.width / 2, owner.height / 2);
        root.tipAnchorX = p.x;
        root.tipAnchorY = p.y;
        tipGrace.stop();
        if (!root.tipShown) tipDelay.restart();
    }
    function releaseTip(owner) {
        if (root.tipOwner !== owner) return;
        root.tipOwner = null;
        tipDelay.stop();
        tipGrace.restart();
    }
    function hideTip(now) {
        tipDelay.stop();
        tipGrace.stop();
        root.tipOwner = null;
        if (now) root.tipShown = false;
        else tipGrace.restart();
    }
    Timer { id: tipDelay; interval: 380; onTriggered: if (root.tipOwner && !root.isMenuOpen) root.tipShown = true }
    Timer { id: tipGrace; interval: 120; onTriggered: if (!root.tipOwner) root.tipShown = false }

    // ── Reveal strip on the docked edge ──────────────────────────────────
    Item {
        id: triggerStrip
        x: root.edge === "right" ? parent.width - width : 0
        y: root.edge === "bottom" ? parent.height - height : 0
        width: !root.hidesItself ? 0 : (root.isVertical ? 2 : parent.width)
        height: !root.hidesItself ? 0 : (root.isVertical ? parent.height : 2)

        HoverHandler {
            id: triggerHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    if (!root.dockVisible) showTimer.restart();
                } else {
                    showTimer.stop();
                    if (root.hidesItself && !root.dockHovered && !root.isMenuOpen) hideTimer.restart();
                }
            }
        }
    }

    // ── Hit box: the card plus the gap to the edge ───────────────────────
    Item {
        id: dockHitBox
        x: root.edge === "left" ? 0
           : (root.edge === "right" ? slideWrapper.x : Math.round((parent.width - width) / 2))
        y: root.isVertical ? Math.round((parent.height - height) / 2) : slideWrapper.y
        width: root.isVertical ? (root.edge === "left" ? slideWrapper.x + slideWrapper.width : parent.width - slideWrapper.x)
                               : slideWrapper.width
        height: root.isVertical ? slideWrapper.height : parent.height - slideWrapper.y

        HoverHandler {
            id: dockHoverHandler
            onHoveredChanged: {
                root.dockHovered = hovered;
                if (hovered) {
                    showTimer.stop();
                    hideTimer.stop();
                    if (root.hidesItself) root.revealed = true;
                } else if (root.hidesItself && !triggerHover.hovered && !root.isMenuOpen) {
                    hideTimer.restart();
                }
            }
        }
    }

    // ── Slide container ──────────────────────────────────────────────────
    Item {
        id: slideWrapper
        width: root.isVertical ? root.dockH + 12 : dockCard.width + 24
        height: root.isVertical ? dockCard.height + 24 : root.dockH + 12
        x: root.edge === "left" ? 8 : (root.edge === "right" ? parent.width - width - 8 : Math.round((parent.width - width) / 2))
        y: root.isVertical ? Math.round((parent.height - height) / 2) : parent.height - height - 8

        // Slide fully past the edge; opacity trails slightly so blur/shadow never linger.
        readonly property real hiddenOffset: root.dockVisible ? 0 : root.dockH + 30
        opacity: root.dockVisible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.dockVisible ? 180 : 260; easing.type: Easing.OutCubic }
        }
        transform: Translate {
            x: -root.inwardX * slideWrapper.hiddenOffset
            y: -root.inwardY * slideWrapper.hiddenOffset
            Behavior on x { NumberAnimation { duration: root.dockVisible ? 300 : 240; easing.type: root.dockVisible ? Easing.OutQuint : Easing.InOutCubic } }
            Behavior on y { NumberAnimation { duration: root.dockVisible ? 300 : 240; easing.type: root.dockVisible ? Easing.OutQuint : Easing.InOutCubic } }
        }

        // Ambient shadow
        Rectangle {
            anchors.fill: dockCard
            anchors.topMargin: 4
            anchors.bottomMargin: -4
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: root.cardRadius + 2
            color: Theme.dockShadow
            visible: Theme.enableShadows
        }

        // ── Glass card ───────────────────────────────────────────────────
        Rectangle {
            id: dockCard
            width: root.isVertical ? root.dockH : dockLayout.implicitWidth + 20
            height: root.isVertical ? dockLayout.implicitHeight + 20 : root.dockH
            x: root.edge === "left" ? 6 : (root.edge === "right" ? parent.width - width - 6 : Math.round((parent.width - width) / 2))
            y: root.isVertical ? Math.round((parent.height - height) / 2) : parent.height - height - 6

            // Translucent when blur is on (Hyprland blurs the layer behind it).
            color: Theme.dockGlass
            radius: root.cardRadius
            border.color: Theme.dockBorder
            border.width: 1
            Behavior on width { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

            // Inner sheen rim
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                color: "transparent"
                border.color: Theme.dockGlassSheen
                border.width: 1
            }

            // Empty dock area: a click dismisses an open app menu. (No wheel binding: scrolling
            // over the dock must never open the App Drawer — Super or the Apps button do.)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: dockContextMenu.hide()
            }

            GridLayout {
                id: dockLayout
                anchors.centerIn: parent
                flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: root.slotGap
                columnSpacing: root.slotGap
                // Arabic: a horizontal dock starts from the right, like the rest of the shell.
                LayoutMirroring.enabled: I18n.isRTL && !root.isVertical
                LayoutMirroring.childrenInherit: true

                // 0 · Apps button (opens the Start-style App Drawer)
                DockSlot {
                    isLauncher: true
                    appKey: "__apps__"
                }

                // 1 · Pinned favourites
                Repeater {
                    model: pinnedModel
                    delegate: DockSlot {
                        required property string modelData
                        appKey: modelData
                        entry: root.entryById[modelData] || null
                    }
                }

                // Faint separator: pinned | running (only when both groups exist)
                Rectangle {
                    visible: pinnedModel.values.length > 0 && runningModel.values.length > 0
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.isVertical ? Math.round(root.iconSz * 0.55) : 1
                    Layout.preferredHeight: root.isVertical ? 1 : Math.round(root.iconSz * 0.55)
                    color: Theme.dockDividerFaint
                }

                // 2 · Running, not pinned
                Repeater {
                    model: runningModel
                    delegate: DockSlot {
                        required property string modelData
                        appKey: modelData
                        entry: root.entryById[modelData] || null
                    }
                }

                // Divider before the trash
                Rectangle {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.isVertical ? Math.round(root.iconSz * 0.66) : 1
                    Layout.preferredHeight: root.isVertical ? 1 : Math.round(root.iconSz * 0.66)
                    Layout.leftMargin: root.isVertical ? 0 : 2
                    Layout.rightMargin: root.isVertical ? 0 : 2
                    Layout.topMargin: root.isVertical ? 2 : 0
                    Layout.bottomMargin: root.isVertical ? 2 : 0
                    color: Theme.dockDivider
                }

                // 3 · Trash
                DockSlot {
                    isTrash: true
                    appKey: "__trash__"
                }
            }
        }
    }

    // ── Tooltip bubble ───────────────────────────────────────────────────
    Rectangle {
        id: tip
        readonly property real cardLeft: slideWrapper.x + dockCard.x
        readonly property real cardTop: slideWrapper.y + dockCard.y

        width: Math.min(tipRow.implicitWidth + 22, 300)
        height: tipRow.implicitHeight + 10
        radius: Math.min(height / 2, Theme.radiusMedium)
        color: Theme.dockTooltipBg
        border.color: Theme.dockTooltipBorder
        border.width: 1
        z: 50

        x: root.edge === "left" ? tip.cardLeft + dockCard.width + 12
         : root.edge === "right" ? tip.cardLeft - width - 12
         : Math.max(8, Math.min(root.width - width - 8, Math.round(root.tipAnchorX - width / 2)))
        y: root.isVertical ? Math.max(8, Math.min(root.height - height - 8, Math.round(root.tipAnchorY - height / 2)))
                           : tip.cardTop - height - 14
        // Glide between icons once visible; appear in place otherwise.
        Behavior on x { enabled: tip.opacity > 0.5 && !root.isVertical; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: tip.opacity > 0.5 && root.isVertical; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        opacity: root.tipShown && root.dockVisible ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: root.tipShown ? 0 : 4 * -root.inwardX
            y: root.tipShown ? 0 : 4 * -root.inwardY
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        Row {
            id: tipRow
            anchors.centerIn: parent
            spacing: 8
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            Text {
                id: tipName
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220)
                text: NotificationManager.bidi(root.tipText)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                color: Theme.notchText
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.DemiBold
                renderType: Theme.renderType
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.tipMeta.length > 0
                text: NotificationManager.bidi(root.tipMeta)
                textFormat: Text.PlainText
                color: Theme.notchTextMeta
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                renderType: Theme.renderType
            }
        }
    }

    // Shared app menu (same component as the App Drawer). The dock is part of its focus
    // grab so clicking another icon while it's open still works.
    AppContextMenu {
        id: dockContextMenu
        hostWindow: root
        grabWindows: [ root ]
    }

    // ═════════════════════════════════════════════════════════════════════
    // One dock slot (app or trash). Fixed size; all motion is transform-only.
    // ═════════════════════════════════════════════════════════════════════
    component DockSlot: Item {
        id: slot

        property string appKey: ""
        property var entry: null
        property bool isTrash: false
        property bool isLauncher: false
        readonly property bool isApp: !isTrash && !isLauncher

        // The Apps button reuses the "running + focused" indicator while the drawer is open.
        readonly property bool running: isLauncher ? ShellState.appDrawerOpen : (isApp && Boolean(entry && entry.running))
        readonly property bool active: isLauncher ? ShellState.appDrawerOpen : (isApp && Boolean(entry && entry.isActive))
        readonly property bool urgent: isApp && Boolean(entry && entry.urgent)
        readonly property bool allMinimized: isApp && Boolean(entry && entry.allMinimized)
        readonly property int windowCount: (isApp && entry && entry.windowCount) ? entry.windowCount : 0
        property bool launching: false

        implicitWidth: root.isVertical ? root.dockH : root.slotLen
        implicitHeight: root.isVertical ? root.slotLen : root.dockH
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.alignment: Qt.AlignCenter
        z: root.hoveredKey === appKey ? 10 : 1

        // Centre along the dock axis → bell-curve magnification (pure function of the
        // pointer, so there's nothing to jitter).
        readonly property real axisCenter: root.isVertical ? y + height / 2 : x + width / 2
        readonly property real mag: root.magnification(axisCenter)

        onRunningChanged: if (running) launching = false
        Timer { id: launchTimeout; interval: 6000; onTriggered: slot.launching = false }

        function tooltipMeta() {
            if (!slot.isApp) return "";
            if (slot.allMinimized) return I18n.tr("dock_minimized");
            if (slot.windowCount > 1) return I18n.windowsCount(slot.windowCount);
            return "";
        }

        // Focused-app well (Windows 11 style tonal plate)
        Rectangle {
            anchors.centerIn: parent
            width: root.iconSz + 8
            height: root.iconSz + 8
            radius: Math.min(width / 2, Math.round(root.cardRadius * 0.62))
            color: Theme.dockActiveWell
            opacity: slot.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Easing.OutCubic } }
        }

        // ── Icon (magnify + lift + press + launch bounce) ────────────────
        Item {
            id: iconBox
            anchors.centerIn: parent
            width: root.iconSz
            height: root.iconSz

            property real pressScale: slotMouse.pressed ? 0.90 : 1.0
            Behavior on pressScale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            property real bounce: 0

            transformOrigin: root.edge === "left" ? Item.Left : (root.edge === "right" ? Item.Right : Item.Bottom)
            scale: (1 + root.magMax * slot.mag) * pressScale
            transform: Translate {
                x: root.inwardX * (3 * slot.mag + iconBox.bounce)
                y: root.inwardY * (3 * slot.mag + iconBox.bounce)
            }
            opacity: slot.allMinimized ? 0.72 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

            SequentialAnimation {
                id: bounceAnim
                NumberAnimation { target: iconBox; property: "bounce"; to: 10; duration: 200; easing.type: Easing.OutQuad }
                NumberAnimation { target: iconBox; property: "bounce"; to: 0; duration: 380; easing.type: Easing.OutBounce }
            }

            // Apps button: monochrome grid glyph on a tile the size of an app icon
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(root.iconSz * 0.06)
                visible: slot.isLauncher
                radius: Math.round(width * 0.26)
                color: Theme.notchSurface
                border.color: Theme.notchBorder
                border.width: 1
                // 3×3 dot grid drawn in QML: theme-independent and always monochrome.
                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    readonly property int cell: Math.max(4, Math.round(root.iconSz * 0.10))
                    spacing: Math.max(3, Math.round(root.iconSz * 0.065))
                    Repeater {
                        model: 9
                        Rectangle {
                            width: parent.cell
                            height: parent.cell
                            radius: Math.round(parent.cell * 0.3)
                            color: Theme.notchText
                        }
                    }
                }
            }
            AppIcon {
                anchors.fill: parent
                visible: slot.isApp
                iconSize: root.iconSz
                source: slot.entry ? slot.entry.icon : ""
            }
            Image {
                anchors.centerIn: parent
                visible: slot.isTrash
                width: Math.round(parent.width * 0.92)
                height: width
                source: slot.isTrash ? "file://" + ConfigManager.projectDir + "/assets/icons/apps/deloway-trash.svg" : ""
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true
                fillMode: Image.PreserveAspectFit
            }
        }

        // ── Running indicator: pill hugging the docked edge ──────────────
        //   focused      long bright pill + soft halo
        //   running      short dim pill (a bit longer with several windows)
        //   minimized    same, faded
        //   urgent       6px pulsing danger dot (semantic colour, ≤ 8px)
        //   launching    breathing dim dot until the first window maps
        Item {
            id: indicator
            visible: !slot.isTrash && ConfigManager.showUnderline && (slot.running || slot.launching)
            readonly property real len: slot.urgent ? 6
                : slot.active ? Math.round(root.iconSz * 0.38)
                : (slot.windowCount > 1 ? 11 : 5)
            readonly property real thick: slot.urgent ? 6 : 3
            // Anchored against the edge, centred along the axis.
            width: root.isVertical ? thick : len
            height: root.isVertical ? len : thick
            x: root.edge === "left" ? 3 : (root.edge === "right" ? parent.width - width - 3 : Math.round((parent.width - width) / 2))
            y: root.isVertical ? Math.round((parent.height - height) / 2) : parent.height - height - 3
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            opacity: slot.allMinimized ? 0.45 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }

            // Halo (two soft layers read as a glow without a blur pass)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + (root.isVertical ? 6 : 12)
                height: parent.height + (root.isVertical ? 12 : 6)
                radius: Math.min(width, height) / 2
                color: Theme.dockIndicatorHalo
                opacity: slot.active && !slot.urgent ? 0.55 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + (root.isVertical ? 3 : 6)
                height: parent.height + (root.isVertical ? 6 : 3)
                radius: Math.min(width, height) / 2
                color: Theme.dockIndicatorHalo
                opacity: slot.active && !slot.urgent ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motionBase } }
            }
            Rectangle {
                id: pill
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                color: slot.urgent ? Theme.colors.urgent : (slot.active ? Theme.dockIndicator : Theme.dockIndicatorIdle)
                Behavior on color { ColorAnimation { duration: Theme.motionBase } }

                SequentialAnimation on opacity {
                    running: slot.urgent || (slot.launching && !slot.running)
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.35; duration: 520; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
                }
            }
        }

        // ── Input ────────────────────────────────────────────────────────
        // Extends over half the gap on each side so hover never drops between icons.
        MouseArea {
            id: slotMouse
            anchors.fill: parent
            anchors.leftMargin: root.isVertical ? 0 : -root.slotGap / 2
            anchors.rightMargin: root.isVertical ? 0 : -root.slotGap / 2
            anchors.topMargin: root.isVertical ? -root.slotGap / 2 : 0
            anchors.bottomMargin: root.isVertical ? -root.slotGap / 2 : 0
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onContainsMouseChanged: {
                root.setHovered(slot.appKey, containsMouse);
                if (containsMouse) {
                    const name = slot.isTrash ? I18n.tr("trash_title")
                               : slot.isLauncher ? I18n.tr("app_menu_title")
                               : (slot.entry ? (slot.entry.name || slot.entry.id) : "");
                    root.requestTip(slot, name, slot.tooltipMeta());
                } else {
                    root.releaseTip(slot);
                }
            }
            onPositionChanged: (mouse) => root.trackPointer(slotMouse, mouse)
            onEntered: root.trackPointer(slotMouse, { x: mouseX, y: mouseY })
            onPressed: root.hideTip(true)

            onClicked: (mouse) => {
                if (slot.isTrash) {
                    if (mouse.button === Qt.LeftButton) Quickshell.execDetached(["xdg-open", "trash://"]);
                    return;
                }
                if (slot.isLauncher) {
                    dockContextMenu.hide();
                    if (mouse.button === Qt.LeftButton) ShellState.toggleAppDrawer();
                    return;
                }
                if (!slot.entry) return;
                if (mouse.button === Qt.RightButton) {
                    dockContextMenu.openFor(slot.entry, slot,
                        root.edge === "left" ? "right" : (root.edge === "right" ? "left" : "above"));
                    return;
                }
                dockContextMenu.hide();
                if (mouse.button === Qt.MiddleButton) {
                    ApplicationManager.newWindow(slot.entry);
                    slot.launching = !slot.running;
                    if (slot.launching) launchTimeout.restart();
                    bounceAnim.restart();
                    return;
                }
                if (!slot.running) {
                    slot.launching = true;
                    launchTimeout.restart();
                    bounceAnim.restart();
                }
                ApplicationManager.clickDockApp(slot.entry);
            }
        }

        // Keep the tooltip text live (e.g. window count changes while hovered).
        onEntryChanged: {
            if (root.tipOwner === slot && slot.entry)
                root.tipMeta = slot.tooltipMeta();
        }
        Component.onDestruction: {
            if (root.hoveredKey === slot.appKey) root.hoveredKey = "";
            if (root.tipOwner === slot) root.hideTip(true);
        }
    }
}
