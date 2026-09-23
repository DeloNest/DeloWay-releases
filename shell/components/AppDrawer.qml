import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "./launcher"

// AppDrawer — Start-menu style launcher (toggled by the Super key).
//
//   ┌──────────────────────────────────────────────┐
//   │  (🔍  Search apps, settings and actions… )    │  integrated search pill
//   │  Pinned                                  12   │  = Dock pins (ApplicationManager)
//   │  ▦ ▦ ▦ ▦ ▦ ▦                                   │  6-column grid, ≤3 rows then scroll
//   │  ─────────────────────────────────────────── │
//   │  All apps                               143   │
//   │  ▣ Internet · · · 5  ›                        │  collapsible category folders
//   │  ▣ Media    · · · 9  ⌄                        │  (or A–Z with letter headers)
//   │     ▸ Spotify                                 │
//   │  ─────────────────────────────────────────── │
//   │  (W) waleed                       ⚙    ⏻      │  footer
//   └──────────────────────────────────────────────┘
//
// Typing switches to universal search (apps · settings · actions · calculator) via
// LauncherIndex. Floating card anchored bottom-centre above the Dock area, opens with a
// short rise + fade. Right-click any app: the shared AppContextMenu (same as the Dock).
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "deloway:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.appDrawerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool isOpen: ShellState.appDrawerOpen
    visible: isOpen || panel.opacity > 0.005

    // ── Geometry ─────────────────────────────────────────────────────────
    // Sits above a bottom Dock the way a Start menu sits above the taskbar.
    readonly property bool dockAtBottom: ConfigManager.dockMode === "always" && ConfigManager.dockPosition === "bottom"
    readonly property int bottomGap: dockAtBottom ? Theme.dockReserved : Theme.space16
    readonly property int panelWidth: Math.min(660, root.width - 32)
    readonly property int panelHeight: Math.min(740, root.height - Theme.topBarReserved - bottomGap - 24)
    readonly property int gridColumns: 6
    readonly property int tileHeight: 90
    readonly property int rowHeight: 40

    // ── Data ─────────────────────────────────────────────────────────────
    property string filterQuery: ""
    readonly property bool searching: filterQuery.trim().length > 0
    readonly property var searchResults: searching ? LauncherIndex.search(filterQuery) : []

    readonly property var pinnedApps: {
        const out = [];
        for (const id of ApplicationManager.pinnedAppIds) {
            const app = ApplicationManager.findApp(id);
            if (app) out.push(app);
        }
        return out;
    }

    readonly property var sortedApps: {
        const locale = I18n.isRTL ? "ar" : "en";
        return LauncherIndex.allApps.slice().sort((a, b) =>
            (a.name || "").localeCompare(b.name || "", locale, { sensitivity: "base" }));
    }

    function letterOf(name) {
        const c = (name || "").trim().charAt(0);
        if (!c) return "#";
        if (/[0-9]/.test(c)) return "#";
        // Alef variants (أ إ آ ٱ) group under one Arabic header, like a dictionary.
        if (/[\u0622\u0623\u0625\u0671]/.test(c)) return "\u0627";
        return c.toUpperCase();
    }

    // ── All-apps rows ────────────────────────────────────────────────────
    // Folders (default): one collapsible folder per freedesktop category
    //   (LauncherIndex.categoryOf), in LauncherIndex.categoryDefs order, empty ones hidden.
    // A–Z: the classic alphabetical list with letter headers.
    // Every row has a stable `key` so the ScriptModel below diffs instead of resetting:
    // expanding/collapsing animates in place and never jumps the scroll position.
    readonly property bool byCategory: ConfigManager.drawerGroupBy !== "alpha"
    property var expandedCats: ({})          // session memory of open folders

    readonly property var categoryGroups: {
        const buckets = {};
        for (const app of root.sortedApps) {
            const c = LauncherIndex.categoryOf(app);
            (buckets[c] = buckets[c] || []).push(app);
        }
        return LauncherIndex.categoryDefs
            .filter(d => buckets[d.id] && buckets[d.id].length > 0)
            .map(d => ({ id: d.id, icon: d.icon, apps: buckets[d.id] }));
    }
    readonly property var groupById: {
        const m = {};
        for (const g of root.categoryGroups) m[g.id] = g;
        return m;
    }
    function toggleFolder(cat, open) {
        const m = Object.assign({}, root.expandedCats);
        const next = open === undefined ? !m[cat] : open;
        if (next) m[cat] = true; else delete m[cat];
        root.expandedCats = m;
    }

    readonly property var listRows: {
        const rows = [];
        if (root.byCategory) {
            for (const g of root.categoryGroups) {
                rows.push({ key: "f:" + g.id, kind: "folder", cat: g.id });
                if (root.expandedCats[g.id])
                    for (const app of g.apps) rows.push({ key: "a:" + g.id + ":" + app.id, kind: "app", app: app, nested: true });
            }
        } else {
            let last = "";
            for (const app of root.sortedApps) {
                const L = root.letterOf(app.name);
                if (L !== last) { rows.push({ key: "h:" + L, kind: "header", letter: L }); last = L; }
                rows.push({ key: "a:" + app.id, kind: "app", app: app, nested: false });
            }
        }
        return rows;
    }
    ScriptModel {
        id: listModel
        values: root.listRows
        objectProp: "key"
    }
    // Rows the keyboard cursor can land on (apps and folders; letter headers are skipped).
    readonly property var selectableIndexes: {
        const idx = [];
        for (let i = 0; i < root.listRows.length; i++)
            if (root.listRows[i].kind !== "header") idx.push(i);
        return idx;
    }
    readonly property var cursorRow: (!root.searching && root.cursor >= root.pinnedApps.length)
        ? (root.listRows[root.selectableIndexes[root.cursor - root.pinnedApps.length]] || null) : null

    // ── Keyboard selection ───────────────────────────────────────────────
    // Browse mode: one cursor over [pinned…, all apps…]. Search mode: over results.
    property int cursor: -1
    readonly property int browseCount: pinnedApps.length + selectableIndexes.length

    function resetCursor() { root.cursor = root.searching ? (searchResults.length > 0 ? 0 : -1) : -1; }
    function moveCursor(delta) {
        const n = root.searching ? searchResults.length : browseCount;
        if (n === 0) return;
        root.cursor = root.cursor < 0 ? (delta > 0 ? 0 : n - 1) : Math.max(0, Math.min(n - 1, root.cursor + delta));
        root.revealCursor();
    }
    function moveVertical(dir) {
        if (root.searching) { moveCursor(dir); return; }
        const p = root.pinnedApps.length;
        if (root.cursor >= 0 && root.cursor < p) {
            const next = root.cursor + dir * root.gridColumns;
            root.cursor = next < 0 ? root.cursor : (next >= p ? p : next);   // fall through into the list
            root.revealCursor();
        } else {
            moveCursor(dir);
        }
    }
    function revealCursor() {
        if (root.searching) { searchList.positionViewAtIndex(root.cursor, ListView.Contain); return; }
        const p = root.pinnedApps.length;
        if (root.cursor >= 0 && root.cursor < p) pinnedGrid.positionViewAtIndex(root.cursor, GridView.Contain);
        else if (root.cursor >= p) appList.positionViewAtIndex(root.selectableIndexes[root.cursor - p], ListView.Contain);
    }
    function activateCursor() {
        if (root.searching) {
            if (root.cursor >= 0 && root.cursor < searchResults.length) root.executeResult(searchResults[root.cursor]);
            else if (searchResults.length > 0) root.executeResult(searchResults[0]);
            return;
        }
        const p = root.pinnedApps.length;
        if (root.cursor >= 0 && root.cursor < p) root.launchApp(root.pinnedApps[root.cursor]);
        else if (root.cursor >= p) {
            const row = root.listRows[root.selectableIndexes[root.cursor - p]];
            if (!row) return;
            if (row.kind === "folder") root.toggleFolder(row.cat);
            else root.launchApp(row.app);
        }
    }

    // Shared app menu (same component as the Dock), opened at the pointer.
    AppContextMenu {
        id: contextMenu
        hostWindow: root
        onActionTriggered: (action) => {
            // Anything that brings a window or Settings forward also dismisses the menu's host.
            if (["open", "new", "window", "info", "max", "min"].indexOf(action) >= 0)
                ShellState.closeAppDrawer();
        }
    }
    function openMenu(app, area, mouse) {
        const p = area.mapToItem(root.contentItem, mouse.x, mouse.y);
        contextMenu.openAt(app, p.x, p.y);
    }

    // ── Actions ──────────────────────────────────────────────────────────
    function launchApp(app) {
        if (!app) return;
        contextMenu.hide();
        ShellState.closeAppDrawer();
        if (app.id) LauncherIndex.recordLaunch(app.id);
        if (typeof app.execute === "function") app.execute();
        else ApplicationManager.launchApp(app);
    }

    function executeResult(item) {
        if (!item) return;
        contextMenu.hide();
        if (item.type === "app") { root.launchApp(item.data); return; }
        ShellState.closeAppDrawer();
        if (item.type === "calc") {
            if (item.data && item.data.value !== undefined) Quickshell.execDetached(["wl-copy", String(item.data.value)]);
        } else if (item.type === "setting") {
            if (item.id === "settings-main") ShellState.toggleSettingsApp();
            else ShellState.openSettingsTab(item.id);
        } else if (item.type === "action") {
            if (item.id === "lock") ShellState.lock();
            else if (item.id === "logout") Hyprland.dispatch("exit");
            else if (item.id === "restart") Quickshell.execDetached(["systemctl", "reboot"]);
            else if (item.id === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    function isRunning(app) {
        return !!app && !!app.id && ApplicationManager.getWindowsForApp(app.id).length > 0;
    }

    // ── Open / close lifecycle ───────────────────────────────────────────
    Connections {
        target: ShellState
        function onAppDrawerOpenChanged() {
            contextMenu.hide();
            if (ShellState.appDrawerOpen) {
                searchInput.text = ShellState.searchQuery || "";
                root.filterQuery = searchInput.text;
                root.resetCursor();
                pinnedGrid.positionViewAtBeginning();
                appList.positionViewAtBeginning();
                searchInput.forceActiveFocus();
            }
        }
        function onSearchQueryChanged() {
            if (ShellState.appDrawerOpen && ShellState.searchQuery !== "") {
                searchInput.text = ShellState.searchQuery;
                root.filterQuery = ShellState.searchQuery;
                root.resetCursor();
            }
        }
    }

    Timer {
        id: searchDebounce
        interval: 40
        onTriggered: { root.filterQuery = searchInput.text; root.resetCursor(); }
    }

    // Click outside → close (no dimming scrim: the desktop stays visible)
    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        onClicked: ShellState.closeAppDrawer()
    }

    // ═════════════════════════════════════════════════════════════════════
    // PANEL
    // ═════════════════════════════════════════════════════════════════════
    Item {
        id: panel
        width: root.panelWidth
        height: root.panelHeight
        x: Math.round((root.width - width) / 2)
        y: root.height - height - root.bottomGap

        // Snappy rise + fade (Start-menu style); faster on close.
        opacity: root.isOpen ? 1 : 0
        transform: Translate {
            y: root.isOpen ? 0 : 18
            Behavior on y { NumberAnimation { duration: root.isOpen ? 180 : 110; easing.type: root.isOpen ? Easing.OutCubic : Easing.InCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: root.isOpen ? 140 : 100; easing.type: root.isOpen ? Easing.OutCubic : Easing.InCubic } }

        // Swallow clicks on the panel so they don't reach the dismiss area
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: contextMenu.hide() }

        // Soft shadow
        Rectangle {
            anchors.fill: card
            anchors.topMargin: 6
            anchors.bottomMargin: -6
            radius: card.radius
            color: Theme.notchShadow
            visible: Theme.enableShadows
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.notchRadiusWindow
            color: Theme.notchBackground
            border.color: Theme.notchBorder
            border.width: 1

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space20
                spacing: Theme.space12

                // ── Search pill ──────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 22
                    color: Theme.notchSurface
                    border.color: searchInput.activeFocus ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 10
                        spacing: 10

                        SymbolicIcon {
                            Layout.alignment: Qt.AlignVCenter
                            iconSize: 16
                            source: "system-search-symbolic"
                            iconColor: Theme.notchTextSecondary
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            clip: true
                            horizontalAlignment: I18n.isRTL ? TextInput.AlignRight : TextInput.AlignLeft
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            color: Theme.notchText
                            selectionColor: Theme.notchSurfaceActive
                            selectedTextColor: Theme.notchText
                            onTextChanged: searchDebounce.restart()

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: parent.horizontalAlignment
                                visible: searchInput.text.length === 0
                                text: I18n.isRTL ? "ابحث عن تطبيق أو إعداد أو إجراء…" : "Search apps, settings and actions…"
                                font: searchInput.font
                                color: Theme.notchTextTertiary
                            }

                            Keys.onEscapePressed: {
                                if (contextMenu.visible) contextMenu.hide();
                                else ShellState.closeAppDrawer();
                            }
                            Keys.onReturnPressed: root.activateCursor()
                            Keys.onEnterPressed: root.activateCursor()
                            Keys.onDownPressed: root.moveVertical(1)
                            Keys.onUpPressed: root.moveVertical(-1)
                            Keys.onTabPressed: root.moveCursor(1)
                            Keys.onBacktabPressed: root.moveCursor(-1)
                            // Left/Right move within the pinned grid when not editing text
                            // …or open/close the folder under the cursor ("forward" opens; RTL-aware)
                            Keys.onLeftPressed: (e) => {
                                if (!root.searching && root.cursor >= 0 && root.cursor < root.pinnedApps.length) root.moveCursor(I18n.isRTL ? 1 : -1);
                                else if (root.cursorRow && root.cursorRow.kind === "folder") root.toggleFolder(root.cursorRow.cat, I18n.isRTL);
                                else e.accepted = false;
                            }
                            Keys.onRightPressed: (e) => {
                                if (!root.searching && root.cursor >= 0 && root.cursor < root.pinnedApps.length) root.moveCursor(I18n.isRTL ? -1 : 1);
                                else if (root.cursorRow && root.cursorRow.kind === "folder") root.toggleFolder(root.cursorRow.cat, !I18n.isRTL);
                                else e.accepted = false;
                            }
                        }

                        // Clear
                        Rectangle {
                            visible: searchInput.text.length > 0
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: clearMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                            SymbolicIcon {
                                anchors.centerIn: parent
                                iconSize: 12
                                source: "window-close-symbolic"
                                iconColor: Theme.notchTextSecondary
                            }
                            MouseArea {
                                id: clearMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                            }
                        }
                    }
                }

                // ── Content: browse ⇄ search (cross-fade, no relayout) ───
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // ===== BROWSE =====
                    ColumnLayout {
                        id: browseView
                        anchors.fill: parent
                        spacing: Theme.space8
                        opacity: root.searching ? 0 : 1
                        visible: opacity > 0.01
                        enabled: !root.searching
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                        SectionLabel {
                            Layout.fillWidth: true
                            text: I18n.tr("pinned")
                            count: root.pinnedApps.length
                        }

                        GridView {
                            id: pinnedGrid
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.pinnedApps.length === 0
                                ? 64
                                : Math.min(3, Math.ceil(root.pinnedApps.length / root.gridColumns)) * root.tileHeight
                            clip: true
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            cellWidth: Math.floor(width / root.gridColumns)
                            cellHeight: root.tileHeight
                            model: root.pinnedApps
                            // Direction comes from the card's inherited LayoutMirroring
                            // (setting layoutDirection too would flip it back).

                            delegate: PinnedTile {
                                required property var modelData
                                required property int index
                                width: pinnedGrid.cellWidth
                                height: pinnedGrid.cellHeight
                                app: modelData
                                selected: !root.searching && root.cursor === index
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.pinnedApps.length === 0
                                width: parent.width - 40
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: I18n.isRTL ? "لا توجد تطبيقات مثبتة. انقر بالزر الأيمن على أي تطبيق ثم «تثبيت في الشريط»."
                                                 : "No pinned apps. Right-click any app and choose “Pin to Dock”."
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(12)
                                color: Theme.notchTextTertiary
                                renderType: Theme.renderType
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.space4
                            Layout.bottomMargin: Theme.space4
                            implicitHeight: 1
                            color: Theme.notchBorderSubtle
                        }

                        // "All apps" + Folders / A–Z switch
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space8
                            SectionLabel {
                                Layout.fillWidth: true
                                text: I18n.tr("all_apps")
                                count: root.sortedApps.length
                            }
                            ViewSwitch { Layout.alignment: Qt.AlignVCenter }
                        }

                        ListView {
                            id: appList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: listModel
                            cacheBuffer: 400
                            ScrollBar.vertical: ScrollBar {
                                policy: appList.contentHeight > appList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                width: 4
                                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.notchBorderHighlight }
                            }

                            // Folder contents fade in; everything below glides down/up.
                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
                            }
                            remove: Transition {
                                NumberAnimation { property: "opacity"; to: 0; duration: 110; easing.type: Easing.InCubic }
                            }
                            displaced: Transition {
                                NumberAnimation { property: "y"; duration: 190; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "opacity"; to: 1; duration: 120 }
                            }

                            delegate: Item {
                                id: rowItem
                                required property var modelData
                                required property int index
                                readonly property string kind: modelData.kind
                                readonly property bool isSelected: !root.searching && root.cursor >= root.pinnedApps.length
                                    && root.selectableIndexes[root.cursor - root.pinnedApps.length] === rowItem.index
                                width: appList.width - 8
                                height: kind === "header" ? 30 : (kind === "folder" ? 46 : root.rowHeight)

                                // Letter header (A–Z view)
                                Text {
                                    visible: rowItem.kind === "header"
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    text: rowItem.modelData.letter || ""
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(12)
                                    font.weight: Font.Bold
                                    color: Theme.notchTextTertiary
                                    renderType: Theme.renderType
                                }

                                // Folder (Folders view)
                                FolderRow {
                                    visible: rowItem.kind === "folder"
                                    anchors.fill: parent
                                    anchors.topMargin: 2
                                    anchors.bottomMargin: 2
                                    group: rowItem.kind === "folder" ? (root.groupById[rowItem.modelData.cat] || null) : null
                                    expanded: rowItem.kind === "folder" && !!root.expandedCats[rowItem.modelData.cat]
                                    selected: rowItem.isSelected
                                }

                                // Guide line for apps inside an open folder
                                Rectangle {
                                    visible: rowItem.kind === "app" && !!rowItem.modelData.nested
                                    anchors.left: parent.left
                                    anchors.leftMargin: 25
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    color: Theme.notchBorderSubtle
                                }

                                AppRow {
                                    visible: rowItem.kind === "app"
                                    anchors.fill: parent
                                    anchors.leftMargin: rowItem.modelData.nested ? 36 : 0
                                    app: rowItem.kind === "app" ? rowItem.modelData.app : null
                                    selected: rowItem.isSelected
                                }
                            }
                        }
                    }

                    // ===== SEARCH =====
                    ColumnLayout {
                        id: searchView
                        anchors.fill: parent
                        spacing: Theme.space8
                        opacity: root.searching ? 1 : 0
                        visible: opacity > 0.01
                        enabled: root.searching
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                        SectionLabel {
                            Layout.fillWidth: true
                            text: I18n.isRTL ? "النتائج" : "Results"
                            count: root.searchResults.length
                        }

                        ListView {
                            id: searchList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.searchResults

                            delegate: ResultRow {
                                required property var modelData
                                required property int index
                                width: searchList.width
                                resultData: modelData
                                isSelected: root.cursor === index
                                isHovered: resultMa.containsMouse
                                MouseArea {
                                    id: resultMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (m) => {
                                        if (m.button === Qt.RightButton && modelData.type === "app")
                                            root.openMenu(modelData.data, resultMa, m);
                                        else root.executeResult(modelData);
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: root.searching && root.searchResults.length === 0
                                SymbolicIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    iconSize: 28
                                    source: "system-search-symbolic"
                                    iconColor: Theme.notchTextTertiary
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: I18n.isRTL ? "لا توجد نتائج" : "No results"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    color: Theme.notchTextSecondary
                                    renderType: Theme.renderType
                                }
                            }
                        }
                    }
                }

                // ── Footer ───────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.notchBorderSubtle
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        color: Theme.qsTileActive
                        Text {
                            anchors.centerIn: parent
                            text: (ControlCenterService.userName.charAt(0) || "?").toUpperCase()
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(14)
                            font.weight: Font.Bold
                            color: Theme.qsTileIconActive
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: ControlCenterService.userName
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.weight: Font.DemiBold
                        color: Theme.notchText
                        renderType: Theme.renderType
                    }
                    FooterButton {
                        iconName: "emblem-system-symbolic"
                        onClicked: { ShellState.closeAppDrawer(); ShellState.openSettingsApp(); }
                    }
                    FooterButton {
                        iconName: "system-shutdown-symbolic"
                        onClicked: { ShellState.closeAppDrawer(); ShellState.openQuickSettingsCapsule("power"); }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // Components
    // ═════════════════════════════════════════════════════════════════════
    // Collapsible folder row: [glyph] Name ··· [icon peek] count ›
    component FolderRow: Rectangle {
        id: fr
        property var group: null
        property bool expanded: false
        property bool selected: false

        radius: Theme.notchRadiusCard
        color: fr.selected ? Theme.notchSurfaceActive : (frMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
        border.color: fr.selected ? Theme.notchBorderHighlight : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 12

            // Folder glyph on a small tonal tile
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                radius: Theme.radiusSmall
                color: fr.expanded ? Theme.notchSurfaceActive : Theme.notchSurface
                border.color: Theme.notchBorderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                SymbolicIcon {
                    anchors.centerIn: parent
                    iconSize: 15
                    source: fr.group ? fr.group.icon : "folder-symbolic"
                    iconColor: fr.expanded || frMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: fr.group ? I18n.tr("drawer_cat_" + fr.group.id) : ""
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
                color: Theme.notchText
                renderType: Theme.renderType
            }

            // Peek at the first apps while collapsed (fades out when open)
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: -5
                opacity: fr.expanded ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Repeater {
                    model: fr.group ? fr.group.apps.slice(0, 3) : []
                    delegate: Rectangle {
                        required property var modelData
                        width: 22
                        height: 22
                        radius: 7
                        color: Theme.notchBackground
                        AppIcon {
                            anchors.centerIn: parent
                            iconSize: 18
                            source: parent.modelData ? parent.modelData.icon : ""
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: fr.group ? String(fr.group.apps.length) : ""
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchTextTertiary
                renderType: Theme.renderType
            }

            // Chevron: points "forward" (reading direction) when closed, down when open
            SymbolicIcon {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 12
                source: I18n.isRTL ? "pan-start-symbolic" : "pan-end-symbolic"
                iconColor: Theme.notchTextSecondary
                rotation: fr.expanded ? (I18n.isRTL ? -90 : 90) : 0
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: frMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { contextMenu.hide(); if (fr.group) root.toggleFolder(fr.group.id); }
        }
    }

    // Folders / A–Z segmented switch (persists in ConfigManager.drawerGroupBy)
    component ViewSwitch: Rectangle {
        id: vs
        implicitHeight: 26
        implicitWidth: vsRow.implicitWidth + 4
        radius: 13
        color: Theme.notchSurface
        border.color: Theme.notchBorderSubtle
        border.width: 1

        Row {
            id: vsRow
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: [
                    { id: "category", icon: "folder-symbolic",   label: I18n.tr("drawer_view_folders") },
                    { id: "alpha",    icon: "view-list-symbolic", label: I18n.tr("drawer_view_az") }
                ]
                delegate: Rectangle {
                    id: seg
                    required property var modelData
                    readonly property bool on: (ConfigManager.drawerGroupBy || "category") === modelData.id
                    height: 22
                    width: segRow.implicitWidth + 18
                    radius: 11
                    color: seg.on ? Theme.notchSurfaceActive : (segMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Row {
                        id: segRow
                        anchors.centerIn: parent
                        spacing: 5
                        SymbolicIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconSize: 11
                            source: seg.modelData.icon
                            iconColor: seg.on ? Theme.notchText : Theme.notchTextSecondary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: seg.modelData.label
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: seg.on ? Font.DemiBold : Font.Normal
                            color: seg.on ? Theme.notchText : Theme.notchTextSecondary
                            renderType: Theme.renderType
                        }
                    }
                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenu.hide();
                            ConfigManager.setDrawerGroupBy(seg.modelData.id);
                            root.resetCursor();
                            appList.positionViewAtBeginning();
                        }
                    }
                }
            }
        }
    }

    component PinnedTile: Item {
        id: tile
        property var app: null
        property bool selected: false

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Theme.notchRadiusCard
            color: tile.selected ? Theme.notchSurfaceActive : (tileMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
            border.color: tile.selected ? Theme.notchBorderHighlight : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6
            width: parent.width - 12

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 40; height: 40
                scale: tileMa.pressed ? 0.92 : 1
                Behavior on scale { NumberAnimation { duration: Theme.motionFast } }
                AppIcon { anchors.fill: parent; iconSize: 40; source: tile.app ? tile.app.icon : "" }
                Rectangle {
                    visible: root.isRunning(tile.app)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 1
                    width: 4; height: 4; radius: 2
                    color: Theme.dockDot
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.app ? (tile.app.name || "") : ""
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                color: Theme.notchText
                renderType: Theme.renderType
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                if (m.button === Qt.RightButton) root.openMenu(tile.app, tileMa, m);
                else root.launchApp(tile.app);
            }
        }
    }

    component AppRow: Rectangle {
        id: row
        property var app: null
        property bool selected: false

        radius: Theme.notchRadiusCard
        color: row.selected ? Theme.notchSurfaceActive : (rowMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
        border.color: row.selected ? Theme.notchBorderHighlight : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            AppIcon {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 26
                source: row.app ? row.app.icon : ""
            }
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: row.app ? (row.app.name || "") : ""
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(13)
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                color: Theme.notchText
                renderType: Theme.renderType
            }
            Rectangle {
                visible: root.isRunning(row.app)
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 5; implicitHeight: 5; radius: 2.5
                color: Theme.dockDot
            }
            SymbolicIcon {
                visible: row.app ? ApplicationManager.isPinned(row.app.id) : false
                Layout.alignment: Qt.AlignVCenter
                iconSize: 12
                source: "view-pin-symbolic"
                iconColor: Theme.notchTextTertiary
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                if (m.button === Qt.RightButton) root.openMenu(row.app, rowMa, m);
                else root.launchApp(row.app);
            }
        }
    }

    component FooterButton: Rectangle {
        id: fb
        property string iconName: ""
        signal clicked()
        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: fbMa.pressed ? Theme.notchSurfaceActive : (fbMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        SymbolicIcon {
            anchors.centerIn: parent
            iconSize: 15
            source: fb.iconName
            iconColor: fbMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
        }
        MouseArea {
            id: fbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }
}
