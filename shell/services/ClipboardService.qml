pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    property bool isAvailable: false
    property var items: []
    property bool isRefreshing: false

    readonly property string cacheDir: (Quickshell.env("HOME") || "") + "/.cache/deloway/clipboard"

    // Background watcher process
    Process {
        id: watcherProcess
    }

    // List items process
    property var _tempList: []

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: function(data) {
                const line = data.trim();
                if (!line) return;
                const tabIdx = line.indexOf("\t");
                if (tabIdx === -1) return;

                const idStr = line.substring(0, tabIdx).trim();
                const preview = line.substring(tabIdx + 1);
                const isBinary = preview.startsWith("[[ binary data");
                const isImage = isBinary && (preview.includes("png") || preview.includes("jpeg") || preview.includes("jpg"));

                root._tempList.push({
                    id: idStr,
                    text: preview,
                    isBinary: isBinary,
                    isImage: isImage,
                    mimeType: isImage ? "image" : (isBinary ? "binary" : "text"),
                    rawLine: line
                });
            }
        }
        onExited: {
            root.items = root._tempList;
            root.isRefreshing = false;
        }
    }

    // Copy process
    Process {
        id: copyProcess
    }

    // Delete item process
    Process {
        id: deleteProcess
        onExited: root.refresh()
    }

    // Wipe process
    Process {
        id: wipeProcess
        onExited: {
            root.items = [];
        }
    }

    // Check & Init process
    Process {
        id: initProcess
        command: ["sh", "-c", "mkdir -p " + root.cacheDir + " && command -v cliphist && command -v wl-paste"]
        onExited: exitCode => {
            if (exitCode === 0) {
                root.isAvailable = true;
                startWatcher();
                refresh();
            } else {
                root.isAvailable = false;
            }
        }
    }

    function startWatcher() {
        watcherProcess.exec([
            "sh", "-c",
            "if ! pgrep -f '[c]liphist store' >/dev/null 2>&1; then " +
            "  wl-paste --type text --watch sh -c 'if ! wl-paste --list-types 2>/dev/null | grep -qiE \"password|secret\"; then cliphist store; fi' & " +
            "  wl-paste --type image --watch cliphist store & " +
            "fi"
        ]);
    }

    function refresh() {
        if (!root.isAvailable) return;
        if (root.isRefreshing) return;
        root.isRefreshing = true;
        root._tempList = [];
        listProcess.exec(["cliphist", "list"]);
    }

    function copyItem(item) {
        if (!item || !item.id) return;
        copyProcess.exec(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", String(item.id)]);
    }

    function deleteItem(item) {
        if (!item || !item.id) return;
        const escaped = (item.text || "").replace(/'/g, "'\\''");
        deleteProcess.exec(["sh", "-c", "printf '%s\\t%s\\n' '" + item.id + "' '" + escaped + "' | cliphist delete"]);
    }

    function wipeHistory() {
        wipeProcess.exec(["cliphist", "wipe"]);
    }

    Component.onCompleted: {
        initProcess.running = true;
    }
}
