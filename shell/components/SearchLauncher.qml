import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "launcher"

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

    WlrLayershell.namespace: "deloway:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.launcherOpen
                                 ? WlrKeyboardFocus.Exclusive
                                 : WlrKeyboardFocus.None

    visible: ShellState.launcherOpen || launcherCard.opacity > 0.005
    exclusionMode: ExclusionMode.Ignore

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────
    property string filterQuery: ""
    property int selectedIndex: 0
    readonly property var results: LauncherIndex.search(filterQuery)

    // Helper process for calculator copying
    Process {
        id: wlCopyProcess
    }

    // Debounce timer for smooth typing
    Timer {
        id: searchDebounceTimer
        interval: 40
        repeat: false
        onTriggered: {
            root.filterQuery = searchInput.text;
            root.selectedIndex = 0;
        }
    }

    // React to launcher open state
    Connections {
        target: ShellState
        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                searchInput.text = ShellState.launcherQuery || "";
                root.filterQuery = searchInput.text;
                root.selectedIndex = 0;
                forceFocusTimer.restart();
            } else {
                searchInput.text = "";
                root.filterQuery = "";
                root.selectedIndex = 0;
            }
        }
        function onLauncherQueryChanged() {
            if (ShellState.launcherOpen) {
                searchInput.text = ShellState.launcherQuery || "";
                root.filterQuery = searchInput.text;
                root.selectedIndex = 0;
            }
        }
    }

    Timer {
        id: forceFocusTimer
        interval: 10
        repeat: false
        onTriggered: {
            searchInput.forceActiveFocus();
            if (searchInput.text.length > 0) {
                searchInput.selectAll();
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Execution dispatcher
    // ─────────────────────────────────────────────────────────────────────
    function executeSelected() {
        if (root.results && root.results.length > 0) {
            const idx = Math.max(0, Math.min(root.selectedIndex, root.results.length - 1));
            executeItem(root.results[idx]);
        }
    }

    function executeItem(item) {
        if (!item) return;

        ShellState.closeLauncher();

        if (item.type === "calc") {
            if (item.data && item.data.value !== undefined) {
                wlCopyProcess.exec(["wl-copy", "--", String(item.data.value)]);
            }
        } else if (item.type === "app") {
            if (item.data) {
                if (item.data.id) {
                    LauncherIndex.recordLaunch(item.data.id);
                }
                if (typeof item.data.execute === "function") {
                    item.data.execute();
                } else {
                    ApplicationManager.launchApp(item.data);
                }
            }
        } else if (item.type === "setting") {
            if (item.id === "settings-main") {
                ShellState.toggleSettingsApp();
            } else {
                ShellState.openSettingsTab(item.id);
            }
        } else if (item.type === "web") {
            Hyprland.dispatch("exec xdg-open 'https://duckduckgo.com/?q=" + encodeURIComponent(item.data.query) + "'");
        } else if (item.type === "action") {
            if (item.id === "lock") {
                ShellState.lock();
            } else if (item.id === "logout") {
                Hyprland.dispatch("exit");
            } else if (item.id === "restart") {
                Hyprland.dispatch("exec systemctl reboot");
            } else if (item.id === "shutdown") {
                Hyprland.dispatch("exec systemctl poweroff");
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Transparent Backdrop (Click outside to dismiss, zero dimming shadow)
    // ─────────────────────────────────────────────────────────────────────
    MouseArea {
        id: backdrop
        anchors.fill: parent
        hoverEnabled: false
        onClicked: ShellState.closeLauncher()
    }

    // ─────────────────────────────────────────────────────────────────────
    // Floating Spotlight Search Card
    // ─────────────────────────────────────────────────────────────────────
    Rectangle {
        id: launcherCard

        anchors.horizontalCenter: parent.horizontalCenter
        // The window spans the screen; its height is there even while targetScreen is
        // briefly null (a monitor being removed), which threw "height of null".
        y: Math.round(root.height * 0.20)
        width: Math.min(500, root.width - 32)

        readonly property int headerHeight: 52
        readonly property int maxResultRows: 7
        readonly property int resultRowHeight: 48
        readonly property bool hasQuery: root.filterQuery.trim().length > 0
        readonly property int resultCount: hasQuery ? (root.results ? root.results.length : 0) : 0

        // In empty state, height is exactly 52px (search bar alone).
        // When typing, height expands dynamically to fit results list.
        height: hasQuery
                ? (headerHeight + 1 + (resultCount > 0 ? (Math.min(maxResultRows, resultCount) * resultRowHeight + 10) : 44))
                : headerHeight

        radius: Theme.notchRadiusWindow
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1
        clip: true

        readonly property bool isOpen: ShellState.launcherOpen
        opacity: isOpen ? 1.0 : 0.0
        scale: isOpen ? 1.0 : 0.97
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: launcherCard.isOpen ? 150 : 110
                easing.type: launcherCard.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: launcherCard.isOpen ? 150 : 110
                easing.type: launcherCard.isOpen ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Search Input Bar (52px) ───────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: launcherCard.headerHeight

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    // Search Icon
                    SymbolicIcon {
                        source: "edit-find-symbolic"
                        iconSize: 18
                        iconColor: Theme.notchText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Input Text Field
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
                                searchDebounceTimer.restart();
                            }

                            Keys.onEscapePressed: ShellState.closeLauncher()

                            Keys.onDownPressed: {
                                if (root.results && root.results.length > 0) {
                                    root.selectedIndex = (root.selectedIndex + 1) % root.results.length;
                                    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                }
                            }

                            Keys.onUpPressed: {
                                if (root.results && root.results.length > 0) {
                                    root.selectedIndex = (root.selectedIndex - 1 + root.results.length) % root.results.length;
                                    resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                }
                            }

                            Keys.onReturnPressed: root.executeSelected()
                            Keys.onEnterPressed: root.executeSelected()
                        }

                        // Placeholder Text
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            color: Theme.notchTextSecondary
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.fontSize(15)
                            font.weight: Font.Normal
                            renderType: Theme.renderType
                            visible: searchInput.text.length === 0 && !searchInput.inputMethodComposing
                            text: I18n.isRTL
                                  ? "ابحث في التطبيقات، الإعدادات، الحساب..."
                                  : "Search applications, settings, calculate..."
                            elide: Text.ElideRight
                        }
                    }

                    // Clear button (visible when query present)
                    Rectangle {
                        visible: searchInput.text.length > 0
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: Theme.notchRadiusPill
                        color: clearMa.containsMouse ? Theme.notchSurfaceHover : "transparent"
                        Layout.alignment: Qt.AlignVCenter

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
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }

                    // ESC badge
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 24
                        radius: Theme.notchRadiusCard
                        color: Theme.notchSurface
                        border.color: Theme.notchBorderSubtle
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

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

            // ── Hairline Divider (visible only when expanding with results) ─
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.notchBorderSubtle
                visible: launcherCard.hasQuery
            }

            // ── Results List ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(launcherCard.maxResultRows, launcherCard.resultCount) * launcherCard.resultRowHeight + 10
                visible: launcherCard.hasQuery && launcherCard.resultCount > 0

                ListView {
                    id: resultsList
                    anchors.fill: parent
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 2
                    clip: true

                    model: root.results
                    currentIndex: root.selectedIndex

                    delegate: ResultRow {
                        width: resultsList.width
                        resultData: modelData
                        isSelected: index === root.selectedIndex

                        onClicked: {
                            root.selectedIndex = index;
                            root.executeItem(modelData);
                        }

                        onHovered: {
                            root.selectedIndex = index;
                        }
                    }
                }
            }

            // ── No Results State ──────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                visible: launcherCard.hasQuery && launcherCard.resultCount === 0

                Text {
                    anchors.centerIn: parent
                    // The query is isolated so its own punctuation ("c++", "hello!") stays
                    // with it instead of jumping to the other side of the quotes.
                    text: I18n.isRTL
                          ? ("لا توجد نتائج تطابق «" + I18n.isolate(root.filterQuery) + "»")
                          : ("No results matching \u201C" + I18n.isolate(root.filterQuery) + "\u201D")
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: Theme.fontSize(13)
                    font.weight: Font.Medium
                    color: Theme.notchTextSecondary
                    renderType: Theme.renderType
                }
            }
        }
    }
}
