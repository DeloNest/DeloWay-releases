import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// WorkspaceIndicator — Dynamic workspace dots/icons/pills for the smart notch.
// Event-driven: Hyprland.workspaces + ToplevelManager.toplevels, no polling.
// OLED tokens only. Wheel scroll limited to this component; does not propagate
// to the notch expand/collapse handler (prevents commit d046548 regression).
Item {
    id: root

    property var hyprMonitor: null
    property int staticCount: ConfigManager.workspacesCount
    property string indicatorStyle: "icons"
    property bool reduceMotion: false

    implicitWidth:  wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight

    // ── Workspace state ───────────────────────────────────────────────────
    readonly property var allToplevels: ToplevelManager.toplevels.values
    readonly property var activeWsObj: root.hyprMonitor ? root.hyprMonitor.activeWorkspace : null
    readonly property int activeWsId:  activeWsObj ? activeWsObj.id : 0

    // map wsId → WlrToplevel[]
    readonly property var topsByWs: {
        const _top = root.allToplevels;
        const map  = {};
        for (let i = 0; i < _top.length; i++) {
            const t = _top[i];
            if (!t || !t.handle) continue;
            const hl = t.handle;
            if (!hl.workspace) continue;
            const wid = hl.workspace.id;
            if (wid <= 0) continue;
            if (!map[wid]) map[wid] = [];
            map[wid].push(t);
        }
        return map;
    }

    // Extra ws ids beyond static range that have toplevels or are active
    readonly property var extraWsIds: {
        const _N   = root.staticCount;
        const _act = root.activeWsId;
        const map  = root.topsByWs;
        const extra = [];
        const keys = Object.keys(map);
        for (let k = 0; k < keys.length; k++) {
            const id = parseInt(keys[k]);
            if (id > _N && id !== _act) extra.push(id);
        }
        if (_act > _N) extra.push(_act);
        extra.sort((a, b) => a - b);
        return extra;
    }

    // Full sorted display list
    readonly property var displayIds: {
        const base = [];
        for (let n = 1; n <= root.staticCount; n++) base.push(n);
        const extra = root.extraWsIds;
        for (let i = 0; i < extra.length; i++) {
            if (base.indexOf(extra[i]) === -1) base.push(extra[i]);
        }
        base.sort((a, b) => a - b);
        return base;
    }

    // ── Scroll: switch workspace without propagating to notch ─────────────
    // Throttle: ignore rapid scroll events
    property real _lastScrollTime: 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: false   // ← blocks further propagation
        onWheel: (wheel) => {
            wheel.accepted = true;       // consume the event here
            const now = Date.now();
            if (now - root._lastScrollTime < 300) return;  // 300 ms throttle
            root._lastScrollTime = now;

            const ids = root.displayIds;
            const cur = root.activeWsId;
            const idx = ids.indexOf(cur);

            if (wheel.angleDelta.y < 0) {
                // scroll down → next workspace
                const next = idx >= 0 && idx < ids.length - 1 ? ids[idx + 1] : ids[ids.length - 1];
                Hyprland.dispatch("workspace " + next);
            } else {
                // scroll up → previous workspace
                const prev = idx > 0 ? ids[idx - 1] : ids[0];
                Hyprland.dispatch("workspace " + prev);
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    function iconForToplevel(top) {
        if (!top || !top.appId) return "";
        const app = ApplicationManager.findApp(top.appId);
        return app ? (app.icon || top.appId) : top.appId;
    }

    function primaryToplevel(tops) {
        if (!tops || tops.length === 0) return null;
        for (let i = 0; i < tops.length; i++) {
            if (tops[i] && tops[i].activated) return tops[i];
        }
        return tops[0];
    }

    // ── Row ───────────────────────────────────────────────────────────────
    RowLayout {
        id: wsRow
        spacing: Theme.wsIndicatorSpacing
        layoutDirection: Qt.LeftToRight

        Repeater {
            model: root.displayIds

            delegate: WorkspaceItem {
                required property int modelData

                readonly property var myTops:    root.topsByWs[modelData] || []
                readonly property var myPrimary: root.primaryToplevel(myTops)

                wsId:         modelData
                isActive:     modelData === root.activeWsId
                hasTops:      myTops.length > 0
                tops:         myTops
                style:        root.indicatorStyle
                primaryIcon:  root.iconForToplevel(myPrimary)
                extraCount:   myTops.length > 1 ? myTops.length - 1 : 0
                reduceMotion: root.reduceMotion

                onSwitchRequested:    (id) => Hyprland.dispatch("workspace " + id)
                onCloseAllRequested:  (id) => {
                    const tops = myTops;
                    for (let i = 0; i < tops.length; i++) {
                        if (tops[i] && tops[i].close) tops[i].close();
                    }
                }
            }
        }
    }
}
