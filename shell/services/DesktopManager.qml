pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Item {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || "/home"
    readonly property string desktopDir: homeDir + "/Desktop"
    readonly property string trashFilesDir: homeDir + "/.local/share/Trash/files"
    readonly property string trashInfoDir: homeDir + "/.local/share/Trash/info"

    // ----------------------------------------------------
    // TRASH & FILE SYSTEM STATE
    // ----------------------------------------------------
    property bool isTrashEmpty: true

    // System default endpoints with unified Reversal amber icons
    readonly property var systemItems: [
        {
            "id": "home",
            "name": "Home",
            "icon": "user-home",
            "path": root.homeDir,
            "isSystem": true,
            "isTrash": false,
            "isDir": true
        },
        {
            "id": "trash",
            "name": "Trash",
            "icon": root.isTrashEmpty ? "user-trash" : "user-trash",
            "path": "trash://",
            "isSystem": true,
            "isTrash": true,
            "isDir": true
        },
        {
            "id": "projects",
            "name": "Projects",
            "icon": "folder-development",
            "path": root.homeDir + "/Projects",
            "isSystem": true,
            "isTrash": false,
            "isDir": true
        },
        {
            "id": "media",
            "name": "Videos",
            "icon": "folder-videos",
            "path": root.homeDir + "/Videos",
            "isSystem": true,
            "isTrash": false,
            "isDir": true
        },
        {
            "id": "downloads",
            "name": "Downloads",
            "icon": "folder-download",
            "path": root.homeDir + "/Downloads",
            "isSystem": true,
            "isTrash": false,
            "isDir": true
        }
    ]

    // User created files and folders on ~/Desktop
    property var userItems: []

    // Combined items array
    readonly property var allItems: systemItems.concat(userItems)

    // Selection management
    property var selectedItemIds: []
    property string editingItemId: ""

    // Context Menu State
    property bool contextMenuVisible: false
    property real contextMenuX: 0
    property real contextMenuY: 0
    property var contextMenuTargetItem: null // null = desktop wallpaper, object = specific item

    // ----------------------------------------------------
    // SELECTION HELPERS
    // ----------------------------------------------------
    function isItemSelected(id) {
        return selectedItemIds.includes(id);
    }

    function selectItem(id, isMulti) {
        if (isMulti) {
            var arr = selectedItemIds.slice();
            var idx = arr.indexOf(id);
            if (idx >= 0) {
                arr.splice(idx, 1);
            } else {
                arr.push(id);
            }
            selectedItemIds = arr;
        } else {
            selectedItemIds = [id];
        }
    }

    function clearSelection() {
        selectedItemIds = [];
        editingItemId = "";
    }

    // ----------------------------------------------------
    // CONTEXT MENU TRIGGERS
    // ----------------------------------------------------
    function showWallpaperContextMenu(x, y) {
        contextMenuTargetItem = null;
        contextMenuX = Math.min(x, 1920 - 240);
        contextMenuY = Math.min(y, 1080 - 320);
        contextMenuVisible = true;
    }

    function showItemContextMenu(item, x, y) {
        contextMenuTargetItem = item;
        if (!selectedItemIds.includes(item.id)) {
            selectedItemIds = [item.id];
        }
        contextMenuX = Math.min(x, 1920 - 240);
        contextMenuY = Math.min(y, 1080 - 280);
        contextMenuVisible = true;
    }

    function closeContextMenu() {
        contextMenuVisible = false;
        contextMenuTargetItem = null;
    }

    // ----------------------------------------------------
    // ACTIONS & LAUNCHERS
    // ----------------------------------------------------
    function openItem(item) {
        if (!item) return;
        if (item.isTrash) {
            Hyprland.dispatch("exec thunar trash://");
        } else if (item.path) {
            Hyprland.dispatch("exec xdg-open '" + item.path + "'");
        }
    }

    function openTerminalHere(dirPath) {
        const target = dirPath || root.desktopDir;
        Hyprland.dispatch("exec kitty --directory '" + target + "'");
    }

    function createFolder(folderName) {
        const name = (folderName && folderName.trim().length > 0) ? folderName.trim() : "New Folder";
        mkdirProcess.exec(["mkdir", "-p", root.desktopDir + "/" + name]);
    }

    function createDocument(fileName) {
        const name = (fileName && fileName.trim().length > 0) ? fileName.trim() : "New Document.txt";
        touchProcess.exec(["touch", root.desktopDir + "/" + name]);
    }

    function renameItem(item, newName) {
        if (!item || !newName || item.name === newName) {
            editingItemId = "";
            return;
        }
        if (item.isSystem) {
            // System folders cannot be physically renamed
            editingItemId = "";
            return;
        }
        const oldP = item.path;
        const newP = root.desktopDir + "/" + newName.trim();
        renameProcess.exec(["mv", oldP, newP]);
        editingItemId = "";
    }

    function moveToTrash(item) {
        if (!item || item.isSystem) return;
        trashProcess.exec(["gio", "trash", item.path]);
    }

    function emptyTrash() {
        emptyTrashProcess.exec(["bash", "-c", "rm -rf " + root.trashFilesDir + "/* " + root.trashInfoDir + "/*"]);
    }

    function startRenaming(id) {
        editingItemId = id;
    }

    // ----------------------------------------------------
    // BACKGROUND SCANNING & PROCESSES
    // ----------------------------------------------------
    Process {
        id: checkTrashProcess
        stdout: SplitParser {
            onRead: function(data) {
                root.isTrashEmpty = (data.trim() === "empty");
            }
        }
    }

    Process {
        id: mkdirProcess
        onExited: refreshDesktop()
    }

    Process {
        id: touchProcess
        onExited: refreshDesktop()
    }

    Process {
        id: renameProcess
        onExited: refreshDesktop()
    }

    Process {
        id: trashProcess
        onExited: refreshDesktop()
    }

    Process {
        id: emptyTrashProcess
        onExited: {
            root.isTrashEmpty = true;
            refreshDesktop();
        }
    }

    Process {
        id: listDesktopProcess
        stdout: SplitParser {
            onRead: function(line) {
                const trimmed = line.trim();
                if (trimmed.length > 0) {
                    const fullP = root.desktopDir + "/" + trimmed;
                    const isDir = !trimmed.includes(".");
                    const newItem = {
                        "id": "user_" + trimmed.replace(/[^a-zA-Z0-9]/g, "_"),
                        "name": trimmed,
                        "icon": isDir ? "folder" : "text-plain",
                        "path": fullP,
                        "isSystem": false,
                        "isTrash": false,
                        "isDir": isDir
                    };
                    var copy = root.userItems.slice();
                    if (!copy.some(i => i.path === fullP)) {
                        copy.push(newItem);
                        root.userItems = copy;
                    }
                }
            }
        }
    }

    function refreshDesktop() {
        root.userItems = [];
        listDesktopProcess.exec(["bash", "-c", "mkdir -p " + root.desktopDir + " && ls -1 " + root.desktopDir]);
        checkTrashProcess.exec(["bash", "-c", "[ -d " + root.trashFilesDir + " ] && [ $(ls -A " + root.trashFilesDir + " 2>/dev/null | wc -l) -gt 0 ] && echo 'full' || echo 'empty'"]);
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: refreshDesktop()
    }

    Component.onCompleted: {
        refreshDesktop();
    }
}
