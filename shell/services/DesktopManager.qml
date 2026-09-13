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
        } else if (item.isDesktopEntry && item.path) {
            Hyprland.dispatch("exec gio launch '" + item.path + "'");
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

    function getFileIcon(filename) {
        if (!filename) return "text-x-generic";
        const dot = filename.lastIndexOf(".");
        if (dot === -1) return "text-x-generic";
        const ext = filename.substring(dot + 1).toLowerCase();

        // 1. Images
        if (["png", "jpg", "jpeg", "svg", "webp", "gif", "bmp", "ico"].includes(ext)) {
            const imgCandidates = ["image-x-generic", "image", "folder-image", "folder-pictures"];
            for (let i = 0; i < imgCandidates.length; i++) {
                if (Quickshell.hasThemeIcon(imgCandidates[i])) return imgCandidates[i];
            }
            return "image-x-generic";
        }

        // 2. Videos
        if (["mp4", "mkv", "avi", "mov", "webm", "flv"].includes(ext)) {
            const vidCandidates = ["video-x-generic", "folder-videos", "media-video", "video"];
            for (let i = 0; i < vidCandidates.length; i++) {
                if (Quickshell.hasThemeIcon(vidCandidates[i])) return vidCandidates[i];
            }
            return "video-x-generic";
        }

        // 3. Audio
        if (["mp3", "wav", "flac", "ogg", "m4a", "aac"].includes(ext)) {
            const audCandidates = ["audio-x-generic", "folder-music", "audio"];
            for (let i = 0; i < audCandidates.length; i++) {
                if (Quickshell.hasThemeIcon(audCandidates[i])) return audCandidates[i];
            }
            return "audio-x-generic";
        }

        // 4. Archives
        if (["zip", "tar", "gz", "xz", "7z", "bz2", "rar"].includes(ext)) {
            const archCandidates = ["package-x-generic", "application-zip", "application-x-tar", "package"];
            for (let i = 0; i < archCandidates.length; i++) {
                if (Quickshell.hasThemeIcon(archCandidates[i])) return archCandidates[i];
            }
            return "package-x-generic";
        }

        // 5. Code & Scripts
        if (["sh", "bash", "py", "js", "ts", "qml", "json", "c", "cpp", "h", "rs", "go", "html", "css", "xml", "yaml", "yml"].includes(ext)) {
            const codeCandidates = ["text-x-script", "application-x-shellscript", "text-x-generic", "folder-documents"];
            for (let i = 0; i < codeCandidates.length; i++) {
                if (Quickshell.hasThemeIcon(codeCandidates[i])) return codeCandidates[i];
            }
            return "text-x-generic";
        }

        // 6. Documents & Text
        const docCandidates = ["text-x-generic", "folder-documents", "document", "text-plain"];
        for (let i = 0; i < docCandidates.length; i++) {
            if (Quickshell.hasThemeIcon(docCandidates[i])) return docCandidates[i];
        }
        return "text-x-generic";
    }

    property var _pendingUserItems: []

    Process {
        id: listDesktopProcess
        stdout: SplitParser {
            onRead: function(line) {
                const trimmed = line.trim();
                if (trimmed.length > 0) {
                    const parts = trimmed.split("\t");
                    const type = parts[0];
                    let icon = "folder";
                    let displayName = "";
                    let fileName = "";
                    let isDir = false;

                    if (type === "DIR") {
                        fileName = parts[2] || parts[1];
                        displayName = fileName;
                        isDir = true;
                        icon = "folder";
                    } else if (type === "DESKTOP") {
                        icon = parts[1] || "application-x-executable";
                        displayName = parts[2] || parts[3];
                        fileName = parts[3] || displayName;
                        isDir = false;
                    } else { // FILE
                        fileName = parts[2] || parts[1];
                        displayName = fileName;
                        isDir = false;
                        icon = root.getFileIcon(fileName);
                    }

                    const fullP = root.desktopDir + "/" + fileName;
                    const newItem = {
                        "id": "user_" + fileName.replace(/[^a-zA-Z0-9]/g, "_"),
                        "name": displayName,
                        "fileName": fileName,
                        "icon": icon,
                        "path": fullP,
                        "isSystem": false,
                        "isTrash": false,
                        "isDir": isDir,
                        "isDesktopEntry": (type === "DESKTOP")
                    };
                    if (!root._pendingUserItems.some(i => i.path === fullP)) {
                        root._pendingUserItems.push(newItem);
                    }
                }
            }
        }
        onExited: {
            root.userItems = root._pendingUserItems;
        }
    }

    function refreshDesktop() {
        root._pendingUserItems = [];
        const scanCmd = "mkdir -p '" + root.desktopDir + "' && for entry in '" + root.desktopDir + "'/*; do [ -e \"$entry\" ] || continue; name=$(basename \"$entry\"); if [ -d \"$entry\" ]; then printf \"DIR\\t\\t%s\\n\" \"$name\"; elif [[ \"$name\" == *.desktop ]]; then d_name=$(grep -m1 '^Name=' \"$entry\" | cut -d= -f2-); d_icon=$(grep -m1 '^Icon=' \"$entry\" | cut -d= -f2-); [ -z \"$d_name\" ] && d_name=\"$name\"; printf \"DESKTOP\\t%s\\t%s\\t%s\\n\" \"$d_icon\" \"$d_name\" \"$name\"; else printf \"FILE\\t\\t%s\\n\" \"$name\"; fi; done";
        listDesktopProcess.exec(["bash", "-c", scanCmd]);
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
