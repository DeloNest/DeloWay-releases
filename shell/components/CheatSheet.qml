import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

PanelWindow {
    id: root
    // Descriptions follow the UI language; every row mirrors a real bind in config/hyprland.conf.
    function t(ar, en) { return I18n.isRTL ? ar : en; }

    required property ShellScreen targetScreen
    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "deloway:cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.cheatSheetOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    visible: ShellState.cheatSheetOpen || cheatSheetCard.opacity > 0.01

    Shortcut {
        sequence: "Escape"
        enabled: ShellState.cheatSheetOpen
        onActivated: ShellState.closeCheatSheet()
    }

    Shortcut {
        sequence: "Super+/"
        enabled: ShellState.cheatSheetOpen
        onActivated: ShellState.closeCheatSheet()
    }

    Shortcut {
        sequence: "Super+Shift+/"
        enabled: ShellState.cheatSheetOpen
        onActivated: ShellState.closeCheatSheet()
    }

    // Dimmed Backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.modalScrim
        opacity: ShellState.cheatSheetOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.closeCheatSheet()
        }
    }

    // Main Window with DeloWindowChrome
    DeloWindowChrome {
        id: cheatSheetCard
        anchors.centerIn: parent
        width: Math.min(1360, parent.width - Theme.space48)
        height: Math.min(780, parent.height - Theme.space48)
        title: I18n.tr("cs_title")
        iconSource: "help-browser-symbolic"
        showCloseButton: true
        onCloseClicked: ShellState.closeCheatSheet()

        opacity: ShellState.cheatSheetOpen ? 1.0 : 0.0
        scale: ShellState.cheatSheetOpen ? 1.0 : 0.95
        Behavior on opacity { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }
        Behavior on scale { NumberAnimation { duration: Theme.motionBase; easing.type: Theme.easingEnter } }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Prevent dismiss on card click
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.space24

            // Four columns of groups. The shortcuts come from ShortcutService — the catalog
            // Hyprland's binds are generated from, with the user's changes — so the guide
            // always shows what is bound now (it used to be a hand-written list that had
            // drifted: it said Super + A opened the app drawer).
            RowLayout {
                anchors.fill: parent
                spacing: Theme.space24

                Repeater {
                    model: [["shell", "tools"], ["windows"], ["apps", "session", "workspaces"], ["media"]]

                    delegate: ColumnLayout {
                        id: column
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.space16

                        Repeater {
                            model: column.modelData
                            delegate: SectionBox {
                                required property string modelData
                                groupId: modelData
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    // ── One group: its title and its shortcuts ───────────────────────────────
    component SectionBox: ColumnLayout {
        id: secRoot
        property string groupId: ""
        readonly property var group: ShortcutService.groups.find(g => g.id === secRoot.groupId) || null
        readonly property var items: ShortcutService.actions.filter(a => a.group === secRoot.groupId
                                                                       && a.binds.length > 0)

        visible: group !== null && items.length > 0
        Layout.fillWidth: true
        spacing: Theme.space8

        Text {
            text: secRoot.group ? (I18n.isRTL ? secRoot.group.ar : secRoot.group.en) : ""
            font.family: Theme.typography.fontFamily
            font.hintingPreference: Theme.hintingPreference
            font.pixelSize: Theme.typography.scaleTitle.size
            font.weight: Font.DemiBold
            renderType: Theme.renderType
            color: Theme.colors.text
        }

        Repeater {
            model: secRoot.items

            delegate: RowLayout {
                id: rowDel
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.space8

                // Written left-to-right in both languages (Super + Shift + S); the row
                // itself mirrors, so the combination sits at the reading start.
                KeyCombo { keys: ShortcutService.actionKeys(rowDel.modelData) }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft   // reading start in both languages
                    text: ShortcutService.label(rowDel.modelData)
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: Theme.fontSize(11)
                    font.weight: Font.Normal
                    renderType: Theme.renderType
                    color: Theme.colors.textSecondary
                    elide: Text.ElideRight
                }
            }
        }
    }
}
