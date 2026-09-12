import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme"
import "../../services"
import "../"

Item {
    id: root

    anchors.fill: parent
    visible: DesktopManager.contextMenuVisible

    // Dismiss context menu on clicking outside
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: DesktopManager.closeContextMenu()
        onWheel: function(wheel) { wheel.accepted = true; }
    }

    // Reusable High-Fidelity Context Menu Item
    component ContextMenuItem: Rectangle {
        id: cItem
        property string title: ""
        property string iconSource: ""
        property color iconColor: Theme.colors.textSecondary
        property bool isUrgent: false
        property bool isSelected: false
        property bool hasSubmenu: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        radius: Theme.radiusSmall

        color: cItem.isSelected ? Qt.alpha(Theme.colors.primary, 0.18) : (itemMouse.pressed ? Theme.colors.surfaceActive : (itemMouse.containsMouse ? Theme.colors.surfaceHover : "transparent"))
        border.color: cItem.isSelected ? Qt.alpha(Theme.colors.primary, 0.45) : (itemMouse.containsMouse ? Theme.colors.borderHighlight : "transparent")
        border.width: 1

        scale: itemMouse.pressed ? 0.98 : 1.0
        transform: Translate {
            x: itemMouse.containsMouse ? (I18n.isRTL ? -3 : 3) : 0
            Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        }
        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            SymbolicIcon {
                source: cItem.iconSource
                iconSize: 15
                iconColor: cItem.isUrgent ? (itemMouse.containsMouse ? Theme.colors.urgent : Qt.alpha(Theme.colors.urgent, 0.85)) : (itemMouse.containsMouse ? Theme.colors.accent : cItem.iconColor)
                scale: itemMouse.containsMouse ? 1.10 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
            }

            Text {
                Layout.fillWidth: true
                text: cItem.title
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: Theme.typography.scaleBody.size
                font.weight: itemMouse.containsMouse ? Font.DemiBold : (cItem.isSelected ? Font.Medium : Font.Normal)
                renderType: Theme.renderType
                color: cItem.isUrgent ? Theme.colors.urgent : (itemMouse.containsMouse ? Theme.colors.text : (cItem.isSelected ? Theme.colors.primary : Theme.colors.text))
                elide: Text.ElideRight
            }

            Text {
                visible: cItem.hasSubmenu
                text: "›"
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: 14
                font.weight: Font.DemiBold
                renderType: Theme.renderType
                color: itemMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                cItem.triggered();
            }
        }
    }

    // Reusable Desktop Mode Radio Option
    component ModeRadioItem: Rectangle {
        id: rItem
        property string modeId: ""
        property string title: ""
        property bool isActive: ConfigManager.desktopMode === modeId

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        radius: Theme.radiusSmall

        color: rItem.isActive ? Qt.alpha(Theme.colors.primary, 0.16) : (rMouse.pressed ? Theme.colors.surfaceActive : (rMouse.containsMouse ? Theme.colors.surfaceHover : "transparent"))
        border.color: rItem.isActive ? Qt.alpha(Theme.colors.primary, 0.35) : (rMouse.containsMouse ? Theme.colors.borderHighlight : "transparent")
        border.width: 1

        scale: rMouse.pressed ? 0.98 : 1.0
        transform: Translate {
            x: rMouse.containsMouse ? (I18n.isRTL ? -3 : 3) : 0
            Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        }
        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        Behavior on color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast; easing.type: Theme.easingEnter } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            // Radio dot indicator
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: rItem.isActive ? Theme.colors.primary : "transparent"
                border.color: rItem.isActive ? Theme.colors.primary : Theme.colors.borderSubtle
                border.width: 1.5

                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.colors.accentText
                    visible: rItem.isActive
                }
            }

            Text {
                Layout.fillWidth: true
                text: rItem.title
                font.family: Theme.typography.fontFamily
                font.hintingPreference: Theme.hintingPreference
                font.pixelSize: Theme.typography.scaleBody.size
                font.weight: rItem.isActive ? Font.DemiBold : (rMouse.containsMouse ? Font.Medium : Font.Normal)
                renderType: Theme.renderType
                color: rItem.isActive ? Theme.colors.primary : (rMouse.containsMouse ? Theme.colors.text : Theme.colors.textSecondary)
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                ConfigManager.setDesktopMode(rItem.modeId);
                DesktopManager.closeContextMenu();
            }
        }
    }

    Rectangle {
        id: menuCard
        x: DesktopManager.contextMenuX
        y: DesktopManager.contextMenuY
        width: 236
        implicitHeight: menuCol.implicitHeight + 16
        radius: Theme.radiusMedium
        color: Qt.alpha(Theme.colors.surface, 0.95)
        border.color: Theme.colors.border
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Subtle drop shadow illusion
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: Theme.radiusMedium + 1
            color: "transparent"
            border.color: Theme.hairline
            border.width: 1
            z: -1
        }

        // Prevent clicks inside menu from closing it
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: menuCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            spacing: 2

            // ====================================================
            // SCENARIO A: WALLPAPER CONTEXT MENU
            // ====================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: DesktopManager.contextMenuTargetItem === null

                ContextMenuItem {
                    title: "New Folder"
                    iconSource: "user-home-symbolic"
                    iconColor: Theme.colors.primary
                    onTriggered: {
                        DesktopManager.createFolder("New Folder");
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: "New Text Document"
                    iconSource: "applications-office-symbolic"
                    onTriggered: {
                        DesktopManager.createDocument("New Document.txt");
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: "Open in Terminal"
                    iconSource: "applications-development-symbolic"
                    onTriggered: {
                        DesktopManager.openTerminalHere();
                        DesktopManager.closeContextMenu();
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    color: Theme.colors.borderSubtle
                }

                // Desktop Mode Sub-header
                Text {
                    Layout.leftMargin: 14
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    text: "DESKTOP MODE"
                    font.family: Theme.typography.fontFamily
                    font.hintingPreference: Theme.hintingPreference
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    renderType: Theme.renderType
                    color: Theme.colors.textTertiary
                }

                ModeRadioItem {
                    modeId: "clean"
                    title: "Clean (Wallpaper Only)"
                }

                ModeRadioItem {
                    modeId: "widgets"
                    title: "Widgets (Movable Cards)"
                }

                ModeRadioItem {
                    modeId: "traditional"
                    title: "Traditional (Icons Grid)"
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    color: Theme.colors.borderSubtle
                }

                ContextMenuItem {
                    title: "Change Wallpaper..."
                    iconSource: "applications-graphics-symbolic"
                    onTriggered: {
                        ShellState.openSettingsTab("appearance");
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: "Desktop Settings..."
                    iconSource: "preferences-system-symbolic"
                    onTriggered: {
                        ShellState.openSettingsTab("desktop");
                        DesktopManager.closeContextMenu();
                    }
                }
            }

            // ====================================================
            // SCENARIO B: ITEM / FILE CONTEXT MENU
            // ====================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: DesktopManager.contextMenuTargetItem !== null

                // Item Header Preview
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    radius: 8
                    color: Theme.colors.surfaceVariant
                    border.color: Theme.colors.borderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        AppIcon {
                            iconSize: 24
                            source: DesktopManager.contextMenuTargetItem ? DesktopManager.contextMenuTargetItem.icon : "folder"
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: DesktopManager.contextMenuTargetItem ? DesktopManager.contextMenuTargetItem.name : ""
                            font.family: Theme.typography.fontFamily
                            font.hintingPreference: Theme.hintingPreference
                            font.pixelSize: Theme.typography.scaleBody.size
                            font.weight: Font.DemiBold
                            renderType: Theme.renderType
                            color: Theme.colors.text
                        }
                    }
                }

                ContextMenuItem {
                    title: "Open"
                    iconSource: "document-open-symbolic"
                    iconColor: Theme.colors.accent
                    onTriggered: {
                        DesktopManager.openItem(DesktopManager.contextMenuTargetItem);
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: "Pin to Dock"
                    iconSource: "view-paged-symbolic"
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem) {
                            ApplicationManager.togglePin(DesktopManager.contextMenuTargetItem.id);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    visible: DesktopManager.contextMenuTargetItem && !DesktopManager.contextMenuTargetItem.isSystem
                    title: "Rename..."
                    iconSource: "edit-rename-symbolic"
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem) {
                            DesktopManager.startRenaming(DesktopManager.contextMenuTargetItem.id);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    visible: DesktopManager.contextMenuTargetItem && !DesktopManager.contextMenuTargetItem.isSystem
                    title: "Move to Trash"
                    iconSource: "user-trash-symbolic"
                    isUrgent: true
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem) {
                            DesktopManager.moveToTrash(DesktopManager.contextMenuTargetItem);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    visible: DesktopManager.contextMenuTargetItem && DesktopManager.contextMenuTargetItem.isTrash
                    title: "Empty Trash"
                    iconSource: "user-trash-symbolic"
                    isUrgent: true
                    onTriggered: {
                        DesktopManager.emptyTrash();
                        DesktopManager.closeContextMenu();
                    }
                }
            }
        }
    }
}
