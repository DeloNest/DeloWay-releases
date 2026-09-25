import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../services"
import "../"
import "../menu"

// The desktop's right-click menu, in its own surface on the Top layer.
// It used to be drawn inside the wallpaper surface (Background layer), i.e. below every
// window: a menu opened next to a window slid under it, a click inside a window did not
// close it, Escape did nothing, and with several monitors it opened on all of them.
// One per screen; only the screen the menu was opened on shows it. While open, the
// transparent full-screen surface takes the click that dismisses it.
PanelWindow {
    id: root

    required property ShellScreen targetScreen
    screen: targetScreen

    readonly property bool shown: DesktopManager.contextMenuVisible
                                  && !!targetScreen && DesktopManager.contextMenuScreen === targetScreen.name

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: root.shown || menuCard.opacity > 0.01

    WlrLayershell.namespace: "deloway:desktop-menu"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Escape closes, like every other menu
    Item {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: DesktopManager.closeContextMenu()
    }

    // Dismiss on any click outside the card (either button), over windows too
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.ArrowCursor
        onClicked: DesktopManager.closeContextMenu()
        onWheel: function(wheel) { wheel.accepted = true; }
    }

    readonly property var target: DesktopManager.contextMenuTargetItem
    readonly property bool onItem: target !== null && target !== undefined

    // Same card as AppContextMenu: opaque, radiusLarge, 1px border, no shadow; fades in
    // with a short slide.
    Rectangle {
        id: menuCard
        // The reference width, grown for a longer row (Arabic labels + a switch), capped.
        width: Math.min(320, Math.max(228, menuCol.implicitWidth + 10))
        height: menuCol.implicitHeight + 10
        // Opens toward the reading end of the pointer (left of it in Arabic).
        x: Math.max(12, Math.min(I18n.isRTL ? DesktopManager.contextMenuX - width : DesktopManager.contextMenuX, root.width - width - 12))
        y: Math.max(12, Math.min(DesktopManager.contextMenuY, root.height - height - 12))
        radius: Theme.radiusLarge
        color: Theme.notchBackground
        border.color: Theme.notchBorder
        border.width: 1

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        opacity: root.shown ? 1.0 : 0.0
        transform: Translate {
            y: root.shown ? 0 : -3
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        // Clicks inside the card never reach the dismiss area
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

        ColumnLayout {
            id: menuCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 5
            spacing: 0

            // ── On the desktop itself ───────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: !root.onItem

                MenuItem {
                    text: I18n.isRTL ? "مجلد جديد" : "New Folder"
                    icon: "folder-new-symbolic"
                    onTriggered: {
                        DesktopManager.createFolder(I18n.isRTL ? "مجلد جديد" : "New Folder");
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    text: I18n.isRTL ? "مستند نصي جديد" : "New Text Document"
                    icon: "document-new-symbolic"
                    onTriggered: {
                        DesktopManager.createDocument(I18n.isRTL ? "مستند جديد.txt" : "New Document.txt");
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    text: I18n.isRTL ? "فتح في الطرفية" : "Open Terminal Here"
                    icon: "utilities-terminal-symbolic"
                    onTriggered: {
                        DesktopManager.openTerminalHere();
                        DesktopManager.closeContextMenu();
                    }
                }

                // Arranging applies to desktop icons only: shown while they are.
                readonly property bool iconsShown: ConfigManager.showDesktopContent && ConfigManager.desktopMode === "traditional"

                MenuSeparator { visible: parent.iconsShown }

                MenuItem {
                    visible: parent.iconsShown
                    text: I18n.isRTL ? "ترتيب الأيقونات تلقائياً" : "Auto-Arrange Icons"
                    icon: "view-app-grid-symbolic"
                    onTriggered: {
                        DesktopManager.autoArrangeIcons(root.width, root.height);
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    visible: parent.iconsShown
                    text: I18n.isRTL ? "المحاذاة للشبكة" : "Align to Grid"
                    icon: "snap-symbolic"
                    toggle: true
                    checked: DesktopManager.snapToGrid
                    onTriggered: ConfigManager.setDesktopSnapToGrid(!ConfigManager.desktopSnapToGrid)
                }

                MenuSeparator {}

                // One switch: the desktop with its items (icons or widgets), or empty.
                MenuItem {
                    text: I18n.isRTL ? "إظهار عناصر سطح المكتب" : "Show Desktop Items"
                    icon: ConfigManager.showDesktopContent ? "view-reveal-symbolic" : "view-conceal-symbolic"
                    toggle: true
                    checked: ConfigManager.showDesktopContent
                    onTriggered: ConfigManager.setShowDesktopContent(!ConfigManager.showDesktopContent)
                }

                MenuSeparator {}

                MenuItem {
                    text: I18n.isRTL ? "تغيير الخلفية…" : "Change Wallpaper…"
                    icon: "preferences-desktop-wallpaper-symbolic"
                    onTriggered: {
                        ShellState.openSettingsTab("wallpaper");
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    text: I18n.isRTL ? "إعدادات سطح المكتب…" : "Desktop Settings…"
                    icon: "preferences-desktop-symbolic"
                    onTriggered: {
                        ShellState.openSettingsTab("desktop");
                        DesktopManager.closeContextMenu();
                    }
                }
            }

            // ── On a desktop item ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: root.onItem

                MenuHeader {
                    icon: root.onItem ? root.target.icon : "folder"
                    title: root.onItem ? root.target.name : ""
                }
                MenuSeparator {}

                MenuItem {
                    text: I18n.isRTL ? "فتح" : "Open"
                    icon: "document-open-symbolic"
                    onTriggered: {
                        DesktopManager.openItem(root.target);
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    text: I18n.isRTL ? "مشاركة عبر LocalSend…" : "Share via LocalSend…"
                    icon: "document-send-symbolic"
                    onTriggered: {
                        if (root.onItem && root.target.path) {
                            ShellState.setSmartNotchTab(2);   // Share tab
                            ShellState.openSmartNotch();
                            LocalSendService.stageFiles([root.target.path]);
                        }
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    // Only .desktop shortcuts map to an installed app; pin that app's real id
                    // (the desktop item id "user_…" could never be pinned).
                    readonly property var targetApp: {
                        const it = root.target;
                        if (!it || !it.isDesktopEntry || !it.fileName) return null;
                        return ApplicationManager.findApp(it.fileName.replace(/\.desktop$/, ""));
                    }
                    visible: targetApp !== null
                    text: (targetApp && ApplicationManager.isPinned(targetApp.id))
                          ? (I18n.isRTL ? "إلغاء التثبيت من الشريط" : "Unpin from Dock")
                          : (I18n.isRTL ? "تثبيت في الشريط" : "Pin to Dock")
                    icon: "view-pin-symbolic"
                    onTriggered: {
                        if (targetApp) ApplicationManager.togglePin(targetApp.id);
                        DesktopManager.closeContextMenu();
                    }
                }
                MenuItem {
                    visible: root.onItem && !root.target.isSystem
                    text: I18n.isRTL ? "إعادة تسمية…" : "Rename…"
                    icon: "edit-rename-symbolic"
                    onTriggered: {
                        if (root.onItem) DesktopManager.startRenaming(root.target.id);
                        DesktopManager.closeContextMenu();
                    }
                }

                MenuSeparator { visible: root.onItem && (!root.target.isSystem || root.target.isTrash) }

                MenuItem {
                    visible: root.onItem && !root.target.isSystem
                    text: I18n.isRTL ? "نقل إلى سلة المحذوفات" : "Move to Trash"
                    icon: "user-trash-symbolic"
                    onTriggered: {
                        if (root.onItem) DesktopManager.moveToTrash(root.target);
                        DesktopManager.closeContextMenu();
                    }
                }
                // Permanent deletion: the first click arms, the second confirms.
                MenuItem {
                    id: emptyTrashItem
                    property bool armed: false
                    visible: root.onItem && !!root.target.isTrash
                    text: armed ? (I18n.isRTL ? "تأكيد: حذف كل ما في السلة نهائياً" : "Confirm: permanently delete all")
                                : (I18n.isRTL ? "تفريغ سلة المحذوفات" : "Empty Trash")
                    icon: "user-trash-symbolic"
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
