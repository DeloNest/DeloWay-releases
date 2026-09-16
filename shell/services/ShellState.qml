pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool appDrawerOpen: false
    property bool quickSettingsOpen: false
    property bool settingsAppOpen: false
    property bool sessionMenuOpen: false
    property bool lockScreenActive: false
    property bool setupWizardOpen: false
    property bool smartNotchExpanded: false
    property int smartNotchTab: 0
    property string searchQuery: ""

    function openSmartNotch() {
        smartNotchTab = 0;
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

    property bool quickSettingsCapsuleExpanded: false
    property string quickSettingsCapsuleView: "wifi"

    function openQuickSettingsCapsule(viewName) {
        quickSettingsCapsuleView = viewName || "wifi";
        quickSettingsCapsuleExpanded = true;
    }

    function closeQuickSettingsCapsule() {
        quickSettingsCapsuleExpanded = false;
    }

    function toggleQuickSettingsCapsule(viewName) {
        if (!quickSettingsCapsuleExpanded) {
            quickSettingsCapsuleView = viewName || "wifi";
        }
        quickSettingsCapsuleExpanded = !quickSettingsCapsuleExpanded;
    }

    function openHotspot() {
        openQuickSettingsCapsule("hotspot");
    }

    function openSetupWizard() {
        setupWizardOpen = true;
    }

    function closeSetupWizard() {
        setupWizardOpen = false;
    }

    function openAppDrawer() {
        quickSettingsOpen = false;
        appStoreOpen = false;
        searchQuery = "";
        appDrawerOpen = true;
    }

    function toggleAppDrawer() {
        if (!appDrawerOpen) {
            quickSettingsOpen = false;
            appStoreOpen = false;
            searchQuery = "";
        }
        appDrawerOpen = !appDrawerOpen;
    }

    function closeAppDrawer() {
        appDrawerOpen = false;
        searchQuery = "";
    }

    property string quickSettingsInitialView: "main"

    function openQuickSettingsWithView(viewName) {
        quickSettingsInitialView = viewName || "main";
        if (!quickSettingsOpen) {
            appDrawerOpen = false;
            appStoreOpen = false;
            quickSettingsOpen = true;
        }
    }

    function toggleQuickSettings() {
        if (!quickSettingsOpen) {
            appDrawerOpen = false;
            appStoreOpen = false;
            quickSettingsInitialView = "main";
        }
        quickSettingsOpen = !quickSettingsOpen;
    }

    function closeQuickSettings() {
        quickSettingsOpen = false;
        quickSettingsInitialView = "main";
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

    function openSettingsTab(tabId) {
        activeSettingsTab = tabId;
        settingsAppOpen = true;
    }

    function closeSettingsApp() {
        settingsAppOpen = false;
        settingsFullScreen = false;
    }

    property bool appStoreOpen: false
    property string storeCategory: "featured"
    property string storeSearchQuery: ""
    property var selectedStoreApp: null

    function openAppStore(category, search) {
        appDrawerOpen = false;
        quickSettingsOpen = false;
        selectedStoreApp = null;
        if (category) storeCategory = category;
        if (search !== undefined) storeSearchQuery = search;
        appStoreOpen = true;
    }

    function toggleAppStore() {
        if (!appStoreOpen) {
            appDrawerOpen = false;
            quickSettingsOpen = false;
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
        quickSettingsOpen = false;
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
            quickSettingsOpen = false;
            appStoreOpen = false;
        }
        cheatSheetOpen = !cheatSheetOpen;
    }

    function openCheatSheet() {
        appDrawerOpen = false;
        quickSettingsOpen = false;
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
        toggleQuickSettings();
    }

    function toggleSessionMenu() {
        if (!sessionMenuOpen) {
            appDrawerOpen = false;
            quickSettingsOpen = false;
            appStoreOpen = false;
        }
        sessionMenuOpen = !sessionMenuOpen;
    }

    function openSessionMenu() {
        appDrawerOpen = false;
        quickSettingsOpen = false;
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
        quickSettingsOpen = false;
        sessionMenuOpen = false;
        appStoreOpen = false;
        settingsAppOpen = false;
        screenshotToolOpen = false;
        cheatSheetOpen = false;
    }
}
