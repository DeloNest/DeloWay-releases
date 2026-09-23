import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// WorkspaceIndicator — Dynamic workspace dots/icons/pills for the smart notch.
// Event-driven: Hyprland.toplevels + Hyprland.activeWorkspace.
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
    readonly property var hlToplevels:   Hyprland.toplevels.values
    readonly property var activeWsObj:   root.hyprMonitor ? root.hyprMonitor.activeWorkspace : null
    readonly property int activeWsId:    activeWsObj ? activeWsObj.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    // Map: wsId (int) → window item list
    readonly property var topsByWs: {
        const _list = root.hlToplevels;
        const map   = {};
        for (let i = 0; i < _list.length; i++) {
            const hl = _list[i];
            if (!hl) continue;

            let wid = 0;
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

            const item = {
                appId:     appId,
                title:     hl.title || "",
                activated: hl.activated || false,
                address:   hl.address || "",
                close: function() {
                    if (hl.wayland && hl.wayland.close) {
                        hl.wayland.close();
                    } else if (hl.address) {
                        Hyprland.dispatch("closewindow address:" + hl.address);
                    }
                }
            };

            if (!map[wid]) map[wid] = [];
            map[wid].push(item);
        }
        return map;
    }

    // Extra workspace IDs beyond static range that have toplevels or are active
    readonly property var extraWsIds: {
        const _N    = root.staticCount;
        const _act  = root.activeWsId;
        const map   = root.topsByWs;
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

    // Returns the primary toplevel (activated window first, else tops[0])
    function primaryToplevel(tops) {
        if (!tops || tops.length === 0) return null;
        for (const t of tops) { if (t && t.activated) return t; }
        return tops[0];
    }

    // Returns the secondary toplevel (different app if possible, else second window)
    function secondaryToplevel(tops) {
        if (!tops || tops.length < 2) return null;
        const primary = primaryToplevel(tops);
        // First try to find a window from a different app
        for (const t of tops) {
            if (t && t !== primary && t.appId !== primary.appId) return t;
        }
        // Otherwise return any second window
        for (const t of tops) {
            if (t && t !== primary) return t;
        }
        return null;
    }

    // No wheel handler here on purpose: scrolling over the workspace dots falls through to
    // the Notch, where scroll-down expands and scroll-up collapses (same as every capsule).
    // Workspaces switch by clicking a dot (or Super+number).

    // ── Row ───────────────────────────────────────────────────────────────
    RowLayout {
        id: wsRow
        spacing:         Theme.wsIndicatorSpacing
        // Always LTR (workspace 1 on the left), pinned locally: a layoutDirection alone
        // is flipped by any mirrored ancestor.
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        Repeater {
            model: root.displayIds

            delegate: WorkspaceItem {
                required property int modelData

                readonly property var myTops:      root.topsByWs[modelData] || []
                readonly property var myPrimary:   root.primaryToplevel(myTops)
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
