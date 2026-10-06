pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

// Keyboard shortcuts: config/shortcuts.json is the catalog (Hyprland's defaults are
// generated from it), the user's changes live in deloway.json → shortcuts, and
// scripts/deloway-shortcuts.py makes Hyprland's live binds match. Settings → Shortcuts
// and the cheat sheet read `actions` from here, so they always show what is bound.
Item {
    id: root

    property var groups: []
    property var actions: []          // each: id, group, ar, en, binds[{mods,key}], fixed, customized, display
    property var foreign: []          // Hyprland binds outside the catalog (user's own)
    property bool recording: false    // Settings is capturing a new shortcut

    readonly property string script: ConfigManager.projectDir + "/scripts/deloway-shortcuts.py"
    readonly property string recordSubmap: "deloway-record"

    function overridesJson() { return JSON.stringify(ConfigManager.shortcutOverrides || {}); }

    // ── State (catalog + overrides + foreign binds) ──────────────────────
    Process {
        id: stateProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.groups = d.groups || [];
                    root.actions = d.actions || [];
                    root.foreign = d.foreign || [];
                } catch (e) {
                    console.warn("[shortcuts] state unreadable: " + e);
                }
            }
        }
    }
    function refresh() { stateProc.exec(["python3", root.script, "state", root.overridesJson()]); }

    // ── Apply (reconcile Hyprland's live binds) ──────────────────────────
    property bool _applyAgain: false
    Process {
        id: applyProc
        onExited: {
            if (root._applyAgain) { root._applyAgain = false; root.apply(); return; }
            root.refresh();
        }
    }
    function apply() {
        if (applyProc.running) { root._applyAgain = true; return; }
        applyProc.exec(["python3", root.script, "apply", root.overridesJson()]);
    }

    // The user's changes arrive after the config file is read, and with every change made
    // in Settings: apply each time they change.
    Connections {
        target: ConfigManager
        function onShortcutOverridesChanged() { root.apply(); }
    }

    // A config reload (hyprland.conf edited, hyprctl reload) brings the defaults back.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.apply();
        }
    }

    Component.onCompleted: {
        Hyprland.dispatch("submap reset");     // a shell that died mid-recording left it on
        root.apply();
    }

    // ── Recording ────────────────────────────────────────────────────────
    // While a new shortcut is captured Hyprland is in an empty submap: the keys reach the
    // Settings window instead of running what they are bound to now.
    function startRecording() {
        root.recording = true;
        Hyprland.dispatch("submap " + root.recordSubmap);
    }
    function stopRecording() {
        if (!root.recording) return;
        root.recording = false;
        Hyprland.dispatch("submap reset");
    }

    // xkb keycode (Qt nativeScanCode on Wayland) → Hyprland key name. By position, so a
    // shortcut recorded with the Arabic layout active is the same key as in English.
    readonly property var keycodeNames: ({
        9: "Escape", 10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8",
        18: "9", 19: "0", 20: "minus", 21: "equal", 22: "BackSpace", 23: "Tab",
        24: "Q", 25: "W", 26: "E", 27: "R", 28: "T", 29: "Y", 30: "U", 31: "I", 32: "O", 33: "P",
        34: "bracketleft", 35: "bracketright", 36: "Return",
        38: "A", 39: "S", 40: "D", 41: "F", 42: "G", 43: "H", 44: "J", 45: "K", 46: "L",
        47: "semicolon", 48: "apostrophe", 49: "grave", 51: "Backslash",
        52: "Z", 53: "X", 54: "C", 55: "V", 56: "B", 57: "N", 58: "M",
        59: "comma", 60: "period", 61: "slash", 65: "Space",
        67: "F1", 68: "F2", 69: "F3", 70: "F4", 71: "F5", 72: "F6", 73: "F7", 74: "F8",
        75: "F9", 76: "F10", 95: "F11", 96: "F12", 107: "Print",
        110: "Home", 111: "up", 112: "Prior", 113: "left", 114: "right", 115: "End",
        116: "down", 117: "Next", 118: "Insert", 119: "Delete"
    })
    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr,
                                         Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L,
                                         Qt.Key_Hyper_R, Qt.Key_CapsLock]

    // A key event → {mods, key} | null (a lone modifier, or a key we cannot name).
    function comboFromEvent(event) {
        if (root.modifierKeys.indexOf(event.key) >= 0) return null;
        const key = root.keycodeNames[event.nativeScanCode];
        if (!key) return null;
        const m = [];
        if (event.modifiers & Qt.MetaModifier) m.push("SUPER");
        if (event.modifiers & Qt.ControlModifier) m.push("CTRL");
        if (event.modifiers & Qt.AltModifier) m.push("ALT");
        if (event.modifiers & Qt.ShiftModifier) m.push("SHIFT");
        return { mods: m.join(" "), key: key };
    }

    // A combination needs a modifier unless the key cannot be typed (F-keys, Print…):
    // a plain letter would stop that letter from ever being typed again.
    function needsModifier(combo) {
        return combo.mods === "" && !/^(F\d+|Print|Insert|Pause)$/.test(combo.key);
    }

    // ── Combos ───────────────────────────────────────────────────────────
    readonly property var modBits: ({ "SUPER": 64, "CTRL": 4, "CONTROL": 4, "ALT": 8, "SHIFT": 1 })
    function maskOf(mods) {
        return String(mods || "").split(/\s+/).reduce((m, t) => m | (root.modBits[t.toUpperCase()] || 0), 0);
    }
    function comboId(b) { return root.maskOf(b.mods) + "|" + String(b.key).toLowerCase(); }
    function comboText(b) {
        const order = ["SUPER", "CTRL", "ALT", "SHIFT"];
        const mask = root.maskOf(b.mods);
        return order.filter(m => mask & root.modBits[m]).join(" ") + "|" + b.key;
    }

    readonly property var keyLabels: ({
        "return": "Enter", "space": "Space", "slash": "/", "question": "?", "semicolon": ";",
        "apostrophe": "'", "backslash": "\\", "minus": "-", "equal": "=", "comma": ",",
        "period": ".", "grave": "`", "bracketleft": "[", "bracketright": "]",
        "prior": "PgUp", "page_up": "PgUp", "next": "PgDn", "page_down": "PgDn",
        "left": "←", "right": "→", "up": "↑", "down": "↓", "escape": "Esc", "delete": "Del",
        "backspace": "⌫", "print": "PrtSc", "mouse:272": "LMB", "mouse:273": "RMB",
        "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
        "xf86audioplay": "Play", "xf86audionext": "Next", "xf86audioprev": "Prev",
        "xf86audiostop": "Stop", "xf86audioraisevolume": "Vol +", "xf86audiolowervolume": "Vol −",
        "xf86audiomute": "Mute", "xf86audiomicmute": "Mic Mute",
        "xf86monbrightnessup": "Bright +", "xf86monbrightnessdown": "Bright −"
    })
    function keyLabel(key) {
        const k = String(key);
        return root.keyLabels[k.toLowerCase()] || (k.length === 1 ? k.toUpperCase() : k);
    }

    // Chips for one bind: ["Super", "Shift", "V"].
    function comboKeys(b) {
        const mask = root.maskOf(b.mods);
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 8) out.push("Alt");
        if (mask & 1) out.push("Shift");
        out.push(root.keyLabel(b.key));
        return out;
    }

    // Chips for an action in lists: its first bind, or its family ("Super + 1 … 0").
    function actionKeys(a) {
        if (!a || !a.binds || a.binds.length === 0) return [];
        if (a.display) {
            const keys = root.comboKeys(a.binds[0]);
            keys[keys.length - 1] = a.display;
            return keys;
        }
        return root.comboKeys(a.binds[0]);
    }

    function label(a) { return I18n.isRTL ? a.ar : a.en; }

    // What else uses this combination, or null: {label, fixed, id} for a catalog action,
    // {label, foreign: true} for a Hyprland bind outside it.
    function conflict(actionId, combo) {
        const id = root.comboId(combo);
        for (const a of root.actions) {
            if (a.id === actionId) continue;
            for (const b of a.binds)
                if (root.comboId(b) === id) return { id: a.id, label: root.label(a), fixed: !!a.fixed };
        }
        for (const f of root.foreign)
            if (root.comboId(f) === id) return { label: f.dispatcher + " " + f.arg, foreign: true };
        return null;
    }

    // ── Changes ──────────────────────────────────────────────────────────
    function setOverrides(o) { ConfigManager.setShortcutOverrides(o); }   // → apply()

    // Gives `actionId` exactly this combination; an action that had it (`replace`) loses it.
    function assign(actionId, combo, replace) {
        const o = Object.assign({}, ConfigManager.shortcutOverrides || {});
        if (replace) {
            const other = root.actions.find(a => a.id === replace);
            if (other) o[replace] = other.binds.filter(b => root.comboId(b) !== root.comboId(combo))
                                             .map(b => root.comboText(b));
        }
        o[actionId] = [root.comboText(combo)];
        root.setOverrides(o);
    }

    function clear(actionId) {
        const o = Object.assign({}, ConfigManager.shortcutOverrides || {});
        o[actionId] = [];
        root.setOverrides(o);
    }

    function reset(actionId) {
        const o = Object.assign({}, ConfigManager.shortcutOverrides || {});
        delete o[actionId];
        root.setOverrides(o);
    }

    function resetAll() { root.setOverrides({}); }

    readonly property int customizedCount: actions.filter(a => a.customized).length
}
