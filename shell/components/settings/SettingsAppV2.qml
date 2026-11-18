import "../"
import "../../services"
import "../../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "tabs"

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    // State management
    property bool isOpen: ShellState.settingsAppOpen
    property string activeTab: ShellState.resolveSettingsTab(ShellState.activeSettingsTab)
    property bool isFullScreen: ShellState.settingsFullScreen

    function toggleFullscreen() {
        ShellState.toggleSettingsFullscreen();
    }

    // Window dragging & sizing properties
    property real customX: -1
    property real customY: -1
    property bool isDragging: false
    // Screen and window dimensions
    readonly property real screenW: targetScreen ? targetScreen.width : (root.width > 0 ? root.width : 1920)
    readonly property real screenH: targetScreen ? targetScreen.height : (root.height > 0 ? root.height : 1080)
    readonly property real windowedW: Math.min(1180, Math.max(720, screenW - 100))
    readonly property real windowedH: Math.min(860, Math.max(500, screenH - 120))
    readonly property real defaultX: Math.max(0, Math.round((screenW - windowedW) / 2))
    readonly property real defaultY: Math.max(0, Math.round((screenH - windowedH) / 2))
    readonly property real clampedX: (root.customX >= 0) ? Math.max(10, Math.min(screenW - windowedW - 10, root.customX)) : defaultX
    readonly property real clampedY: (root.customY >= 0) ? Math.max(10, Math.min(screenH - windowedH - 10, root.customY)) : defaultY

    // Work area gaps matching natural Hyprland windows (leaving capsules and dock completely clear)
    readonly property real gapOut: (typeof ConfigManager !== "undefined" && ConfigManager.windowGapsOut > 0)
                                   ? ConfigManager.windowGapsOut : 10
    readonly property real topGap: Math.max(64, Theme.topBarMarginTop + Theme.topBarCapsuleHeight + gapOut)
    readonly property real bottomGap: Math.max(76, Theme.dockEdgeMargin + Theme.dockHeight + gapOut)
    readonly property real sideGap: gapOut

    readonly property real maximizedX: sideGap
    readonly property real maximizedY: topGap
    readonly property real maximizedW: Math.max(720, screenW - (sideGap * 2))
    readonly property real maximizedH: Math.max(500, screenH - topGap - bottomGap)
    readonly property real normalWindowRounding: (typeof ConfigManager !== "undefined" && ConfigManager.windowRounding > 0)
                                                ? ConfigManager.windowRounding : 10
    // Flattened page order from the registry (groups → pages)
    readonly property var tabList: {
        const out = [];
        for (const g of ShellState.settingsGroups) for (const id of g.pages) out.push({
            "id": id,
            "icon": ShellState.settingsPages[id].icon,
            "file": ShellState.settingsPages[id].file
        })
        return out;
    }
    // Lazy loading registry: maps tabId -> boolean (has been visited)
    property var visitedTabs: ({
    })

    function selectTab(tabId) {
        if (!tabId)
            return ;

        tabId = ShellState.resolveSettingsTab(tabId);
        root.activeTab = tabId;
        if (!root.visitedTabs[tabId]) {
            var updated = Object.assign({
            }, root.visitedTabs);
            updated[tabId] = true;
            root.visitedTabs = updated;
        }
        if (ShellState.activeSettingsTab !== tabId)
            ShellState.activeSettingsTab = tabId;

    }

    function open(tabId) {
        if (tabId)
            root.selectTab(tabId);

        ShellState.openSettingsTab(tabId || root.activeTab);
    }

    function close() {
        ShellState.closeSettingsApp();
    }

    screen: targetScreen
    color: "transparent"
    WlrLayershell.namespace: "deloway:settings-v2"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    Component.onCompleted: {
        root.selectTab(root.activeTab);
    }
    visible: root.isOpen || windowCard.opacity > 0.01

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Synchronize with ShellState
    Connections {
        function onSettingsAppOpenChanged() {
            root.isOpen = ShellState.settingsAppOpen;
            if (ShellState.settingsAppOpen && ShellState.activeSettingsTab)
                root.selectTab(ShellState.activeSettingsTab);

        }

        function onActiveSettingsTabChanged() {
            if (ShellState.activeSettingsTab && ShellState.activeSettingsTab !== root.activeTab)
                root.selectTab(ShellState.activeSettingsTab);

        }

        function onSettingsFullScreenChanged() {
            root.isFullScreen = ShellState.settingsFullScreen;
        }

        function onSettingsScrollRequested(pos) {
            if (contentScroll && contentScroll.contentItem) {
                if (pos >= 0 && pos <= 1) {
                    var maxScroll = Math.max(0, contentScroll.contentHeight - contentScroll.height);
                    contentScroll.contentItem.contentY = pos * maxScroll;
                } else {
                    contentScroll.contentItem.contentY = pos;
                }
            }
        }

        target: ShellState
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: {
            if (root.isFullScreen) {
                root.toggleFullscreen();
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
        onActivated: root.toggleFullscreen()
    }

    Shortcut {
        sequence: "Meta+F"
        enabled: root.isOpen
        onActivated: root.toggleFullscreen()
    }

    Shortcut {
        sequence: "F11"
        enabled: root.isOpen
        onActivated: root.toggleFullscreen()
    }

    // Main window card
    Rectangle {
        id: windowCard

        width: root.isFullScreen ? root.maximizedW : root.windowedW
        height: root.isFullScreen ? root.maximizedH : root.windowedH
        x: root.isFullScreen ? root.maximizedX : root.clampedX
        y: root.isFullScreen ? root.maximizedY : root.clampedY
        radius: root.isFullScreen ? root.normalWindowRounding : Theme.notchRadiusWindow
        color: Theme.windowFill
        border.color: Theme.windowBorder
        border.width: 1
        clip: true
        opacity: root.isOpen ? 1 : 0

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

                    property point pressPosRoot: Qt.point(0, 0)
                    property real startCardX: 0
                    property real startCardY: 0

                    anchors.fill: parent
                    cursorShape: root.isFullScreen ? Qt.ArrowCursor : (pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor)
                    onPressed: (mouse) => {
                        if (!root.isFullScreen) {
                            var p = mapToItem(null, mouse.x, mouse.y);
                            pressPosRoot = p;
                            startCardX = (root.customX >= 0) ? root.customX : root.defaultX;
                            startCardY = (root.customY >= 0) ? root.customY : root.defaultY;
                            root.isDragging = true;
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed && !root.isFullScreen) {
                            var p = mapToItem(null, mouse.x, mouse.y);
                            var deltaX = p.x - pressPosRoot.x;
                            var deltaY = p.y - pressPosRoot.y;
                            var newX = startCardX + deltaX;
                            var newY = startCardY + deltaY;
                            var minX = 10;
                            var maxX = root.screenW - root.windowedW - 10;
                            var minY = 10;
                            var maxY = root.screenH - root.windowedH - 10;
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
                        root.toggleFullscreen();
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

                    Item {
                        Layout.fillWidth: true
                    }

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

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: root.isFullScreen ? "view-restore-symbolic" : "view-fullscreen-symbolic"
                                iconSize: 14
                                iconColor: (fsBtnMa.containsMouse || root.isFullScreen) ? Theme.notchText : Theme.notchTextSecondary

                                Behavior on iconColor {
                                    ColorAnimation {
                                        duration: Theme.motionFast
                                        easing.type: Theme.easingEnter
                                    }

                                }

                            }

                            MouseArea {
                                id: fsBtnMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleFullscreen()
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                    easing.type: Theme.easingEnter
                                }

                            }

                        }

                        // Close Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: closeBtnMa.pressed ? Theme.notchSurfaceActive : (closeBtnMa.containsMouse ? Theme.notchSurfaceHover : "transparent")

                            SymbolicIcon {
                                anchors.centerIn: parent
                                source: "window-close-symbolic"
                                iconSize: 14
                                iconColor: closeBtnMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary

                                Behavior on iconColor {
                                    ColorAnimation {
                                        duration: Theme.motionFast
                                        easing.type: Theme.easingEnter
                                    }

                                }

                            }

                            MouseArea {
                                id: closeBtnMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.close()
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionFast
                                    easing.type: Theme.easingEnter
                                }

                            }

                        }

                    }

                }

            }

            // ── Main Content Area: Sidebar + Floating Content Canvas ──────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.space4
                Layout.leftMargin: Theme.space8
                Layout.rightMargin: Theme.space8
                Layout.bottomMargin: Theme.space8
                spacing: Theme.space8

                // 1. Sidebar
                SettingsSidebar {
                    id: sidebar

                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.round(235 * Math.max(1.0, Theme.fontScale))
                    activeTab: root.activeTab
                    onTabSelected: (tabId) => {
                        return root.selectTab(tabId);
                    }
                }

                // 2. Tab Content Pane - Floating Glass Canvas
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.notchRadiusPanel
                    color: Theme.windowCardFill
                    border.color: Theme.windowCardBorder
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        LayoutMirroring.enabled: I18n.isRTL
                        LayoutMirroring.childrenInherit: true

                        // Page Header (Title + Description, with elegant breathing room)
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: headerCol.implicitHeight + Theme.space24 + Theme.space16
                            Layout.preferredHeight: implicitHeight

                            ColumnLayout {
                                id: headerCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: Theme.space24
                                anchors.leftMargin: Theme.space24
                                anchors.rightMargin: Theme.space24
                                spacing: Theme.space6
                                LayoutMirroring.enabled: I18n.isRTL
                                LayoutMirroring.childrenInherit: true

                                Text {
                                    text: I18n.tr("settings_page_" + root.activeTab)
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(20)
                                    font.weight: Font.Bold
                                    color: Theme.notchText
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                }

                                Text {
                                    // no Wi-Fi adapter: the page is about the wired link only

                                    text: I18n.tr("settings_page_" + root.activeTab + "_desc" + (root.activeTab === "network" && !NetworkService.wifiAvailable ? "_wired" : ""))
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

                            Item {
                                id: contentContainer

                                property Item currentItem: null

                                width: contentScroll.availableWidth
                                implicitHeight: currentItem ? (currentItem.implicitHeight > 0 ? currentItem.implicitHeight : currentItem.height) : 340
                                height: implicitHeight

                                Repeater {
                                    model: root.tabList

                                    delegate: Loader {
                                        id: tabLoader

                                        required property var modelData
                                        readonly property bool isCurrent: root.activeTab === modelData.id
                                        readonly property bool wasVisited: !!root.visitedTabs[modelData.id]

                                        function updateCurrent() {
                                            if (isCurrent && item)
                                                contentContainer.currentItem = item;

                                        }

                                        width: parent ? parent.width : 0
                                        height: item ? item.implicitHeight : implicitHeight
                                        anchors.top: parent ? parent.top : undefined
                                        anchors.left: parent ? parent.left : undefined
                                        anchors.right: parent ? parent.right : undefined
                                        visible: isCurrent
                                        active: wasVisited
                                        onIsCurrentChanged: updateCurrent()
                                        onItemChanged: updateCurrent()
                                        Component.onCompleted: updateCurrent()
                                        // Pages are lazy: loaded on first visit, then kept alive.
                                        source: "tabs/" + modelData.file
                                    }

                                }

                            }

                            ScrollBar.vertical: ScrollBar {
                                id: vBar

                                // Placed explicitly: a replaced ScrollBar gets no position
                                // from the style; `mirrored` follows the inherited RTL.
                                parent: contentScroll
                                x: contentScroll.mirrored ? 0 : contentScroll.width - width
                                y: contentScroll.topPadding
                                height: contentScroll.availableHeight
                                policy: contentScroll.contentHeight > contentScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                width: 6

                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: vBar.pressed ? Theme.notchText : (vBar.hovered ? Theme.notchBorderHighlight : Theme.notchBorder)
                                    opacity: (vBar.active || vBar.hovered) ? 0.8 : 0.4

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.motionFast
                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.motionFast
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

        }



        Behavior on color {
            ColorAnimation {
                duration: Theme.motionThemeFade
                easing.type: Theme.easingTheme
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.motionThemeFade
                easing.type: Theme.easingTheme
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Theme.easingEnter
            }
        }

        transform: Scale {
            origin.x: windowCard.width / 2
            origin.y: windowCard.height / 2
            xScale: root.isFullScreen ? 1 : (root.isOpen ? 1 : 0.96)
            yScale: root.isFullScreen ? 1 : (root.isOpen ? 1 : 0.96)

            Behavior on xScale {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Theme.easingEnter
                }

            }

            Behavior on yScale {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Theme.easingEnter
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

        Behavior on width {
            enabled: !root.isDragging
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

        Behavior on height {
            enabled: !root.isDragging
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

        Behavior on x {
            enabled: !root.isDragging

            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

        Behavior on y {
            enabled: !root.isDragging

            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Theme.easingEnter
            }

        }

    }

    mask: Region {
        item: root.isOpen ? windowCard : null
    }

}
