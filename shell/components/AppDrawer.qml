import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

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

    WlrLayershell.namespace: "deloway:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.appDrawerOpen
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    visible: ShellState.appDrawerOpen || drawerHost.opacity > 0.005
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────
    // Design tokens (Strict monochrome OLED deep black aesthetic)
    // ─────────────────────────────────────────────────────────────────────
    readonly property int radiusCard: Theme.notchRadiusWindow
    readonly property int radiusPanel: Theme.notchRadiusPanel
    readonly property int radiusItem: Theme.notchRadiusCard
    readonly property int radiusPill: Theme.notchRadiusPill

    readonly property color colorBackground: Theme.notchBackground
    readonly property color colorSurface: Theme.notchSurface
    readonly property color colorElevated: Theme.notchSurfaceElevated

    readonly property color colorBorder: Theme.notchBorder
    readonly property color colorBorderSoft: Theme.notchBorderSubtle
    readonly property color colorBorderStrong: Theme.notchBorderHighlight

    readonly property color colorHover: Theme.notchSurfaceHover
    readonly property color colorHoverStrong: Theme.notchSurfaceActive
    readonly property color colorSelected: Theme.notchSurfaceActive

    readonly property color colorText: Theme.notchText
    readonly property color colorTextSecondary: Theme.notchTextSecondary
    readonly property color colorTextTertiary: Theme.notchTextTertiary

    readonly property color colorAccent: Theme.notchText
    readonly property color colorUrgent: Theme.colors.urgent
    readonly property color colorSuccess: Theme.colors.success

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────
    property string filterQuery: ""
    property string selectedCategory: "All"
    property int selectedIndex: 0
    property bool isGridView: true

    readonly property var allApps: LauncherIndex.allApps

    // ─────────────────────────────────────────────────────────────────────
    // Clipboard helper process for calculator
    // ─────────────────────────────────────────────────────────────────────
    Process {
        id: wlCopyProcess
        command: ["wl-copy", ""]
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
    // Arabic & English text normalization
    // ─────────────────────────────────────────────────────────────────────
    function normalizeText(text) {
        if (!text) return "";
        return text.toString().toLowerCase()
            .replace(/[\u064B-\u065F\u0670]/g, "")
            .replace(/[أإآٱ]/g, "ا")
            .replace(/ة/g, "ه")
            .replace(/ى/g, "ي");
    }

    // ─────────────────────────────────────────────────────────────────────
    // Settings index for unified search
    // ─────────────────────────────────────────────────────────────────────
    readonly property var settingsIndex: [
        {
            "id": "settings-main",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "إعدادات النظام" : "System Settings",
            "desc": I18n.isRTL ? "فتح نافذة إعدادات DeloWay الرئيسية" : "Open DeloWay system settings",
            "icon": "settings-symbolic",
            "keywords": ["settings", "preferences", "config", "control", "اعدادات", "إعدادات", "تفضيلات", "ضبط"]
        },
        {
            "id": "appearance",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "المظهر والسمة" : "Appearance & Theme",
            "desc": I18n.isRTL ? "الوضع الداكن، الفاتح، والشفافية" : "Dark Mode, Light Mode, Contrast",
            "icon": "applications-graphics-symbolic",
            "keywords": ["theme", "dark", "light", "color", "appearance", "مظهر", "سمة", "داكن", "فاتح", "الوان", "اعدادات", "إعدادات"]
        },
        {
            "id": "desktop",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "سطح المكتب والخلفية" : "Desktop & Wallpaper",
            "desc": I18n.isRTL ? "أوضاع سطح المكتب، الأيقونات، والودجات" : "Desktop mode, icons, widgets, and wallpaper",
            "icon": "user-home-symbolic",
            "keywords": ["desktop", "wallpaper", "background", "icons", "clean", "widgets", "خلفية", "سطح المكتب", "ايقونات"]
        },
        {
            "id": "dock",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "شريط المهام" : "Dock Settings",
            "desc": I18n.isRTL ? "أوضاع العرض، الإخفاء التلقائي، ومقاس الأيقونات" : "Dock mode, auto-hide, icon size",
            "icon": "view-app-grid-symbolic",
            "keywords": ["dock", "taskbar", "autohide", "size", "pin", "شريط", "مهام", "اخفاء"]
        },
        {
            "id": "topbar",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "الشريط العلوي والكبسولات" : "Top Bar & Capsules",
            "desc": I18n.isRTL ? "صيغة الساعة، مساحات العمل، وشعار النظام" : "Clock format, workspaces count, brand logo",
            "icon": "preferences-system-symbolic",
            "keywords": ["topbar", "bar", "clock", "workspaces", "brand", "علوي", "شريط", "ساعة", "كبسولة"]
        },
        {
            "id": "windows",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "إدارة النوافذ" : "Window Management",
            "desc": I18n.isRTL ? "حدود النوافذ، الفراغات، واستدارة الزوايا" : "Active borders, gaps, corner rounding",
            "icon": "view-fullscreen-symbolic",
            "keywords": ["window", "border", "gaps", "rounding", "hyprland", "نوافذ", "حدود", "فراغات"]
        },
        {
            "id": "shortcuts",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "اختصارات لوحة المفاتيح" : "Keyboard Shortcuts",
            "desc": I18n.isRTL ? "دليل الاختصارات وورقة مفتاح Super" : "Keybindings reference and Super key cheat sheet",
            "icon": "preferences-desktop-keyboard-shortcuts-symbolic",
            "keywords": ["shortcuts", "keys", "hotkeys", "keyboard", "super", "اختصارات", "لوحة", "مفاتيح"]
        },
        {
            "id": "network",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "الشبكة والواي فاي" : "Network & Wi-Fi",
            "desc": I18n.isRTL ? "الواي فاي، إيثرنت، وعنوان IP" : "Wi-Fi, Ethernet, IP address, signal",
            "icon": "network-wireless-symbolic",
            "keywords": ["network", "wifi", "internet", "ethernet", "ip", "شبكة", "واي فاي", "انترنت"]
        },
        {
            "id": "bluetooth",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "البلوتوث" : "Bluetooth",
            "desc": I18n.isRTL ? "أجهزة البلوتوث، الاقتران، والمحولات" : "Bluetooth devices, pairing, adapters",
            "icon": "bluetooth-active-symbolic",
            "keywords": ["bluetooth", "pair", "device", "audio", "بلوتوث", "اقتران", "سماعات"]
        },
        {
            "id": "power",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "الطاقة والبطارية" : "Power & Battery",
            "desc": I18n.isRTL ? "أنماط الطاقة، توقيت السكون، والبطارية" : "Power profiles, sleep timeout, battery status",
            "icon": "power-profile-balanced-symbolic",
            "keywords": ["power", "battery", "sleep", "profile", "طاقة", "بطارية", "سكون"]
        },
        {
            "id": "notifications",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "الإشعارات" : "Notifications",
            "desc": I18n.isRTL ? "عدم الإزعاج، واللافتات" : "Do Not Disturb, banners, sounds",
            "icon": "preferences-system-notifications-symbolic",
            "keywords": ["notification", "dnd", "timeout", "alert", "اشعارات", "ازعاج", "تنبيه"]
        },
        {
            "id": "applications",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "التطبيقات الافتراضية" : "Default Applications",
            "desc": I18n.isRTL ? "المتصفح، الطرفية، ومدير الملفات الافتراضي" : "Default browser, terminal, file manager",
            "icon": "applications-other-symbolic",
            "keywords": ["apps", "default", "browser", "terminal", "تطبيقات", "افتراضية", "متصفح", "طرفية"]
        },
        {
            "id": "about",
            "type": "setting",
            "badge": "SETTING",
            "name": I18n.isRTL ? "حول DeloWay" : "About DeloWay",
            "desc": I18n.isRTL ? "معلومات النظام، النواة، ومحرك Wayland" : "System info, kernel version, Wayland engine",
            "icon": "dialog-information-symbolic",
            "keywords": ["about", "deloos", "deloway", "system", "kernel", "حول", "نظام", "نواة"]
        }
    ]

    // ─────────────────────────────────────────────────────────────────────
    // System actions
    // ─────────────────────────────────────────────────────────────────────
    readonly property var systemActions: [
        {
            "id": "lock",
            "type": "action",
            "badge": "SYSTEM",
            "name": I18n.isRTL ? "قفل الشاشة" : "Lock Screen",
            "desc": I18n.isRTL ? "قفل جلسة Wayland الحالية" : "Lock current Wayland session",
            "icon": "changes-prevent-symbolic",
            "keywords": ["lock", "screen", "session", "sleep", "قفل", "شاشة", "جلسة"]
        },
        {
            "id": "logout",
            "type": "action",
            "badge": "SYSTEM",
            "name": I18n.isRTL ? "تسجيل الخروج" : "Log Out",
            "desc": I18n.isRTL ? "إنهاء الجلسة والعودة لمدير الدخول" : "Exit desktop session to display manager",
            "icon": "system-log-out-symbolic",
            "keywords": ["logout", "log out", "exit", "quit", "خروج", "تسجيل", "انهاء"]
        },
        {
            "id": "restart",
            "type": "action",
            "badge": "SYSTEM",
            "name": I18n.isRTL ? "إعادة تشغيل النظام" : "Restart System",
            "desc": I18n.isRTL ? "إعادة تشغيل الحاسوب بأمان" : "Reboot the computer safely",
            "icon": "system-reboot-symbolic",
            "keywords": ["restart", "reboot", "اعادة", "تشغيل", "ريستارت"]
        },
        {
            "id": "shutdown",
            "type": "action",
            "badge": "SYSTEM",
            "name": I18n.isRTL ? "إيقاف التشغيل" : "Shut Down",
            "desc": I18n.isRTL ? "إطفاء الحاسوب بالكامل" : "Power off the computer",
            "icon": "system-shutdown-symbolic",
            "keywords": ["shutdown", "power off", "turn off", "halt", "ايقاف", "اطفاء", "اغلاق"]
        }
    ]

    // ─────────────────────────────────────────────────────────────────────
    // Computed lists & Search results
    // ─────────────────────────────────────────────────────────────────────
    readonly property var universalResults: LauncherIndex.search(filterQuery)

    readonly property var filteredApps: LauncherIndex.getFilteredApps(selectedCategory, filterQuery)

    readonly property var pinnedList: {
        if (selectedCategory !== "All") return root.filteredApps;

        const list = [];
        for (let i = 0; i < ApplicationManager.pinnedAppIds.length; i++) {
            const id = ApplicationManager.pinnedAppIds[i];
            const app = ApplicationManager.findApp(id);
            if (app) list.push(app);
        }
        return list;
    }

    readonly property var allAppsWithoutPinned: {
        if (selectedCategory !== "All") return root.filteredApps;

        const pinnedSet = new Set(
            ApplicationManager.pinnedAppIds.map(id =>
                id.toLowerCase().replace(/\.desktop$/, "")
            )
        );

        return root.allApps.filter(app =>
            !pinnedSet.has(app.id.toLowerCase().replace(/\.desktop$/, ""))
        );
    }

    // ─────────────────────────────────────────────────────────────────────
    // Helpers & Execution
    // ─────────────────────────────────────────────────────────────────────
    function cycleCategory(dir) {
        const cats = ["All", "System", "Development", "Network", "AudioVideo", "Office", "Graphics", "Game", "Utility"];
        let idx = cats.indexOf(selectedCategory);
        if (idx === -1) idx = 0;
        idx = (idx + dir + cats.length) % cats.length;
        selectedCategory = cats[idx];
    }

    function executeItem(item) {
        if (!item) return;

        drawerContextMenu.hide();
        ShellState.closeAppDrawer();

        if (item.type === "calc") {
            if (item.data && item.data.value) {
                wlCopyProcess.exec(["wl-copy", String(item.data.value)]);
            }
        } else if (item.type === "app") {
            if (item.data && typeof item.data.execute === "function")
                item.data.execute();
            else if (item.data)
                ApplicationManager.launchApp(item.data);
        } else if (item.type === "setting") {
            if (item.id === "settings-main")
                ShellState.toggleSettingsApp();
            else
                ShellState.openSettingsTab(item.id);
        } else if (item.type === "store") {
            ShellState.openAppStore("all", item.data.query);
        } else if (item.type === "action") {
            if (item.id === "lock") {
                ShellState.lock();
            } else if (item.id === "logout") {
                Hyprland.dispatch("exec hyprctl dispatch exit");
            } else if (item.id === "restart") {
                Hyprland.dispatch("exec systemctl reboot");
            } else if (item.id === "shutdown") {
                Hyprland.dispatch("exec systemctl poweroff");
            }
        }
    }

    function launchApp(app) {
        if (!app) return;

        drawerContextMenu.hide();
        ShellState.closeAppDrawer();

        if (app.id) {
            LauncherIndex.recordLaunch(app.id);
        }

        if (typeof app.execute === "function")
            app.execute();
        else
            ApplicationManager.launchApp(app);
    }

    // Debounce timer for smooth typing (60ms)
    Timer {
        id: searchDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            root.filterQuery = searchInput.text;
            root.selectedIndex = 0;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Visual Presentation (Backdrop + Centered OLED Launcher)
    // ─────────────────────────────────────────────────────────────────────

    // Dimmed backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.50)
        opacity: drawerHost.opacity

        Behavior on opacity {
            NumberAnimation {
                duration: drawerHost.isOpen ? 180 : 130
                easing.type: drawerHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.closeAppDrawer()
        }
    }

    // Centered Launcher Card (~640px)
    Item {
        id: drawerHost
        anchors.centerIn: parent
        width: Math.min(640, root.width - 32)
        height: Math.min(540, root.height - 80)

        readonly property bool isOpen: ShellState.appDrawerOpen
        opacity: isOpen ? 1.0 : 0.0
        scale: isOpen ? 1.0 : 0.96
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: drawerHost.isOpen ? 180 : 130
                easing.type: drawerHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: drawerHost.isOpen ? 180 : 130
                easing.type: drawerHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }


        Rectangle {
            id: drawerCard
            anchors.fill: parent
            radius: root.radiusCard
            color: root.colorBackground
            border.color: root.colorBorder
            border.width: 1
            z: 1

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space16
                spacing: Theme.space8

                // ─────────────────────────────────────────────────────────
                // 1. Search Bar & Keyboard shortcuts hint
                // ─────────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    DeloTextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: root.radiusPill
                        customBackground: root.colorSurface
                        customBorderColor: root.colorBorder
                        customFocusBorderColor: root.colorBorderStrong
                        showSearchIcon: true
                        placeholderText: I18n.isRTL ? "ابحث في التطبيقات، احسب، أو نفّذ أوامر النظام..." : "Search apps, calculate, run system actions..."

                        onTextChanged: {
                            if (text === "") {
                                searchDebounceTimer.stop();
                                root.filterQuery = "";
                                root.selectedIndex = 0;
                            } else {
                                searchDebounceTimer.restart();
                            }
                        }

                        textInput.Keys.onEscapePressed: ShellState.closeAppDrawer()

                        textInput.Keys.onDownPressed: {
                            if (root.filterQuery.trim() !== "") {
                                if (root.universalResults.length > 0)
                                    root.selectedIndex = (root.selectedIndex + 1) % root.universalResults.length;
                            }
                        }

                        textInput.Keys.onUpPressed: {
                            if (root.filterQuery.trim() !== "") {
                                if (root.universalResults.length > 0)
                                    root.selectedIndex = (root.selectedIndex - 1 + root.universalResults.length) % root.universalResults.length;
                            }
                        }

                        textInput.Keys.onReturnPressed: {
                            if (root.filterQuery.trim() !== "" && root.universalResults.length > 0) {
                                root.executeItem(
                                    root.universalResults[
                                        Math.min(root.selectedIndex, root.universalResults.length - 1)
                                    ]
                                );
                            } else if (root.filteredApps.length > 0) {
                                root.launchApp(root.filteredApps[0]);
                            }
                        }

                        textInput.Keys.onTabPressed: {
                            if (root.filterQuery.trim() === "") {
                                root.cycleCategory(1);
                            } else if (root.universalResults.length > 0) {
                                root.selectedIndex = (root.selectedIndex + 1) % root.universalResults.length;
                            }
                        }

                        textInput.Keys.onBacktabPressed: {
                            if (root.filterQuery.trim() === "") {
                                root.cycleCategory(-1);
                            } else if (root.universalResults.length > 0) {
                                root.selectedIndex = (root.selectedIndex - 1 + root.universalResults.length) % root.universalResults.length;
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.color: root.colorBorderSoft
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.DemiBold
                            renderType: Theme.renderType
                            color: root.colorTextTertiary
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // 2. Horizontal Category Bar (when search is empty)
                // ─────────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.filterQuery.trim() === ""
                    spacing: Theme.space8

                    ListView {
                        id: categoryBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        orientation: ListView.Horizontal
                        spacing: Theme.space4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        model: [
                            { "id": "All", "label": I18n.tr("all_apps"), "icon": "applications-all-symbolic" },
                            { "id": "System", "label": I18n.tr("category_system"), "icon": "preferences-system-symbolic" },
                            { "id": "Development", "label": I18n.tr("category_development"), "icon": "applications-development-symbolic" },
                            { "id": "Network", "label": I18n.tr("category_internet"), "icon": "applications-internet-symbolic" },
                            { "id": "AudioVideo", "label": I18n.tr("category_multimedia"), "icon": "applications-multimedia-symbolic" },
                            { "id": "Office", "label": I18n.tr("category_office"), "icon": "applications-office-symbolic" },
                            { "id": "Graphics", "label": I18n.tr("category_graphics"), "icon": "applications-graphics-symbolic" },
                            { "id": "Game", "label": I18n.tr("category_games"), "icon": "applications-games-symbolic" },
                            { "id": "Utility", "label": I18n.tr("category_utilities"), "icon": "applications-utilities-symbolic" }
                        ]

                        delegate: Rectangle {
                            id: catPill
                            required property var modelData
                            readonly property bool isSelected: root.selectedCategory === catPill.modelData.id

                            height: 28
                            implicitWidth: catRow.implicitWidth + Theme.space16
                            radius: Theme.radiusSmall
                            color: catPill.isSelected ? root.colorSelected : (catMa.containsMouse ? root.colorHover : "transparent")
                            border.color: catPill.isSelected ? root.colorBorderStrong : (catMa.containsMouse ? root.colorBorder : root.colorBorderSoft)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                id: catRow
                                anchors.centerIn: parent
                                spacing: Theme.space4

                                SymbolicIcon {
                                    iconSize: 13
                                    source: catPill.modelData.icon
                                    iconColor: catPill.isSelected ? root.colorText : root.colorTextSecondary
                                    Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
                                }

                                Text {
                                    text: catPill.modelData.label
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: catPill.isSelected ? Font.DemiBold : Font.Normal
                                    color: catPill.isSelected ? root.colorText : root.colorTextSecondary
                                    renderType: Theme.renderType
                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                }
                            }

                            MouseArea {
                                id: catMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedCategory = catPill.modelData.id
                            }
                        }
                    }

                    // Grid / List View Toggle Button
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: viewToggleMa.containsMouse ? root.colorHover : "transparent"
                        border.color: root.colorBorderSoft
                        border.width: 1

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconSize: 13
                            source: root.isGridView ? "view-list-symbolic" : "view-grid-symbolic"
                            iconColor: root.colorTextSecondary
                        }

                        MouseArea {
                            id: viewToggleMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.isGridView = !root.isGridView
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // 3. Main Content: App Grid vs. Search Results
                // ─────────────────────────────────────────────────────────
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.filterQuery.trim() === "" ? 0 : 1

                    // ── 3A. Applications View (Grid / List) ──────────────
                    ScrollView {
                        id: appScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            width: appScroll.availableWidth
                            spacing: Theme.space8

                            // ── Pinned Section (if in 'All' category) ────
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.selectedCategory === "All" && root.pinnedList.length > 0
                                spacing: Theme.space8

                                Text {
                                    text: I18n.tr("pinned")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.DemiBold
                                    color: root.colorTextSecondary
                                    renderType: Theme.renderType
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: root.isGridView ? 5 : 1
                                    rowSpacing: Theme.space8
                                    columnSpacing: Theme.space8

                                    Repeater {
                                        model: root.pinnedList
                                        delegate: root.isGridView ? gridCardComponent : listCardComponent
                                    }
                                }
                            }

                            // ── All Apps / Category Section ──────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.space8

                                Text {
                                    text: root.selectedCategory === "All"
                                          ? (I18n.isRTL ? "جميع التطبيقات" : "All Applications")
                                          : root.selectedCategory
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.DemiBold
                                    color: root.colorTextSecondary
                                    renderType: Theme.renderType
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: root.isGridView ? 5 : 1
                                    rowSpacing: Theme.space8
                                    columnSpacing: Theme.space8

                                    Repeater {
                                        model: root.selectedCategory === "All"
                                               ? root.allAppsWithoutPinned
                                               : root.filteredApps
                                        delegate: root.isGridView ? gridCardComponent : listCardComponent
                                    }
                                }
                            }
                        }
                    }

                    // ── 3B. Universal Search Results ─────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.space8

                        // Results count and navigation legend
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: (I18n.isRTL ? "النتائج (" : "Results (") + root.universalResults.length + ")"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                font.weight: Font.DemiBold
                                color: root.colorTextSecondary
                                renderType: Theme.renderType
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: I18n.isRTL ? "↑ / ↓ للتنقل • ↵ للاختيار • Esc للإغلاق" : "↑ / ↓ navigate • ↵ select • Esc close"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Normal
                                color: root.colorTextTertiary
                                renderType: Theme.renderType
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: resultsList
                                anchors.fill: parent
                                clip: true
                                spacing: Theme.space4
                                model: root.universalResults
                                currentIndex: root.selectedIndex

                                delegate: Rectangle {
                                    id: resultItem
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected: root.selectedIndex === resultItem.index

                                    width: resultsList.width
                                    height: 48
                                    radius: root.radiusItem
                                    color: resultMouse.pressed
                                           ? root.colorHoverStrong
                                           : (resultMouse.containsMouse
                                              ? root.colorHover
                                              : (isSelected ? root.colorSelected : "transparent"))
                                    border.color: isSelected ? root.colorBorderStrong : "transparent"
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.space8
                                        anchors.rightMargin: Theme.space8
                                        spacing: Theme.space8

                                        // Icon representation
                                        Item {
                                            width: 28
                                            height: 28

                                            AppIcon {
                                                anchors.centerIn: parent
                                                visible: resultItem.modelData.isAppIcon
                                                iconSize: 26
                                                source: resultItem.modelData.icon
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                visible: !resultItem.modelData.isAppIcon
                                                width: 26
                                                height: 26
                                                radius: Theme.radiusSmall
                                                color: resultItem.modelData.id === "shutdown" || resultItem.modelData.id === "restart"
                                                       ? Qt.rgba(root.colorUrgent.r, root.colorUrgent.g, root.colorUrgent.b, 0.14)
                                                       : root.colorHover

                                                SymbolicIcon {
                                                    anchors.centerIn: parent
                                                    iconSize: 15
                                                    source: resultItem.modelData.icon
                                                    iconColor: resultItem.modelData.id === "shutdown" || resultItem.modelData.id === "restart"
                                                               ? root.colorUrgent
                                                               : (resultItem.isSelected ? root.colorText : root.colorTextSecondary)
                                                }
                                            }
                                        }

                                        // Titles & description
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: resultItem.modelData.name || ""
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(13)
                                                font.weight: resultItem.isSelected ? Font.DemiBold : Font.Medium
                                                color: root.colorText
                                                renderType: Theme.renderType
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: resultItem.modelData.desc || ""
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(10)
                                                font.weight: Font.Normal
                                                color: root.colorTextTertiary
                                                renderType: Theme.renderType
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Selection Enter hint (↵) visible only when selected
                                        Text {
                                            visible: resultItem.isSelected
                                            text: "↵"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(14)
                                            font.weight: Font.DemiBold
                                            color: root.colorTextTertiary
                                            renderType: Theme.renderType
                                        }
                                    }

                                    MouseArea {
                                        id: resultMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: root.selectedIndex = resultItem.index

                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton &&
                                                resultItem.modelData.type === "app" &&
                                                resultItem.modelData.data) {
                                                var pos = mapToItem(drawerCard, mouse.x, mouse.y);
                                                drawerContextMenu.show(resultItem.modelData.data, pos.x, pos.y);
                                            } else if (mouse.button === Qt.LeftButton) {
                                                root.executeItem(resultItem.modelData);
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty state
                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: root.universalResults.length === 0
                                spacing: Theme.space8

                                SymbolicIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    iconSize: 32
                                    source: "edit-find-symbolic"
                                    iconColor: root.colorTextTertiary
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: I18n.isRTL ? ("لا توجد نتائج تطابق \"" + root.filterQuery + "\"") : ("No matches found for \"" + root.filterQuery + "\"")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: Font.DemiBold
                                    color: root.colorTextSecondary
                                    renderType: Theme.renderType
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // 4. Compact Monochrome Footer
                // ─────────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: root.radiusPanel
                    color: root.colorSurface
                    border.color: root.colorBorderSoft
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space8
                        anchors.rightMargin: Theme.space8
                        spacing: Theme.space8

                        SymbolicIcon {
                            iconSize: 14
                            source: "deloway-symbolic"
                            iconColor: root.colorTextSecondary
                        }

                        Text {
                            text: I18n.isRTL ? "مشغّل DeloWay" : "DeloWay Launcher"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: root.colorText
                            renderType: Theme.renderType
                        }

                        Item { Layout.fillWidth: true }

                        // Store button
                        Rectangle {
                            width: 26
                            height: 26
                            radius: Theme.radiusSmall
                            color: storeBtnMa.containsMouse ? root.colorHover : "transparent"
                            border.color: root.colorBorderSoft
                            border.width: 1

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 13
                                source: "store-symbolic"
                                iconColor: root.colorTextSecondary
                            }

                            MouseArea {
                                id: storeBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.closeAppDrawer();
                                    ShellState.openAppStore();
                                }
                            }
                        }

                        // Settings button
                        Rectangle {
                            width: 26
                            height: 26
                            radius: Theme.radiusSmall
                            color: settBtnMa.containsMouse ? root.colorHover : "transparent"
                            border.color: root.colorBorderSoft
                            border.width: 1

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 13
                                source: "settings-symbolic"
                                iconColor: root.colorTextSecondary
                            }

                            MouseArea {
                                id: settBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.closeAppDrawer();
                                    ShellState.toggleSettingsApp();
                                }
                            }
                        }

                        // Power button
                        Rectangle {
                            width: 26
                            height: 26
                            radius: Theme.radiusSmall
                            color: pwrBtnMa.containsMouse ? Qt.rgba(root.colorUrgent.r, root.colorUrgent.g, root.colorUrgent.b, 0.12) : "transparent"
                            border.color: root.colorBorderSoft
                            border.width: 1

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 13
                                source: "system-shutdown-symbolic"
                                iconColor: pwrBtnMa.containsMouse ? root.colorUrgent : root.colorTextSecondary
                            }

                            MouseArea {
                                id: pwrBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.closeAppDrawer();
                                    ShellState.toggleSessionMenu();
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // App Delegate Component: Grid Card
            // ─────────────────────────────────────────────────────────────
            Component {
                id: gridCardComponent

                Rectangle {
                    id: gridCell
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: root.radiusItem
                    color: gridMa.pressed
                           ? root.colorHoverStrong
                           : (gridMa.containsMouse ? root.colorHover : root.colorSurface)
                    border.color: gridMa.containsMouse ? root.colorBorderStrong : root.colorBorderSoft
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space8
                        spacing: Theme.space4

                        AppIcon {
                            Layout.alignment: Qt.AlignHCenter
                            iconSize: 34
                            source: gridCell.modelData.icon
                        }

                        Text {
                            Layout.fillWidth: true
                            text: gridCell.modelData.name || ""
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: gridMa.containsMouse ? Font.DemiBold : Font.Medium
                            color: gridMa.containsMouse ? root.colorText : root.colorTextSecondary
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Theme.renderType
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        }
                    }

                    MouseArea {
                        id: gridMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                var pos = mapToItem(drawerCard, mouse.x, mouse.y);
                                drawerContextMenu.show(gridCell.modelData, pos.x, pos.y);
                            } else {
                                root.launchApp(gridCell.modelData);
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // App Delegate Component: List Card
            // ─────────────────────────────────────────────────────────────
            Component {
                id: listCardComponent

                Rectangle {
                    id: listCell
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: root.radiusItem
                    color: listMa.pressed
                           ? root.colorHoverStrong
                           : (listMa.containsMouse ? root.colorHover : "transparent")
                    border.color: listMa.containsMouse ? root.colorBorderStrong : root.colorBorderSoft
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space8
                        anchors.rightMargin: Theme.space8
                        spacing: Theme.space8

                        AppIcon {
                            iconSize: 28
                            source: listCell.modelData.icon
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: listCell.modelData.name || ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                font.weight: listMa.containsMouse ? Font.DemiBold : Font.Medium
                                color: root.colorText
                                elide: Text.ElideRight
                                renderType: Theme.renderType
                            }

                            Text {
                                Layout.fillWidth: true
                                text: listCell.modelData.comment || ""
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.Normal
                                color: root.colorTextTertiary
                                elide: Text.ElideRight
                                renderType: Theme.renderType
                                visible: (listCell.modelData.comment || "") !== ""
                            }
                        }

                        Rectangle {
                            visible: {
                                if (!listCell.modelData) return false;
                                return ApplicationManager.getWindowsForApp(listCell.modelData.id).length > 0;
                            }
                            width: 6
                            height: 6
                            radius: 3
                            color: root.colorSuccess
                        }
                    }

                    MouseArea {
                        id: listMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                var pos = mapToItem(drawerCard, mouse.x, mouse.y);
                                drawerContextMenu.show(listCell.modelData, pos.x, pos.y);
                            } else {
                                root.launchApp(listCell.modelData);
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // Context menu backdrop & component
            // ─────────────────────────────────────────────────────────────
            MouseArea {
                id: drawerContextMenuBackdrop
                z: 600
                anchors.fill: parent
                visible: drawerContextMenu.isOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: drawerContextMenu.hide()
            }

            Item {
                id: drawerContextMenu
                z: 620
                visible: isOpen

                property bool isOpen: false
                property var targetApp: null

                width: 214
                height: menuColumn.implicitHeight + 14

                opacity: isOpen ? 1.0 : 0.0
                scale: isOpen ? 1.0 : 0.96
                transformOrigin: Item.TopLeft

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter }
                }

                function show(app, x, y) {
                    targetApp = app;

                    var offsetX = 8;
                    var offsetY = 8;
                    var targetX = I18n.isRTL ? (x - width - offsetX) : (x + offsetX);
                    if (targetX + width > drawerCard.width - 12) {
                        targetX = x - width - offsetX;
                    }
                    if (targetX < 12) {
                        targetX = x + offsetX;
                    }
                    targetX = Math.max(12, Math.min(targetX, drawerCard.width - width - 12));

                    var targetY = y + offsetY;
                    if (targetY + height > drawerCard.height - 12) {
                        targetY = y - height - offsetY;
                    }
                    targetY = Math.max(12, Math.min(targetY, drawerCard.height - height - 12));

                    transformOrigin = (targetY < y) ? (I18n.isRTL ? Item.BottomRight : Item.BottomLeft)
                                                    : (I18n.isRTL ? Item.TopRight : Item.TopLeft);

                    drawerContextMenu.x = targetX;
                    drawerContextMenu.y = targetY;
                    isOpen = true;
                }

                function hide() {
                    isOpen = false;
                    targetApp = null;
                }

                // Drop shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: -4
                    anchors.leftMargin: -2
                    anchors.rightMargin: -2
                    radius: root.radiusItem + 2
                    color: Theme.notchShadow
                    z: 0
                }

                Rectangle {
                    z: 1
                    anchors.fill: parent
                    radius: root.radiusItem
                    color: Theme.notchBackground
                    border.color: Theme.notchBorder
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        z: 1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => mouse.accepted = true
                        onPressed: mouse => mouse.accepted = true
                    }
                }

                ColumnLayout {
                    id: menuColumn
                    z: 2
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.space8
                    spacing: Theme.space4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space8

                        AppIcon {
                            iconSize: 22
                            source: drawerContextMenu.targetApp ? drawerContextMenu.targetApp.icon : ""
                            visible: Boolean(drawerContextMenu.targetApp && drawerContextMenu.targetApp.icon)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: drawerContextMenu.targetApp
                                  ? (drawerContextMenu.targetApp.name || drawerContextMenu.targetApp.id || "")
                                  : ""
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(12)
                            font.weight: Font.DemiBold
                            color: root.colorText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Theme.renderType
                        }

                        Rectangle {
                            visible: {
                                if (!drawerContextMenu.targetApp) return false;
                                return ApplicationManager.getWindowsForApp(drawerContextMenu.targetApp.id).length > 0;
                            }
                            width: 6
                            height: 6
                            radius: 3
                            color: root.colorSuccess
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.notchBorderSubtle
                    }

                    component MenuRow: Rectangle {
                        id: menuRow
                        property string iconSource: ""
                        property string label: ""
                        property color normalIconColor: root.colorTextSecondary
                        property color hoverIconColor: root.colorText
                        property color normalTextColor: root.colorText
                        property color hoverTextColor: root.colorText
                        property color hoverBackground: root.colorHover
                        signal activated()

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: root.radiusItem
                        color: menuMouse.pressed
                               ? root.colorHoverStrong
                               : (menuMouse.containsMouse ? hoverBackground : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space8
                            anchors.rightMargin: Theme.space8
                            spacing: Theme.space8

                            SymbolicIcon {
                                source: menuRow.iconSource
                                iconSize: 14
                                iconColor: menuMouse.containsMouse ? menuRow.hoverIconColor : menuRow.normalIconColor
                                Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: menuRow.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: menuMouse.containsMouse ? Font.DemiBold : Font.Normal
                                color: menuMouse.containsMouse ? menuRow.hoverTextColor : menuRow.normalTextColor
                                elide: Text.ElideRight
                                renderType: Theme.renderType
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            }
                        }

                        MouseArea {
                            id: menuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 3
                            onClicked: menuRow.activated()
                        }
                    }

                    MenuRow {
                        readonly property bool isPinned:
                            drawerContextMenu.targetApp
                            ? ApplicationManager.isPinned(drawerContextMenu.targetApp.id)
                            : false

                        iconSource: isPinned ? "list-remove" : "list-add"
                        label: isPinned ? I18n.tr("unpin_from_dock") : I18n.tr("pin_to_dock")
                        onActivated: {
                            if (drawerContextMenu.targetApp)
                                ApplicationManager.togglePin(drawerContextMenu.targetApp.id);
                            drawerContextMenu.hide();
                        }
                    }

                    MenuRow {
                        iconSource: "document-open-symbolic"
                        label: I18n.tr("open_app")
                        onActivated: {
                            var app = drawerContextMenu.targetApp;
                            drawerContextMenu.hide();
                            root.launchApp(app);
                        }
                    }

                    MenuRow {
                        visible: {
                            if (!drawerContextMenu.targetApp) return false;
                            return ApplicationManager.getWindowsForApp(drawerContextMenu.targetApp.id).length > 0;
                        }

                        iconSource: "window-close"
                        label: I18n.tr("close_app")
                        hoverIconColor: root.colorUrgent
                        normalTextColor: root.colorUrgent
                        hoverTextColor: root.colorUrgent
                        hoverBackground: Qt.rgba(root.colorUrgent.r, root.colorUrgent.g, root.colorUrgent.b, 0.12)
                        onActivated: {
                            var app = drawerContextMenu.targetApp;
                            if (app) {
                                if (app.id === "settings") {
                                    ShellState.closeSettingsApp();
                                } else if (app.id === "store") {
                                    ShellState.closeAppStore();
                                } else {
                                    var wins = ApplicationManager.getWindowsForApp(app.id);
                                    for (var i = 0; i < wins.length; i++) {
                                        if (wins[i] && typeof wins[i].close === "function")
                                            wins[i].close();
                                    }
                                }
                            }
                            drawerContextMenu.hide();
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Shell State synchronization
    // ─────────────────────────────────────────────────────────────────────
    Connections {
        target: ShellState

        function onAppDrawerOpenChanged() {
            drawerContextMenu.hide();

            if (ShellState.appDrawerOpen) {
                if (ShellState.searchQuery !== "") {
                    searchInput.text = ShellState.searchQuery;
                    root.filterQuery = ShellState.searchQuery;
                } else {
                    searchInput.text = "";
                    root.filterQuery = "";
                }

                root.selectedCategory = "All";
                root.selectedIndex = 0;
                searchInput.forceActiveFocus();
            }
        }

        function onSearchQueryChanged() {
            drawerContextMenu.hide();

            if (ShellState.searchQuery !== "") {
                searchInput.text = ShellState.searchQuery;
                root.filterQuery = ShellState.searchQuery;
                root.selectedIndex = 0;
            }
        }
    }
}