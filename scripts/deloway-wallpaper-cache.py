#!/usr/bin/env python3
"""
Deloway Wallpaper Thumbnail Cache Manager
Lazily generates and caches small wallpaper thumbnails under ~/.cache/deloway/wallpapers/.
Handles double spaces, Arabic filenames, parentheses, and special characters safely.
"""

import sys
import os
import hashlib
import json
import subprocess
from pathlib import Path

import urllib.parse

CACHE_DIR = Path(os.path.expanduser("~/.cache/deloway/wallpapers"))
THUMB_WIDTH = 280
THUMB_HEIGHT = 175

def clean_path(path_str: str) -> str:
    s = path_str.strip()
    if s.startswith("file://"):
        s = s[7:]
    return urllib.parse.unquote(s)

def get_thumb_path(image_path: str) -> Path:
    clean = clean_path(image_path)
    try:
        real_p = os.path.realpath(clean)
        st = os.stat(real_p)
        key = f"{real_p}:{st.st_mtime}:{st.st_size}".encode("utf-8")
    except Exception:
        key = clean.encode("utf-8")
    h = hashlib.sha256(key).hexdigest()[:16]
    return CACHE_DIR / f"{h}.jpg"

def generate_thumb(image_path: str, thumb_p: Path) -> bool:
    clean = clean_path(image_path)
    if not os.path.exists(clean):
        return False
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if thumb_p.exists() and thumb_p.stat().st_size > 0:
        return True
    try:
        # Use ImageMagick with geometry to fill and center-crop
        geom = f"{THUMB_WIDTH}x{THUMB_HEIGHT}^"
        extent = f"{THUMB_WIDTH}x{THUMB_HEIGHT}"
        cmd = [
            "magick", clean,
            "-thumbnail", geom,
            "-gravity", "center",
            "-extent", extent,
            "-quality", "85",
            str(thumb_p)
        ]
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return False

def list_wallpapers():
    project_dir = Path(__file__).resolve().parent.parent
    scanner = project_dir / "scripts" / "deloway-wallpapers-list.py"
    try:
        res = subprocess.run(["python3", str(scanner)], capture_output=True, text=True, check=True)
        items = json.loads(res.stdout.strip())
    except Exception:
        items = []

    for item in items:
        p = item.get("path", "")
        thumb_p = get_thumb_path(p)
        item["thumb"] = str(thumb_p)
        item["thumbExists"] = thumb_p.exists() and thumb_p.stat().st_size > 0

    print(json.dumps(items, ensure_ascii=False))

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "--list":
        list_wallpapers()
        return

    if sys.argv[1] == "--thumb" and len(sys.argv) >= 3:
        img_p = sys.argv[2]
        thumb_p = get_thumb_path(img_p)
        generate_thumb(img_p, thumb_p)
        print(str(thumb_p))
        return

    if sys.argv[1] == "--batch":
        # Generate thumbnails for a list of paths
        for path in sys.argv[2:]:
            if path:
                thumb_p = get_thumb_path(path)
                generate_thumb(path, thumb_p)
        print("OK")
        return

if __name__ == "__main__":
    main()
