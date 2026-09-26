pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

Item {
    id: root

    // Revision counter to force reactivity when DesktopEntries scans complete
    property int _entriesRevision: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root._entriesRevision++;
        }
    }

    // Measured index build time in milliseconds
    property real buildTimeMs: 0

    // ─────────────────────────────────────────────────────────────────────
    // State Persistence: ~/.local/state/deloway/launcher-state.json
    // ─────────────────────────────────────────────────────────────────────
    readonly property string stateDirPath: Quickshell.env("HOME") + "/.local/state/deloway"
    readonly property string stateFilePath: stateDirPath + "/launcher-state.json"

    property var stateData: ({ "usage": {} })

    FileView {
        id: stateFile
        path: root.stateFilePath
        watchChanges: false
        preload: true

        onTextChanged: {
            root.loadState();
        }
    }

    function loadState() {
        try {
            const raw = stateFile.text();
            if (raw && raw.trim().length > 2) {
                const parsed = JSON.parse(raw);
                if (parsed && typeof parsed === "object" && parsed.usage) {
                    stateData = parsed;
                    return;
                }
            }
        } catch (e) {
            // Ignore parse errors, fallback to empty
        }
        stateData = { "usage": {} };
    }

    Timer {
        id: saveDebounceTimer
        interval: 2000
        repeat: false
        onTriggered: root.writeStateNow()
    }

    Process {
        id: saveStateProcess
    }

    function recordLaunch(appId) {
        if (!appId) return;
        const cleanId = appId.toLowerCase().replace(/\.desktop$/, "");
        const curUsage = (stateData && stateData.usage) ? stateData.usage : {};
        const prev = curUsage[cleanId] || { count: 0, lastUsed: 0 };
        curUsage[cleanId] = {
            count: (prev.count || 0) + 1,
            lastUsed: Date.now()
        };
        stateData = { "usage": curUsage };
        saveDebounceTimer.restart();
    }

    function writeStateNow() {
        try {
            const jsonStr = JSON.stringify(stateData || { "usage": {} }, null, 2);
            saveStateProcess.exec(["bash", "-c", "mkdir -p " + root.stateDirPath + " && cat << 'EOF' > " + root.stateFilePath + "\n" + jsonStr + "\nEOF"]);
        } catch (e) {
            // Ignore write errors
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Safe Math Calculator (Zero eval, Recursive Descent Parser)
    // ─────────────────────────────────────────────────────────────────────
    function evaluateMath(expr) {
        if (!expr) return null;
        const clean = expr.trim();
        const hasMathOp = /[\+\-\*\/\%\^\(\)]/.test(clean) ||
                          /\b(sqrt|abs|sin|cos|tan|log|ln|floor|ceil|round|pi|e)\b/i.test(clean);
        if (!hasMathOp) return null;
        if (!/^[\d\s\+\-\*\/\%\^\(\)\.\,a-zA-Z]+$/.test(clean)) return null;

        let pos = 0;
        const len = clean.length;

        function peek() {
            while (pos < len && clean[pos] === " ") pos++;
            return pos < len ? clean[pos] : null;
        }

        function getWord() {
            let start = pos;
            while (pos < len && /[a-zA-Z_]/.test(clean[pos])) pos++;
            return clean.slice(start, pos).toLowerCase();
        }

        function getNumber() {
            let start = pos;
            let hasDot = false;
            while (pos < len && (/[0-9]/.test(clean[pos]) || (clean[pos] === "." && !hasDot))) {
                if (clean[pos] === ".") hasDot = true;
                pos++;
            }
            return parseFloat(clean.slice(start, pos));
        }

        function parseExpr() {
            let left = parseTerm();
            while (true) {
                let ch = peek();
                if (ch === "+") { pos++; left = left + parseTerm(); }
                else if (ch === "-") { pos++; left = left - parseTerm(); }
                else break;
            }
            return left;
        }

        function parseTerm() {
            let left = parseFactor();
            while (true) {
                let ch = peek();
                if (ch === "*") { pos++; left = left * parseFactor(); }
                else if (ch === "/") {
                    pos++;
                    let denom = parseFactor();
                    if (denom === 0) throw new Error("ZeroDivision");
                    left = left / denom;
                }
                else if (ch === "%") { pos++; left = left % parseFactor(); }
                else break;
            }
            return left;
        }

        function parseFactor() {
            let left = parseUnary();
            let ch = peek();
            if (ch === "^") {
                pos++;
                let right = parseFactor();
                return Math.pow(left, right);
            }
            return left;
        }

        function parseUnary() {
            let ch = peek();
            if (ch === "+") { pos++; return parseUnary(); }
            if (ch === "-") { pos++; return -parseUnary(); }
            return parsePrimary();
        }

        function parsePrimary() {
            let ch = peek();
            if (ch === null) throw new Error("EOF");
            if (ch === "(") {
                pos++;
                let val = parseExpr();
                if (peek() !== ")") throw new Error("NoClosingParen");
                pos++;
                return val;
            }
            if (/[0-9\.]/.test(ch)) return getNumber();
            if (/[a-zA-Z]/.test(ch)) {
                let word = getWord();
                if (word === "pi") return Math.PI;
                if (word === "e") return Math.E;
                if (peek() === "(") {
                    pos++;
                    let arg = parseExpr();
                    if (peek() !== ")") throw new Error("NoClosingParen");
                    pos++;
                    switch (word) {
                        case "sqrt": return Math.sqrt(arg);
                        case "abs":  return Math.abs(arg);
                        case "sin":  return Math.sin(arg);
                        case "cos":  return Math.cos(arg);
                        case "tan":  return Math.tan(arg);
                        case "log":  return Math.log10(arg);
                        case "ln":   return Math.log(arg);
                        case "floor": return Math.floor(arg);
                        case "ceil":  return Math.ceil(arg);
                        case "round": return Math.round(arg);
                        default: throw new Error("UnknownFunc");
                    }
                }
                throw new Error("UnknownId");
            }
            throw new Error("BadChar");
        }

        try {
            let res = parseExpr();
            if (peek() !== null) return null;
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return Math.abs(res - Math.round(res)) < 1e-12
                    ? Math.round(res).toString()
                    : Number(res.toFixed(8)).toString();
            }
            return null;
        } catch (e) {
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Normalization & Helpers
    // ─────────────────────────────────────────────────────────────────────
    function normalizeText(text) {
        if (!text) return "";
        return text.toString().toLowerCase()
            .replace(/[\u064B-\u065F\u0670]/g, "")
            .replace(/[أإآٱ]/g, "ا")
            .replace(/ة/g, "ه")
            .replace(/ى/g, "ي")
            .trim();
    }

    function isSubsequence(needle, haystack) {
        if (!needle || !haystack) return false;
        let nIdx = 0, hIdx = 0;
        while (nIdx < needle.length && hIdx < haystack.length) {
            if (needle[nIdx] === haystack[hIdx]) {
                nIdx++;
            }
            hIdx++;
        }
        return nIdx === needle.length;
    }

    function isSubSetting(app) {
        if (!app) return false;
        const cats = app.categories || [];
        const hasSettingCat = cats.some(c =>
            c === "DesktopSettings" ||
            c === "X-XFCE-SettingsDialog" ||
            c === "X-XFCE-PersonalSettings" ||
            c === "X-GNOME-NetworkSettings"
        );
        if (hasSettingCat) return true;
        const id = (app.id || "").toLowerCase();
        if (id.includes("breezestyleconfig") || id.includes("darklystyleconfig") || id.includes("kcm_") || id.includes("geo-handler") || id === "thunar-settings") {
            return true;
        }
        return false;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Applications Index
    // ─────────────────────────────────────────────────────────────────────
    readonly property var allApps: {
        const startTime = Date.now();
        const _rev = _entriesRevision;
        const raw = Array.from(DesktopEntries.applications.values);
        const seen = new Set();
        const list = [];

        // DeloWay built-ins (Settings; the App Store while pamac-manager is installed,
        // standing in for pamac's own entry), defined once in ApplicationManager.
        const builtinKeywords = {
            "settings": ["settings", "preferences", "config", "control", "اعدادات", "إعدادات", "تفضيلات", "ضبط"],
            "store": ["store", "apps", "software", "packages", "install", "pamac", "pkg", "متجر", "تطبيقات", "برامج"]
        };
        for (const b of ApplicationManager.builtinApps) {
            list.push({
                id: b.id,
                name: b.name,
                genericName: b.comment,
                icon: b.icon,
                categories: b.categories,
                comment: b.comment,
                keywords: builtinKeywords[b.id] || [],
                startupClass: b.startupClass,
                execBasename: b.id === "store" ? "pamac-manager" : "settings",
                isWebApp: false,
                isSubSetting: false,
                execute: b.execute
            });
            seen.add(b.id);
        }
        if (ApplicationManager.storeAvailable) seen.add(ApplicationManager.storeEntryId.toLowerCase());

        // All system desktop entries actually installed on disk
        for (let i = 0; i < raw.length; i++) {
            const app = raw[i];
            if (!app || !app.name || !app.id || app.noDisplay) continue;

            const cleanId = app.id.toLowerCase().replace(/\.desktop$/, "");
            if (seen.has(cleanId) || seen.has(app.id)) continue;

            seen.add(cleanId);
            seen.add(app.id);

            // Determine if web app and command basename
            const execStr = app.execString || "";
            const isWeb = execStr.includes("--app-id") || execStr.includes("--profile-directory");
            let execBase = "";
            if (execStr.trim().length > 0) {
                const firstToken = execStr.trim().split(/\s+/)[0];
                execBase = firstToken.replace(/.*\//, "").toLowerCase();
            }

            const item = {
                id: app.id,
                name: app.name,
                genericName: app.genericName || "",
                icon: app.icon || "application-x-executable",
                categories: app.categories || ["All"],
                comment: app.comment || "",
                keywords: app.keywords || [],
                startupClass: app.startupClass || "",
                execBasename: execBase,
                isWebApp: isWeb,
                isSubSetting: false,
                actions: app.actions || [],
                desktopEntry: app,
                execute: function() { ApplicationManager.runEntry(app); }
            };
            item.isSubSetting = root.isSubSetting(item);
            list.push(item);
        }

        root.buildTimeMs = Date.now() - startTime;
        return list;
    }

    // ── App Drawer folders ─────────────────────────────────────────────
    // freedesktop `Categories=` → one folder per app. Order matters: the FIRST folder
    // whose key set intersects the app's categories wins (e.g. an IDE that is also a
    // "TextEditor" lands in Development, a game launcher tagged "Network" in Games).
    // Display order in the drawer is the order below; empty folders are hidden.
    readonly property var categoryDefs: [
        { id: "internet",    icon: "web-browser-symbolic",
          keys: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "IRCClient", "FileTransfer", "P2P", "News"] },
        { id: "media",       icon: "applications-multimedia-symbolic",
          keys: ["AudioVideo", "Audio", "Video", "Player", "Recorder", "Music", "Tuner", "TV"] },
        { id: "office",      icon: "x-office-document-symbolic",
          keys: ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ContactManagement", "Finance", "Viewer"] },
        { id: "graphics",    icon: "applications-graphics-symbolic",
          keys: ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Photography", "Scanning"] },
        { id: "development", icon: "applications-engineering-symbolic",
          keys: ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "GUIDesigner", "Profiling"] },
        { id: "games",       icon: "applications-games-symbolic",
          keys: ["Game", "Emulator"] },
        { id: "education",   icon: "applications-science-symbolic",
          keys: ["Education", "Science", "Math", "Languages", "Dictionary"] },
        { id: "system",      icon: "applications-system-symbolic",
          keys: ["System", "Settings", "Monitor", "PackageManager", "TerminalEmulator", "FileManager",
                 "HardwareSettings", "DesktopSettings", "Security"] },
        { id: "utilities",   icon: "applications-utilities-symbolic",
          keys: ["Utility", "Accessories", "Archiving", "Compression", "TextEditor", "Calculator", "Clock"] },
        { id: "other",       icon: "folder-symbolic", keys: [] }
    ]
    // Classification priority (differs from display order on purpose).
    readonly property var _categoryPriority: ["games", "development", "graphics", "media", "office",
                                              "internet", "education", "system", "utilities"]

    function categoryOf(app) {
        if (!app) return "other";
        const cats = (app.categories || []).map(c => String(c));
        if (cats.length > 0) {
            for (const id of root._categoryPriority) {
                const def = root.categoryDefs.find(d => d.id === id);
                if (def && def.keys.some(k => cats.indexOf(k) >= 0)) return id;
            }
        }
        // Browser web apps (PWAs) rarely declare categories — they're internet apps.
        if (app.isWebApp || /^(brave|chrome|chromium|msedge)-/i.test(String(app.id || ""))) return "internet";
        return "other";
    }

    // Filtered apps for drawer categories
    function getFilteredApps(category, filterQuery) {
        const q = filterQuery ? filterQuery.trim() : "";
        const normQ = normalizeText(q);
        const cat = category || "All";

        return allApps.filter(app => {
            // Category filtering
            if (cat === "All") {
                // Filter out sub-settings in "All" view per rule 3
                if (app.isSubSetting && !normQ) return false;
            } else if (cat === "System") {
                // System category includes both regular System apps and sub-settings
                const isSys = app.categories && app.categories.some(c => c.toLowerCase() === "system");
                if (!isSys && !app.isSubSetting) return false;
            } else {
                if (!app.categories) return false;
                const matchCat = app.categories.some(c => c.toLowerCase().includes(cat.toLowerCase()));
                if (!matchCat) return false;
            }

            // Query matching if provided
            if (normQ) {
                const score = scoreApp(app, normQ);
                return score > 0;
            }

            return true;
        });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Scoring & Search Algorithm
    // ─────────────────────────────────────────────────────────────────────
    function scoreApp(app, normQ) {
        if (!normQ || !app) return 0;

        const normName = normalizeText(app.name);
        const normGeneric = normalizeText(app.genericName || "");
        const normStartup = normalizeText(app.startupClass || "");
        const normExec = normalizeText(app.execBasename || "");

        let score = 0;

        // 1. Name match (Highest priority)
        if (normName === normQ) {
            score += 1000;
        } else if (normName.startsWith(normQ)) {
            score += 800;
        } else {
            const words = normName.split(/\s+/);
            if (words.some(w => w.startsWith(normQ))) {
                score += 600;
            } else if (normName.includes(normQ)) {
                score += 400;
            } else if (normQ.length >= 2 && isSubsequence(normQ, normName)) {
                score += 25;
            }
        }

        // 2. Generic name match
        if (normGeneric) {
            if (normGeneric === normQ) score += 350;
            else if (normGeneric.startsWith(normQ)) score += 300;
            else if (normGeneric.includes(normQ)) score += 200;
        }

        // 3. Keywords match
        if (app.keywords && app.keywords.length > 0) {
            for (let i = 0; i < app.keywords.length; i++) {
                const normKw = normalizeText(app.keywords[i]);
                if (normKw === normQ) { score += 200; break; }
                else if (normKw.startsWith(normQ)) { score += 150; break; }
                else if (normKw.includes(normQ)) { score += 100; break; }
            }
        }

        // 4. StartupWMClass (low weight, prefix only)
        if (normStartup && normStartup.startsWith(normQ)) {
            score += 80;
        }

        // 5. Exec basename (lowest weight, prefix only, IGNORED if isWebApp)
        if (!app.isWebApp && normExec && normExec.startsWith(normQ)) {
            score += 40;
        }

        // 6. Frequency & recency weight boost from state
        if (score > 0 && stateData && stateData.usage) {
            const cleanId = (app.id || "").toLowerCase().replace(/\.desktop$/, "");
            const usage = stateData.usage[cleanId];
            if (usage && usage.count > 0) {
                score += Math.min(usage.count * 5, 50);
            }
        }

        return score;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Settings & System Actions
    // ─────────────────────────────────────────────────────────────────────
    readonly property var settingsIndex: [
        {
            "id": "settings-main",
            "type": "setting",
            "name": I18n.isRTL ? "إعدادات النظام" : "System Settings",
            "desc": I18n.isRTL ? "فتح نافذة إعدادات DeloWay الرئيسية" : "Open DeloWay system settings",
            "icon": "settings-symbolic",
            "keywords": ["settings", "preferences", "config", "control", "اعدادات", "إعدادات", "تفضيلات", "ضبط"]
        },
        {
            "id": "appearance",
            "type": "setting",
            "name": I18n.isRTL ? "المظهر والسمة" : "Appearance & Theme",
            "desc": I18n.isRTL ? "الوضع الداكن، الفاتح، والشفافية" : "Dark Mode, Light Mode, Contrast",
            "icon": "applications-graphics-symbolic",
            "keywords": ["theme", "dark", "light", "color", "appearance", "مظهر", "سمة", "داكن", "فاتح", "الوان", "اعدادات", "إعدادات"]
        },
        {
            "id": "desktop",
            "type": "setting",
            "name": I18n.isRTL ? "سطح المكتب والخلفية" : "Desktop & Wallpaper",
            "desc": I18n.isRTL ? "أوضاع سطح المكتب، الأيقونات، والودجات" : "Desktop mode, icons, widgets, and wallpaper",
            "icon": "user-home-symbolic",
            "keywords": ["desktop", "wallpaper", "background", "icons", "clean", "widgets", "خلفية", "سطح المكتب", "ايقونات"]
        },
        {
            "id": "dock",
            "type": "setting",
            "name": I18n.isRTL ? "شريط المهام" : "Dock Settings",
            "desc": I18n.isRTL ? "أوضاع العرض، الإخفاء التلقائي، ومقاس الأيقونات" : "Dock mode, auto-hide, icon size",
            "icon": "view-app-grid-symbolic",
            "keywords": ["dock", "taskbar", "autohide", "size", "pin", "شريط", "مهام", "اخفاء"]
        },
        {
            "id": "topbar",
            "type": "setting",
            "name": I18n.isRTL ? "الشريط العلوي والكبسولات" : "Top Bar & Capsules",
            "desc": I18n.isRTL ? "صيغة الساعة، مساحات العمل، وشعار النظام" : "Clock format, workspaces count, brand logo",
            "icon": "preferences-system-symbolic",
            "keywords": ["topbar", "bar", "clock", "workspaces", "brand", "علوي", "شريط", "ساعة", "كبسولة"]
        },
        {
            "id": "windows",
            "type": "setting",
            "name": I18n.isRTL ? "إدارة النوافذ" : "Window Management",
            "desc": I18n.isRTL ? "حدود النوافذ، الفراغات، واستدارة الزوايا" : "Active borders, gaps, corner rounding",
            "icon": "view-fullscreen-symbolic",
            "keywords": ["window", "border", "gaps", "rounding", "hyprland", "نوافذ", "حدود", "فراغات"]
        },
        {
            "id": "shortcuts",
            "type": "setting",
            "name": I18n.isRTL ? "اختصارات لوحة المفاتيح" : "Keyboard Shortcuts",
            "desc": I18n.isRTL ? "دليل الاختصارات وورقة مفتاح Super" : "Keybindings reference and Super key cheat sheet",
            "icon": "preferences-desktop-keyboard-shortcuts-symbolic",
            "keywords": ["shortcuts", "keys", "hotkeys", "keyboard", "super", "اختصارات", "لوحة", "مفاتيح"]
        },
        {
            "id": "network",
            "type": "setting",
            "name": I18n.isRTL ? "الشبكة والواي فاي" : "Network & Wi-Fi",
            "desc": I18n.isRTL ? "الواي فاي، إيثرنت، وعنوان IP" : "Wi-Fi, Ethernet, IP address, signal",
            "icon": "network-wireless-symbolic",
            "keywords": ["network", "wifi", "internet", "ethernet", "ip", "شبكة", "واي فاي", "انترنت"]
        },
        {
            "id": "bluetooth",
            "type": "setting",
            "name": I18n.isRTL ? "البلوتوث" : "Bluetooth",
            "desc": I18n.isRTL ? "أجهزة البلوتوث، الاقتران، والمحولات" : "Bluetooth devices, pairing, adapters",
            "icon": "bluetooth-active-symbolic",
            "keywords": ["bluetooth", "pair", "device", "audio", "بلوتوث", "اقتران", "سماعات"]
        },
        {
            "id": "power",
            "type": "setting",
            "name": I18n.isRTL ? "الطاقة والبطارية" : "Power & Battery",
            "desc": I18n.isRTL ? "أنماط الطاقة، توقيت السكون، والبطارية" : "Power profiles, sleep timeout, battery status",
            "icon": "power-profile-balanced-symbolic",
            "keywords": ["power", "battery", "sleep", "profile", "طاقة", "بطارية", "سكون"]
        },
        {
            "id": "notifications",
            "type": "setting",
            "name": I18n.isRTL ? "الإشعارات" : "Notifications",
            "desc": I18n.isRTL ? "عدم الإزعاج، واللافتات" : "Do Not Disturb, banners, sounds",
            "icon": "preferences-system-notifications-symbolic",
            "keywords": ["notification", "dnd", "timeout", "alert", "اشعارات", "ازعاج", "تنبيه"]
        },
        {
            "id": "applications",
            "type": "setting",
            "name": I18n.isRTL ? "التطبيقات الافتراضية" : "Default Applications",
            "desc": I18n.isRTL ? "المتصفح، الطرفية، ومدير الملفات الافتراضي" : "Default browser, terminal, file manager",
            "icon": "applications-other-symbolic",
            "keywords": ["apps", "default", "browser", "terminal", "تطبيقات", "افتراضية", "متصفح", "طرفية"]
        },
        {
            "id": "about",
            "type": "setting",
            "name": I18n.isRTL ? "حول DeloWay" : "About DeloWay",
            "desc": I18n.isRTL ? "معلومات النظام، النواة، ومحرك Wayland" : "System info, kernel version, Wayland engine",
            "icon": "dialog-information-symbolic",
            "keywords": ["about", "deloos", "deloway", "system", "kernel", "حول", "نظام", "نواة"]
        }
    ]

    readonly property var systemActions: [
        {
            "id": "lock",
            "type": "action",
            "name": I18n.isRTL ? "قفل الشاشة" : "Lock Screen",
            "desc": I18n.isRTL ? "قفل جلسة Wayland الحالية" : "Lock current Wayland session",
            "icon": "changes-prevent-symbolic",
            "keywords": ["lock", "screen", "session", "sleep", "قفل", "شاشة", "جلسة"]
        },
        {
            "id": "logout",
            "type": "action",
            "name": I18n.isRTL ? "تسجيل الخروج" : "Log Out",
            "desc": I18n.isRTL ? "إنهاء الجلسة والعودة لمدير الدخول" : "Exit desktop session to display manager",
            "icon": "system-log-out-symbolic",
            "keywords": ["logout", "log out", "exit", "quit", "خروج", "تسجيل", "انهاء"]
        },
        {
            "id": "restart",
            "type": "action",
            "name": I18n.isRTL ? "إعادة تشغيل النظام" : "Restart System",
            "desc": I18n.isRTL ? "إعادة تشغيل الحاسوب بأمان" : "Reboot the computer safely",
            "icon": "system-reboot-symbolic",
            "keywords": ["restart", "reboot", "اعادة", "تشغيل", "ريستارت"]
        },
        {
            "id": "shutdown",
            "type": "action",
            "name": I18n.isRTL ? "إيقاف التشغيل" : "Shut Down",
            "desc": I18n.isRTL ? "إطفاء الحاسوب بالكامل" : "Power off the computer",
            "icon": "system-shutdown-symbolic",
            "keywords": ["shutdown", "power off", "turn off", "halt", "ايقاف", "اطفاء", "اغلاق"]
        }
    ]

    // ─────────────────────────────────────────────────────────────────────
    // Search (Unified Scored Results)
    // ─────────────────────────────────────────────────────────────────────
    function search(query) {
        const q = query ? query.trim() : "";
        if (!q) return [];
        const normQ = normalizeText(q);
        const results = [];

        // 1. Safe Calculator evaluation
        const mathRes = evaluateMath(q);
        if (mathRes !== null) {
            results.push({
                "id": "calc-result",
                "type": "calc",
                "name": "= " + mathRes,
                "desc": q + " • " + (I18n.isRTL ? "اضغط Enter للنسخ إلى الحافظة" : "Press Enter to copy to clipboard"),
                "icon": "accessories-calculator-symbolic",
                "isAppIcon": false,
                "score": 9999,
                "data": { "value": mathRes }
            });
        }

        // 2. Applications (scored)
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            const s = scoreApp(app, normQ);
            if (s > 0) {
                // Description: genericName or category, never raw English comment
                let desc = app.genericName;
                if (!desc && app.categories && app.categories.length > 0) {
                    desc = app.categories[0];
                }
                if (!desc) {
                    desc = I18n.isRTL ? "تطبيق" : "Application";
                }

                results.push({
                    "id": app.id,
                    "type": "app",
                    "name": app.name,
                    "desc": desc,
                    "icon": app.icon,
                    "isAppIcon": true,
                    "score": s,
                    "data": app
                });
            }
        }

        // 3. Settings
        for (let i = 0; i < settingsIndex.length; i++) {
            const s = settingsIndex[i];
            const normName = normalizeText(s.name);
            const normDesc = normalizeText(s.desc);
            const matchesKw = s.keywords.some(k => normalizeText(k).includes(normQ));

            if (normName.includes(normQ) || normDesc.includes(normQ) || matchesKw) {
                let score = 300;
                if (normName === normQ) score = 950;
                else if (normName.startsWith(normQ)) score = 750;
                else if (matchesKw) score = 500;

                results.push({
                    "id": s.id,
                    "type": "setting",
                    "name": s.name,
                    "desc": s.desc,
                    "icon": s.icon,
                    "isAppIcon": false,
                    "score": score,
                    "data": s
                });
            }
        }

        // 4. System actions
        for (let i = 0; i < systemActions.length; i++) {
            const a = systemActions[i];
            const normName = normalizeText(a.name);
            const normDesc = normalizeText(a.desc);
            const matchesKw = a.keywords.some(k => normalizeText(k).includes(normQ));

            if (normName.includes(normQ) || normDesc.includes(normQ) || matchesKw) {
                let score = 250;
                if (normName === normQ) score = 900;
                else if (normName.startsWith(normQ)) score = 700;

                results.push({
                    "id": a.id,
                    "type": "action",
                    "name": a.name,
                    "desc": a.desc,
                    "icon": a.icon,
                    "isAppIcon": false,
                    "score": score,
                    "data": a
                });
            }
        }

        // Sort by score descending
        results.sort((a, b) => b.score - a.score);

        return results;
    }

    Component.onCompleted: {
        loadState();
    }
}
