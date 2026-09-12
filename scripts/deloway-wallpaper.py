#!/usr/bin/env python3
"""
Deloway Wallpaper Utility
Sets desktop wallpaper across Quickshell, GNOME GSettings, and Deloway configuration.
Supports file paths, URIs (file://), and a graphical file chooser dialog (--browse).
"""

import sys
import os
import json
import urllib.parse
import subprocess
from pathlib import Path

DELOWAY_PROJECT_DIR = os.environ.get("DELOWAY_DIR") or str(Path(__file__).resolve().parent.parent)
SHELL_DIR = os.path.join(DELOWAY_PROJECT_DIR, "shell")
CONFIG_DIR = os.path.expanduser("~/.config/deloway")
CONFIG_FILE = os.path.join(CONFIG_DIR, "deloway.json")

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

def open_file_dialog() -> str:
    """Opens a file dialog to choose an image."""
    try:
        # Prefer kdialog
        res = subprocess.run(
            [
                "kdialog",
                "--getopenfilename",
                os.path.expanduser("~/Pictures"),
                "*.png *.jpg *.jpeg *.webp *.jxl *.bmp|Images (*.png *.jpg *.jpeg *.webp *.jxl *.bmp)"
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    
    # Fallback to zenity if available
    try:
        res = subprocess.run(
            [
                "zenity",
                "--file-selection",
                "--file-filter=Image files (png,jpg,jpeg,webp) | *.png *.jpg *.jpeg *.webp *.jxl"
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass

    return ""

def update_config_file(abs_path: str):
    """Persists the wallpaper path in ~/.config/deloway/deloway.json."""
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
        print(f"[deloway-wallpaper] Failed to write {CONFIG_FILE}: {e}", file=sys.stderr)

def sync_gnome_gsettings(abs_path: str):
    """Updates GNOME GSettings for picture-uri and picture-uri-dark."""
    file_uri = f"file://{abs_path}"
    try:
        subprocess.run(
            ["gsettings", "set", "org.gnome.desktop.background", "picture-uri", file_uri],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )
        subprocess.run(
            ["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", file_uri],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )
    except Exception:
        pass

def notify_quickshell(abs_path: str):
    """Sends IPC command to Quickshell to reload wallpaper immediately."""
    try:
        subprocess.run(
            ["quickshell", "ipc", "-p", SHELL_DIR, "call", "deloway", "setWallpaper", abs_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=2
        )
    except Exception as e:
        print(f"[deloway-wallpaper] Quickshell IPC warning: {e}", file=sys.stderr)

def send_notification(abs_path: str):
    """Sends a system notification."""
    name = Path(abs_path).name
    try:
        subprocess.run(
            [
                "notify-send",
                "-a", "Deloway",
                "-i", abs_path,
                "خلفية الشاشة",
                f"تم تعيين الخلفية: {name}"
            ],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )
    except Exception:
        pass

def set_wallpaper(raw_path: str, notify: bool = True):
    abs_path = normalize_path(raw_path)
    if not abs_path or not os.path.exists(abs_path):
        print(f"[deloway-wallpaper] Error: File does not exist: {raw_path}", file=sys.stderr)
        return False
    
    print(f"[deloway-wallpaper] Applying wallpaper: {abs_path}")
    update_config_file(abs_path)
    sync_gnome_gsettings(abs_path)
    notify_quickshell(abs_path)
    if notify:
        send_notification(abs_path)
    return True

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("Usage: deloway-wallpaper <path-or-uri> | --browse | --get")
        sys.exit(0)
    
    arg = sys.argv[1]
    
    if arg == "--get":
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r") as f:
                    c = json.load(f)
                    print(c.get("theme", {}).get("wallpaper", ""))
                    sys.exit(0)
            except Exception:
                pass
        print("")
        sys.exit(0)
        
    if arg == "--browse":
        chosen = open_file_dialog()
        if chosen:
            success = set_wallpaper(chosen, notify=True)
            sys.exit(0 if success else 1)
        else:
            print("[deloway-wallpaper] No file chosen.")
            sys.exit(0)

    no_notify = "--no-notify" in sys.argv
    success = set_wallpaper(arg, notify=not no_notify)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
