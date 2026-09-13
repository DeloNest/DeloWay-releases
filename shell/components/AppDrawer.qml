import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors { bottom: true }

    margins { bottom: 84 }

    implicitWidth: 780
    implicitHeight: 560
    color: "transparent"

    WlrLayershell.namespace: "deloway:appdrawer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.appDrawerOpen
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    visible: ShellState.appDrawerOpen || drawerHost.opacity > 0.005
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────
    // Design tokens (harmonized with Notch OLED deep black aesthetic)
    // ─────────────────────────────────────────────────────────────────────
    readonly property int radiusCard: Theme.notchRadiusWindow
    readonly property int radiusPanel: Theme.notchRadiusPanel
    readonly property int radiusItem: Theme.notchRadiusCard
    readonly property int radiusPill: Theme.notchRadiusPill

    // Pure deep black OLED background matching Notch
    readonly property color colorBackground: Theme.notchBackground
    readonly property color colorSurface: Theme.notchSurface
    readonly property color colorElevated: Theme.notchSurfaceElevated

    readonly property color colorBorder: Theme.notchBorder
    readonly property color colorBorderSoft: Theme.notchBorderSubtle
    readonly property color colorBorderStrong: Theme.notchBorderHighlight

    readonly property color colorHover: Theme.notchSurfaceHover
    readonly property color colorHoverStrong: Theme.notchSurfaceActive
    readonly property color colorSelected: Qt.rgba(Theme.colors.accent.r, Theme.colors.accent.g, Theme.colors.accent.b, 0.28)

    readonly property color colorText: Theme.notchText
    readonly property color colorTextSecondary: Theme.notchTextSecondary
    readonly property color colorTextTertiary: Theme.notchTextTertiary

    readonly property color colorAccent: Theme.colors.accent
    readonly property color colorUrgent: Theme.colors.urgent

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────
    property string filterQuery: ""
    property string selectedCategory: "All"
    property int selectedIndex: 0

    readonly property var allApps: ApplicationManager.allApps

    // ─────────────────────────────────────────────────────────────────────
    // Data
    // ─────────────────────────────────────────────────────────────────────
    readonly property var settingsIndex: [
        {
            "id": "appearance",
            "type": "setting",
            "badge": "SETTING",
            "name": "Appearance & Theme",
            "desc": "Dark Mode, Light Mode, Accent colors, Calm Mica",
            "icon": "applications-graphics-symbolic",
            "isAppIcon": false,
            "keywords": ["theme", "dark", "light", "color", "accent", "appearance", "mica"]
        },
        {
            "id": "desktop",
            "type": "setting",
            "badge": "SETTING",
            "name": "Desktop & Wallpaper",
            "desc": "Desktop mode, icons, widgets, and wallpaper",
            "icon": "user-home-symbolic",
            "isAppIcon": false,
            "keywords": ["desktop", "wallpaper", "background", "icons", "clean", "widgets", "traditional"]
        },
        {
            "id": "dock",
            "type": "setting",
            "badge": "SETTING",
            "name": "Dock Settings",
            "desc": "Dock position, auto-hide, icon size, active indicator",
            "icon": "view-app-grid-symbolic",
            "isAppIcon": false,
            "keywords": ["dock", "taskbar", "autohide", "size", "pin"]
        },
        {
            "id": "topbar",
            "type": "setting",
            "badge": "SETTING",
            "name": "Top Bar",
            "desc": "Clock format, workspaces count, brand logo",
            "icon": "preferences-system-symbolic",
            "isAppIcon": false,
            "keywords": ["topbar", "bar", "clock", "workspaces", "brand"]
        },
        {
            "id": "windows",
            "type": "setting",
            "badge": "SETTING",
            "name": "Window Management",
            "desc": "Active borders, gaps, corner rounding",
            "icon": "view-fullscreen-symbolic",
            "isAppIcon": false,
            "keywords": ["window", "border", "gaps", "rounding", "hyprland"]
        },
        {
            "id": "shortcuts",
            "type": "setting",
            "badge": "SETTING",
            "name": "Keyboard Shortcuts",
            "desc": "Keybindings reference and Super key cheat sheet",
            "icon": "preferences-desktop-keyboard-shortcuts-symbolic",
            "isAppIcon": false,
            "keywords": ["shortcuts", "keys", "hotkeys", "keyboard", "super"]
        },
        {
            "id": "network",
            "type": "setting",
            "badge": "SETTING",
            "name": "Network & Wi-Fi",
            "desc": "Wi-Fi, Ethernet, IP address, signal strength",
            "icon": "network-wireless-symbolic",
            "isAppIcon": false,
            "keywords": ["network", "wifi", "internet", "ethernet", "ip", "wireless"]
        },
        {
            "id": "bluetooth",
            "type": "setting",
            "badge": "SETTING",
            "name": "Bluetooth",
            "desc": "Bluetooth devices, pairing, adapters",
            "icon": "bluetooth-active-symbolic",
            "isAppIcon": false,
            "keywords": ["bluetooth", "pair", "device", "audio"]
        },
        {
            "id": "power",
            "type": "setting",
            "badge": "SETTING",
            "name": "Power & Battery",
            "desc": "Power profiles, sleep timeout, battery status",
            "icon": "power-profile-balanced-symbolic",
            "isAppIcon": false,
            "keywords": ["power", "battery", "sleep", "profile", "saver", "performance"]
        },
        {
            "id": "notifications",
            "type": "setting",
            "badge": "SETTING",
            "name": "Notifications",
            "desc": "Do Not Disturb, banners, sounds",
            "icon": "preferences-system-notifications-symbolic",
            "isAppIcon": false,
            "keywords": ["notification", "dnd", "timeout", "alert"]
        },
        {
            "id": "applications",
            "type": "setting",
            "badge": "SETTING",
            "name": "Default Applications",
            "desc": "Default browser, terminal, file manager, editor",
            "icon": "applications-other-symbolic",
            "isAppIcon": false,
            "keywords": ["apps", "default", "browser", "terminal", "editor", "files"]
        },
        {
            "id": "about",
            "type": "setting",
            "badge": "SETTING",
            "name": "About DeloOS",
            "desc": "System info, kernel version, Wayland engine",
            "icon": "dialog-information-symbolic",
            "isAppIcon": false,
            "keywords": ["about", "deloos", "system", "kernel", "specs"]
        }
    ]

    readonly property var systemActions: [
        {
            "id": "lock",
            "type": "action",
            "badge": "SYSTEM",
            "name": "Lock Screen",
            "desc": "Lock current Wayland session",
            "icon": "changes-prevent-symbolic",
            "isAppIcon": false,
            "keywords": ["lock", "screen", "session", "sleep"]
        },
        {
            "id": "logout",
            "type": "action",
            "badge": "SYSTEM",
            "name": "Log Out",
            "desc": "Exit desktop session to display manager",
            "icon": "system-log-out-symbolic",
            "isAppIcon": false,
            "keywords": ["logout", "log out", "exit", "quit"]
        },
        {
            "id": "restart",
            "type": "action",
            "badge": "SYSTEM",
            "name": "Restart System",
            "desc": "Reboot the computer safely",
            "icon": "system-reboot-symbolic",
            "isAppIcon": false,
            "keywords": ["restart", "reboot"]
        },
        {
            "id": "shutdown",
            "type": "action",
            "badge": "SYSTEM",
            "name": "Shut Down",
            "desc": "Power off the computer",
            "icon": "system-shutdown-symbolic",
            "isAppIcon": false,
            "keywords": ["shutdown", "power off", "turn off", "halt"]
        }
    ]

    // ─────────────────────────────────────────────────────────────────────
    // Computed lists
    // ─────────────────────────────────────────────────────────────────────
    readonly property var universalResults: {
        const q = filterQuery.trim().toLowerCase();
        if (!q) return [];

        const results = [];

        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            const matches =
                app.name.toLowerCase().includes(q) ||
                (app.comment && app.comment.toLowerCase().includes(q));

            if (matches) {
                results.push({
                    "id": app.id,
                    "type": "app",
                    "badge": "APP",
                    "name": app.name,
                    "desc": app.comment || "Application",
                    "icon": app.icon,
                    "isAppIcon": true,
                    "data": app
                });
            }
        }

        for (let i = 0; i < settingsIndex.length; i++) {
            const s = settingsIndex[i];
            const matches =
                s.name.toLowerCase().includes(q) ||
                s.desc.toLowerCase().includes(q) ||
                s.keywords.some(k => k.includes(q));

            if (matches) {
                results.push({
                    "id": s.id,
                    "type": "setting",
                    "badge": "SETTING",
                    "name": s.name,
                    "desc": s.desc,
                    "icon": s.icon,
                    "isAppIcon": false,
                    "data": s
                });
            }
        }

        for (let i = 0; i < systemActions.length; i++) {
            const a = systemActions[i];
            const matches =
                a.name.toLowerCase().includes(q) ||
                a.desc.toLowerCase().includes(q) ||
                a.keywords.some(k => k.includes(q));

            if (matches) {
                results.push({
                    "id": a.id,
                    "type": "action",
                    "badge": "SYSTEM",
                    "name": a.name,
                    "desc": a.desc,
                    "icon": a.icon,
                    "isAppIcon": false,
                    "data": a
                });
            }
        }

        results.push({
            "id": "store-search",
            "type": "store",
            "badge": "STORE",
            "name": "Search for \"" + filterQuery.trim() + "\" in Delo Store",
            "desc": "Find and install packages, flatpaks, and developer tools",
            "icon": "software-store",
            "isAppIcon": true,
            "data": { "query": filterQuery.trim() }
        });

        return results;
    }

    readonly property var filteredApps: {
        const q = filterQuery.trim().toLowerCase();
        return allApps.filter(app => {
            const matchesQuery =
                !q ||
                app.name.toLowerCase().includes(q) ||
                (app.comment && app.comment.toLowerCase().includes(q));

            if (!matchesQuery) return false;
            if (selectedCategory === "All") return true;
            if (!app.categories) return false;

            return app.categories.some(c =>
                c.toLowerCase().includes(selectedCategory.toLowerCase())
            );
        });
    }

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

    readonly property var recentList: {
        if (selectedCategory !== "All") return [];

        const pinnedSet = new Set(
            ApplicationManager.pinnedAppIds.map(id =>
                id.toLowerCase().replace(/\.desktop$/, "")
            )
        );

        return root.allApps
            .filter(app =>
                !pinnedSet.has(app.id.toLowerCase().replace(/\.desktop$/, ""))
            )
            .slice(0, 12);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────
    function executeItem(item) {
        if (!item) return;

        drawerContextMenu.hide();
        ShellState.closeAppDrawer();

        if (item.type === "app") {
            if (item.data && typeof item.data.execute === "function")
                item.data.execute();
            else if (item.data)
                ApplicationManager.launchApp(item.data);
        } else if (item.type === "setting") {
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

        if (typeof app.execute === "function")
            app.execute();
        else
            ApplicationManager.launchApp(app);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Shell animations
    // ─────────────────────────────────────────────────────────────────────
    Item {
        id: drawerHost
        anchors.fill: parent

        readonly property bool isOpen: ShellState.appDrawerOpen
        opacity: isOpen ? 1.0 : 0.0
        scale: isOpen ? 1.0 : 0.97
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation {
                duration: drawerHost.isOpen ? 200 : 150
                easing.type: drawerHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: drawerHost.isOpen ? 200 : 150
                easing.type: drawerHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }

        // Ambient Drop Shadow matching Notch card depth
        Rectangle {
            anchors.fill: drawerCard
            anchors.topMargin: 8
            anchors.bottomMargin: -8
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: root.radiusCard + 4
            color: Theme.notchShadow
            z: 0
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
                anchors.margins: Theme.spacing.panel
                spacing: Theme.spacing.gutter

                // ─────────────────────────────────────────────────────────
                // Search bar (DeloTextField)
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
                        showSearchIcon: true
                        placeholderText: I18n.tr("search_apps")

                        onTextChanged: {
                            root.filterQuery = text;
                            root.selectedIndex = 0;
                        }

                        textInput.Keys.onEscapePressed: ShellState.closeAppDrawer()

                        textInput.Keys.onDownPressed: {
                            if (root.universalResults.length > 0)
                                root.selectedIndex =
                                    (root.selectedIndex + 1) % root.universalResults.length;
                        }

                        textInput.Keys.onUpPressed: {
                            if (root.universalResults.length > 0)
                                root.selectedIndex =
                                    (root.selectedIndex - 1 + root.universalResults.length) % root.universalResults.length;
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
                    }

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.color: root.colorBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Ctrl + K"
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.typography.scaleCaption.size
                            font.weight: Font.Medium
                            renderType: Theme.renderType
                            color: root.colorTextTertiary
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // Main content
                // ─────────────────────────────────────────────────────────
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.filterQuery.trim() === "" ? 0 : 1

                    // ─────────────────────────────────────────────────────
                    // Normal app drawer
                    // ─────────────────────────────────────────────────────
                    RowLayout {
                        spacing: Theme.spacing.gutter

                        Rectangle {
                            Layout.preferredWidth: 164
                            Layout.fillHeight: true
                            radius: root.radiusPanel
                            color: root.colorSurface
                            border.color: root.colorBorderSoft
                            border.width: 1

                            ListView {
                                id: categoryList
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: Theme.spacing.tiny
                                clip: true

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
                                    id: categoryItem
                                    required property var modelData

                                    readonly property bool isSelected:
                                        root.selectedCategory === categoryItem.modelData.id

                                    width: categoryList.width
                                    height: 36
                                    radius: root.radiusItem
                                    color: categoryMouse.pressed
                                           ? root.colorHoverStrong
                                           : ((categoryMouse.containsMouse || isSelected)
                                              ? root.colorHover
                                              : "transparent")
                                    border.color: "transparent"
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacing.medium
                                        anchors.rightMargin: Theme.spacing.tight
                                        spacing: Theme.spacing.tight

                                        SymbolicIcon {
                                            iconSize: 15
                                            source: categoryItem.modelData.icon
                                            iconColor: (categoryItem.isSelected || categoryMouse.containsMouse)
                                                       ? root.colorText
                                                       : root.colorTextSecondary
                                            Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: categoryItem.modelData.label
                                            font.family: Theme.typography.fontFamily
                                            font.hintingPreference: Theme.hintingPreference
                                            font.pixelSize: Theme.typography.scaleBody.size
                                            font.weight: Font.Medium
                                            renderType: Theme.renderType
                                            color: (categoryItem.isSelected || categoryMouse.containsMouse)
                                                   ? root.colorText
                                                   : root.colorTextSecondary
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                        }
                                    }

                                    MouseArea {
                                        id: categoryMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedCategory = categoryItem.modelData.id
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            color: root.colorBorderSoft
                        }

                        ScrollView {
                            id: appScrollView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                width: appScrollView.availableWidth
                                spacing: Theme.spacing.tight

                                Text {
                                    text: I18n.tr("pinned")
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.typography.scaleTitle.size
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: root.colorText
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 5
                                    rowSpacing: Theme.spacing.small
                                    columnSpacing: Theme.spacing.fine

                                    Repeater {
                                        model: root.pinnedList

                                        delegate: Rectangle {
                                            id: pinnedCell
                                            required property var modelData

                                            Layout.preferredWidth: 98
                                            Layout.preferredHeight: 78
                                            radius: root.radiusItem
                                            color: pinnedMouse.pressed
                                                   ? root.colorHoverStrong
                                                   : (pinnedMouse.containsMouse
                                                      ? root.colorHover
                                                      : root.colorSurface)
                                            border.color: pinnedMouse.pressed
                                                          ? root.colorBorderStrong
                                                          : (pinnedMouse.containsMouse
                                                             ? root.colorBorderHighlight
                                                             : root.colorBorderSoft)
                                            border.width: 1

                                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacing.inset
                                                spacing: Theme.spacing.xsmall

                                                AppIcon {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    iconSize: 36
                                                    source: pinnedCell.modelData.icon
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: pinnedCell.modelData.name
                                                    font.family: Theme.typography.fontFamily
                                                    font.hintingPreference: Theme.hintingPreference
                                                    font.pixelSize: Theme.typography.scaleBody.size
                                                    font.weight: pinnedMouse.containsMouse ? Font.DemiBold : Font.Medium
                                                    renderType: Theme.renderType
                                                    color: pinnedMouse.containsMouse
                                                           ? root.colorText
                                                           : root.colorTextSecondary
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                                }
                                            }

                                            MouseArea {
                                                id: pinnedMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton) {
                                                        var pos = mapToItem(drawerCard, mouse.x, mouse.y);
                                                        drawerContextMenu.show(pinnedCell.modelData, pos.x, pos.y);
                                                    } else {
                                                        root.launchApp(pinnedCell.modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: I18n.tr("more_apps")
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.typography.scaleTitle.size
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: root.colorText
                                    Layout.topMargin: 4
                                    visible: root.recentList.length > 0
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 5
                                    rowSpacing: Theme.spacing.small
                                    columnSpacing: Theme.spacing.fine
                                    visible: root.recentList.length > 0

                                    Repeater {
                                        model: root.recentList

                                        delegate: Rectangle {
                                            id: recentCell
                                            required property var modelData

                                            Layout.preferredWidth: 98
                                            Layout.preferredHeight: 78
                                            radius: root.radiusItem
                                            color: recentMouse.pressed
                                                   ? root.colorHoverStrong
                                                   : (recentMouse.containsMouse
                                                      ? root.colorHover
                                                      : root.colorSurface)
                                            border.color: recentMouse.pressed
                                                          ? root.colorBorderStrong
                                                          : (recentMouse.containsMouse
                                                             ? root.colorBorderHighlight
                                                             : root.colorBorderSoft)
                                            border.width: 1

                                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacing.inset
                                                spacing: Theme.spacing.xsmall

                                                AppIcon {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    iconSize: 36
                                                    source: recentCell.modelData.icon
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: recentCell.modelData.name
                                                    font.family: Theme.typography.fontFamily
                                                    font.hintingPreference: Theme.hintingPreference
                                                    font.pixelSize: Theme.typography.scaleBody.size
                                                    font.weight: recentMouse.containsMouse ? Font.DemiBold : Font.Medium
                                                    renderType: Theme.renderType
                                                    color: recentMouse.containsMouse
                                                           ? root.colorText
                                                           : root.colorTextSecondary
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                                }
                                            }

                                            MouseArea {
                                                id: recentMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton) {
                                                        var pos = mapToItem(drawerCard, mouse.x, mouse.y);
                                                        drawerContextMenu.show(recentCell.modelData, pos.x, pos.y);
                                                    } else {
                                                        root.launchApp(recentCell.modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ─────────────────────────────────────────────────────
                    // Search results
                    // ─────────────────────────────────────────────────────
                    ColumnLayout {
                        spacing: Theme.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacing.xsmall
                            Layout.bottomMargin: Theme.spacing.xsmall

                            Text {
                                text: "Results (" + root.universalResults.length + ")"
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.typography.scaleDisplay.size
                                font.weight: Font.DemiBold
                                renderType: Theme.renderType
                                color: root.colorTextSecondary
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "↑ / ↓ navigate • ↵ select • Esc close"
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.typography.scaleCaption.size
                                font.weight: Font.Normal
                                renderType: Theme.renderType
                                color: root.colorTextTertiary
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: resultsList
                                anchors.fill: parent
                                clip: true
                                spacing: Theme.spacing.xsmall
                                model: root.universalResults
                                currentIndex: root.selectedIndex

                                delegate: Rectangle {
                                    id: resultItem
                                    required property var modelData
                                    required property int index

                                    readonly property bool isSelected:
                                        root.selectedIndex === resultItem.index

                                    width: resultsList.width
                                    height: 52
                                    radius: root.radiusItem
                                    color: resultMouse.pressed
                                           ? root.colorHoverStrong
                                           : (resultMouse.containsMouse
                                              ? root.colorHover
                                              : (isSelected ? root.colorSelected : "transparent"))
                                    border.color: isSelected && !resultMouse.containsMouse
                                                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.16)
                                                  : "transparent"
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacing.medium
                                        anchors.rightMargin: Theme.spacing.medium
                                        spacing: Theme.spacing.medium

                                        Item {
                                            width: 32
                                            height: 32

                                            AppIcon {
                                                anchors.centerIn: parent
                                                visible: resultItem.modelData.type === "app"
                                                iconSize: 30
                                                source: resultItem.modelData.icon
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                visible: resultItem.modelData.type !== "app"
                                                width: 28
                                                height: 28
                                                radius: Theme.radius.tooltip
                                                color: resultItem.modelData.id === "shutdown" ||
                                                       resultItem.modelData.id === "restart"
                                                       ? Qt.rgba(root.colorUrgent.r, root.colorUrgent.g, root.colorUrgent.b, 0.14)
                                                       : root.colorHover

                                                SymbolicIcon {
                                                    anchors.centerIn: parent
                                                    iconSize: 16
                                                    source: resultItem.modelData.icon
                                                    iconColor: resultItem.modelData.id === "shutdown" ||
                                                               resultItem.modelData.id === "restart"
                                                               ? root.colorUrgent
                                                               : (resultItem.isSelected
                                                                  ? root.colorAccent
                                                                  : root.colorTextSecondary)
                                                    Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacing.xsmall

                                            Text {
                                                Layout.fillWidth: true
                                                text: resultItem.modelData.name || resultItem.modelData.title || ""
                                                font.family: Theme.typography.fontFamily
                                                font.hintingPreference: Theme.hintingPreference
                                                font.pixelSize: Theme.typography.scaleBody.size
                                                font.weight: Font.DemiBold
                                                renderType: Theme.renderType
                                                color: resultItem.isSelected
                                                       ? root.colorText
                                                       : root.colorText
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: resultItem.modelData.desc
                                                font.family: Theme.typography.fontFamily
                                                font.hintingPreference: Theme.hintingPreference
                                                font.pixelSize: Theme.typography.scaleCaption.size
                                                font.weight: Font.Normal
                                                renderType: Theme.renderType
                                                color: root.colorTextTertiary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 22
                                            Layout.preferredWidth: badgeLabel.implicitWidth + 14
                                            radius: Theme.radius.small
                                            color: "transparent"
                                            border.color: root.colorBorder
                                            border.width: 1

                                            Text {
                                                id: badgeLabel
                                                anchors.centerIn: parent
                                                text: resultItem.modelData.type === "app"
                                                      ? "App"
                                                      : (resultItem.modelData.type === "setting"
                                                         ? "Settings"
                                                         : (resultItem.modelData.type === "store"
                                                            ? "Store"
                                                            : "System"))
                                                font.family: Theme.typography.fontFamily
                                                font.hintingPreference: Theme.hintingPreference
                                                font.pixelSize: Theme.typography.scaleCaption.size
                                                font.weight: Font.Medium
                                                renderType: Theme.renderType
                                                color: resultItem.modelData.type === "app"
                                                       ? root.colorAccent
                                                       : root.colorTextTertiary
                                            }
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

ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: root.universalResults.length === 0
                                    spacing: Theme.spacing.small

                                SymbolicIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    iconSize: 36
                                    source: "edit-find-symbolic"
                                    iconColor: root.colorTextTertiary
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No matches found for \"" + root.filterQuery + "\""
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.typography.scaleTitle.size
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: root.colorTextSecondary
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Try searching for apps, settings panels, or system actions."
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.typography.scaleCaption.size
                                    font.weight: Font.Normal
                                    renderType: Theme.renderType
                                    color: root.colorTextTertiary
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // Footer
                // ─────────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: root.radiusPanel
                    color: root.colorSurface
                    border.color: root.colorBorderSoft
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.gutter
                        anchors.rightMargin: Theme.spacing.gutter
                        spacing: Theme.spacing.tight

                        Rectangle {
                            width: 30
                            height: 30
                            radius: Theme.radius.pill
                            color: root.colorElevated
                            border.color: root.colorBorder
                            border.width: 1

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 15
                                source: "avatar-default-symbolic"
                                iconColor: root.colorTextSecondary
                            }
                        }

                        ColumnLayout {
                            spacing: Theme.spacing.none

                            Text {
                                text: "DeloOS"
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.typography.scaleDisplay.size
                                font.weight: Font.DemiBold
                                renderType: Theme.renderType
                                color: root.colorText
                            }

                            Text {
                                text: "Your workspace, your rules"
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: Theme.typography.scaleCaption.size
                                font.weight: Font.Normal
                                renderType: Theme.renderType
                                color: root.colorTextTertiary
                            }
                        }

                        Item { Layout.fillWidth: true }

                        component FooterButton: Rectangle {
                            id: footerButton
                            property string iconSource: ""
                            property color normalColor: root.colorTextSecondary
                            property color hoverColor: root.colorText
                            property color hoverBackground: root.colorHover
                            signal activated()

                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            radius: root.radiusItem
                            color: footerMouse.pressed
                                   ? root.colorHoverStrong
                                   : (footerMouse.containsMouse ? hoverBackground : "transparent")
                            border.color: footerMouse.pressed
                                          ? root.colorBorderStrong
                                          : (footerMouse.containsMouse ? root.colorBorder : "transparent")
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 17
                                source: footerButton.iconSource
                                iconColor: footerMouse.containsMouse
                                           ? footerButton.hoverColor
                                           : footerButton.normalColor
                                Behavior on iconColor { ColorAnimation { duration: Theme.motionFast } }
                            }

                            MouseArea {
                                id: footerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: footerButton.activated()
                            }
                        }

                        FooterButton {
                            iconSource: "store-symbolic"
                            hoverColor: root.colorAccent
                            onActivated: {
                                ShellState.closeAppDrawer();
                                ShellState.openAppStore();
                            }
                        }

                        FooterButton {
                            iconSource: "settings-symbolic"
                            onActivated: {
                                ShellState.closeAppDrawer();
                                ShellState.toggleSettingsApp();
                            }
                        }

                        FooterButton {
                            iconSource: "power-symbolic"
                            hoverColor: root.colorUrgent
                            hoverBackground: Qt.rgba(root.colorUrgent.r, root.colorUrgent.g, root.colorUrgent.b, 0.12)
                            onActivated: {
                                ShellState.closeAppDrawer();
                                Hyprland.dispatch("exec systemctl poweroff");
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // Context menu backdrop
            // ─────────────────────────────────────────────────────────────
            MouseArea {
                id: drawerContextMenuBackdrop
                z: 600
                anchors.fill: parent
                visible: drawerContextMenu.isOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: drawerContextMenu.hide()
            }

            // ─────────────────────────────────────────────────────────────
            // Context menu
            // ─────────────────────────────────────────────────────────────
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

                    var targetX = Math.max(12, Math.min(x, drawerCard.width - width - 12));
                    var targetY = Math.max(12, Math.min(y - height, drawerCard.height - height - 12));

                    drawerContextMenu.x = targetX;
                    drawerContextMenu.y = targetY;
                    isOpen = true;
                }

                function hide() {
                    isOpen = false;
                    targetApp = null;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.radiusItem
                    color: root.colorElevated
                    border.color: root.colorBorder
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
                    anchors.margins: Theme.spacing.small
                    spacing: Theme.spacing.xsmall

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacing.fine
                        Layout.rightMargin: Theme.spacing.fine
                        Layout.topMargin: Theme.spacing.inset
                        Layout.bottomMargin: Theme.spacing.xsmall
                        spacing: Theme.spacing.small

                        AppIcon {
                            iconSize: 22
                            source: drawerContextMenu.targetApp
                                    ? drawerContextMenu.targetApp.icon
                                    : ""
                            visible: Boolean(
                                drawerContextMenu.targetApp &&
                                drawerContextMenu.targetApp.icon
                            )
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: drawerContextMenu.targetApp
                                  ? (drawerContextMenu.targetApp.name ||
                                     drawerContextMenu.targetApp.id ||
                                     "")
                                  : ""
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.typography.scaleMenuTitle.size
                            font.weight: Font.DemiBold
                            color: root.colorText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Rectangle {
                            visible: {
                                if (!drawerContextMenu.targetApp) return false;
                                return ApplicationManager.getWindowsForApp(
                                    drawerContextMenu.targetApp.id
                                ).length > 0;
                            }
                            width: 7
                            height: 7
                            radius: Theme.radius.pill
                            color: root.colorAccent
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        color: root.colorBorderSoft
                    }

                    component MenuRow: Rectangle {
                        id: menuRow
                        property string iconSource: ""
                        property string label: ""
                        property color normalIconColor: root.colorTextSecondary
                        property color hoverIconColor: root.colorAccent
                        property color normalTextColor: root.colorText
                        property color hoverTextColor: root.colorText
                        property color hoverBackground: root.colorHover
                        signal activated()

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: root.radiusItem
                        color: menuMouse.pressed
                               ? root.colorHoverStrong
                               : (menuMouse.containsMouse ? hoverBackground : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing.tight
                            anchors.rightMargin: Theme.spacing.tight
                            spacing: Theme.spacing.tight

                            SymbolicIcon {
                                source: menuRow.iconSource
                                iconSize: 15
                                iconColor: menuMouse.containsMouse
                                           ? menuRow.hoverIconColor
                                           : menuRow.normalIconColor
                                Behavior on iconColor { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: menuRow.label
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.typography.scaleBody.size
                                font.weight: menuMouse.containsMouse ? Font.DemiBold : Font.Normal
                                color: menuMouse.containsMouse
                                       ? menuRow.hoverTextColor
                                       : menuRow.normalTextColor
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
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
                            return ApplicationManager.getWindowsForApp(
                                drawerContextMenu.targetApp.id
                            ).length > 0;
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

                    Item { Layout.preferredHeight: 2 }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Shell state sync
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