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
            "icon": root.isTrashEmpty ? "user-trash" : "user-trash-full",
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

    // Combined items array (reactive and explicitly updated on changes)
    property var allItems: []

    // Selection management
    property var selectedItemIds: []
    property string editingItemId: ""

    // ----------------------------------------------------
    // GRID METRICS & ICON POSITION PERSISTENCE
    // ----------------------------------------------------
    readonly property real cellWidth: 96
    readonly property real cellHeight: 104
    readonly property real topMargin: 56
    readonly property real sideMargin: 24

    property bool snapToGrid: true

    readonly property string positionsPath: homeDir + "/.config/deloway/desktop_positions.json"
    property var iconPositions: ({})
    property int positionsRevision: 0

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
    }

    // ----------------------------------------------------
    // CONTEXT MENU HANDLERS
    // ----------------------------------------------------
    function showWallpaperContextMenu(x, y) {
        contextMenuTargetItem = null;
        contextMenuX = x;
        contextMenuY = y;
        contextMenuVisible = true;
    }

    function showItemContextMenu(item, x, y) {
        contextMenuTargetItem = item;
        contextMenuX = x;
        contextMenuY = y;
        if (item && item.id && !isItemSelected(item.id)) {
            selectedItemIds = [item.id];
        }
        contextMenuVisible = true;
    }

    function closeContextMenu() {
        contextMenuVisible = false;
        contextMenuTargetItem = null;
    }

    // ----------------------------------------------------
    // ACTIONS (NEW FOLDER, NEW FILE, OPEN TERMINAL, ETC.)
    // ----------------------------------------------------
    function createFolder(baseName) {
        const name = (baseName && baseName.trim().length > 0) ? baseName.trim() : (I18n.isRTL ? "مجلد جديد" : "New Folder");
        const cmd = "cd '" + root.desktopDir + "' && name='" + name + "'; i=1; while [ -e \"$name\" ]; do name=\"" + name + " ($i)\"; i=$((i+1)); done; mkdir -p \"$name\"";
        Quickshell.execDetached(["bash", "-c", cmd]);
        refreshTimer.restart();
    }

    function createDocument(baseName) {
        const name = (baseName && baseName.trim().length > 0) ? baseName.trim() : (I18n.isRTL ? "مستند جديد.txt" : "New Document.txt");
        const cmd = "cd '" + root.desktopDir + "' && name='" + name + "'; i=1; while [ -e \"$name\" ]; do name=\"" + name.replace(/\.txt$/, "") + " ($i).txt\"; i=$((i+1)); done; touch \"$name\"";
        Quickshell.execDetached(["bash", "-c", cmd]);
        refreshTimer.restart();
    }

    function openTerminalHere() {
        Quickshell.execDetached(["kitty", "--directory", root.desktopDir]);
    }

    function openItem(item) {
        if (!item) return;
        if (item.isDesktopEntry && item.path) {
            Quickshell.execDetached(["gtk-launch", item.fileName || item.name]);
        } else if (item.path) {
            Quickshell.execDetached(["xdg-open", item.path]);
        }
    }

    function renameItem(item, newName) {
        if (!item || !newName || item.name === newName) {
            editingItemId = "";
            return;
        }
        if (item.isSystem) {
            editingItemId = "";
            return;
        }
        const oldP = item.path;
        const newP = root.desktopDir + "/" + newName.trim();
        Quickshell.execDetached(["mv", oldP, newP]);
        editingItemId = "";
        refreshTimer.restart();
    }

    function moveToTrash(item) {
        if (!item || item.isSystem) return;
        Quickshell.execDetached(["gio", "trash", item.path]);
        refreshTimer.restart();
    }

    function emptyTrash() {
        Quickshell.execDetached(["bash", "-c", "rm -rf '" + root.trashFilesDir + "'/* '" + root.trashInfoDir + "'/*"]);
        root.isTrashEmpty = true;
        refreshTimer.restart();
    }

    function startRenaming(id) {
        editingItemId = id;
    }

    function cancelRenaming() {
        editingItemId = "";
    }

    // ----------------------------------------------------
    // POSITION CALCULATION & PERSISTENCE
    // ----------------------------------------------------
    function getItemX(id, index, parentW, parentH) {
        // Dependency on revision to re-evaluate on changes
        const _rev = root.positionsRevision;
        if (root.iconPositions && root.iconPositions[id] && root.iconPositions[id].x !== undefined) {
            return root.iconPositions[id].x;
        }
        const pW = (parentW && parentW > 0) ? parentW : 1920;
        const pH = (parentH && parentH > 0) ? parentH : 1080;
        const availableH = Math.max(200, pH - root.topMargin - 60);
        const itemsPerCol = Math.max(1, Math.floor(availableH / root.cellHeight));
        const col = Math.floor(index / itemsPerCol);

        if (I18n.isRTL) {
            return Math.max(10, pW - root.sideMargin - root.cellWidth - (col * root.cellWidth));
        } else {
            return root.sideMargin + (col * root.cellWidth);
        }
    }

    function getItemY(id, index, parentW, parentH) {
        const _rev = root.positionsRevision;
        if (root.iconPositions && root.iconPositions[id] && root.iconPositions[id].y !== undefined) {
            return root.iconPositions[id].y;
        }
        const pH = (parentH && parentH > 0) ? parentH : 1080;
        const availableH = Math.max(200, pH - root.topMargin - 60);
        const itemsPerCol = Math.max(1, Math.floor(availableH / root.cellHeight));
        const row = index % itemsPerCol;
        return root.topMargin + (row * root.cellHeight);
    }

    function saveItemPosition(id, rawX, rawY, parentW, parentH) {
        let finalX = Math.round(rawX);
        let finalY = Math.round(rawY);

        if (root.snapToGrid) {
            const pW = (parentW && parentW > 0) ? parentW : 1920;
            finalY = root.topMargin + Math.max(0, Math.round((finalY - root.topMargin) / root.cellHeight)) * root.cellHeight;
            if (I18n.isRTL) {
                // RTL columns snap from right
                const col = Math.max(0, Math.round((pW - root.sideMargin - root.cellWidth - finalX) / root.cellWidth));
                finalX = Math.max(10, pW - root.sideMargin - root.cellWidth - (col * root.cellWidth));
            } else {
                const col = Math.max(0, Math.round((finalX - root.sideMargin) / root.cellWidth));
                finalX = root.sideMargin + (col * root.cellWidth);
            }
        }

        let updated = Object.assign({}, root.iconPositions);
        updated[id] = { "x": finalX, "y": finalY };
        root.iconPositions = updated;
        root.positionsRevision++;
        savePositionsTimer.restart();
    }

    function autoArrangeIcons(parentW, parentH) {
        const pW = parentW || 1920;
        const pH = parentH || 1080;
        const availableH = Math.max(200, pH - root.topMargin - 60);
        const itemsPerCol = Math.max(1, Math.floor(availableH / root.cellHeight));

        let updated = {};
        for (let i = 0; i < root.allItems.length; i++) {
            const item = root.allItems[i];
            const col = Math.floor(i / itemsPerCol);
            const row = i % itemsPerCol;
            const y = root.topMargin + (row * root.cellHeight);
            let x = 0;
            if (I18n.isRTL) {
                x = Math.max(10, pW - root.sideMargin - root.cellWidth - (col * root.cellWidth));
            } else {
                x = root.sideMargin + (col * root.cellWidth);
            }
            updated[item.id] = { "x": Math.round(x), "y": Math.round(y) };
        }
        root.iconPositions = updated;
        root.positionsRevision++;
        savePositionsTimer.restart();
    }

    function resetPositions() {
        root.iconPositions = ({});
        root.positionsRevision++;
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + root.homeDir + "/.config/deloway' && echo '{}' > '" + root.positionsPath + "'"]);
    }

    // ----------------------------------------------------
    // BACKGROUND SCANNING & PROCESSES
    // ----------------------------------------------------
    Process {
        id: loadPositionsProcess
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    const trimmed = data.trim();
                    if (trimmed.length > 0) {
                        const parsed = JSON.parse(trimmed);
                        if (parsed && typeof parsed === "object") {
                            root.iconPositions = parsed;
                            root.positionsRevision++;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: savePositionsTimer
        interval: 350
        repeat: false
        onTriggered: {
            const jsonStr = JSON.stringify(root.iconPositions, null, 2);
            Quickshell.execDetached(["bash", "-c", "mkdir -p '" + root.homeDir + "/.config/deloway' && cat << 'EOF' > '" + root.positionsPath + "'\n" + jsonStr + "\nEOF"]);
        }
    }

    function loadPositions() {
        loadPositionsProcess.command = ["bash", "-c", "cat '" + root.positionsPath + "' 2>/dev/null || echo '{}'"];
        loadPositionsProcess.running = true;
    }

    Process {
        id: checkTrashProcess
        stdout: SplitParser {
            onRead: function(data) {
                root.isTrashEmpty = (data.trim() === "empty");
            }
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
            root.allItems = root.systemItems.concat(root.userItems);
            console.log("[Deloway Desktop] Scan complete. Found " + root.userItems.length + " user items, total allItems: " + root.allItems.length);
        }
    }

    function refreshDesktop() {
        root._pendingUserItems = [];
        const scanCmd = "mkdir -p '" + root.desktopDir + "' && for entry in '" + root.desktopDir + "'/*; do [ -e \"$entry\" ] || continue; name=$(basename \"$entry\"); if [ -d \"$entry\" ]; then printf \"DIR\\t\\t%s\\n\" \"$name\"; elif [[ \"$name\" == *.desktop ]]; then d_name=$(grep -m1 '^Name=' \"$entry\" | cut -d= -f2-); d_icon=$(grep -m1 '^Icon=' \"$entry\" | cut -d= -f2-); [ -z \"$d_name\" ] && d_name=\"$name\"; printf \"DESKTOP\\t%s\\t%s\\t%s\\n\" \"$d_icon\" \"$d_name\" \"$name\"; else printf \"FILE\\t\\t%s\\n\" \"$name\"; fi; done";
        listDesktopProcess.command = ["bash", "-c", scanCmd];
        listDesktopProcess.running = true;

        checkTrashProcess.command = ["bash", "-c", "[ -d '" + root.trashFilesDir + "' ] && [ $(ls -A '" + root.trashFilesDir + "' 2>/dev/null | wc -l) -gt 0 ] && echo 'full' || echo 'empty'"];
        checkTrashProcess.running = true;
    }

    Process {
        id: desktopWatcherProcess
        command: [
            "python3", "-u", "-c",
            "import os, sys, ctypes\n" +
            "libc = ctypes.CDLL(None)\n" +
            "fd = libc.inotify_init()\n" +
            "MASK = 0x100 | 0x200 | 0x40 | 0x80\n" +
            "d = sys.argv[1]\n" +
            "os.makedirs(d, exist_ok=True)\n" +
            "libc.inotify_add_watch(fd, d.encode(), MASK)\n" +
            "t = sys.argv[2]\n" +
            "if os.path.exists(t):\n" +
            "    libc.inotify_add_watch(fd, t.encode(), MASK)\n" +
            "while True:\n" +
            "    if os.read(fd, 1024):\n" +
            "        print('change', flush=True)\n",
            root.desktopDir,
            root.trashFilesDir
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                refreshTimer.restart();
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: refreshDesktop()
    }

    Component.onCompleted: {
        root.allItems = root.systemItems.concat([]);
        loadPositions();
        refreshDesktop();
    }
}
