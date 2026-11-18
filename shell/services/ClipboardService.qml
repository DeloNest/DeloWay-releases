pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

// Clipboard history (Super + V): cliphist keeps it, this service records into it, lists it,
// manages pinned snippets, provides rich inspectors and acts on items.
Item {
    id: root

    property bool isAvailable: false
    property var items: []
    property var pinnedItems: []
    property bool isRefreshing: false
    property bool _refreshAgain: false

    // Decoded full-text inspection for the active item
    property string currentDecodedText: ""
    property bool isDecoding: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")) + "/deloway"
    readonly property string cacheDir: (Quickshell.env("HOME") || "") + "/.cache/deloway/clipboard"
    readonly property int maxThumbnails: 50
    readonly property int previewWidth: 400

    // ── Pinned Storage ───────────────────────────────────────────────────
    Process {
        id: ensureStateDir
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: pinnedStore
        path: root.stateDir + "/clipboard_pinned.json"
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadPinned()
        onLoadFailed: root.pinnedItems = []
    }

    function loadPinned() {
        try {
            const raw = pinnedStore.text();
            if (raw && raw.trim().length > 0) {
                const data = JSON.parse(raw);
                root.pinnedItems = Array.isArray(data) ? data : [];
            } else {
                root.pinnedItems = [];
            }
        } catch (e) {
            console.warn("[ClipboardService] Failed to parse clipboard_pinned.json:", e);
            root.pinnedItems = [];
        }
    }

    function persistPinned() {
        try {
            pinnedStore.setText(JSON.stringify(root.pinnedItems, null, 2) + "\n");
        } catch (e) {
            console.warn("[ClipboardService] Failed to persist pinned items:", e);
        }
    }

    function isPinned(item) {
        if (!item) return false;
        return root.pinnedItems.some(p => {
            if (item.kind === "image" && p.kind === "image") {
                return (item.id && p.id === item.id) || (p.size === item.size && p.width === item.width && p.height === item.height);
            }
            return !!(p.text && item.text && p.text === item.text);
        });
    }

    function pinItem(item) {
        if (!item || root.isPinned(item)) return;
        const entry = {
            id: item.id || ("pinned_" + Date.now()),
            kind: item.kind || "text",
            text: item.text || "",
            format: item.format || "",
            size: item.size || "",
            width: item.width || 0,
            height: item.height || 0,
            thumb: item.thumb || "",
            pinnedAt: Date.now()
        };
        root.pinnedItems = [entry].concat(root.pinnedItems);
        root.persistPinned();
    }

    function unpinItem(item) {
        if (!item) return;
        root.pinnedItems = root.pinnedItems.filter(p => {
            if (item.kind === "image" && p.kind === "image") {
                return !((item.id && p.id === item.id) || (p.size === item.size && p.width === item.width && p.height === item.height));
            }
            return !(p.text && item.text && p.text === item.text);
        });
        root.persistPinned();
    }

    function togglePin(item) {
        if (root.isPinned(item)) root.unpinItem(item);
        else root.pinItem(item);
    }

    // ── Recording ────────────────────────────────────────────────────────
    component Watcher: Process {
        id: watcher
        property string type: ""
        command: ["setpriv", "--pdeathsig", "TERM", "--",
                  "wl-paste", "--type", watcher.type, "--watch", "cliphist", "store"]
        running: root.isAvailable
        onExited: if (root.isAvailable) restartTimer.restart()
        readonly property Timer restartTimer: Timer {
            interval: 2000
            onTriggered: watcher.running = true
        }
    }
    Watcher { type: "text" }
    Watcher { type: "image" }

    // ── Listing ──────────────────────────────────────────────────────────
    property var _tempList: []

    function parseLine(line) {
        const tab = line.indexOf("\t");
        if (tab < 0) return null;
        const id = line.substring(0, tab).trim();
        const preview = line.substring(tab + 1);
        const bin = /^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$/.exec(preview);
        if (bin) {
            const format = bin[2].toLowerCase();
            return {
                id: id, kind: "image", text: "",
                format: format === "jpeg" ? "jpg" : format,
                size: bin[1], width: Number(bin[3]), height: Number(bin[4]),
                thumb: ""
            };
        }
        if (/^\[\[ binary data/.test(preview))
            return { id: id, kind: "binary", text: preview };
        return { id: id, kind: root.textKind(preview), text: preview };
    }

    function textKind(t) {
        const s = t.trim();
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s)) return "color";
        if (/^(https?|ftp):\/\/\S+$/i.test(s)) return "link";
        if (/^(~|\/)[^\s]*$/.test(s) && s.length > 1) return "path";
        return "text";
    }

    Process {
        id: listProcess
        stdout: SplitParser {
            onRead: data => {
                const entry = root.parseLine(data);
                if (entry) root._tempList.push(entry);
            }
        }
        onExited: {
            root.items = root._tempList;
            root.isRefreshing = false;
            root.cacheThumbnails();
            if (root._refreshAgain) {
                root._refreshAgain = false;
                root.refresh();
            }
        }
    }

    function refresh() {
        if (!root.isAvailable) return;
        if (root.isRefreshing) {
            root._refreshAgain = true;
            return;
        }
        root.isRefreshing = true;
        root._tempList = [];
        listProcess.exec(["cliphist", "-preview-width", String(root.previewWidth), "list"]);
    }

    // ── Thumbnails ───────────────────────────────────────────────────────
    Process {
        id: thumbProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const present = {};
                for (const name of text.split("\n")) if (name) present[name] = true;
                const dir = root.cacheDir;
                root.items = root.items.map(item => {
                    if (item.kind !== "image") return item;
                    const copy = Object.assign({}, item);
                    const name = item.id + "." + item.format;
                    copy.thumb = present[name] ? "file://" + dir + "/" + name : "";
                    return copy;
                });
            }
        }
    }

    function cacheThumbnails() {
        const images = root.items.filter(i => i.kind === "image").slice(0, root.maxThumbnails);
        const keep = images.map(i => i.id + "." + i.format);
        const script =
            'dir="$1"; shift; mkdir -p "$dir"; keep=" "; ' +
            'while [ $# -ge 2 ]; do f="$dir/$2"; keep="$keep$2 "; ' +
            '  if [ ! -s "$f" ]; then cliphist decode "$1" > "$f.part" && mv -f "$f.part" "$f"; fi; shift 2; done; ' +
            'for f in "$dir"/*; do [ -e "$f" ] || continue; n="${f##*/}"; ' +
            '  case "$keep" in *" $n "*) ;; *) rm -f "$f" ;; esac; done; ' +
            'for f in "$dir"/*; do [ -s "$f" ] && printf "%s\\n" "${f##*/}"; done';
        const args = ["sh", "-c", script, "sh", root.cacheDir];
        images.forEach(i => args.push(i.id, i.id + "." + i.format));
        thumbProcess.exec(args);
    }

    // ── Full-Text Decoding for Inspector ──────────────────────────────────
    Process {
        id: fullTextProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentDecodedText = text;
                root.isDecoding = false;
            }
        }
        onExited: {
            root.isDecoding = false;
        }
    }

    function decodeFullText(item) {
        if (!item) {
            root.currentDecodedText = "";
            root.isDecoding = false;
            return;
        }
        if (item.kind === "image") {
            root.currentDecodedText = "";
            root.isDecoding = false;
            return;
        }
        if (item.id && !String(item.id).startsWith("pinned_")) {
            root.isDecoding = true;
            fullTextProcess.exec(["cliphist", "decode", String(item.id)]);
        } else {
            root.currentDecodedText = item.text || "";
            root.isDecoding = false;
        }
    }

    // ── Actions ──────────────────────────────────────────────────────────
    Process { id: copyProcess }
    Process { id: directCopyProcess }
    Process { id: openUrlProcess }
    Process {
        id: deleteProcess
        onExited: root.refresh()
    }
    Process {
        id: wipeProcess
        onExited: {
            root.items = [];
            root.cacheThumbnails();
        }
    }

    function mimeOf(item) {
        return item.kind === "image" ? "image/" + (item.format === "jpg" ? "jpeg" : item.format) : "";
    }

    function copyText(str) {
        if (!str) return;
        directCopyProcess.exec(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", String(str)]);
    }

    function copyItem(item) {
        if (!item) return;
        if (item.kind === "image") {
            const mime = root.mimeOf(item);
            if (item.id && !String(item.id).startsWith("pinned_")) {
                copyProcess.exec(["sh", "-c",
                                  mime ? 'cliphist decode "$1" | wl-copy --type "$2"' : 'cliphist decode "$1" | wl-copy',
                                  "sh", String(item.id), mime]);
            } else if (item.thumb && item.thumb.startsWith("file://")) {
                const filePath = item.thumb.replace("file://", "");
                copyProcess.exec(["sh", "-c", 'wl-copy --type "$2" < "$1"', "sh", filePath, mime]);
            }
        } else {
            if (item.id && !String(item.id).startsWith("pinned_")) {
                copyProcess.exec(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", String(item.id)]);
            } else {
                root.copyText(item.text || "");
            }
        }
    }

    readonly property var terminalClasses: ["kitty", "alacritty", "foot", "footclient", "com.mitchellh.ghostty",
                                            "org.kde.konsole", "org.gnome.console", "org.gnome.terminal",
                                            "wezterm", "org.wezfurlong.wezterm", "xterm", "tilix"]
    property string _pasteShortcut: ""
    Timer {
        id: pasteTimer
        interval: 180
        onTriggered: Hyprland.dispatch("sendshortcut " + root._pasteShortcut + ", code:55, activewindow")
    }

    function pasteItem(item) {
        if (!item) return;
        root.copyItem(item);
        const win = ToplevelManager.activeToplevel;
        if (!win) return;
        const appId = String(win.appId || "").toLowerCase();
        root._pasteShortcut = root.terminalClasses.indexOf(appId) >= 0 ? "CTRL SHIFT" : "CTRL";
        pasteTimer.restart();
    }

    function deleteItem(item) {
        if (!item) return;
        if (root.isPinned(item)) {
            root.unpinItem(item);
        }
        if (item.id && !String(item.id).startsWith("pinned_")) {
            deleteProcess.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", String(item.id)]);
        }
        root.items = root.items.filter(i => i.id !== item.id);
    }

    function wipeHistory(keepPinned) {
        if (keepPinned === undefined) keepPinned = true;
        if (!keepPinned) {
            root.pinnedItems = [];
            root.persistPinned();
        }
        wipeProcess.exec(["cliphist", "wipe"]);
    }

    function openUrl(url) {
        if (!url) return;
        const clean = String(url).trim();
        if (/^(https?|ftp):\/\/\S+$/i.test(clean)) {
            openUrlProcess.exec(["xdg-open", clean]);
        }
    }

    function extractDomain(url) {
        if (!url) return "";
        const m = /^(?:https?:\/\/)?(?:www\.)?([^\/\:\?#]+)/i.exec(String(url).trim());
        return m ? m[1] : "";
    }

    function hexToRgb(hex) {
        let c = String(hex || "").trim().replace("#", "");
        if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
        if (c.length >= 6) {
            const r = parseInt(c.substring(0, 2), 16);
            const g = parseInt(c.substring(2, 4), 16);
            const b = parseInt(c.substring(4, 6), 16);
            if (!isNaN(r) && !isNaN(g) && !isNaN(b)) {
                return "rgb(" + r + ", " + g + ", " + b + ")";
            }
        }
        return "";
    }

    // ── Availability ─────────────────────────────────────────────────────
    Process {
        id: initProcess
        command: ["sh", "-c", "command -v cliphist && command -v wl-paste && command -v wl-copy"]
        onExited: exitCode => {
            root.isAvailable = exitCode === 0;
            if (root.isAvailable) root.refresh();
        }
    }

    Component.onCompleted: initProcess.running = true
}
