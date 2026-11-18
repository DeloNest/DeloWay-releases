import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../services"

// DeloWay Clipboard Manager (Super + V):
// High-productivity dual-pane desktop clipboard hub with:
// - Left pane: item list with quick numbers (1..9), category icons, thumbnails, and pin badges.
// - Right pane: rich live inspector with multiline full-text preview, high-res images,
//   direct browser link launcher, and color HEX/RGB swatches.
// - Filter tabs: All, Pinned ★, Text, Images, Links, Colors.
// - Persistent pinned clips that survive history wipes.
// - Strict OLED monochrome compliance and full RTL / Arabic typography.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.clipboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: ShellState.clipboardOpen || card.opacity > 0.005
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────
    property string searchQuery: ""
    property string activeFilter: "all"  // "all" | "pinned" | "text" | "image" | "link" | "color"
    property int selectedIndex: 0
    property bool confirmingClear: false

    // Arabic and English text normalization (hamza forms, taa marbuta, harakat)
    function normalizeText(text) {
        if (!text) return "";
        return text.toString().toLowerCase()
            .replace(/[\u064B-\u065F\u0670]/g, "")
            .replace(/[أإآٱ]/g, "ا")
            .replace(/ة/g, "ه")
            .replace(/ى/g, "ي");
    }

    function kindLabel(kind) {
        return I18n.tr("clip_" + (kind === "image" || kind === "link" || kind === "color" || kind === "path"
                                  || kind === "binary" ? kind : "text"));
    }

    function searchText(item) {
        if (!item) return "";
        return item.kind === "image"
               ? [I18n.tr("clip_image"), "image", item.format].join(" ")
               : (item.text || "");
    }

    function itemMatchesFilter(item, filter) {
        if (!item) return false;
        if (filter === "all") return true;
        if (filter === "pinned") return ClipboardService.isPinned(item);
        if (filter === "text") return item.kind === "text" || item.kind === "path";
        if (filter === "image") return item.kind === "image";
        if (filter === "link") return item.kind === "link";
        if (filter === "color") return item.kind === "color";
        return true;
    }

    readonly property var baseList: {
        const history = ClipboardService.items || [];
        const pinned = ClipboardService.pinnedItems || [];
        if (root.activeFilter === "pinned") {
            return pinned;
        }
        const historyIds = {};
        const historyTexts = {};
        for (let i = 0; i < history.length; ++i) {
            const h = history[i];
            if (h.id) historyIds[h.id] = true;
            if (h.text) historyTexts[h.text] = true;
        }
        const missingPinned = [];
        for (let j = 0; j < pinned.length; ++j) {
            const p = pinned[j];
            if (p.kind === "image") {
                if (!historyIds[p.id]) missingPinned.push(p);
            } else {
                if (!historyTexts[p.text]) missingPinned.push(p);
            }
        }
        return missingPinned.concat(history);
    }

    readonly property var filteredItems: {
        const list = root.baseList;
        const f = root.activeFilter;
        const q = root.normalizeText(root.searchQuery.trim());
        return list.filter(item => {
            if (!root.itemMatchesFilter(item, f)) return false;
            if (!q) return true;
            return root.normalizeText(root.searchText(item)).includes(q);
        });
    }

    readonly property var selectedItem: filteredItems.length > 0
                                        ? filteredItems[Math.max(0, Math.min(selectedIndex, filteredItems.length - 1))]
                                        : null

    onSelectedItemChanged: {
        if (root.selectedItem) {
            ClipboardService.decodeFullText(root.selectedItem);
        }
    }

    function imageSize(item) {
        if (!item) return "";
        const m = /^([\d.]+) (B|KiB|MiB|GiB)$/.exec(item.size || "");
        if (!m) return item.size || "";
        const mult = { "B": 1, "KiB": 1024, "MiB": 1048576, "GiB": 1073741824 }[m[2]];
        return I18n.fileSize(Number(m[1]) * mult);
    }

    function imageMeta(item) {
        if (!item) return "";
        return I18n.ltr(I18n.number(item.width + "×" + item.height)) + "  ·  " + root.imageSize(item);
    }

    function textMeta(item) {
        if (!item) return "";
        const label = root.kindLabel(item.kind);
        return item.kind === "text" ? label + "  ·  " + I18n.charsCount((item.text || "").length) : label;
    }

    function textStats(str) {
        if (!str) return { chars: 0, words: 0, lines: 1 };
        const chars = str.length;
        const words = (str.trim().match(/\S+/g) || []).length;
        const lines = str.split("\n").length;
        return { chars: chars, words: words, lines: lines };
    }

    function moveSelection(step) {
        const n = root.filteredItems.length;
        if (n === 0) return;
        root.selectedIndex = (root.selectedIndex + step + n) % n;
        list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function cycleFilter(step) {
        const ids = ["all", "pinned", "text", "image", "link", "color"];
        const curIdx = ids.indexOf(root.activeFilter);
        const nextIdx = (curIdx + step + ids.length) % ids.length;
        root.activeFilter = ids[nextIdx];
        ShellState.clipboardFilter = ids[nextIdx];
        root.selectedIndex = 0;
        list.positionViewAtBeginning();
    }

    function paste(item) {
        if (!item) return;
        ShellState.closeClipboard();
        ClipboardService.pasteItem(item);
    }

    function copyOnly(item) {
        if (!item) return;
        ShellState.closeClipboard();
        ClipboardService.copyItem(item);
    }

    function remove(item) {
        if (!item) return;
        ClipboardService.deleteItem(item);
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.filteredItems.length - 2));
    }

    function togglePin(item) {
        if (!item) return;
        ClipboardService.togglePin(item);
    }

    Connections {
        target: ShellState
        function onClipboardOpenChanged() {
            if (ShellState.clipboardOpen) {
                ClipboardService.refresh();
                searchInput.text = ShellState.clipboardQuery || "";
                root.searchQuery = searchInput.text;
                root.activeFilter = ShellState.clipboardFilter || "all";
                root.selectedIndex = 0;
                root.confirmingClear = false;
                focusTimer.restart();
            }
        }
        function onClipboardFilterChanged() {
            root.activeFilter = ShellState.clipboardFilter || "all";
            root.selectedIndex = 0;
            list.positionViewAtBeginning();
        }
        function onClipboardQueryChanged() {
            searchInput.text = ShellState.clipboardQuery || "";
            root.searchQuery = searchInput.text;
            root.selectedIndex = 0;
            list.positionViewAtBeginning();
        }
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: clearConfirmTimer
        interval: 3000
        onTriggered: root.confirmingClear = false
    }

    // Click outside: close window
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeClipboard()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Floating Hub Card
    // ─────────────────────────────────────────────────────────────────────
    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.14)
        width: Math.min(800, root.width - 32)

        readonly property int headerHeight: Math.max(94, Math.round(94 * Math.max(1.0, Theme.fontScale)))
        readonly property int footerHeight: Math.max(34, Math.round(34 * Math.max(1.0, Theme.fontScale)))
        readonly property int maxBodyHeight: Math.max(260, Math.min(520, root.height - y - 36 - headerHeight - footerHeight))
        readonly property bool hasItems: root.filteredItems.length > 0
        readonly property int bodyHeight: hasItems ? maxBodyHeight : 140

        height: headerHeight + 1 + bodyHeight + 1 + footerHeight
        radius: Theme.notchRadiusWindow
        color: Theme.capsuleFill
        border.color: Theme.capsuleBorder
        border.width: 1
        clip: true

        Behavior on color { ColorAnimation { duration: Theme.motionThemeFade; easing.type: Theme.easingTheme } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionThemeFade; easing.type: Theme.easingTheme } }

        readonly property bool isOpen: ShellState.clipboardOpen
        opacity: isOpen ? 1.0 : 0.0
        scale: isOpen ? 1.0 : 0.97
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation { duration: card.isOpen ? 150 : 110; easing.type: card.isOpen ? Easing.OutCubic : Easing.InQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: card.isOpen ? 150 : 110; easing.type: card.isOpen ? Easing.OutCubic : Easing.InQuad }
        }
        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea { anchors.fill: parent }

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header Area (Search bar + Filter tabs) ───────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: card.headerHeight

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    // Search row
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(46, Math.round(46 * Math.max(1.0, Theme.fontScale)))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 14
                            spacing: 10

                            SymbolicIcon {
                                source: "edit-paste-symbolic"
                                iconSize: 18
                                iconColor: Theme.notchText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    horizontalAlignment: TextInput.AlignLeft
                                    color: Theme.notchText
                                    selectionColor: Theme.textSelection
                                    selectedTextColor: Theme.notchText
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.fontSize(15)
                                    renderType: Theme.renderType
                                    clip: true

                                    onTextChanged: {
                                        root.searchQuery = text;
                                        root.selectedIndex = 0;
                                        list.positionViewAtBeginning();
                                    }

                                    Keys.onEscapePressed: ShellState.closeClipboard()
                                    Keys.onTabPressed: event => {
                                        root.cycleFilter(1);
                                        event.accepted = true;
                                    }
                                    Keys.onBacktabPressed: event => {
                                        root.cycleFilter(-1);
                                        event.accepted = true;
                                    }
                                    Keys.onDownPressed: root.moveSelection(1)
                                    Keys.onUpPressed: root.moveSelection(-1)
                                    Keys.onReturnPressed: event => {
                                        if (event.modifiers & Qt.ShiftModifier) root.copyOnly(root.selectedItem);
                                        else root.paste(root.selectedItem);
                                    }
                                    Keys.onEnterPressed: root.paste(root.selectedItem)
                                    Keys.onPressed: event => {
                                        // Quick paste: Alt + 1..9 or 1..9 if search query is empty
                                        const keyNum = event.key - Qt.Key_1;
                                        if (keyNum >= 0 && keyNum <= 8) {
                                            if ((event.modifiers & Qt.AltModifier) || (searchInput.text.length === 0 && !(event.modifiers & Qt.ControlModifier))) {
                                                if (root.filteredItems.length > keyNum) {
                                                    root.paste(root.filteredItems[keyNum]);
                                                    event.accepted = true;
                                                    return;
                                                }
                                            }
                                        }

                                        // Ctrl+P toggles pin
                                        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                            root.togglePin(root.selectedItem);
                                            event.accepted = true;
                                            return;
                                        }

                                        // Ctrl+O opens link in browser
                                        if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
                                            if (root.selectedItem && root.selectedItem.kind === "link") {
                                                ClipboardService.openUrl(root.selectedItem.text);
                                                event.accepted = true;
                                                return;
                                            }
                                        }

                                        // Ctrl+C copies entry
                                        if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier) && searchInput.selectedText.length === 0) {
                                            root.copyOnly(root.selectedItem);
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Delete && searchInput.cursorPosition === searchInput.text.length) {
                                            root.remove(root.selectedItem);
                                            event.accepted = true;
                                        }
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignLeft
                                    visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                                    text: I18n.tr("clip_search")
                                    color: Theme.notchTextSecondary
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: Theme.fontSize(15)
                                    renderType: Theme.renderType
                                    elide: Text.ElideRight
                                }
                            }

                            // Clear query button
                            Rectangle {
                                visible: searchInput.text.length > 0
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: Theme.notchRadiusPill
                                color: queryClearMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    font.weight: Font.DemiBold
                                    color: Theme.notchTextSecondary
                                    renderType: Theme.renderType
                                }
                                MouseArea {
                                    id: queryClearMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = "";
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }

                            // Clear history button
                            Rectangle {
                                visible: (ClipboardService.items || []).length > 0
                                Layout.preferredHeight: Math.max(26, Theme.fontSize(11) + 14)
                                Layout.preferredWidth: clearRow.implicitWidth + 18
                                radius: Layout.preferredHeight / 2
                                color: root.confirmingClear ? Theme.notchSurfaceActive
                                     : (wipeMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                border.width: 1
                                border.color: root.confirmingClear ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                RowLayout {
                                    id: clearRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    SymbolicIcon {
                                        source: "user-trash-symbolic"
                                        iconSize: 12
                                        iconColor: root.confirmingClear ? Theme.colors.urgent : Theme.notchTextSecondary
                                    }
                                    Text {
                                        text: I18n.tr(root.confirmingClear ? "clip_clear_confirm_pinned_safe" : "clip_clear_all")
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(11)
                                        font.weight: Font.Medium
                                        color: root.confirmingClear ? Theme.notchText : Theme.notchTextSecondary
                                        renderType: Theme.renderType
                                    }
                                }
                                MouseArea {
                                    id: wipeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.confirmingClear) {
                                            root.confirmingClear = false;
                                            ClipboardService.wipeHistory(true);
                                        } else {
                                            root.confirmingClear = true;
                                            clearConfirmTimer.restart();
                                        }
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }

                            // ESC pill
                            Rectangle {
                                Layout.preferredHeight: Math.max(24, Theme.fontSize(10) + 10)
                                Layout.preferredWidth: Math.max(38, Layout.preferredHeight + 14)
                                radius: Theme.notchRadiusCard
                                color: Theme.notchSurface
                                border.color: Theme.notchBorderSubtle
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10)
                                    font.weight: Font.DemiBold
                                    color: Theme.notchTextSecondary
                                    renderType: Theme.renderType
                                }
                            }
                        }
                    }

                    // Filter tabs row
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(32, Math.round(32 * Math.max(1.0, Theme.fontScale)))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "all", label: "clip_tab_all", icon: "view-list-symbolic" },
                                    { id: "pinned", label: "clip_tab_pinned", icon: "starred-symbolic" },
                                    { id: "text", label: "clip_tab_text", icon: "text-x-generic-symbolic" },
                                    { id: "image", label: "clip_tab_images", icon: "image-x-generic-symbolic" },
                                    { id: "link", label: "clip_tab_links", icon: "insert-link-symbolic" },
                                    { id: "color", label: "clip_tab_colors", icon: "applications-graphics-symbolic" }
                                ]
                                delegate: Rectangle {
                                    id: tabBtn
                                    required property var modelData
                                    readonly property bool isActive: root.activeFilter === modelData.id
                                    readonly property int pinnedCount: modelData.id === "pinned" ? (ClipboardService.pinnedItems || []).length : 0

                                    Layout.preferredHeight: Math.max(26, Theme.fontSize(11) + 12)
                                    Layout.preferredWidth: tabRow.implicitWidth + 18
                                    radius: Layout.preferredHeight / 2
                                    color: isActive ? Theme.notchSurfaceActive
                                         : (tabMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Theme.notchBorderHighlight : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        id: tabRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        SymbolicIcon {
                                            source: tabBtn.modelData.icon
                                            iconSize: 12
                                            iconColor: tabBtn.isActive ? Theme.notchText : Theme.notchTextSecondary
                                        }

                                        Text {
                                            text: I18n.tr(tabBtn.modelData.label) + (tabBtn.pinnedCount > 0 ? " (" + tabBtn.pinnedCount + ")" : "")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(11.5)
                                            font.weight: tabBtn.isActive ? Font.DemiBold : Font.Medium
                                            color: tabBtn.isActive ? Theme.notchText : Theme.notchTextSecondary
                                            renderType: Theme.renderType
                                        }
                                    }

                                    MouseArea {
                                        id: tabMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeFilter = tabBtn.modelData.id;
                                            ShellState.clipboardFilter = tabBtn.modelData.id;
                                            root.selectedIndex = 0;
                                            list.positionViewAtBeginning();
                                            searchInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorderSubtle
            }

            // ── Dual-Pane Content Body ───────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: card.bodyHeight

                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    visible: card.hasItems

                    // Left Pane: Items List
                    Item {
                        Layout.preferredWidth: Math.round(card.width * 0.46)
                        Layout.fillHeight: true

                        ListView {
                            id: list
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 3
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.filteredItems
                            currentIndex: root.selectedIndex

                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                required property int index

                                readonly property bool isImage: modelData.kind === "image"
                                readonly property bool isSelected: index === root.selectedIndex
                                readonly property bool isPinnedItem: ClipboardService.isPinned(modelData)
                                readonly property bool showActions: isSelected || rowMa.containsMouse

                                width: list.width
                                height: isImage ? Math.max(72, Math.round(Theme.fontSize(13) + Theme.fontSize(11) + 30))
                                                : Math.max(50, Math.round(Theme.fontSize(13) + Theme.fontSize(11) + 22))
                                radius: Theme.notchRadiusCard
                                color: isSelected ? Theme.notchSurfaceActive
                                     : (rowMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                                border.width: 1
                                border.color: isSelected ? Theme.notchBorderHighlight : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selectedIndex = row.index
                                    onClicked: root.paste(row.modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // Quick shortcut chip (1..9)
                                    Rectangle {
                                        visible: row.index < 9
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 4
                                        color: row.isSelected ? Theme.notchSurface : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: String(row.index + 1)
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(9.5)
                                            font.weight: Font.Bold
                                            color: row.isSelected ? Theme.notchText : Theme.notchTextTertiary
                                            renderType: Theme.renderType
                                        }
                                    }

                                    // Thumbnail for Image
                                    ClippingRectangle {
                                        visible: row.isImage
                                        Layout.preferredWidth: 70
                                        Layout.preferredHeight: 46
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Theme.radiusSmall
                                        color: Theme.notchSurface
                                        border.width: 1
                                        border.color: Theme.notchBorderSubtle

                                        Image {
                                            anchors.fill: parent
                                            source: row.isImage ? (row.modelData.thumb || "") : ""
                                            sourceSize.width: 140
                                            sourceSize.height: 92
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                            opacity: status === Image.Ready ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                                        }
                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            visible: !row.modelData.thumb
                                            source: "image-x-generic-symbolic"
                                            iconSize: 16
                                            iconColor: Theme.notchTextTertiary
                                        }
                                    }

                                    // Kind Icon or Color Swatch
                                    Rectangle {
                                        visible: !row.isImage
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Theme.notchRadiusPill
                                        color: row.modelData.kind === "color" ? row.modelData.text.trim()
                                             : (row.isSelected ? Theme.notchSurfaceActive : Theme.notchSurface)
                                        border.width: row.modelData.kind === "color" ? 1 : 0
                                        border.color: Theme.notchBorderHighlight

                                        SymbolicIcon {
                                            anchors.centerIn: parent
                                            visible: row.modelData.kind !== "color"
                                            iconSize: 14
                                            source: ({ "link": "insert-link-symbolic", "path": "folder-symbolic",
                                                       "binary": "application-x-executable-symbolic" })[row.modelData.kind]
                                                    || "text-x-generic-symbolic"
                                            iconColor: row.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                        }
                                    }

                                    // Title & metadata column
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: Theme.fontScale > 1.0 ? -1 : -3

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            // Pin star badge
                                            SymbolicIcon {
                                                visible: row.isPinnedItem
                                                source: "starred-symbolic"
                                                iconSize: 11
                                                iconColor: Theme.notchText
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: row.isImage
                                                      ? I18n.tr("clip_image") + " " + row.modelData.format.toUpperCase()
                                                      : row.modelData.text.replace(/\s+/g, " ").trim()
                                                textFormat: Text.PlainText
                                                horizontalAlignment: Text.AlignLeft
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(12.5)
                                                font.weight: row.isSelected ? Font.DemiBold : Font.Medium
                                                color: Theme.notchText
                                                renderType: Theme.renderType
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: row.isImage ? root.imageMeta(row.modelData)
                                                : (row.modelData.kind === "link"
                                                   ? (ClipboardService.extractDomain(row.modelData.text) || I18n.tr("clip_link"))
                                                   : root.textMeta(row.modelData))
                                            horizontalAlignment: Text.AlignLeft
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10.5)
                                            color: Theme.notchTextSecondary
                                            renderType: Theme.renderType
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Hover action buttons
                                    RowLayout {
                                        spacing: 2
                                        visible: row.showActions

                                        // Pin / Unpin button
                                        Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            radius: Theme.notchRadiusPill
                                            color: pinMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: row.isPinnedItem ? "starred-symbolic" : "non-starred-symbolic"
                                                iconSize: 12
                                                iconColor: pinMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                            }
                                            MouseArea {
                                                id: pinMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.togglePin(row.modelData)
                                            }
                                        }

                                        // Copy button
                                        Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            radius: Theme.notchRadiusPill
                                            color: copyMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: "edit-copy-symbolic"
                                                iconSize: 12
                                                iconColor: copyMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                            }
                                            MouseArea {
                                                id: copyMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.copyOnly(row.modelData)
                                            }
                                        }

                                        // Delete button
                                        Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            radius: Theme.notchRadiusPill
                                            color: delMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                            SymbolicIcon {
                                                anchors.centerIn: parent
                                                source: "user-trash-symbolic"
                                                iconSize: 12
                                                iconColor: delMa.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary
                                            }
                                            MouseArea {
                                                id: delMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.remove(row.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Vertical divider between list and inspector
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Theme.notchBorderSubtle
                    }

                    // Right Pane: Rich Inspector / Live Preview
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            visible: root.selectedItem !== null

                            // Inspector Header (Kind badge, length/size, actions)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: kindText.implicitWidth + 14
                                    radius: 11
                                    color: Theme.notchSurface
                                    border.width: 1
                                    border.color: Theme.notchBorderSubtle
                                    Text {
                                        id: kindText
                                        anchors.centerIn: parent
                                        text: root.selectedItem ? root.kindLabel(root.selectedItem.kind).toUpperCase() : ""
                                        font.family: Theme.typography.fontFamily
                                        font.pixelSize: Theme.fontSize(10)
                                        font.weight: Font.DemiBold
                                        color: Theme.notchText
                                        renderType: Theme.renderType
                                    }
                                }

                                Rectangle {
                                    visible: root.selectedItem && ClipboardService.isPinned(root.selectedItem)
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: pinnedText.implicitWidth + 14
                                    radius: 11
                                    color: Theme.notchSurfaceActive
                                    border.width: 1
                                    border.color: Theme.notchBorderHighlight
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        SymbolicIcon {
                                            source: "starred-symbolic"
                                            iconSize: 10
                                            iconColor: Theme.notchText
                                        }
                                        Text {
                                            id: pinnedText
                                            text: I18n.tr("clip_pinned_badge")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            font.weight: Font.DemiBold
                                            color: Theme.notchText
                                            renderType: Theme.renderType
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: {
                                        if (!root.selectedItem) return "";
                                        if (root.selectedItem.kind === "image") return root.imageMeta(root.selectedItem);
                                        const stats = root.textStats(ClipboardService.currentDecodedText || root.selectedItem.text);
                                        return I18n.tr("clip_lines_count").arg(stats.lines) + "  ·  " +
                                               I18n.tr("clip_words_count").arg(stats.words) + "  ·  " +
                                               I18n.tr("clip_char_count").arg(stats.chars);
                                    }
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(10.5)
                                    color: Theme.notchTextTertiary
                                    renderType: Theme.renderType
                                }
                            }

                            // Inspector Body (Content type specific preview)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // 1. IMAGE PREVIEW
                                ClippingRectangle {
                                    anchors.fill: parent
                                    visible: root.selectedItem && root.selectedItem.kind === "image"
                                    radius: Theme.radiusSmall
                                    color: Theme.notchSurface
                                    border.width: 1
                                    border.color: Theme.notchBorderSubtle

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        source: (root.selectedItem && root.selectedItem.kind === "image") ? (root.selectedItem.thumb || "") : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                    }
                                }

                                // 2. LINK PREVIEW & ACTION
                                ColumnLayout {
                                    anchors.fill: parent
                                    visible: root.selectedItem && root.selectedItem.kind === "link"
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: Theme.radiusSmall
                                        color: Theme.notchSurface
                                        border.width: 1
                                        border.color: Theme.notchBorderSubtle

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            SymbolicIcon {
                                                source: "insert-link-symbolic"
                                                iconSize: 22
                                                iconColor: Theme.notchText
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: root.selectedItem ? (ClipboardService.extractDomain(root.selectedItem.text) || I18n.tr("clip_link")) : ""
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(13)
                                                    font.weight: Font.DemiBold
                                                    color: Theme.notchText
                                                    renderType: Theme.renderType
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: root.selectedItem ? root.selectedItem.text : ""
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(11)
                                                    color: Theme.notchTextSecondary
                                                    renderType: Theme.renderType
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }

                                    // Open in browser button
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        radius: Theme.radiusSmall
                                        color: openBrowserMa.containsMouse ? Theme.notchSurfaceActive : Theme.notchSurface
                                        border.width: 1
                                        border.color: Theme.notchBorderHighlight
                                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            SymbolicIcon {
                                                source: "web-browser-symbolic"
                                                iconSize: 14
                                                iconColor: Theme.notchText
                                            }
                                            Text {
                                                text: I18n.tr("clip_open_link")
                                                font.family: Theme.typography.fontFamily
                                                font.pixelSize: Theme.fontSize(12)
                                                font.weight: Font.Medium
                                                color: Theme.notchText
                                                renderType: Theme.renderType
                                            }
                                        }
                                        MouseArea {
                                            id: openBrowserMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.selectedItem) ClipboardService.openUrl(root.selectedItem.text);
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                // 3. COLOR PREVIEW & SWATCH
                                ColumnLayout {
                                    anchors.fill: parent
                                    visible: root.selectedItem && root.selectedItem.kind === "color"
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 80
                                        radius: Theme.radiusSmall
                                        color: root.selectedItem && root.selectedItem.kind === "color" ? root.selectedItem.text.trim() : "transparent"
                                        border.width: 1
                                        border.color: Theme.notchBorderHighlight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: Theme.radiusSmall
                                            color: Theme.notchSurface
                                            border.width: 1
                                            border.color: hexCopyMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text {
                                                    text: root.selectedItem ? root.selectedItem.text.trim().toUpperCase() : ""
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(12)
                                                    font.weight: Font.DemiBold
                                                    color: Theme.notchText
                                                    renderType: Theme.renderType
                                                }
                                                Text {
                                                    text: "· " + I18n.tr("clip_copy_hex")
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(10.5)
                                                    color: Theme.notchTextSecondary
                                                    renderType: Theme.renderType
                                                }
                                            }
                                            MouseArea {
                                                id: hexCopyMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.selectedItem) ClipboardService.copyText(root.selectedItem.text.trim());
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: Theme.radiusSmall
                                            color: Theme.notchSurface
                                            border.width: 1
                                            border.color: rgbCopyMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text {
                                                    text: root.selectedItem ? ClipboardService.hexToRgb(root.selectedItem.text) : ""
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(12)
                                                    font.weight: Font.DemiBold
                                                    color: Theme.notchText
                                                    renderType: Theme.renderType
                                                }
                                                Text {
                                                    text: "· " + I18n.tr("clip_copy_rgb")
                                                    font.family: Theme.typography.fontFamily
                                                    font.pixelSize: Theme.fontSize(10.5)
                                                    color: Theme.notchTextSecondary
                                                    renderType: Theme.renderType
                                                }
                                            }
                                            MouseArea {
                                                id: rgbCopyMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.selectedItem) ClipboardService.copyText(ClipboardService.hexToRgb(root.selectedItem.text));
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                // 4. MULTILINE TEXT / CODE PREVIEW
                                Rectangle {
                                    anchors.fill: parent
                                    visible: root.selectedItem && root.selectedItem.kind !== "image" && root.selectedItem.kind !== "color" && root.selectedItem.kind !== "link"
                                    radius: Theme.radiusSmall
                                    color: Theme.notchSurface
                                    border.width: 1
                                    border.color: Theme.notchBorderSubtle

                                    Flickable {
                                        id: textFlick
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        contentWidth: previewText.width
                                        contentHeight: previewText.height
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        TextEdit {
                                            id: previewText
                                            width: textFlick.width
                                            readOnly: true
                                            selectByMouse: true
                                            selectionColor: Theme.textSelection
                                            selectedTextColor: Theme.notchText
                                            wrapMode: TextEdit.WrapAnywhere
                                            text: ClipboardService.currentDecodedText || (root.selectedItem ? root.selectedItem.text : "")
                                            color: Theme.notchText
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(12)
                                            renderType: Theme.renderType
                                        }
                                    }
                                }
                            }

                            // Inspector Bottom Action Buttons
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Paste Button (High contrast solid primary action)
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: Theme.radiusSmall
                                    color: pasteBtnMa.containsMouse ? Theme.notchTextSecondary : Theme.notchText
                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        SymbolicIcon {
                                            source: "edit-paste-symbolic"
                                            iconSize: 13
                                            iconColor: Theme.notchBackground
                                        }
                                        Text {
                                            text: I18n.tr("clip_hint_paste") + " (↵)"
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(12)
                                            font.weight: Font.Bold
                                            color: Theme.notchBackground
                                            renderType: Theme.renderType
                                        }
                                    }
                                    MouseArea {
                                        id: pasteBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.paste(root.selectedItem)
                                    }
                                }

                                // Copy Button
                                Rectangle {
                                    Layout.preferredWidth: 84
                                    Layout.preferredHeight: 34
                                    radius: Theme.radiusSmall
                                    color: copyBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                                    border.width: 1
                                    border.color: Theme.notchBorderSubtle
                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        SymbolicIcon {
                                            source: "edit-copy-symbolic"
                                            iconSize: 12
                                            iconColor: Theme.notchText
                                        }
                                        Text {
                                            text: I18n.tr("clip_copy")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(11.5)
                                            font.weight: Font.Medium
                                            color: Theme.notchText
                                            renderType: Theme.renderType
                                        }
                                    }
                                    MouseArea {
                                        id: copyBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.copyOnly(root.selectedItem)
                                    }
                                }

                                // Pin Button
                                Rectangle {
                                    Layout.preferredWidth: 84
                                    Layout.preferredHeight: 34
                                    radius: Theme.radiusSmall
                                    color: pinBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                                    border.width: 1
                                    border.color: (root.selectedItem && ClipboardService.isPinned(root.selectedItem)) ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        SymbolicIcon {
                                            source: (root.selectedItem && ClipboardService.isPinned(root.selectedItem)) ? "starred-symbolic" : "non-starred-symbolic"
                                            iconSize: 12
                                            iconColor: Theme.notchText
                                        }
                                        Text {
                                            text: (root.selectedItem && ClipboardService.isPinned(root.selectedItem)) ? I18n.tr("clip_unpin") : I18n.tr("clip_pin")
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(11.5)
                                            font.weight: Font.Medium
                                            color: Theme.notchText
                                            renderType: Theme.renderType
                                        }
                                    }
                                    MouseArea {
                                        id: pinBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.togglePin(root.selectedItem)
                                    }
                                }

                                // Delete Button
                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 34
                                    radius: Theme.radiusSmall
                                    color: delBtnMa.containsMouse ? Theme.notchSurfaceHover : Theme.notchSurface
                                    border.width: 1
                                    border.color: delBtnMa.containsMouse ? Theme.colors.urgent : Theme.notchBorderSubtle
                                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: "user-trash-symbolic"
                                        iconSize: 13
                                        iconColor: delBtnMa.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary
                                    }
                                    MouseArea {
                                        id: delBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.remove(root.selectedItem)
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !card.hasItems
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !ClipboardService.isAvailable ? I18n.tr("clip_unavailable")
                            : ((ClipboardService.items || []).length === 0
                               ? I18n.tr("clip_empty")
                               : (root.searchQuery.trim().length > 0
                                  ? I18n.tr("clip_no_match").arg("«" + I18n.isolate(root.searchQuery) + "»")
                                  : I18n.tr("clip_empty_filter")))
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(13)
                        font.weight: Font.Medium
                        color: Theme.notchTextSecondary
                        renderType: Theme.renderType
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: ClipboardService.isAvailable && (ClipboardService.items || []).length === 0
                        text: I18n.tr("clip_empty_hint")
                        font.family: Theme.typography.fontFamily
                        font.pixelSize: Theme.fontSize(11)
                        color: Theme.notchTextTertiary
                        renderType: Theme.renderType
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorderSubtle
            }

            // ── Footer: Counts and Shortcuts ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.footerHeight
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 12

                Text {
                    text: I18n.entriesCount((ClipboardService.items || []).length) +
                          ((ClipboardService.pinnedItems || []).length > 0 ? "  ·  " + (ClipboardService.pinnedItems || []).length + " " + I18n.tr("clip_tab_pinned") : "")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(11)
                    color: Theme.notchTextTertiary
                    renderType: Theme.renderType
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [
                        { key: "↵", label: "clip_hint_paste" },
                        { key: "Ctrl C", label: "clip_hint_copy" },
                        { key: "Ctrl P", label: "clip_hint_pin" },
                        { key: "Tab", label: "clip_hint_filter" },
                        { key: "1-9", label: "clip_hint_quick" },
                        { key: "Del", label: "clip_hint_delete" }
                    ]
                    delegate: RowLayout {
                        id: hint
                        required property var modelData
                        spacing: 4
                        Rectangle {
                            Layout.preferredHeight: Math.max(18, Theme.fontSize(10) + 8)
                            Layout.preferredWidth: keyText.implicitWidth + 10
                            radius: 5
                            color: Theme.notchSurface
                            border.width: 1
                            border.color: Theme.notchBorderSubtle
                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: hint.modelData.key
                                transform: Scale {
                                    origin.x: keyText.width / 2
                                    xScale: I18n.isRTL && hint.modelData.key === "↵" ? -1 : 1
                                }
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(10)
                                font.weight: Font.DemiBold
                                color: Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                        }
                        Text {
                            text: I18n.tr(hint.modelData.label)
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                        }
                    }
                }
            }
        }
    }
}
