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

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.clipboardOpen
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    visible: ShellState.clipboardOpen || cardHost.opacity > 0.005
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────
    property string searchQuery: ""
    property int selectedIndex: 0

    // Arabic and English text normalization
    function normalizeText(text) {
        if (!text) return "";
        return text.toString().toLowerCase()
            .replace(/[\u064B-\u065F\u0670]/g, "")
            .replace(/[أإآٱ]/g, "ا")
            .replace(/ة/g, "ه")
            .replace(/ى/g, "ي");
    }

    readonly property var filteredItems: {
        const q = searchQuery.trim();
        const normQ = normalizeText(q);
        const list = (typeof ClipboardService !== "undefined" && ClipboardService && ClipboardService.items) ? ClipboardService.items : [];
        if (!normQ) return list;

        return list.filter(item => {
            return normalizeText(item.text).includes(normQ);
        });
    }

    // ─────────────────────────────────────────────────────────────────────
    // Dimmed Backdrop
    // ─────────────────────────────────────────────────────────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.modalScrim
        opacity: cardHost.opacity

        Behavior on opacity {
            NumberAnimation {
                duration: cardHost.isOpen ? 180 : 130
                easing.type: cardHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.closeClipboard()
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Centered OLED Card (~580px)
    // ─────────────────────────────────────────────────────────────────────
    Item {
        id: cardHost
        anchors.centerIn: parent
        width: Math.min(580, root.width - 32)
        height: Math.min(480, root.height - 80)

        readonly property bool isOpen: ShellState.clipboardOpen
        opacity: isOpen ? 1.0 : 0.0
        scale: isOpen ? 1.0 : 0.96
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: cardHost.isOpen ? 180 : 130
                easing.type: cardHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: cardHost.isOpen ? 180 : 130
                easing.type: cardHost.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }

        // Ambient Drop Shadow
        Rectangle {
            anchors.fill: cardRect
            anchors.topMargin: 10
            anchors.bottomMargin: -10
            anchors.leftMargin: -4
            anchors.rightMargin: -4
            radius: Theme.notchRadiusWindow + 4
            color: Theme.notchShadow
            z: 0
        }

        Rectangle {
            id: cardRect
            anchors.fill: parent
            radius: Theme.notchRadiusWindow
            color: Theme.notchBackground
            border.color: Theme.notchBorder
            border.width: 1
            z: 1

            LayoutMirroring.enabled: I18n.isRTL
            LayoutMirroring.childrenInherit: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space16
                spacing: Theme.space8

                // ─────────────────────────────────────────────────────────
                // 1. Search Bar & Clear Action
                // ─────────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space8

                    DeloTextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: Theme.notchRadiusPill
                        customBackground: Theme.notchSurface
                        customBorderColor: Theme.notchBorder
                        customFocusBorderColor: Theme.notchBorderHighlight
                        showSearchIcon: true
                        placeholderText: I18n.isRTL ? "ابحث في سجل الحافظة..." : "Search clipboard history..."

                        onTextChanged: {
                            root.searchQuery = text;
                            root.selectedIndex = 0;
                        }

                        textInput.Keys.onEscapePressed: ShellState.closeClipboard()

                        textInput.Keys.onDownPressed: {
                            if (root.filteredItems.length > 0)
                                root.selectedIndex = (root.selectedIndex + 1) % root.filteredItems.length;
                        }

                        textInput.Keys.onUpPressed: {
                            if (root.filteredItems.length > 0)
                                root.selectedIndex = (root.selectedIndex - 1 + root.filteredItems.length) % root.filteredItems.length;
                        }

                        textInput.Keys.onReturnPressed: {
                            if (root.filteredItems.length > 0) {
                                const idx = Math.min(root.selectedIndex, root.filteredItems.length - 1);
                                ClipboardService.copyItem(root.filteredItems[idx]);
                                ShellState.closeClipboard();
                            }
                        }
                    }

                    // Clear All Button
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: clearRow.implicitWidth + Theme.space16
                        radius: Theme.radiusSmall
                        color: clearMa.pressed ? Theme.notchSurfaceActive : (clearMa.containsMouse ? Theme.notchSurfaceHover : "transparent")
                        border.color: clearMa.containsMouse ? Theme.notchBorderHighlight : Theme.notchBorderSubtle
                        border.width: 1

                        RowLayout {
                            id: clearRow
                            anchors.centerIn: parent
                            spacing: Theme.space4

                            SymbolicIcon {
                                iconSize: 13
                                source: "edit-clear-all-symbolic"
                                iconColor: clearMa.containsMouse ? Theme.colors.urgent : Theme.notchTextSecondary
                            }

                            Text {
                                text: I18n.isRTL ? "مسح الكل" : "Clear All"
                                font.family: Theme.typography.fontFamily
                                font.pixelSize: Theme.fontSize(11)
                                font.weight: Font.Medium
                                color: clearMa.containsMouse ? Theme.notchText : Theme.notchTextSecondary
                                renderType: Theme.renderType
                            }
                        }

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardService.wipeHistory()
                        }
                    }

                    // ESC badge
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 28
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.color: Theme.notchBorderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.DemiBold
                            renderType: Theme.renderType
                            color: Theme.notchTextTertiary
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // 2. Clipboard Items List
                // ─────────────────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: clipList
                        anchors.fill: parent
                        clip: true
                        spacing: Theme.space4
                        model: root.filteredItems
                        currentIndex: root.selectedIndex

                        delegate: Rectangle {
                            id: clipItem
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: root.selectedIndex === clipItem.index

                            width: clipList.width
                            height: 52
                            radius: Theme.notchRadiusCard
                            color: itemMa.pressed
                                   ? Theme.notchSurfaceActive
                                   : (itemMa.containsMouse
                                      ? Theme.notchSurfaceHover
                                      : (isSelected ? Theme.notchSurfaceActive : "transparent"))
                            border.color: isSelected ? Theme.notchBorderHighlight : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space8
                                anchors.rightMargin: Theme.space8
                                spacing: Theme.space8

                                // Icon (Text vs Image)
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: Theme.radiusSmall
                                    color: Theme.notchSurface
                                    border.color: Theme.notchBorderSubtle
                                    border.width: 1

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        iconSize: 16
                                        source: clipItem.modelData.isImage
                                                ? "image-x-generic-symbolic"
                                                : "edit-copy-symbolic"
                                        iconColor: clipItem.isSelected ? Theme.notchText : Theme.notchTextSecondary
                                    }
                                }

                                // Text & Meta
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft   // reading start, even for Latin/code entries
                                        text: clipItem.modelData.text || ""
                                        font.family: Theme.typography.fontFamily   // the UI font; only terminals are monospace
                                        font.pixelSize: Theme.fontSize(12)
                                        font.weight: clipItem.isSelected ? Font.DemiBold : Font.Normal
                                        color: Theme.notchText
                                        renderType: Theme.renderType
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    RowLayout {
                                        spacing: Theme.space8

                                        Text {
                                            text: clipItem.modelData.isImage
                                                  ? (I18n.isRTL ? "صورة" : "Image")
                                                  : (clipItem.modelData.text.length + (I18n.isRTL ? " حرف" : " chars"))
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            font.weight: Font.Normal
                                            color: Theme.notchTextTertiary
                                            renderType: Theme.renderType
                                        }

                                        Text {
                                            text: "#" + clipItem.modelData.id
                                            font.family: Theme.typography.fontFamily
                                            font.pixelSize: Theme.fontSize(10)
                                            font.weight: Font.Normal
                                            color: Theme.notchTextTertiary
                                            renderType: Theme.renderType
                                        }
                                    }
                                }

                                // Single item delete button (on hover)
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.radiusSmall
                                    visible: itemMa.containsMouse || delMa.containsMouse
                                    color: delMa.containsMouse ? Theme.notchSurfaceHover : "transparent"

                                    SymbolicIcon {
                                        anchors.centerIn: parent
                                        iconSize: 13
                                        source: "user-trash-symbolic"
                                        iconColor: delMa.containsMouse ? Theme.colors.urgent : Theme.notchTextTertiary
                                    }

                                    MouseArea {
                                        id: delMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ClipboardService.deleteItem(clipItem.modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onEntered: root.selectedIndex = clipItem.index

                                onClicked: {
                                    ClipboardService.copyItem(clipItem.modelData);
                                    ShellState.closeClipboard();
                                }
                            }
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: !root.filteredItems || root.filteredItems.length === 0
                        spacing: Theme.space8

                        SymbolicIcon {
                            Layout.alignment: Qt.AlignHCenter
                            iconSize: 32
                            source: (typeof ClipboardService === "undefined" || !ClipboardService || !ClipboardService.isAvailable) ? "dialog-warning-symbolic" : "edit-copy-symbolic"
                            iconColor: Theme.notchTextTertiary
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (typeof ClipboardService === "undefined" || !ClipboardService || !ClipboardService.isAvailable)
                                  ? (I18n.isRTL ? "خدمة الحافظة غير متوفرة (cliphist / wl-paste)" : "Clipboard service unavailable (cliphist / wl-paste)")
                                  : (!ClipboardService.items || ClipboardService.items.length === 0
                                     ? (I18n.isRTL ? "سجل الحافظة فارغ" : "Clipboard history is empty")
                                     : (I18n.isRTL ? "لا توجد نتائج تطابق البحث" : "No matching items found"))
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(13)
                            font.weight: Font.DemiBold
                            color: Theme.notchTextSecondary
                            renderType: Theme.renderType
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────
                // 3. Compact Monochrome Footer
                // ─────────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.notchRadiusPanel
                    color: Theme.notchSurface
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space16
                        anchors.rightMargin: Theme.space16
                        spacing: Theme.space8

                        Text {
                            text: I18n.isRTL
                                  ? ("العناصر: " + (root.filteredItems ? root.filteredItems.length : 0))
                                  : ("Items: " + (root.filteredItems ? root.filteredItems.length : 0))
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.Medium
                            color: Theme.notchTextSecondary
                            renderType: Theme.renderType
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: I18n.isRTL
                                  ? "↑ / ↓ للتنقل • ↵ للنسخ • Esc للإغلاق"
                                  : "↑ / ↓ navigate • ↵ copy • Esc close"
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(10)
                            font.weight: Font.Normal
                            color: Theme.notchTextTertiary
                            renderType: Theme.renderType
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Shell state synchronization
    // ─────────────────────────────────────────────────────────────────────
    Connections {
        target: ShellState

        function onClipboardOpenChanged() {
            if (ShellState.clipboardOpen) {
                ClipboardService.refresh();
                searchInput.text = "";
                root.searchQuery = "";
                root.selectedIndex = 0;
                searchInput.forceActiveFocus();
            }
        }
    }
}
