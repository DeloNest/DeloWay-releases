import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// WorkspaceIndicator — Dynamic workspace dots/icons/pills for the smart notch.
// Event-driven: ToplevelManager.toplevels + Hyprland.activeWorkspace, no polling.
// OLED identity: Theme tokens only. Wheel scroll is consumed here (no propagation).
Item {
    id: root

    property var    hyprMonitor:    null
    property int    staticCount:    ConfigManager.workspacesCount   // default 5
    property string indicatorStyle: "icons"          // "icons" | "numbers" | "dots"
    property bool   reduceMotion:   false

    implicitWidth:  wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight

    // ── Live data ─────────────────────────────────────────────────────────
    readonly property var allToplevels:  ToplevelManager.toplevels.values
    readonly property var activeWsObj:   root.hyprMonitor ? root.hyprMonitor.activeWorkspace : null
    readonly property int activeWsId:    activeWsObj ? activeWsObj.id : 0

    // Map: wsId (int) → WlrToplevel[]
    readonly property var topsByWs: {
        const _top = root.allToplevels;
        const map  = {};
        for (let i = 0; i < _top.length; i++) {
            const t = _top[i];
            if (!t || !t.handle) continue;
            const hl = t.handle;           // HyprlandToplevel
            if (!hl.workspace) continue;
            const wid = hl.workspace.id;
            if (wid <= 0) continue;
            if (!map[wid]) map[wid] = [];
            map[wid].push(t);
        }
        return map;
    }

    // Extra workspace IDs beyond static range that have toplevels or are active
    readonly property var extraWsIds: {
        const _N   = root.staticCount;
        const _act = root.activeWsId;
        const map  = root.topsByWs;
        const extra = [];
        for (const key of Object.keys(map)) {
            const id = parseInt(key);
            if (id > _N && id !== _act) extra.push(id);
        }
        if (_act > _N) extra.push(_act);
        extra.sort((a, b) => a - b);
        return extra;
    }

    // Full ordered list: 1…staticCount always present, extras appended
    readonly property var displayIds: {
        const base = [];
        for (let n = 1; n <= root.staticCount; n++) base.push(n);
        for (const id of root.extraWsIds) {
            if (!base.includes(id)) base.push(id);
        }
        base.sort((a, b) => a - b);
        return base;
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    function iconForToplevel(top) {
        if (!top || !top.appId) return "";
        const app = ApplicationManager.findApp(top.appId);
        return app ? (app.icon || top.appId) : top.appId;
    }

    // Returns the "most relevant" toplevel (activated one first, else tops[0])
    function primaryToplevel(tops) {
        if (!tops || tops.length === 0) return null;
        for (const t of tops) { if (t && t.activated) return t; }
        return tops[0];
    }

    // Returns the second-most-relevant toplevel (first one that is NOT primary)
    function secondaryToplevel(tops) {
        if (!tops || tops.length < 2) return null;
        const primary = primaryToplevel(tops);
        for (const t of tops) { if (t && t !== primary) return t; }
        return null;
    }

    // ── Wheel scroll — consume event, no propagation to notch ─────────────
    property real _lastScrollTime: 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons:        Qt.NoButton
        propagateComposedEvents: false
        onWheel: (wheel) => {
            wheel.accepted = true;
            const now = Date.now();
            if (now - root._lastScrollTime < 300) return;
            root._lastScrollTime = now;

            const ids = root.displayIds;
            const idx = ids.indexOf(root.activeWsId);
            if (wheel.angleDelta.y < 0) {
                const next = (idx >= 0 && idx < ids.length - 1) ? ids[idx + 1] : ids[ids.length - 1];
                Hyprland.dispatch("workspace " + next);
            } else {
                const prev = idx > 0 ? ids[idx - 1] : ids[0];
                Hyprland.dispatch("workspace " + prev);
            }
        }
    }

    // ── Row ───────────────────────────────────────────────────────────────
    RowLayout {
        id: wsRow
        spacing:         Theme.wsIndicatorSpacing
        layoutDirection: Qt.LeftToRight    // always LTR regardless of RTL locale

        Repeater {
            model: root.displayIds

            delegate: WorkspaceItem {
                required property int modelData

                readonly property var myTops:     root.topsByWs[modelData] || []
                readonly property var myPrimary:  root.primaryToplevel(myTops)
                readonly property var mySecondary: root.secondaryToplevel(myTops)

                wsId:          modelData
                isActive:      modelData === root.activeWsId
                hasTops:       myTops.length > 0
                tops:          myTops
                style:         root.indicatorStyle
                primaryIcon:   root.iconForToplevel(myPrimary)
                secondaryIcon: root.iconForToplevel(mySecondary)
                reduceMotion:  root.reduceMotion

                onSwitchRequested:   (id) => Hyprland.dispatch("workspace " + id)
                onCloseAllRequested: (id) => {
                    for (const t of myTops) { if (t && t.close) t.close(); }
                }
            }
        }
    }
}
