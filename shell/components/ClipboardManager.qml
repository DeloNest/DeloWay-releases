import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../services"

// Clipboard history (Super + V), in the launcher's form: one black card under the capsules
// that grows with its content, no dimmed screen. Enter or a click pastes the entry into
// the window that had focus; Ctrl+C (or the copy button) only puts it back on the
// clipboard; Delete removes it. Images show as thumbnails of themselves.
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
        return item.kind === "image"
               ? [I18n.tr("clip_image"), "image", item.format].join(" ")
               : item.text;
    }

    readonly property var filteredItems: {
        const list = ClipboardService.items || [];
        const q = root.normalizeText(root.searchQuery.trim());
        return q ? list.filter(item => root.normalizeText(root.searchText(item)).includes(q)) : list;
    }

    readonly property var selectedItem: filteredItems.length > 0
                                        ? filteredItems[Math.min(selectedIndex, filteredItems.length - 1)]
                                        : null

    // "41 KiB" (cliphist) → the shell's own size format and digits.
    function imageSize(item) {
        const m = /^([\d.]+) (B|KiB|MiB|GiB)$/.exec(item.size || "");
        if (!m) return item.size || "";
        const mult = { "B": 1, "KiB": 1024, "MiB": 1048576, "GiB": 1073741824 }[m[2]];
        return I18n.fileSize(Number(m[1]) * mult);
    }

    function imageMeta(item) {
        return I18n.ltr(I18n.number(item.width + "×" + item.height)) + "  ·  " + root.imageSize(item);
    }

    function textMeta(item) {
        const label = root.kindLabel(item.kind);
        return item.kind === "text" ? label + "  ·  " + I18n.charsCount(item.text.length) : label;
    }

    function moveSelection(step) {
        const n = root.filteredItems.length;
        if (n === 0) return;
        root.selectedIndex = (root.selectedIndex + step + n) % n;
        list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
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

    Connections {
        target: ShellState
        function onClipboardOpenChanged() {
            if (ShellState.clipboardOpen) {
                ClipboardService.refresh();
                searchInput.text = "";
                root.searchQuery = "";
                root.selectedIndex = 0;
                root.confirmingClear = false;
                focusTimer.restart();
            }
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

    // Click outside: close (no dimming, as the launcher)
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeClipboard()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Card
    // ─────────────────────────────────────────────────────────────────────
    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.16)
        width: Math.min(560, root.width - 32)

        readonly property int headerHeight: 52
        readonly property int footerHeight: 34
        // Up to 460 px of entries, never past the bottom of the screen (a short output
        // squeezed the list to what is left; the card used to run off it).
        readonly property int maxListHeight: Math.max(76, Math.min(460, root.height - y - 24 - headerHeight - footerHeight - 2))
        readonly property bool hasItems: root.filteredItems.length > 0
        readonly property int bodyHeight: hasItems ? Math.min(maxListHeight, list.contentHeight + 12) : 88

        height: headerHeight + 1 + bodyHeight + 1 + footerHeight
        radius: Theme.notchRadiusWindow
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1
        clip: true

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

        // Clicks inside the card never reach the backdrop
        MouseArea { anchors.fill: parent }

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Search bar ───────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: card.headerHeight

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
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
                            Keys.onDownPressed: root.moveSelection(1)
                            Keys.onUpPressed: root.moveSelection(-1)
                            Keys.onReturnPressed: event => {
                                if (event.modifiers & Qt.ShiftModifier) root.copyOnly(root.selectedItem);
                                else root.paste(root.selectedItem);
                            }
                            Keys.onEnterPressed: root.paste(root.selectedItem)
                            Keys.onPressed: event => {
                                // Ctrl+C copies the entry unless text of the query is selected;
                                // Delete removes it unless there is query text after the cursor.
                                if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)
                                        && searchInput.selectedText.length === 0) {
                                    root.copyOnly(root.selectedItem);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Delete
                                           && searchInput.cursorPosition === searchInput.text.length) {
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

                    // Clear the query
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

                    // Clear the history: a second click within 3 s confirms
                    Rectangle {
                        visible: (ClipboardService.items || []).length > 0
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: clearRow.implicitWidth + 16
                        radius: Theme.notchRadiusPill
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
                                text: I18n.tr(root.confirmingClear ? "clip_clear_confirm" : "clip_clear_all")
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
                                    ClipboardService.wipeHistory();
                                } else {
                                    root.confirmingClear = true;
                                    clearConfirmTimer.restart();
                                }
                                searchInput.forceActiveFocus();
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 24
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorderSubtle
            }

            // ── Entries ──────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: card.bodyHeight

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2
                    clip: true
                    visible: card.hasItems
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredItems
                    currentIndex: root.selectedIndex

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index

                        readonly property bool isImage: modelData.kind === "image"
                        readonly property bool isSelected: index === root.selectedIndex
                        readonly property bool showActions: isSelected || rowMa.containsMouse

                        width: list.width
                        height: isImage ? 76 : 48
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
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            // Thumbnail of the image itself
                            ClippingRectangle {
                                visible: row.isImage
                                Layout.preferredWidth: 104
                                Layout.preferredHeight: 60
                                Layout.alignment: Qt.AlignVCenter
                                radius: Theme.radiusSmall
                                color: Theme.notchSurface
                                border.width: 1
                                border.color: Theme.notchBorderSubtle

                                Image {
                                    anchors.fill: parent
                                    source: row.isImage ? (row.modelData.thumb || "") : ""
                                    sourceSize.width: 208
                                    sourceSize.height: 120
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
                                    iconSize: 18
                                    iconColor: Theme.notchTextTertiary
                                }
                            }

                            // Kind tile (text, link, path) or the copied colour itself
                            Rectangle {
                                visible: !row.isImage
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter
                                radius: Theme.notchRadiusPill
                                color: row.modelData.kind === "color" ? row.modelData.text.trim()
                                     : (row.isSelected ? Theme.notchSurfaceActive : Theme.notchSurface)
                                border.width: row.modelData.kind === "color" ? 1 : 0
                                border.color: Theme.notchBorderHighlight

                                SymbolicIcon {
                                    anchors.centerIn: parent
                                    visible: row.modelData.kind !== "color"
                                    iconSize: 15
                                    source: ({ "link": "insert-link-symbolic", "path": "folder-symbolic",
                                               "binary": "application-x-executable-symbolic" })[row.modelData.kind]
                                            || "text-x-generic-symbolic"
                                    iconColor: row.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: -4   // Cairo's tall leading, as in the launcher rows

                                Text {
                                    Layout.fillWidth: true
                                    text: row.isImage
                                          ? I18n.tr("clip_image") + " " + row.modelData.format.toUpperCase()
                                          : row.modelData.text.replace(/\s+/g, " ").trim()
                                    textFormat: Text.PlainText
                                    horizontalAlignment: Text.AlignLeft
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(13)
                                    font.weight: row.isSelected ? Font.DemiBold : Font.Medium
                                    color: Theme.notchText
                                    renderType: Theme.renderType
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.isImage ? root.imageMeta(row.modelData) : root.textMeta(row.modelData)
                                    horizontalAlignment: Text.AlignLeft
                                    font.family: Theme.typography.fontFamily
                                    font.pixelSize: Theme.fontSize(11)
                                    color: Theme.notchTextSecondary
                                    renderType: Theme.renderType
                                    elide: Text.ElideRight
                                }
                            }

                            // Copy only / delete, on the hovered or selected entry
                            Repeater {
                                model: [
                                    { icon: "edit-copy-symbolic", tip: "clip_copy", danger: false },
                                    { icon: "user-trash-symbolic", tip: "clip_delete", danger: true }
                                ]
                                delegate: Rectangle {
                                    id: action
                                    required property var modelData
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Theme.notchRadiusPill
                                    opacity: row.showActions ? 1 : 0
                                    visible: opacity > 0
                                    color: actionMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        source: action.modelData.icon
                                        iconSize: 14
                                        iconColor: actionMa.containsMouse
                                                   ? (action.modelData.danger ? Theme.colors.urgent : Theme.notchText)
                                                   : Theme.notchTextSecondary
                                    }
                                    MouseArea {
                                        id: actionMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.selectedIndex = row.index
                                        onClicked: {
                                            if (action.modelData.danger) root.remove(row.modelData);
                                            else root.copyOnly(row.modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty, unavailable or no match
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !card.hasItems
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !ClipboardService.isAvailable ? I18n.tr("clip_unavailable")
                            : ((ClipboardService.items || []).length === 0
                               ? I18n.tr("clip_empty")
                               : I18n.tr("clip_no_match").arg("«" + I18n.isolate(root.searchQuery) + "»"))
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

            // ── Footer: count and keys ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.footerHeight
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 14

                Text {
                    text: I18n.entriesCount((ClipboardService.items || []).length)
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
                        { key: "Del", label: "clip_hint_delete" }
                    ]
                    delegate: RowLayout {
                        id: hint
                        required property var modelData
                        spacing: 5
                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: keyText.implicitWidth + 10
                            radius: 5
                            color: Theme.notchSurface
                            border.width: 1
                            border.color: Theme.notchBorderSubtle
                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: hint.modelData.key
                                // ↵ points back to the line start: flip it in Arabic
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
