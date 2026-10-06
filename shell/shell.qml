//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// ── Local modules ───────────────────────────────────────────────────────────
import "components"
import "components/settings"
import "components/desktop"
import "theme"
import "services"

ShellRoot {
    id: root

    // Zero hot-reload policy (CLAUDE.md): a live QML reload can crash Quickshell, and a
    // `git pull` used to trigger one through the file watcher. Restart the shell instead.
    settings.watchFiles: false

    // ═══════════════════════════════════════════════════════════════════════
    //  GLOBAL SHORTCUTS
    //  Registered at shell level so they work regardless of focus.
    // ═══════════════════════════════════════════════════════════════════════

    // ── Launchers ───────────────────────────────────────────────────────────
    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggles the Deloway Search Launcher (Super alone / Super + Space)"
        onPressed: ShellState.toggleLauncher()
    }

    // ── Shell Toggle (Super alone) ──────────────────────────────────────────
    GlobalShortcut {
        name: "shellToggle"
        description: "Immersion mode: hide top capsules and dock (Super + Shift + F)"
        onPressed: ShellState.toggleShell()
    }

    GlobalShortcut {
        name: "drawerToggle"
        description: "Toggles the Deloway Search Launcher (Super + Space)"
        onPressed: ShellState.toggleLauncher()
    }

    // ── Start menu (Super tap) ──────────────────────────────────────────────
    // Tap-vs-combo detection (Hyprland alone can't tell them apart — a release bind
    // fires even after Super+1):
    //   startMenuSuper     : Super pressed  → arm;  Super released → toggle if still armed
    //   startMenuInterrupt : ANY other key / mouse button / wheel while Super is held
    //                        (transparent, non-consuming catch-all) → disarm
    // So Super+<anything> keeps its own action and never opens the menu.
    property bool startMenuArmed: false

    GlobalShortcut {
        name: "startMenuSuper"
        description: "Tap Super: toggle the Start-style App Drawer"
        onPressed: root.startMenuArmed = true
        onReleased: {
            if (root.startMenuArmed) ShellState.toggleAppDrawer();
            root.startMenuArmed = false;
        }
    }

    GlobalShortcut {
        name: "startMenuInterrupt"
        description: "Internal: a Super combo happened, cancel the pending Start-menu tap"
        onPressed: root.startMenuArmed = false
    }

    GlobalShortcut {
        name: "appDrawerToggle"
        description: "Toggles the Deloway App Drawer (Super + A)"
        onPressed: ShellState.toggleAppDrawer()
    }

    GlobalShortcut {
        name: "settingsToggle"
        description: "Toggles the Deloway Settings App (Super + I)"
        onPressed: ShellState.toggleSettingsApp()
    }

    GlobalShortcut {
        name: "clipboardToggle"
        description: "Toggles the Deloway Clipboard Manager (Super + V)"
        onPressed: ShellState.toggleClipboard()
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

        // ── Session lock (Super+L runs `qs ipc … call deloway lock || hyprlock`) ─
        function lock() { lockScreen.lockSession(); }

        // ── Shell Toggle / Fullscreen ───────────────────────────────────────
        function toggleShell() { ShellState.toggleShell(); }
        function hideShell()   { ShellState.setShellHidden(true); }
        function showShell()   { ShellState.setShellHidden(false); }

        // ── Smart Notch ─────────────────────────────────────────────────────
        function toggleSmartNotch()    { ShellState.toggleSmartNotch(); }
        function openSmartNotch()      { ShellState.openSmartNotch(); }
        function closeSmartNotch()     { ShellState.closeSmartNotch(); }
        function setSmartNotchTab(tab: string) { ShellState.setSmartNotchTab(tab); }
        function stageLocalSend(path: string) {
            if (!path) return;   // no test-fixture fallback
            ShellState.setSmartNotchTab(2);
            ShellState.openSmartNotch();
            LocalSendService.stageFiles([path]);
        }
        function resetLocalSend() {
            LocalSendService.resetStage();
        }

        // ── Search Launcher (Spotlight) ─────────────────────────────────────
        function toggleLauncher()             { ShellState.toggleLauncher(); }
        function openLauncher(query: string)  { ShellState.openLauncher(query || ""); }
        function closeLauncher()              { ShellState.closeLauncher(); }

        // ── Clipboard Manager ───────────────────────────────────────────────
        function toggleClipboard()            { ShellState.toggleClipboard(); }
        function openClipboard()              { ShellState.openClipboard(); }
        function closeClipboard()             { ShellState.closeClipboard(); }

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
        // Settings → Apps → details card for a desktop id (same as the app menu's "App Info").
        function openAppInfo(desktopId: string) { AppActions.openInfo(AppActions.entryFor(desktopId)); }

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
        function setTimeCapsuleTab(tab: int) { ShellState.setTimeCapsuleTab(tab); }
        function startTimer(minutes: int) {
            TimeKeeperService.setTimerMinutes(minutes > 0 ? minutes : 5);
            TimeKeeperService.startTimer();
        }
        function stopAlarm() { TimeKeeperService.dismissAlarm(); }
        function setAlarm(time: string) {
            const t = TimeKeeperService.parseTime(time);
            if (!t) return;
            const hm = t.split(":");
            TimeKeeperService.setAlarmTime(parseInt(hm[0]), parseInt(hm[1]));
            TimeKeeperService.setAlarmEnabled(true);
        }
        function disableAlarm() { TimeKeeperService.setAlarmEnabled(false); }
        function removeReminder(id: string) { TimeKeeperService.removeEvent(id); }
        // Generic settings hook: `ipc call deloway setSetting performanceTier 0`
        // Calls the SAME ConfigManager setter the Settings UI uses (set<Key>).
        function setSetting(key: string, value: string): bool {
            if (!key) return false;
            const fn = "set" + key.charAt(0).toUpperCase() + key.slice(1);
            if (typeof ConfigManager[fn] !== "function") return false;
            let v = value;
            if (value === "true" || value === "false") v = (value === "true");
            else if (value !== "" && !isNaN(Number(value))) v = Number(value);
            ConfigManager[fn](v);
            return true;
        }
        // The same as picking an app in Settings → Apps / the Setup Wizard: a catalog app
        // that is not installed is installed first. role: browser | terminal | fileManager |
        // editor | monitor; desktopId: e.g. org.kde.dolphin.
        function setDefaultApp(role: string, desktopId: string): string {
            const opt = DefaultApps.options(role).find(o => o.desktop.toLowerCase() === desktopId.toLowerCase());
            if (!opt) return "unknown";
            DefaultApps.choose(role, opt);
            return opt.installed ? "chosen" : "installing";
        }
        function getSetting(key: string): string {
            const v = ConfigManager[key];
            return v === undefined ? "undefined" : JSON.stringify(v);
        }
        // Dock: the same action as a left click on an app's icon (focus / minimize / restore / cycle / launch).
        function dockClick(appId: string): string {
            const e = ApplicationManager.dockApps.find(x => x.id === appId);
            if (!e) return "not-in-dock";
            ApplicationManager.clickDockApp(e);
            return "ok";
        }
        function dockState(): string {
            return JSON.stringify(ApplicationManager.dockApps.map(e => ({
                id: e.id, pinned: e.pinned, running: e.running, active: e.isActive,
                windows: e.windowCount, allMinimized: e.allMinimized, urgent: e.urgent })));
        }
        function controlCenterState(): string {
            const c = ControlCenterService;
            return JSON.stringify({ chassis: c.chassis, hasBattery: c.hasBattery, isPortable: c.isPortable,
                                    airplaneMode: c.airplaneMode, showAirplaneToggle: c.showAirplaneToggle,
                                    screenSleepArmed: c.screenSleepArmed, screenSleepTimeoutSec: c.screenSleepTimeoutSec,
                                    displayAsleep: c.displayAsleep });
        }
        function timekeeperState(): string {
            const tk = TimeKeeperService;
            return JSON.stringify({
                timer: { running: tk.timerRunning, finished: tk.timerFinished, remaining: tk.timerRemainingSec, total: tk.timerTotalSec },
                alarm: { enabled: tk.alarmEnabled, time: tk.pad2(tk.alarmHour) + ":" + tk.pad2(tk.alarmMinute),
                         next: tk.nextAlarmAt ? new Date(tk.nextAlarmAt).toISOString() : null, ringing: tk.alarmRinging },
                events: tk.events.length
            });
        }
        function addReminder(date: string, time: string, title: string): bool {
            const key = (date && date !== "today") ? date : TimeKeeperService.dateKey(new Date());
            return TimeKeeperService.addEvent(key, title, time);
        }

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
        // Start the inline rename of a desktop item (as its menu's "Rename…" does)
        function renameDesktopItem(itemId: string): bool {
            const item = DesktopManager.allItems.find(i => i.id === itemId);
            if (!item || item.isSystem) return false;
            DesktopManager.startRenaming(item.id);
            return true;
        }
        function showItemContextMenu(itemId: string, x: int, y: int) {
            var item = DesktopManager.allItems.find(function(i) { return i.id === itemId; });
            if (item) DesktopManager.showItemContextMenu(item, x, y);
        }

        // ── Setup Wizard ────────────────────────────────────────────────────
        function showSetup() { ShellState.openSetupWizard(0); }
        function showSetupStep(step: int) { ShellState.openSetupWizard(step); }
        function closeSetup() { if (ConfigManager.setupCompleted) ShellState.closeSetupWizard(); }

        // ── Global "close topmost" — used by bindings & hotkeys ─────────────
        // Returns true if something was closed, false otherwise.
        function handleClose(): bool {
            if (ShellState.launcherOpen)      { ShellState.closeLauncher();      return true; }
            if (ShellState.settingsAppOpen)   { ShellState.closeSettingsApp();   return true; }
            if (ShellState.clipboardOpen)     { ShellState.closeClipboard();     return true; }
            if (ShellState.appDrawerOpen)     { ShellState.closeAppDrawer();     return true; }
            if (ShellState.cheatSheetOpen)    { ShellState.closeCheatSheet();    return true; }
            if (ShellState.quickSettingsCapsuleExpanded) { ShellState.closeQuickSettingsCapsule(); return true; }
            if (ShellState.timeCapsuleExpanded)          { ShellState.closeTimeCapsule();          return true; }
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
            DesktopContextMenu { targetScreen: screenScope.modelData }
            Loader {
                active: ConfigManager.dockMode !== "disabled"
                sourceComponent: Component {
                    Dock { targetScreen: screenScope.modelData }
                }
            }
            // Unified top bar: TimeCapsule + Notch + QuickSettingsCapsule in ONE surface
            TopBar       { targetScreen: screenScope.modelData }

            // ── On-demand overlays ──────────────────────────────────────────
            SearchLauncher   { targetScreen: screenScope.modelData }
            AppDrawer        { targetScreen: screenScope.modelData }
            ClipboardManager { targetScreen: screenScope.modelData }
            NotificationToast{ targetScreen: screenScope.modelData }

            // NOTE: previously missing. GlobalShortcut "sessionMenuToggle" and
            // IpcHandler.toggleSessionMenu() both called ShellState.toggleSessionMenu(),
            // but no visual surface ever rendered it — Ctrl+Alt+Delete did nothing.
            SessionMenu      { targetScreen: screenScope.modelData }

            // ── Full-screen apps / tools ────────────────────────────────────
            SettingsAppV2  { targetScreen: screenScope.modelData }
            SetupWizard    { targetScreen: screenScope.modelData }
            ScreenshotTool { targetScreen: screenScope.modelData }
            CheatSheet     { targetScreen: screenScope.modelData }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STARTUP
    // ═══════════════════════════════════════════════════════════════════════

    // A missing icon theme turns every app icon into a letter and every theme glyph into a
    // placeholder. Say so once instead of failing silently (install.sh builds the theme).
    Timer {
        interval: 4000
        running: true
        onTriggered: {
            if (Quickshell.hasThemeIcon("folder") || Quickshell.hasThemeIcon("application-x-executable")) return;
            const theme = Quickshell.env("QS_ICON_THEME") || "Reversal-black-dark";
            console.warn("[Deloway] Icon theme '" + theme + "' is not installed; icons fall back to placeholders.");
            NotificationManager.postNotification("DeloWay", I18n.tr("icon_theme_missing_title"),
                I18n.tr("icon_theme_missing_body").replace("%1", I18n.isolate(theme)), "dialog-warning-symbolic");
        }
    }

    Component.onCompleted: {
        // Shortcuts changed in Settings are runtime binds: start the service so it applies
        // them now (it re-applies after every Hyprland config reload).
        ShortcutService.refresh();
        const screenCount = Quickshell.screens.length;
        console.log("[Deloway] Shell initialised — "
                    + screenCount + " screen(s), "
                    + "Fluent components loaded, "
                    + "DeloOS services ready.");
    }
}
