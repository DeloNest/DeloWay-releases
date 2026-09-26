#!/usr/bin/env python3
"""DeloWay per-app language: run one app in Arabic or English whatever the UI language.

    deloway-app-language.py list                      → JSON {desktop id: "ar"|"en"}
    deloway-app-language.py set DESKTOP_ID ar|en|system

How: the app's desktop entry gets a user override in ~/.local/share/applications (which
shadows the system one for every launcher — App Drawer, Dolphin, xdg-open, gtk-launch)
whose Exec lines run it through `env LANGUAGE=… LC_MESSAGES=…`. D-Bus activation is
turned off in the override: GNOME apps (Loupe, Papers…) are otherwise started by the
bus, which ignores Exec. "system" removes the override.

An app whose only desktop entry already lives in the user folder (web apps, AppImages,
Claude…) is edited in place and its original lines are kept in X-DeloWay-* keys, so
"system" restores them exactly.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

MARK = "X-DeloWay-Language"
COPY = "X-DeloWay-Copy"
ORIG_EXEC = "X-DeloWay-OriginalExec"
ORIG_DBUS = "X-DeloWay-OriginalDBusActivatable"

ENV = {
    "ar": "env LANGUAGE=ar:en LC_MESSAGES=ar_SA.UTF-8 ",
    "en": "env LANGUAGE=en_US:en LC_MESSAGES=en_US.UTF-8 ",
}


def user_dir() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "applications"


def system_dirs() -> list:
    dirs = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    return [Path(d) / "applications" for d in dirs if d] + [Path("/var/lib/flatpak/exports/share/applications")]


def desktop_path(base: Path, app_id: str):
    """The file for a desktop id under one base dir ("a-b" may be a/b.desktop)."""
    flat = base / f"{app_id}.desktop"
    if flat.is_file():
        return flat
    parts = app_id.split("-")
    for i in range(1, len(parts)):
        nested = base.joinpath(*parts[:i]) / ("-".join(parts[i:]) + ".desktop")
        if nested.is_file():
            return nested
    return None


def groups(lines):
    """Yield (index, group name or None) for every line."""
    group = None
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            group = s[1:-1]
        yield i, group


def key_of(line):
    return line.split("=", 1)[0].strip() if "=" in line and not line.lstrip().startswith("#") else None


def read_lang(path: Path):
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if key_of(line) == MARK:
                return line.split("=", 1)[1].strip()
    except (OSError, UnicodeDecodeError):
        pass
    return None


def apply_language(lines, lang, copy):
    """The desktop entry lines with every Exec run in `lang`, originals kept."""
    out = []
    for i, group in groups(lines):
        line = lines[i]
        key = key_of(line)
        launchable = group == "Desktop Entry" or (group or "").startswith("Desktop Action ")
        if launchable and key == "Exec":
            orig = line.split("=", 1)[1]
            out.append(f"{ORIG_EXEC}={orig}")
            out.append(f"Exec={ENV[lang]}{orig}")
            continue
        if group == "Desktop Entry" and key == "DBusActivatable":
            out.append(f"{ORIG_DBUS}={line.split('=', 1)[1].strip()}")
            out.append("DBusActivatable=false")
            continue
        out.append(line)
        if line.strip() == "[Desktop Entry]":
            out.append(f"{MARK}={lang}")
            out.append(f"{COPY}={'true' if copy else 'false'}")
    return out


def restore(lines):
    """Undo apply_language on an entry edited in place."""
    out = []
    pending_exec = {}
    for i, group in groups(lines):
        if key_of(lines[i]) == ORIG_EXEC:
            pending_exec[group] = lines[i].split("=", 1)[1]
    for i, group in groups(lines):
        line = lines[i]
        key = key_of(line)
        if key in (MARK, COPY, ORIG_EXEC):
            continue
        if key == "Exec" and group in pending_exec:
            out.append(f"Exec={pending_exec[group]}")
            continue
        if key == ORIG_DBUS:
            out.append(f"DBusActivatable={line.split('=', 1)[1].strip()}")
            continue
        if key == "DBusActivatable" and any(key_of(l) == ORIG_DBUS for l in lines):
            continue   # the original value comes back from ORIG_DBUS
        out.append(line)
    return out


def write(path: Path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".desktop.tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def refresh_cache():
    try:
        subprocess.run(["update-desktop-database", str(user_dir())], capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        pass


def set_language(app_id: str, lang: str) -> dict:
    app_id = app_id[:-len(".desktop")] if app_id.endswith(".desktop") else app_id
    user_file = desktop_path(user_dir(), app_id)
    ours = user_file is not None and read_lang(user_file) is not None

    if lang == "system":
        if not ours:
            return {"ok": True, "app": app_id, "language": "system"}
        lines = user_file.read_text(encoding="utf-8").splitlines()
        copy = any(key_of(l) == COPY and l.split("=", 1)[1].strip() == "true" for l in lines)
        if copy:
            user_file.unlink()
        else:
            write(user_file, restore(lines))
        refresh_cache()
        return {"ok": True, "app": app_id, "language": "system"}

    if lang not in ENV:
        return {"ok": False, "error": "unknown language"}

    if ours:   # change the language of an existing override: start from its original
        lines = restore(user_file.read_text(encoding="utf-8").splitlines())
        copy = read_copy_flag(user_file)
        target = user_file
    elif user_file is not None:   # the app's own entry lives in the user folder: in place
        lines = user_file.read_text(encoding="utf-8").splitlines()
        copy = False
        target = user_file
    else:
        source = next((p for p in (desktop_path(d, app_id) for d in system_dirs()) if p), None)
        if source is None:
            return {"ok": False, "error": "not installed"}
        lines = source.read_text(encoding="utf-8").splitlines()
        copy = True
        target = user_dir() / f"{app_id}.desktop"
    if not any(key_of(l) == "Exec" for l in lines):
        return {"ok": False, "error": "no command to run"}
    write(target, apply_language(lines, lang, copy))
    refresh_cache()
    return {"ok": True, "app": app_id, "language": lang}


def read_copy_flag(path: Path) -> bool:
    for line in path.read_text(encoding="utf-8").splitlines():
        if key_of(line) == COPY:
            return line.split("=", 1)[1].strip() == "true"
    return True


def list_languages() -> dict:
    out = {}
    base = user_dir()
    if base.is_dir():
        for path in base.rglob("*.desktop"):
            lang = read_lang(path)
            if lang:
                out[str(path.relative_to(base))[:-len(".desktop")].replace("/", "-")] = lang
    return out


def main(argv):
    if len(argv) >= 2 and argv[1] == "list":
        print(json.dumps(list_languages()))
        return 0
    if len(argv) >= 4 and argv[1] == "set":
        result = set_language(argv[2], argv[3])
        print(json.dumps(result))
        return 0 if result.get("ok") else 1
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
