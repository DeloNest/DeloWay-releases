pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

// Notch → Share: LocalSend without the LocalSend app. scripts/deloway-localsend.py is a
// small LocalSend peer (Python, standard library) that this service runs and talks to in
// JSON lines. It only runs while it has something to do — a paired device to stay
// reachable for, the Share tab on screen, or a transfer — and exits with the shell.
Item {
    id: root

    // ── The peer ──────────────────────────────────────────────────────────
    readonly property string helperScript: ConfigManager.projectDir + "/scripts/deloway-localsend.py"
    property bool ready: false
    property string localAlias: ""
    property string fingerprint: ""
    property bool receiving: false        // other devices can send here
    property string peerError: ""         // "port_busy" (another program holds port 53317), …
    property bool appElsewhere: false     // …and that program is the LocalSend app
    property var addresses: []            // [{interface, ip}] this computer is reachable on
    property string downloadDir: ""
    readonly property string localIp: addresses.length > 0 ? addresses[0].ip : ""

    // ── Devices ───────────────────────────────────────────────────────────
    readonly property var pairedDevices: Array.isArray(ConfigManager.shareDevices) ? ConfigManager.shareDevices : []
    readonly property bool hasPaired: pairedDevices.length > 0
    property var seen: ({})               // fingerprint → device as last seen (+ seenAt ms)
    property int _clock: 0                // bumped so "online" re-evaluates as time passes
    readonly property int onlineWindow: 3 * 60 * 1000
    property bool isScanning: false

    function isOnline(fp) {
        const _c = root._clock;
        const d = root.seen[fp];
        return !!d && (Date.now() - d.seenAt) < root.onlineWindow;
    }
    function isPaired(fp) { return root.pairedDevices.some(d => d.fingerprint === fp); }
    // Nearby LocalSend devices seen recently that are not paired yet.
    readonly property var nearbyDevices: {
        const _c = root._clock;
        const out = [];
        for (const fp in root.seen) {
            if (!root.isPaired(fp) && root.isOnline(fp)) out.push(root.seen[fp]);
        }
        return out;
    }
    // Paired devices with their live address and online state.
    readonly property var devices: {
        const _c = root._clock;
        const _s = root.seen;
        return root.pairedDevices.map(d => Object.assign({}, d, root.seen[d.fingerprint] || {},
                                                          { online: root.isOnline(d.fingerprint) }));
    }
    property string probeFailedIp: ""
    property string _manualProbe: ""      // an address typed in the connect flow
    signal devicePaired(var device)

    // ── Sending ───────────────────────────────────────────────────────────
    property var droppedFiles: []         // staged for sending
    property string sendStatus: "idle"    // idle | connecting | sending | sent | failed | cancelled
    property real sendProgress: 0.0
    property string sendError: ""         // unreachable | declined | pin | busy | interrupted | failed
    property string currentSendingFile: ""
    property var sendDevice: null
    readonly property bool isSending: sendStatus === "connecting" || sendStatus === "sending"

    // ── Receiving ─────────────────────────────────────────────────────────
    property var incoming: null           // {sessionId, sender, files, totalSize}
    property string receiveStatus: "idle" // idle | asking | receiving | received | ended
    property real receiveProgress: 0.0
    property string receiveEndReason: ""  // declined | expired | cancelled | failed
    property var receivedFiles: []
    readonly property bool isReceiving: receiveStatus === "asking" || receiveStatus === "receiving"

    signal filesStaged(var files)
    signal resetRequested()

    // ── When the peer runs ────────────────────────────────────────────────
    readonly property bool panelVisible: ShellState.smartNotchExpanded && ShellState.smartNotchTab === 2
    onPanelVisibleChanged: if (panelVisible) root.scan()   // fresh online states on opening
    readonly property bool wanted: !root.appOpen
                                   && (root.hasPaired || root.panelVisible || root.isSending
                                       || root.isReceiving || root.droppedFiles.length > 0)
    property bool _run: false
    on_RunChanged: peer.running = root._run
    onWantedChanged: {
        if (root.wanted) { idleStop.stop(); root._run = true; }
        else if (root.appOpen) { idleStop.stop(); root._run = false; }   // free the port now
        else idleStop.restart();
    }
    // Linger a minute after the last reason to run, so flipping tabs does not restart it.
    Timer { id: idleStop; interval: 60000; onTriggered: root._run = root.wanted }
    Component.onCompleted: root._run = root.wanted

    Process {
        id: peer
        stdinEnabled: true
        command: ["python3", root.helperScript, "serve"]
        stdout: SplitParser { onRead: data => root._handle(data) }
        onRunningChanged: {
            if (!running) {
                if (root.appOpen && !app.running) app.running = true;   // the port is free now
                root.ready = false;
                root.receiving = false;
                root.isScanning = false;
                if (root.isSending) { root.sendStatus = "failed"; root.sendError = "interrupted"; }
                if (root.isReceiving) { root.receiveStatus = "ended"; root.receiveEndReason = "failed"; }
            }
        }
        onExited: (code, status) => { if (root._run) restartPeer.restart(); }
    }
    // The peer died while needed: start it again, not in a tight loop.
    Timer { id: restartPeer; interval: 5000; onTriggered: if (root._run && !peer.running) peer.running = true }

    // ── The LocalSend app ─────────────────────────────────────────────────
    // For the app's full experience. It needs port 53317 too, so while it runs (started
    // here) the peer steps aside, and comes back when the app is closed.
    readonly property bool appInstalled: {
        const _r = root._entriesRev;
        return !!DesktopEntries.byId("localsend");
    }
    property int _entriesRev: 0
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root._entriesRev++; }
    }
    property bool appOpen: false          // started from here and still running
    // Opened elsewhere (the peer found port 53317 taken): same situation for the user.
    readonly property bool appHoldsPort: root.appOpen || root.appElsewhere

    Process {
        id: app
        command: ["localsend"]
        onRunningChanged: if (!running) root.appOpen = false
    }

    function openApp() {
        if (app.running || root.appElsewhere) {
            Hyprland.dispatch("focuswindow class:^(org\\.localsend\\.localsend_app)$");
            return;
        }
        root.appOpen = true;               // stops the peer; it starts the app once it is gone
        if (!peer.running) app.running = true;
    }

    // Back to sharing from the Notch: close the app (ours, or one opened elsewhere).
    function closeApp() {
        if (app.running) {
            app.running = false;
        } else if (root.appElsewhere) {
            Quickshell.execDetached(["pkill", "-x", "localsend"]);
            root.peerError = "";
            root.appElsewhere = false;
            root._run = false;             // restart the peer so it takes the port
            peerRestart.restart();
        }
    }
    Timer { id: peerRestart; interval: 1500; onTriggered: root._run = root.wanted }

    function _cmd(obj) {
        if (peer.running) peer.write(JSON.stringify(obj) + "\n");
    }

    function _handle(line) {
        let ev;
        try { ev = JSON.parse(line); } catch (e) { return; }
        switch (ev.event) {
        case "ready":
            root.ready = true;
            root.localAlias = ev.alias || "";
            root.fingerprint = ev.fingerprint || "";
            root.receiving = !!ev.receiving;
            root.peerError = ev.error || "";
            root.appElsewhere = !!ev.appRunning;
            root.downloadDir = ev.downloadDir || "";
            // First run: the phones already saved in the LocalSend app come along.
            if (ConfigManager.shareDevices === null)
                ConfigManager.setShareDevices(Array.isArray(ev.appFavorites) ? ev.appFavorites : []);
            if (root.panelVisible) root.scan();
            break;
        case "network":
            root.addresses = ev.addresses || [];
            break;
        case "device":
            root._saw(ev.device);
            break;
        case "probe-failed":
            if (ev.ip === root._manualProbe) {
                root.probeFailedIp = ev.ip;
                root._manualProbe = "";
            }
            break;
        case "send-status":
            root.sendStatus = ev.status;
            if (ev.total > 0) root.sendProgress = Math.min(1, (ev.sent || 0) / ev.total);
            if (ev.status === "sent") root.sendProgress = 1;
            if (ev.file) root.currentSendingFile = ev.file;
            root.sendError = ev.error || "";
            if (ev.status === "failed")
                console.warn("[share] sending to " + (ev.device || "?") + " failed: " + ev.error + (ev.detail ? " (" + ev.detail + ")" : ""));
            break;
        case "incoming":
            root.incoming = ev;
            root.receiveStatus = "asking";
            root.receiveProgress = 0;
            root.receiveEndReason = "";
            root.receivedFiles = [];
            ShellState.openSmartNotch(2);   // the request is answered in the Share tab
            break;
        case "receive-progress":
            root.receiveStatus = "receiving";
            if (ev.total > 0) root.receiveProgress = Math.min(1, ev.received / ev.total);
            break;
        case "received":
            root.receiveStatus = "received";
            root.receiveProgress = 1;
            root.receivedFiles = ev.files || [];
            if (!root.panelVisible) root._notifyReceived(ev);
            break;
        case "receive-ended":
            if (root.incoming && root.incoming.sessionId === ev.sessionId) {
                root.receiveStatus = "ended";
                root.receiveEndReason = ev.reason || "failed";
            }
            break;
        }
    }

    function _saw(dev) {
        if (!dev || !dev.fingerprint) return;
        const next = Object.assign({}, root.seen);
        next[dev.fingerprint] = Object.assign({}, dev, { seenAt: Date.now() });
        root.seen = next;
        // Typed its address in the connect flow: that is the pairing.
        if (dev.via === "probe" && dev.ip === root._manualProbe) {
            root._manualProbe = "";
            root.pair(dev);
        }
        // A paired phone's address changes with DHCP: remember where it was seen last.
        const i = root.pairedDevices.findIndex(d => d.fingerprint === dev.fingerprint);
        if (i >= 0) {
            const p = root.pairedDevices[i];
            if (p.ip !== dev.ip || p.port !== dev.port || p.alias !== dev.alias || p.protocol !== dev.protocol) {
                const list = root.pairedDevices.slice();
                list[i] = root._record(dev);
                ConfigManager.setShareDevices(list);
            }
        }
    }

    function _record(dev) {
        return { fingerprint: dev.fingerprint, alias: dev.alias || dev.ip, deviceType: dev.deviceType || "mobile",
                 deviceModel: dev.deviceModel || "", ip: dev.ip, port: dev.port || 53317,
                 protocol: dev.protocol === "http" ? "http" : "https" };
    }

    function _notifyReceived(ev) {
        const from = ev.sender ? (ev.sender.alias || ev.sender.ip) : "";
        Quickshell.execDetached(["notify-send", "-a", "DeloWay", "-i", "folder-download-symbolic",
                                 I18n.tr("ls_received_title"),
                                 I18n.uiLine(I18n.filesCount((ev.files || []).length) + " — " + I18n.isolate(from))]);
    }

    // While the Share tab is open: announce every 10 s (one UDP packet per network) and
    // knock on the paired devices' last addresses, so their online state is current.
    Timer {
        interval: 10000
        running: root.panelVisible && root.ready
        repeat: true
        onTriggered: root.scan()
    }
    Timer {
        interval: 15000
        running: root.panelVisible
        repeat: true
        onTriggered: root._clock++
    }
    Timer { id: scanDone; interval: 3000; onTriggered: root.isScanning = false }

    // ── Public API ────────────────────────────────────────────────────────
    function scan() {
        if (!root.ready) return;
        root.isScanning = true;
        scanDone.restart();
        root._clock++;
        root._cmd({ cmd: "scan" });
        for (const d of root.pairedDevices) {
            if (d.ip) root._cmd({ cmd: "probe", ip: d.ip, port: d.port || 53317 });
        }
    }

    // "192.168.1.20" or "192.168.1.20:53318" (LocalSend's port can be changed on the device).
    function probe(address) {
        const m = String(address).trim().match(/^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$/);
        if (!m) return false;
        root.probeFailedIp = "";
        root._manualProbe = m[1];
        root._cmd({ cmd: "probe", ip: m[1], port: m[2] ? parseInt(m[2]) : 53317 });
        return true;
    }

    function pair(dev) {
        if (!dev || !dev.fingerprint || root.isPaired(dev.fingerprint)) return;
        ConfigManager.setShareDevices(root.pairedDevices.concat([root._record(dev)]));
        root.devicePaired(dev);
    }

    function unpair(fp) {
        ConfigManager.setShareDevices(root.pairedDevices.filter(d => d.fingerprint !== fp));
    }

    // Files from anywhere (drop on the notch, desktop menu, IPC) → the Share tab.
    function stageFiles(files) {
        if (!files || files.length === 0) return;
        const clean = [];
        for (let i = 0; i < files.length; i++) {
            let p = String(files[i] || "");
            if (p.startsWith("file://")) p = decodeURIComponent(p.substring(7));
            if (p) clean.push(p);
        }
        root.droppedFiles = clean;
        root.resetSendState();
        filesStaged(clean);
    }

    function clearStaged() {
        root.droppedFiles = [];
        root.resetSendState();
    }

    function resetStage() {
        root.clearStaged();
        resetRequested();
    }

    function sendFiles(files, device) {
        const list = files || root.droppedFiles;
        if (!list || list.length === 0 || !device) return;
        root.sendDevice = device;
        if (!root.ready) {   // the peer is not running (python3 missing, crashed): say so
            root.sendStatus = "failed";
            root.sendError = "failed";
            return;
        }
        root.sendStatus = "connecting";
        root.sendProgress = 0;
        root.sendError = "";
        root.currentSendingFile = "";
        root._cmd({ cmd: "send", files: list,
                    device: { ip: device.ip, port: device.port || 53317, protocol: device.protocol || "https",
                              alias: device.alias || device.ip } });
    }

    function cancelSend() { root._cmd({ cmd: "cancel-send" }); }

    function resetSendState() {
        root.sendStatus = "idle";
        root.sendProgress = 0;
        root.sendError = "";
        root.currentSendingFile = "";
    }

    function acceptIncoming() {
        if (root.incoming) root._cmd({ cmd: "accept", sessionId: root.incoming.sessionId });
        root.receiveStatus = "receiving";
    }
    function declineIncoming() {
        if (root.incoming) root._cmd({ cmd: "decline", sessionId: root.incoming.sessionId });
        root.dismissReceive();
    }
    function cancelReceive() {
        if (root.incoming) root._cmd({ cmd: "cancel-receive", sessionId: root.incoming.sessionId });
    }
    function dismissReceive() {
        root.incoming = null;
        root.receiveStatus = "idle";
        root.receiveProgress = 0;
        root.receivedFiles = [];
    }
    function openReceived() {
        const files = root.receivedFiles;
        Quickshell.execDetached(["xdg-open", files.length === 1 ? files[0] : root.downloadDir]);
    }
    function openDownloads() {
        if (root.downloadDir) Quickshell.execDetached(["xdg-open", root.downloadDir]);
    }

    // Text for a transfer failure code.
    function sendErrorText(code) {
        const key = "ls_err_" + (code || "failed");
        const t = I18n.tr(key);
        return t === key ? I18n.tr("ls_err_failed") : t;
    }
}
