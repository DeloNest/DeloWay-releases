#!/usr/bin/env python3
"""DeloWay app backend: resolve a desktop entry to its owner and (optionally) remove it.

    deloway-app-info.py info      <desktop-id>
    deloway-app-info.py uninstall <desktop-id> [--dry-run]

Both print one JSON object on stdout.

Ownership (first match wins):
  flatpak   the .desktop comes from a flatpak exports dir   → flatpak uninstall
  pacman    a .desktop in the system data dirs is owned by a package (pacman -Qo)
            → pamac remove (polkit prompt via the session agent)
  user      only a per-user .desktop exists (web apps, AppImage/manual shortcuts)
            → the launcher is moved to Trash (gio trash) — reversible
  unowned   system .desktop not owned by any package → not removable

Safety: core packages (compositor, shell, init, drivers, package manager…) and packages
other installed packages depend on are reported as not removable; `uninstall` refuses them.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys

ENV_C = dict(os.environ, LC_ALL="C", LANG="C")
HOME = os.path.expanduser("~")

# Never offered for removal from a context menu.
PROTECTED_PACKAGES = {
    "base", "base-devel", "filesystem", "glibc", "bash", "coreutils", "systemd", "systemd-libs",
    "linux", "linux-lts", "linux-zen", "linux-hardened", "linux-firmware", "mkinitcpio", "grub",
    "pacman", "pamac", "pamac-gtk", "pamac-gtk3", "pamac-cli", "libpamac", "sudo", "polkit",
    "hyprland", "hyprland-git", "quickshell", "quickshell-git", "xdg-desktop-portal",
    "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "hyprpolkitagent",
    "pipewire", "pipewire-pulse", "wireplumber", "networkmanager", "bluez", "mesa",
    "nvidia", "nvidia-dkms", "nvidia-utils", "python", "qt6-base", "qt6-declarative",
    "qt6-wayland", "gtk3", "gtk4", "dbus", "util-linux", "shadow",
}


def data_dirs():
    xdg_home = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
    dirs = [xdg_home]
    for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":"):
        if d and d not in dirs:
            dirs.append(d)
    for extra in (os.path.join(HOME, ".local/share/flatpak/exports/share"),
                  "/var/lib/flatpak/exports/share", "/usr/local/share", "/usr/share"):
        if extra not in dirs:
            dirs.append(extra)
    return dirs


def is_flatpak_path(p):
    return "/flatpak/exports/" in p


def is_user_path(p):
    return p.startswith(os.path.join(HOME, ".local/share/applications"))


def candidates(desktop_id):
    """All .desktop files for this id, highest XDG priority first (case-insensitive)."""
    want = desktop_id.lower()
    if want.endswith(".desktop"):
        want = want[: -len(".desktop")]
    out = []
    for d in data_dirs():
        appdir = os.path.join(d, "applications")
        if not os.path.isdir(appdir):
            continue
        for path in glob.glob(os.path.join(appdir, "**", "*.desktop"), recursive=True):
            rel = os.path.relpath(path, appdir)[: -len(".desktop")].replace("/", "-")
            if rel.lower() == want and os.path.realpath(path) not in [os.path.realpath(x) for x in out]:
                out.append(path)
    if out:
        return out
    # Fallback: match StartupWMClass (dock ids come from window classes)
    for d in data_dirs():
        for path in glob.glob(os.path.join(d, "applications", "**", "*.desktop"), recursive=True):
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    m = re.search(r"^StartupWMClass\s*=\s*(.+)$", f.read(), re.M)
                if m and m.group(1).strip().lower() == want:
                    out.append(path)
            except OSError:
                pass
    return out


def read_entry(path):
    fields = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            in_main = False
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    in_main = line == "[Desktop Entry]"
                    continue
                if in_main and "=" in line:
                    k, v = line.split("=", 1)
                    fields.setdefault(k.strip(), v.strip())
    except OSError:
        pass
    return fields


class LookupFailed(Exception):
    pass


def run(cmd, timeout=20):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, env=ENV_C, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except OSError as e:
        return 127, "", str(e)


def pacman_owner(path):
    code, out, err = run(["pacman", "-Qqo", path])
    if code == 0 and out.strip():
        return out.strip().splitlines()[0]
    if "No package owns" in err or "error: No package" in err:
        return None
    # Timeouts, a locked/broken DB… must never be mistaken for "not owned".
    raise LookupFailed(err.strip() or "pacman exit %d" % code)


def pacman_info(pkg):
    code, out, _ = run(["pacman", "-Qi", pkg])
    info = {}
    if code != 0:
        return info
    key = None
    for line in out.splitlines():
        m = re.match(r"^([A-Za-z][A-Za-z ]+?)\s*:\s?(.*)$", line)
        if m:
            key = m.group(1).strip()
            info[key] = m.group(2).strip()
        elif key and line.startswith(" "):
            info[key] += " " + line.strip()
    foreign = run(["pacman", "-Qqm", pkg])[0] == 0
    info["_foreign"] = foreign
    return info


def listify(v):
    return [] if not v or v == "None" else v.split()


def flatpak_ref(path):
    """Flatpak app id + installation (user/system) from an exported desktop file."""
    app_id = os.path.basename(path)[: -len(".desktop")]
    scope = "user" if path.startswith(HOME) else "system"
    code, out, _ = run(["flatpak", "info", "--" + scope, app_id])
    fields = {}
    if code == 0:
        for line in out.splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                fields[k.strip()] = v.strip()
    return app_id, scope, fields


def resolve(desktop_id):
    files = candidates(desktop_id)
    if not files:
        return {"ok": False, "id": desktop_id, "error": "desktop entry not found"}

    main = files[0]
    entry = read_entry(main)
    res = {
        "ok": True,
        "id": desktop_id,
        "desktopFile": main,
        "name": entry.get("Name", desktop_id),
        "comment": entry.get("Comment", ""),
        "exec": entry.get("Exec", ""),
        "categories": [c for c in entry.get("Categories", "").split(";") if c],
        "source": "unowned",
        "package": "",
        "version": "",
        "description": "",
        "url": "",
        "size": "",
        "installDate": "",
        "licenses": "",
        "requiredBy": [],
        "removable": False,
        "reason": "",
        "userOverride": is_user_path(main) and len(files) > 1,
        "webApp": False,
    }

    flat = next((f for f in files if is_flatpak_path(f)), None)
    system_files = [f for f in files if not is_user_path(f) and not is_flatpak_path(f)]
    owner = None
    try:
        for f in system_files:
            owner = pacman_owner(f)
            if owner:
                break
    except LookupFailed as e:
        res.update(source="unknown", reason="lookup-failed", error=str(e))
        return res

    if flat and not owner:
        app_id, scope, fields = flatpak_ref(flat)
        res.update(source="flatpak", package=app_id, flatpakScope=scope,
                   version=fields.get("Version", ""), size=fields.get("Installed", ""),
                   description=fields.get("Subject", ""), removable=True)
        res["origin"] = fields.get("Origin", "")
    elif owner:
        pi = pacman_info(owner)
        req = listify(pi.get("Required By", ""))
        res.update(source="aur" if pi.get("_foreign") else "pacman", package=owner,
                   version=pi.get("Version", ""), description=pi.get("Description", ""),
                   url=pi.get("URL", ""), size=pi.get("Installed Size", ""),
                   installDate=pi.get("Install Date", ""), licenses=pi.get("Licenses", ""),
                   requiredBy=req)
        if owner in PROTECTED_PACKAGES:
            res["reason"] = "protected"
        elif req:
            res["reason"] = "required"
        else:
            res["removable"] = True
    elif is_user_path(main) and not system_files:
        exe = (res["exec"].split() or [""])[0]
        res["webApp"] = bool(re.search(r"--app-id=|--app=|chrome-|brave-", main + " " + res["exec"]))
        res.update(source="user", package=os.path.basename(main), removable=True)
        res["execPath"] = shutil.which(exe) or exe
    else:
        res["reason"] = "unmanaged"
    return res


def uninstall(desktop_id, dry_run=False):
    info = resolve(desktop_id)
    if not info.get("ok"):
        return {"ok": False, "id": desktop_id, "error": info.get("error", "not found")}
    if not info["removable"]:
        return {"ok": False, "id": desktop_id, "source": info["source"],
                "error": info.get("reason") or "not removable", "requiredBy": info["requiredBy"]}

    src = info["source"]
    if src in ("pacman", "aur"):
        cmd = ["pamac", "remove", "--no-confirm", info["package"]]
    elif src == "flatpak":
        cmd = ["flatpak", "uninstall", "--" + info.get("flatpakScope", "user"),
               "-y", "--noninteractive", info["package"]]
    elif src == "user":
        cmd = ["gio", "trash", info["desktopFile"]]
    else:
        return {"ok": False, "id": desktop_id, "error": "unsupported source"}

    if dry_run:
        return {"ok": True, "id": desktop_id, "source": src, "package": info["package"],
                "dryRun": True, "command": cmd}

    code, out, err = run(cmd, timeout=900)          # pamac waits for the polkit prompt
    tail = "\n".join((err or out).strip().splitlines()[-3:])
    return {"ok": code == 0, "id": desktop_id, "source": src, "package": info["package"],
            "name": info["name"], "error": "" if code == 0 else (tail or "exit %d" % code)}


def main(argv):
    if len(argv) < 3 or argv[1] not in ("info", "uninstall"):
        print(json.dumps({"ok": False, "error": "usage: info|uninstall <desktop-id> [--dry-run]"}))
        return 2
    if argv[1] == "info":
        print(json.dumps(resolve(argv[2]), ensure_ascii=False))
    else:
        print(json.dumps(uninstall(argv[2], "--dry-run" in argv), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
