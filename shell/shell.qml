//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// ── Local modules ───────────────────────────────────────────────────────────
import "components"
import "components/settings"
import "theme"
import "services"

ShellRoot {
    id: root

    // ═══════════════════════════════════════════════════════════════════════
    //  GLOBAL SHORTCUTS
    //  Registered at shell level so they work regardless of focus.
    // ═══════════════════════════════════════════════════════════════════════

    // ── Launchers ───────────────────────────────────────────────────────────
    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggles the Deloway Unified Launcher (Super + Space)"
        onPressed: ShellState.toggleAppDrawer()
    }

    GlobalShortcut {
        name: "drawerToggle"
        description: "Toggles the Deloway App Drawer (Super + D / Super + Space)"
        onPressed: ShellState.toggleAppDrawer()
    }

    GlobalShortcut {
        name: "settingsToggle"
        description: "Toggles the Deloway Settings App (Super + I)"
        onPressed: ShellState.toggleSettingsApp()
    }

    GlobalShortcut {
        name: "storeToggle"
        description: "Toggles the Deloway App Store (Super + S)"
        onPressed: ShellState.toggleAppStore()
    }

    // ── Session ─────────────────────────────────────────────────────────────
    GlobalShortcut {
        name: "lockToggle"
        description: "Locks the Deloway session (Super + L)"
        onPressed: lockScreen.lockSession()
    }

    GlobalShortcut {
        name: "sessionMenuToggle"
        description: "Toggles the Deloway Session Menu (Ctrl + Alt + Delete)"
        onPressed: ShellState.toggleSessionMenu()
    }

    // ── Tools ───────────────────────────────────────────────────────────────
    GlobalShortcut {
        name: "screenshotToggle"
        description: "Toggles Deloway Screenshot Tool (Print / Super + Shift + S)"
        onPressed: ShellState.toggleScreenshot()
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggles the Deloway Cheat Sheet (Super + T)"
        onPressed: ShellState.toggleCheatSheet()
    }

    // ── Sidebars ────────────────────────────────────────────────────────────
    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles the Deloway Left Sidebar / App Drawer (Super + A)"
        onPressed: ShellState.toggleLeftSidebar()
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles the Deloway Right Sidebar / Quick Settings (Super + N)"
        onPressed: ShellState.toggleRightSidebar()
    }

    GlobalShortcut {
        name: "quickSettingsToggle"
        description: "Toggles the Deloway Quick Settings (Super + M)"
        onPressed: ShellState.toggleQuickSettings()
    }

    GlobalShortcut {
        name: "smartNotchToggle"
        description: "Toggles Deloway Smart Notch (Super + Alt + N)"
        onPressed: ShellState.toggleSmartNotch()
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  IPC HANDLER  —  scriptable control via `qs -c deloway ipc call ...`
    // ═══════════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "deloway"

        // ── Smart Notch ─────────────────────────────────────────────────────
        function toggleSmartNotch()    { ShellState.toggleSmartNotch(); }
        function openSmartNotch()      { ShellState.openSmartNotch(); }
        function closeSmartNotch()     { ShellState.closeSmartNotch(); }
        function setSmartNotchTab(tab: string) { ShellState.setSmartNotchTab(tab); }
        function stageLocalSend(path: string) {
            ShellState.setSmartNotchTab(1);
            ShellState.openSmartNotch();
            LocalSendService.stageFiles([path || "/tmp/deloway_test.txt"]);
        }
        function resetLocalSend() {
            LocalSendService.resetStage();
        }

        // ── Unified Launcher ────────────────────────────────────────────────
        function toggleLauncher()             { ShellState.toggleAppDrawer(); }
        function openLauncher()               { ShellState.openAppDrawer(); }
        function closeLauncher()              { ShellState.closeAppDrawer(); }

        // ── App Drawer ──────────────────────────────────────────────────────
        function toggleDrawer()        { ShellState.toggleAppDrawer(); }
        function openDrawer()          { ShellState.openAppDrawer(); }
        function closeDrawer()         { ShellState.closeAppDrawer(); }
        function setSearchQuery(query: string) {
            ShellState.openAppDrawer(query);
        }

        // ── Settings ────────────────────────────────────────────────────────
        function toggleSettings()             { ShellState.toggleSettingsApp(); }
        function openSettings(tab: string)    { ShellState.openSettingsTab(tab || "appearance"); }
        function closeSettings()              { ShellState.closeSettingsApp(); }
        function toggleSettingsFullscreen()   { ShellState.toggleSettingsFullscreen(); }
        function isSettingsOpen(): bool       { return ShellState.settingsAppOpen; }
        function openSettingsTab(tabId: string) { ShellState.openSettingsTab(tabId); }
        function scrollSettings(pos: real)    { ShellState.scrollSettings(pos); }

        // ── Sidebars & Session ──────────────────────────────────────────────
        function toggleLeftSidebar()  { ShellState.toggleLeftSidebar(); }
        function toggleRightSidebar() { ShellState.toggleRightSidebar(); }
        function toggleSessionMenu()  { ShellState.toggleSessionMenu(); }
        function toggleQuickSettings(){ ShellState.toggleQuickSettingsCapsule("main"); }
        function openQuickSettings(view: string) { ShellState.openQuickSettingsCapsule(view || "main"); }
        function closeQuickSettings() { ShellState.closeQuickSettingsCapsule(); }
        function toggleCapsule() { ShellState.toggleQuickSettingsCapsule("main"); }
        function openCapsule(view: string) { ShellState.openQuickSettingsCapsule(view || "main"); }
        function closeCapsule() { ShellState.closeQuickSettingsCapsule(); }
        function openHotspot() { ShellState.openHotspot(); }
        function toggleTimeCapsule() { ShellState.toggleTimeCapsule(); }
        function openTimeCapsule()   { ShellState.openTimeCapsule(); }
        function closeTimeCapsule()  { ShellState.closeTimeCapsule(); }

        // ── Cheat Sheet & Screenshot ────────────────────────────────────────
        function toggleCheatsheet() { ShellState.toggleCheatSheet(); }
        function openCheatsheet()   { ShellState.openCheatSheet(); }
        function closeCheatsheet()  { ShellState.closeCheatSheet(); }
        function toggleScreenshot() { ShellState.toggleScreenshot(); }
        function takeScreenshot(mode: string) {
            if (mode === "area")          ScreenshotManager.captureArea();
            else if (mode === "window")   ScreenshotManager.captureWindow();
            else                          ScreenshotManager.captureFullScreen();
        }

        // ── Store ───────────────────────────────────────────────────────────
        function toggleStore()        { ShellState.toggleAppStore(); }
        function openStore(category: string)   { ShellState.openAppStore(category || "featured", ""); }
        function searchStore(query: string)    { ShellState.openAppStore("all", query); }
        function installStoreApp(appId: string){ PackageManager.installApp(appId); }
        function openStoreApp(appId: string) {
            var app = PackageManager.getApp(appId);
            if (app) ShellState.openAppDetails(app);
        }

        // ── Config ──────────────────────────────────────────────────────────
        function setMode(mode: string)          { ConfigManager.setThemeMode(mode); }
        function setUiLanguage(lang: string)    { ConfigManager.setUiLanguage(lang); }
        function setWallpaper(path: string)     { ConfigManager.setWallpaper(path); }
        function setFontSizeScale(scale: real)  { ConfigManager.setFontSizeScale(scale); }
        function setDockPosition(pos: string)   { ConfigManager.setDockPosition(pos); }
        function setDockIconSize(sz: int)       { ConfigManager.setDockIconSize(sz); }
        function setDockAutoHide(val: bool)     { ConfigManager.setDockAutoHide(val); }
        function setDockMode(mode: string)      { ConfigManager.setDockMode(mode); }
        function setDesktopMode(mode: string) {
            DesktopManager.closeContextMenu();
            ConfigManager.setDesktopMode(mode);
        }

        // ── Desktop / Context Menus ─────────────────────────────────────────
        function closeContextMenu() { DesktopManager.closeContextMenu(); }
        function showDesktopContextMenu(x: int, y: int) {
            DesktopManager.showWallpaperContextMenu(x, y);
        }
        function showItemContextMenu(itemId: string, x: int, y: int) {
            var item = DesktopManager.allItems.find(function(i) { return i.id === itemId; });
            if (item) DesktopManager.showItemContextMenu(item, x, y);
        }

        // ── Setup Wizard ────────────────────────────────────────────────────
        function showSetup() { ShellState.openSetupWizard(); }

        // ── Global "close topmost" — used by bindings & hotkeys ─────────────
        // Returns true if something was closed, false otherwise.
        function handleClose(): bool {
            if (ShellState.settingsAppOpen)   { ShellState.closeSettingsApp();   return true; }
            if (ShellState.appDrawerOpen)     { ShellState.closeAppDrawer();     return true; }
            if (ShellState.cheatSheetOpen)    { ShellState.closeCheatSheet();    return true; }
            if (ShellState.quickSettingsCapsuleExpanded) { ShellState.closeQuickSettingsCapsule(); return true; }
            if (ShellState.timeCapsuleExpanded)          { ShellState.closeTimeCapsule();          return true; }
            if (ShellState.appStoreOpen)      { ShellState.closeAppStore();      return true; }
            if (ShellState.sessionMenuOpen)   { ShellState.closeSessionMenu();   return true; }
            return false;
        }

        // Close everything (loops handleClose until nothing responds).
        function closeAll() {
            var guard = 0;
            while (handleClose() && guard++ < 16) { /* keep closing */ }
        }

        function handleFullscreen(): bool {
            if (ShellState.settingsAppOpen) {
                ShellState.toggleSettingsFullscreen();
                return true;
            }
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  GLOBAL SINGLETONS  (one per shell session, not per screen)
    // ═══════════════════════════════════════════════════════════════════════

    // Wayland session lock (ext-session-lock-v1) — must live outside the
    // per-screen Variants loop, otherwise each monitor would spawn its own lock.
    LockScreen {
        id: lockScreen
    }

    // Bridge: if anything sets `ShellState.lockScreenActive`, perform the lock.
    Connections {
        target: ShellState
        function onLockScreenActiveChanged() {
            if (ShellState.lockScreenActive) {
                lockScreen.lockSession();
                ShellState.lockScreenActive = false;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PER-SCREEN COMPONENTS
    //  Every physical monitor gets its own instance of each UI panel so
    //  multi-monitor setups behave correctly (hotplug-safe).
    // ═══════════════════════════════════════════════════════════════════════

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: screenScope
            required property ShellScreen modelData

            // ── Always-on surfaces ──────────────────────────────────────────
            Background   { targetScreen: screenScope.modelData }
            Loader {
                active: ConfigManager.dockMode !== "disabled"
                sourceComponent: Component {
                    Dock { targetScreen: screenScope.modelData }
                }
            }
            Notch        { targetScreen: screenScope.modelData }
            QuickSettingsCapsule { targetScreen: screenScope.modelData }
            TimeCapsule  { targetScreen: screenScope.modelData }

            // ── On-demand overlays ──────────────────────────────────────────
            AppDrawer        { targetScreen: screenScope.modelData }
            NotificationToast{ targetScreen: screenScope.modelData }

            // NOTE: previously missing. GlobalShortcut "sessionMenuToggle" and
            // IpcHandler.toggleSessionMenu() both called ShellState.toggleSessionMenu(),
            // but no visual surface ever rendered it — Ctrl+Alt+Delete did nothing.
            SessionMenu      { targetScreen: screenScope.modelData }

            // ── Full-screen apps / tools ────────────────────────────────────
            SettingsAppV2  { targetScreen: screenScope.modelData }
            SetupWizard    { targetScreen: screenScope.modelData }
            AppStore       { targetScreen: screenScope.modelData }
            ScreenshotTool { targetScreen: screenScope.modelData }
            CheatSheet     { targetScreen: screenScope.modelData }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STARTUP
    // ═══════════════════════════════════════════════════════════════════════

    Component.onCompleted: {
        const screenCount = Quickshell.screens.length;
        console.log("[Deloway] Shell initialised — "
                    + screenCount + " screen(s), "
                    + "Fluent components loaded, "
                    + "DeloOS services ready.");
    }
}
