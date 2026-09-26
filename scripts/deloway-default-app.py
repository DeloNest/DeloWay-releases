#!/usr/bin/env python3
"""DeloWay default apps by file type: which installed apps can open images, videos,
PDFs and code, which one does now, and making one the default.

    deloway-default-app.py status                 → JSON {apps: {role: [ids]}, current: {role: id}}
    deloway-default-app.py set ROLE DESKTOP_ID [--web]

The default is written with xdg-mime (~/.config/mimeapps.list), which GTK, Qt/KDE,
xdg-open and the browsers all read. Only the role's own types are touched: an app that
also declares other types (Cine lists inode/directory) does not take them over.
--web: the app is the web browser; the common web-viewable types of the role are set
even when its desktop file does not list them (Brave lists no video types).
Role "editor": plain text and source code / scripts. Text editors declare only
text/plain (every source type is a sub-type of it), and without explicit defaults shell
scripts opened in the terminal (kitty-open) and C files in vim.
"""

import configparser
import json
import os
import subprocess
import sys
from pathlib import Path

ROLES = {
    "image": {"key": "image/png", "family": lambda m: m.startswith("image/"),
              "web": ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml",
                      "image/avif", "image/bmp"]},
    "video": {"key": "video/mp4", "family": lambda m: m.startswith("video/"),
              "web": ["video/mp4", "video/webm", "video/ogg"]},
    "pdf": {"key": "application/pdf",
            "family": lambda m: m in ("application/pdf", "application/x-pdf", "application/x-bzpdf",
                                      "application/x-gzpdf", "application/x-xzpdf"),
            "web": ["application/pdf"]},
    "editor": {"key": "text/plain", "family": lambda m: m in EDITOR_TYPES, "web": []},
}

# Plain text, source code and scripts — never text/html (the browser's) or .desktop files.
EDITOR_TYPES = [
    "text/plain", "text/markdown", "text/x-log", "text/csv", "text/css", "text/xml",
    "application/xml", "application/json", "application/x-yaml", "application/yaml",
    "application/toml", "text/x-toml", "application/x-shellscript", "text/x-shellscript",
    "application/x-perl", "text/x-python", "text/x-python3", "application/x-python",
    "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/x-c++hdr", "text/x-java",
    "text/x-lua", "text/rust", "text/x-rust", "text/x-go", "text/javascript",
    "application/javascript", "application/x-typescript", "text/x-qml", "text/x-cmake",
    "text/x-makefile", "text/x-patch", "text/x-diff", "application/x-php",
]


def app_dirs():
    data_home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs = [data_home] + data_dirs.split(":") + ["/var/lib/flatpak/exports/share"]
    return [Path(d) / "applications" for d in dirs if d]


def desktop_entries():
    """{desktop id: {name, mimes}} of the visible applications, first match wins (the
    user's own entries shadow the system's, as in the spec)."""
    found = {}
    for base in app_dirs():
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.desktop")):
            app_id = str(path.relative_to(base))[:-len(".desktop")].replace("/", "-")
            if app_id in found:
                continue
            cfg = configparser.RawConfigParser(strict=False, interpolation=None)
            cfg.optionxform = str
            try:
                cfg.read(path, encoding="utf-8")
            except (configparser.Error, UnicodeDecodeError):
                continue
            if not cfg.has_section("Desktop Entry"):
                continue
            e = cfg["Desktop Entry"]
            if e.get("Type", "Application") != "Application":
                continue
            hidden = e.get("NoDisplay", "false") == "true" or e.get("Hidden", "false") == "true"
            mimes = [m for m in e.get("MimeType", "").split(";") if m]
            found[app_id] = {"name": e.get("Name", app_id), "mimes": mimes, "hidden": hidden}
    return found


def current_default(mime):
    try:
        out = subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True,
                             text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""
    return out[:-len(".desktop")] if out.endswith(".desktop") else out


def role_types(role, entry, web):
    spec = ROLES[role]
    if role == "editor":
        return list(EDITOR_TYPES)   # any text editor opens every text sub-type
    types = [m for m in entry["mimes"] if spec["family"](m)]
    if web:
        types += [m for m in spec["web"] if m not in types]
    return types


def status():
    entries = desktop_entries()
    apps = {}
    for role, spec in ROLES.items():
        if role == "editor":
            continue   # editors come from their Categories (the shell knows them)
        apps[role] = sorted((i for i, e in entries.items()
                             if not e["hidden"] and any(spec["family"](m) for m in e["mimes"])),
                            key=lambda i: entries[i]["name"].lower())
    current = {role: current_default(spec["key"]) for role, spec in ROLES.items()}
    print(json.dumps({"apps": apps, "current": current}))


def set_default(role, app_id, web):
    if role not in ROLES:
        print(json.dumps({"ok": False, "error": "unknown role"}))
        return 1
    app_id = app_id[:-len(".desktop")] if app_id.endswith(".desktop") else app_id
    entry = desktop_entries().get(app_id)
    if not entry:
        print(json.dumps({"ok": False, "error": "not installed"}))
        return 1
    types = role_types(role, entry, web)
    if not types:
        print(json.dumps({"ok": False, "error": "opens none of these files"}))
        return 1
    result = subprocess.run(["xdg-mime", "default", app_id + ".desktop"] + types,
                            capture_output=True, text=True, timeout=10)
    print(json.dumps({"ok": result.returncode == 0, "role": role, "app": app_id, "types": types}))
    return result.returncode


def main(argv):
    if len(argv) >= 2 and argv[1] == "status":
        status()
        return 0
    if len(argv) >= 4 and argv[1] == "set":
        return set_default(argv[2], argv[3], "--web" in argv[4:])
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
