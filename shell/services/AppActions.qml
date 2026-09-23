pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AppActions: the one place the Dock, the App Drawer and Settings → Apps go through for
// per-app actions (launch, pin, window ops, App Info, Uninstall).
//
// Backend: scripts/deloway-app-info.py
//   info <desktop-id>       → owner (pacman/AUR · flatpak · user shortcut · unowned),
//                              package, version, size, install date, removable + reason
//   uninstall <desktop-id>  → pamac remove (polkit prompt) · flatpak uninstall · gio trash
Item {
    id: root

    readonly property string script: ConfigManager.projectDir + "/scripts/deloway-app-info.py"
    readonly property var internalIds: ["settings", "store"]

    function cleanId(id) { return String(id || "").toLowerCase().replace(/\.desktop$/, ""); }
    function isInternal(id) { return root.internalIds.indexOf(root.cleanId(id)) >= 0; }

    // ── Normalised, live view of an app ──────────────────────────────────
    // Accepts a dock entry, a DesktopEntry, a findApp() object or a bare id. Returns the
    // same shape as ApplicationManager.dockApps entries plus `desktopId` (the real,
    // case-preserving desktop-file id for the backend) and `internal`.
    function entryFor(appOrId) {
        const _r = ApplicationManager._windowStateRevision;
        if (!appOrId) return null;
        const rawId = typeof appOrId === "string" ? appOrId : (appOrId.id || "");
        const id = root.cleanId(rawId);
        if (!id) return null;

        let e = ApplicationManager.dockApps.find(x => ApplicationManager.matchesAppId(x.id, id));
        const app = ApplicationManager.findApp(rawId) || ApplicationManager.findApp(id);
        if (!e) {
            const wins = ApplicationManager.getWindowsForApp(id);
            e = {
                id: id,
                name: app ? app.name : (appOrId.name || id),
                icon: app ? app.icon : (appOrId.icon || id),
                desktopEntry: (app && app.execute) ? app : null,
                pinned: ApplicationManager.isPinned(id),
                running: wins.length > 0,
                windowCount: wins.length,
                windows: wins,
                isActive: wins.some(w => ApplicationManager.isActiveWindow(w) && !ApplicationManager.isMinimized(w)),
                urgent: false,
                allMinimized: wins.length > 0 && wins.every(w => ApplicationManager.isMinimized(w))
            };
        }
        return Object.assign({}, e, {
            desktopId: (app && app.id) ? String(app.id) : rawId,
            internal: root.isInternal(id) || root.isInternal(e.id)
        });
    }

    // ── Launch / window actions ──────────────────────────────────────────
    function launch(item) {
        if (!item) return;
        if (item.id === "settings") { ShellState.openSettingsApp(); return; }
        LauncherIndex.recordLaunch(item.desktopId || item.id);
        ApplicationManager.newWindow(item);
    }
    function togglePin(item) { if (item) ApplicationManager.togglePin(item.id); }
    function closeAll(item) {
        if (!item) return;
        if (item.id === "settings") ShellState.closeSettingsApp();
        else ApplicationManager.closeAllWindows(item);
    }

    // ── App Info (backend lookup, cached) ────────────────────────────────
    property var _info: ({})              // desktopId → info object
    property int infoRevision: 0
    property var _infoQueue: []

    function infoFor(desktopId) {
        const _r = root.infoRevision;
        return desktopId ? (root._info[desktopId] || null) : null;
    }
    function requestInfo(desktopId, force) {
        if (!desktopId || root.isInternal(desktopId)) return;
        if (!force && root._info[desktopId]) return;
        if (root._infoQueue.indexOf(desktopId) < 0) root._infoQueue = root._infoQueue.concat([desktopId]);
        if (!infoProc.running) root._nextInfo();
    }
    function _nextInfo() {
        if (root._infoQueue.length === 0) return;
        const id = root._infoQueue[0];
        root._infoQueue = root._infoQueue.slice(1);
        infoProc.targetId = id;
        infoProc.command = ["python3", root.script, "info", id];
        infoProc.running = true;
    }
    Process {
        id: infoProc
        property string targetId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(this.text); } catch (e) { d = { ok: false, error: "bad output" }; }
                const m = Object.assign({}, root._info);
                m[infoProc.targetId] = d;
                root._info = m;
                root.infoRevision++;
            }
        }
        onExited: root._nextInfo()
    }

    // Opens Settings → Apps with the details card for this app.
    function openInfo(item) {
        if (!item) return;
        root.requestInfo(item.desktopId, true);
        ShellState.openAppInfo(item.desktopId);
    }
    function openInSoftwareCenter(info) {
        if (!info || !info.package) return;
        if (info.source === "pacman" || info.source === "aur")
            Quickshell.execDetached(["pamac-manager", "--details=" + info.package]);
    }

    // ── Uninstall ────────────────────────────────────────────────────────
    property var uninstalling: ({})       // desktopId → true while running
    property var _uninstallQueue: []

    function isUninstalling(desktopId) { return !!root.uninstalling[desktopId]; }

    // Caller must have confirmed with the user (the shared menu and Settings both do).
    function uninstall(item) {
        if (!item || item.internal || !item.desktopId || root.isUninstalling(item.desktopId)) return;
        const u = Object.assign({}, root.uninstalling);
        u[item.desktopId] = true;
        root.uninstalling = u;
        root._uninstallQueue = root._uninstallQueue.concat([{ id: item.desktopId, clean: item.id,
                                                              name: item.name, icon: item.icon }]);
        if (!uninstallProc.running) root._nextUninstall();
    }
    function _nextUninstall() {
        if (root._uninstallQueue.length === 0) return;
        const job = root._uninstallQueue[0];
        root._uninstallQueue = root._uninstallQueue.slice(1);
        uninstallProc.job = job;
        uninstallProc.command = ["python3", root.script, "uninstall", job.id];
        uninstallProc.running = true;
    }
    function _finishUninstall(job, res) {
        const u = Object.assign({}, root.uninstalling);
        delete u[job.id];
        root.uninstalling = u;
        const name = job.name || job.id;
        if (res && res.ok) {
            if (ApplicationManager.isPinned(job.clean)) ApplicationManager.unpinApp(job.clean);
            if (ShellState.appInfoId === job.id) ShellState.appInfoId = "";
            NotificationManager.postNotification(I18n.tr("app_menu_title"),
                I18n.tr("app_uninstalled").replace("%1", name),
                res.source === "user" ? I18n.tr("app_uninstalled_shortcut") : "", job.icon);
        } else {
            const err = res ? (res.error || "") : "";
            let body = err;
            if (err === "protected") body = I18n.tr("app_reason_protected");
            else if (err === "required") body = I18n.tr("app_reason_required") + " " + ((res.requiredBy || []).join(", "));
            else if (/not authori[sz]ed|authentication|dismissed|cancel/i.test(err)) body = I18n.tr("app_uninstall_cancelled");
            NotificationManager.postNotification(I18n.tr("app_menu_title"),
                I18n.tr("app_uninstall_failed").replace("%1", name), body, job.icon);
        }
        // Refresh cached info (e.g. a failed attempt may still have changed nothing).
        const m = Object.assign({}, root._info);
        delete m[job.id];
        root._info = m;
        root.infoRevision++;
    }
    Process {
        id: uninstallProc
        property var job: null
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(this.text); } catch (e) { d = { ok: false, error: this.text.trim() }; }
                root._finishUninstall(uninstallProc.job, d);
            }
        }
        onExited: root._nextUninstall()
    }

    // ── Presentation helpers (shared by menu + Settings) ─────────────────
    function sourceLabel(info) {
        if (!info) return "";
        if (info.source === "pacman") return I18n.tr("app_source_pacman");
        if (info.source === "aur") return I18n.tr("app_source_aur");
        if (info.source === "flatpak") return I18n.tr("app_source_flatpak");
        if (info.source === "user") return I18n.tr(info.webApp ? "app_source_webapp" : "app_source_user");
        return I18n.tr("app_source_unowned");
    }
    // One line describing what "Uninstall" will actually do (or why it can't).
    function uninstallSummary(info) {
        if (!info) return I18n.tr("app_checking");
        if (!info.ok) return info.error || "";
        if (!info.removable) {
            if (info.reason === "protected") return I18n.tr("app_reason_protected");
            if (info.reason === "required") return I18n.tr("app_reason_required") + " " + info.requiredBy.slice(0, 3).join(", ");
            if (info.reason === "lookup-failed") return I18n.tr("app_reason_lookup");
            return I18n.tr("app_reason_unmanaged");
        }
        if (info.source === "user") return I18n.tr("app_remove_shortcut");
        return I18n.tr("app_remove_package").replace("%1", info.package) + (info.size ? " · " + info.size : "");
    }
}
