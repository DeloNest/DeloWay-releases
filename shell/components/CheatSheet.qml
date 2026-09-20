import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
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
        color: Qt.rgba(0, 0, 0, 0.65)
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

            // 4 Columns Grid Container
            RowLayout {
                anchors.fill: parent
                spacing: Theme.space24

                // ── Column 1: Shell + Utilities ──────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_shell")
                        items: [
                            { keys: ["Super"], desc: "Toggle overview/launcher" },
                            { keys: ["Super", "V"], desc: "Clipboard history >> clipboard" },
                            { keys: ["Super", "Period"], desc: "Emoji >> clipboard" },
                            { keys: ["Super", "A"], desc: "Toggle left sidebar" },
                            { keys: ["Super", "N"], desc: "Toggle right sidebar" },
                            { keys: ["Super", "/"], desc: "Toggle cheatsheet" },
                            { keys: ["Super", "K"], desc: "Toggle on-screen keyboard" },
                            { keys: ["Super", "M"], desc: "Toggle media controls" },
                            { keys: ["Ctrl", "Alt", "Delete"], desc: "Toggle session menu" },
                            { keys: ["Ctrl", "Super", "T"], desc: "Change wallpaper" },
                            { keys: ["Ctrl", "Super", "R"], desc: "Restart widgets" }
                        ]
                    }

                    SectionBox {
                        title: I18n.tr("cs_utilities")
                        items: [
                            { keys: ["Super", "Shift", "S"], desc: "Screen snip" },
                            { keys: ["Super", "Shift", "C"], desc: "Pick color (Hex) >> clipboard" },
                            { keys: ["Print"], desc: "Screenshot >> clipboard" },
                            { keys: ["Ctrl", "Print"], desc: "Screenshot >> clipboard & file" },
                            { keys: ["Super", "Alt", "R"], desc: "Record region (no sound)" },
                            { keys: ["Super", "Shift", "Alt", "R"], desc: "Record screen (with sound)" },
                            { keys: ["Super", "Shift", "Alt", "RMB"], desc: "AI summary for selected text" }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Column 2: Window + Workspace ─────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_window")
                        items: [
                            { keys: ["Super", "LMB"], desc: "Move" },
                            { keys: ["Super", "RMB"], desc: "Resize" },
                            { keys: ["Super", "←/↑/→/↓"], desc: "Focus in direction" },
                            { keys: ["Super", "Shift", "←/↑/→/↓"], desc: "Move in direction" },
                            { keys: ["Super", "Q"], desc: "Close" },
                            { keys: ["Super", "Shift", "Alt", "Q"], desc: "Forcefully zap a window" },
                            { keys: ["Super", "; / '"], desc: "Adjust split ratio" },
                            { keys: ["Super", "Alt", "Space"], desc: "Float/Tile" },
                            { keys: ["Super", "D"], desc: "Maximize" },
                            { keys: ["Super", "F"], desc: "Fullscreen" },
                            { keys: ["Super", "Alt", "F"], desc: "Fullscreen spoof" },
                            { keys: ["Super", "P"], desc: "Pin" },
                            { keys: ["Super", "Alt", "#"], desc: "Send to workspace # (1, 2, 3,...)" },
                            { keys: ["Super", "Shift", "Page_↑/↓"], desc: "Send to workspace left/right" },
                            { keys: ["Super", "Alt", "S"], desc: "Send to scratchpad" }
                        ]
                    }

                    SectionBox {
                        title: I18n.tr("cs_workspace")
                        items: [
                            { keys: ["Super", "#"], desc: "Focus workspace # (1, 2, 3,...)" },
                            { keys: ["Ctrl", "Super", "←/→"], desc: "Focus left/right" },
                            { keys: ["Super", "Page_↑/↓"], desc: "Focus left/right" },
                            { keys: ["Super", "Scroll ↑/↓"], desc: "Focus left/right" },
                            { keys: ["Super", "S"], desc: "Toggle scratchpad" }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Column 3: Apps + Quick Launch ────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_apps")
                        items: [
                            { keys: ["Super", "Return"], desc: "Terminal (Kitty)" },
                            { keys: ["Super", "E"], desc: "File Manager (Thunar)" },
                            { keys: ["Super", "W"], desc: "Browser" },
                            { keys: ["Super", "C"], desc: "Code Editor" },
                            { keys: ["Super", "Shift", "W"], desc: "Office Suite" },
                            { keys: ["Super", "X"], desc: "Text Editor" },
                            { keys: ["Super", "I"], desc: "Deloway Settings" },
                            { keys: ["Ctrl", "Shift", "Escape"], desc: "System Monitor" },
                            { keys: ["Ctrl", "Super", "V"], desc: "Volume Control" }
                        ]
                    }

                    SectionBox {
                        title: I18n.tr("cs_general")
                        items: [
                            { keys: ["Super", "L"], desc: "Lock screen" },
                            { keys: ["Super", "Escape"], desc: "Dismiss notifications / panels" }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Column 4: Media & System Keys ────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.space16

                    SectionBox {
                        title: I18n.tr("cs_media")
                        items: [
                            { keys: ["XF86AudioMute"], desc: "Mute/unmute audio" },
                            { keys: ["XF86AudioLowerVolume"], desc: "Lower volume" },
                            { keys: ["XF86AudioRaiseVolume"], desc: "Raise volume" },
                            { keys: ["XF86AudioPlay"], desc: "Play/pause media" },
                            { keys: ["XF86AudioNext"], desc: "Next track" },
                            { keys: ["XF86AudioPrev"], desc: "Previous track" },
                            { keys: ["XF86MonBrightnessUp"], desc: "Increase display brightness" },
                            { keys: ["XF86MonBrightnessDown"], desc: "Decrease display brightness" }
                        ]
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ── Reusable Component: Section Box ──────────────────────────────────────
    component SectionBox: ColumnLayout {
        id: secRoot
        property string title: ""
        property var items: []

        Layout.fillWidth: true
        spacing: Theme.space8

        Text {
            text: secRoot.title
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

                // Key Combo (badges with '+' between them)
                RowLayout {
                    spacing: 3

                    Repeater {
                        model: rowDel.modelData.keys

                        delegate: RowLayout {
                            id: keyDel
                            required property string modelData
                            required property int index
                            spacing: 3

                            // Key Pill Badge
                            Rectangle {
                                implicitHeight: 22
                                implicitWidth: (keyDel.modelData === "Super" || keyDel.modelData === "Win")
                                               ? 26
                                               : Math.max(22, keyText.implicitWidth + Theme.space8)
                                radius: Theme.radiusSmall
                                color: Theme.colors.surfaceElevated
                                border.color: Theme.hairline
                                border.width: 1

                                // If Super key: render Windows logo
                                Item {
                                    anchors.centerIn: parent
                                    width: 11
                                    height: 11
                                    visible: keyDel.modelData === "Super" || keyDel.modelData === "Win"

                                    Grid {
                                        anchors.centerIn: parent
                                        columns: 2
                                        spacing: 1.5
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                width: 4
                                                height: 4
                                                radius: 0.8
                                                color: Theme.colors.text
                                            }
                                        }
                                    }
                                }

                                // Text for other keys
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    visible: keyDel.modelData !== "Super" && keyDel.modelData !== "Win"
                                    text: keyDel.modelData
                                    font.family: Theme.typography.fontFamily
                                    font.hintingPreference: Theme.hintingPreference
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    renderType: Theme.renderType
                                    color: Theme.colors.text
                                }
                            }

                            // '+' separator between keys
                            Text {
                                visible: keyDel.index < rowDel.modelData.keys.length - 1
                                text: "+"
                                font.family: Theme.typography.fontFamily
                                font.hintingPreference: Theme.hintingPreference
                                font.pixelSize: 11
                                font.weight: Font.Normal
                                renderType: Theme.renderType
                                color: Theme.colors.textTertiary
                            }
                        }
                    }
                }

                // Description Text
                Text {
                    Layout.fillWidth: true
                    text: rowDel.modelData.desc
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    renderType: Theme.renderType
                    color: Theme.colors.textSecondary
                    elide: Text.ElideRight
                }
            }
        }
    }
}
