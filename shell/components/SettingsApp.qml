import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"
import "../services"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "deloway:settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.settingsAppOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Keyboard shortcuts
    Shortcut {
        sequence: "Escape"
        enabled: ShellState.settingsAppOpen
        onActivated: {
            if (root.isFullScreen) {
                root.isFullScreen = false;
            } else {
                ShellState.closeSettingsApp();
            }
        }
    }

    Shortcut {
        sequence: "Super+Q"
        enabled: ShellState.settingsAppOpen
        onActivated: ShellState.closeSettingsApp()
    }

    Shortcut {
        sequence: "Meta+Q"
        enabled: ShellState.settingsAppOpen
        onActivated: ShellState.closeSettingsApp()
    }

    Shortcut {
        sequence: "Super+F"
        enabled: ShellState.settingsAppOpen
        onActivated: root.isFullScreen = !root.isFullScreen
    }

    Shortcut {
        sequence: "Meta+F"
        enabled: ShellState.settingsAppOpen
        onActivated: root.isFullScreen = !root.isFullScreen
    }

    Shortcut {
        sequence: "F11"
        enabled: ShellState.settingsAppOpen
        onActivated: root.isFullScreen = !root.isFullScreen
    }

    visible: ShellState.settingsAppOpen || mainBg.opacity > 0.01

    property string activeTab: ShellState.activeSettingsTab || "appearance"
    property bool isFullScreen: ShellState.settingsFullScreen
    onIsFullScreenChanged: ShellState.settingsFullScreen = isFullScreen

    Connections {
        target: ShellState
        function onSettingsAppOpenChanged() {
            if (ShellState.settingsAppOpen && ShellState.activeSettingsTab)
                root.activeTab = ShellState.activeSettingsTab
        }
        function onActiveSettingsTabChanged() { root.activeTab = ShellState.activeSettingsTab }
    }

    // ── Unified palette harmonized with Theme ─────────────────────────────────
    readonly property bool isDark: Theme.mode !== "light"
    readonly property color sz950: isDark ? Theme.colors.background : Theme.colors.background       // Background
    readonly property color sz900: isDark ? Theme.colors.surface : Theme.colors.surface             // Card / Surface
    readonly property color sz800: isDark ? Theme.colors.surfaceElevated : Theme.colors.surfaceActive // Active Tab / Subsurface
    readonly property color sz700: isDark ? Theme.colors.border : Theme.colors.border               // Border subtle
    readonly property color sz600: isDark ? Theme.colors.textTertiary : Theme.colors.textTertiary   // Muted Icons
    readonly property color sz500: isDark ? Theme.colors.textTertiary : Theme.colors.textTertiary   // Placeholder
    readonly property color sz400: isDark ? Theme.colors.textSecondary : Theme.colors.textSecondary // Muted text
    readonly property color sz300: isDark ? Theme.colors.text : Theme.colors.text                   // Normal text
    readonly property color sz200: isDark ? Theme.colors.text : Theme.colors.text                   // Secondary text
    readonly property color sz100: isDark ? Theme.colors.text : Theme.colors.text                   // Bright text
    readonly property color sz50:  isDark ? Theme.colors.text : Theme.colors.text                   // Primary text
    readonly property color green: Theme.colors.success                                              // Success badge

    // ── Transparent Backdrop for click-outside dismissal (No dim/blur) ───────
    MouseArea {
        id: backdrop
        anchors.fill: parent
        enabled: ShellState.settingsAppOpen && !root.isFullScreen
        onClicked: ShellState.closeSettingsApp()
    }

    // ── Outer Hairline Halo (Subtle window boundary depth) ───────────────────
    Rectangle {
        id: windowHalo
        z: 0
        x: mainBg.x - 1
        y: mainBg.y - 1
        width: mainBg.width + 2
        height: mainBg.height + 2
        radius: mainBg.radius + 1
        color: "transparent"
        border.color: Qt.rgba(0, 0, 0, 0.50)
        border.width: 1
        visible: !root.isFullScreen && mainBg.opacity > 0.05
        Behavior on x { NumberAnimation { duration: root.isFullScreen ? Theme.motionBase : 0; easing.type: Theme.easingEnter } }
        Behavior on y { NumberAnimation { duration: root.isFullScreen ? Theme.motionBase : 0; easing.type: Theme.easingEnter } }
        Behavior on width { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on radius { NumberAnimation { duration: Theme.motionFast } }
    }

    // ── Main Settings Window Card (Standard Desktop Window) ──────────────────
    Rectangle {
        id: mainBg
        z: 1

        readonly property real targetW: root.isFullScreen ? root.width : Math.min(1080, root.width - 48)
        readonly property real targetH: root.isFullScreen ? root.height : Math.min(720, root.height - 64)
        property real winX: Math.round((root.width - targetW) / 2)
        property real winY: Math.round((root.height - targetH) / 2)

        x: root.isFullScreen ? 0 : winX
        y: root.isFullScreen ? 0 : winY
        width: targetW
        height: targetH
        radius: root.isFullScreen ? 0 : Theme.radiusLarge
        color: root.sz950
        border.color: root.isFullScreen ? "transparent" : Qt.rgba(255, 255, 255, 0.09)
        border.width: root.isFullScreen ? 0 : 1
        clip: true

        Behavior on x { NumberAnimation { duration: root.isFullScreen ? Theme.motionBase : 0; easing.type: Theme.easingEnter } }
        Behavior on y { NumberAnimation { duration: root.isFullScreen ? Theme.motionBase : 0; easing.type: Theme.easingEnter } }
        Behavior on width { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on radius { NumberAnimation { duration: Theme.motionFast } }

        // Block backdrop click inside window
        MouseArea {
            anchors.fill: parent
        }

        opacity: ShellState.settingsAppOpen ? 1.0 : 0.0
        transform: Scale {
            origin.x: mainBg.width / 2
            origin.y: mainBg.height / 2
            xScale: ShellState.settingsAppOpen ? 1.0 : 0.96
            yScale: ShellState.settingsAppOpen ? 1.0 : 0.96
            Behavior on xScale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            Behavior on yScale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        // ── TOP CHROME (macOS-style: traffic lights + centered title) ──────────
        Rectangle {
            id: topChrome
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 48
            color: root.sz950
            z: 2

            // Draggable Window Handler
            MouseArea {
                id: dragArea
                anchors.fill: parent
                z: -1
                property real startX: 0
                property real startY: 0
                cursorShape: root.isFullScreen ? Qt.ArrowCursor : Qt.OpenHandCursor

                onPressed: (mouse) => {
                    if (root.isFullScreen) return;
                    cursorShape = Qt.ClosedHandCursor;
                    startX = mouse.x;
                    startY = mouse.y;
                }
                onPositionChanged: (mouse) => {
                    if (pressed && !root.isFullScreen) {
                        var dx = mouse.x - startX;
                        var dy = mouse.y - startY;
                        var maxX = Math.max(0, root.width - mainBg.width);
                        var maxY = Math.max(0, root.height - mainBg.height);
                        mainBg.winX = Math.max(0, Math.min(maxX, mainBg.winX + dx));
                        mainBg.winY = Math.max(0, Math.min(maxY, mainBg.winY + dy));
                    }
                }
                onReleased: {
                    cursorShape = root.isFullScreen ? Qt.ArrowCursor : Qt.OpenHandCursor;
                }
                onCanceled: {
                    cursorShape = root.isFullScreen ? Qt.ArrowCursor : Qt.OpenHandCursor;
                }
                onDoubleClicked: root.isFullScreen = !root.isFullScreen
            }

            // Bottom hairline separator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(255, 255, 255, 0.06)
            }

            // ── macOS Traffic Light buttons (left) + centered title ──
            RowLayout {
                id: trafficLights
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                spacing: 8

                // Red — Close
                Rectangle {
                    width: 13; height: 13; radius: 6.5
                    color: trafficCloseMa.containsMouse ? "#ff5f57" : Qt.rgba(1.0, 0.37, 0.34, 0.88)
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Text {
                        anchors.centerIn: parent; text: "×"
                        font.pixelSize: 8; font.weight: Font.Bold; color: "#7a0000"
                        visible: trafficCloseMa.containsMouse
                    }
                    MouseArea {
                        id: trafficCloseMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeSettingsApp()
                    }
                }

                // Yellow — Minimize
                Rectangle {
                    width: 13; height: 13; radius: 6.5
                    color: trafficMinMa.containsMouse ? "#febc2e" : Qt.rgba(1.0, 0.74, 0.18, 0.88)
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Text {
                        anchors.centerIn: parent; text: "−"
                        font.pixelSize: 9; font.weight: Font.Bold; color: "#5a3800"
                        visible: trafficMinMa.containsMouse
                    }
                    MouseArea {
                        id: trafficMinMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { }
                    }
                }

                // Green — Maximize
                Rectangle {
                    width: 13; height: 13; radius: 6.5
                    color: trafficMaxMa.containsMouse ? "#28c840" : Qt.rgba(0.16, 0.78, 0.25, 0.88)
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Text {
                        anchors.centerIn: parent
                        text: root.isFullScreen ? "↙" : "↗"
                        font.pixelSize: 7; font.weight: Font.Bold; color: "#003a00"
                        visible: trafficMaxMa.containsMouse
                    }
                    MouseArea {
                        id: trafficMaxMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isFullScreen = !root.isFullScreen
                    }
                }

                // Divider
                Rectangle { width: 1; height: 16; color: Qt.rgba(255, 255, 255, 0.12) }

                // Back arrow
                Text {
                    text: "‹"; font.pixelSize: 20; font.weight: Font.Light
                    color: Qt.rgba(255, 255, 255, 0.35)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }

                // Forward arrow
                Text {
                    text: "›"; font.pixelSize: 20; font.weight: Font.Light
                    color: Qt.rgba(255, 255, 255, 0.35)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }
            }

            // Centered page title
            Text {
                anchors.centerIn: parent
                text: I18n.tr("tab_" + root.activeTab)
                font.family: Theme.typography.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }
        }

        // ── BODY: SIDEBAR + CONTENT ──────────────────────────────────────
        RowLayout {
            anchors.top: topChrome.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
            spacing: 0

            // ── SIDEBAR ──────────────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 236
                Layout.fillHeight: true
                color: Theme.colors.backgroundAlt

                Rectangle {
                    anchors.right: I18n.isRTL ? undefined : parent.right
                    anchors.left: I18n.isRTL ? parent.left : undefined
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Qt.rgba(255, 255, 255, 0.06)
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.topMargin: 16
                    anchors.bottomMargin: 16
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: 230
                        spacing: 1

                        // SYSTEM
                        Text {
                            text: I18n.isRTL ? "النظام" : "SYSTEM"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.sz600
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4
                            font.letterSpacing: 0.8
                        }
                        Repeater {
                            model: [
                                { id: "appearance", icon: "applications-graphics-symbolic",       iconBg: "#8b5cf6" },
                                { id: "language",   icon: "preferences-desktop-locale-symbolic",   iconBg: "#3b82f6" },
                                { id: "desktop",    icon: "user-home-symbolic",                   iconBg: "#0ea5e9" },
                                { id: "dock",       icon: "view-app-grid-symbolic",               iconBg: "#6366f1" },
                                { id: "topbar",     icon: "preferences-system-symbolic",          iconBg: "#64748b" },
                                { id: "windows",    icon: "view-fullscreen-symbolic",             iconBg: "#475569" }
                            ]
                            delegate: ShadcnNavItem {
                                tabId: modelData.id
                                label: I18n.tr("tab_" + modelData.id)
                                iconSource: modelData.icon
                                iconBgColor: modelData.iconBg || Theme.colors.accent
                                isActive: root.activeTab === modelData.id
                                onActivated: root.activeTab = modelData.id
                            }
                        }

                        Item { Layout.preferredHeight: 16 }

                        // CONNECTIVITY
                        Text {
                            text: I18n.isRTL ? "الاتصالات" : "CONNECTIVITY"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.sz600
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4
                            font.letterSpacing: 0.8
                        }
                        Repeater {
                            model: [
                                { id: "network",   icon: "network-wireless-symbolic",       iconBg: "#3b82f6" },
                                { id: "bluetooth", icon: "bluetooth-active-symbolic",        iconBg: "#3b82f6" },
                                { id: "power",     icon: "power-profile-balanced-symbolic",  iconBg: "#10b981" }
                            ]
                            delegate: ShadcnNavItem {
                                tabId: modelData.id
                                label: I18n.tr("tab_" + modelData.id)
                                iconSource: modelData.icon
                                iconBgColor: modelData.iconBg || Theme.colors.accent
                                isActive: root.activeTab === modelData.id
                                onActivated: root.activeTab = modelData.id
                            }
                        }

                        Item { Layout.preferredHeight: 16 }

                        // PREFERENCES
                        Text {
                            text: I18n.isRTL ? "التفضيلات" : "PREFERENCES"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.sz600
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4
                            font.letterSpacing: 0.8
                        }
                        Repeater {
                            model: [
                                { id: "notifications", icon: "preferences-system-notifications-symbolic",       iconBg: "#f59e0b" },
                                { id: "shortcuts",     icon: "preferences-desktop-keyboard-shortcuts-symbolic", iconBg: "#64748b" },
                                { id: "applications",  icon: "applications-other-symbolic",                    iconBg: "#8b5cf6" }
                            ]
                            delegate: ShadcnNavItem {
                                tabId: modelData.id
                                label: I18n.tr("tab_" + modelData.id)
                                iconSource: modelData.icon
                                iconBgColor: modelData.iconBg || Theme.colors.accent
                                isActive: root.activeTab === modelData.id
                                onActivated: root.activeTab = modelData.id
                            }
                        }

                        Item { Layout.preferredHeight: 16 }

                        // ABOUT
                        Text {
                            text: I18n.isRTL ? "حول" : "ABOUT"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.sz600
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4
                            font.letterSpacing: 0.8
                        }
                        ShadcnNavItem {
                            tabId: "about"
                            label: I18n.tr("tab_about")
                            iconSource: "dialog-information-symbolic"
                            iconBgColor: "#0ea5e9"
                            isActive: root.activeTab === "about"
                            onActivated: root.activeTab = "about"
                        }
                    }
                }
            }

            // ── CONTENT VIEW ─────────────────────────────────────────────
            ScrollView {
                id: mainScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: mainScroll.width
                    spacing: 0

                    // Page Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 68
                        color: "transparent"

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 28
                            anchors.rightMargin: 28
                            spacing: 3

                            Text {
                                text: I18n.tr("tab_" + root.activeTab)
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: root.sz50
                                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                                Layout.fillWidth: true
                            }
                            Text {
                                text: I18n.tr(root.activeTab + "_desc")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 12
                                color: root.sz400
                                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 28
                            anchors.rightMargin: 28
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.06)
                        }
                    }

                    // Content Panels Container
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 28
                        Layout.rightMargin: 28
                        Layout.topMargin: 20
                        Layout.bottomMargin: 32
                        spacing: 10

                        // ════════════════════════════════════════════════
                        // 1. APPEARANCE
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "appearance"

                            id: appearanceTabCol
                            property var wallpapersList: [
                                { name: "DeloWay Default", path: ConfigManager.projectDir + "/assets/wallpaper.jpg", category: "Deloway Presets" },
                                { name: "DeloWay Artwork", path: ConfigManager.projectDir + "/assets/album_art.jpg", category: "Deloway Presets" }
                            ]

                            Component.onCompleted: {
                                wallpapersScanProc.running = true;
                            }

                            onVisibleChanged: {
                                if (visible) wallpapersScanProc.running = true;
                            }

                            Process {
                                id: wallpapersScanProc
                                command: ["python3", ConfigManager.projectDir + "/scripts/deloway-wallpapers-list.py"]
                                stdout: SplitParser {
                                    onRead: data => {
                                        try {
                                            var arr = JSON.parse(data.trim());
                                            if (Array.isArray(arr) && arr.length > 0) {
                                                appearanceTabCol.wallpapersList = arr;
                                            }
                                        } catch(e) {}
                                    }
                                }
                            }

                            Process {
                                id: wallpaperBrowseProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-wallpaper.py", "--browse"]
                                onExited: wallpapersScanProc.running = true
                            }

                            Process {
                                id: openPicturesProc
                                command: ["xdg-open", ConfigManager.homeDir + "/Pictures"]
                            }

                            // Theme Mode
                            ShadcnSection {
                                sectionTitle: I18n.tr("theme_mode")
                                sectionDesc: I18n.tr("theme_mode_desc")

                                Row {
                                    spacing: 10
                                    layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
                                    Repeater {
                                        model: [
                                            { id: "dark",  label: I18n.tr("dark_mode"),  sub: I18n.isRTL ? "أسطح زنك داكنة" : "Zinc dark surfaces" },
                                            { id: "light", label: I18n.tr("light_mode"), sub: I18n.isRTL ? "أسطح بيضاء نقية" : "Clean light surfaces" }
                                        ]
                                        delegate: Rectangle {
                                            id: tmC
                                            required property var modelData
                                            readonly property bool isSel: ConfigManager.themeMode === modelData.id
                                            width: 154
                                            height: 58
                                            radius: 10
                                            color: isSel ? Qt.alpha(Theme.colors.accent, 0.15) : (tmMa.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Theme.colors.surfaceElevated)
                                            border.color: isSel ? Theme.colors.accent : (tmMa.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06))
                                            border.width: isSel ? 1.5 : 1
                                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 2
                                                Text {
                                                    text: modelData.label
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    color: tmC.isSel ? root.sz50 : root.sz400
                                                }
                                                Text {
                                                    text: modelData.sub
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 11
                                                    color: root.sz400
                                                }
                                            }

                                            MouseArea {
                                                id: tmMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ConfigManager.setThemeMode(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            // Performance Tier (NewPlan.md §3)
                            ShadcnSection {
                                sectionTitle: I18n.isRTL ? "مستوى الأداء والمؤثرات" : "Performance & Visual Tier"
                                sectionDesc: I18n.isRTL ? "التحكم في مؤثرات الزجاجية (Blur)، تعقيد الحركات، والظلال" : "Control blur effects, motion complexity, and elevation shadows"

                                Row {
                                    spacing: 10
                                    layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
                                    Repeater {
                                        model: [
                                            { id: 2, label: I18n.isRTL ? "أداء فائق (High)" : "High", sub: I18n.isRTL ? "زجاجية كاملة وحركات غنية" : "Full acrylic blur & rich motion" },
                                            { id: 1, label: I18n.isRTL ? "متوازن (Balanced)" : "Balanced", sub: I18n.isRTL ? "جودة عالية وثبات سلس" : "Standard blur & balanced motion" },
                                            { id: 0, label: I18n.isRTL ? "اقتصادي (Efficient)" : "Efficient", sub: I18n.isRTL ? "بدون زجاجية، استقرار مطلق" : "Solid surfaces & minimal motion" }
                                        ]
                                        delegate: Rectangle {
                                            id: ptC
                                            required property var modelData
                                            readonly property bool isSel: ConfigManager.performanceTier === modelData.id
                                            width: 174
                                            height: 64
                                            radius: 10
                                            color: isSel ? Qt.alpha(Theme.colors.accent, 0.15) : (ptMa.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Theme.colors.surfaceElevated)
                                            border.color: isSel ? Theme.colors.accent : (ptMa.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06))
                                            border.width: isSel ? 1.5 : 1
                                            Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 2
                                                Text {
                                                    text: modelData.label
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    color: ptC.isSel ? root.sz50 : root.sz400
                                                }
                                                Text {
                                                    text: modelData.sub
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 10
                                                    color: root.sz400
                                                    wrapMode: Text.WordWrap
                                                    width: parent.width
                                                }
                                            }

                                            MouseArea {
                                                id: ptMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ConfigManager.setPerformanceTier(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            // Desktop Wallpaper Section
                            ShadcnSection {
                                sectionTitle: I18n.tr("wallpaper_title")
                                sectionDesc: I18n.tr("wallpaper_desc")

                                Column {
                                    width: parent.width
                                    spacing: 14

                                    Flow {
                                        width: parent.width
                                        spacing: 12

                                        Repeater {
                                            model: appearanceTabCol.wallpapersList || [
                                                { name: "DeloWay Default", path: ConfigManager.projectDir + "/assets/wallpaper.jpg" },
                                                { name: "DeloWay Artwork", path: ConfigManager.projectDir + "/assets/album_art.jpg" }
                                            ]
                                            delegate: Rectangle {
                                                id: wpCard
                                                required property var modelData
                                                readonly property bool isSel: ConfigManager.wallpaper === modelData.path
                                                width: 184
                                                height: 110
                                                radius: 10
                                                color: Theme.colors.surfaceElevated
                                                border.color: isSel ? Theme.colors.accent : (wpMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.07))
                                                border.width: isSel ? 2 : 1
                                                clip: true

                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: wpCard.isSel ? 2 : 0
                                                    source: "file://" + modelData.path
                                                    fillMode: Image.PreserveAspectCrop
                                                    opacity: wpCard.isSel ? 1.0 : (wpMouse.containsMouse ? 0.9 : 0.7)
                                                    cache: true
                                                }

                                                // Active Check Badge
                                                Rectangle {
                                                    visible: wpCard.isSel
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: 6
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: root.sz50

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✓"
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: root.sz950
                                                    }
                                                }

                                                // Bottom Label with dark gradient backing
                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 28
                                                    color: Qt.alpha(root.sz950, 0.88)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.name
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Medium
                                                        color: wpCard.isSel ? root.sz50 : root.sz300
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                    }
                                                }

                                                MouseArea {
                                                    id: wpMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: ConfigManager.setWallpaper(modelData.path)
                                                }
                                            }
                                        }
                                    }

                                    // Action Toolbar & Current Path
                                    Rectangle {
                                        width: parent.width
                                        height: 48
                                        radius: 6
                                        color: root.sz900
                                        border.color: root.sz800
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            SymbolicIcon {
                                                iconSize: 16
                                                source: "image-x-generic-symbolic"
                                                iconColor: root.sz400
                                            }

                                            Text {
                                                text: (I18n.isRTL ? "الخلفية الحالية: " : "Current: ") + (ConfigManager.wallpaper.split("/").pop() || "wallpaper.jpg")
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 12
                                                color: root.sz300
                                                Layout.fillWidth: true
                                                elide: Text.ElideMiddle
                                            }

                                            ShadcnButton {
                                                btnText: I18n.tr("refresh")
                                                onClicked: wallpapersScanProc.running = true
                                            }

                                            ShadcnButton {
                                                btnText: I18n.tr("open_pictures_folder")
                                                onClicked: openPicturesProc.running = true
                                            }

                                            ShadcnButton {
                                                btnText: I18n.tr("browse_wallpaper")
                                                onClicked: wallpaperBrowseProc.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Windows-style Font Size Scaling (90%, 100%, 110%, 120%, 125%)
                            ShadcnSection {
                                sectionTitle: I18n.tr("display_scaling")
                                sectionDesc: I18n.tr("display_scaling_desc")
                                badgeText: Math.round(ConfigManager.fontSizeScale * 100) + "%"

                                ShadcnSegmented {
                                    model: [
                                        { val: 0.90, label: "90%" },
                                        { val: 1.00, label: "100% (" + I18n.tr("default") + ")" },
                                        { val: 1.10, label: "110%" },
                                        { val: 1.20, label: "120%" },
                                        { val: 1.25, label: "125%" }
                                    ]
                                    selectedVal: ConfigManager.fontSizeScale
                                    onSelect: v => ConfigManager.setFontSizeScale(v)
                                }
                            }

                            // Corner Radius
                            ShadcnSection {
                                sectionTitle: I18n.tr("corner_radius")
                                sectionDesc: I18n.tr("corner_radius_desc")
                                badgeText: ConfigManager.elementRadius + "px"

                                ShadcnSegmented {
                                    model: [
                                        { val: 4,  label: "Sharp (4px)" },
                                        { val: 8,  label: "Standard (8px)" },
                                        { val: 12, label: "Rounded (12px)" }
                                    ]
                                    selectedVal: ConfigManager.elementRadius
                                    onSelect: v => ConfigManager.setElementRadius(v)
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 2. LANGUAGE & KEYBOARD
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            id: langPanel
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "language"

                            property string activeKeymap: "English (US)"
                            property string activeCode: "EN"
                            property var installedLayouts: [
                                { id: "us", name: "English (US)", native: "English (US)", code: "EN" },
                                { id: "ara", name: "Arabic", native: "العربية", code: "AR" }
                            ]
                            property var availableLayouts: []
                            property bool showAddPicker: false

                            onVisibleChanged: {
                                if (visible) kbProc.running = true
                            }

                            Process {
                                id: kbProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-keyboard.py", "status"]
                                stdout: SplitParser {
                                    onRead: data => {
                                        try {
                                            var obj = JSON.parse(data.trim());
                                            if (obj.active) langPanel.activeKeymap = obj.active;
                                            if (obj.code) langPanel.activeCode = obj.code;
                                            if (obj.installed && obj.installed.length > 0) langPanel.installedLayouts = obj.installed;
                                            if (obj.available) langPanel.availableLayouts = obj.available;
                                        } catch (e) {}
                                    }
                                }
                            }

                            Process {
                                id: kbSwitchProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-keyboard.py", "switch"]
                                onExited: kbProc.running = true
                            }

                            Process {
                                id: kbActionProc
                                onExited: kbProc.running = true
                            }

                            // SECTION 1: UI Display Language (لغة واجهة النظام)
                            ShadcnSection {
                                sectionTitle: I18n.tr("ui_language_title")
                                sectionDesc: I18n.tr("ui_language_desc")
                                badgeText: ConfigManager.uiLanguage.toUpperCase()

                                RowLayout {
                                    width: parent.width
                                    spacing: 12

                                    // English Option Card
                                    Rectangle {
                                        id: optEnCard
                                        readonly property bool isSel: ConfigManager.uiLanguage === "en"
                                        Layout.fillWidth: true
                                        height: 64
                                        radius: 10
                                        color: isSel ? Qt.alpha(Theme.colors.accent, 0.15) : (enMa.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Theme.colors.surfaceElevated)
                                        border.color: isSel ? Theme.colors.accent : (enMa.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06))
                                        border.width: isSel ? 1.5 : 1
                                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 12

                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 6
                                                color: root.sz950
                                                border.color: root.sz700
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "EN"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: root.sz50
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: "English (United States)"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    color: root.sz50
                                                }
                                                Text {
                                                    text: "Default desktop interface (LTR)"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 11
                                                    color: root.sz400
                                                }
                                            }

                                            Rectangle {
                                                visible: optEnCard.isSel
                                                width: 20
                                                height: 20
                                                radius: 10
                                                color: Theme.colors.accent
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✓"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: Theme.textOnAccent
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: enMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: I18n.setLanguage("en")
                                        }
                                    }

                                    // Arabic Option Card
                                    Rectangle {
                                        id: optArCard
                                        readonly property bool isSel: ConfigManager.uiLanguage === "ar"
                                        Layout.fillWidth: true
                                        height: 64
                                        radius: 10
                                        color: isSel ? Qt.alpha(Theme.colors.accent, 0.15) : (arMa.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Theme.colors.surfaceElevated)
                                        border.color: isSel ? Theme.colors.accent : (arMa.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06))
                                        border.width: isSel ? 1.5 : 1
                                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 12

                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 6
                                                color: root.sz950
                                                border.color: root.sz700
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "ع"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 15
                                                    font.weight: Font.Bold
                                                    color: root.sz50
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: "العربية (المملكة العربية السعودية)"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    color: root.sz50
                                                }
                                                Text {
                                                    text: "واجهة سطح مكتب عربية متكاملة (RTL)"
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 11
                                                    color: root.sz400
                                                }
                                            }

                                            Rectangle {
                                                visible: optArCard.isSel
                                                width: 20
                                                height: 20
                                                radius: 10
                                                color: Theme.colors.accent
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✓"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: Theme.textOnAccent
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: arMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: I18n.setLanguage("ar")
                                        }
                                    }
                                }
                            }

                            // SECTION 2: Active Keyboard Input Language
                            ShadcnSection {
                                sectionTitle: I18n.tr("active_layout")
                                sectionDesc: I18n.tr("switch_shortcut_desc")
                                badgeText: langPanel.activeCode

                                RowLayout {
                                    width: parent.width
                                    spacing: 16

                                    Rectangle {
                                        width: 48
                                        height: 48
                                        radius: 6
                                        color: root.sz800
                                        border.color: root.sz700
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: langPanel.activeCode
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            color: root.sz50
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: langPanel.activeKeymap
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            color: root.sz50
                                        }
                                        Text {
                                            text: (I18n.isRTL ? "الاختصار السريع: " : "Hotkey: ") + "Shift + Alt"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                    }

                                    ShadcnButton {
                                        btnText: I18n.isRTL ? "تبديل اللغة الآن" : "Switch Layout"
                                        onClicked: kbSwitchProc.running = true
                                    }
                                }
                            }

                            // SECTION 3: Installed Keyboards & Add Language
                            ShadcnSection {
                                sectionTitle: I18n.tr("installed_layouts")
                                sectionDesc: I18n.tr("keyboard_layouts_desc")
                                badgeText: langPanel.installedLayouts.length + " " + (I18n.isRTL ? "لغات" : "Layouts")

                                Column {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: langPanel.installedLayouts
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: parent.width
                                            height: 46
                                            radius: 6
                                            color: root.sz900
                                            border.color: root.sz800
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 12

                                                Rectangle {
                                                    width: 32
                                                    height: 26
                                                    radius: 4
                                                    color: root.sz800
                                                    border.color: root.sz700
                                                    border.width: 1
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.code || modelData.id.toUpperCase()
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.Bold
                                                        color: root.sz50
                                                    }
                                                }

                                                Text {
                                                    text: modelData.name + (modelData.native && modelData.native !== modelData.name ? " (" + modelData.native + ")" : "")
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: (modelData.name.toLowerCase() === langPanel.activeKeymap.toLowerCase() || (modelData.code && modelData.code === langPanel.activeCode)) ? Font.DemiBold : Font.Normal
                                                    color: root.sz50
                                                    Layout.fillWidth: true
                                                }

                                                Rectangle {
                                                    visible: (modelData.name.toLowerCase() === langPanel.activeKeymap.toLowerCase() || (modelData.code && modelData.code === langPanel.activeCode))
                                                    implicitWidth: actBadgeTxt.implicitWidth + 12
                                                    height: 22
                                                    radius: 4
                                                    color: root.sz800
                                                    border.color: root.sz700
                                                    border.width: 1
                                                    Text {
                                                        id: actBadgeTxt
                                                        anchors.centerIn: parent
                                                        text: I18n.tr("active")
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 10
                                                        color: root.sz50
                                                    }
                                                }

                                                // Remove button (only if >1 layouts installed)
                                                ShadcnButton {
                                                    visible: langPanel.installedLayouts.length > 1
                                                    btnText: I18n.tr("remove")
                                                    onClicked: {
                                                        kbActionProc.exec([ConfigManager.projectDir + "/scripts/deloway-keyboard.py", "remove", modelData.id]);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Add Language Controls
                                    RowLayout {
                                        width: parent.width
                                        spacing: 8

                                        ShadcnButton {
                                            btnText: "+ " + I18n.tr("add_language")
                                            onClicked: langPanel.showAddPicker = !langPanel.showAddPicker
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    // Add Language Options Panel
                                    Rectangle {
                                        visible: langPanel.showAddPicker && langPanel.availableLayouts.length > 0
                                        width: parent.width
                                        implicitHeight: addCol.implicitHeight + 16
                                        radius: 6
                                        color: root.sz950
                                        border.color: root.sz700
                                        border.width: 1

                                        ColumnLayout {
                                            id: addCol
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            Text {
                                                text: I18n.isRTL ? "اختر لغة لإضافتها إلى لوحة المفاتيح:" : "Select language to add to your keyboard:"
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 12
                                                color: root.sz400
                                            }

                                            Repeater {
                                                model: langPanel.availableLayouts
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    height: 36
                                                    radius: 4
                                                    color: addMa.containsMouse ? root.sz800 : "transparent"

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: 10

                                                        Text {
                                                            text: modelData.name + " (" + modelData.native + ")"
                                                            font.family: Theme.typography.fontFamily
                                                            font.pixelSize: 12
                                                            color: root.sz50
                                                            Layout.fillWidth: true
                                                        }

                                                        ShadcnButton {
                                                            btnText: I18n.tr("add")
                                                            onClicked: {
                                                                langPanel.showAddPicker = false;
                                                                kbActionProc.exec([ConfigManager.projectDir + "/scripts/deloway-keyboard.py", "add", modelData.id]);
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: addMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // SECTION 4: Switching Shortcut (Windows Standard Shift + Alt)
                            ShadcnSection {
                                sectionTitle: I18n.tr("switch_shortcut")
                                sectionDesc: I18n.tr("switch_shortcut_desc")
                                badgeText: I18n.tr("windows_default")

                                RowLayout {
                                    width: parent.width
                                    spacing: 16

                                    // Windows standard keycap display
                                    Row {
                                        spacing: 6
                                        Rectangle {
                                            width: 60
                                            height: 32
                                            radius: 5
                                            color: root.sz800
                                            border.color: root.sz700
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Shift"
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: root.sz50
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "+"
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: root.sz400
                                        }
                                        Rectangle {
                                            width: 50
                                            height: 32
                                            radius: 5
                                            color: root.sz800
                                            border.color: root.sz700
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Alt"
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: root.sz50
                                            }
                                        }
                                    }

                                    Text {
                                        text: I18n.isRTL ? "معتمد تلقائياً في النظام (Shift + Alt أو Alt + Shift)" : "Enabled by default system-wide (Shift + Alt or Alt + Shift)"
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        color: root.sz400
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 3. DOCK
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "dock"

                            // Position
                            ShadcnSection {
                                sectionTitle: I18n.tr("dock_position")
                                sectionDesc: I18n.tr("dock_position_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: "bottom", label: I18n.tr("bottom") },
                                        { val: "left",   label: I18n.tr("left") },
                                        { val: "right",  label: I18n.tr("right") }
                                    ]
                                    selectedVal: ConfigManager.dockPosition
                                    onSelect: v => ConfigManager.setDockPosition(v)
                                }
                            }

                            // Icon Size
                            ShadcnSection {
                                sectionTitle: I18n.tr("dock_icon_size")
                                sectionDesc: I18n.tr("dock_icon_size_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: 32, label: "32px" },
                                        { val: 38, label: "38px" },
                                        { val: 44, label: "44px" },
                                        { val: 48, label: "48px" },
                                        { val: 56, label: "56px" }
                                    ]
                                    selectedVal: ConfigManager.dockIconSize
                                    onSelect: v => ConfigManager.setDockIconSize(v)
                                }
                            }

                            // Auto-hide Dock (Bug-free toggle row)
                            ShadcnToggleRow {
                                rowTitle: I18n.tr("dock_autohide")
                                rowDesc: I18n.tr("dock_autohide_desc")
                                toggled: ConfigManager.dockAutoHide
                                onToggled: ConfigManager.setDockAutoHide(!ConfigManager.dockAutoHide)
                            }

                            // Active Window Underline (Bug-free toggle row)
                            ShadcnToggleRow {
                                rowTitle: I18n.tr("dock_underline")
                                rowDesc: I18n.tr("dock_underline_desc")
                                toggled: ConfigManager.showUnderline
                                onToggled: {
                                    ConfigManager.showUnderline = !ConfigManager.showUnderline;
                                    ConfigManager.saveConfig();
                                }
                            }

                            // Pinned Apps
                            ShadcnSection {
                                sectionTitle: I18n.tr("pinned_apps")
                                sectionDesc: ConfigManager.pinnedApps.length + " " + I18n.tr("pinned_apps_count")

                                Row {
                                    spacing: 6
                                    Repeater {
                                        model: ConfigManager.pinnedApps
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: 32
                                            height: 32
                                            radius: 6
                                            color: root.sz800
                                            border.color: root.sz700
                                            AppIcon {
                                                anchors.centerIn: parent
                                                iconSize: 20
                                                source: modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 4. TOP BAR
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "topbar"

                            ShadcnSection {
                                sectionTitle: I18n.tr("clock_format")
                                sectionDesc: I18n.tr("clock_format_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: "12h", label: I18n.tr("12h") },
                                        { val: "24h", label: I18n.tr("24h") }
                                    ]
                                    selectedVal: ConfigManager.clockFormat
                                    onSelect: v => ConfigManager.setClockFormat(v)
                                }
                            }

                            ShadcnToggleRow {
                                rowTitle: I18n.tr("show_workspaces")
                                rowDesc: I18n.tr("show_workspaces_desc")
                                toggled: ConfigManager.topBarShowWorkspaces
                                onToggled: {
                                    ConfigManager.topBarShowWorkspaces = !ConfigManager.topBarShowWorkspaces;
                                    ConfigManager.saveConfig();
                                }
                            }

                            ShadcnToggleRow {
                                rowTitle: I18n.tr("show_brand")
                                rowDesc: I18n.tr("show_brand_desc")
                                toggled: ConfigManager.topBarShowBrand
                                onToggled: {
                                    ConfigManager.topBarShowBrand = !ConfigManager.topBarShowBrand;
                                    ConfigManager.saveConfig();
                                }
                            }

                            ShadcnControlRow {
                                rowTitle: I18n.tr("workspaces_count")
                                rowDesc: I18n.tr("workspaces_count_desc")

                                ShadcnStepper {
                                    value: ConfigManager.workspacesCount
                                    minVal: 2
                                    maxVal: 10
                                    onDecrement: {
                                        ConfigManager.workspacesCount = Math.max(2, ConfigManager.workspacesCount - 1);
                                        ConfigManager.saveConfig();
                                    }
                                    onIncrement: {
                                        ConfigManager.workspacesCount = Math.min(10, ConfigManager.workspacesCount + 1);
                                        ConfigManager.saveConfig();
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 5. WINDOWS
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "windows"

                            ShadcnSection {
                                sectionTitle: I18n.tr("layout_presets")
                                sectionDesc: I18n.tr("layout_presets_desc")

                                Row {
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { title: I18n.tr("preset_compact"),  desc: "Gaps 4/8 · Round 6",   in: 4,  out: 8,  r: 6 },
                                            { title: I18n.tr("preset_standard"), desc: "Gaps 6/10 · Round 8",  in: 6,  out: 10, r: 8 },
                                            { title: I18n.tr("preset_spacious"), desc: "Gaps 10/16 · Round 12", in: 10, out: 16, r: 12 }
                                        ]
                                        delegate: Rectangle {
                                            id: wpC
                                            required property var modelData
                                            readonly property bool isSel: ConfigManager.windowGapsIn === modelData.in && ConfigManager.windowRounding === modelData.r
                                            width: 152
                                            height: 60
                                            radius: 10
                                            color: isSel ? Qt.alpha(Theme.colors.accent, 0.15) : (wpC_ma.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Theme.colors.surfaceElevated)
                                            border.color: isSel ? Theme.colors.accent : (wpC_ma.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06))
                                            border.width: isSel ? 1.5 : 1
                                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 2
                                                Text {
                                                    text: modelData.title
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: wpC.isSel ? Font.DemiBold : Font.Medium
                                                    color: wpC.isSel ? Theme.colors.accent : Theme.colors.text
                                                }
                                                Text {
                                                    text: modelData.desc
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 11
                                                    color: wpC.isSel ? Theme.colors.textSecondary : Theme.colors.textTertiary
                                                }
                                            }

                                            MouseArea {
                                                id: wpC_ma
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    ConfigManager.setWindowGaps(modelData.in, modelData.out);
                                                    ConfigManager.setWindowRounding(modelData.r);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ShadcnControlRow {
                                rowTitle: I18n.tr("gaps_in")
                                rowDesc: I18n.tr("gaps_in_desc")
                                ShadcnStepper {
                                    value: ConfigManager.windowGapsIn
                                    minVal: 0
                                    maxVal: 30
                                    unit: "px"
                                    onDecrement: ConfigManager.setWindowGaps(ConfigManager.windowGapsIn - 1, ConfigManager.windowGapsOut)
                                    onIncrement: ConfigManager.setWindowGaps(ConfigManager.windowGapsIn + 1, ConfigManager.windowGapsOut)
                                }
                            }

                            ShadcnControlRow {
                                rowTitle: I18n.tr("gaps_out")
                                rowDesc: I18n.tr("gaps_out_desc")
                                ShadcnStepper {
                                    value: ConfigManager.windowGapsOut
                                    minVal: 0
                                    maxVal: 60
                                    unit: "px"
                                    onDecrement: ConfigManager.setWindowGaps(ConfigManager.windowGapsIn, ConfigManager.windowGapsOut - 2)
                                    onIncrement: ConfigManager.setWindowGaps(ConfigManager.windowGapsIn, ConfigManager.windowGapsOut + 2)
                                }
                            }

                            ShadcnControlRow {
                                rowTitle: I18n.tr("corner_radius")
                                rowDesc: I18n.tr("corner_radius_desc")
                                ShadcnStepper {
                                    value: ConfigManager.windowRounding
                                    minVal: 0
                                    maxVal: 24
                                    unit: "px"
                                    onDecrement: ConfigManager.setWindowRounding(ConfigManager.windowRounding - 2)
                                    onIncrement: ConfigManager.setWindowRounding(ConfigManager.windowRounding + 2)
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 6. DESKTOP
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "desktop"

                            ShadcnSection {
                                sectionTitle: I18n.tr("desktop_mode")
                                sectionDesc: I18n.tr("desktop_mode_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: "clean",       label: I18n.tr("clean_mode") },
                                        { val: "widgets",     label: I18n.tr("widgets_mode") },
                                        { val: "traditional", label: I18n.isRTL ? "تقليدي (أيقونات)" : "Traditional (Icons)" }
                                    ]
                                    selectedVal: ConfigManager.desktopMode
                                    onSelect: v => ConfigManager.setDesktopMode(v)
                                }
                            }

                            ShadcnToggleRow {
                                rowTitle: I18n.tr("desktop_icons")
                                rowDesc: I18n.tr("desktop_icons_desc")
                                toggled: ConfigManager.showDesktopIcons
                                onToggled: ConfigManager.setShowDesktopIcons(!ConfigManager.showDesktopIcons)
                            }

                            ShadcnSection {
                                sectionTitle: I18n.isRTL ? "أدوات سطح المكتب النشطة" : "Active Desktop Widgets"
                                sectionDesc: I18n.isRTL ? "تفعيل وإلغاء الأدوات المعروضة على سطح المكتب" : "Toggle widgets displayed on the desktop surface"
                                visible: ConfigManager.desktopMode === "widgets"

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { id: "clock",          name: I18n.isRTL ? "الساعة والتاريخ" : "Clock & Date" },
                                            { id: "weather",        name: I18n.isRTL ? "الطقس" : "Weather" },
                                            { id: "system_monitor", name: I18n.isRTL ? "مراقب الموارد" : "Hardware Monitor" },
                                            { id: "notes",          name: I18n.isRTL ? "الملاحظات السريعة" : "Quick Notes" }
                                        ]
                                        delegate: Rectangle {
                                            id: wpPill
                                            required property var modelData
                                            readonly property bool isOn: ConfigManager.isWidgetEnabled(modelData.id)
                                            implicitWidth: wpPillTxt.implicitWidth + 24
                                            height: 30
                                            radius: 4
                                            color: isOn ? root.sz800 : root.sz900
                                            border.color: isOn ? root.sz50 : root.sz800
                                            border.width: 1

                                            Text {
                                                id: wpPillTxt
                                                anchors.centerIn: parent
                                                text: modelData.name
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: 12
                                                font.weight: wpPill.isOn ? Font.Medium : Font.Normal
                                                color: wpPill.isOn ? root.sz50 : root.sz400
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ConfigManager.toggleWidget(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            ShadcnSection {
                                sectionTitle: I18n.tr("wallpaper_title")
                                sectionDesc: I18n.tr("wallpaper_desc")

                                RowLayout {
                                    width: parent.width
                                    spacing: 14

                                    Rectangle {
                                        width: 140
                                        height: 84
                                        radius: 6
                                        clip: true
                                        border.color: root.sz800
                                        border.width: 1

                                        Image {
                                            anchors.fill: parent
                                            source: (ConfigManager.wallpaper && ConfigManager.wallpaper.length > 0)
                                                    ? (ConfigManager.wallpaper.startsWith("file://") ? ConfigManager.wallpaper : ("file://" + ConfigManager.wallpaper))
                                                    : ("file://" + ConfigManager.projectDir + "/assets/wallpaper.jpg")
                                            fillMode: Image.PreserveAspectCrop
                                            cache: false
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: ConfigManager.wallpaper.split("/").pop() || "wallpaper.jpg"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: root.sz100
                                        }

                                        Text {
                                            text: I18n.isRTL ? "لتغيير الخلفية واختيار صورة أخرى، انتقل إلى قسم المظهر" : "To customize or browse new wallpapers, go to Appearance tab"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 11
                                            color: root.sz400
                                        }
                                    }

                                    ShadcnButton {
                                        btnText: I18n.isRTL ? "إعدادات المظهر" : "Appearance Settings"
                                        onClicked: root.activeTab = "appearance"
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 7. NETWORK & WI-FI (REAL SCAN & MANAGEMENT)
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            id: netPanel
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "network"

                            property var netData: ({ ethernet: { connected: true, device: "eno1", ip: "192.168.100.9" }, wifi: { available: false, enabled: true, networks: [] } })
                            property bool isScanning: false

                            onVisibleChanged: {
                                if (visible) netStatusProc.running = true
                            }

                            Process {
                                id: netStatusProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-network.py", "status"]
                                stdout: SplitParser {
                                    onRead: data => {
                                        try {
                                            netPanel.netData = JSON.parse(data.trim());
                                        } catch (e) {}
                                    }
                                }
                            }

                            Process {
                                id: netToggleProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-network.py", "toggle-wifi"]
                                onExited: netStatusProc.running = true
                            }

                            Process {
                                id: netRescanProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-network.py", "rescan"]
                                onExited: {
                                    netPanel.isScanning = false;
                                    netStatusProc.running = true;
                                }
                            }

                            property bool ipCopied: false
                            Timer {
                                id: copyResetTimer
                                interval: 2000
                                onTriggered: netPanel.ipCopied = false
                            }

                            Process {
                                id: copyProc
                            }

                            // Ethernet Status Card
                            ShadcnSection {
                                sectionTitle: I18n.isRTL ? "الشبكة السلكية (Ethernet)" : "Wired Network (Ethernet)"
                                sectionDesc: I18n.isRTL ? "اتصال كابل الشبكة الفيزيائي الفعّال" : "Active physical cable connection"
                                badgeText: netPanel.netData.ethernet && netPanel.netData.ethernet.connected ? I18n.tr("connected") : I18n.tr("disconnected")

                                RowLayout {
                                    width: parent.width
                                    spacing: 14

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: netPanel.netData.ethernet && netPanel.netData.ethernet.connected ? root.green : root.sz600
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: (I18n.isRTL ? "المنفذ: " : "Interface: ") + (netPanel.netData.ethernet ? netPanel.netData.ethernet.device : "eno1")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: root.sz50
                                        }
                                        Text {
                                            text: I18n.tr("ip_address") + ": " + (netPanel.netData.ethernet ? netPanel.netData.ethernet.ip : "192.168.100.9")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                    }

                                    ShadcnButton {
                                        btnText: netPanel.ipCopied ? I18n.tr("copied") : (I18n.isRTL ? "نسخ الـ IP" : "Copy IP")
                                        onClicked: {
                                            var theIp = (netPanel.netData.ethernet && netPanel.netData.ethernet.ip) ? netPanel.netData.ethernet.ip : "192.168.100.9";
                                            copyProc.exec(["wl-copy", theIp]);
                                            netPanel.ipCopied = true;
                                            copyResetTimer.restart();
                                        }
                                    }
                                }
                            }

                            // Wi-Fi Control Card
                            ShadcnSection {
                                sectionTitle: I18n.tr("wifi_title")
                                sectionDesc: I18n.tr("wifi_desc")
                                badgeText: netPanel.netData.wifi && netPanel.netData.wifi.enabled ? I18n.tr("radio_on") : I18n.tr("radio_off")

                                Column {
                                    width: parent.width
                                    spacing: 12

                                    RowLayout {
                                        width: parent.width
                                        Text {
                                            text: netPanel.netData.wifi && netPanel.netData.wifi.enabled ? I18n.tr("wifi_enabled") : I18n.tr("wifi_disabled")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            color: root.sz200
                                            Layout.fillWidth: true
                                        }

                                        ShadcnButton {
                                            btnText: netPanel.netData.wifi && netPanel.netData.wifi.enabled ? I18n.tr("disable_wifi") : I18n.tr("enable_wifi")
                                            onClicked: netToggleProc.running = true
                                        }

                                        ShadcnButton {
                                            btnText: netPanel.isScanning ? I18n.tr("scanning") : I18n.tr("scan_networks")
                                            onClicked: {
                                                netPanel.isScanning = true;
                                                netRescanProc.running = true;
                                            }
                                        }
                                    }

                                    Rectangle { width: parent.width; height: 1; color: root.sz800 }

                                    // Network list or adapter notice
                                    Text {
                                        visible: !netPanel.netData.wifi || !netPanel.netData.wifi.available || netPanel.netData.wifi.networks.length === 0
                                        text: netPanel.netData.wifi && netPanel.netData.wifi.available ? I18n.tr("no_wifi_range") : I18n.tr("no_wifi_adapter")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        color: root.sz400
                                    }

                                    Repeater {
                                        model: netPanel.netData.wifi ? netPanel.netData.wifi.networks : []
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: 44
                                            radius: 6
                                            color: root.sz800
                                            border.color: root.sz700
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 10

                                                Text {
                                                    text: modelData.ssid
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    color: root.sz50
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: modelData.signal + "% • " + modelData.security
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 11
                                                    color: root.sz400
                                                }

                                                ShadcnButton {
                                                    btnText: modelData.connected ? I18n.tr("connected") : I18n.tr("connect")
                                                    onClicked: {
                                                        // connect command
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 8. BLUETOOTH (REAL DEVICE MANAGEMENT & SCAN)
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            id: btPanel
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "bluetooth"

                            property var btData: ({ powered: true, devices: [] })
                            property bool isScanning: false

                            onVisibleChanged: {
                                if (visible) btStatusProc.running = true
                            }

                            Process {
                                id: btStatusProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "list"]
                                stdout: SplitParser {
                                    onRead: data => {
                                        try {
                                            btPanel.btData = JSON.parse(data.trim());
                                        } catch (e) {}
                                    }
                                }
                            }

                            Process {
                                id: btToggleProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "toggle"]
                                onExited: btStatusProc.running = true
                            }

                            Process {
                                id: btScanProc
                                command: [ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", "scan"]
                                onExited: {
                                    btPanel.isScanning = false;
                                    btStatusProc.running = true;
                                }
                            }

                            // Adapter Control Card
                            ShadcnSection {
                                sectionTitle: I18n.tr("bluetooth_status")
                                sectionDesc: I18n.tr("bluetooth_status_desc")
                                badgeText: btPanel.btData.powered ? I18n.tr("active") : I18n.tr("disabled")

                                RowLayout {
                                    width: parent.width
                                    spacing: 12

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: btPanel.btData.powered ? root.green : root.sz600
                                    }

                                    Text {
                                        text: btPanel.btData.powered ? I18n.tr("bt_enabled") : I18n.tr("bt_disabled")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 13
                                        color: root.sz200
                                        Layout.fillWidth: true
                                    }

                                    ShadcnButton {
                                        btnText: btPanel.btData.powered ? I18n.tr("disable_bt") : I18n.tr("enable_bt")
                                        onClicked: btToggleProc.running = true
                                    }

                                    ShadcnButton {
                                        btnText: btPanel.isScanning ? I18n.tr("scanning") : I18n.tr("scan_devices")
                                        onClicked: {
                                            btPanel.isScanning = true;
                                            btScanProc.running = true;
                                        }
                                    }
                                }
                            }

                            // Paired & Connected Devices List
                            ShadcnSection {
                                sectionTitle: I18n.tr("bluetooth_devices")
                                sectionDesc: I18n.tr("bluetooth_devices_desc")
                                badgeText: (btPanel.btData.devices ? btPanel.btData.devices.length : 0) + " " + I18n.tr("devices")

                                Column {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        visible: !btPanel.btData.devices || btPanel.btData.devices.length === 0
                                        text: I18n.tr("no_bt_devices")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: 12
                                        color: root.sz400
                                    }

                                    Repeater {
                                        model: btPanel.btData.devices || []
                                        delegate: Rectangle {
                                            id: devRow
                                            required property var modelData
                                            width: parent.width
                                            height: 52
                                            radius: 6
                                            color: root.sz800
                                            border.color: root.sz700
                                            border.width: 1

                                            property Process connProc: Process {
                                                command: [ConfigManager.projectDir + "/scripts/deloway-bluetooth.py", devRow.modelData.connected ? "disconnect" : "connect", devRow.modelData.address]
                                                onExited: btStatusProc.running = true
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 16
                                                spacing: 12

                                                SymbolicIcon {
                                                    source: devRow.modelData.icon || "input-gaming-symbolic"
                                                    iconSize: 18
                                                    iconColor: devRow.modelData.connected ? root.sz50 : root.sz400
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text {
                                                        text: devRow.modelData.name
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 13
                                                        font.weight: Font.Medium
                                                        color: root.sz50
                                                    }
                                                    Text {
                                                        text: devRow.modelData.address + (devRow.modelData.connected ? (" • " + I18n.tr("connected")) : (" • " + I18n.tr("paired")))
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 11
                                                        color: devRow.modelData.connected ? root.green : root.sz400
                                                    }
                                                }

                                                ShadcnButton {
                                                    btnText: devRow.modelData.connected ? I18n.tr("disconnect") : I18n.tr("connect")
                                                    onClicked: devRow.connProc.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 9. POWER
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "power"

                            ShadcnSection {
                                sectionTitle: I18n.tr("power_profile")
                                sectionDesc: I18n.tr("power_profile_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: "performance", label: I18n.tr("power_perf") },
                                        { val: "balanced",    label: I18n.tr("power_bal") },
                                        { val: "saver",       label: I18n.tr("power_sav") }
                                    ]
                                    selectedVal: ConfigManager.powerProfile
                                    onSelect: v => ConfigManager.setPowerProfile(v)
                                }
                            }

                            ShadcnSection {
                                sectionTitle: I18n.tr("screen_sleep")
                                sectionDesc: I18n.tr("screen_sleep_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: 0,    label: I18n.tr("never") },
                                        { val: 300,  label: "5 " + I18n.tr("min") },
                                        { val: 600,  label: "10 " + I18n.tr("min") },
                                        { val: 900,  label: "15 " + I18n.tr("min") },
                                        { val: 1800, label: "30 " + I18n.tr("min") }
                                    ]
                                    selectedVal: ConfigManager.sleepTimeout
                                    onSelect: v => {
                                        ConfigManager.sleepTimeout = v;
                                        ConfigManager.saveConfig();
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 10. NOTIFICATIONS
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "notifications"

                            ShadcnToggleRow {
                                rowTitle: I18n.tr("dnd_mode")
                                rowDesc: I18n.tr("dnd_mode_desc")
                                toggled: ConfigManager.notificationsDnd
                                onToggled: {
                                    ConfigManager.notificationsDnd = !ConfigManager.notificationsDnd;
                                    ConfigManager.saveConfig();
                                }
                            }

                            ShadcnToggleRow {
                                rowTitle: I18n.tr("notif_sound")
                                rowDesc: I18n.tr("notif_sound_desc")
                                toggled: ConfigManager.notificationsSound
                                onToggled: {
                                    ConfigManager.notificationsSound = !ConfigManager.notificationsSound;
                                    ConfigManager.saveConfig();
                                }
                            }

                            ShadcnSection {
                                sectionTitle: I18n.tr("notif_timeout")
                                sectionDesc: I18n.tr("notif_timeout_desc")

                                ShadcnSegmented {
                                    model: [
                                        { val: 3000,  label: "3" + I18n.tr("sec_short") },
                                        { val: 5000,  label: "5" + I18n.tr("sec_short") + " (" + I18n.tr("default") + ")" },
                                        { val: 8000,  label: "8" + I18n.tr("sec_short") },
                                        { val: 10000, label: "10" + I18n.tr("sec_short") }
                                    ]
                                    selectedVal: ConfigManager.notificationsTimeout
                                    onSelect: v => {
                                        ConfigManager.notificationsTimeout = v;
                                        ConfigManager.saveConfig();
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 11. SHORTCUTS
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "shortcuts"

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: I18n.tr("system_keybindings")
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: root.sz200
                                    Layout.fillWidth: true
                                }
                                ShadcnButton {
                                    btnText: I18n.tr("cheat_sheet_btn")
                                    onClicked: ShellState.openCheatSheet()
                                }
                            }

                            Repeater {
                                model: [
                                    {
                                        category: I18n.tr("cat_wm"),
                                        items: [
                                            ["Super + Q", I18n.tr("sc_close")],
                                            ["Super + F", I18n.tr("sc_fullscreen")],
                                            ["Shift + Alt", I18n.tr("sc_switch_kb")],
                                            ["Super + P", I18n.tr("sc_floating")],
                                            ["Super + 1–9", I18n.tr("sc_workspace")]
                                        ]
                                    },
                                    {
                                        category: I18n.tr("cat_shell"),
                                        items: [
                                            ["Super", I18n.tr("sc_launcher")],
                                            ["Super + I", I18n.tr("sc_settings")],
                                            ["Super + T", I18n.tr("sc_cheatsheet")],
                                            ["Super + N", I18n.tr("sc_quicksettings")],
                                            ["Super + Shift + S", I18n.tr("sc_snip")],
                                            ["Ctrl + Alt + Del", I18n.tr("sc_power")]
                                        ]
                                    }
                                ]
                                delegate: ShadcnSection {
                                    required property var modelData
                                    sectionTitle: modelData.category
                                    sectionDesc: modelData.items.length + " " + I18n.tr("tab_shortcuts")

                                    Column {
                                        width: parent.width
                                        spacing: 0

                                        Repeater {
                                            model: modelData.items
                                            delegate: Rectangle {
                                                required property var modelData
                                                required property int index
                                                width: parent.width
                                                height: 38
                                                color: "transparent"

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: 1
                                                    color: root.sz800
                                                    visible: index < parent.parent.count - 1
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: 10

                                                    Text {
                                                        text: modelData[1]
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 13
                                                        color: root.sz200
                                                        Layout.fillWidth: true
                                                    }

                                                    Rectangle {
                                                        implicitWidth: kBadge.implicitWidth + 12
                                                        height: 22
                                                        radius: 4
                                                        color: root.sz800
                                                        border.color: root.sz700
                                                        border.width: 1
                                                        Text {
                                                            id: kBadge
                                                            anchors.centerIn: parent
                                                            text: modelData[0]
                                                            font.family: Theme.typography.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Medium
                                                            color: root.sz200
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 12. DEFAULT APPS (INTERACTIVE PICKERS)
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "applications"

                            ShadcnSection {
                                sectionTitle: I18n.tr("tab_applications")
                                sectionDesc: I18n.tr("default_apps_desc")

                                Column {
                                    width: parent.width
                                    spacing: 16

                                    // 1. Web Browser
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: I18n.tr("web_browser")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: root.sz50
                                        }
                                        Text {
                                            text: I18n.tr("web_browser_desc")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                        ShadcnSegmented {
                                            model: [
                                                { val: "brave", label: "Brave Browser" },
                                                { val: "google-chrome", label: "Google Chrome" },
                                                { val: "firefox", label: "Mozilla Firefox" }
                                            ]
                                            selectedVal: ConfigManager.defaultBrowser
                                            onSelect: v => ConfigManager.setDefaultApp("browser", v)
                                        }
                                    }

                                    Rectangle { width: parent.width; height: 1; color: root.sz800 }

                                    // 2. Terminal
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: I18n.tr("terminal_emulator")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: root.sz50
                                        }
                                        Text {
                                            text: I18n.tr("terminal_emulator_desc")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                        ShadcnSegmented {
                                            model: [
                                                { val: "kitty", label: "Kitty Terminal" },
                                                { val: "alacritty", label: "Alacritty" },
                                                { val: "foot", label: "Foot" }
                                            ]
                                            selectedVal: ConfigManager.defaultTerminal
                                            onSelect: v => ConfigManager.setDefaultApp("terminal", v)
                                        }
                                    }

                                    Rectangle { width: parent.width; height: 1; color: root.sz800 }

                                    // 3. File Manager
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: I18n.tr("file_manager")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: root.sz50
                                        }
                                        Text {
                                            text: I18n.tr("file_manager_desc")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                        ShadcnSegmented {
                                            model: [
                                                { val: "thunar", label: "Thunar (Xfce)" }
                                            ]
                                            selectedVal: ConfigManager.defaultFileManager
                                            onSelect: v => ConfigManager.setDefaultApp("fileManager", v)
                                        }
                                    }

                                    Rectangle { width: parent.width; height: 1; color: root.sz800 }

                                    // 4. Code / Editor
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            text: I18n.tr("code_editor")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: root.sz50
                                        }
                                        Text {
                                            text: I18n.tr("code_editor_desc")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                        ShadcnSegmented {
                                            model: [
                                                { val: "antigravity-ide", label: "Antigravity IDE" },
                                                { val: "code", label: "VS Code" },
                                                { val: "gedit", label: "Text Editor" }
                                            ]
                                            selectedVal: ConfigManager.defaultEditor
                                            onSelect: v => ConfigManager.setDefaultApp("editor", v)
                                        }
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════════════════════
                        // 13. ABOUT
                        // ════════════════════════════════════════════════
                        ColumnLayout {
                            id: aboutPanel
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.activeTab === "about"

                            property string kernelVer: ""
                            property string hyprVer: ""
                            property string uptimeStr: ""
                            property string cpuModel: ""
                            property string memTotal: ""

                            onVisibleChanged: {
                                if (visible) {
                                    sysKernelProc.running = true;
                                    sysHyprProc.running = true;
                                    sysUptimeProc.running = true;
                                    sysCpuProc.running = true;
                                    sysMemProc.running = true;
                                }
                            }

                            Process { id: sysKernelProc; command: ["uname", "-r"]; stdout: SplitParser { onRead: data => aboutPanel.kernelVer = data.trim() } }
                            Process { id: sysHyprProc; command: ["hyprctl", "version"]; stdout: SplitParser { onRead: data => { var m = data.match(/Hyprland\s+([^\s]+)/); if (m) aboutPanel.hyprVer = m[1]; } } }
                            Process { id: sysUptimeProc; command: ["uptime", "-p"]; stdout: SplitParser { onRead: data => aboutPanel.uptimeStr = data.trim().replace(/^up\s+/, "") } }
                            Process { id: sysCpuProc; command: ["sh", "-c", "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //'"]; stdout: SplitParser { onRead: data => aboutPanel.cpuModel = data.trim() } }
                            Process { id: sysMemProc; command: ["sh", "-c", "free -h --si | awk '/^Mem:/{print $2}'"]; stdout: SplitParser { onRead: data => aboutPanel.memTotal = data.trim() } }

                            // Header Card
                            Rectangle {
                                Layout.fillWidth: true
                                height: 76
                                radius: 6
                                color: root.sz900
                                border.color: root.sz800
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 14

                                    Rectangle {
                                        width: 44
                                        height: 44
                                        radius: 8
                                        color: root.sz800
                                        border.color: root.sz700
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "D"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 20
                                            font.weight: Font.Bold
                                            color: root.sz50
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            text: "DeloOS"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                            color: root.sz50
                                        }
                                        Text {
                                            text: "Deloway Desktop Environment • Arch Linux"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 12
                                            color: root.sz400
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        width: 52
                                        height: 22
                                        radius: 4
                                        color: root.sz800
                                        border.color: root.sz700
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: "v1.0"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: root.sz400
                                        }
                                    }
                                }
                            }

                            // Hardware Info
                            ShadcnSection {
                                sectionTitle: I18n.tr("about_hardware_overview")
                                sectionDesc: I18n.tr("about_hardware_desc")

                                Column {
                                    width: parent.width
                                    spacing: 0

                                    Repeater {
                                        model: [
                                            { label: I18n.tr("os_name"),             value: "Arch Linux (x86_64)" },
                                            { label: I18n.tr("kernel"),              value: aboutPanel.kernelVer || I18n.tr("loading") },
                                            { label: I18n.tr("hyprland_ver"),        value: aboutPanel.hyprVer   || I18n.tr("loading") },
                                            { label: I18n.tr("uptime"),              value: aboutPanel.uptimeStr  || I18n.tr("loading") },
                                            { label: I18n.tr("processor"),           value: aboutPanel.cpuModel   || I18n.tr("loading") },
                                            { label: I18n.tr("system_memory"),       value: aboutPanel.memTotal ? aboutPanel.memTotal + " RAM" : I18n.tr("loading") },
                                            { label: I18n.tr("shell_font"),          value: "SF Pro Display / SF Arabic" },
                                            { label: I18n.tr("mono_font"),           value: "JetBrainsMono Nerd Font" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: parent.width
                                            height: 36
                                            color: "transparent"

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: 1
                                                color: root.sz800
                                                visible: index < 7
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 10

                                                Text {
                                                    text: modelData.label
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    color: root.sz400
                                                    Layout.preferredWidth: 150
                                                }
                                                Text {
                                                    text: modelData.value
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                    color: root.sz50
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // AUTHENTIC SHADCN/UI PRIMITIVES (BUG-FREE & PROPERLY SIZED)
    // ═══════════════════════════════════════════════════════════════════════

    // Sidebar navigation tab item
    component ShadcnNavItem: Item {
        property string tabId: ""
        property string label: ""
        property string iconSource: ""
        property color iconBgColor: Theme.colors.accent
        property bool isActive: false
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 36

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            radius: 7
            // macOS-style: active = blue-tinted row, hover = subtle white
            color: isActive ? Qt.rgba(0.23, 0.51, 0.95, 0.22) : (navMa.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
            border.color: "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
                spacing: 10

                // Colored circular icon container (macOS System Settings style)
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 6
                    color: iconBgColor

                    SymbolicIcon {
                        anchors.centerIn: parent
                        source: iconSource
                        iconSize: 13
                        iconColor: Qt.rgba(1, 1, 1, 0.95)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: label
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 13
                    font.weight: isActive ? Font.DemiBold : Font.Normal
                    color: isActive ? Theme.colors.text : (navMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: navMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    ShellState.activeSettingsTab = tabId;
                    activated();
                }
            }
        }
    }

    // Modern Card Container
    component ShadcnSection: Rectangle {
        id: secCard
        property string sectionTitle: ""
        property string sectionDesc: ""
        property string badgeText: ""
        default property alias secContent: secSlot.data

        Layout.fillWidth: true
        width: parent ? parent.width : 200
        implicitHeight: Math.max(64, secInnerCol.childrenRect.height + 32)
        radius: 12
        color: Theme.colors.surface
        border.color: Qt.rgba(255, 255, 255, 0.07)
        border.width: 1

        Column {
            id: secInnerCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 18
            spacing: 14

            RowLayout {
                width: parent.width
                layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: secCard.sectionTitle
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.colors.text
                        Layout.fillWidth: true
                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                    }
                    Text {
                        text: secCard.sectionDesc
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 12
                        color: Theme.colors.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                        visible: secCard.sectionDesc !== ""
                    }
                }

                Rectangle {
                    visible: secCard.badgeText !== ""
                    implicitWidth: bBadgeTxt.implicitWidth + 14
                    height: 22
                    radius: 6
                    color: Theme.colors.surfaceElevated
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                    Text {
                        id: bBadgeTxt
                        anchors.centerIn: parent
                        text: secCard.badgeText
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.colors.text
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(255, 255, 255, 0.05)
                visible: secSlot.children.length > 0
            }

            Column {
                id: secSlot
                width: parent.width
                spacing: 10
            }
        }
    }

    // Modern Switch Row
    component ShadcnToggleRow: Rectangle {
        id: toggleCard
        property string rowTitle: ""
        property string rowDesc: ""
        property bool toggled: false
        signal toggled()

        Layout.fillWidth: true
        implicitHeight: Math.max(64, toggleRowLayout.implicitHeight + 24)
        radius: 12
        color: Theme.colors.surface
        border.color: Qt.rgba(255, 255, 255, 0.07)
        border.width: 1

        RowLayout {
            id: toggleRowLayout
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: toggleCard.rowTitle
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                    Layout.fillWidth: true
                    horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                }
                Text {
                    text: toggleCard.rowDesc
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 12
                    color: Theme.colors.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                    visible: toggleCard.rowDesc !== ""
                }
            }

            // Authentic Switch
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 24
                radius: 12
                color: toggleCard.toggled ? Theme.colors.accent : Theme.colors.surfaceElevated
                border.color: toggleCard.toggled ? Theme.colors.accent : Qt.rgba(255, 255, 255, 0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: toggleCard.toggled ? Theme.textOnAccent : Theme.colors.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                    x: toggleCard.toggled ? 23 : 3
                    Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleCard.toggled()
                }
            }
        }
    }

    // Modern Control Row (Inline title, desc, and control)
    component ShadcnControlRow: Rectangle {
        id: ctrlRow
        property string rowTitle: ""
        property string rowDesc: ""
        default property alias rowContent: ctrlSlot.data

        Layout.fillWidth: true
        implicitHeight: Math.max(64, ctrlRowLayout.implicitHeight + 24)
        radius: 12
        color: Theme.colors.surface
        border.color: Qt.rgba(255, 255, 255, 0.07)
        border.width: 1

        RowLayout {
            id: ctrlRowLayout
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: ctrlRow.rowTitle
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.colors.text
                    Layout.fillWidth: true
                    horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                }
                Text {
                    text: ctrlRow.rowDesc
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 12
                    color: Theme.colors.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                    visible: ctrlRow.rowDesc !== ""
                }
            }

            Item {
                id: ctrlSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }

    // Modern Segmented Tabs Control
    component ShadcnSegmented: Rectangle {
        id: segCtrl
        property var model: []
        property var selectedVal: null
        signal select(var val)

        Layout.fillWidth: true
        width: parent ? parent.width : 200
        height: 38
        radius: 8
        color: Theme.colors.surfaceVariant
        border.color: Qt.rgba(255, 255, 255, 0.07)
        border.width: 1

        Row {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 2

            Repeater {
                model: segCtrl.model
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isSelected: {
                        var v1 = Number(segCtrl.selectedVal);
                        var v2 = Number(modelData.val);
                        if (!isNaN(v1) && !isNaN(v2)) {
                            return Math.abs(v1 - v2) < 0.02;
                        }
                        return String(segCtrl.selectedVal) === String(modelData.val);
                    }
                    width: Math.floor((parent.width - (segCtrl.model.length - 1) * 2) / Math.max(1, segCtrl.model.length))
                    height: parent.height
                    radius: 6
                    color: isSelected ? Theme.colors.accent : (segMa.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                    border.color: isSelected ? Qt.alpha(Theme.colors.accent, 0.5) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: 12
                        font.weight: parent.isSelected ? Font.DemiBold : Font.Normal
                        color: parent.isSelected ? Theme.textOnAccent : Theme.colors.textSecondary
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: segCtrl.select(modelData.val)
                    }
                }
            }
        }
    }

    // Modern Outline Button
    component ShadcnButton: Rectangle {
        id: sBtn
        property string btnText: ""
        signal clicked()

        implicitWidth: btnLabel.implicitWidth + 24
        implicitHeight: 32
        radius: 8
        color: btnMa.pressed ? Theme.colors.surfaceActive : (btnMa.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated)
        border.color: Qt.rgba(255, 255, 255, 0.08)
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: sBtn.btnText
            font.family: Theme.typography.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Theme.colors.text
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sBtn.clicked()
        }
    }

    // Modern Stepper control
    component ShadcnStepper: RowLayout {
        property int value: 0
        property int minVal: 0
        property int maxVal: 100
        property string unit: ""
        signal decrement()
        signal increment()
        spacing: 4

        Rectangle {
            width: 32
            height: 32
            radius: 8
            color: dMa.pressed ? Theme.colors.surfaceActive : (dMa.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated)
            border.color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Text {
                anchors.centerIn: parent
                text: "−"
                font.pixelSize: 15
                font.weight: Font.Bold
                color: dMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
            }
            MouseArea {
                id: dMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (value > minVal) decrement()
            }
        }
        Rectangle {
            implicitWidth: Math.max(72, sValTxt.implicitWidth + 24)
            height: 32
            radius: 8
            color: Theme.colors.surfaceElevated
            border.color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1
            Text {
                id: sValTxt
                anchors.centerIn: parent
                text: value + (unit ? " " + unit : "")
                font.family: Theme.typography.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.colors.text
            }
        }
        Rectangle {
            width: 32
            height: 32
            radius: 8
            color: iMa.pressed ? Theme.colors.surfaceActive : (iMa.containsMouse ? Theme.colors.surfaceHover : Theme.colors.surfaceElevated)
            border.color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Text {
                anchors.centerIn: parent
                text: "+"
                font.pixelSize: 15
                font.weight: Font.Bold
                color: iMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
            }
            MouseArea {
                id: iMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (value < maxVal) increment()
            }
        }
    }
}
