pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool appDrawerOpen: false
    property bool settingsAppOpen: false
    property bool sessionMenuOpen: false
    property bool lockScreenActive: false
    property bool setupWizardOpen: false
    property bool smartNotchExpanded: false
    property int smartNotchTab: 0
    property real smartNotchCurrentWidth: 200
    property string searchQuery: ""

    function openSmartNotch(tab) {
        if (tab !== undefined && tab !== null && tab !== "") {
            smartNotchTab = parseInt(tab) || 0;
        }
        smartNotchExpanded = true;
    }

    function closeSmartNotch() {
        smartNotchExpanded = false;
    }

    function toggleSmartNotch() {
        if (!smartNotchExpanded) smartNotchTab = 0;
        smartNotchExpanded = !smartNotchExpanded;
    }

    function setSmartNotchTab(index) {
        smartNotchTab = parseInt(index) || 0;
    }

    property bool timeCapsuleExpanded: false

    function openTimeCapsule() {
        appDrawerOpen = false;
        appStoreOpen = false;
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
        appDrawerOpen = false;
        appStoreOpen = false;
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
            appDrawerOpen = false;
            appStoreOpen = false;
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

    function openAppDrawer(initialQuery) {
        quickSettingsCapsuleExpanded = false;
        appStoreOpen = false;
        searchQuery = (typeof initialQuery === "string") ? initialQuery : "";
        appDrawerOpen = true;
    }

    function toggleAppDrawer() {
        if (!appDrawerOpen) {
            quickSettingsCapsuleExpanded = false;
            appStoreOpen = false;
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
        quickSettingsCapsuleExpanded = false;
        appDrawerOpen = false;
        appStoreOpen = false;
        clipboardOpen = true;
    }

    function toggleClipboard() {
        if (!clipboardOpen) {
            quickSettingsCapsuleExpanded = false;
            appDrawerOpen = false;
            appStoreOpen = false;
        }
        clipboardOpen = !clipboardOpen;
    }

    function closeClipboard() {
        clipboardOpen = false;
    }

    property string activeSettingsTab: "appearance"
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

    function openSettingsTab(tabId) {
        activeSettingsTab = tabId;
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

    property bool appStoreOpen: false
    property string storeCategory: "featured"
    property string storeSearchQuery: ""
    property var selectedStoreApp: null

    function openAppStore(category, search) {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        selectedStoreApp = null;
        if (category) storeCategory = category;
        if (search !== undefined) storeSearchQuery = search;
        appStoreOpen = true;
    }

    function toggleAppStore() {
        if (!appStoreOpen) {
            appDrawerOpen = false;
            quickSettingsCapsuleExpanded = false;
            selectedStoreApp = null;
        }
        appStoreOpen = !appStoreOpen;
    }

    function closeAppStore() {
        appStoreOpen = false;
        selectedStoreApp = null;
    }

    function openAppDetails(app) {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        selectedStoreApp = app;
        appStoreOpen = true;
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
            appStoreOpen = false;
        }
        cheatSheetOpen = !cheatSheetOpen;
    }

    function openCheatSheet() {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        appStoreOpen = false;
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
            appStoreOpen = false;
        }
        sessionMenuOpen = !sessionMenuOpen;
    }

    function openSessionMenu() {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        appStoreOpen = false;
        sessionMenuOpen = true;
    }

    function closeSessionMenu() {
        sessionMenuOpen = false;
    }


    function lock() {
        closeAll();
        lockScreenActive = true;
    }

    function closeAll() {
        appDrawerOpen = false;
        quickSettingsCapsuleExpanded = false;
        sessionMenuOpen = false;
        appStoreOpen = false;
        settingsAppOpen = false;
        screenshotToolOpen = false;
        cheatSheetOpen = false;
    }
}
