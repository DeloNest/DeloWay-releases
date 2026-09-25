pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    // ─────────────────────────────────────────────────────────────────────────
    // Reactive Properties
    // ─────────────────────────────────────────────────────────────────────────
    property var networkData: null

    // Ethernet State
    property bool ethernetConnected: false
    property string ethernetDevice: ""
    property string ethernetIp: ""

    // Wi-Fi State
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiSsid: ""
    property var wifiNetworks: []
    property string connectingSsid: ""
    property string networkError: ""
    property bool isScanning: false

    // Saved Wi-Fi Connections
    property var savedConnections: []

    // SSID whose last connect attempt failed for lack of / wrong credentials.
    property string passwordRequiredSsid: ""

    function isSaved(ssid) {
        for (const c of root.savedConnections) if (c.name === ssid) return true;
        return false;
    }

    // IP Configuration Details
    property var ipDetails: ({
        "ipv4": "",
        "gateway": "",
        "dns": [],
        "interface": "",
        "mac": ""
    })

    // Hotspot State
    property bool hotspotAvailable: false
    property bool hotspotEnabled: false
    property string hotspotSsid: ""
    property string hotspotPassword: ""
    property string hotspotError: ""
    // Why a hotspot cannot start here (no adapter, no AP mode, no dnsmasq), translated;
    // "" when nothing is known to be missing.
    property string hotspotProblem: ""
    property string hotspotSaveSuccess: ""
    property var hotspotClients: []
    property bool hotspotActionRunning: hotspotActionProc.running
    property bool hotspotConfigureRunning: hotspotConfigureProc.running

    // ─────────────────────────────────────────────────────────────────────────
    // Backend Processes
    // ─────────────────────────────────────────────────────────────────────────

    // Main status process (reads wifi, ethernet, hotspot via deloway-network.py)
    Process {
        id: statusProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.networkData = parsed;
                    root.networkError = "";

                    if (parsed.ethernet) {
                        root.ethernetConnected = !!parsed.ethernet.connected;
                        root.ethernetDevice = parsed.ethernet.device || "";
                        root.ethernetIp = parsed.ethernet.ip || "";
                    }

                    if (parsed.wifi) {
                        root.wifiAvailable = !!parsed.wifi.available;
                        root.wifiEnabled = !!parsed.wifi.enabled;
                        root.wifiConnected = !!parsed.wifi.connected;
                        root.wifiSsid = parsed.wifi.ssid || "";
                        root.wifiNetworks = parsed.wifi.networks || [];
                    }

                    if (parsed.hotspot) {
                        root.hotspotAvailable = !!parsed.hotspot.available;
                        root.hotspotEnabled = !!parsed.hotspot.enabled;
                        if (parsed.hotspot.ssid) root.hotspotSsid = parsed.hotspot.ssid;
                        if (parsed.hotspot.password) root.hotspotPassword = parsed.hotspot.password;
                        if (parsed.hotspot.clients !== undefined) root.hotspotClients = parsed.hotspot.clients;
                        root.hotspotProblem = parsed.hotspot.error_code ? root.hotspotMessage(parsed.hotspot) : "";
                    }
                } catch (e) {
                    root.networkError = I18n.isRTL ? "تعذر قراءة بيانات الشبكة" : "Failed to parse network data";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.networkError = I18n.isRTL ? "تعذر جلب بيانات الشبكة" : "Failed to fetch network data";
            }
        }
    }

    // Toggle Wi-Fi process
    Process {
        id: wifiToggleProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "toggle-wifi"]
        onExited: root.refresh()
    }

    // Rescan Wi-Fi process
    Process {
        id: wifiRescanProc
        command: ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "rescan"]
        onStarted: root.isScanning = true
        onExited: {
            root.isScanning = false;
            root.refresh();
        }
    }

    // Connect Wi-Fi process
    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const res = JSON.parse(data.trim());
                    root.passwordRequiredSsid = (!res.success && res.needsPassword) ? wifiConnectProc.targetSsid : "";
                    if (!res.success) {
                        root.networkError = res.needsPassword
                            ? (I18n.isRTL ? "كلمة المرور مطلوبة أو غير صحيحة" : "Password required or incorrect")
                            : (res.error || (I18n.isRTL ? "فشل الاتصال بالشبكة" : "Failed to connect to network"));
                    } else {
                        root.networkError = "";
                    }
                } catch (e) {}
            }
        }
        onExited: {
            root.connectingSsid = "";
            root.refresh();
            // A request made while this one ran starts only now, so results are never
            // attributed to the wrong network.
            if (root._pendingConnect) {
                const next = root._pendingConnect;
                root._pendingConnect = null;
                root._startConnect(next.ssid, next.password);
            }
        }
    }

    // Disconnect Wi-Fi process
    Process {
        id: wifiDisconnectProc
        onExited: root.refresh()
    }

    // Saved connections list process (nmcli)
    Process {
        id: savedConnsProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT", "con", "show"]
        // One stdout line per connection → accumulate and publish once on exit
        // (previously each line replaced the list, so only the last one survived).
        property var acc: []
        onStarted: acc = []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = root.nmSplit(data.trim());
                if (parts.length < 4) return;
                const type = parts[2].trim();
                const name = parts[0].trim();
                if ((type === "802-11-wireless" || type === "wifi") && name !== "Deloway-Hotspot") {
                    savedConnsProc.acc.push({ name: name, uuid: parts[1].trim(), type: "wifi", autoconnect: parts[3].trim() === "yes" });
                }
            }
        }
        onExited: root.savedConnections = savedConnsProc.acc.slice()
    }

    // Forget / delete connection process
    Process {
        id: forgetConnProc
        onExited: {
            savedConnsProc.running = true;
            statusProc.running = true;
        }
    }

    // IP details process
    Process {
        id: ipDetailsProc
        command: ["sh", "-c", "ip -j addr; echo '---ROUTES---'; ip -j route show default; echo '---DNS---'; nmcli -t -f IP4.DNS dev show 2>/dev/null || true"]
        stdout: SplitParser {
            splitMarker: "\n"
            property string accumulator: ""
            onRead: data => {
                accumulator += data + "\n";
            }
        }
        onExited: {
            try {
                const fullText = ipDetailsProc.stdout.accumulator;
                ipDetailsProc.stdout.accumulator = "";

                const sections = fullText.split("---ROUTES---");
                const addrPart = sections[0] || "";
                let routePart = "";
                let dnsPart = "";

                if (sections.length > 1) {
                    const subSections = sections[1].split("---DNS---");
                    routePart = subSections[0] || "";
                    dnsPart = subSections[1] || "";
                }

                let iface = "";
                let gw = "";
                let ipAddr = "";
                let macAddr = "";
                const dnsList = [];

                // Parse routes
                try {
                    const routes = JSON.parse(routePart.trim());
                    if (Array.isArray(routes) && routes.length > 0) {
                        gw = routes[0].gateway || "";
                        iface = routes[0].dev || "";
                    }
                } catch (e) {}

                // Parse addrs
                try {
                    const addrs = JSON.parse(addrPart.trim());
                    if (Array.isArray(addrs)) {
                        for (let i = 0; i < addrs.length; i++) {
                            const dev = addrs[i];
                            if (iface && dev.ifname !== iface) continue;
                            if (!iface && (dev.ifname.startsWith("wl") || dev.ifname.startsWith("en"))) {
                                iface = dev.ifname;
                            }
                            if (dev.ifname === iface) {
                                macAddr = dev.address || "";
                                const infos = dev.addr_info || [];
                                for (let j = 0; j < infos.length; j++) {
                                    if (infos[j].family === "inet") {
                                        ipAddr = infos[j].local + "/" + infos[j].prefixlen;
                                        break;
                                    }
                                }
                                break;
                            }
                        }
                    }
                } catch (e) {}

                // Parse DNS
                const dnsLines = dnsPart.trim().split("\n");
                for (let k = 0; k < dnsLines.length; k++) {
                    const l = dnsLines[k].trim();
                    if (l.indexOf("IP4.DNS") !== -1 && l.indexOf(":") !== -1) {
                        const dnsVal = l.split(":")[1].trim();
                        if (dnsVal && dnsList.indexOf(dnsVal) === -1) {
                            dnsList.push(dnsVal);
                        }
                    }
                }

                root.ipDetails = {
                    "ipv4": ipAddr,
                    "gateway": gw,
                    "dns": dnsList,
                    "interface": iface,
                    "mac": macAddr
                };
            } catch (e) {}
        }
    }

    // Hotspot action process (start/stop)
    Process {
        id: hotspotActionProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const res = JSON.parse(data.trim());
                    if (res.enabled !== undefined) root.hotspotEnabled = res.enabled;
                    root.hotspotError = res.success === false ? root.hotspotMessage(res) : "";
                } catch (e) {}
            }
        }
        onExited: root.refresh()
    }

    // Hotspot configure process
    Process {
        id: hotspotConfigureProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const res = JSON.parse(data.trim());
                    if (res.success) {
                        root.hotspotError = "";
                        root.hotspotSaveSuccess = I18n.isRTL ? "تم حفظ إعدادات نقطة الاتصال" : "Hotspot saved successfully";
                        if (res.ssid) root.hotspotSsid = res.ssid;
                        if (res.password) root.hotspotPassword = res.password;
                    } else {
                        root.hotspotError = root.hotspotMessage(res) || (I18n.isRTL ? "فشل حفظ الإعدادات" : "Failed to save configuration");
                        root.hotspotSaveSuccess = "";
                    }
                } catch (e) {
                    root.hotspotError = I18n.isRTL ? "خطأ في قراءة النتيجة" : "Error parsing response";
                }
            }
        }
        onExited: root.refresh()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API Methods
    // ─────────────────────────────────────────────────────────────────────────

    function refresh() {
        statusProc.running = true;
        savedConnsProc.running = true;
        ipDetailsProc.running = true;
    }

    function toggleWifi() {
        const next = !root.wifiEnabled;
        wifiToggleProc.running = true;
        root.wifiEnabled = next;
    }

    function scanWifi() {
        wifiRescanProc.running = true;
    }

    // `nmcli -t` escapes ':' and '\\' inside values ("Cafe\\:Guest"): split on unescaped
    // colons only, then unescape.
    function nmSplit(line) {
        const out = []; let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (c === ":") { out.push(cur); cur = ""; } else cur += c;
        }
        out.push(cur);
        return out;
    }

    // Latest tap wins: while an attempt is running (nmcli can take ~25 s), a new
    // request is held and started when it exits (starting a busy Process only
    // queued a restart with whatever command was set last).
    property var _pendingConnect: null
    function connectWifi(ssid, password) {
        if (!ssid) return;
        if (wifiConnectProc.running) {
            root._pendingConnect = { ssid: ssid, password: password || "" };
            return;
        }
        root._startConnect(ssid, password);
    }
    function _startConnect(ssid, password) {
        root.connectingSsid = ssid;
        root.networkError = "";
        const cmd = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "connect", ssid];
        if (password && password.length > 0) {
            cmd.push(password);
        }
        wifiConnectProc.targetSsid = ssid;
        root.passwordRequiredSsid = "";
        wifiConnectProc.command = cmd;
        wifiConnectProc.running = true;
    }

    function disconnectWifi() {
        const dev = (root.networkData && root.networkData.wifi && root.networkData.wifi.device)
            ? root.networkData.wifi.device
            : (root.ipDetails && root.ipDetails.interface ? root.ipDetails.interface : "wlan0");
        wifiDisconnectProc.command = ["nmcli", "dev", "disconnect", dev];
        wifiDisconnectProc.running = true;
    }

    function forgetConnection(nameOrUuid) {
        if (!nameOrUuid) return;
        forgetConnProc.command = ["nmcli", "con", "delete", nameOrUuid];
        forgetConnProc.running = true;
    }

    // A helper result → user-facing text: known error codes are translated, anything else
    // (NetworkManager's own message) is shown as reported.
    function hotspotMessage(res) {
        if (!res) return "";
        return res.error_code ? I18n.tr("hotspot_err_" + res.error_code, res.error || "") : (res.error || "");
    }

    function toggleHotspot() {
        root.hotspotError = "";
        root.hotspotSaveSuccess = "";
        const action = root.hotspotEnabled ? "hotspot-stop" : "hotspot-start";
        hotspotActionProc.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", action];
        hotspotActionProc.running = true;
    }

    function configureHotspot(ssid, password) {
        root.hotspotError = "";
        root.hotspotSaveSuccess = "";
        if (!ssid || ssid.trim().length === 0) {
            root.hotspotError = I18n.isRTL ? "اسم الشبكة لا يمكن أن يكون فارغاً" : "SSID cannot be empty";
            return;
        }
        if (!password || password.length < 8) {
            root.hotspotError = I18n.isRTL ? "كلمة المرور يجب ألا تقل عن 8 خانات" : "Password must be at least 8 characters";
            return;
        }
        hotspotConfigureProc.command = ["python3", ConfigManager.projectDir + "/scripts/deloway-network.py", "hotspot-configure", ssid.trim(), password];
        hotspotConfigureProc.running = true;
    }

    // Periodic & Lifecycle
    Component.onCompleted: {
        root.refresh();
    }
}
