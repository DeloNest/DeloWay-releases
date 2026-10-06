pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

// Clipboard history (Super + V): cliphist keeps it, this service records into it, lists it
// and acts on it.
//
// Recording: two wl-paste watchers (text, images) owned by the shell — they start and stop
// with it and are restarted if they exit. They used to be launched in the background of a
// short-lived `sh`, which did not survive it: nothing was ever recorded. Entries a password
// manager marks sensitive (CLIPBOARD_STATE, set by wl-paste) are skipped by cliphist itself.
//
// Images: cliphist lists them as "[[ binary data 41 KiB png 800x450 ]]". The most recent
// ones are decoded into ~/.cache/deloway/clipboard/<id>.<format> for the thumbnails; files of
// entries gone from the history are removed.
Item {
    id: root

    property bool isAvailable: false
    property var items: []
    property bool isRefreshing: false
    property bool _refreshAgain: false

    readonly property string cacheDir: (Quickshell.env("HOME") || "") + "/.cache/deloway/clipboard"
    readonly property int maxThumbnails: 40
    // Longer previews than cliphist's 100 characters: two lines in the list, and search.
    readonly property int previewWidth: 400

    // ── Recording ────────────────────────────────────────────────────────
    component Watcher: Process {
        id: watcher
        property string type: ""
        // setpriv --pdeathsig: the kernel ends the watcher when the shell dies, however it
        // dies (killall on a restart left one orphaned pair per restart, all recording).
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

    // What a text entry is, for its icon and label.
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
    // Decodes the images without a cached file, removes files no longer in the history,
    // then points the items at their files (a new list, so bindings update).
    Process {
        id: thumbProcess
        onExited: {
            const dir = root.cacheDir;
            let recent = 0;
            root.items = root.items.map(item => {
                if (item.kind !== "image") return item;
                const copy = Object.assign({}, item);
                copy.thumb = recent++ < root.maxThumbnails ? "file://" + dir + "/" + item.id + "." + item.format : "";
                return copy;
            });
        }
    }

    function cacheThumbnails() {
        const images = root.items.filter(i => i.kind === "image").slice(0, root.maxThumbnails);
        const keep = images.map(i => i.id + "." + i.format);
        // $1 = dir; then pairs of (id, file name). Files not named are removed.
        const script =
            'dir="$1"; shift; mkdir -p "$dir"; keep=" "; ' +
            'while [ $# -ge 2 ]; do f="$dir/$2"; keep="$keep$2 "; ' +
            '  if [ ! -s "$f" ]; then cliphist decode "$1" > "$f.part" && mv -f "$f.part" "$f"; fi; shift 2; done; ' +
            'for f in "$dir"/*; do [ -e "$f" ] || continue; n="${f##*/}"; ' +
            '  case "$keep" in *" $n "*) ;; *) rm -f "$f" ;; esac; done';
        const args = ["sh", "-c", script, "sh", root.cacheDir];
        images.forEach(i => args.push(i.id, i.id + "." + i.format));
        thumbProcess.exec(args);
    }

    // ── Actions ──────────────────────────────────────────────────────────
    Process { id: copyProcess }
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

    // Puts the entry back on the clipboard (it also moves to the top of the history).
    function copyItem(item) {
        if (!item || !item.id) return;
        const mime = root.mimeOf(item);
        copyProcess.exec(["sh", "-c",
                          mime ? 'cliphist decode "$1" | wl-copy --type "$2"' : 'cliphist decode "$1" | wl-copy',
                          "sh", String(item.id), mime]);
    }

    // Copies the entry and pastes it into the window that had focus before Super + V:
    // Ctrl+V, or Ctrl+Shift+V in a terminal (Ctrl+V is a control character there). Sent
    // once the panel has let go of the keyboard and the window has it back.
    readonly property var terminalClasses: ["kitty", "alacritty", "foot", "footclient", "com.mitchellh.ghostty",
                                            "org.kde.konsole", "org.gnome.console", "org.gnome.terminal",
                                            "wezterm", "org.wezfurlong.wezterm", "xterm", "tilix"]
    property string _pasteShortcut: ""
    Timer {
        id: pasteTimer
        interval: 180
        onTriggered: Hyprland.dispatch("sendshortcut " + root._pasteShortcut + ", V, activewindow")
    }

    function pasteItem(item) {
        if (!item || !item.id) return;
        root.copyItem(item);
        const win = ToplevelManager.activeToplevel;
        if (!win) return;   // no window to paste into: copied only
        const appId = String(win.appId || "").toLowerCase();
        root._pasteShortcut = root.terminalClasses.indexOf(appId) >= 0 ? "CTRL SHIFT" : "CTRL";
        pasteTimer.restart();
    }

    function deleteItem(item) {
        if (!item || !item.id) return;
        // cliphist delete reads "<id>\t…" lines; only the id matters.
        deleteProcess.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", String(item.id)]);
        root.items = root.items.filter(i => i.id !== item.id);   // at once; the refresh confirms
    }

    function wipeHistory() {
        wipeProcess.exec(["cliphist", "wipe"]);
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
