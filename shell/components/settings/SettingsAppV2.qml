import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../"
import "tabs"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "deloway:settings-v2"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        item: root.isOpen ? windowCard : null
    }

    // State management
    property bool isOpen: ShellState.settingsAppOpen
    property string activeTab: ShellState.activeSettingsTab || "appearance"
    property bool isFullScreen: ShellState.settingsFullScreen

    // Window dragging & sizing properties
    property real customX: -1
    property real customY: -1
    property bool isDragging: false

    readonly property real windowedW: Math.min(1060, Math.max(600, root.width - 80))
    readonly property real windowedH: Math.min(700, Math.max(400, root.height - 80))

    readonly property real defaultX: Math.max(0, Math.round((root.width - windowedW) / 2))
    readonly property real defaultY: Math.max(0, Math.round((root.height - windowedH) / 2))

    readonly property real clampedX: Math.max(10, Math.min(root.width - windowCard.width - 10, (root.customX >= 0) ? root.customX : defaultX))
    readonly property real clampedY: Math.max(10, Math.min(root.height - windowCard.height - 10, (root.customY >= 0) ? root.customY : defaultY))

    // Tab definitions
    readonly property var tabList: [
        { id: "appearance",    category: "system",       icon: "applications-graphics-symbolic" },
        { id: "language",      category: "system",       icon: "preferences-desktop-locale-symbolic" },
        { id: "desktop",       category: "system",       icon: "user-home-symbolic" },
        { id: "dock",          category: "system",       icon: "view-app-grid-symbolic" },
        { id: "topbar",        category: "system",       icon: "preferences-system-symbolic" },
        { id: "windows",       category: "system",       icon: "view-fullscreen-symbolic" },
        { id: "network",       category: "connectivity", icon: "network-wireless-symbolic" },
        { id: "bluetooth",     category: "connectivity", icon: "bluetooth-active-symbolic" },
        { id: "power",         category: "connectivity", icon: "power-profile-balanced-symbolic" },
        { id: "notifications", category: "preferences",  icon: "preferences-system-notifications-symbolic" },
        { id: "shortcuts",     category: "preferences",  icon: "preferences-desktop-keyboard-shortcuts-symbolic" },
        { id: "applications",  category: "preferences",  icon: "applications-other-symbolic" },
        { id: "about",         category: "about",        icon: "dialog-information-symbolic" }
    ]

    // Lazy loading registry: maps tabId -> boolean (has been visited)
    property var visitedTabs: ({})

    function selectTab(tabId) {
        if (!tabId) return;
        root.activeTab = tabId;
        if (!root.visitedTabs[tabId]) {
            var updated = Object.assign({}, root.visitedTabs);
            updated[tabId] = true;
            root.visitedTabs = updated;
        }
        if (ShellState.activeSettingsTab !== tabId) {
            ShellState.activeSettingsTab = tabId;
        }
    }

    function open(tabId) {
        if (tabId) root.selectTab(tabId);
        ShellState.openSettingsTab(tabId || root.activeTab);
    }

    function close() {
        ShellState.closeSettingsApp();
    }

    // Synchronize with ShellState
    Connections {
        target: ShellState
        function onSettingsAppOpenChanged() {
            root.isOpen = ShellState.settingsAppOpen;
            if (ShellState.settingsAppOpen && ShellState.activeSettingsTab) {
                root.selectTab(ShellState.activeSettingsTab);
            }
        }
        function onActiveSettingsTabChanged() {
            if (ShellState.activeSettingsTab && ShellState.activeSettingsTab !== root.activeTab) {
                root.selectTab(ShellState.activeSettingsTab);
            }
        }
        function onSettingsFullScreenChanged() {
            root.isFullScreen = ShellState.settingsFullScreen;
        }
        function onSettingsScrollRequested(pos) {
            if (contentScroll && contentScroll.contentItem) {
                if (pos >= 0 && pos <= 1.0) {
                    var maxScroll = Math.max(0, contentScroll.contentHeight - contentScroll.height);
                    contentScroll.contentItem.contentY = pos * maxScroll;
                } else {
                    contentScroll.contentItem.contentY = pos;
                }
            }
        }
    }

    Component.onCompleted: {
        root.selectTab(root.activeTab);
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: {
            if (root.isFullScreen) {
                root.isFullScreen = false;
                ShellState.settingsFullScreen = false;
            } else {
                root.close();
            }
        }
    }

    Shortcut {
        sequence: "Super+Q"
        enabled: root.isOpen
        onActivated: root.close()
    }

    Shortcut {
        sequence: "Meta+Q"
        enabled: root.isOpen
        onActivated: root.close()
    }

    Shortcut {
        sequence: "Super+F"
        enabled: root.isOpen
        onActivated: {
            root.isFullScreen = !root.isFullScreen;
            ShellState.settingsFullScreen = root.isFullScreen;
        }
    }

    Shortcut {
        sequence: "Meta+F"
        enabled: root.isOpen
        onActivated: {
            root.isFullScreen = !root.isFullScreen;
            ShellState.settingsFullScreen = root.isFullScreen;
        }
    }

    Shortcut {
        sequence: "F11"
        enabled: root.isOpen
        onActivated: {
            root.isFullScreen = !root.isFullScreen;
            ShellState.settingsFullScreen = root.isFullScreen;
        }
    }

    visible: root.isOpen || windowCard.opacity > 0.01

    // Main window card
    Rectangle {
        id: windowCard

        width: root.isFullScreen ? root.width : root.windowedW
        height: root.isFullScreen ? root.height : root.windowedH
        x: root.isFullScreen ? 0 : root.clampedX
        y: root.isFullScreen ? 0 : root.clampedY
        radius: root.isFullScreen ? 0 : Theme.notchRadiusWindow
        color: Theme.notchBackground
        border.color: root.isFullScreen ? "transparent" : Theme.notchBorderSubtle
        border.width: root.isFullScreen ? 0 : 1
        clip: true

        opacity: root.isOpen ? 1.0 : 0.0
        transform: Scale {
            origin.x: windowCard.width / 2
            origin.y: windowCard.height / 2
            xScale: root.isFullScreen ? 1.0 : (root.isOpen ? 1.0 : 0.96)
            yScale: root.isFullScreen ? 1.0 : (root.isOpen ? 1.0 : 0.96)
            Behavior on xScale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
            Behavior on yScale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on width   { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on height  { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on x       { enabled: !root.isDragging; NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on y       { enabled: !root.isDragging; NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        // Window Layout: Header + Body (Sidebar & Floating Content Canvas)
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ── Integrated Header (Seamless with OLED background) ─────────
            Item {
                id: windowHeader
                Layout.fillWidth: true
                height: 50

                // Header drag area for moving the window & double-click fullscreen
                MouseArea {
                    id: headerDragArea
                    anchors.fill: parent
                    cursorShape: root.isFullScreen ? Qt.ArrowCursor : (pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor)

                    property point pressPosRoot: Qt.point(0, 0)
                    property real startCardX: 0
                    property real startCardY: 0

                    onPressed: mouse => {
                        if (!root.isFullScreen) {
                            var p = mapToItem(null, mouse.x, mouse.y);
                            pressPosRoot = p;
                            startCardX = (root.customX >= 0) ? root.customX : root.defaultX;
                            startCardY = (root.customY >= 0) ? root.customY : root.defaultY;
                            root.isDragging = true;
                        }
                    }

                    onPositionChanged: mouse => {
                        if (pressed && !root.isFullScreen) {
                            var p = mapToItem(null, mouse.x, mouse.y);
                            var deltaX = p.x - pressPosRoot.x;
                            var deltaY = p.y - pressPosRoot.y;
                            var newX = startCardX + deltaX;
                            var newY = startCardY + deltaY;

                            var minX = 10;
                            var maxX = root.width - windowCard.width - 10;
                            var minY = 10;
                            var maxY = root.height - windowCard.height - 10;

                            if (maxX < minX) {
                                minX = 0;
                                maxX = root.width - 100;
                            }
                            if (maxY < minY) {
                                minY = 0;
                                maxY = root.height - 50;
                            }

                            root.customX = Math.max(minX, Math.min(maxX, newX));
                            root.customY = Math.max(minY, Math.min(maxY, newY));
                        }
                    }

                    onReleased: {
                        root.isDragging = false;
                    }

                    onCanceled: {
                        root.isDragging = false;
                    }

                    onDoubleClicked: {
                        root.isFullScreen = !root.isFullScreen;
                        ShellState.settingsFullScreen = root.isFullScreen;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space16
                    anchors.rightMargin: Theme.space16
                    spacing: Theme.space8

                        // Start Side: Shell branding & Title
                        RowLayout {
                            spacing: Theme.space8
                            Layout.alignment: Qt.AlignVCenter

                            SymbolicIcon {
                                source: "preferences-system-symbolic"
                                iconSize: 16
                                iconColor: Theme.notchText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: I18n.isRTL ? "إعدادات النظام" : "System Settings"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(13)
                                font.weight: Font.DemiBold
                                color: Theme.notchText
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // End Side: Window Controls (Circular capsules, themed)
                        RowLayout {
                            spacing: Theme.space4
                            Layout.alignment: Qt.AlignVCenter

                            // Fullscreen Toggle
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: fsBtnMa.pressed ? Theme.notchSurfaceActive : (fsBtnMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: root.isFullScreen ? "view-restore-symbolic" : "view-fullscreen-symbolic"
                                    iconSize: 14
                                    iconColor: (fsBtnMa.containsMouse || root.isFullScreen) ? Theme.notchText : Theme.notchTextSecondary
                                    Behavior on iconColor { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                }

                                MouseArea {
                                    id: fsBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.isFullScreen = !root.isFullScreen;
                                        ShellState.settingsFullScreen = root.isFullScreen;
                                    }
                                }
                            }

                            // Close Button
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: closeBtnMa.pressed ? Theme.notchSurfaceActive : (closeBtnMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    source: "window-close"
                                    iconSize: 14
                                    iconColor: closeBtnMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                    Behavior on iconColor { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
                                }

                                MouseArea {
                                    id: closeBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.close()
                                }
                            }
                        }
                    }
                }

                // ── Main Content Area: Sidebar + Floating Content Canvas ──────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: Theme.space8
                    Layout.rightMargin: Theme.space8
                    Layout.bottomMargin: Theme.space8
                    spacing: Theme.space8

                    // 1. Sidebar
                    SettingsSidebar {
                        id: sidebar
                        Layout.fillHeight: true
                        Layout.preferredWidth: 230
                        activeTab: root.activeTab
                        onTabSelected: tabId => root.selectTab(tabId)
                    }

                    // 2. Tab Content Pane - Floating Glass Canvas
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.notchRadiusPanel
                        color: Theme.notchSurface
                        border.color: Theme.notchBorderSubtle
                        border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            LayoutMirroring.enabled: I18n.isRTL
                            LayoutMirroring.childrenInherit: true

                            // Page Header (Title + Description, no wire divider)
                            Item {
                                Layout.fillWidth: true
                                height: 64

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space24
                                    anchors.rightMargin: Theme.space24
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.space4
                                    LayoutMirroring.enabled: I18n.isRTL
                                    LayoutMirroring.childrenInherit: true

                                    Text {
                                        text: I18n.tr("tab_" + root.activeTab)
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(18)
                                        font.weight: Font.Bold
                                        color: Theme.notchText
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    Text {
                                        text: I18n.tr(root.activeTab + "_desc")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(12)
                                        color: Theme.notchTextSecondary
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                }
                            }

                            // Content ScrollView with availableWidth fix
                            ScrollView {
                                id: contentScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentWidth: availableWidth
                                contentHeight: contentContainer.implicitHeight

                                ScrollBar.vertical: ScrollBar {
                                    id: vBar
                                    policy: contentScroll.contentHeight > contentScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                    width: 6
                                    contentItem: Rectangle {
                                        implicitWidth: 6
                                        radius: 3
                                        color: vBar.pressed ? Theme.notchText : (vBar.hovered ? Theme.notchBorderHighlight : Theme.notchBorder)
                                        opacity: (vBar.active || vBar.hovered) ? 0.8 : 0.4
                                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                    }
                                }

                                Connections {
                                    target: ShellState
                                    function onSettingsScrollRequested(pos) {
                                        if (vBar) {
                                            vBar.position = Math.max(0, Math.min(1.0 - vBar.size, pos));
                                        }
                                    }
                                }

                                Item {
                                    id: contentContainer
                                    width: contentScroll.availableWidth
                                    implicitHeight: currentItem ? (currentItem.implicitHeight > 0 ? currentItem.implicitHeight : currentItem.height) : 340
                                    height: implicitHeight
                                    property Item currentItem: null

                                    Repeater {
                                        model: root.tabList
                                        delegate: Loader {
                                            id: tabLoader
                                            required property var modelData
                                            readonly property bool isCurrent: root.activeTab === modelData.id
                                            readonly property bool wasVisited: !!root.visitedTabs[modelData.id]

                                            width: parent ? parent.width : 0
                                            height: item ? item.implicitHeight : implicitHeight
                                            anchors.top: parent ? parent.top : undefined
                                            anchors.left: parent ? parent.left : undefined
                                            anchors.right: parent ? parent.right : undefined

                                            visible: isCurrent
                                            active: wasVisited

                                            function updateCurrent() {
                                                if (isCurrent && item) {
                                                    contentContainer.currentItem = item;
                                                }
                                            }

                                            onIsCurrentChanged: updateCurrent()
                                            onItemChanged: updateCurrent()
                                            Component.onCompleted: updateCurrent()

                                            sourceComponent: (modelData.id === "appearance") ? appearanceComponent : (modelData.id === "dock" ? dockComponent : (modelData.id === "windows" ? windowsComponent : (modelData.id === "topbar" ? topbarComponent : placeholderComponent)))

                                            Component {
                                                id: appearanceComponent
                                                AppearanceTab {}
                                            }

                                            Component {
                                                id: dockComponent
                                                DockTab {}
                                            }

                                            Component {
                                                id: windowsComponent
                                                WindowsTab {}
                                            }

                                            Component {
                                                id: topbarComponent
                                                TopBarTab {}
                                            }

                                            Component {
                                                id: placeholderComponent
                                                Item {
                                                    id: placeholderRoot
                                                    width: tabLoader.width
                                                    implicitHeight: 340

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: Theme.space24
                                                        radius: Theme.notchRadiusCard
                                                        color: Theme.notchSurfaceElevated
                                                        border.color: Theme.notchBorderSubtle
                                                        border.width: 1

                                                        ColumnLayout {
                                                            anchors.centerIn: parent
                                                            spacing: Theme.space16

                                                            SymbolicIcon {
                                                                source: modelData.icon
                                                                iconSize: 32
                                                                iconColor: Theme.notchText
                                                                Layout.alignment: Qt.AlignHCenter
                                                            }

                                                            Text {
                                                                text: I18n.tr("tab_" + modelData.id)
                                                                font.family: Theme.typography.fontFamily
                                                                font.pixelSize: Theme.fontSize(18)
                                                                font.weight: Font.DemiBold
                                                                color: Theme.notchText
                                                                Layout.alignment: Qt.AlignHCenter
                                                            }

                                                            Text {
                                                                text: (I18n.isRTL ? "مساحة التبويب (Placeholder) — " : "Tab Placeholder — ") + modelData.id
                                                                font.family: Theme.typography.fontFamily
                                                                font.pixelSize: Theme.fontSize(13)
                                                                color: Theme.notchTextTertiary
                                                                Layout.alignment: Qt.AlignHCenter
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
            }
        }
    }
