pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool appDrawerOpen: false
    property bool launcherOpen: false
    property string launcherQuery: ""
    property bool settingsAppOpen: false
    property bool sessionMenuOpen: false
    property bool lockScreenActive: false
    property bool setupWizardOpen: false
    property bool smartNotchExpanded: false
    property int smartNotchTab: 0
    property real smartNotchCurrentWidth: 200
    property string searchQuery: ""

    function openSmartNotch(tab) {
        timeCapsuleExpanded = false;
        quickSettingsCapsuleExpanded = false;
        launcherOpen = false;
        appDrawerOpen = false;
        cheatSheetOpen = false;
        sessionMenuOpen = false;
        if (tab !== undefined && tab !== null && tab !== "") {
            smartNotchTab = parseInt(tab) || 0;
        }
        smartNotchExpanded = true;
    }

    function closeSmartNotch() {
        smartNotchExpanded = false;
    }

    function toggleSmartNotch() {
        if (!smartNotchExpanded) {
            openSmartNotch();
        } else {
            closeSmartNotch();
        }
    }

    function setSmartNotchTab(index) {
        smartNotchTab = parseInt(index) || 0;
    }

    property bool timeCapsuleExpanded: false
    // 0 = Time & Utilities, 1 = System & Hardware. Survives open/close.
    property int timeCapsuleTab: 0

    function setTimeCapsuleTab(tab) {
        timeCapsuleTab = Math.max(0, Math.min(1, parseInt(tab) || 0));
    }

    function openTimeCapsule() {
        smartNotchExpanded = false;
        quickSettingsCapsuleExpanded = false;
        launcherOpen = false;
        appDrawerOpen = false;
        cheatSheetOpen = false;
        sessionMenuOpen = false;
        timeCapsuleExpanded = true;
    }

    function closeTimeCapsule() {
        timeCapsuleExpanded = false;
    }

    function toggleTimeCapsule() {
        if (!timeCapsuleExpanded) {
            openTimeCapsule();
        } else {
            closeTimeCapsule();
        }
    }

    property bool quickSettingsCapsuleExpanded: false
    property string quickSettingsCapsuleView: "main"

    function openQuickSettingsCapsule(viewName) {
        smartNotchExpanded = false;
        timeCapsuleExpanded = false;
        launcherOpen = false;
        appDrawerOpen = false;
        cheatSheetOpen = false;
        sessionMenuOpen = false;
        quickSettingsCapsuleView = viewName || "main";
        quickSettingsCapsuleExpanded = true;
    }

    function closeQuickSettingsCapsule() {
        quickSettingsCapsuleExpanded = false;
    }

    function toggleQuickSettingsCapsule(viewName) {
        if (!quickSettingsCapsuleExpanded) {
            smartNotchExpanded = false;
            timeCapsuleExpanded = false;
            launcherOpen = false;
            appDrawerOpen = false;
            cheatSheetOpen = false;
            sessionMenuOpen = false;
            quickSettingsCapsuleView = viewName || "main";
            quickSettingsCapsuleExpanded = true;
        } else {
            if (viewName && quickSettingsCapsuleView !== viewName) {
                quickSettingsCapsuleView = viewName;
            } else {
                quickSettingsCapsuleExpanded = false;
            }
        }
    }

    function openHotspot() {
        openQuickSettingsCapsule("hotspot");
    }

    // Aliases directing legacy calls to the capsule exclusively
    function toggleQuickSettings() {
        toggleQuickSettingsCapsule("main");
    }

    function openQuickSettings(view) {
        openQuickSettingsCapsule(view || "main");
    }

    function openQuickSettingsWithView(viewName) {
        openQuickSettingsCapsule(viewName || "main");
    }

    function closeQuickSettings() {
        closeQuickSettingsCapsule();
    }

    function openSetupWizard() {
        setupWizardOpen = true;
    }

    function closeSetupWizard() {
        setupWizardOpen = false;
    }

    // ── Search Launcher (Spotlight / Raycast) ───────────────────────────
    function openLauncher(initialQuery) {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        timeCapsuleExpanded = false;
        cheatSheetOpen = false;
        sessionMenuOpen = false;
        clipboardOpen = false;
        launcherQuery = (typeof initialQuery === "string") ? initialQuery : "";
        launcherOpen = true;
    }

    function closeLauncher() {
        launcherOpen = false;
        launcherQuery = "";
    }

    function toggleLauncher() {
        if (!launcherOpen) {
            openLauncher();
        } else {
            closeLauncher();
        }
    }

    // ── App Drawer ───────────────────────────────────────────────────────
    function openAppDrawer(initialQuery) {
        launcherOpen = false;
        quickSettingsCapsuleExpanded = false;
        searchQuery = (typeof initialQuery === "string") ? initialQuery : "";
        appDrawerOpen = true;
    }

    function toggleAppDrawer() {
        if (!appDrawerOpen) {
            launcherOpen = false;
            quickSettingsCapsuleExpanded = false;
            searchQuery = "";
        }
        appDrawerOpen = !appDrawerOpen;
    }

    function closeAppDrawer() {
        appDrawerOpen = false;
        searchQuery = "";
    }

    // ── Clipboard Manager ───────────────────────────────────────────────
    property bool clipboardOpen: false

    function openClipboard() {
        launcherOpen = false;
        quickSettingsCapsuleExpanded = false;
        appDrawerOpen = false;
        clipboardOpen = true;
    }

    function toggleClipboard() {
        if (!clipboardOpen) {
            launcherOpen = false;
            quickSettingsCapsuleExpanded = false;
            appDrawerOpen = false;
        }
        clipboardOpen = !clipboardOpen;
    }

    function closeClipboard() {
        clipboardOpen = false;
    }

    // ── Settings navigation registry (single source of truth) ───────────
    // Sidebar groups, page order, icons and source files all come from here, so the
    // sidebar and the page loader can never disagree.
    readonly property var settingsGroups: [
        { id: "connectivity",    pages: ["network", "bluetooth"] },
        { id: "personalization", pages: ["appearance", "wallpaper", "topbar", "dock"] },
        { id: "system",          pages: ["windows", "notifications", "power", "apps", "time_language", "about"] }
    ]
    readonly property var settingsPages: ({
        "network":       { icon: "network-wireless-symbolic",                 file: "NetworkTab.qml" },
        "bluetooth":     { icon: "bluetooth-active-symbolic",                 file: "BluetoothTab.qml" },
        "appearance":    { icon: "applications-graphics-symbolic",            file: "AppearanceTab.qml" },
        "wallpaper":     { icon: "preferences-desktop-wallpaper-symbolic",    file: "WallpaperTab.qml" },
        "topbar":        { icon: "preferences-desktop-display-symbolic",      file: "TopBarTab.qml" },
        "dock":          { icon: "view-app-grid-symbolic",                    file: "DockTab.qml" },
        "windows":       { icon: "window-new-symbolic",                       file: "WindowsTab.qml" },
        "notifications": { icon: "preferences-system-notifications-symbolic", file: "NotificationsTab.qml" },
        "power":         { icon: "system-shutdown-symbolic",                  file: "PowerTab.qml" },
        "apps":          { icon: "applications-system-symbolic",              file: "AppsTab.qml" },
        "time_language": { icon: "preferences-desktop-locale-symbolic",       file: "TimeLanguageTab.qml" },
        "about":         { icon: "help-about-symbolic",                       file: "AboutTab.qml" }
    })
    // Old / external ids (launcher shortcuts, desktop menu, IPC, saved state) → current page.
    readonly property var settingsAliases: ({
        "connectivity": "network", "wifi": "network", "hotspot": "network",
        "desktop": "wallpaper", "workspaces": "windows",
        "system": "about", "applications": "apps", "default_apps": "apps", "music": "apps",
        "language": "time_language", "time": "time_language",
        "shortcuts": "about", "theme": "appearance"
    })
    function resolveSettingsTab(tabId) {
        if (!tabId) return "network";
        if (settingsPages[tabId]) return tabId;
        const alias = settingsAliases[tabId];
        return (alias && settingsPages[alias]) ? alias : "network";
    }

    property string activeSettingsTab: "network"
    property bool settingsFullScreen: false

    function toggleSettingsFullscreen() {
        settingsFullScreen = !settingsFullScreen;
    }

    function toggleSettingsApp() {
        if (settingsAppOpen) {
            settingsAppOpen = false;
            settingsFullScreen = false;
        } else {
            settingsAppOpen = true;
        }
    }

    function openSettingsApp() {
        settingsAppOpen = true;
    }

    // Settings → Apps shows a details card for this desktop id (set by the app menu).
    property string appInfoId: ""
    signal appInfoRequested(string desktopId)
    function openAppInfo(desktopId) {
        appInfoId = desktopId || "";
        openSettingsTab("apps");
        settingsScrollRequested(0);
        appInfoRequested(appInfoId);
    }

    function openSettingsTab(tabId) {
        activeSettingsTab = resolveSettingsTab(tabId);
        settingsAppOpen = true;
    }

    function closeSettingsApp() {
        settingsAppOpen = false;
        settingsFullScreen = false;
    }

    signal settingsScrollRequested(real position)
    function scrollSettings(pos) {
        settingsScrollRequested(pos);
    }

    property bool screenshotToolOpen: false

    function openScreenshot() {
        screenshotToolOpen = true;
    }

    function closeScreenshot() {
        screenshotToolOpen = false;
    }

    function toggleScreenshot() {
        screenshotToolOpen = !screenshotToolOpen;
    }

    // ── Cheat Sheet ────────────────────────────────────────
    property bool cheatSheetOpen: false

    function toggleCheatSheet() {
        if (!cheatSheetOpen) {
            appDrawerOpen = false;
            quickSettingsCapsuleExpanded = false;
        }
        cheatSheetOpen = !cheatSheetOpen;
    }

    function openCheatSheet() {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        cheatSheetOpen = true;
    }

    function closeCheatSheet() {
        cheatSheetOpen = false;
    }

    // ── Sidebars ───────────────────────────────────────────
    function toggleLeftSidebar() {
        toggleAppDrawer();
    }

    function toggleRightSidebar() {
        toggleQuickSettingsCapsule("main");
    }

    function toggleSessionMenu() {
        if (!sessionMenuOpen) {
            appDrawerOpen = false;
            quickSettingsCapsuleExpanded = false;
        }
        sessionMenuOpen = !sessionMenuOpen;
    }

    function openSessionMenu() {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        sessionMenuOpen = true;
    }

    function closeSessionMenu() {
        sessionMenuOpen = false;
    }

    // ── Shell Visibility / Immersion Mode (Super key toggle) ────────
    property bool shellHidden: false

    function toggleShell() {
        if (!shellHidden) {
            closeAll();
            shellHidden = true;
        } else {
            shellHidden = false;
        }
        console.log("[Deloway] toggleShell executed. shellHidden =", shellHidden);
    }

    function setShellHidden(val) {
        if (val) {
            closeAll();
            shellHidden = true;
        } else {
            shellHidden = false;
        }
    }

    function lock() {
        closeAll();
        lockScreenActive = true;
    }

    function closeAll() {
        launcherOpen = false;
        appDrawerOpen = false;
        smartNotchExpanded = false;
        timeCapsuleExpanded = false;
        quickSettingsCapsuleExpanded = false;
        sessionMenuOpen = false;
        settingsAppOpen = false;
        screenshotToolOpen = false;
        cheatSheetOpen = false;
    }
}
