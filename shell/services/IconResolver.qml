pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// IconResolver: the one place theme icons are turned into image URLs.
//
// Quickshell's icon image provider answers a lookup it cannot satisfy with a real image,
// a magenta/black checkerboard, and reports Image.Ready. A status check therefore cannot
// catch a missing icon; the name has to be proved with hasThemeIcon() before it is ever
// requested. Every theme-icon consumer (SymbolicIcon, AppIcon, tray glyphs and menus,
// notification icons) goes through here, so a missing icon renders as nothing (or the
// caller's own fallback) instead of the checkerboard.
Item {
    id: root

    // True when the current icon theme (or one it inherits) provides `name`.
    function has(name) {
        return !!name && Quickshell.hasThemeIcon(name);
    }

    // URL of the first of `names` the theme provides, or "" when none is.
    function themeUrl(...names) {
        for (const n of names) {
            if (root.has(n)) return Quickshell.iconPath(n, "");
        }
        return "";
    }

    // /usr/share/pixmaps, the icon spec's last place to look: some apps install their icon
    // only there (Antigravity), where hasThemeIcon() cannot see it. The folder is read once
    // (name → file, svg over png over xpm) so only files that exist are ever requested.
    property var pixmaps: ({})
    Process {
        running: true
        command: ["sh", "-c", "ls -1 /usr/share/pixmaps 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rank = { "svg": 3, "png": 2, "xpm": 1 };
                const map = {};
                for (const file of text.split("\n")) {
                    const m = /^(.+)\.(svg|png|xpm)$/i.exec(file);
                    if (!m) continue;
                    const key = m[1].toLowerCase();
                    const prev = map[key];
                    if (!prev || rank[m[2].toLowerCase()] > rank[prev.split(".").pop().toLowerCase()]) map[key] = file;
                }
                root.pixmaps = map;
            }
        }
    }

    // file:// URL of the pixmap called `name` (any extension), or "".
    function pixmapUrl(name) {
        if (!name) return "";
        const file = root.pixmaps[String(name).toLowerCase().replace(/\.(svg|png|xpm)$/i, "")];
        return file ? "file:///usr/share/pixmaps/" + file : "";
    }

    // Icons that point somewhere (log out, external link, speaker…) have "-rtl" variants in
    // icon themes; in Arabic the variant is used when the theme has it. Themes spell it
    // both ways (system-log-out-rtl-symbolic, audio-volume-high-symbolic-rtl). Opt-in per
    // call: arrows the caller already swaps (go-previous/go-next) must not flip twice.
    function directional(name) {
        if (!name || !I18n.isRTL) return name;
        const candidates = /-symbolic$/.test(name)
            ? [name.replace(/-symbolic$/, "-rtl-symbolic"), name + "-rtl"]
            : [name + "-rtl"];
        for (const c of candidates) if (root.has(c)) return c;
        return name;
    }

    // Any icon source a D-Bus client or a caller may hand us — "image://icon/NAME",
    // "image://icon/NAME?fallback=OTHER", a plain theme name, a path or another image
    // provider URL (tray pixmaps: image://qsimage/…) — made safe to display. Theme lookups
    // are proved first; everything else passes through unchanged.
    function safeUrl(source) {
        if (!source) return "";
        const s = String(source);
        if (s.startsWith("image://icon/")) {
            const rest = s.substring("image://icon/".length);
            const q = rest.indexOf("?");
            const name = decodeURIComponent(q >= 0 ? rest.substring(0, q) : rest);
            const query = q >= 0 ? rest.substring(q + 1) : "";
            // A path smuggled into the theme provider (some tray items do this)
            if (name.startsWith("/")) return ConfigManager.fileUrl(name);
            // Tray items with their own IconThemePath: the icon lives outside the theme,
            // where hasThemeIcon() cannot see it; the provider resolves it.
            if (/(?:^|&)path=/.test(query)) return s;
            const fb = (/(?:^|&)fallback=([^&]*)/.exec(query) || [])[1];
            return root.themeUrl(name, fb ? decodeURIComponent(fb) : "");
        }
        if (s.startsWith("/")) return ConfigManager.fileUrl(s);
        if (s.includes("://")) return s;
        return root.themeUrl(s);
    }
}
