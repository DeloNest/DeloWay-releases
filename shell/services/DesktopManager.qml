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

    // Fixed desktop items. Home and Trash always; Projects, Videos and Downloads only
    // when the folder exists (the XDG location, e.g. a localized "Videos"), found by the
    // desktop scan. Names follow the UI language.
    property var sysPaths: ({})     // id → existing folder, from refreshDesktop()
    readonly property var systemItems: {
        const list = [
            { "id": "home", "name": I18n.tr("desk_home"), "icon": "user-home", "path": root.homeDir,
              "isSystem": true, "isTrash": false, "isDir": true },
            { "id": "trash", "name": I18n.tr("desk_trash"), "icon": root.isTrashEmpty ? "user-trash" : "user-trash-full",
              "path": "trash://", "isSystem": true, "isTrash": true, "isDir": true }
        ];
        const extra = [["projects", "desk_projects", "folder-development"],
                       ["media",    "desk_videos",   "folder-videos"],        // id kept: saved positions
                       ["downloads","desk_downloads","folder-download"]];
        for (const e of extra) {
            if (root.sysPaths[e[0]]) list.push({ "id": e[0], "name": I18n.tr(e[1]), "icon": e[2], "path": root.sysPaths[e[0]],
                                                 "isSystem": true, "isTrash": false, "isDir": true });
        }
        return list;
    }

    // User created files and folders on ~/Desktop
    property var userItems: []

    // Combined items array (reactive and explicitly updated on changes)
    readonly property var allItems: root.systemItems.concat(root.userItems)

    // Selection management
    property var selectedItemIds: []
    property string editingItemId: ""

    // ----------------------------------------------------
    // GRID METRICS & ICON POSITION PERSISTENCE
    // ----------------------------------------------------
    readonly property real cellWidth: 100
    readonly property real cellHeight: 108
    readonly property real itemWidth: 88     // a two-line name fits under the icon
    readonly property real itemHeight: 100
    readonly property real topMargin: 56
    readonly property real sideMargin: 24

    // Saved in deloway.json (desktop.snapToGrid); it used to reset on every restart.
    readonly property bool snapToGrid: ConfigManager.desktopSnapToGrid

    readonly property string positionsPath: homeDir + "/.config/deloway/desktop_positions.json"
    property var iconPositions: ({})
    property int positionsRevision: 0

    // Context Menu State
    property bool contextMenuVisible: false
    property real contextMenuX: 0
    property real contextMenuY: 0
    property var contextMenuTargetItem: null // null = desktop wallpaper, object = specific item
    // The screen (ShellScreen name) the menu is open on — each screen has its own menu
    // surface, and only this one shows it.
    property string contextMenuScreen: ""

    function _menuScreen(screenName) {
        return screenName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
    }

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
    // x, y are screen-local (the desktop spans its screen); screenName defaults to the
    // focused monitor (IPC).
    function showWallpaperContextMenu(x, y, screenName) {
        contextMenuTargetItem = null;
        contextMenuX = x;
        contextMenuY = y;
        contextMenuScreen = _menuScreen(screenName);
        contextMenuVisible = true;
    }

    function showItemContextMenu(item, x, y, screenName) {
        contextMenuTargetItem = item;
        contextMenuX = x;
        contextMenuY = y;
        contextMenuScreen = _menuScreen(screenName);
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
        // Directory and name travel as positional args, never spliced into the script.
        Quickshell.execDetached(["sh", "-c",
            'cd "$1" || exit 1; n="$2"; i=1; while [ -e "$n" ]; do n="$2 ($i)"; i=$((i+1)); done; mkdir -p -- "$n"',
            "sh", root.desktopDir, name]);
        refreshTimer.restart();
    }

    function createDocument(baseName) {
        const name = (baseName && baseName.trim().length > 0) ? baseName.trim() : (I18n.isRTL ? "مستند جديد.txt" : "New Document.txt");
        Quickshell.execDetached(["sh", "-c",
            'cd "$1" || exit 1; n="$2"; i=1; while [ -e "$n" ]; do n="$3 ($i).txt"; i=$((i+1)); done; touch -- "$n"',
            "sh", root.desktopDir, name, name.replace(/\.txt$/, "")]);
        refreshTimer.restart();
    }

    // The user's terminal (delo-app), started in the desktop folder
    function openTerminalHere() {
        ApplicationManager.run([ConfigManager.projectDir + "/bin/delo-app", "terminal"], root.desktopDir);
    }

    function openItem(item) {
        if (!item) return;
        if (item.isDesktopEntry && item.path) {
            ApplicationManager.run(["gtk-launch", item.fileName || item.name]);
        } else if (item.path) {
            ApplicationManager.run(["xdg-open", item.path]);
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
        const name = newName.trim();
        // A name, not a path: no '/', '.', '..' (they would move the file out of the
        // Desktop, e.g. '../.bashrc'). Existing targets are never overwritten.
        if (!name || name.indexOf("/") >= 0 || name === "." || name === "..") {
            editingItemId = "";
            return;
        }
        renameProcess.targetName = name;
        // The icon keeps its place under its new name.
        const pos = root.iconPositions[item.id];
        if (pos) {
            const updated = Object.assign({}, root.iconPositions);
            updated["user:" + name] = pos;
            root.iconPositions = updated;
            savePositionsTimer.restart();
        }
        renameProcess.exec(["sh", "-c", '[ -e "$2" ] && exit 3; mv -n -- "$1" "$2"',
                            "sh", item.path, root.desktopDir + "/" + name]);
        editingItemId = "";
    }

    function moveToTrash(item) {
        if (!item || item.isSystem) return;
        Quickshell.execDetached(["gio", "trash", item.path]);
        refreshTimer.restart();
    }

    // gio empties files/ and info/ including dotfiles; the icon state comes from the
    // re-check afterwards, not an optimistic assignment.
    function emptyTrash() {
        emptyTrashProcess.exec(["gio", "trash", "--empty"]);
    }
    Process {
        id: emptyTrashProcess
        onExited: refreshTimer.restart()
    }
    Process {
        id: renameProcess
        property string targetName: ""
        onExited: (code) => {
            if (code === 3)
                NotificationManager.postNotification(I18n.isRTL ? "سطح المكتب" : "Desktop",
                    (I18n.isRTL ? "يوجد عنصر باسم «%1» مسبقاً" : "“%1” already exists").replace("%1", targetName), "", "");
            refreshTimer.restart();
        }
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
    // Every icon has a cell of its own. Saved positions are grid cells — c counted from
    // the reading-start edge (the right in Arabic), r from the top — so they survive a
    // language switch or another screen size; with "Align to Grid" off, a free position
    // in pixels ({x, y, free}). layout() places the saved ones first; any icon without a
    // position, whose cell is taken or off this screen, goes to the next free cell. It
    // used to put such an icon in the cell of its index in the list, whatever was there:
    // a new file sat on top of a saved one, and pixel positions from a wider screen were
    // off-screen.
    readonly property real bottomMargin: 110   // the Dock

    function gridFor(parentW, parentH) {
        const W = (parentW && parentW > 0) ? parentW : 1920;
        const H = (parentH && parentH > 0) ? parentH : 1080;
        return {
            W: W, H: H,
            cols: Math.max(1, Math.floor((W - 2 * root.sideMargin) / root.cellWidth)),
            rows: Math.max(1, Math.floor((H - root.topMargin - root.bottomMargin) / root.cellHeight))
        };
    }

    function cellXY(g, c, r) {
        const xOff = Math.round((root.cellWidth - root.itemWidth) / 2);
        const yOff = Math.round((root.cellHeight - root.itemHeight) / 2);
        const x = I18n.isRTL ? g.W - root.sideMargin - (c + 1) * root.cellWidth + xOff
                             : root.sideMargin + c * root.cellWidth + xOff;
        return { x: Math.round(x), y: Math.round(root.topMargin + r * root.cellHeight + yOff) };
    }

    // The cell under an icon whose top-left corner is at (x, y), clamped to the grid.
    function cellAt(g, x, y) {
        const cx = x + root.itemWidth / 2;
        const cy = y + root.itemHeight / 2;
        const c = I18n.isRTL ? Math.floor((g.W - root.sideMargin - cx) / root.cellWidth)
                             : Math.floor((cx - root.sideMargin) / root.cellWidth);
        const r = Math.floor((cy - root.topMargin) / root.cellHeight);
        return { c: Math.max(0, Math.min(g.cols - 1, c)), r: Math.max(0, Math.min(g.rows - 1, r)) };
    }

    function _key(c, r) { return c + ":" + r; }

    // Next free cell, column by column from the reading-start edge.
    function _nextFree(g, taken, from) {
        let i = from.i;
        for (;; i++) {
            const c = Math.floor(i / g.rows), r = i % g.rows;
            if (c >= g.cols) { from.i = i + 1; return { c: c, r: r }; }   // more icons than cells
            if (!taken[root._key(c, r)]) { from.i = i + 1; return { c: c, r: r }; }
        }
    }

    // The free cell nearest to a target cell.
    function _nearestFree(g, taken, target) {
        let best = null, bestD = Infinity;
        for (let c = 0; c < g.cols; c++) {
            for (let r = 0; r < g.rows; r++) {
                if (taken[root._key(c, r)]) continue;
                const d = (c - target.c) * (c - target.c) + (r - target.r) * (r - target.r);
                if (d < bestD) { bestD = d; best = { c: c, r: r }; }
            }
        }
        return best || target;
    }

    // { id: {x, y} } for every desktop item on a screen of this size. `persist`: write the
    // cells it had to choose (new icons, converted old pixel positions) so they stay put —
    // done by one screen only, other screen sizes must not overwrite them.
    function layout(parentW, parentH, persist) {
        const _rev = root.positionsRevision;
        const _rtl = I18n.isRTL;
        const g = root.gridFor(parentW, parentH);
        const saved = root.iconPositions || {};
        const taken = {};
        const out = {};
        const chosen = {};
        const dropped = [];                    // old-id keys now saved under the new id
        const pending = [];
        // Positions saved under the old ids still count where that id named one file only.
        const legacyCount = {};
        for (const item of root.allItems)
            if (item.legacyId) legacyCount[item.legacyId] = (legacyCount[item.legacyId] || 0) + 1;

        for (const item of root.allItems) {
            let p = saved[item.id];
            let migrated = false;
            if (!p && item.legacyId && legacyCount[item.legacyId] === 1 && saved[item.legacyId]) {
                p = saved[item.legacyId];
                migrated = true;
            }
            if (!p) { pending.push(item); continue; }
            if (p.free && !root.snapToGrid) {
                const x = Math.max(8, Math.min(g.W - root.itemWidth - 8, p.x));
                const y = Math.max(root.topMargin, Math.min(g.H - root.itemHeight - root.bottomMargin, p.y));
                const cell = root.cellAt(g, x, y);
                const k = root._key(cell.c, cell.r);
                if (taken[k]) { pending.push(item); continue; }
                taken[k] = item.id;
                out[item.id] = { x: Math.round(x), y: Math.round(y) };
                continue;
            }
            // Grid cell; an old pixel position (or a free one, now aligned) maps to its cell.
            const legacy = p.c === undefined;
            const cell = legacy ? root.cellAt(g, p.x, p.y) : { c: p.c, r: p.r };
            const k = root._key(cell.c, cell.r);
            if (cell.c >= g.cols || cell.r >= g.rows || taken[k]) { pending.push(item); continue; }
            taken[k] = item.id;
            out[item.id] = root.cellXY(g, cell.c, cell.r);
            if (legacy || migrated) chosen[item.id] = cell;
            if (migrated) dropped.push(item.legacyId);
        }
        const cursor = { i: 0 };
        for (const item of pending) {
            const cell = root._nextFree(g, taken, cursor);
            taken[root._key(cell.c, cell.r)] = item.id;
            out[item.id] = root.cellXY(g, cell.c, cell.r);
            chosen[item.id] = cell;
        }
        if (persist && Object.keys(chosen).length > 0) Qt.callLater(root._rememberCells, chosen, dropped);
        return out;
    }

    function _rememberCells(cells, dropped) {
        const updated = Object.assign({}, root.iconPositions);
        let changed = false;
        for (const old of (dropped || [])) {
            if (updated[old] !== undefined) { delete updated[old]; changed = true; }
        }
        for (const id in cells) {
            const cur = updated[id];
            if (cur && cur.c === cells[id].c && cur.r === cells[id].r) continue;
            updated[id] = { c: cells[id].c, r: cells[id].r };
            changed = true;
        }
        if (!changed) return;
        root.iconPositions = updated;
        root.positionsRevision++;
        savePositionsTimer.restart();
    }

    // A drop: the cell under the icon, or the free one nearest to it when another icon
    // is there; with "Align to Grid" off, the exact spot unless it covers another icon.
    function saveItemPosition(id, rawX, rawY, parentW, parentH) {
        const g = root.gridFor(parentW, parentH);
        const current = root.layout(parentW, parentH, false);
        const taken = {};
        for (const other in current) {
            if (other === id) continue;
            const cell = root.cellAt(g, current[other].x, current[other].y);
            taken[root._key(cell.c, cell.r)] = other;
        }
        const updated = Object.assign({}, root.iconPositions);
        const covers = other => Math.abs(current[other].x - rawX) < root.itemWidth
                                && Math.abs(current[other].y - rawY) < root.itemHeight;
        if (!root.snapToGrid && !Object.keys(current).some(o => o !== id && covers(o))) {
            updated[id] = { x: Math.round(rawX), y: Math.round(rawY), free: true };
        } else {
            const target = root.cellAt(g, rawX, rawY);
            const cell = taken[root._key(target.c, target.r)] ? root._nearestFree(g, taken, target) : target;
            updated[id] = { c: cell.c, r: cell.r };
        }
        root.iconPositions = updated;
        root.positionsRevision++;
        savePositionsTimer.restart();
    }

    function autoArrangeIcons(parentW, parentH) {
        const g = root.gridFor(parentW, parentH);
        const updated = {};
        for (let i = 0; i < root.allItems.length; i++) {
            updated[root.allItems[i].id] = { c: Math.floor(i / g.rows), r: i % g.rows };
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
    // Whole-file read: a line-by-line SplitParser fed JSON.parse one line of the
    // (pretty-printed) file at a time, so saved positions never loaded back.
    Process {
        id: loadPositionsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = this.text.trim();
                if (trimmed.length === 0) return;
                try {
                    const parsed = JSON.parse(trimmed);
                    if (parsed && typeof parsed === "object") {
                        root.iconPositions = parsed;
                        root.positionsRevision++;
                    }
                } catch (e) {
                    console.warn("[DesktopManager] desktop_positions.json is not valid JSON; keeping auto-layout");
                }
            }
        }
    }

    Timer {
        id: savePositionsTimer
        interval: 350
        repeat: false
        onTriggered: {
            // Content and path are arguments, not part of the script.
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"',
                                     "sh", root.positionsPath, JSON.stringify(root.iconPositions)]);
        }
    }

    function loadPositions() {
        loadPositionsProcess.command = ["sh", "-c", 'cat "$1" 2>/dev/null || echo "{}"', "sh", root.positionsPath];
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

    // A file's icon: the theme's mimetype icon for its extension — never a folder picture
    // (the old fallbacks listed folder-documents / folder-videos / folder-pictures, which
    // made files look like folders). The first name the theme has wins.
    readonly property var _mimeIcons: [
        [["png", "jpg", "jpeg", "svg", "webp", "gif", "bmp", "ico", "avif", "heic"], ["image-x-generic"]],
        [["mp4", "mkv", "avi", "mov", "webm", "flv", "m4v"], ["video-x-generic"]],
        [["mp3", "wav", "flac", "ogg", "opus", "m4a", "aac"], ["audio-x-generic"]],
        [["zip", "tar", "gz", "xz", "7z", "bz2", "rar", "zst"], ["package-x-generic", "application-x-archive"]],
        [["pdf"], ["application-pdf", "x-office-document"]],
        [["doc", "docx", "odt", "rtf"], ["x-office-document"]],
        [["xls", "xlsx", "ods", "csv"], ["x-office-spreadsheet"]],
        [["ppt", "pptx", "odp"], ["x-office-presentation"]],
        [["sh", "bash", "zsh"], ["application-x-shellscript", "text-x-script"]],
        [["py", "js", "ts", "qml", "json", "c", "cpp", "h", "rs", "go", "html", "css", "xml", "yaml", "yml", "toml"], ["text-x-script"]]
    ]
    function getFileIcon(filename) {
        const dot = filename ? filename.lastIndexOf(".") : -1;
        const ext = dot > 0 ? filename.substring(dot + 1).toLowerCase() : "";
        const row = root._mimeIcons.find(r => r[0].indexOf(ext) >= 0);
        for (const n of (row ? row[1] : []).concat(["text-x-generic"])) {
            if (IconResolver.has(n)) return n;
        }
        return "text-x-generic";
    }

    property var _pendingUserItems: []
    property var _pendingSysPaths: ({})

    Process {
        id: listDesktopProcess
        stdout: SplitParser {
            onRead: function(line) {
                const trimmed = line.trim();
                if (trimmed.length > 0) {
                    const parts = trimmed.split("\t");
                    const type = parts[0];
                    if (type === "SYS") {             // SYS <id> <existing folder>
                        root._pendingSysPaths[parts[1]] = parts[2];
                        return;
                    }
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
                        // The exact name: unique in the folder. The old id replaced every
                        // non-ASCII letter with "_", so two Arabic names of the same length
                        // shared one id — one position (stacked icons), one selection.
                        "id": "user:" + fileName,
                        "legacyId": "user_" + fileName.replace(/[^a-zA-Z0-9]/g, "_"),
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
            root.sysPaths = root._pendingSysPaths;
            root.userItems = root._pendingUserItems;
        }
    }

    function refreshDesktop() {
        root._pendingUserItems = [];
        root._pendingSysPaths = ({});
        // Paths travel as positional arguments ($1 desktop, $2 home), never spliced into
        // the script. SYS lines report the fixed folders that exist (XDG location first).
        const scanCmd =
            'd="$1"; h="$2"; mkdir -p -- "$d"\n' +
            'xdgdir() { p=$(xdg-user-dir "$1" 2>/dev/null); if [ -n "$p" ] && [ "$p" != "$h" ]; then printf %s "$p"; else printf %s "$h/$2"; fi; }\n' +
            'p=$(xdgdir VIDEOS Videos);      [ -d "$p" ] && printf "SYS\\tmedia\\t%s\\n" "$p"\n' +
            'p=$(xdgdir DOWNLOAD Downloads); [ -d "$p" ] && printf "SYS\\tdownloads\\t%s\\n" "$p"\n' +
            '[ -d "$h/Projects" ] && printf "SYS\\tprojects\\t%s\\n" "$h/Projects"\n' +
            'for entry in "$d"/*; do\n' +
            '  [ -e "$entry" ] || continue; name=$(basename -- "$entry")\n' +
            '  if [ -d "$entry" ]; then printf "DIR\\t\\t%s\\n" "$name"\n' +
            '  elif [[ "$name" == *.desktop ]]; then\n' +
            '    d_name=$(grep -m1 "^Name=" "$entry" | cut -d= -f2-); d_icon=$(grep -m1 "^Icon=" "$entry" | cut -d= -f2-)\n' +
            '    [ -z "$d_name" ] && d_name="$name"\n' +
            '    printf "DESKTOP\\t%s\\t%s\\t%s\\n" "$d_icon" "$d_name" "$name"\n' +
            '  else printf "FILE\\t\\t%s\\n" "$name"; fi\n' +
            'done\n';
        listDesktopProcess.command = ["bash", "-c", scanCmd, "deloway-desktop-scan", root.desktopDir, root.homeDir];
        listDesktopProcess.running = true;

        checkTrashProcess.command = ["sh", "-c", '[ -n "$(ls -A "$1" 2>/dev/null)" ] && echo full || echo empty', "sh", root.trashFilesDir];
        checkTrashProcess.running = true;
    }

    Process {
        id: desktopWatcherProcess
        command: [
            "python3", "-u", "-c",
            "import os, sys, ctypes\n" +
            "libc = ctypes.CDLL(None)\n" +
            // Die with the shell: PR_SET_PDEATHSIG(SIGTERM). The loop blocks in read()
            // and would otherwise be orphaned on every shell restart.
            "libc.prctl(1, 15, 0, 0, 0)\n" +
            "if os.getppid() == 1: sys.exit(0)\n" +
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
        onTriggered: root.refreshDesktop()
    }

    Component.onCompleted: {
        loadPositions();
        refreshDesktop();
    }
}
