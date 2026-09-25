pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."
import "../theme"

Item {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || "/home"
    // Repo root: DELOWAY_DIR (hyprland.conf / deloway-session), older aliases, then the
    // parent of the loaded shell dir unless it is the ~/.config/deloway/shell link.
    readonly property string projectDir: {
        const env = Quickshell.env("DELOWAY_DIR") || Quickshell.env("DELOWAY_ROOT") || Quickshell.env("DELOWAY_HOME");
        if (env) return env;
        const shellDir = String(Quickshell.shellDir || "").replace(/\/+$/, "");
        if (shellDir.endsWith("/shell") && !shellDir.startsWith(homeDir + "/.config/"))
            return shellDir.slice(0, -"/shell".length);
        return homeDir + "/Projects/Deloway";
    }
    readonly property string userConfigDir: homeDir + "/.config/deloway"
    readonly property string markerPath: userConfigDir + "/setup_done"
    readonly property string fallbackConfigPath: projectDir + "/config/deloway.json"
    readonly property string configPath: {
        const envPath = Quickshell.env("DELOWAY_CONFIG");
        if (envPath && envPath.length > 0) return envPath;
        return userConfigDir + "/deloway.json";
    }

    // Theme Settings (Strict Monochrome)
    property string themeMode: "dark"
    readonly property color accentColor: Theme.colors.accent
    property string wallpaper: projectDir + "/assets/wallpaper.jpg"
    property real fontSizeScale: 1.0
    property string fontFamily: "Cairo"
    property int transparencyLevel: 85
    property int elementRadius: 8
    property int performanceTier: 1 // 0=Efficient, 1=Balanced, 2=High
    property bool applySystemTheme: true

    // Desktop Settings (§5.8)
    property string desktopMode: "clean"
    property bool showDesktopIcons: true
    property var enabledWidgets: ["clock", "weather", "system_monitor", "notes"]
    property var widgetPositions: ({
        "clock": { "x": 60, "y": 70 },
        "weather": { "x": 380, "y": 70 },
        "system_monitor": { "x": 60, "y": 280 },
        "notes": { "x": 380, "y": 280 }
    })

    // Dock Settings
    property string dockMode: "always" // "always" | "autohide" | "intellihide" | "disabled"
    property bool dockAutoHide: dockMode === "autohide" || dockMode === "intellihide"
    property bool dockEnabled: dockMode !== "disabled"
    property string dockPosition: "bottom"
    property int dockIconSize: 38
    property bool showUnderline: true
    // null until the user pins/unpins: the Dock then shows the chosen default apps
    // (ApplicationManager.defaultPinnedAppIds). [] is a real choice — an empty Dock.
    property var pinnedApps: null

    // TopBar Settings
    property bool topBarShowBrand: true
    property bool topBarShowWorkspaces: true
    property string clockFormat: "12h"
    property int workspacesCount: 5
    property string workspaceIndicatorStyle: "icons" // "icons" | "numbers" | "dots"
    // Sides of the top bar capsules around the Notch. Physical and the same in every
    // language: "clockLeft" (default: clock left, Quick Settings right) | "clockRight".
    property string capsuleOrder: "clockLeft"
    readonly property bool clockOnRight: capsuleOrder === "clockRight"
    property bool timeCapsuleEnabled: true
    property bool timeCapsuleShowHijri: true
    property string timeCapsuleWeekStart: "saturday" // "saturday" | "sunday" | "monday"
    property bool timeCapsuleShowHardware: true
    property bool timeCapsuleShowSeconds: true
    property bool timeCapsuleShowShortDate: true
    property bool timeCapsuleArabicDigits: true
    property bool timeCapsuleShowCpu: true
    property bool timeCapsuleShowRam: true
    property bool timeCapsuleShowGpu: true
    property bool timeCapsuleShowTemps: true

    // Windows & Hyprland Settings
    property color activeBorder: "#ffffff"
    property color inactiveBorder: "#2a3142"
    property int windowGapsIn: 5
    property int windowGapsOut: 10
    property int windowRounding: 10
    property bool followMouse: true
    property bool dimInactive: false

    // Notifications
    property bool notificationsDnd: false
    property int notificationsTimeout: 5000
    property bool notificationsSound: false
    property bool notchNotifications: true
    property string drawerGroupBy: "category"   // App Drawer › All apps: "category" (folders) | "alpha" (A–Z)

    // Power Settings (§5.9)
    property string powerProfile: "balanced"
    property int sleepTimeout: 30

    // Default Applications (§5.9)
    property string defaultBrowser: "brave"
    property string defaultTerminal: "kitty"
    property string defaultFileManager: "thunar"
    property string defaultEditor: "org.gnome.TextEditor"
    property string defaultMonitor: "missioncenter"

    // Music Settings (P10)
    property string musicPreferredPlayer: "auto"
    property var musicLaunchTarget: ({ "type": "app", "value": "spotify", "webApp": false })

    // System & Localization Settings
    property string uiLanguage: "en"
    property var keyboardLayouts: ["us", "ara"]

    // Setup Wizard State
    property bool setupCompleted: true

    FileView {
        id: markerFile
        path: root.markerPath
        atomicWrites: true
        printErrors: false      // absent until the Setup Wizard finishes
    }

    // Shipped template (config/deloway.json): read synchronously, because it is needed the
    // moment a first run is detected.
    FileView {
        id: fallbackFile
        path: root.fallbackConfigPath
        blockLoading: true
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        preload: true
        atomicWrites: true      // written by writeConfigNow(): temp file + rename, never half a file
        printErrors: false      // a missing file is the first run, handled in onLoadFailed

        onTextChanged: {
            const raw = text();
            if (!raw || !raw.trim()) return;
            if (raw === root._lastWritten) return;   // our own save: nothing new to apply
            root.loadFromText(raw);
            // Apply compositor-side settings from what was actually loaded (the startup
            // sync used to run before the async file load and pushed the built-in defaults).
            hyprSyncDebounce.restart();
        }

        // No deloway.json yet (fresh install, installer skipped, or file deleted): start from
        // the shipped template, whose setupCompleted is false, so the Setup Wizard opens.
        // This used to race the async load in Component.onCompleted and lose: the built-in
        // defaults (setupCompleted: true) won, the wizard never showed and the Dock came up
        // with a hardcoded pin list.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.setupCompleted = false;
                root.loadFromText(fallbackFile.text());
            } else {
                console.warn("[Deloway] Cannot read " + root.configPath + " (error " + error
                             + "); using the built-in defaults.");
            }
            hyprSyncDebounce.restart();
        }
    }

    Timer {
        id: hyprSyncDebounce
        interval: 200
        repeat: false
        onTriggered: {
            root.syncHyprlandWindowSettings();
            root.syncHyprlandVisualEffects();
        }
    }

    Component.onCompleted: {
        root.syncHyprlandWindowSettings();
        root.syncHyprlandVisualEffects();
    }

    // Graphics & Visual Effects tier → compositor effects (blur / shadows).
    //   0 Efficient : no blur, no shadows      (shell drop-shadows also off via Theme.enableShadows)
    //   1 Balanced  : blur 8×2, shadow 14      (the stock DeloWay values)
    //   2 High      : blur 10×3, shadow 22
    function syncHyprlandVisualEffects() {
        const t = root.performanceTier;
        const pairs = [
            ["decoration:blur:enabled", t >= 1 ? "true" : "false"],
            ["decoration:shadow:enabled", t >= 1 ? "true" : "false"]
        ];
        if (t >= 1) {
            pairs.push(["decoration:blur:size", t >= 2 ? 10 : 8]);
            pairs.push(["decoration:blur:passes", t >= 2 ? 3 : 2]);
            pairs.push(["decoration:shadow:range", t >= 2 ? 22 : 14]);
        }
        root.hyprKeywords(pairs);
    }

    // `hyprctl reload` (e.g. after editing hyprland.conf) resets every runtime keyword
    // back to the file's values; re-apply the user's Settings choices afterwards.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.syncHyprlandWindowSettings();
                root.syncHyprlandVisualEffects();
            }
        }
    }

    // ── Command helpers ──────────────────────────────────────────────────
    // Side-effect commands run as independent detached processes. (They previously all
    // shared `saveProcess`, and each exec() replaced the one before it — so multi-command
    // setters kept only their LAST command, which was usually the config write. Result:
    // gaps/rounding/focus/dim, default apps, wallpaper GTK keys… never actually applied.)
    function run(cmd) {
        Quickshell.execDetached(cmd);
    }

    // Several Hyprland keywords in ONE hyprctl call (atomic, one round-trip).
    function hyprKeywords(pairs) {
        const batch = pairs.map(p => "keyword " + p[0] + " " + p[1]).join(" ; ");
        root.run(["hyprctl", "--batch", batch]);
    }

    // Qt colour → Hyprland colour literal (rgba(rrggbbaa)); "#ffffff" is not accepted.
    function hyprColor(c) {
        const q = Qt.color(c);
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "rgba(" + h(q.r) + h(q.g) + h(q.b) + h(q.a) + ")";
    }

    function syncHyprlandWindowSettings() {
        try {
            const pairs = [
                ["general:gaps_in", root.windowGapsIn],
                ["general:gaps_out", root.windowGapsOut],
                ["decoration:rounding", root.windowRounding],
                ["input:follow_mouse", root.followMouse ? 1 : 0],
                ["decoration:dim_inactive", root.dimInactive ? "true" : "false"],
                // Hyprland's own text (group bars, error bar) in the UI typeface
                ["misc:font_family", root.fontFamily],
                ["group:groupbar:font_family", root.fontFamily]
            ];
            // Window borders follow the theme mode (they used to stay white on light).
            const dark = root.themeMode !== "light";
            pairs.push(["general:col.active_border", dark ? "rgba(ffffffdd)" : "rgba(0f172add)"]);
            pairs.push(["general:col.inactive_border", dark ? "rgba(444444cc)" : "rgba(c8c8c8cc)"]);
            root.hyprKeywords(pairs);
        } catch (err) {
            console.warn("[Deloway] Failed to sync Hyprland settings: " + err);
        }
    }

    function loadFromText(raw) {
        try {
            const cfg = JSON.parse(raw);
            if (cfg.theme) {
                if (cfg.theme.mode) {
                    root.themeMode = cfg.theme.mode;
                }
                // Legacy accentColor compatibility: safely ignored in strict monochrome identity
                if (cfg.theme.wallpaper !== undefined) root.wallpaper = cfg.theme.wallpaper;
                if (cfg.theme.fontSizeScale !== undefined) root.fontSizeScale = cfg.theme.fontSizeScale;
                if (cfg.theme.fontFamily !== undefined) root.fontFamily = cfg.theme.fontFamily;
                if (cfg.theme.transparencyLevel !== undefined) root.transparencyLevel = cfg.theme.transparencyLevel;
                if (cfg.theme.elementRadius !== undefined) root.elementRadius = cfg.theme.elementRadius;
                if (cfg.theme.performanceTier !== undefined) root.performanceTier = cfg.theme.performanceTier;
                if (cfg.theme.applySystemTheme !== undefined) root.applySystemTheme = cfg.theme.applySystemTheme;
            }
            if (cfg.desktop) {
                if (cfg.desktop.mode) root.desktopMode = cfg.desktop.mode;
                if (cfg.desktop.showIcons !== undefined) root.showDesktopIcons = cfg.desktop.showIcons;
                if (cfg.desktop.widgetPositions) root.widgetPositions = cfg.desktop.widgetPositions;
                if (cfg.desktop.enabledWidgets) root.enabledWidgets = cfg.desktop.enabledWidgets;
            }
            if (cfg.dock) {
                if (cfg.dock.mode) {
                    root.dockMode = cfg.dock.mode;
                } else if (cfg.dock.enabled === false) {
                    root.dockMode = "disabled";
                } else if (cfg.dock.autoHide !== undefined) {
                    root.dockMode = cfg.dock.autoHide ? "autohide" : "always";
                }
                if (cfg.dock.position) root.dockPosition = cfg.dock.position;
                if (cfg.dock.iconSize) root.dockIconSize = cfg.dock.iconSize;
                if (cfg.dock.showUnderline !== undefined) root.showUnderline = cfg.dock.showUnderline;
                if (Array.isArray(cfg.dock.pinnedApps)) root.pinnedApps = cfg.dock.pinnedApps;
            }
            if (cfg.drawer && (cfg.drawer.groupBy === "category" || cfg.drawer.groupBy === "alpha")) {
                root.drawerGroupBy = cfg.drawer.groupBy;
            }
            if (cfg.topBar) {
                if (cfg.topBar.showBrand !== undefined) root.topBarShowBrand = cfg.topBar.showBrand;
                if (cfg.topBar.showWorkspaces !== undefined) root.topBarShowWorkspaces = cfg.topBar.showWorkspaces;
                if (cfg.topBar.clockFormat) root.clockFormat = cfg.topBar.clockFormat;
                if (cfg.topBar.workspacesCount) root.workspacesCount = cfg.topBar.workspacesCount;
                if (cfg.topBar.workspaceIndicatorStyle) root.workspaceIndicatorStyle = cfg.topBar.workspaceIndicatorStyle;
                if (cfg.topBar.capsuleOrder === "clockLeft" || cfg.topBar.capsuleOrder === "clockRight")
                    root.capsuleOrder = cfg.topBar.capsuleOrder;
                if (cfg.topBar.timeCapsuleEnabled !== undefined) root.timeCapsuleEnabled = cfg.topBar.timeCapsuleEnabled;
                if (cfg.topBar.timeCapsuleShowHijri !== undefined) root.timeCapsuleShowHijri = cfg.topBar.timeCapsuleShowHijri;
                if (cfg.topBar.timeCapsuleWeekStart) root.timeCapsuleWeekStart = cfg.topBar.timeCapsuleWeekStart;
                if (cfg.topBar.timeCapsuleShowHardware !== undefined) root.timeCapsuleShowHardware = cfg.topBar.timeCapsuleShowHardware;
                if (cfg.topBar.timeCapsuleShowSeconds !== undefined) root.timeCapsuleShowSeconds = cfg.topBar.timeCapsuleShowSeconds;
                if (cfg.topBar.timeCapsuleShowShortDate !== undefined) root.timeCapsuleShowShortDate = cfg.topBar.timeCapsuleShowShortDate;
                if (cfg.topBar.timeCapsuleArabicDigits !== undefined) root.timeCapsuleArabicDigits = cfg.topBar.timeCapsuleArabicDigits;
                if (cfg.topBar.timeCapsuleShowCpu !== undefined) root.timeCapsuleShowCpu = cfg.topBar.timeCapsuleShowCpu;
                if (cfg.topBar.timeCapsuleShowRam !== undefined) root.timeCapsuleShowRam = cfg.topBar.timeCapsuleShowRam;
                if (cfg.topBar.timeCapsuleShowGpu !== undefined) root.timeCapsuleShowGpu = cfg.topBar.timeCapsuleShowGpu;
                if (cfg.topBar.timeCapsuleShowTemps !== undefined) root.timeCapsuleShowTemps = cfg.topBar.timeCapsuleShowTemps;
            }
            if (cfg.windows) {
                if (cfg.windows.activeBorder) {
                    const ab = cfg.windows.activeBorder.toString().toLowerCase();
                    if (ab === "#0084ff" || ab === "#0ea5e9" || ab === "#8b5cf6") {
                        root.activeBorder = "#ffffff";
                    } else {
                        root.activeBorder = cfg.windows.activeBorder;
                    }
                }
                if (cfg.windows.inactiveBorder) root.inactiveBorder = cfg.windows.inactiveBorder;
                if (cfg.windows.gapsIn !== undefined) root.windowGapsIn = cfg.windows.gapsIn;
                if (cfg.windows.gapsOut !== undefined) root.windowGapsOut = cfg.windows.gapsOut;
                if (cfg.windows.rounding !== undefined) root.windowRounding = cfg.windows.rounding;
                if (cfg.windows.followMouse !== undefined) root.followMouse = cfg.windows.followMouse;
                if (cfg.windows.dimInactive !== undefined) root.dimInactive = cfg.windows.dimInactive;
            }
            if (cfg.notifications) {
                if (cfg.notifications.dnd !== undefined) root.notificationsDnd = cfg.notifications.dnd;
                if (cfg.notifications.timeout) root.notificationsTimeout = cfg.notifications.timeout;
                if (cfg.notifications.sound !== undefined) root.notificationsSound = cfg.notifications.sound;
                if (cfg.notifications.notch !== undefined) root.notchNotifications = cfg.notifications.notch;
            }
            if (cfg.power) {
                if (cfg.power.profile) root.powerProfile = cfg.power.profile;
                if (cfg.power.sleepTimeout !== undefined) root.sleepTimeout = cfg.power.sleepTimeout;
            }
            if (cfg.defaultApps) {
                if (cfg.defaultApps.browser) root.defaultBrowser = cfg.defaultApps.browser;
                if (cfg.defaultApps.terminal) root.defaultTerminal = cfg.defaultApps.terminal;
                if (cfg.defaultApps.fileManager) root.defaultFileManager = cfg.defaultApps.fileManager;
                if (cfg.defaultApps.editor) root.defaultEditor = cfg.defaultApps.editor;
                if (cfg.defaultApps.monitor) root.defaultMonitor = cfg.defaultApps.monitor;
            }
            if (cfg.music) {
                if (cfg.music.preferredPlayer !== undefined) root.musicPreferredPlayer = cfg.music.preferredPlayer;
                if (cfg.music.launchTarget !== undefined) root.musicLaunchTarget = cfg.music.launchTarget;
            }
            if (cfg.system) {
                if (cfg.system.uiLanguage) root.uiLanguage = cfg.system.uiLanguage;
                if (cfg.system.keyboardLayouts) root.keyboardLayouts = cfg.system.keyboardLayouts;
            }
            if (cfg.setupCompleted !== undefined) {
                root.setupCompleted = cfg.setupCompleted;
            }
            const initialLang = (root.uiLanguage === "ar") ? "ar" : "en_US:en";
            root.run(["hyprctl", "keyword", "env", "LANGUAGE," + initialLang]);
            root.run(["dbus-update-activation-environment", "--systemd", "LANGUAGE=" + initialLang]);
            updateGtkThemes();
        } catch (err) {
            console.warn("[Deloway] Failed to parse config JSON: " + err);
        }
    }


    function setThemeMode(mode) {
        if (mode !== "dark" && mode !== "light") return;
        root.themeMode = mode;
        saveConfig();
        syncHyprlandWindowSettings();

        if (root.applySystemTheme) {
            updateGtkThemes();
        }
    }

    function setAccentColor(col) {
        // Deprecated: DeloWay is strictly monochrome (Dark/Light only)
    }

    function setApplySystemTheme(val) {
        root.applySystemTheme = val;
        saveConfig();
        if (val) {
            updateGtkThemes();
        }
    }

    function setPerformanceTier(tier) {
        if (tier < 0 || tier > 2) return;
        root.performanceTier = tier;
        syncHyprlandVisualEffects();
        saveConfig();
    }

    // Qt theming integration (kdeglobals/qt6ct) - delegated to system theme engine

    // Coalesce rapid changes (mode + font + radius) into one toolkit re-theme.
    Timer {
        id: themeApplyDebounce
        interval: 150
        repeat: false
        onTriggered: gtkThemeProcess.exec(["python3", root.projectDir + "/scripts/deloway-theme-apply.py",
                                           "--mode", root.themeMode,
                                           "--font-scale", String(root.fontSizeScale),
                                           "--radius", String(root.elementRadius)])
    }

    function updateGtkThemes() {
        if (!root.applySystemTheme) return;
        // Pass the mode explicitly: deloway.json / theme.json are written asynchronously
        // (debounced), so the script could otherwise read the previous mode.
        themeApplyDebounce.restart();
    }

    function setDockMode(mode) {
        if (["always", "autohide", "intellihide", "disabled"].indexOf(mode) < 0) return;
        root.dockMode = mode;
        saveConfig();
    }

    function setDockAutoHide(val) {
        root.setDockMode(val ? "autohide" : "always");
    }

    function setDockEnabled(val) {
        if (!val) {
            root.setDockMode("disabled");
        } else {
            root.setDockMode(root.dockAutoHide ? (root.dockMode === "intellihide" ? "intellihide" : "autohide") : "always");
        }
    }

    function setDockIconSize(sz) {
        root.dockIconSize = sz;
        saveConfig();
    }

    function setShowUnderline(val) {
        root.showUnderline = val;
        saveConfig();
    }

    function setNotificationsDnd(val) {
        root.notificationsDnd = val;
        saveConfig();
    }

    function setNotificationsSound(val) {
        root.notificationsSound = !!val;
        saveConfig();
    }

    function setDrawerGroupBy(mode) {
        if (mode !== "category" && mode !== "alpha") return;
        root.drawerGroupBy = mode;
        saveConfig();
    }

    function setNotchNotifications(val) {
        root.notchNotifications = !!val;
        saveConfig();
    }

    function setTopBarShowWorkspaces(val) {
        root.topBarShowWorkspaces = !!val;
        saveConfig();
    }

    function setNotificationsTimeout(ms) {
        root.notificationsTimeout = Math.max(1000, Math.min(20000, ms));
        saveConfig();
    }

    function setClockFormat(fmt) {
        root.clockFormat = fmt;
        saveConfig();
    }

    function setWindowGaps(gapsIn, gapsOut) {
        root.windowGapsIn = Math.max(0, Math.min(30, gapsIn));
        root.windowGapsOut = Math.max(0, Math.min(40, gapsOut));
        root.hyprKeywords([["general:gaps_in", root.windowGapsIn], ["general:gaps_out", root.windowGapsOut]]);
        saveConfig();
    }

    function setWindowRounding(r) {
        root.windowRounding = Math.max(0, Math.min(24, r));
        root.run(["hyprctl", "keyword", "decoration:rounding", String(root.windowRounding)]);
        saveConfig();
    }

    function setFollowMouse(val) {
        root.followMouse = val;
        root.run(["hyprctl", "keyword", "input:follow_mouse", val ? "1" : "0"]);
        saveConfig();
    }

    function setDimInactive(val) {
        root.dimInactive = val;
        root.run(["hyprctl", "keyword", "decoration:dim_inactive", val ? "true" : "false"]);
        saveConfig();
    }

    function setActiveBorder(col) {
        root.activeBorder = col;
        root.hyprKeywords([["general:col.active_border", root.hyprColor(col)]]);
        saveConfig();
    }

    // Factory reset of the options exposed in Settings. Goes through the setters so
    // compositor keywords, GTK theming and theme files are re-applied, not just saved.
    function resetToDefaults() {
        setThemeMode("dark");
        setFontSizeScale(1.0);
        setElementRadius(8);
        setPerformanceTier(1);
        setDockMode("always");
        setDockPosition("bottom");
        setDockIconSize(48);
        setShowUnderline(true);
        setWindowGaps(5, 10);
        setWindowRounding(8);
        setFollowMouse(true);
        setDimInactive(false);
        setWorkspacesCount(5);
        setWorkspaceIndicatorStyle("icons");
        setCapsuleOrder("clockLeft");
        setTopBarShowWorkspaces(true);
        setNotificationsDnd(false);
        setNotificationsSound(false);
        setNotificationsTimeout(5000);
        setNotchNotifications(true);
        setSleepTimeout(30);
        setClockFormat("12h");
    }

    function setDesktopMode(mode) {
        if (mode !== "clean" && mode !== "widgets" && mode !== "traditional") return;
        root.desktopMode = mode;
        saveConfig();
    }

    function setShowDesktopIcons(val) {
        root.showDesktopIcons = val;
        saveConfig();
    }

    function setWidgetPosition(widgetId, x, y) {
        var pos = Object.assign({}, root.widgetPositions);
        pos[widgetId] = { "x": Math.round(x), "y": Math.round(y) };
        root.widgetPositions = pos;
        saveConfig();
    }

    function toggleWidget(widgetId) {
        var arr = root.enabledWidgets.slice();
        var idx = arr.indexOf(widgetId);
        if (idx >= 0) {
            arr.splice(idx, 1);
        } else {
            arr.push(widgetId);
        }
        root.enabledWidgets = arr;
        saveConfig();
    }

    function isWidgetEnabled(widgetId) {
        return root.enabledWidgets.includes(widgetId);
    }

    function setWallpaper(path) {
        if (!path || String(path).trim().length === 0) return;
        var cleanPath = String(path).trim();
        if (cleanPath.startsWith("picture-uri:")) {
            cleanPath = cleanPath.substring(12).trim();
        }
        if (cleanPath.startsWith("'") && cleanPath.endsWith("'")) {
            cleanPath = cleanPath.substring(1, cleanPath.length - 1);
        }
        if (cleanPath.startsWith('"') && cleanPath.endsWith('"')) {
            cleanPath = cleanPath.substring(1, cleanPath.length - 1);
        }
        if (cleanPath.startsWith("file://")) {
            cleanPath = decodeURIComponent(cleanPath.substring(7));
        }
        if (cleanPath.length === 0) return;
        if (cleanPath === root.wallpaper) return;

        root.wallpaper = cleanPath;
        saveConfig();

        // Sync with GNOME GSettings so external tools and image viewers stay in sync
        var uri = root.fileUrl(cleanPath);
        root.run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", uri]);
        root.run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", uri]);
    }

    // A local path (or a file:// URL someone stored unencoded) as a correct file:// URL.
    // Plain "file://" + path broke on "#" and "?" — "#silver surfer#.jpeg" was read as
    // the fragment "silver surfer#.jpeg" of the folder — so such wallpapers never loaded.
    function fileUrl(path) {
        if (!path) return "";
        let p = String(path);
        if (p.startsWith("file://")) {
            try { p = decodeURIComponent(p.substring(7)); } catch (e) { p = p.substring(7); }
        }
        if (!p.startsWith("/")) return String(path);   // another scheme: leave it alone
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function setFontSizeScale(scale) {
        root.fontSizeScale = Math.max(0.7, Math.min(1.5, scale));
        saveConfig();
        if (root.applySystemTheme) {
            updateGtkThemes();
        }
    }

    function setFontFamily(family) {
        if (!family || root.fontFamily === family) return;
        root.fontFamily = family;
        saveConfig();
        root.hyprKeywords([["misc:font_family", family], ["group:groupbar:font_family", family]]);
        if (root.applySystemTheme) {
            updateGtkThemes();
        }
    }

    function setTransparencyLevel(level) {
        root.transparencyLevel = Math.max(0, Math.min(100, Math.round(level)));
        saveConfig();
    }

    function setElementRadius(r) {
        root.elementRadius = Math.max(0, Math.min(24, Math.round(r)));
        saveConfig();
        // App corner radii follow the shell's (passed to the theme script as --radius)
        if (root.applySystemTheme) updateGtkThemes();
    }

    function setCapsuleOrder(order) {
        if (order !== "clockLeft" && order !== "clockRight") return;
        root.capsuleOrder = order;
        saveConfig();
    }

    function setWorkspaceIndicatorStyle(style) {
        if (style !== "icons" && style !== "numbers" && style !== "dots") return;
        root.workspaceIndicatorStyle = style;
        saveConfig();
    }

    function setWorkspacesCount(count) {
        const val = Math.max(1, Math.min(10, Math.round(count)));
        root.workspacesCount = val;
        saveConfig();
    }

    function setTimeCapsuleEnabled(enabled) {
        root.timeCapsuleEnabled = !!enabled;
        saveConfig();
    }

    function setTimeCapsuleShowHijri(val) {
        root.timeCapsuleShowHijri = !!val;
        saveConfig();
    }

    function setTimeCapsuleWeekStart(val) {
        if (val !== "saturday" && val !== "sunday" && val !== "monday") return;
        root.timeCapsuleWeekStart = val;
        saveConfig();
    }

    function setTimeCapsuleShowHardware(val) {
        root.timeCapsuleShowHardware = !!val;
        saveConfig();
    }

    function setTimeCapsuleShowSeconds(val) {
        root.timeCapsuleShowSeconds = !!val;
        saveConfig();
    }

    function setTimeCapsuleShowShortDate(val) {
        root.timeCapsuleShowShortDate = !!val;
        saveConfig();
    }

    function setTimeCapsuleArabicDigits(val) {
        root.timeCapsuleArabicDigits = !!val;
        saveConfig();
    }

    function setTimeCapsuleShowCpu(val) {
        root.timeCapsuleShowCpu = !!val;
        saveConfig();
    }

    function setTimeCapsuleShowRam(val) {
        root.timeCapsuleShowRam = !!val;
        saveConfig();
    }

    function setTimeCapsuleShowGpu(val) {
        root.timeCapsuleShowGpu = !!val;
        saveConfig();
    }

    function setTimeCapsuleShowTemps(val) {
        root.timeCapsuleShowTemps = !!val;
        saveConfig();
    }

    function setDockPosition(pos) {
        if (pos !== "bottom" && pos !== "left" && pos !== "right") return;
        root.dockPosition = pos;
        saveConfig();
    }

    function setPinnedApps(apps) {
        root.pinnedApps = apps;
        saveConfig();
    }

    // Back to the chosen default apps (browser, terminal, file manager).
    function resetPinnedApps() {
        root.pinnedApps = null;
        saveConfig();
    }

    function setPowerProfile(prof) {
        if (["power-saver", "balanced", "performance"].indexOf(prof) < 0) return;
        root.powerProfile = prof;
        ControlCenterService.setPowerProfile(prof);   // powerprofilesctl set + read-back
        saveConfig();
    }

    function setSleepTimeout(min) {
        root.sleepTimeout = min;
        saveConfig();
    }

    // Stores the choice (what delo-app launches) and makes it the XDG default. The value may
    // be a desktop id or an executable; the XDG defaults need the exact desktop file, so it is
    // resolved (building "<value>.desktop" named files that do not exist: brave.desktop,
    // dolphin.desktop). The Dock's default pins follow browser/terminal/file manager.
    function setDefaultApp(cat, value) {
        if (!value) return;
        const clean = value.replace(/\.desktop$/, "");
        const entry = ApplicationManager.resolveAppEntry(clean);
        const desktopFile = (entry ? entry.id.replace(/\.desktop$/, "") : clean) + ".desktop";
        if (cat === "browser") {
            root.defaultBrowser = clean;
            root.run(["xdg-settings", "set", "default-web-browser", desktopFile]);
            root.run(["xdg-mime", "default", desktopFile, "x-scheme-handler/http", "x-scheme-handler/https", "text/html"]);
        } else if (cat === "terminal") {
            root.defaultTerminal = clean;
        } else if (cat === "fileManager") {
            root.defaultFileManager = clean;
            root.run(["xdg-mime", "default", desktopFile, "inode/directory"]);
        } else if (cat === "editor") {
            root.defaultEditor = clean;
            root.run(["xdg-mime", "default", desktopFile, "text/plain"]);
        } else if (cat === "monitor") {
            root.defaultMonitor = clean;
        } else {
            return;
        }
        saveConfig();
    }

    function setMusicPreferredPlayer(player) {
        root.musicPreferredPlayer = player || "auto";
        saveConfig();
    }

    function setMusicLaunchTarget(target) {
        if (!target) return;
        root.musicLaunchTarget = target;
        saveConfig();
    }

    property bool _musicLaunching: false
    Timer {
        id: musicLaunchDebounce
        interval: 3000
        repeat: false
        onTriggered: root._musicLaunching = false
    }

    function launchMusic() {
        if (root._musicLaunching) return;
        root._musicLaunching = true;
        musicLaunchDebounce.restart();

        const target = root.musicLaunchTarget || ({ "type": "app", "value": "spotify", "webApp": false });
        // Values come from a free-text Settings field: they are passed to sh as
        // positional arguments ("$1"), never concatenated into the script.
        if (target.type === "url" && target.value) {
            let url = target.value.trim();
            if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(url)) url = "https://" + url;
            if (target.webApp) {
                root.run(["sh", "-c",
                    'for b in brave chromium google-chrome google-chrome-stable thorium-browser; do ' +
                    'command -v "$b" >/dev/null 2>&1 && exec "$b" --app="$1"; done; exec xdg-open "$1"',
                    "sh", url]);
            } else {
                root.run(["xdg-open", url]);
            }
        } else if (target.type === "app" && target.value) {
            const val = target.value.trim();
            const app = ApplicationManager.findApp(val);
            if (app && typeof app.execute === "function") {
                app.execute();
            } else if (/^[A-Za-z0-9._-]+$/.test(val)) {
                root.run(["sh", "-c", 'gtk-launch "$1" 2>/dev/null || exec "$1"', "sh", val]);
            } else {
                console.warn("[ConfigManager] music launch target is not an app id:", val);
            }
        }
    }

    function setUiLanguage(lang) {
        if (lang !== "en" && lang !== "ar") return;
        root.uiLanguage = lang;
        saveConfig();
        const langVal = (lang === "ar") ? "ar" : "en_US:en";
        root.run(["hyprctl", "keyword", "env", "LANGUAGE," + langVal]);
        root.run(["dbus-update-activation-environment", "--systemd", "LANGUAGE=" + langVal]);
        localeApplyProcess.lang = lang;
        localeApplyProcess.exec(["python3", root.projectDir + "/scripts/deloway-locale-apply.py", "--lang", lang]);
        if (root.applySystemTheme) {
            updateGtkThemes();
        }
        // The result notification is posted by localeApplyProcess.onExited, so a failed
        // apply no longer announces success.
    }

    function setKeyboardLayouts(layouts) {
        if (!Array.isArray(layouts) || layouts.length === 0) return;
        root.keyboardLayouts = layouts;
        saveConfig();
        const layoutStr = layouts.join(",");
        root.run(["hyprctl", "keyword", "input:kb_layout", layoutStr]);
    }

    // Coalesce bursts (e.g. resetToDefaults → 20 setters) into one full write.
    Timer {
        id: saveDebounce
        interval: 120
        repeat: false
        onTriggered: root.writeConfigNow()
    }
    function saveConfig() {
        saveDebounce.restart();
    }

    function writeConfigNow() {
        const configData = {
            theme: {
                mode: root.themeMode,
                wallpaper: root.wallpaper,
                fontSizeScale: root.fontSizeScale,
                fontFamily: root.fontFamily,
                transparencyLevel: root.transparencyLevel,
                elementRadius: root.elementRadius,
                performanceTier: root.performanceTier,
                applySystemTheme: root.applySystemTheme
            },
            desktop: {
                mode: root.desktopMode,
                showIcons: root.showDesktopIcons,
                widgetPositions: root.widgetPositions,
                enabledWidgets: root.enabledWidgets
            },
            dock: {
                mode: root.dockMode,
                autoHide: root.dockAutoHide,
                enabled: root.dockEnabled,
                position: root.dockPosition,
                iconSize: root.dockIconSize,
                showUnderline: root.showUnderline,
                pinnedApps: root.pinnedApps
            },
            topBar: {
                showBrand: root.topBarShowBrand,
                showWorkspaces: root.topBarShowWorkspaces,
                clockFormat: root.clockFormat,
                workspacesCount: root.workspacesCount,
                workspaceIndicatorStyle: root.workspaceIndicatorStyle,
                capsuleOrder: root.capsuleOrder,
                timeCapsuleEnabled: root.timeCapsuleEnabled,
                timeCapsuleShowHijri: root.timeCapsuleShowHijri,
                timeCapsuleWeekStart: root.timeCapsuleWeekStart,
                timeCapsuleShowHardware: root.timeCapsuleShowHardware,
                timeCapsuleShowSeconds: root.timeCapsuleShowSeconds,
                timeCapsuleShowShortDate: root.timeCapsuleShowShortDate,
                timeCapsuleArabicDigits: root.timeCapsuleArabicDigits,
                timeCapsuleShowCpu: root.timeCapsuleShowCpu,
                timeCapsuleShowRam: root.timeCapsuleShowRam,
                timeCapsuleShowGpu: root.timeCapsuleShowGpu,
                timeCapsuleShowTemps: root.timeCapsuleShowTemps
            },
            windows: {
                activeBorder: root.activeBorder.toString(),
                inactiveBorder: root.inactiveBorder.toString(),
                gapsIn: root.windowGapsIn,
                gapsOut: root.windowGapsOut,
                rounding: root.windowRounding,
                followMouse: root.followMouse,
                dimInactive: root.dimInactive
            },
            notifications: {
                dnd: root.notificationsDnd,
                timeout: root.notificationsTimeout,
                sound: root.notificationsSound,
                notch: root.notchNotifications
            },
            drawer: {
                groupBy: root.drawerGroupBy
            },
            power: {
                profile: root.powerProfile,
                sleepTimeout: root.sleepTimeout
            },
            defaultApps: {
                browser: root.defaultBrowser,
                terminal: root.defaultTerminal,
                fileManager: root.defaultFileManager,
                editor: root.defaultEditor,
                monitor: root.defaultMonitor
            },
            music: {
                preferredPlayer: root.musicPreferredPlayer,
                launchTarget: root.musicLaunchTarget
            },
            system: {
                uiLanguage: root.uiLanguage,
                keyboardLayouts: root.keyboardLayouts
            },
            setupCompleted: root.setupCompleted
        };

        // Atomic write through the FileView (it used to be a bash heredoc: not atomic, so
        // a crash mid-write left a truncated deloway.json, and a quote in the path broke it).
        const jsonStr = JSON.stringify(configData, null, 2) + "\n";
        root._lastWritten = jsonStr;
        configFile.setText(jsonStr);
    }
    property string _lastWritten: ""

    function completeSetup() {
        root.setupCompleted = true;
        saveConfig();
        markerFile.setText("done\n");
    }


    Process {
        id: gtkThemeProcess
    }

    Process {
        id: localeApplyProcess
        property string lang: "en"
        stderr: StdioCollector { id: localeApplyErr }
        onExited: (exitCode) => {
            const ar = localeApplyProcess.lang === "ar";
            if (exitCode === 0) {
                NotificationManager.postNotification(
                    ar ? "إعدادات اللغة" : "Language Settings",
                    ar ? "تم تغيير لغة النظام" : "System Language Changed",
                    ar ? "تُطبَّق اللغة على البرامج بعد إعادة تسجيل الدخول، والمفتوحة منها بعد إعادة تشغيلها"
                       : "Language will be applied to applications after re-login, and to running apps after restarting them",
                    "preferences-desktop-locale");
            } else {
                const tail = (localeApplyErr.text || "").trim().split("\n").slice(-1)[0] || ("exit " + exitCode);
                NotificationManager.postNotification(
                    ar ? "إعدادات اللغة" : "Language Settings",
                    ar ? "تعذّر تطبيق لغة النظام" : "Could not apply the system language",
                    tail, "dialog-warning-symbolic");
            }
        }
    }

    Process {
        id: wallpaperGsettingsMonitorProc
        // Tethered: dies with the shell (it used to be orphaned on every restart).
        command: ["python3", root.projectDir + "/scripts/deloway-tether.py",
                  "gsettings", "monitor", "org.gnome.desktop.background", "picture-uri"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.length > 0) {
                    root.setWallpaper(line);
                }
            }
        }
    }
}

