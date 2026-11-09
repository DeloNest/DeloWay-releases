import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Overview — Mission Control / Workspace Overview for DeloWay
// Event-driven: Hyprland.toplevels + Hyprland.workspaces
// OLED identity: Strict Monochrome OLED, high luminance contrast, Theme tokens only.
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

    WlrLayershell.namespace: "deloway:overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: ShellState.overviewOpen || backdrop.opacity > 0.01

    // ── Live Hyprland Data ──────────────────────────────────────────────────
    readonly property var hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : (Hyprland.focusedMonitor || null)
    readonly property var hlToplevels: Hyprland.toplevels.values
    readonly property var activeWsObj: hyprMonitor ? hyprMonitor.activeWorkspace : (Hyprland.focusedWorkspace || null)
    readonly property int activeWsId:  activeWsObj ? activeWsObj.id : 1

    property int selectedWorkspaceId: activeWsId

    // Synchronize selected workspace when overview opens
    Connections {
        target: ShellState
        function onOverviewOpenChanged() {
            if (ShellState.overviewOpen) {
                root.selectedWorkspaceId = root.activeWsId;
                root.draggedAddress = "";
                root.hoveredDropWsId = -1;
            }
        }
    }

    // ── Drag & Drop State ───────────────────────────────────────────────────
    property string draggedAddress: ""
    property string draggedTitle: ""
    property string draggedAppId: ""
    property int hoveredDropWsId: -1

    // ── Workspaces Map ──────────────────────────────────────────────────────
    readonly property int staticWsCount: ConfigManager.workspacesCount || 5

    // Map: wsId (int) → list of toplevel items
    readonly property var toplevelsByWs: {
        const list = root.hlToplevels;
        const map = {};
        for (let i = 0; i < list.length; i++) {
            const hl = list[i];
            if (!hl) continue;

            let wid = 1;
            if (hl.workspace && hl.workspace.id !== undefined) {
                wid = hl.workspace.id;
            } else if (hl.lastIpcObject && hl.lastIpcObject.workspace && hl.lastIpcObject.workspace.id !== undefined) {
                wid = hl.lastIpcObject.workspace.id;
            }
            if (wid <= 0) continue;

            let appId = "";
            if (hl.wayland && hl.wayland.appId) {
                appId = hl.wayland.appId;
            } else if (hl.lastIpcObject) {
                appId = hl.lastIpcObject.class || hl.lastIpcObject.initialClass || "";
            }

            // Wayland Toplevel handle for ScreencopyView live capture
            let tl = hl.wayland || null;
            if (!tl && typeof ToplevelManager !== "undefined" && ToplevelManager.toplevels) {
                const tmList = ToplevelManager.toplevels.values;
                for (let j = 0; j < tmList.length; j++) {
                    const candidate = tmList[j];
                    if (candidate && (candidate.appId === appId || candidate.title === hl.title)) {
                        tl = candidate;
                        break;
                    }
                }
            }

            let posX = 0;
            let posY = 0;
            if (hl.lastIpcObject && hl.lastIpcObject.at) {
                posX = hl.lastIpcObject.at[0] || 0;
                posY = hl.lastIpcObject.at[1] || 0;
            } else if (hl.wayland && hl.wayland.geometry) {
                posX = hl.wayland.geometry.x || 0;
                posY = hl.wayland.geometry.y || 0;
            }

            const item = {
                appId: appId,
                title: hl.title || "",
                address: hl.address || "",
                activated: hl.activated || false,
                workspaceId: wid,
                wayland: tl,
                raw: hl,
                x: posX,
                y: posY
            };

            if (!map[wid]) map[wid] = [];
            map[wid].push(item);
        }

        // Sort windows in each workspace strictly by real physical screen coordinates
        for (const k of Object.keys(map)) {
            map[k].sort((a, b) => {
                if (Math.abs(a.y - b.y) > 120) return a.y - b.y;
                return a.x - b.x;
            });
        }
        return map;
    }

    // List of all workspaces to display (1..staticWsCount + any extra active workspaces)
    readonly property var displayWsIds: {
        const ids = [];
        for (let n = 1; n <= root.staticWsCount; n++) ids.push(n);

        const map = root.toplevelsByWs;
        for (const k of Object.keys(map)) {
            const wid = parseInt(k);
            if (wid > root.staticWsCount && !ids.includes(wid)) {
                ids.push(wid);
            }
        }
        if (root.activeWsId > root.staticWsCount && !ids.includes(root.activeWsId)) {
            ids.push(root.activeWsId);
        }
        ids.sort((a, b) => a - b);
        return ids;
    }

    // Windows belonging to the currently selected workspace
    readonly property var currentWindows: root.toplevelsByWs[root.selectedWorkspaceId] || []

    // ── Shortcuts ───────────────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        enabled: ShellState.overviewOpen
        onActivated: ShellState.closeOverview()
    }

    Shortcut {
        sequence: "Super+Tab"
        enabled: ShellState.overviewOpen
        onActivated: ShellState.toggleOverview()
    }

    Shortcut {
        sequence: "Super+O"
        enabled: ShellState.overviewOpen
        onActivated: ShellState.toggleOverview()
    }

    Shortcut {
        sequence: "Left"
        enabled: ShellState.overviewOpen && root.draggedAddress === ""
        onActivated: {
            const ids = root.displayWsIds;
            const idx = ids.indexOf(root.selectedWorkspaceId);
            if (idx > 0) root.selectedWorkspaceId = ids[idx - 1];
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: ShellState.overviewOpen && root.draggedAddress === ""
        onActivated: {
            const ids = root.displayWsIds;
            const idx = ids.indexOf(root.selectedWorkspaceId);
            if (idx >= 0 && idx < ids.length - 1) root.selectedWorkspaceId = ids[idx + 1];
        }
    }

    // ── Fullscreen Backdrop (Transparent - Zero Black Background) ───────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "transparent"
        opacity: ShellState.overviewOpen ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.closeOverview()
        }
    }

    // ── Main Content Container ──────────────────────────────────────────────
    Item {
        id: contentContainer
        anchors.fill: parent
        opacity: ShellState.overviewOpen ? 1.0 : 0.0
        scale: ShellState.overviewOpen ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }
        }

        // Layout direction mirroring for RTL
        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 52
            width: Math.min(parent.width - 64, 1500)
            spacing: 20

            // ═══════════════════════════════════════════════════════════════
            //  1. TOP SECTION: WORKSPACE CAROUSEL STRIP
            // ═══════════════════════════════════════════════════════════════
            Row {
                id: wsStrip
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                // Always LTR (Workspace 1 on the left, matching the center capsule)
                LayoutMirroring.enabled: false

                Repeater {
                    model: root.displayWsIds

                    Rectangle {
                        id: wsCard
                        readonly property int wsId: modelData
                        readonly property bool isSelected: root.selectedWorkspaceId === wsId
                        readonly property bool isLiveActive: root.activeWsId === wsId
                        readonly property bool isDropTarget: root.hoveredDropWsId === wsId
                        readonly property var wsWindows: root.toplevelsByWs[wsId] || []

                        width: 220
                        height: 126
                        radius: Theme.radiusMedium

                        // Adaptive Theme Card Styling (Glass translucent / OLED Dark / Crisp Light)
                        color: wsCard.isDropTarget
                            ? Theme.notchSurfaceActive
                            : (wsCard.isSelected
                                ? (Theme.isGlass ? Qt.rgba(0.14, 0.14, 0.14, 0.94) : Theme.notchSurfaceActive)
                                : (wsMouse.containsMouse
                                    ? (Theme.isGlass ? Qt.rgba(0.11, 0.11, 0.11, 0.92) : Theme.notchSurfaceHover)
                                    : (Theme.isGlass ? Qt.rgba(0.08, 0.08, 0.08, 0.88) : Theme.notchBackground)))
                        border.color: (wsCard.isSelected || wsCard.isDropTarget)
                            ? Theme.colors.borderHighlight
                            : (wsCard.isLiveActive
                                ? Theme.notchTextSecondary
                                : (Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder))
                        border.width: (isSelected || isDropTarget) ? 2 : 1

                        scale: isDropTarget ? 1.06 : (wsMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            // Workspace Header (Badge & Title)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                LayoutMirroring.enabled: false

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: Theme.radiusSmall
                                    color: wsCard.isSelected ? Theme.notchText : Theme.notchSurface
                                    border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: I18n.number(wsCard.wsId)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        font.bold: true
                                        color: wsCard.isSelected ? (Theme.isLight ? "#ffffff" : "#000000") : Theme.notchText
                                    }
                                }

                                Text {
                                    text: I18n.tr("overview_workspace")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.bold: wsCard.isSelected
                                    color: wsCard.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                // Active Live Indicator Dot
                                Rectangle {
                                    visible: wsCard.isLiveActive
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.notchText
                                }
                            }

                            // Miniature Workspace Canvas Preview (Mini Windows)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusSmall
                                color: Theme.isGlass ? Qt.rgba(0.04, 0.04, 0.04, 0.70) : Theme.notchSurface
                                border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                                border.width: 1
                                clip: true

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    LayoutMirroring.enabled: false

                                    Repeater {
                                        model: Math.min(wsCard.wsWindows.length, 4)

                                        Rectangle {
                                            id: miniWinBox
                                            readonly property var miniWin: wsCard.wsWindows[index]
                                            width: wsCard.wsWindows.length === 1 ? 84 : (wsCard.wsWindows.length === 2 ? 64 : 40)
                                            height: wsCard.wsWindows.length === 1 ? 52 : (wsCard.wsWindows.length === 2 ? 44 : 32)
                                            radius: Theme.radiusSmall
                                            color: Theme.notchSurfaceElevated
                                            border.color: Theme.notchBorderHighlight
                                            border.width: 1
                                            clip: true

                                            // Fallback App Icon
                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: miniWin ? root.resolveIcon(miniWin.appId) : "window-new-symbolic"
                                                iconSize: wsCard.wsWindows.length === 1 ? 20 : 14
                                                iconColor: Theme.notchText
                                                visible: !miniScreencopy.hasContent
                                            }

                                            // Miniature Screencopy Live Capture
                                            ScreencopyView {
                                                id: miniScreencopy
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                captureSource: miniWin ? (miniWin.wayland || miniWin.raw) : null
                                                live: ShellState.overviewOpen
                                                paintCursor: false
                                                visible: hasContent
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: wsCard.wsWindows.length === 0
                                    text: "—"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize(14)
                                    color: Theme.notchTextSecondary
                                }
                            }
                        }

                        // Mouse interaction & Drop Zone handling
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.selectedWorkspaceId = wsCard.wsId;
                            }

                            onDoubleClicked: {
                                Hyprland.dispatch("workspace " + wsCard.wsId);
                                ShellState.closeOverview();
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            //  2. CENTER SECTION: WINDOW EXPOSÉ CANVAS
            // ═══════════════════════════════════════════════════════════════
            Item {
                id: windowCanvas
                Layout.fillWidth: true
                implicitHeight: root.currentWindows.length === 0 ? emptyStateCol.implicitHeight + 40 : windowFlow.implicitHeight
                Layout.alignment: Qt.AlignHCenter

                // Empty State if no windows
                ColumnLayout {
                    id: emptyStateCol
                    anchors.centerIn: parent
                    visible: root.currentWindows.length === 0
                    spacing: 16

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 64
                        height: 64
                        radius: 32
                        color: Theme.isGlass ? Theme.capsuleFill : Theme.notchBackground
                        border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                        border.width: 1

                        SymbolicIcon {
                            anchors.centerIn: parent
                            source: "window-new-symbolic"
                            iconSize: 28
                            iconColor: Theme.notchTextSecondary
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: I18n.tr("overview_no_windows")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(15)
                        color: Theme.notchTextSecondary
                    }
                }

                // Grid of Windows
                Flow {
                    id: windowFlow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    LayoutMirroring.enabled: false
                    width: {
                        const n = root.currentWindows.length;
                        if (n <= 1) return 640;
                        if (n === 2) return 560 * 2 + 24;
                        return Math.min(parent.width - 64, Math.min(n, 3) * 420 + (Math.min(n, 3) - 1) * 20);
                    }
                    spacing: 20
                    visible: root.currentWindows.length > 0

                    Repeater {
                        model: root.currentWindows

                        Rectangle {
                            id: windowCard
                            readonly property var winData: modelData
                            readonly property bool isActivated: winData ? winData.activated : false
                            readonly property string winAddress: winData ? winData.address : ""
                            readonly property string winAppId: winData ? winData.appId : ""
                            readonly property string winTitle: winData ? winData.title : ""
                            readonly property var winWayland: winData ? winData.wayland : null
                            readonly property bool isBeingDragged: root.draggedAddress === winAddress

                            // Responsive sizing based on window count
                            width: root.currentWindows.length === 1 ? 640 : (root.currentWindows.length === 2 ? 560 : (root.currentWindows.length <= 4 ? 420 : 360))
                            height: root.currentWindows.length === 1 ? 420 : (root.currentWindows.length === 2 ? 360 : (root.currentWindows.length <= 4 ? 280 : 240))
                            radius: Theme.radiusLarge

                            color: Theme.isGlass ? Qt.rgba(0.08, 0.08, 0.08, 0.88) : Theme.notchBackground
                            border.color: (cardMouse.containsMouse || isActivated)
                                ? Theme.colors.borderHighlight
                                : (Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder)
                            border.width: (cardMouse.containsMouse || isActivated) ? 2 : 1

                            opacity: isBeingDragged ? 0.35 : 1.0
                            scale: cardMouse.containsMouse && !isBeingDragged ? 1.02 : 1.0

                            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // ── Window Header Bar ──
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // App Icon
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: Theme.radiusSmall
                                        color: Theme.notchSurface
                                        border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                                        border.width: 1

                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            source: root.resolveIcon(windowCard.winAppId)
                                            iconSize: 16
                                            iconColor: Theme.notchText
                                        }
                                    }

                                    // Window Title
                                    Text {
                                        Layout.fillWidth: true
                                        text: windowCard.winTitle || windowCard.winAppId || "Window"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize(13)
                                        font.bold: true
                                        color: Theme.notchText
                                        elide: Text.ElideRight
                                    }

                                    // Close Button (Destructive Semantic Action)
                                    Rectangle {
                                        id: closeBtn
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: closeMouse.containsMouse ? Theme.colors.urgent : Theme.notchSurface
                                        border.color: closeMouse.containsMouse ? Theme.colors.urgent : (Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder)
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(11)
                                            font.bold: true
                                            color: closeMouse.containsMouse ? "#ffffff" : Theme.notchText
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (windowCard.winAddress) {
                                                    Hyprland.dispatch("closewindow address:" + windowCard.winAddress);
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Window Body Mockup / Live Preview ──
                                Rectangle {
                                    id: previewBox
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.radiusMedium
                                    color: cardMouse.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                                    border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                                    border.width: 1
                                    clip: true

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    // Fallback UI when screencopy has no content yet
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 12
                                        visible: !screencopy.hasContent

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 52
                                            height: 52
                                            radius: Theme.radiusMedium
                                            color: Theme.isGlass ? Qt.rgba(1, 1, 1, 0.10) : (Theme.isDark ? "#000000" : "#ffffff")
                                            border.color: Theme.colors.borderHighlight
                                            border.width: 1

                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: root.resolveIcon(windowCard.winAppId)
                                                iconSize: 28
                                                iconColor: Theme.notchText
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: windowCard.winAppId
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize(12)
                                            color: Theme.notchTextSecondary
                                        }
                                    }

                                    // Live Application Window Content Screencopy
                                    ScreencopyView {
                                        id: screencopy
                                        anchors.centerIn: parent
                                        width: {
                                            if (!hasContent || sourceSize.width <= 0 || sourceSize.height <= 0) return parent.width;
                                            const aspect = sourceSize.width / sourceSize.height;
                                            const containerAspect = parent.width / Math.max(1, parent.height);
                                            return (aspect > containerAspect) ? parent.width : Math.min(parent.width, parent.height * aspect);
                                        }
                                        height: {
                                            if (!hasContent || sourceSize.width <= 0 || sourceSize.height <= 0) return parent.height;
                                            const aspect = sourceSize.width / sourceSize.height;
                                            const containerAspect = parent.width / Math.max(1, parent.height);
                                            return (aspect > containerAspect) ? Math.min(parent.height, parent.width / aspect) : parent.height;
                                        }
                                        captureSource: windowCard.winWayland || (windowCard.winData ? windowCard.winData.raw : null)
                                        live: ShellState.overviewOpen
                                        paintCursor: false
                                        visible: hasContent
                                    }
                                }
                            }

                            // Card Interaction & Drag To Workspace
                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.draggedAddress !== "" ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                property real startX: 0
                                property real startY: 0
                                property bool isDragging: false

                                onPressed: (mouse) => {
                                    startX = mouse.x;
                                    startY = mouse.y;
                                    isDragging = false;
                                }

                                onPositionChanged: (mouse) => {
                                    if (!pressed) return;
                                    const dx = mouse.x - startX;
                                    const dy = mouse.y - startY;
                                    if (!isDragging && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
                                        isDragging = true;
                                        root.draggedAddress = windowCard.winAddress;
                                        root.draggedTitle = windowCard.winTitle;
                                        root.draggedAppId = windowCard.winAppId;
                                    }

                                    if (isDragging) {
                                        // Update drag ghost coordinates
                                        const globalPt = mapToItem(root.contentItem, mouse.x, mouse.y);
                                        dragGhost.x = globalPt.x - dragGhost.width / 2;
                                        dragGhost.y = globalPt.y - dragGhost.height / 2;

                                        // Check if hovering over any workspace card
                                        root.checkDropTarget(globalPt.x, globalPt.y);
                                    }
                                }

                                onReleased: {
                                    if (isDragging) {
                                        if (root.hoveredDropWsId > 0 && root.hoveredDropWsId !== root.selectedWorkspaceId) {
                                            Hyprland.dispatch("movetoworkspacesilent " + root.hoveredDropWsId + ",address:" + windowCard.winAddress);
                                        }
                                        root.draggedAddress = "";
                                        root.hoveredDropWsId = -1;
                                        isDragging = false;
                                    } else {
                                        // Normal click: focus window and close overview
                                        if (windowCard.winAddress) {
                                            Hyprland.dispatch("focuswindow address:" + windowCard.winAddress);
                                            ShellState.closeOverview();
                                        }
                                    }
                                }

                                onCanceled: {
                                    root.draggedAddress = "";
                                    root.hoveredDropWsId = -1;
                                    isDragging = false;
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            //  3. BOTTOM SECTION: NAVIGATION HINTS CAPSULE
            // ═══════════════════════════════════════════════════════════════
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: hintRow.implicitWidth + 32
                implicitHeight: 40
                radius: 20
                color: Theme.isGlass ? Theme.capsuleFill : Theme.notchBackground
                border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                border.width: 1

                RowLayout {
                    id: hintRow
                    anchors.centerIn: parent
                    spacing: 12

                    SymbolicIcon {
                        source: "help-about-symbolic"
                        iconSize: 14
                        iconColor: Theme.notchTextSecondary
                    }

                    Text {
                        text: I18n.tr("overview_hint")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize(12)
                        color: Theme.notchTextSecondary
                    }

                    Rectangle {
                        width: 32
                        height: 20
                        radius: 4
                        color: Theme.notchSurface
                        border.color: Theme.isGlass ? Theme.capsuleBorder : Theme.notchBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.bold: true
                            color: Theme.notchText
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        //  4. FLOATING DRAG GHOST (While dragging window card)
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            id: dragGhost
            visible: root.draggedAddress !== ""
            width: 220
            height: 120
            radius: Theme.radiusMedium
            color: Theme.isGlass ? Qt.rgba(0.12, 0.12, 0.12, 0.85) : Theme.notchSurfaceHover
            border.color: Theme.colors.borderHighlight
            border.width: 2
            z: 999
            opacity: 0.9

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                SymbolicIcon {
                    Layout.alignment: Qt.AlignHCenter
                    source: root.resolveIcon(root.draggedAppId)
                    iconSize: 28
                    iconColor: Theme.notchText
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 190
                    text: root.draggedTitle || root.draggedAppId
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize(12)
                    color: Theme.notchText
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── Helper Methods ──────────────────────────────────────────────────────
    function resolveIcon(appId) {
        if (!appId) return "application-x-executable-symbolic";
        const app = ApplicationManager.findApp(appId);
        if (app && app.icon) return app.icon;
        return IconResolver.resolve(appId) || "application-x-executable-symbolic";
    }

    // Hit-testing global point against workspace cards in the carousel strip
    function checkDropTarget(globalX, globalY) {
        // Strip is in top area (y between ~40 and ~190)
        if (globalY < 40 || globalY > 190) {
            root.hoveredDropWsId = -1;
            return;
        }

        // Check horizontal position relative to workspace cards
        const ids = root.displayWsIds;
        const cardW = 220;
        const cardSpacing = 16;
        const totalW = ids.length * cardW + (ids.length - 1) * cardSpacing;
        const startX = (root.width - totalW) / 2;

        if (globalX >= startX && globalX <= startX + totalW) {
            const relX = globalX - startX;
            const index = Math.floor(relX / (cardW + cardSpacing));
            if (index >= 0 && index < ids.length) {
                const offsetInSlot = relX - index * (cardW + cardSpacing);
                if (offsetInSlot <= cardW) {
                    root.hoveredDropWsId = ids[index];
                    return;
                }
            }
        }
        root.hoveredDropWsId = -1;
    }
}
