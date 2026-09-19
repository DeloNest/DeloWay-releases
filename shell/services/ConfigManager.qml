pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Item {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || "/home"
    readonly property string projectDir: Quickshell.env("DELOWAY_DIR") || Quickshell.env("DELOWAY_ROOT") || (homeDir + "/Projects/Deloway")
    readonly property string userConfigDir: homeDir + "/.config/deloway"
    readonly property string markerPath: userConfigDir + "/setup_done"
    readonly property string fallbackConfigPath: projectDir + "/config/deloway.json"
    readonly property string configPath: {
        const envPath = Quickshell.env("DELOWAY_CONFIG");
        if (envPath && envPath.length > 0) return envPath;
        return userConfigDir + "/deloway.json";
    }

    // Theme Settings
    property string themeMode: "dark"
    property color accentColor: "#0ea5e9"
    property string wallpaper: projectDir + "/assets/wallpaper.jpg"
    property real fontSizeScale: 1.0
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
    property string dockPosition: "bottom"
    property bool dockAutoHide: false
    property int dockIconSize: 38
    property bool showUnderline: true
    property var pinnedApps: ["brave-browser", "kitty", "thunar", "spotify", "settings", "store"]

    // TopBar Settings
    property bool topBarShowBrand: true
    property bool topBarShowWorkspaces: true
    property string clockFormat: "12h"
    property int workspacesCount: 5

    // Windows & Hyprland Settings
    property color activeBorder: "#0084ff"
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

    // Power Settings (§5.9)
    property string powerProfile: "balanced"
    property int sleepTimeout: 30

    // Default Applications (§5.9)
    property string defaultBrowser: "brave"
    property string defaultTerminal: "kitty"
    property string defaultFileManager: "thunar"
    property string defaultEditor: "org.gnome.TextEditor"

    // System & Localization Settings
    property string uiLanguage: "en"
    property var keyboardLayouts: ["us", "ara"]

    // Setup Wizard State
    property bool setupCompleted: true

    FileView {
        id: markerFile
        path: root.markerPath
        watchChanges: true
    }

    FileView {
        id: fallbackFile
        path: root.fallbackConfigPath
        watchChanges: false
        preload: true
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        preload: true

        onTextChanged: {
            root.loadFromText(text());
        }
    }

    Component.onCompleted: {
        try {
            var raw = configFile.text();
            if (!raw || raw.trim().length < 5) {
                // Fallback to project template
                raw = fallbackFile.text();
            }
            if (raw && raw.length > 5) {
                root.loadFromText(raw);
            }
            root.syncHyprlandWindowSettings();
        } catch (e) {
            console.log("[Deloway] ConfigManager using default configuration: " + e);
        }
    }

    function syncHyprlandWindowSettings() {
        try {
            saveProcess.exec(["hyprctl", "keyword", "general:gaps_in", String(root.windowGapsIn)]);
            saveProcess.exec(["hyprctl", "keyword", "general:gaps_out", String(root.windowGapsOut)]);
            saveProcess.exec(["hyprctl", "keyword", "decoration:rounding", String(root.windowRounding)]);
            saveProcess.exec(["hyprctl", "keyword", "input:follow_mouse", root.followMouse ? "1" : "0"]);
            saveProcess.exec(["hyprctl", "keyword", "decoration:dim_inactive", root.dimInactive ? "true" : "false"]);
            if (root.activeBorder) {
                saveProcess.exec(["hyprctl", "keyword", "general:col.active_border", root.activeBorder.toString()]);
            }
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
                    Theme.setMode(cfg.theme.mode);
                }
                if (cfg.theme.accentColor) {
                    root.accentColor = cfg.theme.accentColor;
                    Theme.colors.accent = cfg.theme.accentColor;
                    Theme.colors.primary = cfg.theme.accentColor;
                }
                if (cfg.theme.wallpaper !== undefined) root.wallpaper = cfg.theme.wallpaper;
                if (cfg.theme.fontSizeScale !== undefined) root.fontSizeScale = cfg.theme.fontSizeScale;
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
                if (cfg.dock.position) root.dockPosition = cfg.dock.position;
                if (cfg.dock.autoHide !== undefined) root.dockAutoHide = cfg.dock.autoHide;
                if (cfg.dock.iconSize) root.dockIconSize = cfg.dock.iconSize;
                if (cfg.dock.showUnderline !== undefined) root.showUnderline = cfg.dock.showUnderline;
                if (cfg.dock.pinnedApps) root.pinnedApps = cfg.dock.pinnedApps;
            }
            if (cfg.topBar) {
                if (cfg.topBar.showBrand !== undefined) root.topBarShowBrand = cfg.topBar.showBrand;
                if (cfg.topBar.showWorkspaces !== undefined) root.topBarShowWorkspaces = cfg.topBar.showWorkspaces;
                if (cfg.topBar.clockFormat) root.clockFormat = cfg.topBar.clockFormat;
                if (cfg.topBar.workspacesCount) root.workspacesCount = cfg.topBar.workspacesCount;
            }
            if (cfg.windows) {
                if (cfg.windows.activeBorder) root.activeBorder = cfg.windows.activeBorder;
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
            }
            if (cfg.system) {
                if (cfg.system.uiLanguage) root.uiLanguage = cfg.system.uiLanguage;
                if (cfg.system.keyboardLayouts) root.keyboardLayouts = cfg.system.keyboardLayouts;
            }
            if (cfg.setupCompleted !== undefined) {
                root.setupCompleted = cfg.setupCompleted;
            }
            updateGtkThemes();
        } catch (err) {
            console.warn("[Deloway] Failed to parse config JSON: " + err);
        }
    }


    function writeThemeJson() {
        const themeJsonPath = root.projectDir + "/shell/theme/theme.json";
        const accentStr = root.accentColor.toString();
        const darkPal = Object.assign({}, Theme.darkPalette, { "accent": accentStr, "primary": accentStr });
        const lightPal = Object.assign({}, Theme.lightPalette, { "accent": accentStr, "primary": accentStr });
        const themeJsonContent = JSON.stringify({
            "theme": root.themeMode === "dark" ? "deloos-dark" : "deloos-light",
            "mode": root.themeMode,
            "accent": accentStr,
            "colors": Theme.colors,
            "dark": darkPal,
            "light": lightPal,
            "radius": Theme.radius,
            "spacing": Theme.spacing,
            "typography": Theme.typography
        }, null, 2);
        saveThemeProcess.exec(["bash", "-c", "cat << 'EOF' > " + themeJsonPath + "\n" + themeJsonContent + "\nEOF"]);
    }

    function setThemeMode(mode) {
        if (mode !== "dark" && mode !== "light") return;
        root.themeMode = mode;
        Theme.setMode(mode);
        saveConfig();
        writeThemeJson();

        if (root.applySystemTheme) {
            updateGtkThemes();
        }
    }

    function setAccentColor(col) {
        root.accentColor = col;
        Theme.colors.accent = col;
        Theme.colors.primary = col;
        saveConfig();
        // Update active border in Hyprland
        const hex = col.toString().replace("#", "");
        Hyprland.dispatch("exec hyprctl keyword general:col.active_border 'rgb(" + hex + ")'");
        writeThemeJson();
        if (root.applySystemTheme) {
            updateGtkThemes();
        }
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
        saveConfig();
    }

    // Qt theming integration (kdeglobals/qt6ct) - delegated to system theme engine

    function updateGtkThemes() {
        if (!root.applySystemTheme) return;
        gtkThemeProcess.exec(["python3", root.projectDir + "/scripts/deloway-theme-apply.py"]);
    }

    function setDockAutoHide(val) {
        root.dockAutoHide = val;
        saveConfig();
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
        saveProcess.exec(["hyprctl", "keyword", "general:gaps_in", String(root.windowGapsIn)]);
        saveProcess.exec(["hyprctl", "keyword", "general:gaps_out", String(root.windowGapsOut)]);
        saveConfig();
    }

    function setWindowRounding(r) {
        root.windowRounding = Math.max(0, Math.min(24, r));
        saveProcess.exec(["hyprctl", "keyword", "decoration:rounding", String(root.windowRounding)]);
        saveConfig();
    }

    function setFollowMouse(val) {
        root.followMouse = val;
        saveProcess.exec(["hyprctl", "keyword", "input:follow_mouse", val ? "1" : "0"]);
        saveConfig();
    }

    function setDimInactive(val) {
        root.dimInactive = val;
        saveProcess.exec(["hyprctl", "keyword", "decoration:dim_inactive", val ? "true" : "false"]);
        saveConfig();
    }

    function setActiveBorder(col) {
        root.activeBorder = col;
        saveProcess.exec(["hyprctl", "keyword", "general:col.active_border", col.toString()]);
        saveConfig();
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
        var uri = "file://" + cleanPath;
        saveProcess.exec(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", uri]);
        saveProcess.exec(["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", uri]);
    }

    function setFontSizeScale(scale) {
        root.fontSizeScale = Math.max(0.7, Math.min(1.5, scale));
        saveConfig();
    }

    function setTransparencyLevel(level) {
        root.transparencyLevel = Math.max(0, Math.min(100, Math.round(level)));
        saveConfig();
    }

    function setElementRadius(r) {
        root.elementRadius = Math.max(0, Math.min(24, Math.round(r)));
        root.windowRounding = root.elementRadius;
        saveProcess.exec(["hyprctl", "keyword", "decoration:rounding", String(root.elementRadius)]);
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

    function setPowerProfile(prof) {
        root.powerProfile = prof;
        saveProcess.exec(["bash", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl set " + prof + " || true"]);
        saveConfig();
    }

    function setSleepTimeout(min) {
        root.sleepTimeout = min;
        saveConfig();
    }

    function setDefaultApp(cat, cmd) {
        if (cat === "browser") {
            root.defaultBrowser = cmd;
            saveProcess.exec(["xdg-settings", "set", "default-web-browser", cmd + ".desktop"]);
        } else if (cat === "terminal") {
            root.defaultTerminal = cmd;
        } else if (cat === "fileManager") {
            root.defaultFileManager = cmd;
            saveProcess.exec(["xdg-mime", "default", cmd + ".desktop", "inode/directory"]);
        } else if (cat === "editor") {
            root.defaultEditor = cmd;
            saveProcess.exec(["xdg-mime", "default", cmd + ".desktop", "text/plain"]);
        }
        saveConfig();
    }

    function setUiLanguage(lang) {
        if (lang !== "en" && lang !== "ar") return;
        root.uiLanguage = lang;
        saveConfig();
    }

    function setKeyboardLayouts(layouts) {
        if (!Array.isArray(layouts) || layouts.length === 0) return;
        root.keyboardLayouts = layouts;
        saveConfig();
        const layoutStr = layouts.join(",");
        saveProcess.exec(["hyprctl", "keyword", "input:kb_layout", layoutStr]);
    }

    function saveConfig() {
        const configData = {
            theme: {
                mode: root.themeMode,
                accentColor: root.accentColor.toString(),
                wallpaper: root.wallpaper,
                fontSizeScale: root.fontSizeScale,
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
                position: root.dockPosition,
                autoHide: root.dockAutoHide,
                iconSize: root.dockIconSize,
                showUnderline: root.showUnderline,
                pinnedApps: root.pinnedApps
            },
            topBar: {
                showBrand: root.topBarShowBrand,
                showWorkspaces: root.topBarShowWorkspaces,
                clockFormat: root.clockFormat,
                workspacesCount: root.workspacesCount
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
                sound: root.notificationsSound
            },
            power: {
                profile: root.powerProfile,
                sleepTimeout: root.sleepTimeout
            },
            defaultApps: {
                browser: root.defaultBrowser,
                terminal: root.defaultTerminal,
                fileManager: root.defaultFileManager,
                editor: root.defaultEditor
            },
            system: {
                uiLanguage: root.uiLanguage,
                keyboardLayouts: root.keyboardLayouts
            },
            setupCompleted: root.setupCompleted
        };

        const jsonStr = JSON.stringify(configData, null, 2);
        saveProcess.exec(["bash", "-c", "mkdir -p " + root.userConfigDir + " && cat << 'EOF' > " + root.configPath + "\n" + jsonStr + "\nEOF"]);
    }

    function completeSetup() {
        root.setupCompleted = true;
        saveConfig();
        saveProcess.exec(["bash", "-c", "mkdir -p " + root.userConfigDir + " && echo 'done' > " + root.markerPath]);
    }

    Process {
        id: saveProcess
    }

    Process {
        id: saveThemeProcess
    }

    Process {
        id: gtkThemeProcess
    }

    Process {
        id: wallpaperGsettingsMonitorProc
        command: ["gsettings", "monitor", "org.gnome.desktop.background", "picture-uri"]
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

