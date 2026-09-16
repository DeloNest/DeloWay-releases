import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../"

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

    // State management
    property bool isOpen: ShellState.settingsAppOpen
    property string activeTab: ShellState.activeSettingsTab || "appearance"
    property bool isFullScreen: ShellState.settingsFullScreen

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

    // Backdrop click-outside dismissal
    MouseArea {
        id: backdrop
        anchors.fill: parent
        enabled: root.isOpen && !root.isFullScreen
        onClicked: root.close()
    }

    // Main window card container
    Rectangle {
        id: windowCard
        readonly property real targetW: root.isFullScreen ? root.width : Math.min(1060, root.width - 80)
        readonly property real targetH: root.isFullScreen ? root.height : Math.min(700, root.height - 80)

        width: targetW
        height: targetH
        x: root.isFullScreen ? 0 : Math.round((root.width - targetW) / 2)
        y: root.isFullScreen ? 0 : Math.round((root.height - targetH) / 2)
        radius: root.isFullScreen ? 0 : Theme.radiusLarge
        color: Theme.colors.backgroundAlt
        border.color: root.isFullScreen ? "transparent" : Theme.borderSubtle
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

        // Prevent click-outside dismissal when clicking inside the window
        MouseArea {
            anchors.fill: parent
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
        }
        Behavior on x {
            NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
        }
        Behavior on y {
            NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter }
        }

        // Window Layout: Header + Body (Sidebar & Content)
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            // ── Minimalist Clean Header (Zero macOS traffic lights) ────────────
            Rectangle {
                id: windowHeader
                Layout.fillWidth: true
                height: 48
                color: Theme.colors.surface
                border.color: Theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space16
                    anchors.rightMargin: Theme.space16
                    spacing: Theme.space8
                    layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight

                    // Start Side: Shell branding & Title
                    RowLayout {
                        spacing: Theme.space8
                        Layout.alignment: Qt.AlignVCenter

                        SymbolicIcon {
                            source: "preferences-system-symbolic"
                            iconSize: 16
                            iconColor: Theme.colors.accent
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: I18n.isRTL ? "إعدادات النظام" : "System Settings"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // End Side: Clean Window Controls (Symbolic, fully themed)
                    RowLayout {
                        spacing: Theme.space4
                        Layout.alignment: Qt.AlignVCenter

                        // Fullscreen Toggle
                        Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.radiusSmall
                            color: fsBtnMa.containsMouse ? Theme.colors.surfaceHover : "transparent"

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: root.isFullScreen ? "view-restore-symbolic" : "view-fullscreen-symbolic"
                                iconSize: 14
                                iconColor: fsBtnMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
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
                            radius: Theme.radiusSmall
                            color: closeBtnMa.containsMouse ? Theme.colors.surfaceHover : "transparent"

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "window-close"
                                iconSize: 14
                                iconColor: closeBtnMa.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
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

            // ── Main Content Area: Sidebar + Active Tab Content ───────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                layoutDirection: I18n.isRTL ? Qt.RightToLeft : Qt.LeftToRight

                // 1. Sidebar
                SettingsSidebar {
                    id: sidebar
                    Layout.fillHeight: true
                    Layout.preferredWidth: 240
                    activeTab: root.activeTab
                    onTabSelected: tabId => root.selectTab(tabId)
                }

                // 2. Tab Content Pane
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Page Header (Title + Description)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 64
                        color: "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space24
                            anchors.rightMargin: Theme.space24
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.space4

                            Text {
                                text: I18n.tr("tab_" + root.activeTab)
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Theme.colors.text
                                Layout.fillWidth: true
                                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                            }

                            Text {
                                text: I18n.tr(root.activeTab + "_desc")
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: 12
                                color: Theme.colors.textSecondary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                horizontalAlignment: I18n.isRTL ? Text.AlignRight : Text.AlignLeft
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Theme.borderSubtle
                        }
                    }

                    // Content ScrollView with availableWidth fix
                    ScrollView {
                        id: contentScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Item {
                            id: contentContainer
                            width: contentScroll.availableWidth
                            implicitHeight: activeLoader ? activeLoader.implicitHeight : 340
                            property var activeLoader: null

                            Repeater {
                                model: root.tabList
                                delegate: Loader {
                                    id: tabLoader
                                    required property var modelData
                                    readonly property bool isCurrent: root.activeTab === modelData.id
                                    readonly property bool wasVisited: !!root.visitedTabs[modelData.id]

                                    width: parent ? parent.width : 0
                                    anchors.top: parent ? parent.top : undefined
                                    anchors.left: parent ? parent.left : undefined
                                    anchors.right: parent ? parent.right : undefined

                                    visible: isCurrent
                                    active: wasVisited

                                    onIsCurrentChanged: {
                                        if (isCurrent) contentContainer.activeLoader = tabLoader;
                                    }
                                    Component.onCompleted: {
                                        if (isCurrent) contentContainer.activeLoader = tabLoader;
                                    }

                                    sourceComponent: Component {
                                        Item {
                                            id: placeholderRoot
                                            width: tabLoader.width
                                            implicitHeight: 340

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: Theme.space24
                                                radius: Theme.radiusLarge
                                                color: Theme.colors.surface
                                                border.color: Theme.borderSubtle
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: Theme.space16

                                                    SymbolicIcon {
                                                        source: modelData.icon
                                                        iconSize: 40
                                                        iconColor: Theme.colors.accent
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }

                                                    Text {
                                                        text: I18n.tr("tab_" + modelData.id)
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 18
                                                        font.weight: Font.DemiBold
                                                        color: Theme.colors.text
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }

                                                    Text {
                                                        text: (I18n.isRTL ? "مساحة التبويب (Placeholder) — " : "Tab Placeholder — ") + modelData.id
                                                        font.family: Theme.typography.fontFamily
                                                        font.pixelSize: 13
                                                        color: Theme.colors.textTertiary
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
