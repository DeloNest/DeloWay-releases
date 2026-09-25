#!/usr/bin/env python3
"""
Deloway Wallpaper Daemon
Monitors GNOME GSettings (org.gnome.desktop.background picture-uri)
so when browsers (Firefox, Chrome), image viewers (Loupe, EOG), or file managers (Thunar)
perform "Set as Desktop Background", Deloway immediately picks up the new wallpaper!
"""

import sys
import os
import time
import json
import urllib.parse
import subprocess
from pathlib import Path

DELOWAY_PROJECT_DIR = os.environ.get("DELOWAY_DIR") or str(Path(__file__).resolve().parent.parent)
SHELL_DIR = os.path.join(DELOWAY_PROJECT_DIR, "shell")
from deloway_config import config_path, tr

CONFIG_FILE = config_path()
CONFIG_DIR = os.path.dirname(CONFIG_FILE)

def normalize_path(raw_path: str) -> str:
    if not raw_path:
        return ""
    p = raw_path.strip().strip("'\"")
    if p.startswith("picture-uri:"):
        p = p.split(":", 1)[1].strip().strip("'\"")
    if p.startswith("file://"):
        p = urllib.parse.unquote(p[7:])
    p = os.path.expanduser(p)
    return os.path.abspath(p)

def get_current_deloway_wallpaper() -> str:
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                c = json.load(f)
                return c.get("theme", {}).get("wallpaper", "")
        except Exception:
            pass
    return ""

def update_config_file(abs_path: str):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    cfg = {}
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
        except Exception:
            cfg = {}
    
    if "theme" not in cfg or not isinstance(cfg["theme"], dict):
        cfg["theme"] = {}
    
    cfg["theme"]["wallpaper"] = abs_path

    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"[deloway-wallpaper-daemon] Failed to write {CONFIG_FILE}: {e}", file=sys.stderr)

def notify_quickshell(abs_path: str):
    try:
        subprocess.run(
            ["quickshell", "ipc", "-p", SHELL_DIR, "call", "deloway", "setWallpaper", abs_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=2
        )
    except Exception as e:
        print(f"[deloway-wallpaper-daemon] Quickshell IPC warning: {e}", file=sys.stderr)

def _die_with_parent():
    """preexec_fn: PR_SET_PDEATHSIG(SIGTERM) in the child before exec."""
    import ctypes, signal
    ctypes.CDLL(None).prctl(1, signal.SIGTERM, 0, 0, 0)

def acquire_single_instance_lock():
    """One daemon per user session: exec-once runs on every login, and the daemon
    outlives Hyprland when KillUserProcesses=no. Returns the held lock file."""
    import fcntl
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/deloway-{os.getuid()}"
    os.makedirs(runtime, exist_ok=True)
    fh = open(os.path.join(runtime, "deloway-wallpaper-daemon.lock"), "w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)          # another instance is already running
    return fh

def compositor_alive():
    """False once the Hyprland session that started us is gone."""
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        return True          # not started from Hyprland: keep running
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    return os.path.exists(os.path.join(runtime, "hypr", sig))

def main():
    _lock = acquire_single_instance_lock()
    print("[deloway-wallpaper-daemon] Starting GSettings wallpaper sync monitor...", file=sys.stderr)
    cmd = ["gsettings", "monitor", "org.gnome.desktop.background", "picture-uri"]

    while compositor_alive():
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
                preexec_fn=_die_with_parent,   # gsettings must not outlive the daemon
            )
            for line in proc.stdout:
                line = line.strip()
                if not line:
                    continue
                path = normalize_path(line)
                if not path or not os.path.exists(path):
                    continue
                
                current = get_current_deloway_wallpaper()
                if path != current:
                    print(f"[deloway-wallpaper-daemon] Detected external wallpaper change: {path}", file=sys.stderr)
                    update_config_file(path)
                    notify_quickshell(path)
                    try:
                        subprocess.run(
                            [
                                "notify-send",
                                "-a", "Deloway",
                                "-i", path,
                                tr("Wallpaper", "خلفية الشاشة"),
                                tr(f"Wallpaper set: {Path(path).name}", f"تم تعيين الخلفية: {Path(path).name}")
                            ],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
                        )
                    except Exception:
                        pass
        except Exception as e:
            print(f"[deloway-wallpaper-daemon] Error in monitor loop: {e}", file=sys.stderr)
        # gsettings exited (EOF, e.g. the session bus went away): never respawn in a
        # busy loop, and stop once the compositor session is gone.
        time.sleep(2)

if __name__ == "__main__":
    main()
