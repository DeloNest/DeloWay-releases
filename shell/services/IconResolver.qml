pragma Singleton
import QtQuick
import Quickshell

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
            if (name.startsWith("/")) return "file://" + name;
            // Tray items with their own IconThemePath: the icon lives outside the theme,
            // where hasThemeIcon() cannot see it; the provider resolves it.
            if (/(?:^|&)path=/.test(query)) return s;
            const fb = (/(?:^|&)fallback=([^&]*)/.exec(query) || [])[1];
            return root.themeUrl(name, fb ? decodeURIComponent(fb) : "");
        }
        if (s.startsWith("/")) return "file://" + s;
        if (s.includes("://")) return s;
        return root.themeUrl(s);
    }
}
