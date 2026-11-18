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

    readonly property int screenMargin: 12
    readonly property int pointerX: DesktopManager.contextMenuX
    readonly property int pointerY: DesktopManager.contextMenuY

    // Smart horizontal placement:
    // In RTL, default to opening to the left of the cursor (pointerX - menuCard.width).
    // If it doesn't fit on the left, flip to opening to the right of the cursor (pointerX).
    // In LTR, default to opening to the right of the cursor (pointerX).
    // If it doesn't fit on the right, flip to opening to the left of the cursor.
    readonly property bool openToLeft: I18n.isRTL
        ? (pointerX - menuCard.width >= screenMargin || pointerX < root.width - menuCard.width - screenMargin)
        : (pointerX + menuCard.width > root.width - screenMargin && pointerX - menuCard.width >= screenMargin)

    // Smart vertical placement:
    // Default to opening downward. If overflowing the bottom edge, flip upward.
    readonly property bool openUpward: (pointerY + menuCard.height > root.height - screenMargin)
                                       && (pointerY - menuCard.height >= screenMargin)

    // Entrance / Exit controller
    Connections {
        target: DesktopManager
        function onContextMenuVisibleChanged() {
            if (root.shown) {
                root.triggerEntrance();
            } else {
                root.triggerExit();
            }
        }
        function onContextMenuRevisionChanged() {
            if (root.shown) {
                root.triggerEntrance();
            }
        }
    }

    function triggerEntrance() {
        exitAnim.stop();
        entranceAnim.stop();
        menuCard.scale = 0.90;
        menuCard.opacity = 0.0;
        entranceAnim.start();
    }

    function triggerExit() {
        entranceAnim.stop();
        exitAnim.start();
    }

    ParallelAnimation {
        id: entranceAnim
        NumberAnimation {
            target: menuCard
            property: "scale"
            from: 0.90
            to: 1.0
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: menuCard
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: menuCard
            property: "scale"
            to: 0.94
            duration: 90
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: menuCard
            property: "opacity"
            to: 0.0
            duration: 90
            easing.type: Easing.InQuad
        }
    }

    // Modern professional menu card
    Rectangle {
        id: menuCard
        // The reference width, grown for a longer row (Arabic labels + a switch), capped.
        width: Math.min(320, Math.max(228, menuCol.implicitWidth + 12))
        height: menuCol.implicitHeight + 12

        x: openToLeft
            ? Math.max(screenMargin, Math.min(root.width - width - screenMargin, pointerX - width))
            : Math.max(screenMargin, Math.min(root.width - width - screenMargin, pointerX))

        y: openUpward
            ? Math.max(screenMargin, Math.min(root.height - height - screenMargin, pointerY - height))
            : Math.max(screenMargin, Math.min(root.height - height - screenMargin, pointerY))

        // Dynamically anchored to the mouse click corner!
        transformOrigin: openUpward
            ? (openToLeft ? Item.BottomRight : Item.BottomLeft)
            : (openToLeft ? Item.TopRight : Item.TopLeft)

        radius: Theme.notchRadiusCard
        color: Theme.capsuleFill
        border.color: Theme.capsuleBorder
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.motionThemeFade; easing.type: Theme.easingTheme } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionThemeFade; easing.type: Theme.easingTheme } }

        LayoutMirroring.enabled: I18n.isRTL
        LayoutMirroring.childrenInherit: true

        scale: 0.90
        opacity: 0.0

        // Soft ambient elevation shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: Theme.notchShadow
            opacity: 0.65
            z: -1
        }

        // Top luminous rim highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 1
            color: Theme.notchBorderHighlight
            opacity: 0.55
        }

        // Clicks inside the card never reach the dismiss area
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

        ColumnLayout {
            id: menuCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
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
                    // LocalSend sends files only (deloway-localsend.py drops folders), so
                    // offering it on a folder or the Trash always ended in a failed transfer.
                    visible: root.onItem && !root.target.isDir
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
