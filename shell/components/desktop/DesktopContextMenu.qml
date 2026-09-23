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

    // Reusable Clean Fluent Context Menu Item
    component ContextMenuItem: Rectangle {
        id: cItem
        property string title: ""
        property string iconSource: ""
        property bool isUrgent: false
        property bool isCheckable: false
        property bool isChecked: false
        property bool hasSubmenu: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        radius: 6

        color: cItem.isChecked
               ? Theme.notchSurfaceElevated
               : (itemMouse.pressed ? Theme.notchSurfaceActive : (itemMouse.containsMouse ? Theme.notchSurfaceHover : "transparent"))
        border.color: itemMouse.containsMouse ? Theme.notchBorderSubtle : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 9

            SymbolicIcon {
                visible: cItem.iconSource.length > 0
                source: cItem.iconSource
                iconSize: 14
                iconColor: cItem.isUrgent
                           ? Theme.danger
                           : (itemMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
            }

            Text {
                Layout.fillWidth: true
                text: cItem.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(12)
                font.weight: cItem.isChecked ? Font.DemiBold : Font.Medium
                color: cItem.isUrgent
                       ? Theme.danger
                       : (itemMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                elide: Text.ElideRight
                renderType: Theme.renderType
            }

            // Checkmark for toggle items
            Text {
                visible: cItem.isCheckable && cItem.isChecked
                text: "✓"
                font.family: Theme.typography.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Theme.notchText
            }

            // Submenu chevron
            Text {
                visible: cItem.hasSubmenu
                text: I18n.isRTL ? "‹" : "›"
                font.family: Theme.typography.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: itemMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary
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

    // Modern Desktop Mode Selector Option
    component ModeOptionItem: Rectangle {
        id: mItem
        property string modeId: ""
        property string title: ""
        readonly property bool isActive: ConfigManager.desktopMode === modeId

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        radius: 6

        color: mItem.isActive
               ? Theme.notchSurfaceElevated
               : (mMouse.containsMouse ? Theme.notchSurfaceHover : "transparent")
        border.color: mItem.isActive
                      ? Theme.notchBorder
                      : (mMouse.containsMouse ? Theme.notchBorderSubtle : "transparent")
        border.width: 1

        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: mItem.title
                font.family: Theme.typography.fontFamily
                font.pixelSize: Theme.fontSize(11)
                font.weight: mItem.isActive ? Font.DemiBold : Font.Normal
                color: mItem.isActive ? Theme.notchText : (mMouse.containsMouse ? Theme.notchText : Theme.notchTextSecondary)
                elide: Text.ElideRight
                renderType: Theme.renderType
            }

            // Minimalist active dot / check
            Text {
                visible: mItem.isActive
                text: "✓"
                font.family: Theme.typography.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Theme.notchText
            }
        }

        MouseArea {
            id: mMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                ConfigManager.setDesktopMode(mItem.modeId);
                DesktopManager.closeContextMenu();
            }
        }
    }

    // Outer card: flat OLED surface, 1px border (no shadow or glow)
    Rectangle {
        id: menuCard
        x: Math.max(12, Math.min(DesktopManager.contextMenuX, root.width - width - 12))
        y: Math.max(12, Math.min(DesktopManager.contextMenuY, root.height - height - 12))
        width: 232
        implicitHeight: menuCol.implicitHeight + 14
        radius: 12
        color: Theme.notchBackground
        border.color: Theme.notchBorderSubtle
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        // Smooth fade & scale entrance
        opacity: DesktopManager.contextMenuVisible ? 1.0 : 0.0
        scale: DesktopManager.contextMenuVisible ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

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
            anchors.topMargin: 7
            anchors.bottomMargin: 7
            spacing: 2

            // ====================================================
            // SCENARIO A: WALLPAPER CONTEXT MENU
            // ====================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: DesktopManager.contextMenuTargetItem === null

                ContextMenuItem {
                    title: I18n.isRTL ? "مجلد جديد" : "New Folder"
                    iconSource: "folder"
                    onTriggered: {
                        DesktopManager.createFolder(I18n.isRTL ? "مجلد جديد" : "New Folder");
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "مستند نصي جديد" : "New Text Document"
                    iconSource: "document"
                    onTriggered: {
                        DesktopManager.createDocument(I18n.isRTL ? "مستند جديد.txt" : "New Document.txt");
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "فتح في الطرفية" : "Open Terminal Here"
                    iconSource: "utilities-terminal"
                    onTriggered: {
                        DesktopManager.openTerminalHere();
                        DesktopManager.closeContextMenu();
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 3
                    Layout.bottomMargin: 3
                    color: Theme.notchBorderSubtle
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "ترتيب الأيقونات تلقائياً" : "Auto-Arrange Icons"
                    iconSource: "view-grid"
                    onTriggered: {
                        DesktopManager.autoArrangeIcons(root.width, root.height);
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "المحاذاة للشبكة" : "Align to Grid"
                    isCheckable: true
                    isChecked: DesktopManager.snapToGrid
                    onTriggered: {
                        DesktopManager.snapToGrid = !DesktopManager.snapToGrid;
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 3
                    Layout.bottomMargin: 3
                    color: Theme.notchBorderSubtle
                }

                // Desktop Mode Sub-header
                Text {
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.topMargin: 2
                    Layout.bottomMargin: 1
                    text: I18n.isRTL ? "وضع سطح المكتب" : "DESKTOP MODE"
                    font.family: Theme.typography.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.notchTextTertiary
                    renderType: Theme.renderType
                }

                ModeOptionItem {
                    modeId: "traditional"
                    title: I18n.isRTL ? "أيقونات حرة (تقليدي)" : "Free Icons (Traditional)"
                }

                ModeOptionItem {
                    modeId: "widgets"
                    title: I18n.isRTL ? "ودجات ذكية" : "Smart Widgets"
                }

                ModeOptionItem {
                    modeId: "clean"
                    title: I18n.isRTL ? "نظيف (خلفية فقط)" : "Clean (Wallpaper Only)"
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 3
                    Layout.bottomMargin: 3
                    color: Theme.notchBorderSubtle
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "تغيير الخلفية..." : "Change Wallpaper..."
                    iconSource: "image"
                    onTriggered: {
                        ShellState.openSettingsTab("appearance");
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "إعدادات سطح المكتب..." : "Desktop Settings..."
                    iconSource: "settings"
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
                    Layout.preferredHeight: 36
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    Layout.bottomMargin: 2
                    radius: 6
                    color: Theme.notchSurface
                    border.color: Theme.notchBorderSubtle
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        AppIcon {
                            iconSize: 22
                            source: DesktopManager.contextMenuTargetItem ? DesktopManager.contextMenuTargetItem.icon : "folder"
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: DesktopManager.contextMenuTargetItem ? DesktopManager.contextMenuTargetItem.name : ""
                            font.family: Theme.typography.fontFamily
                            font.pixelSize: Theme.fontSize(11)
                            font.weight: Font.DemiBold
                            color: Theme.notchText
                            renderType: Theme.renderType
                        }
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "فتح" : "Open"
                    iconSource: "document-open"
                    onTriggered: {
                        DesktopManager.openItem(DesktopManager.contextMenuTargetItem);
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "مشاركة عبر LocalSend..." : "Share via LocalSend..."
                    iconSource: "send"
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem && DesktopManager.contextMenuTargetItem.path) {
                            ShellState.setSmartNotchTab(1);
                            ShellState.openSmartNotch();
                            LocalSendService.stageFiles([DesktopManager.contextMenuTargetItem.path]);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    title: I18n.isRTL ? "تثبيت في الشريط (Dock)" : "Pin to Dock"
                    iconSource: "view-paged"
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem) {
                            ApplicationManager.togglePin(DesktopManager.contextMenuTargetItem.id);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                ContextMenuItem {
                    visible: DesktopManager.contextMenuTargetItem && !DesktopManager.contextMenuTargetItem.isSystem
                    title: I18n.isRTL ? "إعادة تسمية..." : "Rename..."
                    iconSource: "edit-rename"
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem) {
                            DesktopManager.startRenaming(DesktopManager.contextMenuTargetItem.id);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                // Separator
                Rectangle {
                    visible: DesktopManager.contextMenuTargetItem && !DesktopManager.contextMenuTargetItem.isSystem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    color: Theme.notchBorderSubtle
                }

                ContextMenuItem {
                    visible: DesktopManager.contextMenuTargetItem && !DesktopManager.contextMenuTargetItem.isSystem
                    title: I18n.isRTL ? "نقل إلى سلة المحذوفات" : "Move to Trash"
                    iconSource: "user-trash"
                    isUrgent: true
                    onTriggered: {
                        if (DesktopManager.contextMenuTargetItem) {
                            DesktopManager.moveToTrash(DesktopManager.contextMenuTargetItem);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }

                // Permanent deletion: the first click arms, the second confirms.
                ContextMenuItem {
                    id: emptyTrashItem
                    property bool armed: false
                    visible: DesktopManager.contextMenuTargetItem && DesktopManager.contextMenuTargetItem.isTrash
                    title: armed ? (I18n.isRTL ? "تأكيد: حذف كل ما في السلة نهائياً" : "Confirm: permanently delete all")
                                 : (I18n.isRTL ? "تفريغ سلة المحذوفات" : "Empty Trash")
                    iconSource: "user-trash"
                    isUrgent: true
                    onTriggered: {
                        if (!armed) { armed = true; return; }
                        armed = false;
                        DesktopManager.emptyTrash();
                        DesktopManager.closeContextMenu();
                    }
                    Connections {
                        target: DesktopManager
                        function onContextMenuVisibleChanged() { emptyTrashItem.armed = false; }
                    }
                }
            }
        }
    }
}
